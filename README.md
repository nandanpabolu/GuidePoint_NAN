# GuidePoint (GuidePoint_NAN)

**Assistive indoor navigation** using **QR-encoded building graphs**, **voice destination entry**, **A\*** routing, **spoken guidance**, **step sensing**, and **optional on-device vision (YOLO / scene classifier TFLite)**.

Joint initiative: **B.V. Raju Institute of Technology (BVRIT), India** and **The University of Texas at Dallas (UTD)** — developed under **UTDesign EPICS**.

---

## Semester checklist & handoff (#180 parity)

Compliance matrix + GitHub Wiki copy instructions live in **`docs/SUBMISSION_CHECKLIST_ISSUE_180.md`** and **`docs/handoff/WIKI_EXPORT_README.md`**.

---

## Conceptual overview

Many indoor spaces lack universally accessible **turn-by-turn** guidance analogous to GPS. GuidePoint distributes **digital floor graphs** embedded in QR codes (or reachable via HTTPS), then merges **heard intent** (“Seminar hall”) → **planned path** → **live navigation UI** emphasizing **hands-free cues**.

### User / partner roles

| Role | Responsibility |
|------|----------------|
| **End traveler** | Scans QR, speaks destination, follows instructions & permissions UX. |
| **Facilities partner** | Authors / hosts JSON graphs, prints laminated QR rollout assets. |
| **Developer / researcher** | Maintains Flutter build, swaps TFLite models, retrains detectors in Python. |

---

## Functional requirements (screen-level)

Routes defined in **`flutter_app/lib/main.dart`** (`/` Terms, `/scanner` hub).

### `TermsScreen` (`terms_screen.dart`)

- Displays legal / scope copy; persists acceptance **`SharedPreferences: terms_accepted`**.
- On accept navigates replacement → **`QRScannerScreen`**.

### `QRScannerScreen` (`qr_scanner_screen.dart`)

- Initializes camera via **`mobile_scanner`** (+ mic permission scaffolding for STT downstream).
- **QR payload semantics**
  - **Inline JSON** matching **`docs/MAP_DATA_SCHEMA.md`**, OR
  - Absolute **HTTPS URL** returning same JSON (**`package:http`** `GET`).
- Parses graph into **`AStarPathfinder`**; optional root **`start_node_id`** selects non-default waypoint start.
- **Speech capture** (**`speech_to_text`**) after map load; substring match over node **`name`** for destination inference.
- **Debug-only overlays** (omit in **`flutter build --release`** consumer drops): Quick **Load sample map** + navigation preview leveraging constants in **`demo_data.dart`**.

### `NavigationScreen` (`navigation_screen.dart`)

- Owns **`CameraController`** previews for confirmation snaps.
- **TTS cues** (**`flutter_tts`**) spaced to reduce chatter storms.
- **Step counting** (**`StepCountService` + `pedometer`**) biases coarse progress between nodes when vision cues weak.
- **TensorFlow Lite** (`tflite_flutter` + `image`): optional **`scene_classifier.tflite`**; **`yolo_detector.tflite`** supports indoor cues aligned via node **`yolo_landmarks`**.
- **Waypoint confirmation** combines proximity thresholds + classifier confidence when loaded.

### `StoredDataScreen` (`stored_data_screen.dart`)

Shows ordered textual instructions surfaced from routed path generation (replay / inspection).

### Auxiliary logic

| Module | Responsibility |
|--------|----------------|
| **`astar_pathfinding.dart`** | JSON ingest + heuristic A* planner |
| **`services/step_count_service.dart`** | Streams step deltas |
| **`services/position_estimator.dart`** | Fuses steps into interim coordinates |
| **`services/scene_classifier.dart`** | Optional CNN logits → node id hypothesis |
| **`services/yolo_detector.dart`** | YOLOv8 TFLite decode + waypoint overlap heuristic |

---

## Third-party integrations (packages & rationale)

| Package | Responsibility |
|---------|----------------|
| **`mobile_scanner`** | Decode QR payloads with device camera |
| **`http`** | Optional remote JSON map fetch |
| **`speech_to_text` / `flutter_tts`** | Voice UX loop |
| **`shared_preferences`** | Persist ToS flag + last QR payload snippet |
| **`permission_handler`** | Runtime permission orchestration |
| **`pedometer`** | Indoor distance proxy fallback |
| **`camera`**, **`image`**, **`tflite_flutter`** | Vision confirmation loop |

_No Auth0 / Stripe / SaaS billing integrations in-scope today._

---

## Tech stack snapshot

**Client:** Flutter 3 · Dart (**`flutter_app/`**)  
**On-device ML:** TensorFlow Lite (YOLO bundled; scene head optional file drop)  
**Offline batch tooling:** Python 3 · NumPy · TensorFlow · Ultralytics (**`requirements.txt`**)  

**Persistence model:** Portable JSON (**no Postgres/MySQL OLTP**) — canonical schema textualized in **`docs/MAP_DATA_SCHEMA.md`**.

Model training runs & checkpoints: **`models/runs/train/guidepoint/`** · helper script **`models/runGuidePoint.py`**.

---

## Database, Docker & environment variables

### Relational DB / Prisma / `schema.sql`

**Not used.** If future teams bolt on org-wide CMS, introduce **explicit SQL / Prisma migrations** beside this readme.

### `docker-compose.yml`

**Not used** — GuidePoint ships as a **Flutter mobile client** plus optional CDN JSON; there is no compose-managed database tier to start. Documented here intentionally for syllabus transparency.

### `.env.example`

Template at repo root shows **future** centralized map URL / hypothetical API secrets using placeholder strings (course guidance: **`EXAMPLE_*`**). Runtime Android signing stays in **`flutter_app/android/key.properties`** (gitignored via **`.gitignore`**).

---

## Deployment & migrations

Production path = signed **mobile bundles** (**Play App Bundles**, **IPA**). Partner-run servers optional for JSON hosting — not prerequisite.

**Migrating CAD / spreadsheet → JSON graph** remains manual authoring / tooling TBD — no scripted ETL bundled.

Release signing scaffolding: **`flutter_app/android/key.properties.example`**.

---

## Repository layout

```
GuidePoint_NAN/
├── CHANGELOG.md
├── LICENSE                    # MIT
├── README.md
├── .env.example
├── requirements.txt           # Python / ML toolchain
├── figma/README.md           # Screenshots / Figma link placeholders
├── scripts/                  # Dev shell helpers (+ README inside)
├── tools/scan_atl_qr.html
├── data/maps/               # ATL_JSON + Python nav utilities + PNG graph renders
├── docs/                     # Includes Issue #180 checklist + Wiki export Markdown
├── models/
│   ├── runGuidePoint.py
│   └── runs/…                # Weights / eval plots
├── navigation/README.md     # Empty slot explained (future dart shared routing)
├── flutter_app/              # Flutter project (PRIMARY SHIPPABLE SURFACE)
│   ├── lib/main.dart demo_data.dart screens/ services/
│   └── assets/models maps Icons
└── tests/.gitkeep            # Dart tests primary path: flutter_app/test/
```

---

## Development setup (assume Flutter/Xcode/Android SDK installed)

### Mobile smoke

```bash
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter run
```

### macOS projector shortcut

```bash
./scripts/run_macos.sh
```

Guided onboarding & ATL projector QR helper → **`docs/SETUP_FLUTTER_AND_RUN.md`**, **`docs/DEMO_AND_TESTING.md`**  
Deep architecture brainstorming → **`docs/ARCHITECTURE_SENSOR_FUSION.md`**, **`docs/Online_Vs_Offline.md`**.

---

## Python path (offline model evaluation script)

Execute **from repo root** unless you rewrite relative paths inside the script itself:

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cd models && python runGuidePoint.py      # expects input/ images relative to cwd
```

Weights path inside script: **`runs/train/guidepoint/weights/best.pt`**.

---

## Map JSON excerpt

Expanded graph & landmark metadata shipped with repo: **`data/maps/ATL_JSON.json`**.

```json
{
  "building": {
    "name": "ATL",
    "floors": [{
      "floor_number": 1,
      "nodes": [
        {"id": "main_entrance", "name": "Main Entrance", "position": [0, 0]}
      ],
      "edges": [
        {"from_id": "main_entrance", "to_id": "junction_1", "distance": 3}
      ]
    }]
  }
}
```

Optional root key when QR is placed at waypoint: **`"start_node_id": "junction_1"`**.

---

## Contributors

**BVRIT:** Kishore-2013, saikarthikbattula, Keerthika0510, SaarthakMaheshuni  

**UTD:** khaledalshiddi, nandanpabolu, Amulya Prasad Rayabhagi  

---

## References

- Fork lineage: [Kishore-2013/Guide_Point](https://github.com/Kishore-2013/Guide_Point)  
- Roboflow corpus (historic detector lineage): [Object Detection Dataset](https://universe.roboflow.com/object-detection-fpevm/my-first-project-frvbt/dataset/5)

## License

Distributed under the **MIT License** — see **`LICENSE`** in repository root.
