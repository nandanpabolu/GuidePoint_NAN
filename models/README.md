# `models/` — training outputs & reproducibility guide

Partner repo looks “heavy” here because **`models/runs/`** holds **exported weights (~100+ MB)** plus **evaluation plots** from Ultralytics/YOLO training.

| Path | Typical contents |
|------|------------------|
| **`runs/train/guidepoint/`** | `weights/*.pt`, TFLite `best_saved_model/`, curves — **canonical run** referenced by **`runGuidePoint.py`** |
| **`runs/eval/`, `runs/detect/`, `runs/test/`** | Metrics plots, confusion matrices, sample JPEGs comparing PyTorch vs TFLite |
| **`runGuidePoint.py`** | Batch inference consuming `runs/train/guidepoint/weights/best.pt` |

**Deleting** these folders trims disk use but removes **immediate reproducibility** unless you regenerate from datasets. Keeping them preserves **evidence alongside the shipped app**.
