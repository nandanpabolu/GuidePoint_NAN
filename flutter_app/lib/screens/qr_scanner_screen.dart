import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math'; 
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';

// IMPORTS
import '../demo_data.dart';
import 'astar_pathfinding.dart';
import 'navigation_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool isProcessing = false;
  final MobileScannerController cameraController = MobileScannerController();

  AStarPathfinder? _pathfinder;
  String _buildingName = '';
  String? _startNodeId; // From QR payload (optional); null => use main_entrance

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _recognizedWords = '';

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    _initSpeech();
  }

  void _initSpeech() async {
    // Initialize speech engine
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        // Optional: You can handle status updates here
      },
      onError: (errorNotification) {
        // Optional: Handle errors (like no mic input)
      },
    );
    if (mounted) setState(() {});
  }

  void _startListening() async {
    // Clear previous words so the UI looks fresh
    setState(() => _recognizedWords = ''); 
    
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _recognizedWords = result.recognizedWords;
          if (result.finalResult) {
            _isListening = false;
            _findPathToDestination(_recognizedWords);
          }
        });
      },
      listenFor: const Duration(seconds: 10), // Stop automatically after 10s
      pauseFor: const Duration(seconds: 3),   // Wait 3s for silence before processing
    );
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  Future<void> _requestCameraPermission() async {
    await Permission.camera.request();
    // Also request microphone permission here to be safe
    await Permission.microphone.request();
    if (mounted) setState(() {});
  }

  void processQRCode(String code) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);
    
    try {
      String jsonString;
      final uri = Uri.tryParse(code);

      if (uri != null && uri.isAbsolute) {
        final response = await http.get(uri).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw Exception('Request timed out loading map URL'),
        );
        if (response.statusCode == 200) {
          jsonString = response.body;
        } else {
          throw Exception('Failed to load data from URL: ${response.statusCode}');
        }
      } else {
        jsonString = code;
      }
      
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('qr_data', jsonString);

      final pathfinder = AStarPathfinder.fromJson(jsonData);
      // Optional: QR can include start_node_id when placed at a waypoint
      final rawStartId = jsonData['start_node_id'] as String?;
      final startNodeId = (rawStartId != null && rawStartId.isNotEmpty && pathfinder.nodes.containsKey(rawStartId))
          ? rawStartId
          : null;

      if (mounted) {
        setState(() {
          _pathfinder = pathfinder;
          _buildingName = jsonData['building']?['name'] ?? 'Unknown Building';
          _startNodeId = startNodeId;
          isProcessing = false;
        });

        if (_speechEnabled) {
          _startListening();
        }
      }

    } catch (e) {
      if (!mounted) return;
      _showErrorDialog("Could not process QR Code.\nError: ${e.toString()}");
      setState(() => isProcessing = false);
    }
  }
  
  void _findPathToDestination(String destinationName) {
    if (_pathfinder == null || destinationName.isEmpty) {
      _showErrorDialog("No destination spoken or map data not loaded.");
      return;
    }

    String? targetId;
    for (var node in _pathfinder!.nodes.values) {
      if (node.name.toLowerCase().contains(destinationName.toLowerCase())) {
        targetId = node.id;
        break;
      }
    }

    if (targetId == null) {
      _showErrorDialog("Could not find a place named '$destinationName'. Please try again.");
      return;
    }

    final String startId = _startNodeId ?? 'main_entrance';

    if (!_pathfinder!.nodes.containsKey(startId)) {
      _showErrorDialog("Start point not found in map data.");
       return;
    }

    final List<String> pathIds = _pathfinder!.findPath(startId, targetId);

    if (pathIds.isEmpty) {
      _showErrorDialog("Could not find a path to $destinationName.");
      return;
    }

    _navigateToGuidance(pathIds);
  }

  void _navigateToGuidance(List<String> pathIds) {
    final List<String> instructions = [];

    if (pathIds.length < 2) {
       instructions.add("You are already at the destination.");
    } else {
      for (int i = 0; i < pathIds.length - 1; i++) {
        String currentId = pathIds[i];
        String nextId = pathIds[i + 1];

        Node? currentNode = _pathfinder!.nodes[currentId];
        Node? nextNode = _pathfinder!.nodes[nextId];

        if (currentNode != null && nextNode != null) {
          double distance = sqrt(pow(nextNode.x - currentNode.x, 2) + pow(nextNode.y - currentNode.y, 2));
          String distString = distance.toStringAsFixed(1);
          instructions.add("Walk $distString meters to ${nextNode.name}.");
        }
      }
      instructions.add("You have reached your destination.");
    }

    unawaited(_goToNavigation(pathIds, instructions));
  }

  /// Release the QR scanner camera before opening navigation (owns its own camera).
  Future<void> _goToNavigation(List<String> pathIds, List<String> instructions) async {
    try {
      await cameraController.stop();
    } catch (_) {}
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          buildingName: _buildingName,
          route: pathIds,
          pathfinder: _pathfinder!,
          instructions: instructions,
        ),
      ),
    );
  }
  
  void _showErrorDialog(String message) {
     showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text("Navigation Error"),
            content: Text(message),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pathfinder == null ? "Scan Building QR Code" : _buildingName),
      ),
      // I kept the button here so the user can RETRY if the auto-listen fails
      floatingActionButton: _pathfinder == null
          ? null
          : FloatingActionButton(
              onPressed: _speechToText.isNotListening ? _startListening : _stopListening,
              tooltip: 'Retry Listening',
              child: Icon(_speechToText.isNotListening ? Icons.mic_off : Icons.mic),
            ),
      body: _pathfinder == null ? _buildScannerBody() : _buildGuidanceHub(),
    );
  }

  void _loadDemoMap() {
    if (isProcessing) return;
    processQRCode(kDemoMapJson);
  }

  void _openNavigationDemo() {
    if (_pathfinder == null) return;
    const List<String> pathIds = kDemoRoute;
    final List<String> instructions = [];
    if (pathIds.length >= 2) {
      for (int i = 0; i < pathIds.length - 1; i++) {
        final currentNode = _pathfinder!.nodes[pathIds[i]];
        final nextNode = _pathfinder!.nodes[pathIds[i + 1]];
        if (currentNode != null && nextNode != null) {
          final distance = sqrt(pow(nextNode.x - currentNode.x, 2) + pow(nextNode.y - currentNode.y, 2));
          instructions.add("Walk ${distance.toStringAsFixed(1)} meters to ${nextNode.name}.");
        }
      }
    }
    instructions.add("You have reached your destination.");
    unawaited(_goToNavigation(pathIds, instructions));
  }

  Widget _buildScannerBody() {
    return Stack(
      children: [
        MobileScanner(
          controller: cameraController,
          onDetect: (capture) {
            if (isProcessing) return;
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              processQRCode(barcodes.first.rawValue!);
            }
          },
        ),
        if (!kReleaseMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Developer: load sample map without scanning.",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: isProcessing ? null : _loadDemoMap,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text("Load sample map"),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGuidanceHub() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _isListening
                  ? 'Listening...'
                  : 'Say your destination.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              size: 60,
              color: _isListening ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              _recognizedWords,
              style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic, color: Colors.deepPurple),
              textAlign: TextAlign.center,
            ),
            if (!kReleaseMode) ...[
              const SizedBox(height: 32),
              const Text("Developer: open navigation without voice:",
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openNavigationDemo,
                icon: const Icon(Icons.directions_walk, size: 20),
                label: const Text("Preview navigation UI"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
