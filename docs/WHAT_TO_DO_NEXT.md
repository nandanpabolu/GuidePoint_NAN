# GuidePoint: What to Do Next — Documentation and Next Steps

This document points you to detailed docs and gives a clear order of operations for development and testing.

---

## 1. Documentation Index

| Document | Purpose |
|----------|---------|
| [DEMO_AND_TESTING.md](DEMO_AND_TESTING.md) | How to run the app, create test QR codes, and test each feature. |
| [ARCHITECTURE_SENSOR_FUSION.md](ARCHITECTURE_SENSOR_FUSION.md) | Full system design: sensors, position estimator, navigation controller, Scene CNN, data flows, phases. |
| [Online_Vs_Offline.md](Online_Vs_Offline.md) | Tradeoffs between online vs offline (maps, Scene CNN, STT), and when to use which. |
| [../README.md](../README.md) | Project overview, repo structure, tech stack, quick start. |

---

## 2. Current State (Summary)

- **Done:** Flutter app with QR scan, voice destination (STT), A* pathfinding, TTS, dynamic start from QR (`start_node_id`), navigation screen with step count, position estimator (steps × 0.7 m along route), control loop, waypoint confirmation hook (Scene CNN), off-route detection and re-route.
- **Pending:** A trained **Scene CNN** TFLite model in `flutter_app/assets/models/scene_classifier.tflite`. Without it, waypoint confirmation is skipped (only step-based distance cues run).
- **Optional later:** ARCore (VIO) for better position accuracy on Android.

---

## 3. What to Do Next (Priority Order)

### Immediate: Run and demo

1. **Run the app**  
   See [DEMO_AND_TESTING.md](DEMO_AND_TESTING.md): `cd flutter_app && flutter pub get && flutter run`.

2. **Test the flow**  
   Use a QR code with the ATL map (inline or URL). Say “Seminar Hall” or “Idea Labs”. Confirm you get the Navigation screen, instructions, and (on device) step count updates.

3. **Optional: test dynamic start**  
   Use a QR that includes `"start_node_id": "junction_1"` and confirm the path starts from that node.

---

### Short term: Scene CNN (enables waypoint confirmation)

4. **Collect data**  
   50–100 images per waypoint (e.g. main_entrance, junction_1, seminar_hall, idea_labs). Label by the same `id` as in the map.

5. **Train a model**  
   Use MobileNetV2 (or similar) to classify images into those waypoint IDs. Export to TFLite (input e.g. 224×224×3, output [1, numClasses]).

6. **Add the model to the app**  
   Put `scene_classifier.tflite` in `flutter_app/assets/models/`. Rebuild. The existing `SceneClassifier` in `lib/services/scene_classifier.dart` will load it; waypoint confirmation will run when step-based distance to next waypoint &lt; 2 m.

7. **Align label order**  
   Ensure the order of class indices in the TFLite model matches the order of `pathfinder.nodes.keys` (or the `labelIds` list passed to `SceneClassifier`). See `scene_classifier.dart` and map node ids.

---

### Medium term: Improve robustness and UX

8. **Tune constants**  
   In `lib/services/position_estimator.dart`: `NavConstants` (waypoint threshold 2 m, confidence 0.85, off-route 5 m, step length 0.7 m). Adjust if your building scale or accuracy need it.

9. **Handle edge cases**  
   No path found, no camera permission, TFLite load failure, very short routes. Add user-facing messages and fallbacks where needed.

10. **Optional: ARCore (Phase 4)**  
    For better accuracy, add ARCore on Android and feed VIO pose into the position estimator; keep pedometer as fallback when VIO is unavailable. See [ARCHITECTURE_SENSOR_FUSION.md](ARCHITECTURE_SENSOR_FUSION.md) Phase 4.

---

## 4. Key Files (Reference)

| What | Where |
|------|--------|
| QR scan, start location, pathfinding trigger | `flutter_app/lib/Screens/qr_scanner_screen.dart` |
| Navigation screen, control loop, TTS, CNN trigger | `flutter_app/lib/Screens/navigation_screen.dart` |
| Step-based position along route | `flutter_app/lib/services/position_estimator.dart` |
| Scene CNN (TFLite) | `flutter_app/lib/services/scene_classifier.dart` |
| Step count | `flutter_app/lib/services/step_count_service.dart` |
| A* and map graph | `flutter_app/lib/Screens/astar_pathfinding.dart` |
| Map data (ATL) | `data/maps/ATL JSON.json` |
| Constants | `NavConstants` in `position_estimator.dart` |

---

## 5. Architecture Summary

- **AnchorStep:** Position from **pedometer** (steps × 0.7 m) along the route; **Scene CNN** confirms “You are at waypoint X” when near and confidence ≥ 0.85, then resets the step baseline.
- **Off-route:** If estimated position is &gt; 5 m from the current segment, the app finds the nearest map node and re-runs A* to the destination, then replaces the route and says “Recalculating route.”
- **Output:** TTS for distance cues and waypoint/destination announcements.

For full detail (sensors, flows, APIs, phases), use [ARCHITECTURE_SENSOR_FUSION.md](ARCHITECTURE_SENSOR_FUSION.md).

---

## 6. Checklist Before a Demo or Handoff

- [ ] App runs: `flutter run` on Android.
- [ ] QR with ATL map (inline or URL) loads and shows “Say your destination.”
- [ ] Voice destination (“Seminar Hall” / “Idea Labs”) produces a path and Navigation screen.
- [ ] TTS plays instructions; “View instructions” list works.
- [ ] On a real device, step count increases when walking.
- [ ] If `scene_classifier.tflite` is present, waypoint confirmation is attempted when close to the next waypoint.
- [ ] Off-route: taking a wrong turn (or simulating) triggers “Recalculating route” and a new path.

---

For the **demo flow only**, follow [DEMO_AND_TESTING.md](DEMO_AND_TESTING.md). For **design and online/offline**, use [ARCHITECTURE_SENSOR_FUSION.md](ARCHITECTURE_SENSOR_FUSION.md) and [Online_Vs_Offline.md](Online_Vs_Offline.md).
