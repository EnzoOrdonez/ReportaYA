import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reportaya/models/models.dart';
import 'package:reportaya/utils/fechas.dart';

/// El JSON de las pruebas es una respuesta real del backend (GET /api/reportes/1040).
void main() {
  setUpAll(() => initializeDateFormatting('es', null));

  test('ReporteResponse lee la respuesta real del backend', () {
    final json =
        jsonDecode(File('test/fixtures/reporte_1040.json').readAsStringSync())
            as Map<String, dynamic>;
    final r = ReporteResponse.fromJson(json);
    expect(r.id, 1040);
    expect(r.estado, EstadoReporte.PENDIENTE);
    expect(r.tipoProblema, TipoProblema.RESIDUOS);
    expect(r.ubicacion.direccion, 'Av. Brasil 800, Pueblo Libre');
    expect(r.tieneTecnico, isFalse);
  });

  test(
    'HistorialEstado lee el historial real (el primer cambio no tiene estado anterior)',
    () {
      final lista =
          (jsonDecode(
                    File(
                      'test/fixtures/historial_1040.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .map((e) => HistorialEstado.fromJson(e as Map<String, dynamic>))
              .toList();
      expect(lista, isNotEmpty);
      expect(lista.last.estadoAnterior, isNull);
      expect(lista.last.estadoNuevo, EstadoReporte.PENDIENTE);
    },
  );

  test(
    'campos opcionales ausentes toman valores por defecto sin lanzar excepciones',
    () {
      final r = ReporteResponse.fromJson({
        'ubicacion': <String, dynamic>{'latitud': -12.0, 'longitud': -77.0},
      });
      expect(r.id, 0);
      expect(r.estado, EstadoReporte.PENDIENTE);
    },
  );

  test('etiquetas de los cinco tipos de problema', () {
    expect(TipoProblema.values.map(TipoProblema.label), [
      'Infraestructura',
      'Residuos',
      'Seguridad',
      'Alumbrado',
      'Otro',
    ]);
    expect(TipoProblema.label('DESCONOCIDO'), 'Otro');
  });

  test('formato de fechas en espanol y tolerancia a texto invalido', () {
    expect(fmtFecha('2026-04-26T14:05:00'), '26 abr 2026');
    expect(fmtFecha('no-es-fecha'), 'no-es-fecha');
  });
}
