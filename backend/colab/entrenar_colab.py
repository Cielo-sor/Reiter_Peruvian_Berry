# ============ GUÍA PARA GOOGLE COLAB (cada bloque "# %%" es una celda) ============
# Antes: Entorno de ejecución > Cambiar tipo > GPU T4. Sube el .zip exportado de Roboflow (YOLOv11).

# %% 1. Instalar y descomprimir (ajusta el nombre del zip)
# !pip install -q ultralytics
# !unzip -q "/content/TU_DATASET.zip" -d /content/dataset
# !find /content/dataset -maxdepth 2 -type d

# %% 2. Corregir rutas del data.yaml
import glob, os, yaml
yaml_path = glob.glob("/content/dataset/**/data.yaml", recursive=True)[0]
root = os.path.dirname(yaml_path)
has = lambda rel: os.path.isdir(os.path.join(root, rel)) and len(os.listdir(os.path.join(root, rel))) > 0
train = "train/images" if has("train/images") else None
val = next((r for r in ["valid/images", "val/images", "test/images"] if has(r)), None)
d = yaml.safe_load(open(yaml_path))
d["path"], d["train"], d["val"] = root, train, val or train
d.pop("test", None)
yaml.safe_dump(d, open(yaml_path, "w"))
print(d)   # val debe ser una carpeta distinta de train; si no, reparte mejor en Roboflow

# %% 3. Revisar datos (valid DEBE tener cuadros de ambas clases)
import collections
print("clases:", d["names"])
for split in ["train", "valid"]:
    c, n = collections.Counter(), 0
    for f in glob.glob(f"{root}/{split}/labels/*.txt"):
        n += 1
        for line in open(f):
            if line.split():
                c[line.split()[0]] += 1
    print(split, "| imágenes:", n, "| cuadros por clase:", dict(c))

# %% 4. Entrenar
from ultralytics import YOLO
model = YOLO("yolo11s.pt")
model.train(data=yaml_path, epochs=150, imgsz=640, batch=16,
            optimizer="AdamW", lr0=0.0005, lrf=0.1, warmup_epochs=5, cos_lr=True,
            amp=False, patience=50, name="calidad_v2")

# %% 5. Resultado: revisa results.png y confusion_matrix.png; descarga best.pt
# from google.colab import files
# files.download("/content/runs/detect/calidad_v2/weights/best.pt")
