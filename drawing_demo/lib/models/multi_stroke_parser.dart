import 'dart:io';
import 'package:xml/xml.dart' as xml;
import 'package:path_provider/path_provider.dart';
import 'dollar_q.dart';

class MultiStrokeParser {
  static const String xmlDataFolder = 'XMLData';

  static Future<List<MultiStrokePath>> loadStrokePatternsLocal() async {
    final directory = await getApplicationDocumentsDirectory();
    final patternDir = Directory('${directory.path}/$xmlDataFolder');

    if (!await patternDir.exists()) {
      return [];
    }

    List<MultiStrokePath> paths = [];

    await for (var entity
        in patternDir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.xml')) {
        String contents = await entity.readAsString();
        paths.add(parseXmlString(contents));
      }
    }

    return paths;
  }

  static Future<MultiStrokePath> loadStrokePattern(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$xmlDataFolder/$fileName.xml');

    if (!await file.exists()) {
      throw Exception("File not found: $fileName.xml");
    }

    String contents = await file.readAsString();
    return parseXmlString(contents);
  }

  static Future<List<MultiStrokePath>> loadStrokePatterns(
      List<String> fileNames) async {
    List<MultiStrokePath> paths = [];
    for (var fileName in fileNames) {
      try {
        MultiStrokePath path = await loadStrokePattern(fileName);
        paths.add(path);
      } catch (e) {
        print("Error loading $fileName: $e");
      }
    }
    return paths;
  }

  static MultiStrokePath parseXmlString(String xmlString) {
    try {
      final document = xml.XmlDocument.parse(xmlString);
      final gestureElement = document.rootElement;

      String? gestureName = gestureElement.getAttribute('Name');
      gestureName = gestureName?.split('~').first;

      List<List<GesturePoint>> strokes = [];
      var strokeElements = gestureElement.findElements('Stroke');

      for (var strokeIndex = 0;
          strokeIndex < strokeElements.length;
          strokeIndex++) {
        var strokeElement = strokeElements.elementAt(strokeIndex);
        List<GesturePoint> currentStroke = [];
        var pointElements = strokeElement.findElements('Point');

        for (var pointElement in pointElements) {
          double x = double.parse(pointElement.getAttribute('X') ?? '0');
          double y = double.parse(pointElement.getAttribute('Y') ?? '0');
          double? time = double.tryParse(pointElement.getAttribute('T') ?? '');
          double? pressure =
              double.tryParse(pointElement.getAttribute('Pressure') ?? '');

          currentStroke.add(GesturePoint(x, y, strokeIndex, time, pressure));
        }

        strokes.add(currentStroke);
      }

      return MultiStrokePath(strokes.expand((element) => element).toList(), gestureName ?? 'Unknown');
    } catch (e) {
      print('Error parsing XML: $e');
      throw const FormatException('Error parsing XML');
    }
  }

}
