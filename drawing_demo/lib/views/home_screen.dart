import 'package:flutter/material.dart';
import '../widgets/canvas_widget.dart';
import '../widgets/recognition_result_widget.dart';
import '../widgets/control_panel_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _recognitionResult = '';

  void _updateRecognitionResult(String result) {
    setState(() {
      _recognitionResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Gesture Recognizer'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: CanvasWidget(
              onRecognitionComplete: _updateRecognitionResult,
            ),
          ),
          RecognitionResultWidget(result: _recognitionResult),
          const ControlPanelWidget(),
        ],
      ),
    );
  }
}
