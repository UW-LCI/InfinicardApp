import 'dart:math';

class Point {
  double x;
  double y;
  int? strokeId;

  Point(this.x, this.y, [this.strokeId]);

  double distanceTo(Point other) {
    return sqrt(pow(x - other.x, 2) + pow(y - other.y, 2));
  }
}

class MultiStrokePath {
  List<List<Point>> strokes;
  String? name;

  MultiStrokePath(this.strokes, [this.name]);

  List<Point> get asPoints => strokes.expand((stroke) => stroke).toList();
}

class DollarQ {
  List<MultiStrokePath> _templates = [];
  final int cloudSize;
  final int lutSize;

  DollarQ({this.cloudSize = 32, this.lutSize = 64});

  set templates(List<MultiStrokePath> newTemplates) {
    _templates = newTemplates.map((t) {
      var normalizedPoints = normalize(t.asPoints, cloudSize, lutSize);
      var mstroke = MultiStrokePath([normalizedPoints], t.name);
      mstroke.lut = computeLookUpTable(normalizedPoints, lutSize, cloudSize);
      return mstroke;
    }).toList();
  }

  List<MultiStrokePath> get templates => _templates;

  Map<String, dynamic> recognize(MultiStrokePath points) {
    var score = double.infinity;
    var normalizedPoints = normalize(points.asPoints, cloudSize, lutSize);
    var lut = computeLookUpTable(normalizedPoints, lutSize, cloudSize);
    var updatedCandidate = MultiStrokePath([normalizedPoints]);
    updatedCandidate.lut = lut;

    MultiStrokePath? match;
    int? templateIndex;

    for (var i = 0; i < templates.length; i++) {
      var template = templates[i];
      var d = cloudMatch(updatedCandidate, template, cloudSize, score);
      if (d < score) {
        score = d;
        match = template;
        templateIndex = i;
      }
    }

    if (match != null && templateIndex != null) {
      return {
        'template': match.asPoints,
        'templateIndex': templateIndex,
        'score': score,
      };
    }

    return {};
  }

  static List<Point> normalize(List<Point> points, int cloudSize, int lookUpTableSize) {
    var resampled = resample(points, cloudSize);
    var translated = translateToOrigin(resampled);
    var scaled = scale(translated, lookUpTableSize);
    return scaled;
  }

  static List<Point> resample(List<Point> points, int n) {
    var interval = pathLength(points) / (n - 1);
    var D = 0.0;
    var newPoints = [points[0]];

    for (var i = 1; i < points.length; i++) {
      var d = points[i].distanceTo(points[i - 1]);
      if (D + d >= interval) {
        var qx = points[i - 1].x + ((interval - D) / d) * (points[i].x - points[i - 1].x);
        var qy = points[i - 1].y + ((interval - D) / d) * (points[i].y - points[i - 1].y);
        var q = Point(qx, qy, points[i].strokeId);
        newPoints.add(q);
        points.insert(i, q);
        D = 0;
      } else {
        D += d;
      }
    }

    if (newPoints.length == n - 1) {
      newPoints.add(points.last);
    }

    return newPoints;
  }

  static List<Point> translateToOrigin(List<Point> points) {
    var centroid = calculateCentroid(points);
    return points.map((p) => Point(p.x - centroid.x, p.y - centroid.y, p.strokeId)).toList();
  }

  static Point calculateCentroid(List<Point> points) {
    var sumX = 0.0, sumY = 0.0;
    for (var p in points) {
      sumX += p.x;
      sumY += p.y;
    }
    return Point(sumX / points.length, sumY / points.length);
  }

  static List<Point> scale(List<Point> points, int m) {
    var minX = points.map((p) => p.x).reduce(min);
    var maxX = points.map((p) => p.x).reduce(max);
    var minY = points.map((p) => p.y).reduce(min);
    var maxY = points.map((p) => p.y).reduce(max);

    var size = max(maxX - minX, maxY - minY);
    return points.map((p) => Point(
      (p.x - minX) * (m - 1) / size,
      (p.y - minY) * (m - 1) / size,
      p.strokeId
    )).toList();
  }

  static List<List<int>> computeLookUpTable(List<Point> points, int m, int n) {
    var lut = List.generate(m, (_) => List.filled(m, -1));
    for (var x = 0; x < m; x++) {
      for (var y = 0; y < m; y++) {
        var point = Point(x.toDouble(), y.toDouble());
        var minIndex = 0;
        var minDist = double.infinity;
        for (var i = 0; i < points.length; i++) {
          var dist = point.distanceTo(points[i]);
          if (dist < minDist) {
            minDist = dist;
            minIndex = i;
          }
        }
        lut[x][y] = minIndex;
      }
    }
    return lut;
  }

  static double cloudMatch(MultiStrokePath points, MultiStrokePath template, int n, double minimum) {
    var step = sqrt(n).round();
    var lowerBound1 = computeLowerBound(points.asPoints, template.asPoints, step, n, template.lut!);
    var lowerBound2 = computeLowerBound(template.asPoints, points.asPoints, step, n, points.lut!);
    var minSoFar = minimum;

    for (var i = 0; i < n - 1; i += step) {
      var index = i ~/ step;
      if (lowerBound1[index] < minSoFar) {
        var distance = cloudDistance(points.asPoints, template.asPoints, n, i, minSoFar);
        minSoFar = min(minSoFar, distance);
      }
      if (lowerBound2[index] < minSoFar) {
        var distance = cloudDistance(template.asPoints, points.asPoints, n, i, minSoFar);
        minSoFar = min(minSoFar, distance);
      }
    }
    return minSoFar;
  }

  static double cloudDistance(List<Point> points, List<Point> template, int n, int start, double minSoFar) {
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
      unmatched.remove(index);
      sum += (n - unmatched.length) * minDist;
      if (sum >= minSoFar) {
        return sum;
      }
      i = (i + 1) % n;
    } while (i != start);
    return sum;
  }

  static List<double> computeLowerBound(List<Point> points, List<Point> template, int step, int n, List<List<int>> lut) {
    var lowerBound = [0.0];
    var summedAreaTable = <double>[];

    for (var i = 0; i < n; i++) {
      var point = points[i];
      var x = point.x.toInt();
      var y = point.y.toInt();
      var index = lut[x][y];
      var distance = point.distanceTo(template[index]);
      var area = i == 0 ? distance : summedAreaTable[i - 1] + distance;
      summedAreaTable.add(area);
      lowerBound[0] += (n - i) * distance;
    }

    for (var i = step; i < n - 1; i += step) {
      var nextValue = lowerBound[0] + (i * summedAreaTable[n - 1]) - (n * summedAreaTable[i - 1]);
      lowerBound.add(nextValue);
    }
    return lowerBound;
  }

  static double pathLength(List<Point> points) {
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += points[i].distanceTo(points[i - 1]);
    }
    return length;
  }
}

extension MultiStrokePathExtension on MultiStrokePath {
  static final Map<MultiStrokePath, List<List<int>>?> _lutStorage = {};

  List<List<int>>? get lut => _lutStorage[this];
  set lut(List<List<int>>? value) => _lutStorage[this] = value;
}