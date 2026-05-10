import os
import json
from ultralytics import YOLO

# -------- CONFIG --------
MODEL_PATH = os.path.join("runs", "train", "guidepoint", "weights", "best.pt")
INPUT_DIR  = "input"     # folder with images
OUTPUT_JSON = "output.json"

# -------- LOAD MODEL --------
model = YOLO(MODEL_PATH)

results_json = []

# -------- PROCESS IMAGES --------
for img_name in os.listdir(INPUT_DIR):
    if not img_name.lower().endswith((".jpg", ".jpeg", ".png")):
        continue

    img_path = os.path.join(INPUT_DIR, img_name)
    results = model(img_path)[0]

    image_entry = {
        "image": img_name,
        "detections": []
    }

    object_id = 1

    if results.boxes is not None:
        for box in results.boxes:
            cls_id = int(box.cls[0])
            conf   = float(box.conf[0])

            x1, y1, x2, y2 = box.xyxy[0].tolist()

            detection = {
                "objectID": object_id,
                "landmark": model.names[cls_id],
                "confidence": round(conf, 4),
                "corners": {
                    "top_left":     {"x": x1, "y": y1},
                    "top_right":    {"x": x2, "y": y1},
                    "bottom_left":  {"x": x1, "y": y2},
                    "bottom_right": {"x": x2, "y": y2}
                }
            }

            image_entry["detections"].append(detection)
            object_id += 1

    results_json.append(image_entry)

# -------- SAVE JSON --------
with open(OUTPUT_JSON, "w") as f:
    json.dump(results_json, f, indent=4)

print(f" Done! Results saved to {OUTPUT_JSON}")

# -------- SAVE LABELS --------
current_dir = os.path.dirname(os.path.abspath(__file__))
target_path = os.path.join(current_dir, "..", "flutter_app", "assets", "models", "labels.txt")    
target_path = os.path.normpath(target_path)
try:
    with open(target_path, "w") as f:
        for i in range(len(model.names)):
            f.write(model.names[i] + "\n")
    print(f"Done! Labels saved to: {target_path}")
except IOError as e:
    print(f"Error: Could not write to labels.txt {e}")