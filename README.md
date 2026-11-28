# ReportaYA

Sistema para reportar incidencias urbanas (huecos, alumbrado, residuos, seguridad) y seguir su atención municipal. Incluye una app en Flutter para tres roles (ciudadano, operador municipal y técnico de campo) y una API REST en Spring Boot con PostgreSQL.

Proyecto del curso Proyecto de Desarrollo de Software, Universidad de Lima, ciclo 2026-2. Versión 1.1.4.

## En funcionamiento

| Pieza | Dirección |
|---|---|
| App web (PC, iPhone, cualquier navegador) | https://enzoordonez.github.io/ReportaYA-App/ |
| App Android (APK firmado) | https://github.com/EnzoOrdonez/ReportaYA-App/releases/latest |
| API REST | https://reportaya-api-mcg4.onrender.com (estado en `/salud`) |

El backend corre en el plan gratis de Render: tras 15 minutos sin uso se apaga y tarda cerca de un minuto en volver. La app lo despierta al abrirse y avisa en el inicio de sesión.

## Estructura

```
app/        App Flutter (Dart, GetX, flutter_map + OpenStreetMap)
backend/    API Spring Boot 3.5 (Java 17, JPA, PostgreSQL, JWT, BCrypt)
docs/       Capturas de pantalla y evidencias de las pruebas
```

## Arquitectura

Cliente y servidor en capas. La app separa pantallas, controladores GetX (estado reactivo), servicios y un cliente HTTP único que agrega el token. La API separa controladores REST, servicios con las reglas de negocio, repositorios JPA y entidades; un interceptor valida el JWT y cada controlador comprueba el rol y el dueño del recurso con el token, nunca con datos del cuerpo.

Ciclo de un reporte: `PENDIENTE -> REVISION -> FINALIZADO`, o `PENDIENTE/REVISION -> RECHAZADO` con motivo. Cada cambio queda en `historial_estados`.

## Novedades de la 1.1.4

- Ubicación del equipo al crear un reporte (una vez, en primer plano y con permiso) y botón *Mi ubicación*; si se niega, se marca en el mapa (RF-04, RF-05).
- Aviso de alcance con los números 105, 116 y 106 (RF-20) y aviso de privacidad con aceptación registrada en la API (RF-21).
- Resumen antes de enviar, referencia opcional del lugar y fotos JPG o PNG de hasta 2 MB (HU-03, RNF-01).
- Recuperación con enlace al formulario web y código ligado al correo; 5 solicitudes por hora (HU-05).
- Bloqueo de 5 minutos tras 5 claves incorrectas y revocación del token al cerrar sesión o cambiar la contraseña (HU-02).
- Validaciones de HU-01 y HU-03: contraseña de 8 caracteres, nombres de 2 a 100, título de 5 a 100 y descripción de 20 a 1000.

## Ejecutar en local

Backend (Java 17 y PostgreSQL):

```bash
cd backend
psql -d reportaya -f db/crear-TABLAS.sql
psql -d reportaya -f db/llenar-TABLAS.sql      # datos de prueba, clave 123456
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/reportaya \
SPRING_DATASOURCE_USERNAME=postgres SPRING_DATASOURCE_PASSWORD=... \
JWT_SECRET=una_cadena_de_al_menos_32_caracteres APP_VERIFICAR_CORREO=false \
./mvnw spring-boot:run
```

App (Flutter 3.44):

```bash
cd app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8081/api
```

Las fotos de demostración del selector solo aparecen si se compila con `--dart-define=FOTOS_DEMO=true` (lo usan las pruebas E2E); la versión publicada exige una foto real.

Cuentas de prueba de `db/llenar-TABLAS.sql`: `ciudadano`, `op.maria` (operador) y `tec.carlos` (técnico). En producción esas cuentas usan otras claves.

## Pruebas

| Nivel | Herramienta | Resultado (v1.1.4) |
|---|---|---|
| Unitarias e integración del backend | JUnit 5, Mockito, MockMvc, H2 | 48 de 48 |
| Unitarias y de widgets de la app (incluye accesibilidad) | flutter_test | 46 de 46 |
| Sistema, caja negra sobre la API | pytest + requests | 66 de 66 |
| Extremo a extremo sobre la web | Playwright | 11 de 11 |
| Carga (50 usuarios, 60 s) | httpx asíncrono | p95 de 694 ms, 0 errores |
| Humo en producción (solo lectura) | pytest | 10 de 10 |

El detalle, la cobertura y los defectos encontrados están en [docs/PRUEBAS.md](docs/PRUEBAS.md).

## Seguridad del repositorio

Este repositorio no contiene claves ni credenciales: la llave de firma de Android, `key.properties`, los archivos `.env` y `application-local.properties` están fuera del control de versiones. Tampoco incluye flujos de GitHub Actions programados.

## Créditos

La aplicación nace de los repositorios del equipo: [jeffangeloss/ReportaYA-Front](https://github.com/jeffangeloss/ReportaYA-Front) y [Yotzuga/ReportaYA-Backend](https://github.com/Yotzuga/ReportaYA-Backend), con aportes de Mariel Casolda, Enzo Ordoñez, Jefferson Sánchez y Anthony Yance. Esta versión agrega las correcciones de seguridad, el despliegue en la nube, la campaña de pruebas, las mejoras de accesibilidad y las funciones de la 1.1.x.
