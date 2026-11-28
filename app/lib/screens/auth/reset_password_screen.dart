// lib/screens/auth/reset_password_screen.dart
// Paso 2 de la recuperacion de contrasena, en dos sub-pasos para enfocar una
// tarea por pantalla: (1) codigo de verificacion, (2) nueva contrasena.
// Diseno replicado de ULIMA++ con la paleta de ReportaYA. El codigo de
// ReportaYA es alfanumerico de 6 caracteres en mayusculas (ej. "A3F9K2").

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../routes/app_routes.dart';
import '../../widgets/custom_toast.dart';
import 'password_reset_ui.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const int _resendCooldownSeconds = 60;

  final _auth = Get.find<AuthController>();
  final _codigoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  late final String _correo;

  /// true si el código llegó en el enlace del correo (HU-05).
  bool _codigoDesdeEnlace = false;
  bool _avanzando = false;

  /// Sub-paso visible: 0 = codigo, 1 = nueva contrasena.
  int _step = 0;

  String? _error;
  bool _loading = false;
  bool _resending = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Llega desde "Olvidé mi contraseña" (argumento String) o desde el enlace
    // del correo: #/reset-password?correo=...&codigo=... (parámetros de ruta).
    final args = Get.arguments;
    final params = Get.parameters;
    String correo = '';
    String? codigo;
    if (args is String) {
      correo = args;
    } else if (args is Map) {
      correo = '${args['correo'] ?? ''}';
      codigo = args['codigo']?.toString();
    }
    if (correo.isEmpty) correo = params['correo'] ?? '';
    codigo ??= params['codigo'];
    _correo = correo.trim();
    final limpio = extraerCodigoRecuperacion(codigo ?? '');
    if (limpio != null) {
      _codigoCtrl.text = limpio;
      _codigoDesdeEnlace = true;
      _step = 1;
    }
  }

  Future<void> _pegarCodigo() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final codigo = extraerCodigoRecuperacion(data?.text ?? '');
    if (!mounted) return;
    if (codigo == null) {
      setState(
        () => _error =
            'No hay un código de $kResetCodeLength caracteres copiado. '
            'Cópialo del correo o escríbelo.',
      );
      return;
    }
    _codigoCtrl.text = codigo;
    _continuarAPassword();
  }

  /// Al completar los 6 caracteres se pasa solo a la nueva contraseña.
  void _alCompletarCodigo(String _) {
    if (_step != 0 || _avanzando) return;
    _avanzando = true;
    Future.delayed(const Duration(milliseconds: 250), () {
      _avanzando = false;
      if (mounted && _step == 0) _continuarAPassword();
    });
  }

  void _salir() {
    if (Navigator.of(context).canPop()) {
      Get.back();
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codigoCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // --- Sub-paso 1 -> 2: valida el codigo localmente y avanza. ---
  void _continuarAPassword() {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.length < kResetCodeLength) {
      setState(
        () => _error = 'El código debe tener $kResetCodeLength caracteres.',
      );
      return;
    }
    setState(() {
      _error = null;
      _step = 1;
    });
  }

  // --- Sub-paso 2 -> 1 (flecha atras o codigo rechazado por el backend). ---
  void _volverACodigo() {
    setState(() {
      _error = null;
      _step = 0;
    });
  }

  Future<void> _restablecer() async {
    if (_loading) return;

    final codigo = _codigoCtrl.text.trim();
    final nuevaPass = _passCtrl.text;
    final confirmacion = _confirmPassCtrl.text;

    if (nuevaPass.length < kMinPasswordLength) {
      setState(
        () => _error =
            'La contraseña debe tener al menos $kMinPasswordLength caracteres.',
      );
      return;
    }
    if (nuevaPass != confirmacion) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await _auth.restablecerContrasena(
        _correo,
        codigo,
        nuevaPass,
        confirmacion,
      );
      AppToast.success('Contraseña restablecida con éxito');
      await Future.delayed(const Duration(milliseconds: 600));
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = msg;
        // Si el backend rechaza el codigo, regresar al sub-paso del codigo
        // para corregirlo o reenviarlo, con el error visible ahi.
        if (_esErrorDeCodigo(msg)) {
          _step = 0;
          _codigoDesdeEnlace = false;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _esErrorDeCodigo(String msg) {
    // El backend responde con tildes ("Código ... inválido"); se normalizan
    // para que la comparación funcione con y sin ellas.
    final m = msg
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    return m.contains('codigo') ||
        m.contains('token') ||
        m.contains('expir') ||
        m.contains('invalid') ||
        m.contains('valid');
  }

  Future<void> _reenviarCodigo() async {
    if (_resendCooldown > 0 || _resending || _loading) return;
    if (_correo.isEmpty) {
      setState(
        () => _error = 'No se pudo reenviar el código. Vuelve a empezar.',
      );
      return;
    }

    setState(() {
      _error = null;
      _resending = true;
    });

    try {
      await _auth.solicitarRecuperacion(_correo);
      _iniciarCooldown();
      AppToast.success('Código reenviado a tu correo');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _iniciarCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown <= 1) {
          _resendCooldown = 0;
          timer.cancel();
        } else {
          _resendCooldown--;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = PasswordResetPalette.from(context);

    if (_correo.isEmpty) {
      return PasswordResetScaffold(
        palette: palette,
        onBack: _salir,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PasswordResetTitle(palette: palette, text: 'Acceso inválido'),
            const SizedBox(height: 10),
            PasswordResetSubtitle(
              palette: palette,
              text: 'Vuelve a solicitar el código de recuperación.',
            ),
            const SizedBox(height: 24),
            PasswordResetPrimaryButton(
              palette: palette,
              label: 'Volver',
              loading: false,
              onPressed: () => Get.offAllNamed(AppRoutes.recoverPassword),
            ),
          ],
        ),
      );
    }

    return PasswordResetScaffold(
      palette: palette,
      onBack: _salir,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _step == 0
            ? _buildCodigoStep(palette, key: const ValueKey('code-step'))
            : _buildPasswordStep(palette, key: const ValueKey('password-step')),
      ),
    );
  }

  // --- Sub-paso 1: codigo de verificacion (+ reenviar). ---
  Widget _buildCodigoStep(PasswordResetPalette palette, {required Key key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PasswordResetTitle(palette: palette, text: 'Verifica tu correo'),
        const SizedBox(height: 10),
        PasswordResetSubtitle(
          palette: palette,
          text:
              'Ingresa el código de $kResetCodeLength caracteres que '
              'enviamos a ${maskEmail(_correo)}.',
        ),
        const SizedBox(height: 26),
        PasswordResetFieldLabel(
          palette: palette,
          text: 'Código de verificación',
        ),
        const SizedBox(height: 8),
        PasswordResetCodeField(
          controller: _codigoCtrl,
          palette: palette,
          autofocus: true,
          onCompleted: _alCompletarCodigo,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _pegarCodigo,
            icon: const Icon(Icons.content_paste, size: 18),
            label: const Text('Pegar código'),
            style: TextButton.styleFrom(
              foregroundColor: palette.focusedFieldLine,
              minimumSize: const Size(48, 48),
            ),
          ),
        ),
        PasswordResetErrorMessage(palette: palette, message: _error),
        const SizedBox(height: 28),
        PasswordResetPrimaryButton(
          palette: palette,
          label: 'Continuar',
          loading: false,
          onPressed: _continuarAPassword,
        ),
        const SizedBox(height: 8),
        _buildReenviarLink(palette),
      ],
    );
  }

  Widget _buildReenviarLink(PasswordResetPalette palette) {
    final enabled = _resendCooldown == 0 && !_resending;
    final label = _resending
        ? 'Reenviando...'
        : _resendCooldown > 0
        ? 'Reenviar código (${_resendCooldown}s)'
        : 'Reenviar código';

    return Center(
      child: TextButton(
        onPressed: enabled ? _reenviarCodigo : null,
        style: TextButton.styleFrom(
          foregroundColor: palette.focusedFieldLine,
          disabledForegroundColor: palette.fieldHint,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // --- Sub-paso 2: nueva contrasena y confirmacion. ---
  Widget _buildPasswordStep(PasswordResetPalette palette, {required Key key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _volverACodigo,
              icon: Icon(Icons.arrow_back, size: 20, color: palette.fieldHint),
              splashRadius: 18,
              tooltip: 'Cambiar código',
            ),
            Expanded(
              child: PasswordResetTitle(
                palette: palette,
                text: 'Crea tu nueva contraseña',
              ),
            ),
            // Equilibra el ancho del IconButton para centrar el titulo.
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 10),
        PasswordResetSubtitle(
          palette: palette,
          text: _codigoDesdeEnlace
              ? 'Código ${_codigoCtrl.text} tomado del enlace de tu correo. '
                    'Usa al menos $kMinPasswordLength caracteres.'
              : 'Usa al menos $kMinPasswordLength caracteres.',
        ),
        const SizedBox(height: 26),
        PasswordResetFieldLabel(palette: palette, text: 'Nueva contraseña'),
        const SizedBox(height: 8),
        PasswordResetField(
          controller: _passCtrl,
          palette: palette,
          hint: 'Mínimo $kMinPasswordLength caracteres',
          obscureText: !_passwordVisible,
          textInputAction: TextInputAction.next,
          suffixIcon: PasswordVisibilityToggle(
            palette: palette,
            visible: _passwordVisible,
            onPressed: () =>
                setState(() => _passwordVisible = !_passwordVisible),
          ),
        ),
        const SizedBox(height: 18),
        PasswordResetFieldLabel(palette: palette, text: 'Confirmar contraseña'),
        const SizedBox(height: 8),
        PasswordResetField(
          controller: _confirmPassCtrl,
          palette: palette,
          hint: 'Repite la nueva contraseña',
          obscureText: !_confirmVisible,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _restablecer(),
          suffixIcon: PasswordVisibilityToggle(
            palette: palette,
            visible: _confirmVisible,
            onPressed: () => setState(() => _confirmVisible = !_confirmVisible),
          ),
        ),
        PasswordResetErrorMessage(palette: palette, message: _error),
        const SizedBox(height: 28),
        PasswordResetPrimaryButton(
          palette: palette,
          label: 'Confirmar',
          loading: _loading,
          onPressed: _restablecer,
        ),
      ],
    );
  }
}
