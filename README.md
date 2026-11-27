# ReportaYA

Sistema para reportar incidencias urbanas (huecos, alumbrado, residuos, seguridad) y seguir su atención municipal. Incluye una app en Flutter para tres roles (ciudadano, operador municipal y técnico de campo) y una API REST en Spring Boot con PostgreSQL.

Proyecto del curso Proyecto de Desarrollo de Software, Universidad de Lima, ciclo 2026-2. Versión 1.1.2.

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

Cuentas de prueba de `db/llenar-TABLAS.sql`: `ciudadano`, `op.maria` (operador) y `tec.carlos` (técnico). En producción esas cuentas usan otras claves.

## Pruebas

| Nivel | Herramienta | Resultado (v1.1.2) |
|---|---|---|
| Unitarias e integración del backend | JUnit 5, Mockito, MockMvc, H2 | 37 de 37 |
| Unitarias y de widgets de la app (incluye accesibilidad) | flutter_test | 31 de 31 |
| Sistema, caja negra sobre la API | pytest + requests | 57 de 57 |
| Extremo a extremo sobre la web | Playwright | 8 de 8 |
| Carga (50 usuarios, 60 s) | httpx asíncrono | p95 de 694 ms, 0 errores |
| Humo en producción (solo lectura) | pytest | 10 de 10 |

El detalle, la cobertura y los defectos encontrados están en [docs/PRUEBAS.md](docs/PRUEBAS.md).

## Seguridad del repositorio

Este repositorio no contiene claves ni credenciales: la llave de firma de Android, `key.properties`, los archivos `.env` y `application-local.properties` están fuera del control de versiones. Tampoco incluye flujos de GitHub Actions programados.

## Créditos

La aplicación nace de los repositorios del equipo: [jeffangeloss/ReportaYA-Front](https://github.com/jeffangeloss/ReportaYA-Front) y [Yotzuga/ReportaYA-Backend](https://github.com/Yotzuga/ReportaYA-Backend), con aportes de Mariel Casolda, Enzo Ordoñez, Jefferson Sánchez y Anthony Yance. Esta versión agrega las correcciones de seguridad, el despliegue en la nube, la campaña de pruebas y las mejoras de accesibilidad de la 1.1.x.
