import 'package:flutter/material.dart';
import 'views/drawing_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drawing Recognition App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const DrawingPage(),
    );
  }
}
