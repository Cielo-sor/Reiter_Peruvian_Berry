# REITER PERUVIAN BERRY S.A.
## Sistema Cloud de Monitoreo de Calidad de Arándanos

### Descripción del proyecto

Proyecto académico orientado al desarrollo de una plataforma web para el monitoreo de muestras de arándanos en Reiter Peruvian Berry S.A.

El sistema busca facilitar la supervisión de las capturas realizadas en casetas, la consulta de registros y la visualización de resultados relacionados con defectos de calidad y condición de los frutos.

### Tecnologías utilizadas

- **Backend:** Python y Django.
- **Frontend:** HTML, CSS y JavaScript.
- **Base de datos local:** SQLite.
- **Inteligencia artificial:** integración prevista con un modelo de detección basado en YOLO.
- **Control de versiones:** Git y GitHub.

### Módulos de la plataforma web

1. **Inicio de sesión:** acceso a la plataforma mediante cuentas de usuario.
2. **Dashboard:** indicadores generales del monitoreo.
3. **Monitoreo:** seguimiento de capturas y frecuencia de muestreo por caseta.
4. **Registros:** consulta de información e historial.
5. **Módulos y casetas:** organización de los puntos de muestreo.
6. **Detecciones:** visualización de resultados y clasificación de defectos.
7. **Reportes:** presentación de información resumida.
8. **Usuarios:** administración de cuentas y roles.
9. **Configuración:** opciones del sistema y cambio de contraseña.

### Estado actual del desarrollo

Se ha avanzado en la adaptación visual de la plataforma web existente al proceso de monitoreo de arándanos.

La integración funcional con la aplicación móvil, la detección real mediante inteligencia artificial y los servicios Cloud deben verificarse e implementarse según el avance del proyecto.

### Ejecución local

**1. Crear un entorno virtual**

```powershell
python -m venv .venv
```

**2. Activar el entorno virtual en Windows**

```powershell
.\.venv\Scripts\Activate.ps1
```

**3. Instalar dependencias**

```powershell
pip install -r requirements.txt
```

**4. Configurar las variables de entorno**

Tomar como referencia `.env.example` y crear la configuración local necesaria.

**5. Aplicar las migraciones**

```powershell
python manage.py migrate
```

**6. Iniciar el servidor**

```powershell
python manage.py runserver
```

Acceder desde el navegador a:

`http://127.0.0.1:8000/`

### Consideraciones

La base de datos SQLite local, los respaldos y las credenciales privadas no se incluyen en el repositorio.

El proyecto se encuentra en desarrollo y algunas funcionalidades pueden utilizar datos simulados.

### Proyecto académico

**Reiter Peruvian Berry S.A. — Sistema Cloud de Monitoreo de Calidad de Arándanos.**