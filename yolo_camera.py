import cv2
import time
import urllib.request
import numpy as np
from ultralytics import YOLO
from ultralytics.utils import LOGGER

LOGGER.setLevel(50)

# IP Camera URL
url = 'http://espcam.local/cam-lo.jpg'

# Load YOLOv8 model
model = YOLO("yolov8n_ncnn_model", verbose=False)

# Define allowed classes
allowed_classes = ["person", "chair", "car"]

cv2.namedWindow("Live Cam with YOLOv8", cv2.WINDOW_AUTOSIZE)

while True:
    try:
        img_resp = urllib.request.urlopen(url)
        imgnp = np.array(bytearray(img_resp.read()), dtype=np.uint8)
        frame = cv2.imdecode(imgnp, -1)

        frame = cv2.rotate(frame, cv2.ROTATE_90_CLOCKWISE)

    except Exception as e:
        print(f"Error fetching frame: {e}")
        continue

    results = model(frame)

    frame_height, frame_width, _ = frame.shape
    center_x = frame_width // 2

    filtered_detections = []
    for result in results:
        for box in result.boxes:
            class_name = result.names[int(box.cls[0])]
            if class_name in allowed_classes:
                filtered_detections.append(box)

    annotated_frame = frame.copy()
    directions = set()

    for box in filtered_detections:
        x1, y1, x2, y2 = map(int, box.xyxy[0])
        confidence = box.conf[0]
        class_name = result.names[int(box.cls[0])]

        object_center_x = (x1 + x2) // 2

        if object_center_x < center_x - 50:
            directions.add("right")
        elif object_center_x > center_x + 50:
            directions.add("left")
        else:
            directions.add("back")

        cv2.rectangle(annotated_frame, (x1, y1), (x2, y2), (0, 255, 0), 2)

        label = f"{class_name}: {confidence:.2f}"
        cv2.putText(annotated_frame, label, (x1, y1 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

    if "back" in directions:
        movement = "Move Back"
    elif "left" in directions:
        movement = "Move Left"
    elif "right" in directions:
        movement = "Move Right"
    else:
        movement = "Move Straight"

    cv2.putText(annotated_frame, movement, (10, 220),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 2)

    inference_time = results[0].speed['inference']
    fps = 1000 / inference_time if inference_time > 0 else 0
    text = f'FPS: {fps:.1f}'

    font = cv2.FONT_HERSHEY_SIMPLEX
    text_size = cv2.getTextSize(text, font, 1, 2)[0]
    text_x = annotated_frame.shape[1] - text_size[0] - 10
    text_y = text_size[1] + 10
    cv2.putText(annotated_frame, text, (text_x, text_y),
                font, 1, (255, 255, 255), 2, cv2.LINE_AA)

    print(movement, flush=True)
    cv2.imshow("Live Cam with YOLOv8", annotated_frame)

    if cv2.waitKey(1) == ord("q"):
        break

cv2.destroyAllWindows()
