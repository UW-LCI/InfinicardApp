import 'package:flutter/material.dart';
import '../widgets/canvas_widget.dart';
import '../widgets/control_panel_widget.dart';

class DrawingPage extends StatefulWidget {
  const DrawingPage({super.key});

  @override
  _DrawingPageState createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  // Create a GlobalKey to access the CanvasWidget's state
  final GlobalKey<CanvasWidgetState> _canvasKey = GlobalKey<CanvasWidgetState>();

  // Method to handle recognition results
  void _onRecognitionComplete(String result) {
    if (result.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  // Method to prompt the user for a gesture name
  Future<String?> _promptForGestureName(BuildContext context) async {
    String? gestureName;
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Gesture'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Gesture Name',
            ),
            onChanged: (value) {
              gestureName = value;
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(gestureName);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing Recognition App'),
      ),
      body: Column(
        children: [
          // Expanded widget to make CanvasWidget take available space
          Expanded(
            child: CanvasWidget(
              key: _canvasKey,
              onRecognitionComplete: _onRecognitionComplete,
            ),
          ),
          // ControlPanelWidget with callbacks
          ControlPanelWidget(
            onClear: () {
              _canvasKey.currentState?.clearCanvas();
            },
            onRecognize: () {
              _canvasKey.currentState?.recognizeGesture();
            },
            onSave: () async {
              String? name = await _promptForGestureName(context);
              if (name != null && name.trim().isNotEmpty) {
                _canvasKey.currentState?.saveGesture(name.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gesture "$name" saved successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gesture name cannot be empty')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
