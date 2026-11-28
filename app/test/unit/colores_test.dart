import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaya/widgets/app_colors.dart';

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  // Las etiquetas de estado, los botones Aceptar y Rechazar y los avisos usan
  // texto blanco sobre estos colores: deben cumplir WCAG 2.1 AA (4,5:1).
  const fondos = {
    'Pendiente': AppColors.estadoPendiente,
    'En revisión': AppColors.estadoRevision,
    'Finalizado': AppColors.estadoFinalizado,
    'Rechazado': AppColors.estadoRechazado,
  };

  for (final e in fondos.entries) {
    test('Texto blanco sobre el color de ${e.key} llega a 4,5:1', () {
      expect(_contraste(Colors.white, e.value), greaterThanOrEqualTo(4.5));
    });
  }

  test(
    'Cabecera del técnico: texto blanco grande llega a 3:1 en ambos extremos',
    () {
      for (final c in AppColors.tecnicoGradient) {
        expect(_contraste(Colors.white, c), greaterThanOrEqualTo(3.0));
      }
    },
  );

  test('Cada estado tiene un nombre visible además del color', () {
    for (final estado in ['PENDIENTE', 'REVISION', 'FINALIZADO', 'RECHAZADO']) {
      expect(AppColors.textoEstado(estado), isNot(equals(estado)));
    }
  });
}
