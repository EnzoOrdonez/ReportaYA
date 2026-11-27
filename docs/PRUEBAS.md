# Pruebas de ReportaYA

Campaña ejecutada el 26 y 27 de noviembre de 2026 sobre la versión desplegada (1.1.1) y sobre la versión corregida (1.1.2). Las pruebas que crean datos se ejecutaron en un entorno aislado (PostgreSQL 16 local con `db/llenar-TABLAS.sql`); contra producción solo se ejecutaron pruebas de humo de lectura.

## Niveles y herramientas

| Nivel | Qué verifica | Dónde |
|---|---|---|
| Unitarias | Reglas de negocio aisladas con dobles de prueba: ciclo de estados, validaciones, JWT, permisos, fotos | `backend/src/test/java/.../service`, `.../util`; `app/test/unit` |
| Integración | Contexto Spring completo (interceptor, controladores, servicios, JPA) sobre H2 en modo PostgreSQL | `backend/src/test/java/.../integracion` |
| Widgets | Formularios, texto al 200 %, pantalla de 360 x 640 dp y pautas de accesibilidad de Flutter | `app/test/widget` |
| Sistema (caja negra) | 59 casos sobre la API con partición de equivalencias, valores límite, tabla de decisión y transición de estados | `backend/pruebas/sistema` |
| Extremo a extremo | 8 flujos completos en la app web, a través del árbol de accesibilidad | `app/test_e2e` |
| Carga | RNF-06: 50 usuarios concurrentes durante 60 s | `backend/pruebas/carga` |
| Humo | Despliegue en la nube: salud, 401, CORS, HTTPS, versión web y release | `backend/pruebas/humo` |

## Resultados

| Nivel | v1.1.1 | v1.1.2 |
|---|---|---|
| JUnit (backend) | no tenía pruebas | 38 de 38 |
| flutter_test (app) | 26 de 29 | 31 de 31 |
| Sistema (API) | 52 de 55 | 59 de 59 |
| E2E (web) | no se ejecutó | 8 de 8 |
| Humo en producción | 10 de 10 | 10 de 10 |

Carga (v1.1.2, backend fijado a un núcleo de CPU y 512 MB de memoria, con el agente de JaCoCo activo): 10 959 consultas, 0 errores, p50 de 227 ms, p95 de 694 ms, p99 de 916 ms y 100 % de respuestas en 3 s o menos.

Cobertura de líneas del backend medida con JaCoCo: 53,9 % con JUnit, 63,9 % con las pruebas de sistema y E2E, y 65,0 % combinada (52,1 % de ramas).

## Defectos encontrados y corregidos

| ID | Hallazgo en 1.1.1 | Prueba que lo detectó | Corrección en 1.1.2 |
|---|---|---|---|
| D-01 | La API aceptaba un DNI con letras | CP-11 | `@Pattern` de 8 dígitos; también teléfono de 9 dígitos |
| D-02 | El técnico podía cerrar un reporte sin fotos (RF-11) | CP-47 | Entre 1 y 3 fotos en la API y en la app |
| D-03 | Una foto corrupta en el cierre respondía 500 | CP-48 | Responde 400 y la transacción se revierte |
| D-04 | Al finalizar, el técnico no volvía a su bandeja (y el operador tras rechazar) | E2E-05 | Navegación con `Navigator.pop` en lugar de `Get.back()` |
| D-05 | Cualquier cuenta con sesión podía leer las fotos y el historial de reportes ajenos (RNF-03, control de acceso roto) | Revisión de código; CP-58 y CP-59 fallaron contra la versión previa (57 de 59) | `RequestAuth.requireLecturaReporte` en detalle, fotos e historial; desplegado el 27/11/2026 |
| A-01 | Login con texto al 200 % se desbordaba 136 px | Widget | Pestañas flexibles de 48 dp |
| A-02 | Contraste insuficiente en enlaces y título (2,7:1 a 3,0:1) | Widget | Colores de texto con contraste AA |
| A-03 | Botones sin etiqueta para el lector de pantalla | Widget y E2E | Etiquetas y textos del sistema en español |

Entre la primera y la segunda ejecución también se corrigieron casos de prueba: CP-11 reutilizaba un DNI ya registrado, CP-42 leía el campo `tecnicoId` en lugar de `tecnicoAsignadoId` y CP-49 aceptaba 400 o 403 sin decirlo en el resultado esperado (ahora espera 400 y 403 y comprueba que el reporte no cambia). La prueba E2E-03 acepta la dirección o las coordenadas, porque Nominatim limita las consultas del servicio público.

## Pendientes conocidos

- Contraste de las etiquetas de estado: texto blanco sobre #FFA500 (1,97:1), #FF6B6B y #4CAF50 (2,78:1) y #9E9E9E (2,68:1), por debajo de 4,5:1.
- Prueba de aceptación con usuarios (RNF-07) y prueba en un dispositivo Android físico (RNF-05), sin ejecutar.
- Textos sin tilde: "Se notificara al ciudadano", "Contrasena restablecida con exito" y "Ubicacion seleccionada".

## Evidencias

- `evidencias/sistema_ejecucion1_v1.1.1.md` (52 de 55), `evidencias/sistema_ejecucion2_v1.1.2.md` (57 de 59, antes del parche de D-05) y `evidencias/sistema_ejecucion3_v1.1.2.md` (59 de 59): tabla caso por caso.
- `evidencias/flutter_ejecucion1_v1.1.1.txt` (26 de 29) y `evidencias/flutter_ejecucion2_v1.1.2.txt` (31 de 31).
- `evidencias/e2e_y_humo.md`: E2E y humo antes y después de publicar, y humo después del parche de D-05.
- `evidencias/carga_rnf06.json`: resultado de la prueba de carga.
- `capturas/`: pantallas tomadas por las pruebas E2E; `capturas/responsivo/` en 360, 412, 820 y 1366 px de ancho.
