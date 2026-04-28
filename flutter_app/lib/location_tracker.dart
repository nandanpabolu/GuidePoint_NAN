/* 
    GuidePoint Location Tracker

    This class implements a multi-sensor fusion approach to estimate the user's location in an indoor environment using:
    - VSLAM (Visual Simultaneous Localization and Mapping) from ARCore for real-time camera-based tracking
    - IMU (Inertial Measurement Unit) data from the device's accelerometer to estimate movement based on steps
    - GPS as a sanity check for large drifts (only if GPS is valid indoors, which is rare)
    - Landmark recognition using a custom YOLOv8 model to correct drift when known landmarks are detected

    Tunable Hyperparameters:
    - stridelength: based on user height or average stride length for better step-based movement estimation
    - gpsDriftThreshold: should be current GPS indoor accuracy limit + buffer
    - landmarkWeight: should be relatively high (landmark coordinates are absolute)
    - gpsTrustThreshold: should be relatively low (based on GPS indoor accuracy)
*/

import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter_vision/flutter_vision.dart';

class LocationTracker {
    Vector3 currentLocation = Vector3.zero();

    Vector3? gpsCoords;
    StreamSubscription? stepSub;
    Timer? gpsTimer;
    List<Map<String, dynamic>> landmarkJsonList = []; 
    final FlutterVision vision; 
    DateTime _lastInferenceTime = DateTime.now();

    int totalSteps = 0;
    int lastStepCount = 0;
    static const double strideLength = 0.75; // average stride length in meters

    static const double vslamWeight = 0.8; // in relation to IMU data
    static const double landmarkWeight = 0.5; // in relation to VSLAM/IMU, used in LERP
    static const double gpsTrustThreshold = 0.05; // low interpolation factor, small drift correction
    static const double gpsDriftThreshold = 10.0; // in meters - if current estimate is this far from GPS, we consider GPS for correction

    LocationTracker({FlutterVision? vision}) : vision = vision ?? FlutterVision();

    /* *** MAIN METHODS *** */

    // Call this when ARCore is initialized to start tracking
    // Note: driver needs to initialize the ArCoreView and call getUserLocation on each frame update, passing the camera frame data
    void start(ArCoreController arController) async {

        // Initialize JSON & ML model
        await loadJSONData();
        await loadModel();

        // Start GPS tracking
        gpsTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
            try {
                gpsCoords = await getGPSCoordinates();
            } catch (_) {}
        });

        // Start IMU Listening
        stepSub = userAccelerometerEventStream().listen((event) {
            // Use Euclidean norm (magnitude of a vector) to detect steps
            double magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
            if (magnitude > 12.0) totalSteps++;
        });
    }

    // Call this to stop tracking and clean up resources
    Future<void> stop() async {
        gpsTimer?.cancel();
        stepSub?.cancel();
        await vision.closeYoloModel();
    }

    // Returns user's current location as [longitude, altitude, latitude]
    Future<Vector3> getUserLocation(dynamic cameraFrame) async {

        // Returns previous location if camera frame fails
        if (cameraFrame == null) return currentLocation;

        try { 
            // Get IMU step count since last snapshot
            double movementFromSteps = (totalSteps - lastStepCount) * strideLength;
            lastStepCount = totalSteps;

            // Get VSLAM coordinates from ARCore
            final pose = cameraFrame.camera?.displayOrientedPose;
            Vector3 vslamCoords = pose.getTranslation();
            currentLocation.x = vslamCoords.x;
            currentLocation.y = vslamCoords.y;

            // Merge IMU & VSLAM data with weights
            currentLocation.z = (vslamCoords.z * vslamWeight) + (movementFromSteps * (1.0 - vslamWeight));

            // Get relative landmark coordinates if available
            if (cameraFrame != null && landmarkJsonList.isNotEmpty) {

                // Get model prediction every 1 second to prevent overload
                if (DateTime.now().difference(_lastInferenceTime).inMilliseconds > 1000) {
                    _lastInferenceTime = DateTime.now();
                    List<Map<String, dynamic>> results = await predict(cameraFrame);

                    for (var detection in results) {
                        Vector3? landmarkCoords = await getLandmarkCoordinates(detection['tag']);

                        if (landmarkCoords != null) {
                            Matrix4? landmarkPose = await getLandmarkPose(detection['box'], cameraFrame);
                            Matrix4? cameraPose = cameraFrame.camera?.displayOrientedPose;
                            
                            if (landmarkPose != null && cameraPose != null) {
                                Vector3 relativeOffset = calculateRelativeOffset(cameraPose, landmarkPose);
                                Vector3 relativeLandmarkCoords = landmarkCoords + relativeOffset;
                                currentLocation = lerp(currentLocation, relativeLandmarkCoords, landmarkWeight);
                            }
                        }
                    }
                }
            }

            // Get GPS estimate for sanity check (only if GPS is valid and we have drifted)
            if (gpsCoords != null && gpsCoords != Vector3.zero()) {
                if (currentLocation.distanceTo(gpsCoords!) > gpsDriftThreshold) {
                    currentLocation = lerp(currentLocation, gpsCoords!, gpsTrustThreshold);
                }
            }

            return currentLocation;

        } catch (e) {
            // If anything fails, return the state from the previous frame
            return currentLocation; 
        }
    }

    /* *** HELPERS *** */

    Future<void> loadJSONData() async {
        final String response =
            await rootBundle.loadString('assets/maps/ATL_JSON.json');
        final dynamic decoded = jsonDecode(response);
        if (decoded is List<dynamic>) {
            landmarkJsonList = decoded.cast<Map<String, dynamic>>();
            return;
        }
        if (decoded is Map<String, dynamic>) {
            final building = decoded['building'];
            final floors = building != null && building is Map<String, dynamic>
                ? building['floors']
                : decoded['floors'];
            if (floors is List && floors.isNotEmpty) {
                final first = floors.first;
                if (first is Map<String, dynamic>) {
                    final nodes = first['nodes'];
                    if (nodes is List<dynamic>) {
                        landmarkJsonList = nodes.cast<Map<String, dynamic>>();
                        return;
                    }
                }
            }
        }
        landmarkJsonList = [];
    }

    Future<void> loadModel() async {
        await vision.loadYoloModel(
            modelPath: 'assets/models/yolo_detector.tflite',
            labels: 'assets/models/labels.txt',
            modelVersion: "yolov8",
            quantization: false,
            numThreads: 1,
            useGpu: false,
        );
    }

    Future<List<Map<String, dynamic>>> predict(dynamic cameraFrame) async {
        return await vision.yoloOnFrame(
            bytesList: cameraFrame.planes.map((plane) => plane.bytes as Uint8List).toList(),
            imageHeight: cameraFrame.height,
            imageWidth: cameraFrame.width,
        );
    }

    Future<Vector3> getGPSCoordinates() async {
        try {
            // Check for services and permissions
            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
            if (!serviceEnabled) {
                return Vector3.zero();
            }

            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
                permission = await Geolocator.requestPermission();
                if (permission == LocationPermission.denied || 
                    permission == LocationPermission.deniedForever) {
                return Vector3.zero(); 
                }
            }

            // Get position with a timeout to prevent hanging
            Position position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 5), 
            );

            return Vector3(position.longitude, position.altitude, position.latitude);

        } catch (e) {
            return Vector3.zero(); // fallback
        }
    }

    // Returns the camera pose of a detected landmark
    Future<Matrix4?> getLandmarkPose(List<dynamic> box, dynamic cameraFrame) async {
        double centerX = (box[0] + box[2]) / 2;
        double centerY = (box[1] + box[3]) / 2;

        List<ArCoreHitTestResult> hitResults = await cameraFrame.hitTest(centerX, centerY);

        if (hitResults.isNotEmpty) {
            return Matrix4.translation(hitResults.first.pose.translation);
        }
        return null;
    }

    // Returns a detected landmark's coordinates
    Future<Vector3?> getLandmarkCoordinates(String landmarkTag) async {
        try {
            var landmarkData = landmarkJsonList.firstWhere(
            (item) => item['id'] == landmarkTag,
            );
            return Vector3(landmarkData['position'][0].toDouble(), 0, landmarkData['position'][1].toDouble());
        } catch (_) {
            return null;
        }
    }

    // Returns the camera's relative postion to a landmark
    Vector3 calculateRelativeOffset(Matrix4 cameraPose, Matrix4 landmarkPose) {
        Matrix4 landmarkInverse = Matrix4.inverted(landmarkPose);   // set landmark as origin
        Matrix4 relativeMatrix = landmarkInverse * cameraPose;
        return relativeMatrix.getTranslation();
    }

    // Returns global VSLAM coordinates based on local pose and anchor coordinates    
    // Unused for now since landmark global coordinates are not given    
    Vector3 getVSLAMGlobalCoordinates(Matrix4 localPose, double anchorLat, double anchorLon) {
        const double earthRadius = 6378137.0;
        Vector3 localPoseCoords = localPose.getTranslation();
        double offsetLat = localPoseCoords.z / earthRadius;
        double offsetLon = localPoseCoords.x / (earthRadius * math.cos(math.pi * anchorLat / 180));

        double newLat = anchorLat + (offsetLat * (180 / math.pi));
        double newLon = anchorLon + (offsetLon * (180 / math.pi));

        return Vector3(newLon, 0, newLat);
    }

    // Use LERP to merge estimates and correct drift
    // LERP: Linear Interpolation - https://en.wikipedia.org/wiki/Linear_interpolation
    // LERP is a smoother transition than plain averaging
    // Result = Prediction1 + (Predition2 - Prediction1) * InterpolationFactor
    Vector3 lerp(Vector3 start, Vector3 end, double t) {
        return start + (end - start) * t;
    }
}