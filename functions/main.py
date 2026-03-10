from firebase_functions import https_fn, options
from firebase_admin import initialize_app
import io
import os

initialize_app()

INPUT_SIZE = 320
CONFIDENCE_THRESHOLD = 0.5
COCO_CLASSES = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train',
    'truck', 'boat', 'traffic light', 'fire hydrant', 'stop sign',
    'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep', 'cow',
    'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella', 'handbag',
    'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball', 'kite',
    'baseball bat', 'baseball glove', 'skateboard', 'surfboard',
    'tennis racket', 'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon',
    'bowl', 'banana', 'apple', 'sandwich', 'orange', 'broccoli', 'carrot',
    'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch', 'potted plant',
    'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote',
    'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink',
    'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear',
    'hair drier', 'toothbrush',
]

_interpreter = None


def _get_interpreter():
    global _interpreter
    if _interpreter is None:
        from ai_edge_litert import interpreter as tflite  # noqa: lazy import (not available on Windows)
        model_path = os.path.join(os.path.dirname(__file__), 'yolo11n_float32.tflite')
        _interpreter = tflite.Interpreter(model_path=model_path)
        _interpreter.allocate_tensors()
    return _interpreter


@https_fn.on_request(
    memory=options.MemoryOption.MB_512,
    timeout_sec=60,
    cors=True,
)
def detect_frame(req: https_fn.Request) -> https_fn.Response:
    """Receives a JPEG frame, runs YOLO, returns annotated JPEG if detected or 204 if not."""
    if req.method != 'POST':
        return https_fn.Response('Method not allowed', status=405)

    image_bytes = req.data
    if not image_bytes:
        return https_fn.Response('No image data', status=400)

    try:
        import numpy as np  # noqa: lazy import
        from PIL import Image, ImageDraw  # noqa: lazy import
        image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
        original_w, original_h = image.size
        resized = image.resize((INPUT_SIZE, INPUT_SIZE))
        input_array = np.array(resized, dtype=np.float32) / 255.0
        input_array = np.expand_dims(input_array, axis=0)

        interpreter = _get_interpreter()
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        interpreter.set_tensor(input_details[0]['index'], input_array)
        interpreter.invoke()
        output = interpreter.get_tensor(output_details[0]['index'])[0]  # [84, 2100]

        found = []
        for i in range(output.shape[1]):
            scores = output[4:, i]
            max_score = float(np.max(scores))
            max_class = int(np.argmax(scores))
            if max_score >= CONFIDENCE_THRESHOLD:
                cx, cy, w, h = (float(output[j, i]) for j in range(4))
                found.append((cx, cy, w, h, max_class, max_score))

        if not found:
            return https_fn.Response('', status=204)  # No detection

        # Draw bounding boxes
        draw = ImageDraw.Draw(image)
        scale_x = original_w / INPUT_SIZE
        scale_y = original_h / INPUT_SIZE
        for cx, cy, w, h, cls, score in found:
            x1 = int((cx - w / 2) * scale_x)
            y1 = int((cy - h / 2) * scale_y)
            x2 = int((cx + w / 2) * scale_x)
            y2 = int((cy + h / 2) * scale_y)
            draw.rectangle([x1, y1, x2, y2], outline='red', width=3)
            name = COCO_CLASSES[cls] if cls < len(COCO_CLASSES) else str(cls)
            draw.text((x1, max(0, y1 - 16)), f'{name} {score * 100:.0f}%', fill='red')

        out_buf = io.BytesIO()
        image.save(out_buf, format='JPEG', quality=85)
        out_buf.seek(0)
        return https_fn.Response(out_buf.read(), status=200, content_type='image/jpeg')

    except Exception as e:
        return https_fn.Response(f'Error: {str(e)}', status=500)
