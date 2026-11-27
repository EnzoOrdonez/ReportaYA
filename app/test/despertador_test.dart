import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reportaya/services/despertador.dart';

void main() {
  Future<Despertador> correr(http.Client cliente) async {
    final d = Despertador();
    await http.runWithClient(() => d.despertar(), () => cliente);
    return d;
  }

  test('marca despierto cuando /salud responde 200', () async {
    Uri? pedido;
    final d = await correr(
      MockClient((r) async {
        pedido = r.url;
        return http.Response('{"estado":"ok"}', 200);
      }),
    );
    expect(pedido!.path, endsWith('/salud'));
    expect(d.despierto.value, isTrue);
    expect(d.esperando.value, isFalse);
  });

  test(
    'backend sin /salud (404) no se marca despierto ni deja el aviso',
    () async {
      final d = await correr(MockClient((_) async => http.Response('', 404)));
      expect(d.despierto.value, isFalse);
      expect(d.esperando.value, isFalse);
    },
  );

  test('sin red no lanza excepcion', () async {
    final d = await correr(
      MockClient((_) async => throw http.ClientException('sin red')),
    );
    expect(d.despierto.value, isFalse);
    expect(d.esperando.value, isFalse);
  });
}
