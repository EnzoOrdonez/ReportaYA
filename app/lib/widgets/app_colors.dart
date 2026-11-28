import 'package:flutter/material.dart';
import '../models/enums.dart';

class AppColors {
  static const Color primary = Color(0xFFA27EFF);

  /// Violeta oscuro para texto sobre fondo blanco (enlaces): contraste 7:1 (WCAG AA).
  static const Color enlace = Color(0xFF6D28D9);

  /// Gris para texto secundario sobre blanco: contraste 4.8:1 (WCAG AA).
  static const Color textoSecundario = Color(0xFF6B7280);

  /// Inicio del degradado del login: con texto blanco grande llega a 4.2:1.
  static const Color primaryProfundo = Color(0xFF8B5CF6);
  static const Color secondary = Color(0xFF6A9FFF);
  static const Color textPrimary = Color(0xFF1F1F29);
  static const Color error = Color(0xFFDC2626);
  static const Color tecnicoPrimary = Color(0xFF2E7D32);
  static const Color tecnicoSecondary = Color(0xFF388E3C);

  static const List<Color> ciudadanoGradient = [primary, secondary];
  static const List<Color> operadorGradient = [primary, secondary];
  static const List<Color> tecnicoGradient = [tecnicoPrimary, tecnicoSecondary];

  // Estados (4, alineados a los CU). Se usan como fondo de etiquetas y botones
  // con texto blanco, por eso cumplen contraste AA (4,5:1) sobre blanco:
  // rojo 4,98:1, ámbar 5,02:1, verde 5,13:1 y gris 6,19:1.
  static const Color estadoPendiente = Color(0xFFD32F2F);
  static const Color estadoRevision = Color(0xFFB45309);
  static const Color estadoFinalizado = Color(0xFF2E7D32);
  static const Color estadoRechazado = Color(0xFF616161);

  static Color forEstado(String estado) {
    switch (estado.toUpperCase()) {
      case EstadoReporte.PENDIENTE:
        return estadoPendiente;
      case EstadoReporte.REVISION:
        return estadoRevision;
      case EstadoReporte.FINALIZADO:
        return estadoFinalizado;
      case EstadoReporte.RECHAZADO:
        return estadoRechazado;
      default:
        return Colors.grey;
    }
  }

  static String textoEstado(String estado) {
    switch (estado.toUpperCase()) {
      case EstadoReporte.PENDIENTE:
        return 'Pendiente';
      case EstadoReporte.REVISION:
        return 'En revisión';
      case EstadoReporte.FINALIZADO:
        return 'Finalizado';
      case EstadoReporte.RECHAZADO:
        return 'Rechazado';
      default:
        return estado;
    }
  }

  static IconData iconoTipo(String? tipo) {
    switch (tipo) {
      case TipoProblema.INFRAESTRUCTURA:
        return Icons.construction;
      case TipoProblema.RESIDUOS:
        return Icons.delete_outline;
      case TipoProblema.SEGURIDAD:
        return Icons.shield_outlined;
      case TipoProblema.ALUMBRADO:
        return Icons.lightbulb_outline;
      default:
        return Icons.report_problem_outlined;
    }
  }
}
