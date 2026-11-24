#!/usr/bin/env bash
# deploy/actualizar.sh — Aplica cambios del código o de deploy/.env.piloto: reconstruye y reinicia web + worker.
# Las migraciones se aplican solas al arrancar la web.   bash /srv/reiter/deploy/actualizar.sh
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { echo "Primero ejecuta instalar.sh"; exit 1; }
docker compose build web
docker compose up -d --remove-orphans || true   # si la web falla, abajo se muestran sus mensajes
echo "Esperando a la web..."
for i in $(seq 1 40); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' reiter-web-1 2>/dev/null)" = "healthy" ] && break
  sleep 5
done
if [ "$(docker inspect -f '{{.State.Health.Status}}' reiter-web-1 2>/dev/null)" != "healthy" ]; then
  docker compose logs --tail 60 web
  echo "La web no arrancó: revisa el mensaje de arriba."; exit 1
fi
docker compose ps
docker compose exec -T web python manage.py diagnostico --sin-color || true
