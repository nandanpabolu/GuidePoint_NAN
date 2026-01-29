from ultralytics import YOLO
import cv2
import os

# Load trained model
model = YOLO("model/best_saved_model/best_float32.tflite")

# Folder containing test images
input_folder = "demo_images"    # images here
output_folder = "demo_results"  # results here

def main():
    # Make output folder
    os.makedirs(output_folder, exist_ok=True)

    # Loop through every file in the input folder
    for filename in os.listdir(input_folder):
        if filename.lower().endswith((".png", ".jpg", ".jpeg")):
            img_path = os.path.join(input_folder, filename)

            # Run the model on the image
            results = model(img_path, imgsz=640, conf=0.4)

            # Annotated output
            annotated = results[0].plot()

            # Save annotated image
            save_path = os.path.join(output_folder, f"det_{filename}")
            cv2.imwrite(save_path, annotated)

            print(f"Processed: {filename} -> {save_path}")

    print("\nAll images processed. Check the 'demo_results' folder!")

if __name__ == "__main__":
    main()
