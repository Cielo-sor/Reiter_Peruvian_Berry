from io import BytesIO
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from PIL import Image
from rest_framework.test import APIClient

from cuentas.models import AccountStatus, Role
from ia.inference import DetectorNoDisponible

from .detector import jpeg
from .models import Inspeccion


class InspeccionesTests(TestCase):
    ruta = "/api/v1/inspecciones"

    def setUp(self):
        usuarios = get_user_model().objects
        self.operador = usuarios.create_user(email="operador@example.test", password="Clave-devel-123",
                                             status=AccountStatus.ACTIVO, roles=[Role.ESPECIALISTA_FITOSANITARIO])
        self.otro = usuarios.create_user(email="otro@example.test", password="Clave-devel-123",
                                        status=AccountStatus.ACTIVO)
        self.api = APIClient()

    def foto(self):
        foto = BytesIO()
        Image.new("RGB", (16, 16)).save(foto, "PNG")
        return SimpleUploadedFile("foto.png", foto.getvalue(), content_type="image/png")

    def test_historial_y_foto_son_privados(self):
        self.assertEqual(self.api.get(self.ruta).status_code, 401)
        self.api.force_authenticate(self.operador)
        caja = {"label": "arandano_danado", "category": "condicion", "confidence": 0.8}
        with patch("inspecciones.detector.analizar", side_effect=lambda imagen: ([caja], jpeg(imagen))):
            respuesta = self.api.post(self.ruta, {"file": self.foto(), "lote": "A1"})
        self.assertEqual(respuesta.status_code, 201)
        resultado = respuesta.json()
        self.assertEqual(resultado["defect_count"], 1)
        self.assertEqual(self.api.get(self.ruta).json(), [resultado])
        foto = self.api.get(resultado["annotated_url"])
        self.assertEqual(foto.status_code, 200)
        self.assertEqual(foto["Content-Type"], "image/jpeg")
        self.assertIn("no-store", foto["Cache-Control"])
        self.api.force_authenticate(self.otro)
        self.assertEqual(self.api.get(self.ruta).json(), [])
        self.assertEqual(self.api.get(resultado["annotated_url"]).status_code, 404)

    def test_error_de_foto_o_modelo_no_crea_registro(self):
        self.api.force_authenticate(self.operador)
        invalida = SimpleUploadedFile("foto.png", b"texto")
        self.assertEqual(self.api.post(self.ruta, {"file": invalida}).status_code, 400)
        with patch("inspecciones.detector.analizar", side_effect=DetectorNoDisponible()):
            self.assertEqual(self.api.post(self.ruta, {"file": self.foto()}).status_code, 503)
        self.assertFalse(Inspeccion.objects.exists())

    def test_login_renovacion_y_panel_web(self):
        dispositivo = "379681ec-9077-4185-a28a-c357c0f22dda"
        datos = {
            "email": self.operador.email, "password": "Clave-devel-123",
            "device": {"deviceId": dispositivo, "platform": "android",
                       "model": "", "osVersion": "", "appVersion": ""},
        }
        login = self.api.post("/api/v1/auth/login", datos, format="json")
        self.assertEqual(login.status_code, 200)
        renovacion = self.api.post("/api/v1/auth/refresh", {
            "refreshToken": login.json()["refreshToken"], "deviceId": dispositivo,
        }, format="json")
        self.assertEqual(renovacion.status_code, 200)
        self.api.credentials(HTTP_AUTHORIZATION=f'Bearer {renovacion.json()["accessToken"]}',
                             HTTP_X_DEVICE_ID=dispositivo)
        self.assertEqual(self.api.get(self.ruta).status_code, 200)
        self.client.force_login(self.operador)
        self.assertContains(self.client.get("/inspecciones/"), "Todavía no hay inspecciones.")
