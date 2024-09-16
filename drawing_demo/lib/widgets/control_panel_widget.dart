// control_panel_widget.dart

import 'package:flutter/material.dart';

class ControlPanelWidget extends StatelessWidget {
  final VoidCallback onClear;
  final VoidCallback onRecognize;
  final VoidCallback onSave;

  const ControlPanelWidget({
    super.key,
    required this.onClear,
    required this.onRecognize,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: onClear,
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: onRecognize,
            child: const Text('Recognize'),
          ),
          ElevatedButton(
            onPressed: onSave,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
