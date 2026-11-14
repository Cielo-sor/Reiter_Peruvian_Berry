import uuid
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from PIL import Image, ImageOps

from . import db, detector

BASE = Path(__file__).resolve().parent.parent
UPLOADS = BASE / "uploads"
(UPLOADS / "original").mkdir(parents=True, exist_ok=True)
(UPLOADS / "annotated").mkdir(parents=True, exist_ok=True)

app = FastAPI(title="Inspección de calidad y condición de arándano")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.mount("/uploads", StaticFiles(directory=UPLOADS), name="uploads")
db.init_db()


@app.get("/health")
def health():
    return {"status": "ok", "model": detector.model_info()}


@app.post("/api/detect")
def detect_defects(file: UploadFile = File(...), lote: str = Form("")):
    name = uuid.uuid4().hex + ".jpg"
    orig_rel, ann_rel = f"original/{name}", f"annotated/{name}"
    orig, ann = UPLOADS / orig_rel, UPLOADS / ann_rel
    try:
        img = Image.open(file.file)
        img = ImageOps.exif_transpose(img).convert("RGB")
        img.save(orig, "JPEG", quality=90)
    except Exception:
        raise HTTPException(400, "El archivo no es una imagen válida")
    try:
        dets = detector.detect(str(orig), str(ann))
    except Exception as e:
        orig.unlink(missing_ok=True)
        raise HTTPException(500, f"Error en la inferencia: {e}")
    det_id = db.insert(lote.strip(), orig_rel, ann_rel, dets)
    return db.get(det_id)


@app.get("/api/detections")
def list_detections(limit: int = 200, only_defects: bool = False):
    return db.list_all(min(limit, 1000), only_defects)


@app.get("/api/stats")
def get_stats():
    return db.stats()


@app.delete("/api/detections/{det_id}")
def delete_detection(det_id: int):
    item = db.get(det_id)
    if not item:
        raise HTTPException(404, "No encontrado")
    for key in ("image_url", "annotated_url"):
        (BASE / item[key].lstrip("/")).unlink(missing_ok=True)
    db.delete(det_id)
    return {"deleted": det_id}


@app.get("/")
def dashboard():
    return FileResponse(BASE / "dashboard" / "index.html")
