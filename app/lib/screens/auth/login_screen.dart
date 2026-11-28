import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../configs/api_config.dart';
import '../../configs/version_app.dart';
import '../../controllers/auth_controller.dart';
import '../../models/enums.dart';
import '../../routes/app_routes.dart';
import '../../services/despertador.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/custom_toast.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/servidor_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _verClave = false;

  /// El selector de servidor es una herramienta de desarrollo: en la versión
  /// publicada solo aparece si ya se eligió otro servidor o tras mantener
  /// presionado el título "ReportaYA".
  bool _mostrarServidor = kDebugMode || ApiConfig.usaUrlPersonalizada;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final usuario = _usuarioCtrl.text.trim();
    final password = _passwordCtrl.text;
    setState(() => _loading = true);
    try {
      final auth = Get.find<AuthController>();
      final response = await auth.login(usuario, password);
      AppToast.success(
        response.message.isNotEmpty
            ? response.message
            : '¡Inicio de sesión exitoso!',
      );
      await Future.delayed(const Duration(milliseconds: 500));
      switch (response.tipoCuenta) {
        case TipoCuenta.OPERADOR_MUNICIPAL:
          Get.offAllNamed(AppRoutes.homeOperador);
          break;
        case TipoCuenta.TECNICO:
          Get.offAllNamed(AppRoutes.homeTecnico);
          break;
        default:
          Get.offAllNamed(AppRoutes.mainTabs);
      }
    } catch (e) {
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      colors: const [
        AppColors.primaryProfundo,
        Color(0xFFD4C4FF),
        Colors.white,
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 30),
            GestureDetector(
              onLongPress: () => setState(() => _mostrarServidor = true),
              child: Semantics(
                header: true,
                child: const Text(
                  'ReportaYA',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pestanas: cada una ocupa la mitad, se parte en dos lineas si el
                    // texto esta ampliado y mide al menos 48 dp de alto (area tactil).
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            selected: true,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: const Center(
                                child: Text(
                                  'Iniciar Sesión',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.enlace,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Get.toNamed(AppRoutes.register),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: const Center(
                                child: Text(
                                  'Registrarse',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppColors.textoSecundario,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _Label('Usuario:'),
                    _input(
                      _usuarioCtrl,
                      'Ingresa tu usuario',
                      autofill: AutofillHints.username,
                    ),
                    const SizedBox(height: 12),
                    const _Label('Contraseña:'),
                    _input(
                      _passwordCtrl,
                      'Ingresa tu contraseña',
                      obscure: !_verClave,
                      autofill: AutofillHints.password,
                      suffix: IconButton(
                        tooltip: _verClave
                            ? 'Ocultar contraseña'
                            : 'Mostrar contraseña',
                        icon: Icon(
                          _verClave ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _verClave = !_verClave),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA27EFF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _loading ? null : _handleLogin,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Iniciar Sesión',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Get.toNamed(AppRoutes.recoverPassword),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.enlace),
                      ),
                    ),
                    // Aviso mientras el servidor gratis se despierta (~1 min la primera vez).
                    Obx(() {
                      final d = Get.find<Despertador>();
                      if (!d.esperando.value) return const SizedBox.shrink();
                      return const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                              ),
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Despertando el servidor... la primera vez puede tardar hasta 1 minuto.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    // Permite elegir PC local o nube sin recompilar el APK.
                    if (_mostrarServidor)
                      TextButton.icon(
                        onPressed: _loading
                            ? null
                            : () async {
                                if (await mostrarDialogoServidor()) {
                                  setState(() {});
                                  Get.find<Despertador>().despertar();
                                }
                              },
                        icon: const Icon(
                          Icons.dns_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          'Servidor: ${ApiConfig.descripcionCorta}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textoSecundario,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Get.toNamed(AppRoutes.privacidad),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text(
                'Aviso de privacidad',
                style: TextStyle(
                  color: AppColors.enlace,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Text(
              'ReportaYA $kVersionApp · Proyecto académico, Universidad de Lima',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String hint, {
    bool obscure = false,
    String? autofill,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      autocorrect: false,
      autofillHints: autofill == null ? null : [autofill],
      validator: (value) => (value == null || value.trim().isEmpty)
          ? 'Este campo es obligatorio'
          : null,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF555555),
      ),
    ),
  );
}
