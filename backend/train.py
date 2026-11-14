"""Entrenamiento YOLO (Ultralytics) para arandano_sano / arandano_danado.
Uso:  python train.py [ruta/data.yaml]     (recomendado en Google Colab con GPU)"""
import sys
from ultralytics import YOLO

data = sys.argv[1] if len(sys.argv) > 1 else "dataset/data.yaml"
model = YOLO("yolo11s.pt")
model.train(
    data=data,
    epochs=150,
    imgsz=640,          # debe coincidir con IMG_SIZE del servidor (por defecto 640)
    batch=16,
    optimizer="AdamW", lr0=0.0005, lrf=0.1, warmup_epochs=5, cos_lr=True,
    amp=False,          # evita la inestabilidad numérica vista en Colab
    patience=50,
    degrees=10, fliplr=0.5, flipud=0.5, hsv_v=0.4,
    name="calidad_v2",
)
print("Listo: copia runs/detect/calidad_v2/weights/best.pt a backend/models/best.pt")
