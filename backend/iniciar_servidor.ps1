# Uso (PowerShell, dentro de backend):  .\iniciar_servidor.ps1
Set-Location $PSScriptRoot
Set-ExecutionPolicy -Scope Process Bypass -Force
if (-not (Test-Path ".venv\Scripts\Activate.ps1")) { py -3.12 -m venv .venv }
. .\.venv\Scripts\Activate.ps1
if (-not (Test-Path ".venv\.instalado")) {
    python -m pip install --upgrade pip
    pip install -r requirements.txt
    New-Item ".venv\.instalado" -ItemType File | Out-Null
}
if (-not (Test-Path "models\best.pt")) { Write-Host "AVISO: falta models\best.pt (el modelo entrenado)." -ForegroundColor Yellow }
uvicorn app.main:app --host 0.0.0.0 --port 8000
