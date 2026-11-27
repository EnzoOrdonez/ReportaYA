import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reportaya/services/api_client.dart';

/// Pruebas unitarias del cliente HTTP: traduccion de errores y paginacion.
void main() {
  Future<T> con<T>(MockClient cliente, Future<T> Function() f) =>
      http.runWithClient(f, () => cliente);

  test('devuelve el JSON de una respuesta 2xx', () async {
    final r = await con(
      MockClient((_) async => http.Response('{"id":7}', 200)),
      () => ApiClient.instance.get('/x', auth: false),
    );
    expect(r, {'id': 7});
  });

  test('usa el mensaje {"error": ...} del backend', () async {
    final f = con(
      MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'El titulo es obligatorio'}),
          400,
        ),
      ),
      () => ApiClient.instance.post('/reportes', {}, auth: false),
    );
    await expectLater(
      f,
      throwsA(
        predicate((e) => e.toString().contains('El titulo es obligatorio')),
      ),
    );
  });

  test('traduce 403 sin cuerpo a un mensaje legible', () async {
    final f = con(
      MockClient((_) async => http.Response('', 403)),
      () => ApiClient.instance.get('/x', auth: false),
    );
    await expectLater(
      f,
      throwsA(predicate((e) => e.toString().contains('No tienes permiso'))),
    );
  });

  test('una pagina HTML de error (502) no rompe la app', () async {
    final f = con(
      MockClient((_) async => http.Response('<html>Bad Gateway</html>', 502)),
      () => ApiClient.instance.get('/x', auth: false),
    );
    await expectLater(
      f,
      throwsA(predicate((e) => e.toString().contains('no está disponible'))),
    );
  });

  test('sin red devuelve un mensaje de conexion', () async {
    final f = con(
      MockClient((_) async => throw http.ClientException('sin red')),
      () => ApiClient.instance.get('/x', auth: false),
    );
    await expectLater(
      f,
      throwsA(predicate((e) => e.toString().contains('No se pudo conectar'))),
    );
  });

  test('getTodasLasPaginas recorre las paginas hasta last=true', () async {
    final pedidas = <String>[];
    final cliente = MockClient((req) async {
      final page = int.parse(req.url.queryParameters['page']!);
      pedidas.add(req.url.query);
      return http.Response(
        jsonEncode({
          'content': [page * 10, page * 10 + 1],
          'last': page == 2,
        }),
        200,
      );
    });
    final todo = await con(
      cliente,
      () => ApiClient.instance.getTodasLasPaginas('/reportes?estado=PENDIENTE'),
    );
    expect(todo, [0, 1, 10, 11, 20, 21]);
    expect(pedidas, [
      'estado=PENDIENTE&page=0',
      'estado=PENDIENTE&page=1',
      'estado=PENDIENTE&page=2',
    ]);
  });

  test(
    'getTodasLasPaginas entiende el formato {"page":{"totalPages":N}}',
    () async {
      final cliente = MockClient((req) async {
        final page = int.parse(req.url.queryParameters['page']!);
        return http.Response(
          jsonEncode({
            'content': ['p$page'],
            'page': {'totalPages': 2},
          }),
          200,
        );
      });
      expect(
        await con(
          cliente,
          () => ApiClient.instance.getTodasLasPaginas('/reportes'),
        ),
        ['p0', 'p1'],
      );
    },
  );
}
