from django.conf import settings
from django.db import models


class Inspeccion(models.Model):
    usuario = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    creada = models.DateTimeField(auto_now_add=True)
    lote = models.CharField(max_length=120, blank=True)
    detecciones = models.JSONField(default=list)
    original = models.BinaryField()
    anotada = models.BinaryField()

    class Meta:
        ordering = ["-id"]
