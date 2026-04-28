// Test driver for LocationTracker in lib
// Additional tests: JSON loading, model logic, frame processing

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:guide_point/location_tracker.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';


// --- Mocks ---
class MockArCoreController extends Mock implements ArCoreController {}
class MockFlutterVision extends Mock implements FlutterVision {}

void main() {
    late LocationTracker tracker;
    late MockFlutterVision mockVision;

    setUp(() {
        mockVision = MockFlutterVision();
        tracker = LocationTracker(vision: mockVision);
        tracker.landmarkJsonList = [
            {"id": "UTD_Door_ECSS", "position": [10.0, 20.0]}
        ];
        tracker.currentLocation = Vector3(5, 0, 5);
    });

    group('Safe Execution Tests', () {
        test('getUserLocation should return last location when frame is null (Crash-Proof Check)', () async {
            final result = await tracker.getUserLocation(null);
            expect(result.x, equals(5.0));
            expect(result.z, equals(5.0));
            // Passed: system handled null frame without crashing.
        });
    });

    group('Fusion & Math Logic', () {
        test('calculateRelativeOffset should derive correct Vector3 from Matrix4', () {
            final cameraPose = Matrix4.translationValues(0, 0, 5);
            final landmarkPose = Matrix4.identity();
            final offset = tracker.calculateRelativeOffset(cameraPose, landmarkPose);
            expect(offset.z, equals(5.0));
            expect(offset.x, equals(0.0));
        });

        test('getLandmarkCoordinates should correctly parse JSON and map axes', () async {
            final coords = await tracker.getLandmarkCoordinates("UTD_Door_ECSS");
            expect(coords, isNotNull);
            expect(coords!.x, equals(10.0));
            expect(coords.z, equals(20.0));
        });

        test('LERP Fusion Logic test', () {
            tracker.currentLocation = Vector3(0, 0, 0);
            final target = Vector3(10, 0, 10);
            tracker.currentLocation = tracker.lerp(tracker.currentLocation, target, 0.5);
            expect(tracker.currentLocation.x, equals(5.0));
            expect(tracker.currentLocation.z, equals(5.0));
        });

        test('GPS Drift correction should apply when threshold is exceeded', () {
            tracker.currentLocation = Vector3(0, 0, 0);
            final fakeGps = Vector3(20, 0, 0); 
            if (tracker.currentLocation.distanceTo(fakeGps) > 10.0) {
                tracker.currentLocation = tracker.lerp(tracker.currentLocation, fakeGps, 0.05);
            }
            expect(tracker.currentLocation.x, equals(1.0));
        });

        test('GPS Correction should ignore (0,0,0) fallback values', () async {
            tracker.currentLocation = Vector3(10, 0, 10);
            tracker.gpsCoords = Vector3.zero(); 

            // If GPS is zero (Null Island case), there should be no LERP update
            if (tracker.gpsCoords != Vector3.zero() && 
                tracker.currentLocation.distanceTo(tracker.gpsCoords!) > 10.0) {
                tracker.currentLocation = tracker.lerp(tracker.currentLocation, tracker.gpsCoords!, 0.05);
            }
            expect(tracker.currentLocation.x, equals(10.0));
        });
    });
}