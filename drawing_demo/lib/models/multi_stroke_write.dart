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

  void startGesture({
    required String name,
    required String subject,
    String inputType = 'finger',
    required MultiStrokePath multistroke,
  }) {
    int count =
        multistroke.strokes.fold(0, (sum, stroke) => sum + stroke.length);

    builder.element('Gestures', nest: () {
      builder.attribute('Name', name);
      builder.attribute('Subject', subject);
      builder.attribute('InputType', inputType);
      builder.attribute('Speed', 'MEDIUM');
      builder.attribute('NumPts', count.toString());

      write(multistroke);
    });
  }

  void write(MultiStrokePath multiStrokePath) {
    for (var stroke in multiStrokePath.strokes) {
      strokeCount++;
      builder.element('Stroke', nest: () {
        builder.attribute('index', strokeCount.toString());
        for (var point in stroke) {
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

  String endDocument() {
    return builder.buildDocument().toXmlString(pretty: true);
  }

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

  Future<String> generateUniqueName(
      Directory directory, String baseFileName) async {
    const uuid = Uuid();
    String uniqueFileName = '${baseFileName}_${uuid.v4()}';
    return '$uniqueFileName.xml';
  }
}
