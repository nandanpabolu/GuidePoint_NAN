# YOLO Object Detection Model

**BVRIT's Pre-trained YOLO Model** for indoor object detection.

> Source: [Kishore-2013/Guide_Point](https://github.com/Kishore-2013/Guide_Point)

---

## Model Overview

This YOLOv8 model is trained to detect common indoor objects that can serve as navigation landmarks.

### Classes (16)

| ID | Class | ID | Class |
|----|-------|----|-------|
| 0 | Board | 8 | Outdoors |
| 1 | Chair | 9 | Pillar |
| 2 | Cubicle | 10 | Portrait |
| 3 | Door | 11 | Poster |
| 4 | Doorway | 12 | Rug |
| 5 | Fans | 13 | Table |
| 6 | Human | 14 | Window |
| 7 | Lighting | 15 | Objects |

---

## Model Files

| File | Format | Size | Use Case |
|------|--------|------|----------|
| `best.pt` | PyTorch | ~6MB | Training/fine-tuning |
| `best.onnx` | ONNX | ~12MB | Cross-platform inference |
| `best_saved_model/best_float32.tflite` | TFLite | ~6MB | **Mobile deployment** |
| `best_saved_model/best_float16.tflite` | TFLite (FP16) | ~3MB | Mobile (optimized) |

---

## Dataset Info

```yaml
# From data.yaml
train: ../train/images
val: ../valid/images
test: ../test/images

nc: 16  # Number of classes

# Dataset from Roboflow
roboflow:
  workspace: object-detection-fpevm
  project: my-first-project-frvbt
  version: 5
  license: CC BY 4.0
  url: https://universe.roboflow.com/object-detection-fpevm/my-first-project-frvbt/dataset/5
```

---

## Usage

### Python (Ultralytics)

```python
from ultralytics import YOLO

# Load model
model = YOLO("best.pt")  # or best_saved_model/best_float32.tflite

# Run inference
results = model("image.jpg", imgsz=640, conf=0.4)

# Get annotated image
annotated = results[0].plot()
```

### Demo Script

```bash
# Place test images in demo_images/ folder
python demo_folder.py

# Results saved to demo_results/
```

---

## Evaluation Results

See `evaluation/` folder for:

- `confusion_matrix.png` - Classification performance
- `BoxF1_curve.png` - F1 score curve
- `BoxP_curve.png` - Precision curve
- `BoxR_curve.png` - Recall curve
- `results.csv` - Training metrics
- `val_batch*_pred.jpg` - Validation predictions

---

## Flutter Integration

To use in Flutter app:

1. Add `tflite_flutter` to `pubspec.yaml`
2. Copy `best_float32.tflite` to `assets/models/`
3. Load and run inference:

```dart
import 'package:tflite_flutter/tflite_flutter.dart';

final interpreter = await Interpreter.fromAsset('models/best_float32.tflite');
// Process camera frames...
```

---

## UTD Enhancement Opportunities

This object detection model can be combined with:

1. **Scene Classification CNN** - "You are in: Seminar Hall"
2. **Spatial Reasoning** - "Door detected 3 meters ahead"
3. **Navigation Context** - Use detected objects to confirm location

The detected objects (Door, Pillar, etc.) can serve as waypoint confirmation during navigation.
