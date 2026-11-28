import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reportaya/models/cuenta.dart';
import 'package:reportaya/screens/auth/password_reset_ui.dart';
import 'package:reportaya/utils/validacion_foto.dart';

Uint8List _jpg(int n) {
  final b = Uint8List(n);
  b[0] = 0xFF;
  b[1] = 0xD8;
  b[2] = 0xFF;
  return b;
}

void main() {
  group('RNF-01 / RF-06: validación de fotos', () {
    test('JPG de 2 MB exactos se acepta y con 1 byte más se rechaza', () {
      expect(validarFoto(_jpg(kMaxBytesFoto)), isNull);
      expect(validarFoto(_jpg(kMaxBytesFoto + 1)), contains('2 MB'));
    });

    test('PNG válido se acepta; WebP y vacío se rechazan', () {
      final png = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, //
      ]);
      final webp = Uint8List.fromList('RIFF0000WEBPVP8 '.codeUnits);
      expect(validarFoto(png), isNull);
      expect(validarFoto(webp), contains('JPG o PNG'));
      expect(validarFoto(Uint8List(0)), contains('vacía'));
    });
  });

  group('HU-05: código pegado o del enlace', () {
    test('acepta el código solo, en minúsculas o con espacios', () {
      expect(extraerCodigoRecuperacion('a3f9k2'), 'A3F9K2');
      expect(extraerCodigoRecuperacion('  A3F9K2 \n'), 'A3F9K2');
    });

    test('lo encuentra dentro del asunto del correo', () {
      expect(
        extraerCodigoRecuperacion('Tu código de ReportaYA: H7MQ2Z'),
        'H7MQ2Z',
      );
      expect(
        extraerCodigoRecuperacion('Tu código de ReportaYA: ABCDEF'),
        'ABCDEF',
      );
    });

    test('rechaza textos sin un código de 6 caracteres', () {
      expect(extraerCodigoRecuperacion('hola'), isNull);
      expect(extraerCodigoRecuperacion('ABC12'), isNull);
      expect(extraerCodigoRecuperacion('ABC1234'), isNull);
    });
  });

  test('RF-21: el registro envía la aceptación del aviso de privacidad', () {
    final json = CrearCuentaRequest(
      usuario: 'ana',
      contrasena: 'Clave1234',
      nombres: 'Ana',
      apellidos: "D'Ángelo",
      dni: '12345678',
      telefono: '987654321',
      correo: 'ana@mail.com',
      aceptaPrivacidad: true,
    ).toJson();
    expect(json['aceptaPrivacidad'], isTrue);
  });
}
