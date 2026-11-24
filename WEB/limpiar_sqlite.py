import os
from django.apps import apps
from django.db import transaction
from django.db.models.deletion import ProtectedError

# Orden preliminar de eliminación
TABLAS = [
    "notifications",
    "human_reviews",
    "review_cases",
    "detections",
    "ai_tasks",
    "quality_results",
    "captures",
    "monitoring_passes",
    "session_devices",
    "monitoring_sessions",
    "capture_sequences",
    "marker_changes",
    "markers",
    "field_segments",
    "field_rows",
    "field_lots",
    "deleted_captures",
    "deleted_sessions",
    "incidents",
]

USUARIOS_CONSERVAR = [
    "admin@demo.pe",
    "supervisor@demo.pe",
    "operador@demo.pe",
]

modelos = {
    modelo._meta.db_table: modelo
    for modelo in apps.get_models()
}

print("=== PRUEBA DE LIMPIEZA SQLITE ===")

try:
    with transaction.atomic():
        for tabla in TABLAS:
            modelo = modelos.get(tabla)

            if modelo is None:
                raise ValueError(
                    f"Tabla no encontrada: {tabla}"
                )

            cantidad = modelo.objects.count()
            print(f"Limpiando {tabla}: {cantidad}")

            modelo.objects.all().delete()

        User = apps.get_model("cuentas", "User")

        sobrantes = User.objects.exclude(
            email__in=USUARIOS_CONSERVAR
        )

        print(
            "Usuarios a eliminar:",
            sobrantes.count()
        )

        sobrantes.delete()

        print("Prueba completada correctamente.")

        if os.environ.get("CONFIRMAR_LIMPIEZA") == "SI":
            print("Limpieza confirmada. Se guardarán los cambios.")
        else:
            transaction.set_rollback(True)
            print("Modo simulación: cambios revertidos.")

except Exception as error:
    print("ERROR:", type(error).__name__)
    print(str(error)[:500])
    print("La transacción fue revertida.")
    raise
    
print("=== PROCESO FINALIZADO ===")