import 'package:flutter/material.dart';

class ControlPanelWidget extends StatelessWidget {
  const ControlPanelWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () {
              // Implement clear functionality
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement recognize functionality
            },
            child: const Text('Recognize'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement save functionality
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}