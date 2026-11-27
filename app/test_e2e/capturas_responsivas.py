"""Capturas de las mismas pantallas en cuatro tamanos para documentar el diseno responsivo."""
import sys
from pathlib import Path
from ui import sync_playwright, abrir, login, esperar_texto, clic, foto

SAL = Path(__file__).parent / "capturas" / "responsivo"; SAL.mkdir(parents=True, exist_ok=True)
TAMANOS = {"movil_360x640": (360, 640, 2), "movil_412x915": (412, 915, 2), "tablet_820x1180": (820, 1180, 1), "escritorio_1366x768": (1366, 768, 1)}

with sync_playwright() as p:
    for nombre, (w, h, esc) in TAMANOS.items():
        nav, pg = abrir(p, ancho=w, alto=h, escala=esc)
        foto(pg, SAL / f"{nombre}_login.png")
        login(pg, "ciudadano", "123456")
        esperar_texto(pg, "Reportar Incidencia", 30)
        foto(pg, SAL / f"{nombre}_inicio.png")
        clic(pg, "Reportar")
        esperar_texto(pg, "Tipo de problema")
        foto(pg, SAL / f"{nombre}_reportar.png")
        nav.close()
        nav, pg = abrir(p, ancho=w, alto=h, escala=esc)
        login(pg, "op.maria", "123456")
        esperar_texto(pg, "COLA DE REPORTES", 30)
        foto(pg, SAL / f"{nombre}_operador.png")
        nav.close()
        print("ok", nombre)
