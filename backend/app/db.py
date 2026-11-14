import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

DB_PATH = Path(__file__).resolve().parent.parent / "data" / "inspections.db"
DB_PATH.parent.mkdir(parents=True, exist_ok=True)


def _conn():
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    return c


def init_db():
    with _conn() as c:
        c.execute(
            """CREATE TABLE IF NOT EXISTS inspections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT NOT NULL,
                lote TEXT,
                image_path TEXT NOT NULL,
                annotated_path TEXT NOT NULL,
                defect_count INTEGER NOT NULL,
                condition_count INTEGER NOT NULL,
                quality_count INTEGER NOT NULL,
                detections TEXT NOT NULL
            )"""
        )


def insert(lote, image_path, annotated_path, dets):
    cond = sum(1 for d in dets if d.get("category") == "condicion")
    qual = sum(1 for d in dets if d.get("category") == "calidad")
    now = datetime.now(timezone.utc).isoformat()
    with _conn() as c:
        cur = c.execute(
            "INSERT INTO inspections (created_at, lote, image_path, annotated_path, "
            "defect_count, condition_count, quality_count, detections) VALUES (?,?,?,?,?,?,?,?)",
            (now, lote, image_path, annotated_path, cond + qual, cond, qual, json.dumps(dets)),
        )
        return cur.lastrowid


def _row(r):
    return {
        "id": r["id"],
        "created_at": r["created_at"],
        "lote": r["lote"] or "",
        "image_url": "/uploads/" + r["image_path"],
        "annotated_url": "/uploads/" + r["annotated_path"],
        "defect_count": r["defect_count"],
        "condition_count": r["condition_count"],
        "quality_count": r["quality_count"],
        "detections": json.loads(r["detections"]),
    }


def get(det_id):
    with _conn() as c:
        r = c.execute("SELECT * FROM inspections WHERE id=?", (det_id,)).fetchone()
    return _row(r) if r else None


def list_all(limit=200, only_defects=False):
    q = "SELECT * FROM inspections"
    if only_defects:
        q += " WHERE defect_count > 0"
    q += " ORDER BY id DESC LIMIT ?"
    with _conn() as c:
        rows = c.execute(q, (limit,)).fetchall()
    return [_row(r) for r in rows]


def delete(det_id):
    with _conn() as c:
        c.execute("DELETE FROM inspections WHERE id=?", (det_id,))


def stats():
    items = list_all(limit=100000)
    groups = {}
    for it in items:
        for d in it["detections"]:
            g = groups.setdefault(
                d["label"], {"label": d["label"], "display": d.get("display", d["label"]),
                             "category": d.get("category", "calidad"), "count": 0}
            )
            g["count"] += 1
    return {
        "total_images": len(items),
        "images_with_defects": sum(1 for i in items if i["defect_count"] > 0),
        "condition_defects": sum(i["condition_count"] for i in items),
        "quality_defects": sum(i["quality_count"] for i in items),
        "by_label": sorted(groups.values(), key=lambda g: -g["count"]),
    }
