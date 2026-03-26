import 'dart:math';
import 'package:collection/collection.dart';

// 1. DATA MODELS
class Node {
  final String id;
  final String name;
  final double x;
  final double y;

  /// YOLO class names (from indoor model) that may appear at this waypoint — see map JSON `yolo_landmarks`.
  final List<String> yoloLandmarks;

  // Properties for A* calculation
  double gCost = 0; // Distance from start
  double hCost = 0; // Distance to end (heuristic)
  Node? parent;     // To retrace the path

  double get fCost => gCost + hCost; // Total cost

  Node({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.yoloLandmarks = const [],
  });
}

class Edge {
  final String fromId;
  final String toId;
  final double weight;

  Edge({required this.fromId, required this.toId, required this.weight});
}

// Add a small helper heuristic that uses sqrt (from dart:math)
double euclideanDistance(Node a, Node b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return sqrt(dx * dx + dy * dy);
}

// 2. THE A* ALGORITHM CLASS
class AStarPathfinder {
  final Map<String, Node> nodes = {};
  final List<Edge> edges = [];

  // Constructor parses your JSON data immediately
  AStarPathfinder.fromJson(Map<String, dynamic> jsonGraph) {
    _parseGraph(jsonGraph);
  }

  void _parseGraph(Map<String, dynamic> json) {
    // Adjust these keys based on your actual JSON structure
    // We assume the first floor for this implementation
    final floor = json['building']['floors'][0]; 
    
    // Parse Nodes
    for (var nodeData in floor['nodes']) {
      final lm = (nodeData['yolo_landmarks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      nodes[nodeData['id']] = Node(
        id: nodeData['id'],
        name: nodeData['name'],
        x: (nodeData['position'][0] as num).toDouble(),
        y: (nodeData['position'][1] as num).toDouble(),
        yoloLandmarks: lm,
      );
    }

    // Parse Edges
    for (var edgeData in floor['edges']) {
      edges.add(Edge(
        fromId: edgeData['from_id'],
        toId: edgeData['to_id'],
        weight: (edgeData['distance'] as num).toDouble(),
      ));
    }
  }

  // Heuristic Function (Manhattan Distance as per your Python code)
  // Note: You can swap this for Euclidean (sqrt) if you want "as the crow flies" distance.
  double _getHeuristic(Node a, Node b) {
    return (a.x - b.x).abs() + (a.y - b.y).abs();
  }

  // Get neighbors for a specific node
  List<String> _getNeighbors(String nodeId) {
    List<String> neighbors = [];
    for (var edge in edges) {
      if (edge.fromId == nodeId) neighbors.add(edge.toId);
      if (edge.toId == nodeId) neighbors.add(edge.fromId); // Assuming 2-way paths
    }
    return neighbors;
  }

  // Get distance between two directly connected nodes
  double _getDistance(String nodeA, String nodeB) {
    var edge = edges.firstWhere(
      (e) => (e.fromId == nodeA && e.toId == nodeB) || 
             (e.fromId == nodeB && e.toId == nodeA)
    );
    return edge.weight;
  }

  // THE SEARCH FUNCTION
  List<String> findPath(String startId, String endId) {
    // Reset node states
    for (var node in nodes.values) {
      node.gCost = double.infinity;
      node.hCost = 0;
      node.parent = null;
    }

    Node? startNode = nodes[startId];
    Node? endNode = nodes[endId];

    if (startNode == null || endNode == null) return [];

    // Open Set (Priority Queue based on fCost)
    PriorityQueue<Node> openSet = PriorityQueue((a, b) => a.fCost.compareTo(b.fCost));
    Set<String> closedSet = {};

    startNode.gCost = 0;
    startNode.hCost = _getHeuristic(startNode, endNode);
    openSet.add(startNode);

    while (openSet.isNotEmpty) {
      Node current = openSet.removeFirst();

      if (current.id == endId) {
        return _retracePath(startNode, current);
      }

      closedSet.add(current.id);

      for (String neighborId in _getNeighbors(current.id)) {
        if (closedSet.contains(neighborId)) continue;

        Node neighbor = nodes[neighborId]!;
        double newMovementCost = current.gCost + _getDistance(current.id, neighbor.id);

        if (newMovementCost < neighbor.gCost) {
          neighbor.gCost = newMovementCost;
          neighbor.hCost = _getHeuristic(neighbor, endNode);
          neighbor.parent = current;

          // If neighbor is not in openSet, add it. 
          // Note: PriorityQueue doesn't have a fast 'contains', but usually A* // simply adds it. For optimization, we can check if it's already there,
          // but simpler logic works fine for small graphs.
          openSet.add(neighbor); 
        }
      }
    }

    return []; // No path found
  }

  List<String> _retracePath(Node startNode, Node endNode) {
    List<String> path = [];
    Node? currentNode = endNode;

    while (currentNode != null) {
      path.add(currentNode.id);
      currentNode = currentNode.parent;
    }
    
    return path.reversed.toList();
  }
}