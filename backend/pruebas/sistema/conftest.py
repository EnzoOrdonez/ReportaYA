"""Pruebas de sistema (caja negra) de la API de ReportaYA.

Se ejecutan contra un backend en marcha con los datos de db/llenar-TABLAS.sql:
    REPORTAYA_URL=http://127.0.0.1:8081 pytest pruebas/sistema -q

Crean datos, por eso NO deben ejecutarse contra produccion.
Cada caso declara su identificador, la tecnica de diseno y el requisito que verifica;
al terminar se escriben resultados.csv y resultados.md en pruebas/sistema/reportes/.
"""
import base64, csv, os, random, string, subprocess, time
from pathlib import Path
import pytest, requests

URL = os.environ.get("REPORTAYA_URL", "http://127.0.0.1:8081").rstrip("/")
API = URL + "/api"
CLAVE_SEMILLA = os.environ.get("REPORTAYA_CLAVE_SEMILLA", "123456")
IMG = Path(os.environ.get("REPORTAYA_IMG", Path(__file__).resolve().parents[2] / "assets" / "img" / "Incidencia01.png"))
SALIDA = Path(__file__).parent / "reportes"
_REG = []


def caso(cid, tecnica, requisito, descripcion, esperado):
    def deco(f):
        f._caso = dict(id=cid, tecnica=tecnica, requisito=requisito, descripcion=descripcion, esperado=esperado)
        return f
    return deco


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    out = yield
    rep = out.get_result()
    meta = getattr(item.function, "_caso", None)
    if meta and (rep.when == "call" or (rep.when == "setup" and rep.outcome != "passed")):
        obtenido = getattr(item, "_obtenido", "")
        if rep.failed and not obtenido:
            obtenido = str(rep.longrepr).splitlines()[-1][:160]
        _REG.append({**meta, "obtenido": obtenido, "resultado": "Aprobado" if rep.passed else "Fallido",
                     "duracion_s": f"{rep.duration:.2f}"})


def pytest_sessionfinish(session, exitstatus):
    if not _REG:
        return
    SALIDA.mkdir(exist_ok=True)
    filas = sorted(_REG, key=lambda r: int(r["id"].split("-")[1]))
    with open(SALIDA / "resultados.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(filas[0].keys()))
        w.writeheader(); w.writerows(filas)
    ok = sum(r["resultado"] == "Aprobado" for r in filas)
    with open(SALIDA / "resultados.md", "w", encoding="utf-8") as fh:
        fh.write(f"# Pruebas de sistema ReportaYA\n\nBackend: {URL}\nFecha: {time.strftime('%Y-%m-%d %H:%M')}\n\n")
        fh.write(f"Aprobados {ok} de {len(filas)}\n\n| ID | Requisito | Tecnica | Caso | Esperado | Obtenido | Resultado |\n|---|---|---|---|---|---|---|\n")
        for r in filas:
            fh.write(f"| {r['id']} | {r['requisito']} | {r['tecnica']} | {r['descripcion']} | {r['esperado']} | {r['obtenido']} | {r['resultado']} |\n")


# ---------------------------------------------------------------- utilidades
def sufijo(n=6):
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=n))


def dni_unico():
    return "".join(random.choices(string.digits, k=8))


def login(usuario, clave):
    return requests.post(f"{API}/auth/login", json={"usuario": usuario, "password": clave}, timeout=30)


def token(usuario, clave=CLAVE_SEMILLA):
    r = login(usuario, clave)
    assert r.status_code == 200, r.text
    return r.json()


def h(tok):
    return {"Authorization": f"Bearer {tok}"}


def cuerpo_registro(**kw):
    s = sufijo()
    base = dict(usuario=f"u{s}", contrasena="Clave123", nombres="Prueba", apellidos="Sistema",
                dni=dni_unico(), telefono="987654321", correo=f"u{s}@prueba.pe", tipoCuenta="CIUDADANO",
                aceptaPrivacidad=True)
    base.update(kw)
    return base


def registrar(**kw):
    b = cuerpo_registro(**kw)
    r = requests.post(f"{API}/cuenta", json=b, timeout=30)
    return r, b


def ciudadano_nuevo():
    r, b = registrar()
    assert r.status_code == 201, r.text
    s = token(b["usuario"], b["contrasena"])
    return {"id": s["cuentaId"] if "cuentaId" in s else s["id"], "token": s["token"], "datos": b}


def cuerpo_reporte(**kw):
    base = dict(titulo="Poste caido en la vereda", descripcion="Poste de alumbrado inclinado sobre la vereda, riesgo para peatones.",
                tipoProblema="ALUMBRADO", ubicacion={"latitud": -12.0853, "longitud": -77.0376, "direccion": "Av. Arequipa 1234, Lince"})
    base.update(kw)
    return base


def crear_reporte(tok, **kw):
    return requests.post(f"{API}/reportes", json=cuerpo_reporte(**kw), headers=h(tok), timeout=30)


def img_b64():
    return base64.b64encode(IMG.read_bytes()).decode()


def sql(q):
    """Consulta de apoyo (caja gris) a la base del entorno de pruebas."""
    cmd = ["psql", "-h", os.environ.get("PGHOST", "127.0.0.1"), "-p", os.environ.get("PGPORT", "5433"),
           "-U", os.environ.get("PGUSER", "postgres"), "-d", os.environ.get("PGDATABASE", "reportaya"), "-At", "-c", q]
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.strip()


@pytest.fixture(scope="session")
def op():
    return token("op.maria")


@pytest.fixture(scope="session")
def tec():
    return token("tec.carlos")


@pytest.fixture(scope="session")
def tec2():
    return token("tec.lucia")


@pytest.fixture
def ciu():
    return ciudadano_nuevo()


@pytest.fixture
def ciu2():
    return ciudadano_nuevo()
