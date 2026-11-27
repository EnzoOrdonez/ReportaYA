"""Pruebas de extremo a extremo (E2E) sobre la version web compilada de ReportaYA.

Requisitos: backend local con db/llenar-TABLAS.sql y la web servida, por ejemplo:
    flutter build web --release --dart-define=API_BASE_URL=http://localhost:8081/api
    python -m http.server 8080 --directory build/web
    REPORTAYA_WEB=http://127.0.0.1:8080/ pytest test_e2e -v
Cada prueba guarda capturas en test_e2e/capturas/. Las pruebas comparten estado y van en orden.
"""
import os, random, string, time
from pathlib import Path
import pytest
from ui import (sync_playwright, abrir, activar_semantica, nodos, buscar, esperar_texto, clic, escribir, foto, login, tocar, desplazar)

CAP = Path(__file__).parent / "capturas"; CAP.mkdir(exist_ok=True)
S = "".join(random.choices(string.ascii_lowercase, k=4))
DATOS = {"usuario": f"vecino{S}", "clave": "Clave123", "titulo": f"Poste apagado {S.upper()}"}
CLAVE_SEMILLA = os.environ.get("REPORTAYA_CLAVE_SEMILLA", "123456")


@pytest.fixture(scope="module")
def p():
    with sync_playwright() as pw:
        yield pw


def nueva(p, **kw):
    nav, pg = abrir(p, **kw)
    return nav, pg


def por_tam(pg, w, h, tol=4):
    return [n for n in nodos(pg) if abs(n["w"] - w) <= tol and abs(n["h"] - h) <= tol]


def clic_nodo(pg, n):
    pg.evaluate("i => document.querySelectorAll('flt-semantics, input, textarea')[i].click()", n["i"])
    pg.wait_for_timeout(800)


def agregar_foto_demo(pg):
    clic(pg, "Agregar foto")
    clic(pg, "Usar foto de demo")
    clic(pg, "Foto de demo 1")


def test_e2e01_registro_y_primer_ingreso(p):
    """RF-01 / HU-01: un vecino crea su cuenta desde la app y entra con ella."""
    nav, pg = nueva(p)
    foto(pg, CAP / "01_login.png")
    clic(pg, "Registrarse")
    esperar_texto(pg, "Crear cuenta")
    for etiqueta, valor in [("Nombres", "Rosa"), ("Apellidos", "Huaman"), ("DNI", str(random.randint(10000000, 99999999))),
                            ("Teléfono", "987654321"), ("Correo", f"{DATOS['usuario']}@prueba.pe"),
                            ("Usuario", DATOS["usuario"]), ("Contraseña", DATOS["clave"])]:
        escribir(pg, etiqueta, valor)
    foto(pg, CAP / "02_registro.png")
    n = [x for x in nodos(pg) if (x["label"] or x["text"]) == "Registrarse" and x["role"] == "button"]
    clic_nodo(pg, n[-1])
    esperar_texto(pg, "Iniciar Sesión", 20)
    login(pg, DATOS["usuario"], DATOS["clave"])
    esperar_texto(pg, "Rosa Huaman", 30)
    foto(pg, CAP / "03_inicio_ciudadano.png")
    nav.close()


def test_e2e02_clave_incorrecta(p):
    """RF-02: con una clave incorrecta la app avisa y no entra."""
    nav, pg = nueva(p)
    login(pg, DATOS["usuario"], "otra-clave")
    esperar_texto(pg, "Usuario o contraseña inválidos", 20)
    foto(pg, CAP / "04_login_error.png", avisos=True)
    assert buscar(pg, "Iniciar Sesión")
    nav.close()


def test_e2e03_ciudadano_reporta(p):
    """RF-19, RF-05, RF-06 / HU-03 y HU-17: crear un reporte con punto en el mapa y una foto."""
    nav, pg = nueva(p)
    login(pg, DATOS["usuario"], DATOS["clave"])
    esperar_texto(pg, "Reportar Incidencia", 30)
    clic(pg, "Reportar")
    esperar_texto(pg, "Enviar reporte")
    escribir(pg, "Ej. Hueco en la pista", DATOS["titulo"])
    clic(pg, "Alumbrado")
    escribir(pg, "Describe la incidencia", "El poste de la esquina del parque está apagado desde hace tres noches.")
    mapa = buscar(pg, "Mapa. Toca para marcar", exacto=False)
    tocar(pg, mapa["x"] + 25, mapa["y"] + 15)
    # Con Nominatim disponible aparece la direccion ("Lima, Lima"); si el servicio publico
    # limita las consultas, la app muestra las coordenadas y el reporte se puede enviar igual.
    fin = time.time() + 30
    while time.time() < fin and not (buscar(pg, "Lima", exacto=False) or buscar(pg, "Ubicacion seleccionada", exacto=False)):
        pg.wait_for_timeout(400)
    assert buscar(pg, "Lima", exacto=False) or buscar(pg, "Ubicacion seleccionada", exacto=False), "El punto marcado no muestra direccion ni coordenadas"
    clic(pg, "Enviar reporte")
    esperar_texto(pg, "Adjunta al menos una foto", 10)
    agregar_foto_demo(pg)
    pg.wait_for_timeout(800)
    foto(pg, CAP / "05_reportar.png")
    clic(pg, "Enviar reporte")
    esperar_texto(pg, "Mis Reportes", 30)
    esperar_texto(pg, DATOS["titulo"], 30)
    foto(pg, CAP / "06_mis_reportes.png", avisos=True)
    n = buscar(pg, DATOS["titulo"], exacto=False)
    assert "PENDIENTE" in (n["label"] or n["text"]).upper()
    nav.close()


def test_e2e04_operador_acepta_y_asigna(p):
    """RF-07 y RF-08 / HU-04 y HU-10: el operador acepta el reporte y asigna un tecnico."""
    nav, pg = nueva(p)
    login(pg, "op.maria", CLAVE_SEMILLA)
    esperar_texto(pg, "COLA DE REPORTES", 30)
    esperar_texto(pg, DATOS["titulo"], 30)
    foto(pg, CAP / "07_operador_cola.png")
    clic(pg, DATOS["titulo"], exacto=False)
    esperar_texto(pg, "Aceptar reporte", 20)
    foto(pg, CAP / "08_operador_gestion.png")
    clic(pg, "Aceptar reporte")
    esperar_texto(pg, "Asignar Técnico", 20)
    clic(pg, "Asignar Técnico")
    esperar_texto(pg, "Carlos Mendoza", 20)
    foto(pg, CAP / "09_operador_asignar.png")
    clic(pg, "Carlos Mendoza", exacto=False)
    esperar_texto(pg, "Técnico asignado: Carlos Mendoza", 20)
    foto(pg, CAP / "10_operador_asignado.png")
    nav.close()


def test_e2e05_tecnico_resuelve(p):
    """RF-09 y RF-11 / HU-11 y HU-12: el tecnico documenta la solucion y cierra el reporte."""
    nav, pg = nueva(p)
    login(pg, "tec.carlos", CLAVE_SEMILLA)
    esperar_texto(pg, "MIS ASIGNACIONES", 30)
    esperar_texto(pg, DATOS["titulo"], 30)
    foto(pg, CAP / "11_tecnico_tareas.png")
    clic(pg, DATOS["titulo"], exacto=False)
    esperar_texto(pg, "Iniciar trabajo de campo", 20)
    clic(pg, "Iniciar trabajo de campo")
    esperar_texto(pg, "Finalizar reporte", 20)
    escribir(pg, "Describe el trabajo realizado", "Se cambió la luminaria y se verificó el encendido.")
    clic(pg, "Finalizar reporte")
    esperar_texto(pg, "Adjunta al menos una foto", 10)
    agregar_foto_demo(pg)
    foto(pg, CAP / "12_tecnico_evidencia.png")
    clic(pg, "Finalizar reporte")
    esperar_texto(pg, "Reporte finalizado", 30)
    esperar_texto(pg, "MIS ASIGNACIONES", 30)
    # La seccion RESUELTOS va despues de todas las asignaciones abiertas; con una base
    # que ya paso por la suite de sistema puede haber decenas, asi que se recorre la lista.
    for _ in range(40):
        n = buscar(pg, DATOS["titulo"], exacto=False)
        if n and "FINALIZADO" in (n["label"] or n["text"]).upper():
            break
        desplazar(pg, 600)
    assert n and "FINALIZADO" in (n["label"] or n["text"]).upper()
    foto(pg, CAP / "13_tecnico_resuelto.png")
    nav.close()


def test_e2e06_ciudadano_ve_resultado(p):
    """RF-13 / HU-07: el ciudadano ve su reporte finalizado con evidencia y cronologia."""
    nav, pg = nueva(p)
    login(pg, DATOS["usuario"], DATOS["clave"])
    esperar_texto(pg, "Reportar Incidencia", 30)
    clic(pg, "Mis reportes")
    esperar_texto(pg, DATOS["titulo"], 30)
    n = buscar(pg, DATOS["titulo"], exacto=False)
    assert "FINALIZADO" in (n["label"] or n["text"]).upper()
    clic(pg, DATOS["titulo"], exacto=False)
    esperar_texto(pg, "CRONOLOGÍA", 20)
    esperar_texto(pg, "Fotos de resolución", 20)
    foto(pg, CAP / "14_detalle_finalizado.png")
    desplazar(pg, 900)
    foto(pg, CAP / "15_detalle_cronologia.png")
    nav.close()


def test_e2e07_mapa_y_cierre_de_sesion(p):
    """RF-15 / HU-08 y RF-02: mapa con leyenda y cierre de sesion."""
    nav, pg = nueva(p)
    login(pg, DATOS["usuario"], DATOS["clave"])
    esperar_texto(pg, "Reportar Incidencia", 30)
    clic(pg, "Mapa")
    esperar_texto(pg, "Mapa de incidencias", 20)
    pg.wait_for_timeout(3500)
    foto(pg, CAP / "16_mapa.png")
    clic(pg, "Inicio")
    clic(pg, "Cerrar sesión")
    esperar_texto(pg, "Iniciar Sesión", 20)
    nav.close()


def test_e2e08_operador_rechaza_con_motivo(p):
    """RF-07 / HU-04: el operador rechaza un reporte con motivo y vuelve a la cola."""
    import requests
    api = os.environ.get("REPORTAYA_API", "http://127.0.0.1:8081/api")
    tok = requests.post(f"{api}/auth/login", json={"usuario": DATOS["usuario"], "password": DATOS["clave"]}, timeout=30).json()["token"]
    titulo = f"Duplicado {S.upper()}"
    rid = requests.post(f"{api}/reportes", headers={"Authorization": f"Bearer {tok}"}, timeout=30, json={
        "titulo": titulo, "descripcion": "Reporte repetido para probar el rechazo.", "tipoProblema": "OTRO",
        "ubicacion": {"latitud": -12.07, "longitud": -77.05}}).json()["id"]
    nav, pg = nueva(p)
    login(pg, "op.maria", CLAVE_SEMILLA)
    esperar_texto(pg, titulo, 30)
    clic(pg, titulo, exacto=False)
    clic(pg, "Rechazar reporte")
    escribir(pg, "Motivo del rechazo", "Duplicado de un reporte ya registrado en la misma esquina.")
    foto(pg, CAP / "17_operador_rechazo.png")
    clic(pg, "Confirmar rechazo")
    esperar_texto(pg, "COLA DE REPORTES", 20)
    d = requests.get(f"{api}/reportes/{rid}", headers={"Authorization": f"Bearer {tok}"}, timeout=30).json()
    assert d["estado"] == "RECHAZADO" and d["comentarioResolucion"].startswith("Duplicado")
    nav.close()
