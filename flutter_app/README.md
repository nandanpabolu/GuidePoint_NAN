# GuidePoint Flutter App

**BVRIT's Flutter Implementation** - Cross-platform mobile application for indoor navigation.

> Source: [Kishore-2013/Guide_Point](https://github.com/Kishore-2013/Guide_Point)

---

## Overview

A Flutter-based mobile application designed to provide accessible indoor navigation for visually impaired users through QR code scanning and voice-guided instructions.

---

## Features

- **Dynamic QR Code Processing** - Handles QR codes with direct JSON or URLs to hosted maps
- **Complex Map Parsing** - Parses nested JSON building layouts into step-by-step paths
- **Voice-Guided Navigation** - Text-to-Speech for hands-free directional instructions
- **Multi-Modal Controls**:
  - On-Screen Buttons (Play/Pause, Next, Previous, Replay)
  - Voice Commands ("Seminar Hall")
  - Hardware Key Integration (Volume button recall)
- **A* Pathfinding** - Optimal route calculation built-in

---

## Tech Stack

| Component | Package |
|-----------|---------|
| Framework | Flutter & Dart |
| QR Scanning | `mobile_scanner` ^3.5.5 |
| HTTP Requests | `http` |
| Text-to-Speech | `flutter_tts` ^3.8.3 |
| Speech Recognition | `speech_to_text` ^6.6.1 |
| Local Storage | `shared_preferences` ^2.2.3 |
| Permissions | `permission_handler` ^11.3.0 |
| Hardware Keys | `volume_controller` ^3.4.0 |

---

## Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                    # App entry point & routing
│   └── Screens/
│       ├── terms_screen.dart        # First-launch T&C
│       ├── qr_scanner_screen.dart   # QR scanner + voice input
│       ├── stored_data_screen.dart  # Navigation instructions + TTS
│       └── astar_pathfinding.dart   # A* algorithm implementation
├── android/                         # Android platform code
├── ios/                             # iOS platform code
├── web/                             # Web platform code
├── linux/                           # Linux platform code
├── macos/                           # macOS platform code
├── windows/                         # Windows platform code
├── assets/
│   └── Icons/
│       └── app_icon.png
├── pubspec.yaml                     # Dependencies
└── test/
    └── widget_test.dart
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.2.0+
- Dart SDK
- Android Studio / Xcode (for mobile builds)

### Installation

```bash
# Navigate to flutter_app directory
cd flutter_app

# Get dependencies
flutter pub get

# Run on connected device
flutter run
```

### Building

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release
```

---

## User Flow

1. **First Launch** → Accept Terms & Conditions
2. **Scanner Screen** → Scan building QR code
3. **Voice Input** → Say destination (auto-starts after scan)
4. **Navigation** → A* calculates path, TTS reads instructions

---

## Map JSON Format

The app expects building maps in this format:

```json
{
  "building": {
    "name": "Building Name",
    "floors": [{
      "floor_number": 1,
      "nodes": [
        {"id": "node_id", "name": "Display Name", "position": [x, y]}
      ],
      "edges": [
        {"from_id": "node1", "to_id": "node2", "distance": 3}
      ]
    }]
  }
}
```

---

## Contributors

- **Kishore-2013** (BVRIT)
- **khaledalshiddi**
- **saikarthikbattula**
- **Keerthika0510**
- **SaarthakMaheshuni**

---

## Integration with UTD AI Models

The app is designed to integrate with UTD's TensorFlow Lite models for:
- **Scene Classification** - Identify current location from camera
- **Object Detection** - Detect indoor landmarks

Integration path: `../models/` contains trained models ready for Flutter integration via `tflite_flutter` package.
