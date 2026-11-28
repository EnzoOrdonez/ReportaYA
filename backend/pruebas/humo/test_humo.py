"""Pruebas de humo del despliegue en la nube. Solo lectura: no crean ni modifican datos.
    REPORTAYA_URL=https://reportaya-api-mcg4.onrender.com REPORTAYA_WEB=https://enzoordonez.github.io/ReportaYA-App/ \
    REPORTAYA_VERSION=1.1.2 pytest pruebas/humo -v"""
import random
import os, time
import requests

URL = os.environ.get("REPORTAYA_URL", "https://reportaya-api-mcg4.onrender.com").rstrip("/")
WEB = os.environ.get("REPORTAYA_WEB", "https://enzoordonez.github.io/ReportaYA-App/")
VERSION = os.environ.get("REPORTAYA_VERSION")
ORIGEN_WEB = "https://" + WEB.split("/")[2]


def test_h01_salud():
    t0 = time.time(); r = requests.get(f"{URL}/salud", timeout=150)
    print(f"salud en {time.time() - t0:.2f} s")
    assert r.status_code == 200 and r.json() == {"estado": "ok", "base": "ok"}


def test_h02_sin_token_401():
    assert requests.get(f"{URL}/api/reportes", timeout=60).status_code == 401


def test_h03_token_invalido_401():
    assert requests.get(f"{URL}/api/reportes/mapa", headers={"Authorization": "Bearer x.y.z"}, timeout=60).status_code == 401


def test_h04_login_inexistente_401():
    r = requests.post(f"{URL}/api/auth/login", json={"usuario": f"humo_no_existe_{random.randint(10**5, 10**6)}", "password": "no-es-clave"}, timeout=60)
    assert r.status_code == 401 and "error" in r.json()


def test_h05_cors_web_permitida():
    r = requests.options(f"{URL}/api/reportes", headers={"Origin": ORIGEN_WEB, "Access-Control-Request-Method": "GET"}, timeout=60)
    assert r.headers.get("Access-Control-Allow-Origin") == ORIGEN_WEB


def test_h06_cors_origen_desconocido_rechazado():
    r = requests.options(f"{URL}/api/reportes", headers={"Origin": "https://sitio-desconocido.example", "Access-Control-Request-Method": "GET"}, timeout=60)
    assert r.status_code == 403 and "Access-Control-Allow-Origin" not in r.headers


def test_h07_http_redirige_a_https():
    r = requests.get(URL.replace("https://", "http://") + "/salud", allow_redirects=False, timeout=60)
    assert r.status_code in (301, 302, 307, 308) and r.headers["Location"].startswith("https://")


def test_h08_web_publicada():
    r = requests.get(WEB, timeout=60)
    assert r.status_code == 200 and "<title>ReportaYA</title>" in r.text


def test_h09_version_web():
    v = requests.get(WEB.rstrip("/") + "/version.json", timeout=60).json()
    print("version web:", v)
    if VERSION:
        assert v["version"] == VERSION


def test_h10_apk_publicado():
    """La etiqueta de la version existe en el repositorio de la app (el flujo de publicacion crea el release)."""
    import subprocess
    repo = os.environ.get("REPORTAYA_REPO_APP", "https://github.com/EnzoOrdonez/ReportaYA-App")
    tags = subprocess.run(["git", "ls-remote", "--tags", repo], capture_output=True, text=True, timeout=120).stdout
    print("etiquetas:", sorted({l.split("refs/tags/")[1] for l in tags.splitlines() if "refs/tags/" in l}))
    assert f"refs/tags/v{VERSION or ''}" in tags
