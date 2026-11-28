import 'dart:typed_data';

/// RNF-01 / HU-15: cada foto enviada pesa como máximo 2 MB después de que la
/// app la reduce (1280 px de ancho, calidad 60).
const int kMaxBytesFoto = 2 * 1024 * 1024;

/// RF-06: solo se aceptan fotografías JPG o PNG.
bool esJpgOPng(Uint8List b) {
  final jpg = b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;
  final png =
      b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A;
  return jpg || png;
}

/// Devuelve el motivo para rechazar la foto o null si se puede adjuntar.
String? validarFoto(Uint8List bytes) {
  if (bytes.isEmpty) return 'La foto está vacía. Elige otra.';
  if (!esJpgOPng(bytes)) {
    return 'Formato no admitido: usa una foto JPG o PNG.';
  }
  if (bytes.length > kMaxBytesFoto) {
    final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
    return 'La foto pesa $mb MB incluso reducida y el máximo es 2 MB. '
        'Toma otra con menos detalle o elige una distinta.';
  }
  return null;
}
