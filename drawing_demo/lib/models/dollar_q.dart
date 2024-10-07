import 'dart:math';
import 'dart:async';
import 'dart:isolate';
import 'dart:io';

class GesturePoint {
  double x, y;
  int strokeId;
  double? time;
  double? pressure;
  int index;

  GesturePoint(this.x, this.y, this.strokeId,
      [this.time, this.pressure, this.index = -1]);

  double distanceTo(GesturePoint other) {
    var dx = x - other.x;
    var dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }
}

class MultiStrokePath {
  List<GesturePoint> strokes;
  String name; // maybe optional
  List<List<int>>? lut; // Look-up table

  MultiStrokePath(this.strokes, [this.name = '']);
}

class DollarQ {
  List<MultiStrokePath> _templates = [];
  final int cloudSize;
  final int lutSize;
  late KDTree _kdTree;

  DollarQ({this.cloudSize = 32, this.lutSize = 64});

  set templates(List<MultiStrokePath> newTemplates) {
    _templates = newTemplates.map((t) {
      var normalizedPoints = normalize(t.strokes, cloudSize, lutSize);
      for (int i = 0; i < normalizedPoints.length; i++) {
        normalizedPoints[i].index = i; // Assigning index
      }
      var mstroke = MultiStrokePath(normalizedPoints, t.name);
      mstroke.lut = computeLookUpTable(normalizedPoints, lutSize, cloudSize);
      return mstroke;
    }).toList();

    // Build a k-d tree for spatial indexing
    List<GesturePoint> allPoints = _templates.expand((t) => t.strokes).toList();
    _kdTree = KDTree(allPoints);
  }

  List<MultiStrokePath> get templates => _templates;

  Future<Map<String, dynamic>> recognize(MultiStrokePath points) async {
    var score = double.infinity;
    var normalizedPoints = normalize(points.strokes, cloudSize, lutSize);
    for (int i = 0; i < normalizedPoints.length; i++) {
      normalizedPoints[i].index = i;
    }
    var lut = computeLookUpTable(normalizedPoints, lutSize, cloudSize);
    var updatedCandidate = MultiStrokePath(normalizedPoints);
    updatedCandidate.lut = lut;

    // Use isolates to parallelize the matching process
    int processorCount = Platform.numberOfProcessors;
    int batchSize = (_templates.length / processorCount).ceil();
    List<Future<_MatchResult>> futures = [];

    for (int i = 0; i < _templates.length; i += batchSize) {
      int end = (i + batchSize < _templates.length)
          ? i + batchSize
          : _templates.length;
      var subset = _templates.sublist(i, end);
      var isolateData = _IsolateData(
        candidate: updatedCandidate,
        templates: subset,
        cloudSize: cloudSize,
        initialMin: score,
        sendPort: ReceivePort().sendPort,
      );
      futures.add(_matchTemplatesInIsolate(isolateData));
    }

    var results = await Future.wait(futures);
    _MatchResult? bestMatch;

    for (var result in results) {
      if (result.distance < score) {
        score = result.distance;
        bestMatch = result;
      }
    }

    if (bestMatch != null) {
      int templateIndex = _templates.indexOf(bestMatch.template);
      return {
        'template': bestMatch.template.strokes,
        'templateIndex': templateIndex,
        'score': score,
      };
    }

    return {};
  }

  Future<_MatchResult> _matchTemplatesInIsolate(_IsolateData data) async {
    final response = ReceivePort();
    final isolateData = _IsolateData(
      candidate: data.candidate,
      templates: data.templates,
      cloudSize: data.cloudSize,
      initialMin: data.initialMin,
      sendPort: response.sendPort, // Pass the SendPort
    );
    await Isolate.spawn<_IsolateData>(
      (data) => _isolateEntry(data, cloudMatch),
      isolateData,
      onExit: response.sendPort,
      onError: response.sendPort,
    );

    // Listen for the _MatchResult from the isolate
    return await response.first as _MatchResult;
  }

  static void _isolateEntry(
      _IsolateData data,
      double Function(MultiStrokePath, MultiStrokePath, int, double)
          cloudMatch) {
    _MatchResult best = _MatchResult(MultiStrokePath([]), data.initialMin);
    for (var template in data.templates) {
      var d =
          cloudMatch(data.candidate, template, data.cloudSize, best.distance);
      if (d < best.distance) {
        best = _MatchResult(template, d);
      }
    }

    // Send the best match back to the main isolate
    data.sendPort.send(best);
  }

  List<GesturePoint> normalize(
      List<GesturePoint> points, int cloudSize, int lookUpTableSize) {
    var resampled = resample(points, cloudSize);
    var translated = translateToOrigin(resampled);
    var scaled = scale(translated, lookUpTableSize);
    return scaled;
  }

  List<GesturePoint> resample(List<GesturePoint> points, int n) {
    // Validate 'n' to prevent excessive memory allocation
    if (n <= 1 || n > 1000) {
      // Adjust the upper limit as needed
      throw ArgumentError('Parameter n must be between 2 and 1000');
    }
    print('Resample called with n=$n and points.length=${points.length}');
    var pathLen = pathLength(points);
    print('Total path length: $pathLen');
    var interval = pathLen / (n - 1);
    var D = 0.0;
    var newPoints = <GesturePoint>[points[0]];
    var i = 1;
    const int maxPoints = 1000; // Define a maximum cap for newPoints

    while (i < points.length && newPoints.length < maxPoints) {
      var d = points[i].distanceTo(points[i - 1]);
      if (D + d >= interval) {
        var t = (interval - D) / d;
        var qx = points[i - 1].x + t * (points[i].x - points[i - 1].x);
        var qy = points[i - 1].y + t * (points[i].y - points[i - 1].y);
        var q = GesturePoint(
            qx, qy, points[i].strokeId, points[i].time, points[i].pressure);
        newPoints.add(q);
        D = 0.0;
      } else {
        D += d;
        i++;
      }
    }

    // Ensure the last point is added if necessary
    if (newPoints.length == n - 1 && i < points.length) {
      newPoints.add(points.last);
    }

    return newPoints;
  }

  List<GesturePoint> translateToOrigin(List<GesturePoint> points) {
    var centroid = calculateCentroid(points);
    return points
        .map((p) => GesturePoint(p.x - centroid.x, p.y - centroid.y, p.strokeId,
            p.time, p.pressure, p.index))
        .toList();
  }

  GesturePoint calculateCentroid(List<GesturePoint> points) {
    var sumX = 0.0, sumY = 0.0;
    for (var p in points) {
      sumX += p.x;
      sumY += p.y;
    }
    return GesturePoint(sumX / points.length, sumY / points.length, 0);
  }

  List<GesturePoint> scale(List<GesturePoint> points, int m) {
    var minX = points.map((p) => p.x).reduce(min);
    var maxX = points.map((p) => p.x).reduce(max);
    var minY = points.map((p) => p.y).reduce(min);
    var maxY = points.map((p) => p.y).reduce(max);

    var size = max(maxX - minX, maxY - minY);
    return points
        .map((p) => GesturePoint(
            (p.x - minX) * (m - 1) / size,
            (p.y - minY) * (m - 1) / size,
            p.strokeId,
            p.time,
            p.pressure,
            p.index))
        .toList();
  }

  List<List<int>> computeLookUpTable(List<GesturePoint> points, int m, int n) {
    var lut = List.generate(m, (_) => List.filled(m, -1));
    for (var x = 0; x < m; x++) {
      for (var y = 0; y < m; y++) {
        var point = GesturePoint(x.toDouble(), y.toDouble(), 0);
        var nearest = _kdTree.nearest(point);
        lut[x][y] = nearest?.index ?? -1;
      }
    }
    return lut;
  }

  double cloudMatch(
      MultiStrokePath points, MultiStrokePath template, int n, double minimum) {
    var step = sqrt(n).round();
    var lowerBound1 = computeLowerBound(
        points.strokes, template.strokes, step, n, template.lut!);
    var lowerBound2 = computeLowerBound(
        template.strokes, points.strokes, step, n, points.lut!);
    var minSoFar = minimum;

    for (var i = 0; i < n - 1; i += step) {
      var index = i ~/ step;
      if (lowerBound1[index] < minSoFar) {
        var distance =
            cloudDistance(points.strokes, template.strokes, n, i, minSoFar);
        minSoFar = min(minSoFar, distance);
      }
      if (lowerBound2[index] < minSoFar) {
        var distance =
            cloudDistance(template.strokes, points.strokes, n, i, minSoFar);
        minSoFar = min(minSoFar, distance);
      }
    }
    return minSoFar;
  }

  double cloudDistance(List<GesturePoint> points, List<GesturePoint> template,
      int n, int start, double minSoFar) {
    var i = start;
    var unmatched = List.generate(n, (index) => index);
    var sum = 0.0;
    do {
      var index = -1;
      var minDist = double.infinity;
      for (var j in unmatched) {
        var d = points[i].distanceTo(template[j]);
        if (d < minDist) {
          minDist = d;
          index = j;
        }
      }
      if (index == -1) break; // No match found
      unmatched.remove(index);
      sum += (n - unmatched.length) * minDist;
      if (sum >= minSoFar) {
        return sum;
      }
      i = (i + 1) % n;
    } while (i != start);
    return sum;
  }

  List<double> computeLowerBound(List<GesturePoint> points,
      List<GesturePoint> template, int step, int n, List<List<int>> lut) {
    var lowerBound = <double>[];
    var summedAreaTable = <double>[];

    double sum = 0.0;
    for (var i = 0; i < n; i++) {
      var point = points[i];
      var x = point.x.toInt().clamp(0, lut.length - 1);
      var y = point.y.toInt().clamp(0, lut[0].length - 1);
      var index = lut[x][y];
      if (index == -1 || index >= template.length) continue;
      var distance = point.distanceTo(template[index]);
      sum += distance;
      summedAreaTable.add(sum);
    }

    lowerBound.add(sum);
    for (var i = step; i < n - 1; i += step) {
      var nextValue = lowerBound[0] +
          (i * (summedAreaTable.last)) -
          (n * (summedAreaTable[i - step < 0 ? 0 : i - step]));
      lowerBound.add(nextValue);
    }
    return lowerBound;
  }

  double pathLength(List<GesturePoint> points) {
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += points[i].distanceTo(points[i - 1]);
    }
    return length;
  }
}

class _MatchResult {
  MultiStrokePath template;
  double distance;

  _MatchResult(this.template, this.distance);
}

class _IsolateData {
  MultiStrokePath candidate;
  List<MultiStrokePath> templates;
  int cloudSize;
  double initialMin;
  SendPort sendPort;

  _IsolateData({
    required this.candidate,
    required this.templates,
    required this.cloudSize,
    required this.initialMin,
    required this.sendPort,
  });
}

// Simple k-d tree implementation for spatial indexing
class KDTree {
  KDNode? _root;

  KDTree(List<GesturePoint> points) {
    _root = _buildKDTree(points, 0);
  }

  GesturePoint? nearest(GesturePoint target) {
    double bestDist = double.infinity;
    GesturePoint? bestPoint;

    void search(KDNode? node, int depth) {
      if (node == null) return;

      double d = target.distanceTo(node.point);
      if (d < bestDist) {
        bestDist = d;
        bestPoint = node.point;
      }

      int axis = depth % 2;
      KDNode? next = axis == 0
          ? (target.x < node.point.x ? node.left : node.right)
          : (target.y < node.point.y ? node.left : node.right);
      KDNode? other = axis == 0
          ? (target.x < node.point.x ? node.right : node.left)
          : (target.y < node.point.y ? node.right : node.left);

      search(next, depth + 1);
      double diff = axis == 0
          ? (target.x - node.point.x).abs()
          : (target.y - node.point.y).abs();
      if (diff < bestDist) {
        search(other, depth + 1);
      }
    }

    search(_root, 0);
    return bestPoint;
  }

  static KDNode? _buildKDTree(List<GesturePoint> points, int depth) {
    if (points.isEmpty) return null;

    int axis = depth % 2;
    points.sort((a, b) => axis == 0 ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    int median = points.length ~/ 2;
    return KDNode(
      point: points[median],
      left: _buildKDTree(points.sublist(0, median), depth + 1),
      right: _buildKDTree(points.sublist(median + 1), depth + 1),
    );
  }
}

class KDNode {
  GesturePoint point;
  KDNode? left;
  KDNode? right;

  KDNode({
    required this.point,
    this.left,
    this.right,
  });
}
