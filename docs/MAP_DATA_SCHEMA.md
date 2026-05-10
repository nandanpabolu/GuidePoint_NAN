# Building map JSON schema (“data layer” for GuidePoint)

This project does **not** use a relational database. Venue topology is modeled as JSON consumed by **`AStarPathfinder.fromJson`** in `flutter_app/lib/screens/astar_pathfinding.dart`.

## Top-level shapes

Maps may be scanned from a QR as either:

1. **`{ "building": { … } }`** — canonical graph (see fields below).
2. Same object **plus optional** root keys used by **`qr_scanner_screen.dart`**:
   - **`start_node_id`** (optional `String`) — waypoint id inside `building.floors[0].nodes` when the QR is placed at that node instead of assuming `main_entrance`.

## Required structure

```
building
├── name                     string
└── floors[]                 array (first floor `[0]` is used by Dart parser today)
    ├── floor_number         int
    ├── nodes[]
    │   ├── id               string — unique waypoint id used in routing
    │   ├── name             string — spoken / UI label (“Seminar Hall”)
    │   ├── position[]       [x, y] numbers — planar meters for A* heuristic
    │   └── yolo_landmarks[] optional strings — classifier hint per node
    └── edges[]
        ├── from_id          string
        ├── to_id            string
        └── distance         number — meters/weight connecting the two nodes (undirected in app)
```

## Canonical sample file

- **`data/maps/ATL_JSON.json`** — large multi-node graph (+ Python experimentation assets)
- **`flutter_app/assets/maps/ATL_JSON.json`** — bundled copy consumed by tooling/tests if referenced
- **`tools/scan_atl_qr.html`** — emits a compact 4-node QR for demos

See also root **`README.md`** → Map JSON excerpt.
