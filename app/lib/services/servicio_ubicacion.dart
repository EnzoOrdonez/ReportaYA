import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

/// Resultado de pedir la ubicación del dispositivo (RF-04).
class ResultadoUbicacion {
  final double? lat;
  final double? lng;

  /// Mensaje para el usuario cuando no se pudo obtener la ubicación.
  final String? motivo;

  /// true si el permiso quedó negado de forma permanente (hay que ir a Ajustes).
  final bool negadoPermanente;

  const ResultadoUbicacion.ok(double this.lat, double this.lng)
    : motivo = null,
      negadoPermanente = false;

  const ResultadoUbicacion.error(this.motivo, {this.negadoPermanente = false})
    : lat = null,
      lng = null;

  bool get exito => lat != null && lng != null;
}

/// Pide la ubicación una sola vez y en primer plano, con permiso del usuario.
/// No rastrea en segundo plano (exclusión del Plan de Proyecto).
class ServicioUbicacion {
  static const Duration limite = Duration(seconds: 12);

  Future<ResultadoUbicacion> obtenerActual() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const ResultadoUbicacion.error(
          'La ubicación del dispositivo está desactivada. Actívala o toca el mapa para marcar el punto.',
        );
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.deniedForever) {
        return const ResultadoUbicacion.error(
          kIsWeb
              ? 'El navegador bloqueó la ubicación: permítela en la configuración del sitio o toca el mapa para marcar el punto.'
              : 'El permiso de ubicación está bloqueado: habilítalo en Ajustes o toca el mapa para marcar el punto.',
          negadoPermanente: true,
        );
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.unableToDetermine) {
        return const ResultadoUbicacion.error(
          'Sin permiso de ubicación: toca el mapa para marcar el punto.',
        );
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: limite,
        ),
      );
      return ResultadoUbicacion.ok(pos.latitude, pos.longitude);
    } catch (_) {
      return const ResultadoUbicacion.error(
        'No se pudo obtener tu ubicación a tiempo. Toca el mapa para marcar el punto.',
      );
    }
  }

  Future<void> abrirAjustes() => Geolocator.openAppSettings();
}
