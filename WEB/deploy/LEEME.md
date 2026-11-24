# Despliegue de Reiter en un VPS con Docker y Traefik

La plataforma corre en Docker **junto** a OpenClaw, usando el Traefik que ya ocupa los puertos 80/443 (no se
instala otro proxy ni se toca su configuración). Base de datos: Supabase. Fotos: Cloudinary.

| Contenedor | Qué hace | Tope |
|---|---|---|
| `reiter-web-1` | gunicorn: web + API `/api/v1` (migraciones al arrancar) | 700 MB · 0,8 CPU |
| `reiter-worker-1` | `worker_ia`: análisis de fotos y avisos | 1,2 GB · 0,7 CPU |

Aislamiento: usuario sin privilegios (uid 10001), sistema de archivos de solo lectura, sin capacidades de Linux,
`no-new-privileges`, red interna propia, logs de 10 MB × 3. Secretos solo en `deploy/.env.piloto` (permiso 600).

## Instalar (una vez)

```bash
mkdir -p /srv/reiter && tar -xzf /root/reiter-plataforma.tar.gz -C /srv/reiter
DOMINIO=reiter.example.com bash /srv/reiter/deploy/instalar.sh          # crea .env.piloto y se detiene
nano /srv/reiter/deploy/.env.piloto          # DATABASE_URL y CLOUDINARY_URL
DOMINIO=reiter.example.com bash /srv/reiter/deploy/instalar.sh          # construye, levanta y diagnostica
cd /srv/reiter/deploy && docker compose exec web python manage.py createsuperuser
```

## Día a día

```bash
cd /srv/reiter/deploy
docker compose ps                                   # estado
docker compose logs -f --tail 50 web worker         # consola (Ctrl+C para salir)
docker compose exec web python manage.py diagnostico
docker compose restart worker
bash actualizar.sh                                  # tras cambiar código o .env.piloto
```

Actualizar el código: subir un nuevo `reiter-plataforma.tar.gz` y
`tar -xzf /root/reiter-plataforma.tar.gz -C /srv/reiter && bash /srv/reiter/deploy/actualizar.sh`
(el `.env.piloto` y `modelos/` no vienen en el paquete, así que no se pisan).

## Modelos de IA

1. Copiar `modelo.onnx` a `/srv/reiter/deploy/modelos/` (`scp modelo.onnx root@IP:/srv/reiter/deploy/modelos/`).
2. En `/gestion/` → Modelos de IA: crear la configuración activa (clases, imgsz, umbrales).
3. Para inspección de arándanos en Flutter, usa un ONNX separado: copia `arandanos.onnx` en el mismo directorio y agrega `INSPECCION_MODEL_PATH=/app/modelos/arandanos.onnx` a `.env.piloto`.
4. Ejecuta `bash actualizar.sh`.

## Retirar al terminar el proyecto

`bash /srv/reiter/deploy/desinstalar.sh` → borra contenedores, imágenes y `/srv/reiter`. OpenClaw y Traefik
quedan intactos. Retira después el registro DNS de esta instancia.
