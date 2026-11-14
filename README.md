# 🫐 Inspección de calidad y condición de arándano cosechado (YOLO)

App móvil (Android/iOS) + servidor que detecta con **YOLO Ultralytics** si cada arándano está
**sano (verde)** o **dañado (rojo)** y guarda la imagen en un **dashboard web**.

```
arandanos-calidad/
├── backend/   FastAPI + YOLO + SQLite + dashboard   (Python 3.10–3.12)
└── mobile/    App Flutter (Android + iOS)
```

## Clases (fase actual)
| Clase | Color | Regla de etiquetado |
|---|---|---|
| `arandano_sano` | Verde | Fruta sin ningún defecto |
| `arandano_danado` | Rojo | Fruta con cualquier defecto de calidad o condición del póster |

Un cuadro por fruta; ante la duda, no etiquetar. **No** marcar "bajo calibre" como dañado
(requiere medir con referencia de tamaño). El código ya soporta las clases por tipo de defecto
(ver `backend/app/detector.py` y `backend/dataset/GUIA_ETIQUETADO.md`) para una fase futura.

## 1. Entrenar el modelo (obligatorio: el proyecto NO incluye modelo)
1. Etiqueta en Roboflow (2 clases; Train y Valid con ambas) y exporta en formato **YOLOv11**.
2. Sigue `backend/colab/entrenar_colab.py` en Google Colab (GPU T4), celda por celda.
3. Revisa `results.png` (pérdidas estables, mAP50 en alza) y descarga `best.pt`.
4. Cópialo a `backend/models/best.pt`.

## 2. Servidor (Windows / PowerShell)
```powershell
cd backend
.\iniciar_servidor.ps1
```
La primera vez crea el entorno e instala dependencias (varios minutos, descarga PyTorch).
Manual: `py -3.12 -m venv .venv` → `.\.venv\Scripts\Activate.ps1` → `pip install -r requirements.txt`
→ `uvicorn app.main:app --host 0.0.0.0 --port 8000`. Usa Python 3.10–3.12 (no 3.13+).

- Salud: http://localhost:8000/health (debe decir `local:models/best.pt`)
- Dashboard: http://localhost:8000 · API: http://localhost:8000/docs
- Opcionales antes de arrancar: `$env:CONF_THRESHOLD="0.35"`, `$env:IMG_SIZE="640"`, `$env:MODEL_PATH="models/best.pt"`.

## 3. App móvil (Flutter)
```powershell
cd mobile
flutter create --platforms=android,ios --org com.reiter --project-name arandanos_plagas .
flutter pub get
```
`flutter create .` no pisa `lib/` ni `pubspec.yaml`. Después, los permisos:

**Android** – `android/app/src/main/AndroidManifest.xml`:
- antes de `<application`: `<uses-permission android:name="android.permission.INTERNET"/>`
- dentro de `<application`: `android:usesCleartextTraffic="true"` (solo desarrollo; en producción usar HTTPS)

**iOS** (Mac + Xcode) – `ios/Runner/Info.plist`, dentro del `<dict>`:
```xml
<key>NSCameraUsageDescription</key><string>Se usa la cámara para fotografiar fruta.</string>
<key>NSPhotoLibraryUsageDescription</key><string>Se usa la galería para analizar fotos.</string>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
```
Si el build falla por el NDK: instalar `ndk;28.2.13676358` desde Android Studio (SDK Manager > SDK Tools).
Ejecutar: `flutter run`. Si ya tienes tu carpeta `mobile` con `android/` e `ios/` funcionando, solo copia `lib/`.

## 4. Conectar celular y servidor (Ajustes de la app → *Guardar y probar*)
- **USB:** `adb reverse tcp:8000 tcp:8000` (adb en `%LOCALAPPDATA%\Android\Sdk\platform-tools\`) y URL `http://localhost:8000`.
- **Wi-Fi:** `http://IP-DE-LA-LAPTOP:8000` (`ipconfig` → IPv4). Misma red, perfil **privado**, y puerto abierto
  (PowerShell admin): `New-NetFirewallRule -DisplayName "API 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow`.
  Redes de instituciones suelen aislar dispositivos: usar hotspot del celular o USB.
- **Emulador Android:** `http://10.0.2.2:8000`.

## Limitaciones conocidas
- Sin modelo entrenado no hay detección; la calidad depende de fotos y etiquetas (≥150 cuadros por clase para prototipo).
- Captura recomendada: fondo liso mate, luz difusa constante, frutas separadas, objeto de referencia de tamaño.
- Sin autenticación ni HTTPS: no exponer a internet tal cual.
- Ultralytics YOLO usa licencia AGPL-3.0: para uso comercial cerrado revisar la licencia empresarial.
- No define aprobación/rechazo de lote: depende de las especificaciones de Reiter.
- El dashboard cuenta todo `arandano_danado` como "condición/dañado" hasta separar clases por defecto.

## Próximos pasos
Más fotos de campo y reentrenar · separar clases por defecto · medir calibre por geometría ·
autenticación + HTTPS + despliegue · reportes por lote.
