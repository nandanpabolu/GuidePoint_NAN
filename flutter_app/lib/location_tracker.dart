/* Integration Notes

Remember to tune hyperparameters:
    - stridelength can be tuned based on user height or average stride length for better step-based movement estimation
    - gpsDriftThreshold: should be current GPS indoor accuracy limit + buffer
    - landmarkTrustThreshold: should be relatively high (landmark coordinates are absolute)
    - gpsTrustThreshold: should be relatively low (based on GPS indoor accuracy)

Dependency Notes:
    - Android API should be compatible with all SDK versions  
*/

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter_vision/flutter_vision.dart';

class LocationTracker {
    Vector3 currentLocation; // [longitude, altitude, latitude]

    Vector3? gpsCoords;
    StreamSubscription? stepSub;
    Timer? gpsTimer;
    List<Map<String, dynamic>> landmarkJsonList;
    FlutterVision vision;
    List<Map<String, dynamic>> landmarkJsonList;
    DateTime _lastInferenceTime = DateTime.now();

    int totalSteps = 0;
    int lastStepCount;
    const int strideLength = 0.75; // Average stride length in meters

    const double gpsDriftThreshold = 10.0; // Meters - if current estimate is this far from GPS, we consider GPS for correction
    const double landmarkTrustThreshold = 0.5; // Hyperparameter: how much to trust landmark estimate vs VSLAM/IMU, used in LERP
    const double gpsTrustThreshold = 0.05; // Hyperparameter: low interpolation factor, small drift correction

    /* *** MAIN METHODS *** */

    // Call this when ARCore is initialized to start tracking
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
        stepSub = stepCountEvents.listen((event) {
        totalSteps = event.steps;
        });

        // Bind to the ARCore Frame Update
        arController.onTrackingUpdate = (cameraFrame) {
        getUserLocation(cameraFrame);
        };
    }

    // Call this to stop tracking and clean up resources
    void stop() {
        gpsTimer?.cancel();
        stepSub?.cancel();
        await vision.closeYoloModel();
    }

    // Returns user's current location as [longitude, altitude, latitude]
    Vector3 getUserLocation(dynamic cameraFrame) {
        
        // Get IMU step count since last snapshot
        double movementFromSteps = (totalSteps - lastStepCount) * strideLength;
        lastStepCount = totalSteps;

        // Get coordinate estimate from VSLAM & step count, using weights
        Vector3 vslamCoords = cameraFrame.camera.displayOrientedPose.getTranslation();
        if (vslamCoords == null) {
            vslamCoords = Vector3.zero(); // Default to zero if no VSLAM data available
        }
        double vslamWeight = 0.8;   // Hyperparameter, can be tuned based on testing
        currentLocation.x = vslamCoords.x;
        currentLocation.y = vslamCoords.y;
        currentLocation.z = (vslamCoords.z * vslamWeight) + (movementFromSteps * (1.0 - vslamWeight));

        // Get relative landmark coordinates if available
        Vector3 landmarkCoords;
        if (cameraFrame != null && landmarkJsonList.isNotEmpty) {
            
            // Run ML Model every 1 second
            List<Map<String, dynamic>> results;
            if (DateTime.now().difference(_lastInferenceTime).inMilliseconds > 1000) {
                _lastInferenceTime = DateTime.now();            
                results = await predict(cameraFrame); 
            }
            for (var detection in results) {
                landmarkCoords = getLandmarkCoordinates(detection['tag']);

                if (landmarkCoords != null) {
                    Matrix4 landmarkPose = getLandmarkPose(detection['box']);
                    Matrix4 cameraPose = cameraFrame.camera.displayOrientedPose;
                    if (landmarkPose != null && cameraPose != null) {
                        // Calculate relative offset from camera to landmark
                        Vector3 relativeOffset = calculateRelativeOffset(cameraPose, landmarkPose);
                        Vector3 relativeLandmarkCoords = landmarkCoords + relativeOffset;

                        // Use LERP to merge VSLAM/IMU prediction and landmark prediction
                        // LERP: Linear Interpolation - https://en.wikipedia.org/wiki/Linear_interpolation
                        // LERP is a smoother transition than plain averaging
                        // Result = Prediction1 + (Predition2 - Prediction1) * InterpolationFactor
                        currentLocation = Vector3.lerp(currentLocation, relativeLandmarkCoords, landmarkTrustThreshold);
                    }
                } 
            }
        }
        
        // Get GPS estimate for sanity check
        if (landmarkCoords == null && gpsCoords != null) {
            if (gpsCoords != null && currentLocation.distanceTo(gpsCoords) > gpsDriftThreshold) {
                currentLocation = Vector3.lerp(currentLocation, gpsCoords, gpsTrustThreshold); 
            }
        }

        return currentLocation;
    }

    /* *** HELPERS *** */

    Future<void> loadJSONData() async {
        String response = await rootBundle.loadString('assets/maps/ATL_JSON.json');
        List<dynamic> data = jsonDecode(response);    
        landmarkJsonList = data.cast<Map<String, dynamic>>();   
    }

    Future<void> loadModel() async {
        await vision.loadYoloModel(
        modelPath: 'assets/models/yolo_detector.tflite',
        labels: 'assets/models/labels.txt', // You need a text file with your class names
        modelVersion: "yolov8",
        quantization: false,
        numThreads: 1,
        useGpu: false,
        );
    }

    Future<List<Map<String, dynamic>>> predict(dynamic cameraFrame) async {
        // Note: cameraFrame usually needs to be converted to bytes for TFLite
        result = await vision.yoloOnFrame(
        bytesList: cameraFrame.planes.map((plane) => plane.bytes).toList(),
        imageHeight: cameraFrame.height,
        imageWidth: cameraFrame.width,
        );
        
        return result; 
    }

    // Returns GPS coordinates as a vector [latitude, attitude, longitude]
    Future<Vector3> getGPSCoordinates() async {
        bool serviceEnabled;
        LocationPermission permission;

        // Check if location services are enabled
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) { 
            return Vector3(0, 0, 0);
        }

        // Handle permissions
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied) {
                return Vector3(0, 0, 0);
            }
        }
        if (permission == LocationPermission.deniedForever) {
            return Vector3(0, 0, 0);
        } 

        // Fetch current position
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high
        );
        return Vector3(position.longitude, position.altitude, position.latitude);
    }

    // Returns the camera pose of a detected landmark
    Matrix4 getLandmarkPose(List<dynamic> box) async {
        double x1 = box[0];
        double y1 = box[1];
        double x2 = box[2];
        double y2 = box[3];

        double centerX = (x1 + x2) / 2;
        double centerY = (y1 + y2) / 2;
        List<HitTestResult> hitResults = await frame.hitTest(centerX, centerY);

        if (hitResults.isNotEmpty) {
            HitTestResult closestHit = hitResults.first;    // the first result is usually the most accurate 
            landmarkPose = closestHit.pose;
        }
        return landmarkPose;
    }

    // Returns a detected landmark's coordinates
    Vector3 getLandmarkCoordinates(String landmarkTag) async {
        if (landmarkTag != null) {
        var landmarkData = landmarkJsonList.firstWhere(
            (item) => item['id'] == landmarkTag,
            orElse: () => {},
        );

        if (landmarkData.isNotEmpty) {
            return Vector3(
            landmarkData['position'][0].toDouble(), 
            0, // attitude not taken into account
            landmarkData['position'][1].toDouble()
            );
        }
        }
        return null; // Return null if no landmark is detected or found in JSON
    }

    // Returns the camera's relative postion to a landmark
    Vector3 calculateRelativeOffset(Matrix4 cameraPose, Matrix4 landmarkPose) {
        // Invert the Landmark Pose
        // This turns the landmark into the (0,0,0) center of the universe
        Matrix4 landmarkInverse = Matrix4.inverted(landmarkPose);

        // Multiply by the Camera Pose
        // This calculates where the camera is from the landmark's perspective
        Matrix4 relativeMatrix = landmarkInverse * cameraPose;

        return relativeMatrix.getTranslation(); // returns a Vector3 of (x,y,z) in meters
    }

    // Returns global VSLAM coordinates as a vector [latitude, longitude] 
    // based on local pose and anchor coordinates    
    // Unused for now since landmark global coordinates are not given
    Vector3 getVSLAMGlobalCoordinates(Matrix4 localPose, double anchorLat, double anchorLon) {
        const double earthRadius = 6378137.0;

        // ARCore 'x' is East/West, 'y' is up/down, 'z' is North/South (all meters)
        Vector3 localPoseCoords = localPose.getTranslation();
        double offsetLat = localPoseCoords.z / earthRadius;
        double offsetLon = localPoseCoords.x / (earthRadius * Math.cos(Math.PI * anchorLat / 180));

        // Convert offsets from radians to degrees
        double newLat = anchorLat + (offsetLat * (180 / Math.PI));
        double newLon = anchorLon + (offsetLon * (180 / Math.PI));

        return Vector3(newLon, 0, newLat);
    }

}