# Pruebas de ReportaYA

Campaña ejecutada el 26 y 27 de noviembre de 2026 sobre la versión desplegada (1.1.1) y sobre la versión corregida (1.1.2). Las pruebas que crean datos se ejecutaron en un entorno aislado (PostgreSQL 16 local con `db/llenar-TABLAS.sql`); contra producción solo se ejecutaron pruebas de humo de lectura.

## Niveles y herramientas

| Nivel | Qué verifica | Dónde |
|---|---|---|
| Unitarias | Reglas de negocio aisladas con dobles de prueba: ciclo de estados, validaciones, JWT, permisos, fotos | `backend/src/test/java/.../service`, `.../util`; `app/test/unit` |
| Integración | Contexto Spring completo (interceptor, controladores, servicios, JPA) sobre H2 en modo PostgreSQL | `backend/src/test/java/.../integracion` |
| Widgets | Formularios, texto al 200 %, pantalla de 360 x 640 dp y pautas de accesibilidad de Flutter | `app/test/widget` |
| Sistema (caja negra) | 57 casos sobre la API con partición de equivalencias, valores límite, tabla de decisión y transición de estados | `backend/pruebas/sistema` |
| Extremo a extremo | 8 flujos completos en la app web, a través del árbol de accesibilidad | `app/test_e2e` |
| Carga | RNF-06: 50 usuarios concurrentes durante 60 s | `backend/pruebas/carga` |
| Humo | Despliegue en la nube: salud, 401, CORS, HTTPS, versión web y release | `backend/pruebas/humo` |

## Resultados

| Nivel | v1.1.1 | v1.1.2 |
|---|---|---|
| JUnit (backend) | no tenía pruebas | 37 de 37 |
| flutter_test (app) | 26 de 29 | 31 de 31 |
| Sistema (API) | 52 de 55 | 57 de 57 |
| E2E (web) | no se ejecutó | 8 de 8 |
| Humo en producción | 10 de 10 | 10 de 10 |

Carga (v1.1.2, backend fijado a un núcleo de CPU y 512 MB de memoria, con el agente de JaCoCo activo): 10 959 consultas, 0 errores, p50 de 227 ms, p95 de 694 ms, p99 de 916 ms y 100 % de respuestas en 3 s o menos.

Cobertura de líneas del backend medida con JaCoCo: 53,7 % con JUnit, 63,7 % con las pruebas de sistema y E2E, y 64,8 % combinada (51,2 % de ramas).

## Defectos encontrados y corregidos

| ID | Hallazgo en 1.1.1 | Prueba que lo detectó | Corrección en 1.1.2 |
|---|---|---|---|
| D-01 | La API aceptaba un DNI con letras | CP-11 | `@Pattern` de 8 dígitos; también teléfono de 9 dígitos |
| D-02 | El técnico podía cerrar un reporte sin fotos (RF-11) | CP-47 | Entre 1 y 3 fotos en la API y en la app |
| D-03 | Una foto corrupta en el cierre respondía 500 | CP-48 | Responde 400 y la transacción se revierte |
| D-04 | Al finalizar, el técnico no volvía a su bandeja (y el operador tras rechazar) | E2E-05 | Navegación con `Navigator.pop` en lugar de `Get.back()` |
| A-01 | Login con texto al 200 % se desbordaba 136 px | Widget | Pestañas flexibles de 48 dp |
| A-02 | Contraste insuficiente en enlaces y título (2,7:1 a 3,0:1) | Widget | Colores de texto con contraste AA |
| A-03 | Botones sin etiqueta para el lector de pantalla | Widget y E2E | Etiquetas y textos del sistema en español |

Entre la primera y la segunda ejecución también se corrigieron dos casos de prueba: CP-11 reutilizaba un DNI ya registrado y CP-42 leía el campo `tecnicoId` en lugar de `tecnicoAsignadoId`.

## Evidencias

- `evidencias/sistema_ejecucion1_v1.1.1.md` y `evidencias/sistema_ejecucion2_v1.1.2.md`: tabla caso por caso.
- `evidencias/e2e_y_humo.md`: E2E y humo antes y después de publicar.
- `evidencias/carga_rnf06.json`: resultado de la prueba de carga.
- `capturas/`: pantallas tomadas por las pruebas E2E; `capturas/responsivo/` en 360, 412, 820 y 1366 px de ancho.
