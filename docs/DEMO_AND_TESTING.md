# GuidePoint: Demo and Testing Guide

This document explains how to run the app and test each feature end-to-end.

**Never used Flutter?** → Use **[SETUP_FLUTTER_AND_RUN.md](SETUP_FLUTTER_AND_RUN.md)** for step-by-step install and the **ATL test QR** (open [`tools/scan_atl_qr.html`](../tools/scan_atl_qr.html) in your browser and scan it with the app).  

**No Android phone?** → Use an **emulator**: see **[ANDROID_EMULATOR_SETUP.md](ANDROID_EMULATOR_SETUP.md)** (Android Studio is installed; create a virtual device and run the app on it).

---

## 1. Prerequisites

- **Flutter SDK** 3.2+ ([flutter.dev](https://flutter.dev))
- **Android device or emulator** (Android 7.0+ for full features; pedometer may need a real device)
- **QR code** that encodes the building map (see below)
- **Microphone** for voice destination

---

## 2. Run the App

```bash
cd flutter_app
flutter pub get
flutter run
```

Select an Android device or emulator when prompted. On first run, allow **Camera** and **Microphone** when the app asks.

**Quick, responsive demo (no emulator, no QR):** Run on **macOS** so the app is snappy and you don’t need a camera or QR:

```bash
cd flutter_app && flutter run -d macos
```

Then in the app (debug/profile): tap **“Load sample map”**, then **“Preview navigation UI”** to see the full navigation UI.

---

## 3. Create a Test QR Code

The app needs a QR code that contains the **building map** (JSON). You can either:

### Option A: Inline JSON (no internet)

Encode the full map in the QR. Example content (use a QR generator and paste this):

```json
{
  "building": {
    "name": "ATL",
    "floors": [{
      "floor_number": 1,
      "nodes": [
        {"id": "main_entrance", "name": "Main Entrance", "position": [0, 0]},
        {"id": "junction_1", "name": "Hallway Junction", "position": [0, 3]},
        {"id": "seminar_hall", "name": "Seminar Hall", "position": [4, 3]},
        {"id": "idea_labs", "name": "Idea Labs", "position": [-2, 3]}
      ],
      "edges": [
        {"from_id": "main_entrance", "to_id": "junction_1", "distance": 3},
        {"from_id": "junction_1", "to_id": "seminar_hall", "distance": 4},
        {"from_id": "junction_1", "to_id": "idea_labs", "distance": 2}
      ]
    }]
  }
}
```

Optional: add a start location when the QR is placed at a waypoint:

```json
{
  "building": { ... },
  "start_node_id": "junction_1"
}
```

### Option B: URL to map JSON

If the QR contains a URL (e.g. `https://yourserver.com/atl.json`), the app will fetch the map from that URL. The response must be valid JSON in the same format as above.

---

## 4. Demo Flow: Step-by-Step

| Step | Action | What to expect |
|------|--------|----------------|
| 1 | Open app | Terms & Conditions screen (first time only). Tap **I Accept**. |
| 2 | Camera view | QR scanner is shown. Point camera at the test QR code. |
| 3 | After scan | Map loads; screen switches to “Say your destination.” Mic starts listening. |
| 4 | Say destination | Say e.g. **“Seminar Hall”** or **“Idea Labs”**. Wait for final result (or tap mic to stop). |
| 5 | Path computed | App navigates to **Navigation** screen. You see waypoint index and step count. |
| 6 | Walk (optional) | On a real device, walking updates the step count. TTS gives distance cues every ~5 s. |
| 7 | Waypoint confirmation | When the app has a Scene CNN model and you are “near” a waypoint, it may say “You have reached …”. Without the model, only step-based cues run. |
| 8 | Replay instructions | Tap the list icon in the app bar to open the full instruction list and replay TTS. |

---

## 5. What to Test

### 5.1 Basic pathfinding (no walking)

- Scan QR → say **“Seminar Hall”**. You should get a navigation screen and instructions like “Walk 3 meters to Hallway Junction”, “Walk 4 meters to Seminar Hall”.
- Try **“Idea Labs”** and **“Main Entrance”** (if at main entrance, you may get “You are already at the destination” when route has one node).

### 5.2 Dynamic start (if QR has `start_node_id`)

- Use a QR payload that includes `"start_node_id": "junction_1"`.
- Say **“Seminar Hall”**. The path should start from **junction_1** (not main_entrance).

### 5.3 Pedometer (real device)

- On the Navigation screen, check that **Steps** increases as you walk. If it stays 0, the device may not support the step counter or permissions may be missing.

### 5.4 Scene CNN (when model is added)

- After placing `scene_classifier.tflite` in `flutter_app/assets/models/` and rebuilding, waypoint confirmation can run when you are within ~2 m of the next waypoint (by step-based estimate). The app will try to capture a frame and classify; if confidence ≥ 0.85, it will announce “You have reached [waypoint]”.

---

## 6. Troubleshooting

| Issue | What to try |
|-------|-------------|
| QR not recognized | Ensure the QR contains valid JSON or a reachable URL. Avoid very long inline JSON (URL is better for large maps). |
| “No destination spoken” | Speak clearly; wait for the final STT result. Check microphone permission. |
| “Could not find a place named…” | Use names that match the map (e.g. “Seminar Hall”, “Idea Labs”, “Hallway Junction”). |
| Steps always 0 | Use a real device with a step counter; grant Activity Recognition (or similar) if prompted. |
| App crashes on Navigation screen | Ensure map has at least 2 nodes and a path from start to destination. Check that `assets/models/` exists (even if the TFLite file is missing). |

---

## 7. Demo Without a QR Code or Camera

Built into the app:

1. On the **scanner screen** (debug/profile), tap **“Load sample map”**. The sample ATL map loads (no camera or QR needed).
2. On the **“Say your destination”** screen, tap **“Preview navigation UI”** to open the navigation screen with a sample route (Main Entrance → Seminar Hall). You can see how the app looks and hear instructions without speaking or scanning.

Use this on an emulator (where the camera can’t easily scan a QR on the same machine) or when running on **macOS** (`flutter run -d macos`) for a fast, responsive preview. These shortcuts are **hidden in release builds**.

---

For **architecture** and **what to do next**, see [WHAT_TO_DO_NEXT.md](WHAT_TO_DO_NEXT.md).
