import 'package:drawing_demo/views/canvas.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stroke_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => StrokeProvider(),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: DrawingCanvas(),
      )
    );
  }
}
