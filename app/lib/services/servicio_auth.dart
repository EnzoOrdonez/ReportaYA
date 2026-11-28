import 'package:http/http.dart' as http;

import '../configs/api_config.dart';
import '../models/auth.dart';
import '../models/cuenta.dart';
import 'api_client.dart';

/// Servicio de cuenta y autenticación (CU-01, CU-02, CU-03).
/// Usa ApiClient sin token (rutas públicas) para compartir tiempos límite y
/// mensajes de error con el resto de la app.
class ServicioAuth {
  final ApiClient _client = ApiClient.instance;

  // --- CU-01 Login ---
  Future<AuthLoginResponse> login(String usuario, String password) async {
    final res = await _client.post('/auth/login', {
      'usuario': usuario,
      'password': password,
    }, auth: false);
    if (res is! Map<String, dynamic>) {
      throw Exception('Respuesta inesperada del servidor al iniciar sesión');
    }
    return AuthLoginResponse.fromJson(res);
  }

  // --- CU-02 Registro ---
  Future<CuentaResponse> crearCuenta(CrearCuentaRequest req) async {
    final res = await _client.post('/cuenta', req.toJson(), auth: false);
    if (res is! Map<String, dynamic>) {
      throw Exception('Respuesta inesperada del servidor al crear la cuenta');
    }
    return CuentaResponse.fromJson(res);
  }

  // --- CU-03 Recuperar contraseña ---
  Future<void> solicitarRecuperacion(String correo) async {
    await _client.post('/auth/recuperar-password', {
      'correo': correo,
    }, auth: false);
  }

  /// Restablece la contraseña usando el código de recuperación.
  /// HU-02 CA2: avisa al backend para que el token deje de valer. No pasa por
  /// ApiClient para que un 401 no dispare otra vez el cierre de sesión, y nunca
  /// lanza error: la sesión local se cierra igual.
  Future<void> cerrarSesionEnServidor(String token) async {
    try {
      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Sin red o servidor dormido: el token vence solo a las 24 h.
    }
  }

  Future<void> restablecerContrasena(
    String correo,
    String token,
    String nuevaPassword,
  ) async {
    await _client.post('/auth/restablecer-password', {
      'correo': correo,
      'token': token,
      'nuevaContrasena': nuevaPassword,
    }, auth: false);
  }
}
