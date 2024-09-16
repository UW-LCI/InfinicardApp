import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../models/dollar_q.dart';

class CanvasWidget extends StatefulWidget {
  final Function(String) onRecognitionComplete;

  const CanvasWidget({super.key, required this.onRecognitionComplete});

  @override
  _CanvasWidgetState createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends State<CanvasWidget> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  late DollarQ _dollarQ;

  @override
  void initState() {
    super.initState();
    _dollarQ = DollarQ();
    _loadTemplates();
  }

  void _loadTemplates() {
    // TODO: Load your gesture templates here
    // For now, we'll just add a simple template as an example
    var template = MultiStrokePath([
      [Point(0, 0), Point(1, 1), Point(2, 2)],
    ], "line");
    _dollarQ.templates = [template];
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = [details.localPosition];
      _strokes.add(_currentStroke);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentStroke.add(details.localPosition);
      _strokes[_strokes.length - 1] = List.from(_currentStroke);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _recognizeGesture();
  }

  void _recognizeGesture() {
    var points = _strokes.map((stroke) =>
      stroke.map((offset) => Point(offset.dx, offset.dy)).toList()
    ).toList();

    var candidate = MultiStrokePath(points);
    var result = _dollarQ.recognize(candidate);

    if (result.isNotEmpty) {
      var score = result['score'] as double;
      var templateIndex = result['templateIndex'] as int;
      var templateName = _dollarQ.templates[templateIndex].name;
      widget.onRecognitionComplete('Recognized: $templateName (Score: ${score.toStringAsFixed(2)})');
    } else {
      widget.onRecognitionComplete('No match found');
    }
  }

  void _clear() {
    setState(() {
      _strokes.clear();
    });
    widget.onRecognitionComplete('');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: CustomPaint(
        painter: _CanvasPainter(_strokes),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
        ),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _CanvasPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (final stroke in strokes) {
      if (stroke.length > 1) {
        canvas.drawPoints(ui.PointMode.polygon, stroke, paint);
      } else if (stroke.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}