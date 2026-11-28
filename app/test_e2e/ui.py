"""Ayudas para manejar la version web de Flutter con Playwright a traves del arbol de accesibilidad."""
import os, re, time
from playwright.sync_api import sync_playwright, Page

WEB = os.environ.get("REPORTAYA_WEB", "http://127.0.0.1:8080/")
CHROME = os.environ.get("CHROME", "/usr/bin/google-chrome")


def abrir(p, ancho=412, alto=915, escala=2, ruta="", esperar="Iniciar Sesión", **ctx_kw):
    """ctx_kw pasa opciones al contexto, por ejemplo permissions=["geolocation"] y
    geolocation={...}. Sin permiso, Chromium rechaza la ubicación como un usuario que dice "No"."""
    proxy = os.environ.get("HTTPS_PROXY")
    nav = p.chromium.launch(executable_path=CHROME, args=["--no-sandbox"],
                            proxy={"server": proxy, "bypass": "localhost,127.0.0.1"} if proxy else None)
    ctx = nav.new_context(viewport={"width": ancho, "height": alto}, device_scale_factor=escala, locale="es-PE", **ctx_kw)
    pg = ctx.new_page()
    pg.goto(WEB + ruta, wait_until="networkidle")
    esperar_texto(pg, esperar, 60)
    return nav, pg


def activar_semantica(pg: Page):
    if pg.query_selector("flt-semantics-placeholder"):
        pg.evaluate("document.querySelector('flt-semantics-placeholder').click()")
        pg.wait_for_timeout(600)


def nodos(pg: Page):
    activar_semantica(pg)
    return pg.evaluate("""() => Array.from(document.querySelectorAll('flt-semantics, input, textarea')).map((e, i) => {
        const r = e.getBoundingClientRect();
        return {i: i, tag: e.tagName, role: e.getAttribute('role') || '', label: (e.getAttribute('aria-label') || '').trim(),
                text: Array.from(e.childNodes).filter(c => c.nodeType === 3 || (c.tagName && !c.tagName.startsWith('FLT-SEMANTICS')))
                        .map(c => c.textContent).join('').trim(), x: r.x + r.width / 2, y: r.y + r.height / 2,
                w: r.width, h: r.height};
    }).filter(n => n.w > 0 && n.h > 0)""")


def buscar(pg, texto, exacto=True, tag=None):
    for n in nodos(pg):
        val = n["label"] or n["text"]
        if tag and n["tag"] != tag:
            continue
        if (val == texto or val.split("\n")[0] == texto) if exacto else (texto.lower() in val.lower()):
            return n
    return None


def esperar_texto(pg, texto, seg=20, exacto=False):
    fin = time.time() + seg
    while time.time() < fin:
        try:
            if buscar(pg, texto, exacto):
                return True
        except Exception:
            pass
        pg.wait_for_timeout(400)
    raise AssertionError(f"No aparecio el texto: {texto}")


def tocar(pg, x, y):
    pg.mouse.move(x, y)
    pg.mouse.down()
    pg.wait_for_timeout(90)
    pg.mouse.up()
    pg.wait_for_timeout(600)


def desplazar(pg, dy=400):
    vp = pg.viewport_size
    # Borde izquierdo: fuera de mapas y otros elementos que capturan la rueda.
    pg.mouse.move(min(8, vp["width"] / 2), vp["height"] / 2)
    pg.mouse.wheel(0, dy)
    pg.wait_for_timeout(700)


def clic(pg, texto, exacto=True, intentos=5):
    """Activa el nodo accesible (boton, pestana, enlace) como lo haria un lector de pantalla.
    Si no esta en pantalla, desplaza la vista hacia abajo hasta encontrarlo."""
    n = buscar(pg, texto, exacto)
    for _ in range(intentos):
        if n:
            break
        desplazar(pg)
        n = buscar(pg, texto, exacto)
    assert n, f"No se encontro: {texto}"
    pg.evaluate("i => document.querySelectorAll('flt-semantics, input, textarea')[i].click()", n["i"])
    pg.wait_for_timeout(700)


def escribir(pg, etiqueta, valor):
    n = buscar(pg, etiqueta, exacto=False, tag="INPUT") or buscar(pg, etiqueta, exacto=False, tag="TEXTAREA")
    for _ in range(4):
        if n:
            break
        desplazar(pg, 300)
        n = buscar(pg, etiqueta, exacto=False, tag="INPUT") or buscar(pg, etiqueta, exacto=False, tag="TEXTAREA")
    assert n, f"No se encontro el campo: {etiqueta}"
    # Si el campo quedo detras de la barra inferior, se desplaza antes de tocarlo.
    alto = pg.viewport_size["height"]
    for _ in range(4):
        if n["y"] < alto - 140:
            break
        desplazar(pg, 250)
        n = buscar(pg, etiqueta, exacto=False, tag="INPUT") or buscar(pg, etiqueta, exacto=False, tag="TEXTAREA") or n
    tocar(pg, n["x"], n["y"])
    pg.keyboard.press("Control+A")
    pg.keyboard.type(valor, delay=5)
    pg.wait_for_timeout(250)


def foto(pg, ruta, avisos=False):
    """Captura la pantalla. Por defecto espera a que se cierren los avisos (3 s)."""
    pg.wait_for_timeout(900 if avisos else 3300)
    pg.screenshot(path=str(ruta))


def login(pg, usuario, clave):
    esperar_texto(pg, "Ingresa tu usuario", 30)
    pg.wait_for_timeout(500)
    escribir(pg, "Ingresa tu usuario", usuario)
    escribir(pg, "Ingresa tu contraseña", clave)
    n = [x for x in nodos(pg) if (x["label"] or x["text"]) == "Iniciar Sesión" and x["role"] == "button"]
    pg.evaluate("i => document.querySelectorAll('flt-semantics, input, textarea')[i].click()", n[-1]["i"])
