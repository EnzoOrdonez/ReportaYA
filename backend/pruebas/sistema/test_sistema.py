"""Casos de prueba de caja negra. PE = particion de equivalencias, VL = valores limite,
TD = tabla de decision (rol x accion), TE = transicion de estados, EG = conjetura de errores."""
import base64, time
import jwt, requests
from conftest import (API, URL, caso, h, login, token, registrar, cuerpo_registro, ciudadano_nuevo,
                      crear_reporte, cuerpo_reporte, img_b64, sql, sufijo, IMG)


def anotar(request, r):
    request.node._obtenido = f"{r.status_code} {r.text[:90]}".replace("|", "/").replace("\n", " ")


# ------------------------------------------------------------------ autenticacion (RF-02, HU-02)
@caso("CP-01", "PE", "RF-02 / HU-02", "Inicio de sesion con credenciales validas de cada rol", "200 y token con el rol correcto")
def test_cp01_login_roles(request):
    roles = {}
    for u in ("ciudadano", "op.maria", "tec.carlos"):
        r = login(u, "123456"); assert r.status_code == 200
        roles[u] = r.json()["tipoCuenta"]
    request.node._obtenido = f"200 {roles}"
    assert roles == {"ciudadano": "CIUDADANO", "op.maria": "OPERADOR_MUNICIPAL", "tec.carlos": "TECNICO"}


@caso("CP-02", "PE", "RF-02 / HU-02", "Contrasena incorrecta", "401 con mensaje en espanol")
def test_cp02_clave_incorrecta(request):
    r = login("ciudadano", "otra-clave"); anotar(request, r)
    assert r.status_code == 401 and "error" in r.json()


@caso("CP-03", "EG", "RF-02 / RNF-03", "Usuario inexistente responde igual que clave incorrecta", "401 con el mismo mensaje que CP-02")
def test_cp03_usuario_inexistente(request):
    a = login("ciudadano", "otra-clave").json(); r = login("no_existe_" + sufijo(), "x123456"); anotar(request, r)
    assert r.status_code == 401 and r.json() == a


@caso("CP-04", "PE", "RF-02", "Usuario o contrasena vacios", "400")
def test_cp04_campos_vacios(request):
    r = login("", ""); anotar(request, r)
    assert r.status_code == 400


@caso("CP-05", "PE", "RNF-03", "Ruta protegida sin token", "401")
def test_cp05_sin_token(request):
    r = requests.get(f"{API}/reportes/mapa", timeout=30); anotar(request, r)
    assert r.status_code == 401


@caso("CP-06", "EG", "RNF-03", "Token alterado (firma invalida)", "401")
def test_cp06_token_alterado(request):
    t = token("ciudadano")["token"]; t = t[:-3] + ("aaa" if not t.endswith("aaa") else "bbb")
    r = requests.get(f"{API}/reportes/mapa", headers=h(t), timeout=30); anotar(request, r)
    assert r.status_code == 401


@caso("CP-07", "VL", "RNF-03", "Token vencido (exp un segundo en el pasado)", "401")
def test_cp07_token_vencido(request):
    import os
    secreto = os.environ.get("JWT_SECRET", "entorno-de-pruebas-local-no-es-produccion-0123456789")
    t = jwt.encode({"sub": "1", "usuario": "ciudadano", "tipoCuenta": "CIUDADANO", "iat": int(time.time()) - 100,
                    "exp": int(time.time()) - 1}, secreto, algorithm="HS384")
    r = requests.get(f"{API}/reportes/mapa", headers=h(t), timeout=30); anotar(request, r)
    assert r.status_code == 401


# ------------------------------------------------------------------ registro (RF-01, HU-01)
@caso("CP-08", "PE", "RF-01 / HU-01", "Registro de ciudadano con datos validos", "201, cuenta CIUDADANO activa y puede iniciar sesion")
def test_cp08_registro_valido(request):
    r, b = registrar(); anotar(request, r)
    assert r.status_code == 201 and r.json()["tipoCuenta"] == "CIUDADANO" and r.json()["activo"] is True
    assert login(b["usuario"], b["contrasena"]).status_code == 200


@caso("CP-09", "PE", "RF-01", "Usuario, DNI o correo ya registrados", "400 con mensaje claro en los tres casos")
def test_cp09_duplicados(request):
    r0, b = registrar(); assert r0.status_code == 201
    codes = []
    for campo in ("usuario", "dni", "correo"):
        nuevo = cuerpo_registro(); nuevo[campo] = b[campo]
        r = requests.post(f"{API}/cuenta", json=nuevo, timeout=30); codes.append((campo, r.status_code, r.json().get("error", "")[:40]))
    request.node._obtenido = str(codes)
    assert all(c[1] == 400 for c in codes)


@caso("CP-10", "VL", "RF-01", "DNI de 7, 8 y 9 digitos", "400, 201, 400")
def test_cp10_dni_limites(request):
    res = [registrar(dni="1234567")[0].status_code, registrar()[0].status_code, registrar(dni="123456789")[0].status_code]
    request.node._obtenido = str(res)
    assert res == [400, 201, 400]


@caso("CP-11", "PE", "RF-01", "DNI de 8 caracteres no numericos", "400")
def test_cp11_dni_letras(request):
    r, _ = registrar(dni="".join(__import__("random").choices("ABCDEFGHJKLMNPQRSTUVWXYZ", k=8))); anotar(request, r)
    assert r.status_code == 400


@caso("CP-12", "VL", "RF-01", "Contrasena de 5 y de 6 caracteres", "400 y 201")
def test_cp12_clave_limites(request):
    res = [registrar(contrasena="12345")[0].status_code, registrar(contrasena="123456")[0].status_code]
    request.node._obtenido = str(res)
    assert res == [400, 201]


@caso("CP-13", "VL", "RF-01", "Usuario de 2, 3, 50 y 51 caracteres", "400, 201, 201, 400")
def test_cp13_usuario_limites(request):
    s = sufijo(4)
    res = [registrar(usuario="ab")[0].status_code, registrar(usuario=s[:3])[0].status_code,
           registrar(usuario=(s + "x" * 50)[:50])[0].status_code, registrar(usuario=s + "y" * 47)[0].status_code]
    request.node._obtenido = str(res)
    assert res == [400, 201, 201, 400]


@caso("CP-14", "PE", "RF-01", "Correo con formato invalido", "400")
def test_cp14_correo_invalido(request):
    r, _ = registrar(correo="correo-sin-arroba"); anotar(request, r)
    assert r.status_code == 400


@caso("CP-15", "TD", "RF-01 / RF-17", "Registro publico pidiendo rol OPERADOR_MUNICIPAL o TECNICO", "400 en ambos (sin elevacion de privilegios)")
def test_cp15_sin_elevacion(request):
    res = [registrar(tipoCuenta=t)[0].status_code for t in ("OPERADOR_MUNICIPAL", "TECNICO")]
    request.node._obtenido = str(res)
    assert res == [400, 400]


# ------------------------------------------------------------------ recuperacion (RF-03, HU-05)
@caso("CP-16", "EG", "RF-03 / HU-05", "Solicitud con correo registrado y no registrado", "200 con el mismo mensaje (no revela cuentas)")
def test_cp16_recuperar_uniforme(request, ciu):
    a = requests.post(f"{API}/auth/recuperar-password", json={"correo": ciu["datos"]["correo"]}, timeout=30)
    b = requests.post(f"{API}/auth/recuperar-password", json={"correo": "nadie" + sufijo() + "@prueba.pe"}, timeout=30)
    request.node._obtenido = f"{a.status_code}/{b.status_code} mismo cuerpo={a.json() == b.json()}"
    assert a.status_code == b.status_code == 200 and a.json() == b.json()


@caso("CP-17", "TE", "RF-03 / HU-05", "Restablecer con codigo valido, luego reutilizarlo", "200, login con la nueva clave, 400 al reutilizar")
def test_cp17_restablecer(request, ciu):
    correo = ciu["datos"]["correo"]
    requests.post(f"{API}/auth/recuperar-password", json={"correo": correo}, timeout=30)
    cod = sql(f"select c.token_recuperacion from cuentas c join personas p on p.id=c.persona_id where p.correo='{correo}'")
    assert len(cod) == 6
    r1 = requests.post(f"{API}/auth/restablecer-password", json={"token": cod, "nuevaContrasena": "Nueva456"}, timeout=30)
    l = login(ciu["datos"]["usuario"], "Nueva456")
    r2 = requests.post(f"{API}/auth/restablecer-password", json={"token": cod, "nuevaContrasena": "Otra4567"}, timeout=30)
    request.node._obtenido = f"{r1.status_code}, login {l.status_code}, reuso {r2.status_code}"
    assert (r1.status_code, l.status_code, r2.status_code) == (200, 200, 400)


@caso("CP-18", "VL", "RF-03", "Codigo vencido (31 min) y clave nueva de 5 caracteres", "400 en ambos")
def test_cp18_codigo_vencido(request, ciu):
    correo = ciu["datos"]["correo"]
    requests.post(f"{API}/auth/recuperar-password", json={"correo": correo}, timeout=30)
    cod = sql(f"select c.token_recuperacion from cuentas c join personas p on p.id=c.persona_id where p.correo='{correo}'")
    corta = requests.post(f"{API}/auth/restablecer-password", json={"token": cod, "nuevaContrasena": "12345"}, timeout=30)
    sql(f"update cuentas set token_recuperacion_expiracion = now() - interval '1 minute' where token_recuperacion='{cod}'")
    vencido = requests.post(f"{API}/auth/restablecer-password", json={"token": cod, "nuevaContrasena": "Nueva456"}, timeout=30)
    request.node._obtenido = f"clave corta {corta.status_code}, vencido {vencido.status_code}"
    assert corta.status_code == 400 and vencido.status_code == 400


# ------------------------------------------------------------------ reporte ciudadano (RF-19, RF-05, RF-06)
@caso("CP-19", "PE", "RF-19 / HU-03", "Crear reporte con datos validos", "201, estado PENDIENTE, codigo asignado e historial inicial")
def test_cp19_crear_reporte(request, ciu):
    r = crear_reporte(ciu["token"]); anotar(request, r)
    d = r.json(); hist = requests.get(f"{API}/historial-estados/reporte/{d['id']}", headers=h(ciu["token"]), timeout=30).json()
    assert r.status_code == 201 and d["estado"] == "PENDIENTE" and d["id"] > 0
    assert [x["estadoNuevo"] for x in hist] == ["PENDIENTE"]


@caso("CP-20", "PE", "RF-19", "Una clase valida por cada tipo de problema", "201 en los 5 tipos")
def test_cp20_tipos(request, ciu):
    res = {t: crear_reporte(ciu["token"], tipoProblema=t).status_code for t in ("INFRAESTRUCTURA", "RESIDUOS", "SEGURIDAD", "ALUMBRADO", "OTRO")}
    request.node._obtenido = str(res)
    assert set(res.values()) == {201}


@caso("CP-21", "VL", "RF-19", "Titulo vacio, de 255 y de 256 caracteres", "400, 201, 400")
def test_cp21_titulo_limites(request, ciu):
    res = [crear_reporte(ciu["token"], titulo="   ").status_code, crear_reporte(ciu["token"], titulo="T" * 255).status_code,
           crear_reporte(ciu["token"], titulo="T" * 256).status_code]
    request.node._obtenido = str(res)
    assert res == [400, 201, 400]


@caso("CP-22", "VL", "RF-19", "Descripcion de 1000 y de 1001 caracteres", "201 y 400")
def test_cp22_descripcion_limites(request, ciu):
    res = [crear_reporte(ciu["token"], descripcion="d" * 1000).status_code, crear_reporte(ciu["token"], descripcion="d" * 1001).status_code]
    request.node._obtenido = str(res)
    assert res == [201, 400]


@caso("CP-23", "PE", "RF-05 / HU-17", "Reporte sin ubicacion y sin latitud", "400 en ambos")
def test_cp23_sin_ubicacion(request, ciu):
    b = cuerpo_reporte(); b.pop("ubicacion")
    r1 = requests.post(f"{API}/reportes", json=b, headers=h(ciu["token"]), timeout=30)
    r2 = crear_reporte(ciu["token"], ubicacion={"longitud": -77.03})
    request.node._obtenido = f"{r1.status_code}, {r2.status_code}"
    assert (r1.status_code, r2.status_code) == (400, 400)


@caso("CP-24", "EG", "RF-05", "Punto marcado en el mapa sin direccion geocodificada", "201 y direccion con las coordenadas")
def test_cp24_sin_direccion(request, ciu):
    r = crear_reporte(ciu["token"], ubicacion={"latitud": -12.1, "longitud": -77.0}); anotar(request, r)
    assert r.status_code == 201 and r.json()["ubicacion"]["direccion"].startswith("Ubicación -12.1")


@caso("CP-25", "TD", "RF-02 / RNF-03", "Operador y tecnico intentan crear un reporte", "403 en ambos")
def test_cp25_roles_no_crean(request, op, tec):
    res = [crear_reporte(op["token"]).status_code, crear_reporte(tec["token"]).status_code]
    request.node._obtenido = str(res)
    assert res == [403, 403]


@caso("CP-26", "EG", "RNF-03", "El cuerpo indica la cuenta de otro ciudadano", "201 y el reporte queda a nombre de la cuenta del token")
def test_cp26_cuenta_del_token(request, ciu, ciu2):
    r = crear_reporte(ciu["token"], cuentaId=ciu2["id"]); anotar(request, r)
    assert r.status_code == 201 and r.json()["cuentaId"] == ciu["id"]


@caso("CP-27", "PE", "RF-06", "Adjuntar foto PNG valida y descargarla", "201 y la descarga devuelve los mismos bytes")
def test_cp27_foto_valida(request, ciu):
    rid = crear_reporte(ciu["token"]).json()["id"]
    r = requests.post(f"{API}/reportes/{rid}/fotos", json={"archivoBase64": img_b64(), "tipo": "INICIAL", "descripcion": "Foto"}, headers=h(ciu["token"]), timeout=60)
    url = r.json()["url"]; url = url if url.startswith("http") else URL + url
    f = requests.get(url, timeout=30)
    request.node._obtenido = f"{r.status_code}, descarga {f.status_code} identica={f.content == IMG.read_bytes()}"
    assert r.status_code == 201 and f.status_code == 200 and f.content == IMG.read_bytes()


@caso("CP-28", "VL", "RF-06", "Foto de 5 MB exactos y de 5 MB + 1 byte", "201 y 400")
def test_cp28_foto_limite(request, ciu):
    rid = crear_reporte(ciu["token"]).json()["id"]
    png = b"\x89PNG\r\n\x1a\n"
    def subir(n):
        data = png + b"\0" * (n - len(png))
        return requests.post(f"{API}/reportes/{rid}/fotos", json={"archivoBase64": base64.b64encode(data).decode(), "tipo": "INICIAL"},
                             headers=h(ciu["token"]), timeout=120).status_code
    res = [subir(5 * 1024 * 1024), subir(5 * 1024 * 1024 + 1)]
    request.node._obtenido = str(res)
    assert res == [201, 400]


@caso("CP-29", "PE", "RF-06", "Foto con base64 invalido y con tipo inexistente", "400 en ambos")
def test_cp29_foto_invalida(request, ciu):
    rid = crear_reporte(ciu["token"]).json()["id"]
    a = requests.post(f"{API}/reportes/{rid}/fotos", json={"archivoBase64": "@@no-es-base64@@", "tipo": "INICIAL"}, headers=h(ciu["token"]), timeout=30)
    b = requests.post(f"{API}/reportes/{rid}/fotos", json={"archivoBase64": img_b64(), "tipo": "INTERMEDIA"}, headers=h(ciu["token"]), timeout=30)
    request.node._obtenido = f"{a.status_code}, {b.status_code}"
    assert (a.status_code, b.status_code) == (400, 400)


@caso("CP-30", "TD", "RF-06 / RNF-03", "Foto en reporte ajeno y foto FINAL por el ciudadano duenio", "403 en ambos")
def test_cp30_foto_permisos(request, ciu, ciu2):
    rid = crear_reporte(ciu["token"]).json()["id"]
    a = requests.post(f"{API}/reportes/{rid}/fotos", json={"archivoBase64": img_b64(), "tipo": "INICIAL"}, headers=h(ciu2["token"]), timeout=30)
    b = requests.post(f"{API}/reportes/{rid}/fotos", json={"archivoBase64": img_b64(), "tipo": "FINAL"}, headers=h(ciu["token"]), timeout=30)
    request.node._obtenido = f"{a.status_code}, {b.status_code}"
    assert (a.status_code, b.status_code) == (403, 403)


# ------------------------------------------------------------------ consulta y permisos (RF-13, RF-15, RF-16)
@caso("CP-31", "TD", "RF-13 / HU-07", "Listar los reportes propios y los de otro ciudadano", "200 solo con reportes propios y 403 para los ajenos")
def test_cp31_mis_reportes(request, ciu, ciu2):
    crear_reporte(ciu["token"]); crear_reporte(ciu["token"])
    a = requests.get(f"{API}/reportes/cuenta/{ciu['id']}?page=0", headers=h(ciu["token"]), timeout=30)
    b = requests.get(f"{API}/reportes/cuenta/{ciu['id']}?page=0", headers=h(ciu2["token"]), timeout=30)
    duenos = {x["cuentaId"] for x in a.json()["content"]}
    request.node._obtenido = f"{a.status_code} total={a.json()['totalElements']} duenos={duenos}; ajeno {b.status_code}"
    assert a.status_code == 200 and duenos == {ciu["id"]} and a.json()["totalElements"] == 2 and b.status_code == 403


@caso("CP-32", "TD", "RF-16 / HU-09", "Ficha del reporte: duenio, otro ciudadano, operador, tecnico no asignado", "200, 403, 200, 403")
def test_cp32_ficha_permisos(request, ciu, ciu2, op, tec2):
    rid = crear_reporte(ciu["token"]).json()["id"]
    res = [requests.get(f"{API}/reportes/{rid}", headers=h(t), timeout=30).status_code for t in (ciu["token"], ciu2["token"], op["token"], tec2["token"])]
    request.node._obtenido = str(res)
    assert res == [200, 403, 200, 403]


@caso("CP-58", "TD", "RF-16 / RNF-03", "Fotos del reporte: duenio, otro ciudadano, operador, tecnico no asignado", "200, 403, 200, 403")
def test_cp58_fotos_permisos(request, ciu, ciu2, op, tec2):
    rid = crear_reporte(ciu["token"]).json()["id"]
    requests.post(f"{API}/reportes/{rid}/fotos", json={"archivoBase64": img_b64(), "tipo": "INICIAL", "descripcion": "Foto"},
                  headers=h(ciu["token"]), timeout=60)
    res = [requests.get(f"{API}/reportes/{rid}/fotos", headers=h(t), timeout=30).status_code for t in (ciu["token"], ciu2["token"], op["token"], tec2["token"])]
    request.node._obtenido = str(res)
    assert res == [200, 403, 200, 403]


@caso("CP-59", "TD", "RF-13 / RNF-03", "Historial de estados: duenio, otro ciudadano, operador, tecnico no asignado y reporte inexistente", "200, 403, 200, 403 y 404")
def test_cp59_historial_permisos(request, ciu, ciu2, op, tec2):
    rid = crear_reporte(ciu["token"]).json()["id"]
    res = [requests.get(f"{API}/historial-estados/reporte/{rid}", headers=h(t), timeout=30).status_code for t in (ciu["token"], ciu2["token"], op["token"], tec2["token"])]
    res.append(requests.get(f"{API}/historial-estados/reporte/999999999", headers=h(op["token"]), timeout=30).status_code)
    request.node._obtenido = str(res)
    assert res == [200, 403, 200, 403, 404]


@caso("CP-33", "PE", "RF-15 / HU-08", "Mapa filtrado por estado y por tipo", "200 y todos los puntos cumplen el filtro")
def test_cp33_mapa_filtros(request, ciu):
    crear_reporte(ciu["token"], tipoProblema="RESIDUOS")
    a = requests.get(f"{API}/reportes/mapa?estado=PENDIENTE", headers=h(ciu["token"]), timeout=30).json()
    b = requests.get(f"{API}/reportes/mapa?tipo=RESIDUOS", headers=h(ciu["token"]), timeout=30).json()
    c = requests.get(f"{API}/reportes/mapa?estado=PENDIENTE&tipo=RESIDUOS", headers=h(ciu["token"]), timeout=30).json()
    request.node._obtenido = f"estado={len(a)} tipo={len(b)} ambos={len(c)}"
    assert a and b and c and all(x["estado"] == "PENDIENTE" for x in a) and all(x["tipoProblema"] == "RESIDUOS" for x in b)
    assert all(x["estado"] == "PENDIENTE" and x["tipoProblema"] == "RESIDUOS" for x in c)


@caso("CP-34", "PE", "RF-15", "Filtro de estado inexistente", "400 con mensaje")
def test_cp34_filtro_invalido(request, ciu):
    r = requests.get(f"{API}/reportes/mapa?estado=PERDIDO", headers=h(ciu["token"]), timeout=30); anotar(request, r)
    assert r.status_code == 400


@caso("CP-35", "PE", "RF-16", "Reporte inexistente", "404")
def test_cp35_inexistente(request, op):
    r = requests.get(f"{API}/reportes/999999999", headers=h(op["token"]), timeout=30); anotar(request, r)
    assert r.status_code == 404


@caso("CP-36", "TD", "RF-07 / RNF-03", "Bandeja general de reportes: ciudadano y operador", "403 y 200")
def test_cp36_bandeja_general(request, ciu, op):
    a = requests.get(f"{API}/reportes?page=0", headers=h(ciu["token"]), timeout=30).status_code
    b = requests.get(f"{API}/reportes?page=0", headers=h(op["token"]), timeout=30).status_code
    request.node._obtenido = f"{a}, {b}"
    assert (a, b) == (403, 200)


# ------------------------------------------------------------------ operador (RF-07, RF-08)
@caso("CP-37", "TE", "RF-07 / HU-04", "Operador acepta un reporte PENDIENTE", "200, estado REVISION e historial PENDIENTE -> REVISION")
def test_cp37_aceptar(request, ciu, op):
    rid = crear_reporte(ciu["token"]).json()["id"]
    r = requests.post(f"{API}/operador/reportes/{rid}/aceptar", json={}, headers=h(op["token"]), timeout=30); anotar(request, r)
    hist = requests.get(f"{API}/historial-estados/reporte/{rid}", headers=h(op["token"]), timeout=30).json()
    assert r.status_code == 200 and r.json()["estado"] == "REVISION"
    assert any(x["estadoAnterior"] == "PENDIENTE" and x["estadoNuevo"] == "REVISION" for x in hist)


@caso("CP-38", "TD", "RF-07", "Ciudadano y tecnico intentan aceptar", "403 en ambos")
def test_cp38_aceptar_sin_rol(request, ciu, tec):
    rid = crear_reporte(ciu["token"]).json()["id"]
    res = [requests.post(f"{API}/operador/reportes/{rid}/aceptar", json={}, headers=h(t), timeout=30).status_code for t in (ciu["token"], tec["token"])]
    request.node._obtenido = str(res)
    assert res == [403, 403]


@caso("CP-39", "TE", "RF-07 / HU-04", "Rechazar con motivo y rechazar sin motivo", "200 RECHAZADO con el motivo guardado; 400 sin motivo")
def test_cp39_rechazar(request, ciu, op):
    rid = crear_reporte(ciu["token"]).json()["id"]; rid2 = crear_reporte(ciu["token"]).json()["id"]
    a = requests.post(f"{API}/operador/reportes/{rid}/rechazar", json={"motivo": "Duplicado del reporte 1042"}, headers=h(op["token"]), timeout=30)
    b = requests.post(f"{API}/operador/reportes/{rid2}/rechazar", json={}, headers=h(op["token"]), timeout=30)
    request.node._obtenido = f"{a.status_code} {a.json().get('estado')} motivo={a.json().get('comentarioResolucion')!r}; sin motivo {b.status_code}"
    assert a.status_code == 200 and a.json()["estado"] == "RECHAZADO" and a.json()["comentarioResolucion"] == "Duplicado del reporte 1042"
    assert b.status_code == 400


@caso("CP-40", "TE", "RF-07 / RF-24", "Transiciones no permitidas: PENDIENTE -> FINALIZADO y salir de RECHAZADO", "400 en ambas")
def test_cp40_transiciones_invalidas(request, ciu, op):
    rid = crear_reporte(ciu["token"]).json()["id"]
    a = requests.patch(f"{API}/reportes/{rid}/estado", params={"estado": "FINALIZADO"}, headers=h(op["token"]), timeout=30)
    requests.post(f"{API}/operador/reportes/{rid}/rechazar", json={"motivo": "Fuera de la jurisdiccion"}, headers=h(op["token"]), timeout=30)
    b = requests.post(f"{API}/operador/reportes/{rid}/aceptar", json={}, headers=h(op["token"]), timeout=30)
    request.node._obtenido = f"{a.status_code}, {b.status_code}"
    assert (a.status_code, b.status_code) == (400, 400)


@caso("CP-41", "TE", "RF-08 / HU-10", "Asignar tecnico a reporte en REVISION y a reporte PENDIENTE", "201 y 400")
def test_cp41_asignar(request, ciu, op, tec):
    rid = crear_reporte(ciu["token"]).json()["id"]; rid2 = crear_reporte(ciu["token"]).json()["id"]
    requests.post(f"{API}/operador/reportes/{rid}/aceptar", json={}, headers=h(op["token"]), timeout=30)
    a = requests.post(f"{API}/asignaciones", json={"reporteId": rid, "tecnicoId": tec["cuentaId"]}, headers=h(op["token"]), timeout=30)
    b = requests.post(f"{API}/asignaciones", json={"reporteId": rid2, "tecnicoId": tec["cuentaId"]}, headers=h(op["token"]), timeout=30)
    request.node._obtenido = f"{a.status_code}, {b.status_code}"
    assert (a.status_code, b.status_code) == (201, 400)


@caso("CP-42", "PE", "RF-08", "Asignar un tecnico inexistente y un ciudadano como tecnico", "4xx en ambos, sin cambios en el reporte")
def test_cp42_asignar_invalido(request, ciu, op):
    rid = crear_reporte(ciu["token"]).json()["id"]
    requests.post(f"{API}/operador/reportes/{rid}/aceptar", json={}, headers=h(op["token"]), timeout=30)
    a = requests.post(f"{API}/asignaciones", json={"reporteId": rid, "tecnicoId": 999999}, headers=h(op["token"]), timeout=30)
    b = requests.post(f"{API}/asignaciones", json={"reporteId": rid, "tecnicoId": ciu["id"]}, headers=h(op["token"]), timeout=30)
    d = requests.get(f"{API}/reportes/{rid}", headers=h(op["token"]), timeout=30).json()
    request.node._obtenido = f"{a.status_code}, {b.status_code}, tecnico={d.get('tecnicoAsignadoId')}"
    assert 400 <= a.status_code < 500 and 400 <= b.status_code < 500 and not d.get("tecnicoAsignadoId")


@caso("CP-43", "TD", "RF-08", "Ciudadano intenta asignar un tecnico", "403")
def test_cp43_asignar_sin_rol(request, ciu, tec):
    rid = crear_reporte(ciu["token"]).json()["id"]
    r = requests.post(f"{API}/asignaciones", json={"reporteId": rid, "tecnicoId": tec["cuentaId"]}, headers=h(ciu["token"]), timeout=30); anotar(request, r)
    assert r.status_code == 403


# ------------------------------------------------------------------ tecnico (RF-09, RF-11)
def reporte_asignado(ciu, op, tec):
    rid = crear_reporte(ciu["token"]).json()["id"]
    requests.post(f"{API}/operador/reportes/{rid}/aceptar", json={}, headers=h(op["token"]), timeout=30)
    requests.post(f"{API}/asignaciones", json={"reporteId": rid, "tecnicoId": tec["cuentaId"]}, headers=h(op["token"]), timeout=30)
    return rid


def completar(tec_id, rid, tok, comentario="Se cambio la luminaria y se probo el encendido.", fotos=None):
    fotos = [{"archivoBase64": img_b64(), "tipo": "FINAL", "descripcion": "Foto final de la reparacion"}] if fotos is None else fotos
    return requests.patch(f"{API}/tecnicos/{tec_id}/reportes/{rid}/completar", json={"comentarioResolucion": comentario, "fotos": fotos},
                          headers=h(tok), timeout=60)


@caso("CP-44", "TD", "RF-09 / HU-11", "Bandeja Mis tareas propia y de otro tecnico", "200 con el reporte asignado y 403 para la ajena")
def test_cp44_mis_tareas(request, ciu, op, tec, tec2):
    rid = reporte_asignado(ciu, op, tec)
    a = requests.get(f"{API}/tecnicos/{tec['cuentaId']}/reportes?estado=REVISION&page=0&size=200", headers=h(tec["token"]), timeout=30)
    b = requests.get(f"{API}/tecnicos/{tec['cuentaId']}/reportes?page=0", headers=h(tec2["token"]), timeout=30)
    ids = {x["id"] for x in a.json()["content"]}
    request.node._obtenido = f"{a.status_code} contiene={rid in ids}; ajena {b.status_code}"
    assert a.status_code == 200 and b.status_code == 403


@caso("CP-45", "VL", "RF-11 / HU-12", "Comentario de cierre de 9 y de 10 caracteres", "400 y 200")
def test_cp45_comentario_limites(request, ciu, op, tec):
    rid = reporte_asignado(ciu, op, tec)
    a = completar(tec["cuentaId"], rid, tec["token"], comentario="123456789")
    b = completar(tec["cuentaId"], rid, tec["token"], comentario="1234567890")
    request.node._obtenido = f"{a.status_code}, {b.status_code}"
    assert (a.status_code, b.status_code) == (400, 200)


@caso("CP-46", "VL", "RF-06 / RF-11", "Cierre con 4 fotos (maximo 3)", "400 y el reporte sigue en REVISION")
def test_cp46_cuatro_fotos(request, ciu, op, tec):
    rid = reporte_asignado(ciu, op, tec)
    f = {"archivoBase64": img_b64(), "tipo": "FINAL", "descripcion": "Foto final de la reparacion"}
    r = completar(tec["cuentaId"], rid, tec["token"], fotos=[f] * 4)
    e = requests.get(f"{API}/reportes/{rid}", headers=h(tec["token"]), timeout=30).json()["estado"]
    request.node._obtenido = f"{r.status_code}, estado {e}"
    assert r.status_code == 400 and e == "REVISION"


@caso("CP-47", "PE", "RF-11 / HU-12", "Cierre sin ninguna foto final", "400 (se exige al menos una fotografia)")
def test_cp47_sin_fotos(request, ciu, op, tec):
    rid = reporte_asignado(ciu, op, tec)
    r = completar(tec["cuentaId"], rid, tec["token"], fotos=[]); anotar(request, r)
    assert r.status_code == 400


@caso("CP-48", "EG", "RF-11", "Cierre con una foto corrupta", "400 y el reporte sigue en REVISION sin fotos FINAL")
def test_cp48_foto_corrupta(request, ciu, op, tec):
    rid = reporte_asignado(ciu, op, tec)
    r = completar(tec["cuentaId"], rid, tec["token"], fotos=[{"archivoBase64": "%%%corrupta%%%", "tipo": "FINAL", "descripcion": "Foto final de la reparacion"}])
    d = requests.get(f"{API}/reportes/{rid}", headers=h(op["token"]), timeout=30).json()
    finales = [f for f in d.get("fotos") or [] if f["tipo"] == "FINAL"]
    request.node._obtenido = f"{r.status_code} {r.text[:60]}; estado {d['estado']}, fotos FINAL {len(finales)}"
    assert r.status_code == 400 and d["estado"] == "REVISION" and not finales


@caso("CP-49", "TD", "RF-11 / RNF-03", "Otro tecnico intenta cerrar el reporte (con su id y con el id del asignado)", "400 (no asignado) y 403 (id ajeno); el reporte sigue en REVISION")
def test_cp49_cierre_ajeno(request, ciu, op, tec, tec2):
    rid = reporte_asignado(ciu, op, tec)
    a = completar(tec2["cuentaId"], rid, tec2["token"]).status_code
    b = completar(tec["cuentaId"], rid, tec2["token"]).status_code
    d = requests.get(f"{API}/reportes/{rid}", headers=h(ciu["token"]), timeout=30).json()
    finales = sum(f["tipo"] == "FINAL" for f in (d.get("fotos") or []))
    request.node._obtenido = f"{a}, {b}; estado {d['estado']}, fotos FINAL {finales}"
    assert (a, b) == (400, 403) and d["estado"] == "REVISION" and finales == 0


@caso("CP-50", "TE", "RF-11 / RF-13 / HU-07", "Flujo completo PENDIENTE -> REVISION -> FINALIZADO visto por el ciudadano", "200; FINALIZADO con comentario, foto FINAL e historial de 3 estados")
def test_cp50_flujo_completo(request, ciu, op, tec):
    rid = reporte_asignado(ciu, op, tec)
    r = completar(tec["cuentaId"], rid, tec["token"])
    d = requests.get(f"{API}/reportes/{rid}", headers=h(ciu["token"]), timeout=30).json()
    hist = requests.get(f"{API}/historial-estados/reporte/{rid}", headers=h(ciu["token"]), timeout=30).json()
    estados = sorted(x["estadoNuevo"] for x in hist)
    request.node._obtenido = f"{r.status_code}; {d['estado']}; fotos FINAL {sum(f['tipo']=='FINAL' for f in d['fotos'])}; historial {estados}"
    assert r.status_code == 200 and d["estado"] == "FINALIZADO" and d["comentarioResolucion"]
    assert any(f["tipo"] == "FINAL" for f in d["fotos"]) and estados == ["FINALIZADO", "PENDIENTE", "REVISION"]


@caso("CP-51", "TE", "RF-11", "Cerrar dos veces el mismo reporte y rechazar uno FINALIZADO", "400 en ambos (estado terminal)")
def test_cp51_terminal(request, ciu, op, tec):
    rid = reporte_asignado(ciu, op, tec); completar(tec["cuentaId"], rid, tec["token"])
    a = completar(tec["cuentaId"], rid, tec["token"]).status_code
    b = requests.post(f"{API}/operador/reportes/{rid}/rechazar", json={"motivo": "Prueba"}, headers=h(op["token"]), timeout=30).status_code
    request.node._obtenido = f"{a}, {b}"
    assert (a, b) == (400, 400)


# ------------------------------------------------------------------ seguridad transversal (RNF-03)
@caso("CP-52", "EG", "RNF-03", "Las contrasenas se guardan con BCrypt", "Ningun hash en texto plano")
def test_cp52_bcrypt(request):
    total = sql("select count(*) from cuentas"); malos = sql("select count(*) from cuentas where contrasena_hash !~ '^\\$2[aby]\\$'")
    request.node._obtenido = f"{total} cuentas, {malos} sin BCrypt"
    assert malos == "0"


@caso("CP-53", "TD", "RNF-03", "CORS: origen de la version web y origen desconocido", "Cabecera permitida para localhost y 403 para el desconocido")
def test_cp53_cors(request):
    a = requests.options(f"{API}/reportes", headers={"Origin": "http://localhost:8080", "Access-Control-Request-Method": "GET"}, timeout=30)
    b = requests.options(f"{API}/reportes", headers={"Origin": "https://sitio-malicioso.example", "Access-Control-Request-Method": "GET"}, timeout=30)
    request.node._obtenido = f"{a.status_code} {a.headers.get('Access-Control-Allow-Origin')}; {b.status_code}"
    assert a.headers.get("Access-Control-Allow-Origin") == "http://localhost:8080" and b.status_code == 403


@caso("CP-54", "EG", "RNF-03", "Errores de validacion y de base sin trazas internas", "Mensajes sin SQL, clases Java ni stack trace")
def test_cp54_sin_trazas(request, ciu):
    cuerpos = [registrar(dni="1")[0].text, crear_reporte(ciu["token"], titulo="x" * 300).text,
               requests.post(f"{API}/reportes", data="{no json", headers={**h(ciu['token']), "Content-Type": "application/json"}, timeout=30).text]
    sospechosos = [c for c in cuerpos if any(k in c for k in ("SQL", "org.", "java.", "Exception", "constraint"))]
    request.node._obtenido = f"{len(sospechosos)} respuestas con detalles internos"
    assert not sospechosos


@caso("CP-55", "PE", "RNF-03", "Chequeo de salud del servicio", "200 con estado ok y base ok")
def test_cp55_salud(request):
    r = requests.get(f"{URL}/salud", timeout=30); anotar(request, r)
    assert r.status_code == 200 and r.json() == {"estado": "ok", "base": "ok"}


@caso("CP-56", "VL", "RF-06 / HU-03", "Tercera y cuarta foto INICIAL del mismo reporte", "201 y 400 (de una a tres fotos)")
def test_cp56_tope_fotos(request, ciu):
    rid = crear_reporte(ciu["token"]).json()["id"]
    res = [requests.post(f"{API}/reportes/{rid}/fotos", json={"archivoBase64": img_b64(), "tipo": "INICIAL"}, headers=h(ciu["token"]), timeout=60).status_code
           for _ in range(4)]
    request.node._obtenido = str(res)
    assert res == [201, 201, 201, 400]


@caso("CP-57", "PE", "RF-01", "Telefono de 8 digitos y con letras", "400 en ambos")
def test_cp57_telefono(request):
    res = [registrar(telefono="98765432")[0].status_code, registrar(telefono="98765432a")[0].status_code]
    request.node._obtenido = str(res)
    assert res == [400, 400]
