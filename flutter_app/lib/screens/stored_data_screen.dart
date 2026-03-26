import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class StoredDataScreen extends StatefulWidget {
  final String buildingName;
  final List<String> instructions;

  const StoredDataScreen({
    super.key,
    required this.buildingName,
    required this.instructions,
  });

  @override
  State<StoredDataScreen> createState() => _StoredDataScreenState();
}

class _StoredDataScreenState extends State<StoredDataScreen> {
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    // Speak the instructions automatically when the screen loads
    _speak();
  }

  Future<void> _speak() async {
    String fullInstructions = widget.instructions.join('. ');
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5); // A slower, clearer rate
    await flutterTts.speak(fullInstructions);
  }

  Future<void> _stop() async {
    await flutterTts.stop();
  }

  @override
  void dispose() {
    // IMPORTANT: Stop TTS and release resources when the screen is closed
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.buildingName),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context, 'recall_scan'),
            icon: const Icon(Icons.history),
            tooltip: 'Recall Last Scan',
          ),
        ],
      ),
      body: ListView.builder(
        // Add padding at the bottom to avoid FAB overlap
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
        itemCount: widget.instructions.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            elevation: 2.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              title: Text(
                widget.instructions[index],
                style: const TextStyle(fontSize: 16),
              ),
            ),
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _speak,
            tooltip: 'Speak Directions',
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            heroTag: 'speakBtn',
            child: const Icon(Icons.volume_up),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: _stop,
            tooltip: 'Stop Speaking',
            backgroundColor: Colors.grey.shade700,
            foregroundColor: Colors.white,
            heroTag: 'stopBtn',
            child: const Icon(Icons.stop),
          ),
        ],
      ),
    );
  }
}
