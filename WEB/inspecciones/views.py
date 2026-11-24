import logging

from django.http import HttpResponse
from django.shortcuts import get_object_or_404, render
from django.urls import reverse
from PIL import Image
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from api.errors import ApiError
from ia.inference import DetectorNoDisponible, abrir_imagen
from web.permissions import web_view

from . import detector
from .models import Inspeccion


log = logging.getLogger(__name__)


class FotoSerializer(serializers.Serializer):
    file = serializers.FileField()
    lote = serializers.CharField(required=False, allow_blank=True, max_length=120)


def _foto(registro, variante):
    respuesta = HttpResponse(getattr(registro, variante), content_type="image/jpeg")
    respuesta["Cache-Control"] = "private, no-store"
    return respuesta


def _resultado(registro):
    condicion = sum(d["category"] == "condicion" for d in registro.detecciones)
    calidad = sum(d["category"] == "calidad" for d in registro.detecciones)
    return {
        "id": registro.pk, "created_at": registro.creada.isoformat(), "lote": registro.lote,
        "defect_count": condicion + calidad, "condition_count": condicion, "quality_count": calidad,
        "detections": registro.detecciones,
        "image_url": reverse("api:inspeccion_imagen", args=[registro.pk, "original"]),
        "annotated_url": reverse("api:inspeccion_imagen", args=[registro.pk, "anotada"]),
    }


class InspeccionesView(APIView):
    parser_classes = [MultiPartParser]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "inspecciones"

    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        if request.user.must_change_password:
            raise ApiError("FORBIDDEN", 403, "Cambia tu contraseña temporal antes de inspeccionar.")

    @extend_schema(operation_id='inspecciones_list', responses=OpenApiTypes.OBJECT)
    def get(self, request):
        registros = Inspeccion.objects.filter(usuario=request.user).defer("original", "anotada")
        return Response([_resultado(r) for r in registros[:100]])

    @extend_schema(request=FotoSerializer, responses={201: OpenApiTypes.OBJECT})
    def post(self, request):
        formulario = FotoSerializer(data=request.data)
        formulario.is_valid(raise_exception=True)
        foto = formulario.validated_data["file"]
        if foto.size > 10 * 1024 * 1024:
            raise ApiError("VALIDATION_ERROR", 413, "La foto supera los 10 MB.")
        try:
            with Image.open(foto) as datos:
                if datos.width * datos.height > 25_000_000 or datos.format not in {"JPEG", "PNG", "WEBP"}:
                    raise ValueError("Formato o tamaño no admitido")
                foto.seek(0)
                imagen = abrir_imagen(foto.read())
        except (OSError, ValueError, Image.DecompressionBombError) as exc:
            raise ApiError("VALIDATION_ERROR", 400, "Usa una foto JPEG, PNG o WebP de hasta 25 megapíxeles.") from exc
        try:
            detecciones, anotada = detector.analizar(imagen)
        except DetectorNoDisponible as exc:
            raise ApiError("INTERNAL_ERROR", 503, "El modelo de inspección no está disponible.") from exc
        except Exception as exc:
            log.exception("Falló la inferencia de inspección")
            raise ApiError("INTERNAL_ERROR", 500, "No se pudo analizar la foto.") from exc
        registro = Inspeccion.objects.create(
            usuario=request.user, lote=formulario.validated_data.get("lote", ""),
            detecciones=detecciones, original=detector.jpeg(imagen), anotada=anotada,
        )
        return Response(_resultado(registro), status=201)


class ImagenView(APIView):
    @extend_schema(operation_id='inspecciones_imagen', responses={(200, 'image/jpeg'): OpenApiTypes.BINARY})
    def get(self, request, pk, variante):
        if request.user.must_change_password:
            raise ApiError("FORBIDDEN", 403, "Cambia tu contraseña temporal.")
        registro = get_object_or_404(Inspeccion.objects.only(variante), pk=pk, usuario=request.user)
        return _foto(registro, variante)


@web_view("inspecciones.ver")
def historial_web(request):
    registros = Inspeccion.objects.select_related("usuario").defer("original", "anotada")[:100]
    return render(request, "web/inspecciones.html", {"registros": registros})


@web_view("inspecciones.ver")
def imagen_web(request, pk):
    return _foto(get_object_or_404(Inspeccion.objects.only("anotada"), pk=pk), "anotada")
