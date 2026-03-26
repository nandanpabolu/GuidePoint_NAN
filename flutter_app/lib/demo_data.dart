/// Sample building map for non-release debug/profile builds only (`Load sample map`).
const String kDemoMapJson = '''
{
  "building": {
    "name": "ATL",
    "floors": [
      {
        "floor_number": 1,
        "nodes": [
          {"id": "main_entrance", "name": "Main Entrance", "position": [0, 0], "yolo_landmarks": ["Door", "Doorway", "Lighting"]},
          {"id": "junction_1", "name": "Hallway Junction", "position": [0, 3], "yolo_landmarks": ["Pillar", "Lighting", "Doorway", "Poster"]},
          {"id": "seminar_hall", "name": "Seminar Hall", "position": [4, 3], "yolo_landmarks": ["Chair", "Table", "Board", "Lighting"]},
          {"id": "idea_labs", "name": "Idea Labs", "position": [-2, 3], "yolo_landmarks": ["Cubicle", "Chair", "Table", "Window"]}
        ],
        "edges": [
          {"from_id": "main_entrance", "to_id": "junction_1", "distance": 3},
          {"from_id": "junction_1", "to_id": "seminar_hall", "distance": 4},
          {"from_id": "junction_1", "to_id": "idea_labs", "distance": 2}
        ]
      }
    ]
  }
}
''';

/// Precomputed route for debug/profile “Preview navigation UI” (Main Entrance → Seminar Hall).
const List<String> kDemoRoute = ['main_entrance', 'junction_1', 'seminar_hall'];
