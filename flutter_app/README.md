# GuidePoint — Flutter mobile client (`guide_point`)

Authoritative syllabus-level documentation → **repository root [`README.md`](../README.md)**.

This README only surfaces **Flutter-specific developer facts**.

---

## Platforms

Android · iOS · macOS/Linux/Windows scaffold present for smoke tests (`flutter run -d macos`). **Golden path targets phones** (permissions + sensors).

---

## Dependencies (see [`pubspec.yaml`](pubspec.yaml))

| Capability | Packages |
|-----------|----------|
| QR scan | `mobile_scanner`, `permission_handler` |
| Remote maps | `http` |
| Voice | `speech_to_text`, `flutter_tts` |
| Persist prefs | `shared_preferences` |
| Steps | `pedometer` |
| Vision | `camera`, `image`, `tflite_flutter` |
| Algorithms | `collection` helpers inside A |

---

## Project structure (actual Dart tree)

```
lib/
├── main.dart                 # Routing + theme
├── demo_data.dart            # Debug/demo JSON + fixed route snippet
├── screens/
│   ├── terms_screen.dart
│   ├── qr_scanner_screen.dart   # QR + STT orchestration → navigation jump
│   ├── navigation_screen.dart   # Guidance loop (camera/TTS/steps/models)
│   ├── stored_data_screen.dart # Instruction ledger view
│   └── astar_pathfinding.dart  # Planner + parser
├── services/
│   ├── step_count_service.dart
│   ├── position_estimator.dart
│   ├── scene_classifier.dart
│   └── yolo_detector.dart
└── ...
```

Bundled atlas copy (optional duplication of `../../data/maps/ATL_JSON.json`) → **`assets/maps/`**.

TFLite + labels live under **`assets/models/`**.

---

## Run / build

```bash
flutter pub get
flutter analyze
flutter test
flutter run                 # attach device/emulator selection
flutter build apk --release # after signing configs
flutter build ios --release # macOS hosts only w/ Xcode
```

Android release signing placeholders → **`android/key.properties.example`**.
