import 'dart:io';

import 'package:flutter/services.dart';

/// Carga Roboto y Material Icons reales del SDK de Flutter. Sin esto las pruebas
/// usan la fuente de prueba (cada letra es un cuadrado) y reportan desbordes falsos.
Future<void> cargarFuentesReales() async {
  final base =
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  Future<ByteData> leer(String f) async =>
      ByteData.sublistView(File('$base/$f').readAsBytesSync());
  final roboto = FontLoader('Roboto');
  for (final f in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    roboto.addFont(leer(f));
  }
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(leer('MaterialIcons-Regular.otf'))).load();
}
