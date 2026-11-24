from functools import lru_cache
from io import BytesIO
from pathlib import Path
from types import SimpleNamespace

from django.conf import settings
from PIL import ImageDraw

from ia.inference import DetectorNoDisponible
from ia.inference.onnx import DetectorOnnx


CLASES = ("arandano_sano", "arandano_danado")
ETIQUETAS = {
    "arandano_sano": ("Arándano sano", "sano", "#00aa00"),
    "arandano_danado": ("Arándano dañado", "condicion", "#dd0000"),
}


@lru_cache(maxsize=1)
def cargar_modelo(ruta):
    if not ruta or not Path(ruta).is_file():
        raise DetectorNoDisponible("Falta configurar el modelo ONNX de inspección.")
    modelo = SimpleNamespace(classes=CLASES, imgsz=640, conf_threshold=0.35,
                             iou_threshold=0.7, version="inspeccion", tiling={})
    return DetectorOnnx(modelo, ruta)


def jpeg(imagen):
    salida = BytesIO()
    imagen.save(salida, "JPEG", quality=90)
    return salida.getvalue()


def analizar(imagen):
    detector = cargar_modelo(settings.INSPECCION_MODEL_PATH)
    anotada = imagen.copy()
    dibujos = ImageDraw.Draw(anotada)
    detecciones = []
    for caja in detector.analizar_imagen(imagen).boxes:
        clase = caja["class_name"]
        etiqueta, categoria, color = ETIQUETAS[clase]
        coordenadas = [caja[k] for k in ("x_min", "y_min", "x_max", "y_max")]
        confianza = caja["confidence"]
        dibujos.rectangle(coordenadas, outline=color, width=3)
        dibujos.text(tuple(coordenadas[:2]), f"{etiqueta} {confianza:.0%}", fill=color,
                     stroke_width=1, stroke_fill="white")
        detecciones.append({
            "class_id": CLASES.index(clase), "label": clase, "display": etiqueta,
            "category": categoria, "is_defect": categoria != "sano",
            "confidence": confianza, "bbox": coordenadas,
        })
    return detecciones, jpeg(anotada)
