# Workflow — Developer environment

Detailed commands also live at repo root **`README.md`**.

## Setup (assumes Xcode / Android SDK / Flutter already installed per course machine image)

```bash
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter run
```

## Assets you may drop in manually

**`flutter_app/assets/models/`**

- **`yolo_detector.tflite`** (ships today) — indoor object confirmations  
- Optional **`scene_classifier.tflite`** + matching label cardinality — waypoint softmax confirmation

## Python tooling (offline batch labeling)

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt  # installs TensorFlow tooling + Jupyter stack
python models/runGuidePoint.py   # expects Ultralytics checkpoints under models/runs/...
```

**Note:** Maintain virtualenv **outside** of git snapshots per `.gitignore`.
