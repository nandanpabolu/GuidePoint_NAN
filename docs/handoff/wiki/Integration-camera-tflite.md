# Integration — Camera + TensorFlow Lite

**Packages:** `camera`, `image`, `tflite_flutter`

**Models (drop under `flutter_app/assets/models/`):**

- **`yolo_detector.tflite`** — indoor landmark confirmation when CNN absent or low confidence fallback.  
- Optional **`scene_classifier.tflite`** — softmax over waypoint ids aligning with **`SceneClassifier`** label ordering.

**Flow:** Periodic still capture during **`NavigationScreen`** waypoint proximity → inference → audible confirmation cues.
