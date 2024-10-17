import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui' as ui;
import '../models/multi_stroke_parser.dart';
import '../models/dollar_q.dart';
import '../models/multi_stroke_write.dart';

class CanvasWidget extends StatefulWidget {
  final Function(String) onRecognitionComplete;

  const CanvasWidget({super.key, required this.onRecognitionComplete});

  @override
  CanvasWidgetState createState() => CanvasWidgetState();
}

class CanvasWidgetState extends State<CanvasWidget> {
  final List<List<GesturePoint>> _strokes = [];
  List<GesturePoint> _currentStroke = [];
  late DollarQ _dollarQ;

  @override
  void initState() {
    super.initState();
    _dollarQ = DollarQ();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      var templates = await MultiStrokeParser.loadStrokePatternsLocal();
      _dollarQ.templates = templates;
      print("Loaded ${templates.length} templates");
    } catch (e) {
      print("Error loading templates: $e");
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    setState(() {
      _currentStroke = [_createPoint(event)];
      _strokes.add(_currentStroke);
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    setState(() {
      _currentStroke.add(_createPoint(event));
      _strokes[_strokes.length - 1] = List.from(_currentStroke);
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    _recognizeGesture();
  }

  GesturePoint _createPoint(PointerEvent event) {
    double? pressure;
    if (event.kind == PointerDeviceKind.stylus) {
      pressure = (event.pressure * 255).round().toDouble();
    }
    return GesturePoint(
      event.localPosition.dx,
      event.localPosition.dy,
      _strokes.length - 1, // strokeId
      event.timeStamp.inMilliseconds.toDouble(),
      pressure
    );
  }

  // // This is for DOLLARQ recognition, we can ignore this for now
  void _recognizeGesture() async {
      var flattenedStrokes = _strokes.expand((stroke) => stroke).toList();
      var candidate = MultiStrokePath(flattenedStrokes);
      var result = await _dollarQ.recognize(candidate);

      if (result.isNotEmpty) {
        var score = result['score'] as double;
        var templateIndex = result['templateIndex'] as int;
        var templateName = _dollarQ.templates[templateIndex].name;
        widget.onRecognitionComplete('Recognized: $templateName (Score: ${score.toStringAsFixed(2)})');
      } else {
        widget.onRecognitionComplete('No match found');
      }
    }

  Future<void> _saveGesture(String name) async {
    var flattenedStrokes = _strokes.expand((stroke) => stroke).toList();
    var multistroke = MultiStrokePath(flattenedStrokes, name);
    var writer = MultiStrokeWrite();
    writer.startGesture(name: name, subject: "01", multistroke: multistroke);

    try {
      await writer.saveToDirectory(name, name);
      print("Gesture saved successfully");
      // Reload templates after saving
      await _loadTemplates();
    } catch (e) {
      print("Error saving gesture: $e");
    }
  }
  // // End of DOLLAR Q recognition

  void _clear() {
    setState(() {
      _strokes.clear();
    });
    widget.onRecognitionComplete('');
  }

  // Public methods to be accessed from parent
  void clearCanvas() {
    _clear();
  }

  void recognizeGesture() {
    _recognizeGesture();
  }

  Future<void> saveGesture(String name) async {
    await _saveGesture(name);
  }

  // Build the canvas widget (VIEW)
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      child: CustomPaint(
        painter: _CanvasPainter(_strokes),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color.fromARGB(0, 12, 11, 11),
        ),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<List<GesturePoint>> strokes;

  _CanvasPainter(this.strokes);


  // Possible bug here, drawing path cannot properly handle angles.
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;
    paint.style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length > 1) {
        var path = Path();
        path.moveTo(stroke[0].x, stroke[0].y);
        for (var i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].x, stroke[i].y);
        }
        canvas.drawPath(path, paint);
      } else if (stroke.length == 1) {
        canvas.drawPoints(ui.PointMode.points, [Offset(stroke[0].x, stroke[0].y)], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
