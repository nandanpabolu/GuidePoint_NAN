import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/step_count_service.dart';
import '../services/position_estimator.dart';
import '../services/scene_classifier.dart';
import '../services/yolo_detector.dart';
import 'astar_pathfinding.dart';
import 'stored_data_screen.dart';

class NavigationScreen extends StatefulWidget {
  final String buildingName;
  final List<String> route;
  final AStarPathfinder pathfinder;
  final List<String> instructions;

  const NavigationScreen({
    super.key,
    required this.buildingName,
    required this.route,
    required this.pathfinder,
    required this.instructions,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final StepCountService _stepService = StepCountService();
  final FlutterTts _tts = FlutterTts();
  Timer? _controlTimer;
  int _stepCount = 0;
  int _currentWaypointIndex = 0;
  String _lastConfirmedWaypoint = '';
  SceneClassifier? _sceneClassifier;
  YoloDetector? _yoloDetector;
  CameraController? _cameraController;
  bool _cameraReady = false;
  DateTime? _lastCueTime;
  bool _isConfirmingWaypoint = false;
  bool _arrived = false;
  String _visionHint = '';

  @override
  void initState() {
    super.initState();
    if (widget.route.isNotEmpty) {
      _lastConfirmedWaypoint = widget.route[0];
    }
    if (widget.route.length < 2) {
      _arrived = true;
      _initTts().then((_) => _tts.speak('You are already at the destination.'));
      return;
    }
    _startNavigationSession();
  }

  Future<void> _startNavigationSession() async {
    await Permission.camera.request();
    if (Platform.isAndroid) {
      await Permission.activityRecognition.request();
    } else if (Platform.isIOS) {
      await Permission.sensors.request();
    }
    if (!mounted) return;
    _stepService.start((steps) {
      if (mounted) setState(() => _stepCount = steps);
    });
    _stepService.setBaselineToNow();
    await _initTts();

    final labelIds = widget.pathfinder.nodes.keys.toList()..sort();
    final scene = SceneClassifier(labelIds: labelIds);
    final yolo = YoloDetector();

    await Future.wait([
      () async {
        if (await scene.load()) {
          if (mounted) setState(() => _sceneClassifier = scene);
        } else {
          scene.close();
        }
      }(),
      () async {
        if (await yolo.load()) {
          if (mounted) setState(() => _yoloDetector = yolo);
        } else {
          yolo.close();
        }
      }(),
    ]);

    if (!mounted) return;
    setState(() {
      _visionHint = _visionStatusLine();
    });

    await _initCamera();
    _controlTimer = Timer.periodic(
      const Duration(milliseconds: NavConstants.controlLoopMs),
      _onControlTick,
    );
  }

  String _visionStatusLine() {
    final hasScene = _sceneClassifier?.isLoaded == true;
    final hasYolo = _yoloDetector?.isLoaded == true;
    if (hasScene && hasYolo) {
      return 'Vision: scene model + indoor object detector active — point the camera while approaching each stop.';
    }
    if (hasYolo) {
      return 'Vision: indoor object detector active — point the camera at doors, pillars, and furniture near each stop.';
    }
    if (hasScene) {
      return 'Vision: scene classifier active.';
    }
    return 'Vision: using step-based proximity only (add TFLite models under assets/models for AI confirmation).';
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: false,
      );
      await controller.initialize();
      if (mounted) {
        setState(() {
          _cameraController = controller;
          _cameraReady = true;
        });
      }
    } catch (_) {}
  }

  void _onControlTick(Timer timer) {
    if (!mounted || _arrived || widget.route.length < 2) return;

    final nextIdx = _currentWaypointIndex + 1;
    if (nextIdx >= widget.route.length) {
      _arrived = true;
      _controlTimer?.cancel();
      _tts.speak('You have reached your destination.');
      return;
    }

    final estimator = PositionEstimator(
      pathfinder: widget.pathfinder,
      route: widget.route,
      lastConfirmedWaypoint: _lastConfirmedWaypoint,
      stepCount: _stepCount,
    );
    final pos = estimator.estimate();
    if (pos == null) return;

    final nextWaypointId = widget.route[nextIdx];
    final nextNode = widget.pathfinder.nodes[nextWaypointId];
    if (nextNode == null) return;

    final distToNext = _euclidean(pos.x, pos.y, nextNode.x, nextNode.y);

    if (_currentWaypointIndex + 1 < widget.route.length) {
      final a = widget.pathfinder.nodes[widget.route[_currentWaypointIndex]]!;
      final b = widget.pathfinder.nodes[widget.route[_currentWaypointIndex + 1]]!;
      final distToSegment = pointToSegmentDistance(pos.x, pos.y, a.x, a.y, b.x, b.y);
      if (distToSegment > NavConstants.offRouteThreshold) {
        _reRoute(pos);
        return;
      }
    }

    if (distToNext < NavConstants.waypointThreshold && !_isConfirmingWaypoint) {
      _tryConfirmWaypoint(nextWaypointId, nextNode.name);
      return;
    }

    final now = DateTime.now();
    if (_lastCueTime == null || now.difference(_lastCueTime!).inSeconds >= 5) {
      _lastCueTime = now;
      _tts.speak('Continue straight, ${distToNext.toStringAsFixed(1)} meters to ${nextNode.name}.');
    }
  }

  Future<void> _tryConfirmWaypoint(String waypointId, String waypointName) async {
    if (_isConfirmingWaypoint) return;
    _isConfirmingWaypoint = true;

    Uint8List? imageBytes;
    if (_cameraReady && _cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final file = await _cameraController!.takePicture();
        imageBytes = await file.readAsBytes();
      } catch (_) {}
    }

    var confirmed = false;

    if (imageBytes != null && _sceneClassifier != null && _sceneClassifier!.isLoaded) {
      final result = await _sceneClassifier!.predict(imageBytes);
      if (result != null &&
          result.locationId == waypointId &&
          result.confidence >= NavConstants.cnnConfidenceThreshold) {
        confirmed = true;
        if (mounted) {
          setState(() {
            _visionHint = 'Scene match: $waypointId (${(result.confidence * 100).round()}%)';
          });
        }
      }
    }

    if (!confirmed &&
        imageBytes != null &&
        _yoloDetector != null &&
        _yoloDetector!.isLoaded) {
      final dets = await _yoloDetector!.detect(
        imageBytes,
        confThreshold: NavConstants.yoloConfidenceThreshold,
      );
      final node = widget.pathfinder.nodes[waypointId];
      if (mounted) {
        setState(() {
          _visionHint = dets.isEmpty
              ? 'Detector: no objects — aim at doors, signage, or furniture.'
              : 'Detector: ${dets.map((e) => '${e.className} ${(e.score * 100).round()}%').take(5).join(' · ')}';
        });
      }
      if (node != null &&
          _yoloDetector!.matchesWaypoint(
            dets,
            node,
            minConfidence: NavConstants.yoloConfidenceThreshold,
          )) {
        confirmed = true;
      }
    }

    final hasAnyVision =
        (_sceneClassifier?.isLoaded == true) || (_yoloDetector?.isLoaded == true);
    if (!confirmed && !hasAnyVision) {
      confirmed = true;
      if (mounted) {
        setState(() {
          _visionHint = 'No AI models loaded — confirmed stop from step proximity only.';
        });
      }
    }

    if (confirmed) {
      if (!mounted) return;
      setState(() {
        _lastConfirmedWaypoint = waypointId;
        _currentWaypointIndex++;
        _stepService.reset();
      });
      _tts.speak('You have reached $waypointName.');
      final nextIdx = _currentWaypointIndex + 1;
      if (nextIdx >= widget.route.length) {
        _arrived = true;
        _controlTimer?.cancel();
        _tts.speak('You have reached your destination.');
      } else {
        final nextNode = widget.pathfinder.nodes[widget.route[nextIdx]];
        if (nextNode != null) {
          _tts.speak('Walk to ${nextNode.name}.');
        }
      }
    }

    if (mounted) _isConfirmingWaypoint = false;
  }

  void _reRoute(PositionEstimate pos) {
    final targetId = widget.route.last;
    double minDist = double.infinity;
    String? nearestId;
    for (final entry in widget.pathfinder.nodes.entries) {
      final d = _euclidean(pos.x, pos.y, entry.value.x, entry.value.y);
      if (d < minDist) {
        minDist = d;
        nearestId = entry.key;
      }
    }
    if (nearestId == null) return;
    final newRoute = widget.pathfinder.findPath(nearestId, targetId);
    if (newRoute.isEmpty) return;
    _controlTimer?.cancel();
    _tts.speak('Recalculating route.');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          buildingName: widget.buildingName,
          route: newRoute,
          pathfinder: widget.pathfinder,
          instructions: widget.instructions,
        ),
      ),
    );
  }

  double _euclidean(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return sqrt(dx * dx + dy * dy);
  }

  @override
  void dispose() {
    _controlTimer?.cancel();
    _stepService.dispose();
    _tts.stop();
    _sceneClassifier?.close();
    _yoloDetector?.close();
    _cameraController?.dispose();
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
            icon: const Icon(Icons.list),
            tooltip: 'View instructions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StoredDataScreen(
                    buildingName: widget.buildingName,
                    instructions: widget.instructions,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _cameraReady &&
                        _cameraController != null &&
                        _cameraController!.value.isInitialized
                    ? ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio:
                                1 / _cameraController!.value.aspectRatio,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      )
                    : ColoredBox(
                        color: Colors.black26,
                        child: Center(
                          child: Text(
                            _cameraReady ? 'Camera unavailable' : 'Starting camera…',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _visionHint,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Text(
                    'Waypoint ${_currentWaypointIndex + 1} of ${widget.route.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Steps: $_stepCount',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (widget.route.isNotEmpty &&
                      _currentWaypointIndex + 1 < widget.route.length)
                    Text(
                      'Next: ${widget.pathfinder.nodes[widget.route[_currentWaypointIndex + 1]]?.name ?? "—"}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Hold the phone so the live view shows the corridor or landmark ahead. '
                    'When you are close enough, the app captures a frame to verify the stop '
                    '(scene model and/or indoor object detector).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
