import 'package:flutter/material.dart';

class Stroke {
  List<Offset> points;
  Color color;
  double strokeWidth;
  int? timestamp;

  Stroke({required this.points, required this.color, required this.strokeWidth, this.timestamp});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Stroke &&
        listEquals(other.points, points) &&
        other.color == color &&
        other.strokeWidth == strokeWidth;
  }

  @override
  int get hashCode => points.hashCode ^ color.hashCode ^ strokeWidth.hashCode;
}

bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}