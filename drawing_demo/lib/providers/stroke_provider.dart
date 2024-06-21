import 'package:flutter/material.dart';
import '../models/stroke.dart';

class StrokeProvider extends ChangeNotifier {
  final List<Stroke> _strokes = [];

  List<Stroke> get strokes => _strokes;

  // TODO: Update Stroke Provider (real time drawing)
  void updateStroke(Offset point) {
    if(_strokes.isEmpty) {
      _strokes.add(Stroke(points: [], color: Colors.black, strokeWidth: 5.0));
    }
    _strokes.last.points.add(point);
    notifyListeners();
  }

  void addStroke(Stroke stroke) {
    _strokes.add(stroke);
    notifyListeners();
  }

  void removeStroke(Stroke stroke) {
    _strokes.remove(stroke);
    notifyListeners();
  }

  void clearStrokes() {
    _strokes.clear();
    notifyListeners();
  }
}