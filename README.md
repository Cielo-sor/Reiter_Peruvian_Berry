# Reiter Peruvian Berry | Inspección de arándanos

- `WEB/` contiene el servidor Django, el panel y la API que usa Flutter.
- `mobile/` contiene la app de captura e historial.
- `backend/` conserva temporalmente FastAPI y los recursos de entrenamiento mientras se verifica la migración.

## Prueba local

1. En `WEB/`, ejecuta `iniciar.bat`. Django se inicia en el puerto 8000. Consulta [la guía de WEB](WEB/README.md) para preparar la base y los usuarios.
2. Instala `requirements-ia.txt` en el entorno de Django y configura `INSPECCION_MODEL_PATH` en `WEB/.env` con la ruta absoluta al ONNX de arándanos. El modelo debe ser YOLO11 con las clases en orden `arandano_sano`, `arandano_danado`. Si el equipo de IA dispone del peso `best.pt`, puede exportarlo con `yolo export model=best.pt format=onnx imgsz=640`. Verifica ese orden en el modelo antes de usarlo.
3. En Flutter, abre Ajustes, indica la URL del servidor e inicia sesión con una cuenta habilitada para móviles. En Android usa `http://10.0.2.2:8000` en emulador, `http://localhost:8000` con `adb reverse tcp:8000 tcp:8000`, o la IP de la laptop en Wi-Fi.
4. Envía una foto y comprueba la imagen anotada en la app y el registro en `/inspecciones/` con una cuenta web autorizada.

## Instancia propia de Reiter

Usa la [guía de despliegue de WEB](WEB/deploy/LEEME.md) en infraestructura de Reiter. Define explícitamente `DOMINIO` al ejecutar el instalador y configura una base PostgreSQL y una cuenta de Cloudinary propias. Para la inspección, monta el ONNX en `deploy/modelos/` y define `INSPECCION_MODEL_PATH=/app/modelos/arandanos.onnx` en el entorno del servidor. Las imágenes de inspección se guardan en PostgreSQL junto a su registro y se descargan por rutas autenticadas. Incluye la base en los respaldos.

Verifica la app desde datos móviles con la URL HTTPS de Reiter antes de retirar FastAPI. Si otra instalación tiene datos en `backend/data/inspections.db` o en `backend/uploads/`, conserva la base y las fotos hasta verificar su traslado.
