import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stroke_provider.dart';
import '../models/stroke.dart';

class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({super.key});

  @override
  _DrawingCanvasState createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final List<Offset> _currentPoints = []; // Maybe not needed

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // onPanStart: (details) {
      //   setState(() {
      //     RenderBox renderBox = context.findRenderObject() as RenderBox;
      //     _currentPoints.add(renderBox.globalToLocal(details.globalPosition));
      //   });
      // },

      onPanUpdate: (details) {
        setState(() {
          RenderBox renderBox = context.findRenderObject() as RenderBox;
          _currentPoints.add(renderBox.globalToLocal(details.globalPosition));
        });
        // Update Stroke Provider (real time drawing)
      },

      onPanEnd: (details) {
        Provider.of<StrokeProvider>(context, listen: false).addStroke(
          Stroke(points: List.from(_currentPoints), color: Colors.black, strokeWidth: 5.0),
        );
        setState(() {
          _currentPoints.clear();
        });
      },

      child: Consumer<StrokeProvider>(
        builder: (context, strokeProvider, child) {
          return CustomPaint(
            painter: DrawingPainter(strokes: strokeProvider.strokes),
            child: Container(),
          );
        },
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<Stroke> strokes;

  DrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (var stroke in strokes) {
      Paint paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke.strokeWidth;
      for (int i = 0; i < stroke.points.length - 1; i++) {
          canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}