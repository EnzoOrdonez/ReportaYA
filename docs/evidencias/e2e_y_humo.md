# Resultados de pruebas E2E y de humo

## E2E sobre la web 1.1.2 (Playwright, backend local)

Fecha: 2026-11-27 00:17  |  Casos: 8  |  Fallos: 0  |  Errores: 0  |  Tiempo: 167.3 s

| Caso | Resultado | Tiempo (s) |
|---|---|---|
| test_e2e01_registro_y_primer_ingreso | Aprobado | 32.1 |
| test_e2e02_clave_incorrecta | Aprobado | 8.0 |
| test_e2e03_ciudadano_reporta | Aprobado | 25.1 |
| test_e2e04_operador_acepta_y_asigna | Aprobado | 24.4 |
| test_e2e05_tecnico_resuelve | Aprobado | 25.9 |
| test_e2e06_ciudadano_ve_resultado | Aprobado | 17.0 |
| test_e2e07_mapa_y_cierre_de_sesion | Aprobado | 17.0 |
| test_e2e08_operador_rechaza_con_motivo | Aprobado | 17.7 |

## Humo en produccion antes de publicar (1.1.1)

Fecha: 2026-11-27 00:16  |  Casos: 10  |  Fallos: 0  |  Errores: 0  |  Tiempo: 3.9 s

| Caso | Resultado | Tiempo (s) |
|---|---|---|
| test_h01_salud | Aprobado | 0.2 |
| test_h02_sin_token_401 | Aprobado | 0.4 |
| test_h03_token_invalido_401 | Aprobado | 0.4 |
| test_h04_login_inexistente_401 | Aprobado | 0.9 |
| test_h05_cors_web_permitida | Aprobado | 0.4 |
| test_h06_cors_origen_desconocido_rechazado | Aprobado | 0.3 |
| test_h07_http_redirige_a_https | Aprobado | 0.1 |
| test_h08_web_publicada | Aprobado | 0.4 |
| test_h09_version_web | Aprobado | 0.3 |
| test_h10_apk_publicado | Aprobado | 0.4 |

## Humo en produccion despues de publicar (1.1.2)

Fecha: 2026-11-27 00:42  |  Casos: 10  |  Fallos: 0  |  Errores: 0  |  Tiempo: 5.8 s

| Caso | Resultado | Tiempo (s) |
|---|---|---|
| test_h01_salud | Aprobado | 0.5 |
| test_h02_sin_token_401 | Aprobado | 0.7 |
| test_h03_token_invalido_401 | Aprobado | 1.1 |
| test_h04_login_inexistente_401 | Aprobado | 1.1 |
| test_h05_cors_web_permitida | Aprobado | 0.4 |
| test_h06_cors_origen_desconocido_rechazado | Aprobado | 0.4 |
| test_h07_http_redirige_a_https | Aprobado | 0.2 |
| test_h08_web_publicada | Aprobado | 0.4 |
| test_h09_version_web | Aprobado | 0.4 |
| test_h10_apk_publicado | Aprobado | 0.5 |
