import 'dart:math';
import '../screens/astar_pathfinding.dart';

/// Constants for AnchorStep (single place).
class NavConstants {
  static const double waypointThreshold = 2.0;
  static const double cnnConfidenceThreshold = 0.85;
  /// Minimum detector score when matching [Node.yoloLandmarks].
  static const double yoloConfidenceThreshold = 0.38;
  static const double offRouteThreshold = 5.0;
  static const double stepLengthM = 0.7;
  static const int controlLoopMs = 100;
}

/// Estimated position and heading from step count along the route.
class PositionEstimate {
  final double x;
  final double y;
  final double headingDegrees;

  const PositionEstimate({required this.x, required this.y, required this.headingDegrees});
}

/// Step-based position along the current route (AnchorStep).
/// Uses stepCount * stepLength along route segments from [lastConfirmedWaypoint].
class PositionEstimator {
  final AStarPathfinder pathfinder;
  final List<String> route;
  final String lastConfirmedWaypoint;
  final int stepCount;

  PositionEstimator({
    required this.pathfinder,
    required this.route,
    required this.lastConfirmedWaypoint,
    required this.stepCount,
  });

  /// Returns current (x, y) and heading in map coordinates.
  PositionEstimate? estimate() {
    if (route.isEmpty) return null;
    final nodes = pathfinder.nodes;
    final lastIdx = route.indexOf(lastConfirmedWaypoint);
    if (lastIdx < 0 || lastIdx >= route.length) return null;

    double distanceRemaining = stepCount * NavConstants.stepLengthM;
    String currentNodeId = lastConfirmedWaypoint;
    Node? currentNode = nodes[currentNodeId];
    if (currentNode == null) return null;
    Node current = currentNode;

    int idx = lastIdx;
    while (idx + 1 < route.length && distanceRemaining > 0) {
      final nextId = route[idx + 1];
      final nextNode = nodes[nextId];
      if (nextNode == null) break;

      final dx = nextNode.x - current.x;
      final dy = nextNode.y - current.y;
      final segmentLength = sqrt(dx * dx + dy * dy);
      if (segmentLength <= 0) {
        idx++;
        current = nextNode;
        currentNodeId = nextId;
        continue;
      }

      if (distanceRemaining <= segmentLength) {
        final t = distanceRemaining / segmentLength;
        final x = current.x + t * dx;
        final y = current.y + t * dy;
        final headingRad = atan2(dy, dx);
        final headingDeg = headingRad * 180 / pi;
        return PositionEstimate(x: x, y: y, headingDegrees: headingDeg);
      }

      distanceRemaining -= segmentLength;
      idx++;
      current = nextNode;
      currentNodeId = nextId;
    }

    return PositionEstimate(
      x: current.x,
      y: current.y,
      headingDegrees: idx + 1 < route.length
          ? (atan2(
              (nodes[route[idx + 1]]!.y - current.y),
              (nodes[route[idx + 1]]!.x - current.x),
            ) *
            180 /
            pi)
          : 0,
    );
  }
}

/// Distance from point (px, py) to line segment (ax,ay)-(bx,by).
double pointToSegmentDistance(double px, double py, double ax, double ay, double bx, double by) {
  final abx = bx - ax;
  final aby = by - ay;
  final apx = px - ax;
  final apy = py - ay;
  final ab2 = abx * abx + aby * aby;
  if (ab2 <= 0) return sqrt(apx * apx + apy * apy);
  var t = (apx * abx + apy * aby) / ab2;
  t = t.clamp(0.0, 1.0);
  final qx = ax + t * abx;
  final qy = ay + t * aby;
  return sqrt((px - qx) * (px - qx) + (py - qy) * (py - qy));
}
