"""Detector de defectos de calidad y condición en arándano cosechado (YOLO Ultralytics)."""
import os
import threading

import cv2

CONF = float(os.getenv("CONF_THRESHOLD", "0.35"))
IMGSZ = int(os.getenv("IMG_SIZE", "640"))  # debe coincidir con el imgsz del entrenamiento
MODEL_PATH = os.getenv("MODEL_PATH", "models/best.pt")

# ── Taxonomía (los nombres deben coincidir EXACTO con las clases del dataset) ──
HEALTHY = {"arandano_sano"}
# Fase actual: "arandano_danado" agrupa cualquier defecto y se muestra en rojo.
CONDICION = {"arandano_danado", "deshidratado", "exudacion", "pudricion", "hongo", "machucon", "partidura"}
CALIDAD = {
    "ausencia_bloom", "bajo_calibre", "cicatriz", "dano_ave", "desgarro",
    "hendidura_pedicelar", "inmaduro", "russeting", "suciedad",
    "pedunculo_adherido", "resto_floral", "filodio",
}
DISPLAY = {
    "arandano_sano": "Arándano sano",
    "arandano_danado": "Arándano dañado",
    "ausencia_bloom": "Ausencia de bloom", "bajo_calibre": "Bajo calibre",
    "cicatriz": "Cicatriz", "dano_ave": "Daño por ave", "desgarro": "Desgarro",
    "hendidura_pedicelar": "Hendidura pedicelar", "inmaduro": "Inmaduro",
    "russeting": "Russeting (Russet)", "suciedad": "Suciedad",
    "pedunculo_adherido": "Pedúnculo adherido", "resto_floral": "Resto floral",
    "filodio": "Filodio (verde)",
    "deshidratado": "Deshidratado", "exudacion": "Exudación", "pudricion": "Pudrición",
    "hongo": "Hongo", "machucon": "Machucón", "partidura": "Partidura de la fruta",
}

# Colores BGR por categoría
COLORS = {"condicion": (0, 0, 255), "calidad": (0, 140, 255), "sano": (0, 170, 0)}

_model = None
_lock = threading.Lock()
_FONT = cv2.FONT_HERSHEY_SIMPLEX


def model_info() -> str:
    return f"local:{MODEL_PATH}"


def categorize(label: str) -> str:
    l = label.strip().lower()
    if l in HEALTHY:
        return "sano"
    if l in CONDICION:
        return "condicion"
    return "calidad"  # cualquier otra clase se trata como defecto de calidad


def _get_model():
    global _model
    with _lock:
        if _model is None:
            if not os.path.exists(MODEL_PATH):
                raise RuntimeError(
                    f"No se encontró el modelo '{MODEL_PATH}'. Copia tu best.pt a backend/models/ "
                    "o define MODEL_PATH."
                )
            from ultralytics import YOLO

            _model = YOLO(MODEL_PATH)
        return _model


def draw_boxes(img, dets):
    """Rojo = defecto de condición/dañado, naranja = defecto de calidad, verde = sano."""
    h, w = img.shape[:2]
    thick = max(3, round(min(h, w) / 150))
    scale = max(0.6, min(h, w) / 900)
    ft = max(1, thick // 2)
    for i, d in enumerate(dets, 1):
        x1, y1, x2, y2 = [int(v) for v in d["bbox"]]
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(w - 1, x2), min(h - 1, y2)
        color = COLORS[d["category"]]
        cv2.rectangle(img, (x1, y1), (x2, y2), color, thick)
        text = f'{i}. {d["label"]} {int(d["confidence"] * 100)}%'  # ASCII: OpenCV no dibuja tildes
        (tw, th), base = cv2.getTextSize(text, _FONT, scale, ft)
        top = y1 - th - base - 8
        if top < 0:
            top = y1
        cv2.rectangle(img, (x1, top), (x1 + tw + 10, top + th + base + 8), color, -1)
        cv2.putText(img, text, (x1 + 5, top + th + 3), _FONT, scale, (255, 255, 255), ft, cv2.LINE_AA)
    return img


def detect(image_path: str, annotated_path: str):
    model = _get_model()
    with _lock:
        result = model.predict(image_path, conf=CONF, imgsz=IMGSZ, verbose=False)[0]
    dets = []
    for b in result.boxes:
        cls = int(b.cls[0])
        label = result.names[cls]
        cat = categorize(label)
        dets.append(
            {
                "class_id": cls,
                "label": label,
                "display": DISPLAY.get(label.strip().lower(), label),
                "category": cat,
                "is_defect": cat != "sano",
                "confidence": round(float(b.conf[0]), 3),
                "bbox": [round(v, 1) for v in b.xyxy[0].tolist()],
            }
        )
    img = cv2.imread(image_path)
    cv2.imwrite(annotated_path, draw_boxes(img, dets))
    return dets
