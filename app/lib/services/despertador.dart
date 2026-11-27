import 'dart:async';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../configs/api_config.dart';

/// Despierta el backend en cuanto se abre la app.
///
/// En el plan gratis de Render el servidor se apaga tras 15 min sin tráfico y
/// tarda alrededor de un minuto en volver. Si esa espera recae en el primer
/// login, el usuario ve un error. Con este aviso, el servidor empieza a
/// arrancar mientras la persona escribe su usuario y contraseña.
class Despertador extends GetxService {
  /// true mientras hay una petición a /salud en curso.
  final esperando = false.obs;

  /// true cuando el backend respondió 200 en /salud.
  final despierto = false.obs;

  int _intento = 0;

  /// Lanza GET {origen}/salud sin bloquear. Llamar de nuevo tras cambiar de
  /// servidor reinicia el estado; las respuestas de un servidor anterior se
  /// descartan.
  Future<void> despertar() async {
    final intento = ++_intento;
    despierto.value = false;
    esperando.value = true;
    try {
      final r = await http
          .get(Uri.parse('${ApiConfig.origen}/salud'))
          .timeout(const Duration(seconds: 120));
      if (intento == _intento) despierto.value = r.statusCode == 200;
    } catch (_) {
      // Sin red o backend antiguo sin /salud: el login mostrará el error real.
    } finally {
      if (intento == _intento) esperando.value = false;
    }
  }
}
