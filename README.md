# GuidePoint_NAN

**AI-Powered Indoor Navigation for the Visually Impaired**

A collaborative project between **B.V. Raju Institute of Technology (BVRIT), India** and **The University of Texas at Dallas (UTD), USA**

---

## Problem Statement

Visually impaired individuals face significant challenges navigating indoor spaces due to the lack of reliable, real-time localization systems. Unlike outdoor environments that rely on GPS, indoor areas like hospitals, college campuses, malls, and offices lack structured, accessible guidance infrastructure.

---

## Project Overview

GuidePoint is an assistive technology solution that enables visually impaired users to navigate indoor environments using AI-based localization and voice guidance. The system uses smartphone cameras and sensors to determine the user's location and provide turn-by-turn navigation instructions.

### Key Features

- **AI-Based Indoor Localization** - Uses camera + IMU sensors to track position without GPS
- **Visual Positioning System (VPS)** - Leverages SLAM for live indoor tracking
- **Voice-Based Navigation** - Natural language step-by-step guidance
- **Pathfinding** - A* algorithm for optimal route calculation
- **Offline Functionality** - Works without internet after map download

---

## Repository Structure

This repository combines **BVRIT's Flutter app** with **UTD's AI/ML development**:

```
GuidePoint_NAN/
├── README.md                        # This file
├── requirements.txt                 # Python ML dependencies
│
├── flutter_app/                     # BVRIT's Flutter Application
│   ├── lib/
│   │   ├── main.dart               # App entry point
│   │   └── Screens/
│   │       ├── astar_pathfinding.dart    # A* algorithm ✅
│   │       ├── qr_scanner_screen.dart    # QR + voice input
│   │       ├── stored_data_screen.dart   # Navigation + TTS
│   │       └── terms_screen.dart         # First-launch T&C
│   ├── android/                    # Android platform
│   ├── ios/                        # iOS platform
│   ├── pubspec.yaml                # Flutter dependencies
│   └── README.md                   # Flutter app docs
│
├── models/                          # AI/ML Models
│   ├── yolo/                       # BVRIT's YOLO Object Detection
│   │   ├── best.pt                 # PyTorch weights
│   │   ├── best.onnx               # ONNX format
│   │   ├── best_saved_model/       # TFLite models
│   │   │   ├── best_float32.tflite # Mobile-ready model
│   │   │   └── best_float16.tflite # Optimized model
│   │   ├── evaluation/             # Training metrics & plots
│   │   ├── data.yaml               # Dataset config
│   │   └── README.md               # Model documentation
│   ├── training/                   # UTD: Model training scripts
│   └── tflite/                     # UTD: Scene classification models
│
├── navigation/                      # UTD: Navigation algorithms
│
├── data/
│   ├── images/                     # Training images
│   └── maps/
│       └── ATL JSON.json           # Sample building map
│
├── docs/                           # Documentation
│   └── bvrit_progress/             # BVRIT evaluation results
│
└── tests/                          # Unit tests
```

---

## Current Implementation Status

### BVRIT Contributions ✅

| Component | Status | Description |
|-----------|--------|-------------|
| Flutter App | ✅ Complete | Cross-platform mobile application |
| QR Scanner | ✅ Complete | `mobile_scanner` integration |
| A* Pathfinding | ✅ Complete | Full Dart implementation |
| Voice Input | ✅ Complete | `speech_to_text` integration |
| Voice Output (TTS) | ✅ Complete | `flutter_tts` integration |
| Map Parser | ✅ Complete | JSON building layout support |

### UTD Responsibilities 🎯

| Component | Status | Description |
|-----------|--------|-------------|
| YOLO Model | Trained | 16-class object detection |
| Scene Classification CNN | ⏳ Pending | Identify rooms from camera |
| Model Training Pipeline | ⏳ Pending | TensorFlow training scripts |
| TFLite Conversion | ✅ Done | Mobile-optimized models |
| Location Detection | ⏳ Pending | Replace hardcoded start point |
| Enhanced NLP | ⏳ Pending | Better intent parsing |

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      FLUTTER APPLICATION                         │
│                         (flutter_app/)                           │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   QR Scanner    │   Voice I/O     │   A* Navigation             │
│   (Camera)      │   (STT/TTS)     │   (Pathfinding)             │
└────────┬────────┴────────┬────────┴──────────────┬──────────────┘
         │                 │                       │
         ▼                 ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                         AI MODELS                                │
│                          (models/)                               │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   YOLO          │   Scene CNN     │   Intent Parser             │
│   (Object Det.) │   (Location)    │   (NLP)                     │
│   ✅ BVRIT      │   🎯 UTD        │   🎯 UTD                    │
└─────────────────┴─────────────────┴─────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BUILDING MAPS                               │
│                       (data/maps/)                               │
│                  JSON: nodes, edges, floors                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Run Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

### Test YOLO Model

```bash
cd models/yolo
pip install ultralytics
python demo_folder.py
```

### Setup ML Development (UTD)

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Demo and Documentation

- **[Demo & Testing](docs/DEMO_AND_TESTING.md)** — How to run the app, create test QR codes, and test each feature (QR, voice, navigation, step count, waypoint confirmation).
- **[What to Do Next](docs/WHAT_TO_DO_NEXT.md)** — Documentation index, current state, prioritized next steps (Scene CNN, tuning, ARCore), key files, and demo checklist.
- **Architecture & design:** [docs/ARCHITECTURE_SENSOR_FUSION.md](docs/ARCHITECTURE_SENSOR_FUSION.md), [docs/Online_Vs_Offline.md](docs/Online_Vs_Offline.md).

---

## Tech Stack

| Layer | Technology | Team |
|-------|------------|------|
| **Mobile App** | Flutter (Dart) | BVRIT ✅ |
| **QR Scanning** | `mobile_scanner` | BVRIT ✅ |
| **Pathfinding** | A* (Dart) | BVRIT ✅ |
| **Voice Input** | `speech_to_text` | BVRIT ✅ |
| **Voice Output** | `flutter_tts` | BVRIT ✅ |
| **Object Detection** | YOLOv8 (TFLite) | BVRIT ✅ |
| **Scene Classification** | CNN (TFLite) | UTD 🎯 |
| **Model Training** | TensorFlow/PyTorch | UTD 🎯 |
| **Map Format** | JSON | Joint |

---

## Map JSON Format

```json
{
  "building": {
    "name": "ATL",
    "floors": [{
      "floor_number": 1,
      "nodes": [
        {"id": "main_entrance", "name": "Main Entrance", "position": [0, 0]},
        {"id": "seminar_hall", "name": "Seminar Hall", "position": [4, 3]}
      ],
      "edges": [
        {"from_id": "main_entrance", "to_id": "junction_1", "distance": 3}
      ]
    }]
  }
}
```

---

## UTD Semester Goals

1. **Research** ML models for indoor scene recognition
2. **Develop** CNN architecture for room/zone classification
3. **Train** model on labeled indoor environment images
4. **Convert** to TensorFlow Lite for mobile deployment
5. **Integrate** with Flutter app via `tflite_flutter`

---

## Key Integration Point

The Flutter app currently has a **hardcoded start location**:

```dart
// In qr_scanner_screen.dart
const String startId = 'main_entrance';  // ← REPLACE WITH AI
```

**UTD's Goal:** Build a CNN that outputs the current location ID based on camera input, replacing this hardcoded value.

---

## Contributors

### BVRIT Team
- Kishore-2013
- saikarthikbattula
- Keerthika0510
- SaarthakMaheshuni

### UTD Team
- khaledalshiddi
- nandanpabolu
- Amulya Prasad Rayabhagi

---

## References

- **BVRIT Original Repo:** [Kishore-2013/Guide_Point](https://github.com/Kishore-2013/Guide_Point)
- **Roboflow Dataset:** [Object Detection Dataset](https://universe.roboflow.com/object-detection-fpevm/my-first-project-frvbt/dataset/5)

---

## License

This project is developed as part of the **UTDesign EPICS** program at The University of Texas at Dallas.
