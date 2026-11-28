import 'package:flutter/material.dart';

import 'enlaces.dart';

/// RF-20 / HU-19: aclara que ReportaYA es una simulación académica y no un
/// canal municipal, y orienta hacia los números oficiales de emergencia del Perú.
class AvisoAlcance extends StatelessWidget {
  const AvisoAlcance({super.key});

  static const textoAlcance =
      'ReportaYA es una simulación académica de la Universidad de Lima: tus '
      'reportes no se envían a ninguna municipalidad real, y su número no es '
      'un expediente ni compromete un plazo de reparación. Ante una '
      'emergencia llama a:';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0C36D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF8A5A00)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  textoAlcance,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Color(0xFF5C3D00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: const [
              _Numero('105', 'Policía'),
              _Numero('116', 'Bomberos'),
              _Numero('106', 'SAMU'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero(this.numero, this.entidad);
  final String numero;
  final String entidad;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => abrirTelefono(numero),
      icon: const Icon(Icons.call, size: 16),
      label: Text('$numero $entidad'),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF7A4B00),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}
