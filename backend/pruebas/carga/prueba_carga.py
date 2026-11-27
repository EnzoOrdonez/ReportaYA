"""Prueba de carga para RNF-06: listas y detalles en <= 3 s en al menos 95 de 100 consultas
con 50 usuarios concurrentes. Uso:
    python pruebas/carga/prueba_carga.py --url http://127.0.0.1:8081 --usuarios 50 --segundos 60
Solo contra un entorno de pruebas (inicia sesion con las cuentas de la semilla)."""
import argparse, asyncio, json, random, statistics, time
import httpx


async def usuario(cli, api, tok_c, tok_o, cid, ids, fin, lat, err):
    h_c = {"Authorization": f"Bearer {tok_c}"}; h_o = {"Authorization": f"Bearer {tok_o}"}
    while time.perf_counter() < fin:
        op = random.choice(["mis_reportes", "detalle", "mapa", "bandeja_operador"])
        url, h = {"mis_reportes": (f"{api}/reportes/cuenta/{cid}?page=0", h_c),
                  "detalle": (f"{api}/reportes/{random.choice(ids)}", h_o),
                  "mapa": (f"{api}/reportes/mapa", h_c),
                  "bandeja_operador": (f"{api}/reportes?page=0", h_o)}[op]
        t0 = time.perf_counter()
        try:
            r = await cli.get(url, headers=h)
            (lat.setdefault(op, [])).append(time.perf_counter() - t0)
            if r.status_code != 200:
                err.append((op, r.status_code))
        except Exception as e:
            err.append((op, type(e).__name__))


async def main(a):
    api = a.url.rstrip("/") + "/api"
    async with httpx.AsyncClient(timeout=30, limits=httpx.Limits(max_connections=a.usuarios)) as cli:
        c = (await cli.post(f"{api}/auth/login", json={"usuario": "ciudadano", "password": a.clave})).json()
        o = (await cli.post(f"{api}/auth/login", json={"usuario": "op.maria", "password": a.clave})).json()
        pag = (await cli.get(f"{api}/reportes?page=0", headers={"Authorization": f"Bearer {o['token']}"})).json()
        ids = [x["id"] for x in pag["content"]] or [1042]
        lat, err = {}, []
        fin = time.perf_counter() + a.segundos
        await asyncio.gather(*[usuario(cli, api, c["token"], o["token"], c["cuentaId"], ids, fin, lat, err) for _ in range(a.usuarios)])
    todas = sorted(x for v in lat.values() for x in v)
    p = lambda xs, q: sorted(xs)[min(len(xs) - 1, int(round(q / 100 * len(xs))) - 1)]
    res = {"usuarios": a.usuarios, "segundos": a.segundos, "consultas": len(todas), "errores": len(err),
           "rps": round(len(todas) / a.segundos, 1), "p50_ms": round(p(todas, 50) * 1000), "p95_ms": round(p(todas, 95) * 1000),
           "p99_ms": round(p(todas, 99) * 1000), "max_ms": round(todas[-1] * 1000),
           "dentro_de_3s_pct": round(sum(x <= 3 for x in todas) / len(todas) * 100, 2),
           "por_operacion": {k: {"n": len(v), "p95_ms": round(p(v, 95) * 1000)} for k, v in lat.items()}}
    print(json.dumps(res, indent=2, ensure_ascii=False))
    if a.salida:
        open(a.salida, "w").write(json.dumps(res, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://127.0.0.1:8081"); ap.add_argument("--usuarios", type=int, default=50)
    ap.add_argument("--segundos", type=int, default=60); ap.add_argument("--clave", default="123456"); ap.add_argument("--salida")
    asyncio.run(main(ap.parse_args()))
