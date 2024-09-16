import 'dart:io';
import 'package:xml/xml.dart' as xml;
import 'package:path_provider/path_provider.dart';
import 'dollar_q.dart';
import 'package:uuid/uuid.dart';

class MultiStrokeWrite {
  final xml.XmlBuilder builder = xml.XmlBuilder();
  int strokeCount = 0;

  MultiStrokeWrite() {
    builder.processing(
        'xml', 'version="1.0" encoding="utf-8" standalone="yes"');
    builder.element('Gestures', nest: () {});
  }

  /// Starts a new gesture entry in the XML.
  void startGesture({
    required String name,
    required String subject,
    String inputType = 'finger',
    required MultiStrokePath multistroke,
  }) {
    // Total number of points
    int pointCount = multistroke.strokes.length;

    builder.element('Gestures', nest: () {
      builder.attribute('Name', name);
      builder.attribute('Subject', subject);
      builder.attribute('InputType', inputType);
      builder.attribute('Speed', 'MEDIUM');
      builder.attribute('NumPts', pointCount.toString());

      write(multistroke);
    });
  }

  /// Writes the strokes of a gesture to the XML.
  void write(MultiStrokePath multiStrokePath) {
    // Group points by strokeId
    Map<int, List<GesturePoint>> groupedStrokes = groupByStroke(multiStrokePath.strokes);

    for (var entry in groupedStrokes.entries) {
      int strokeId = entry.key;
      List<GesturePoint> strokePoints = entry.value;

      strokeCount++;
      builder.element('Stroke', nest: () {
        builder.attribute('index', strokeCount.toString());
        for (var point in strokePoints) {
          builder.element('Point', nest: () {
            builder.attribute('X', point.x.round().toString());
            builder.attribute('Y', point.y.round().toString());
            if (point.time != null) {
              builder.attribute('T', point.time!.toString());
            }
            if (point.pressure != null) {
              builder.attribute('Pressure', point.pressure!.toString());
            }
          });
        }
      });
    }
  }

  /// Groups a list of GesturePoints by their strokeId.
  Map<int, List<GesturePoint>> groupByStroke(List<GesturePoint> points) {
    Map<int, List<GesturePoint>> grouped = {};
    for (var point in points) {
      grouped.putIfAbsent(point.strokeId, () => []).add(point);
    }
    return grouped;
  }

  /// Finalizes the XML document and returns it as a string.
  String endDocument() {
    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Saves the XML document to the specified directory with a unique file name.
  Future<void> saveToDirectory(String directory, String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dirPath = '${appDir.path}/XMLData/$directory';
      final dir = Directory(dirPath);

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      String uniqueFileName = await generateUniqueName(dir, fileName);
      final file = File('$dirPath/$uniqueFileName');

      await file.writeAsString(endDocument());
      print('File created and data written successfully to: ${file.path}');
    } catch (e) {
      print('Failed to save XML file: $e');
    }
  }

  /// Generates a unique file name using UUID.
  Future<String> generateUniqueName(
      Directory directory, String baseFileName) async {
    const uuid = Uuid();
    String uniqueFileName = '${baseFileName}_${uuid.v4()}';
    return '$uniqueFileName.xml';
  }
}
