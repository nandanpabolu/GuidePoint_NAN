import 'dart:async';
import 'package:pedometer/pedometer.dart';

/// Provides step count since last reset (e.g. since navigation started).
/// Used by AnchorStep position estimator.
class StepCountService {
  StreamSubscription<StepCount>? _subscription;
  int _stepsAtReset = 0;
  int _latestSteps = 0;
  bool _started = false;
  bool _baselineSet = false;

  /// Steps since last [reset].
  int get stepCountSinceStart {
    if (!_started) return 0;
    final since = _latestSteps - _stepsAtReset;
    return since > 0 ? since : 0;
  }

  /// Start listening to the pedometer. Call from navigation start.
  void start(void Function(int stepCountSinceStart)? onUpdate) {
    if (_started) return;
    _started = true;
    _subscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        _latestSteps = event.steps;
        if (!_baselineSet) {
          _stepsAtReset = event.steps;
          _baselineSet = true;
        }
        onUpdate?.call(stepCountSinceStart);
      },
      onError: (Object e) {
        // Log; some devices don't support step counter
        assert(() {
          // ignore: avoid_print
          print('StepCountService error: $e');
          return true;
        }());
      },
    );
  }

  /// Reset baseline so stepCountSinceStart becomes 0 (e.g. at waypoint confirm).
  void reset() {
    _stepsAtReset = _latestSteps;
  }

  /// Set baseline to current device step count (call when starting a navigation session).
  void setBaselineToNow() {
    _stepsAtReset = _latestSteps;
    _baselineSet = true;
  }

  /// Stop listening.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
