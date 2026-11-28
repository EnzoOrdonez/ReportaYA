import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../models/models.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/custom_toast.dart';
import '../../widgets/gradient_scaffold.dart';

/// Vista 07 Registro (CU-02). Solo CIUDADANO. Crea la cuenta en el almacen local.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = Get.find<AuthController>();
  final _c = <String, TextEditingController>{
    for (final k in [
      'nombres',
      'apellidos',
      'dni',
      'telefono',
      'correo',
      'usuario',
      'contrasena',
    ])
      k: TextEditingController(),
  };
  bool _loading = false;
  bool _verClave = false;
  bool _aceptaPrivacidad = false;

  /// HU-01: nombres y apellidos de 2 a 100 caracteres; se admiten tildes,
  /// espacios, guiones y apóstrofes.
  static final _reNombre = RegExp(r"^\p{L}[\p{L}\p{M} '’-]*$", unicode: true);

  String? _validarNombre(String? v) {
    final t = v!.trim();
    if (t.isEmpty) return 'Requerido';
    if (t.length < 2 || t.length > 100) return 'Entre 2 y 100 caracteres';
    if (!_reNombre.hasMatch(t)) {
      return 'Solo letras, espacios, guiones y apóstrofes';
    }
    return null;
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final cuenta = await _auth.registrar(
        CrearCuentaRequest(
          usuario: _c['usuario']!.text.trim(),
          contrasena: _c['contrasena']!.text,
          nombres: _c['nombres']!.text.trim(),
          apellidos: _c['apellidos']!.text.trim(),
          dni: _c['dni']!.text.trim(),
          telefono: _c['telefono']!.text.trim(),
          correo: _c['correo']!.text.trim(),
          aceptaPrivacidad: _aceptaPrivacidad,
        ),
      );
      // Si el servidor exige verificar el correo, la cuenta nace inactiva
      // (el login devolveria 403); si no, ya se puede entrar.
      AppToast.success(
        cuenta.activo
            ? 'Cuenta creada. Ya puedes iniciar sesión.'
            : 'Cuenta creada. Revisa tu correo y abre el enlace de activación antes de iniciar sesión.',
      );
      await Future.delayed(const Duration(milliseconds: 1800));
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      colors: AppColors.ciudadanoGradient,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: Get.back,
                    tooltip: 'Volver',
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Text(
                    'Crear cuenta',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _field(
                        'nombres',
                        'Nombres',
                        autofill: AutofillHints.givenName,
                        validator: _validarNombre,
                      ),
                      _field(
                        'apellidos',
                        'Apellidos',
                        autofill: AutofillHints.familyName,
                        validator: _validarNombre,
                      ),
                      _field(
                        'dni',
                        'DNI',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v!.trim().isEmpty) return 'Requerido';
                          if (v.trim().length != 8 ||
                              int.tryParse(v.trim()) == null) {
                            return 'Debe tener 8 dígitos numéricos';
                          }
                          return null;
                        },
                      ),
                      _field(
                        'telefono',
                        'Teléfono',
                        keyboardType: TextInputType.phone,
                        autofill: AutofillHints.telephoneNumberNational,
                        validator: (v) {
                          if (v!.trim().isEmpty) return 'Requerido';
                          if (v.trim().length != 9 ||
                              int.tryParse(v.trim()) == null) {
                            return 'Debe tener 9 dígitos numéricos';
                          }
                          return null;
                        },
                      ),
                      _field(
                        'correo',
                        'Correo electrónico',
                        keyboardType: TextInputType.emailAddress,
                        autofill: AutofillHints.email,
                        validator: (v) {
                          if (v!.trim().isEmpty) return 'Requerido';
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(v.trim())) {
                            return 'Correo inválido';
                          }
                          return null;
                        },
                      ),
                      _field(
                        'usuario',
                        'Usuario',
                        autofill: AutofillHints.newUsername,
                        validator: (v) {
                          final t = v!.trim();
                          if (t.isEmpty) return 'Requerido';
                          if (t.length < 3 || t.length > 50) {
                            return 'Entre 3 y 50 caracteres';
                          }
                          return null;
                        },
                      ),
                      _field(
                        'contrasena',
                        'Contraseña',
                        obscure: !_verClave,
                        autofill: AutofillHints.newPassword,
                        suffix: IconButton(
                          tooltip: _verClave
                              ? 'Ocultar contraseña'
                              : 'Mostrar contraseña',
                          icon: Icon(
                            _verClave ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _verClave = !_verClave),
                        ),
                        validator: (v) =>
                            v!.length < 8 ? 'Mínimo 8 caracteres' : null,
                      ),
                      _CasillaPrivacidad(
                        valor: _aceptaPrivacidad,
                        onChanged: (v) => setState(() => _aceptaPrivacidad = v),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _loading ? null : _registrar,
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
                                  'Registrarse',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    bool obscure = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    String? autofill,
    Widget? suffix,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: _c[key],
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      autofillHints: autofill == null ? null : [autofill],
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}

/// RF-21 / HU-01: aceptación obligatoria del aviso de privacidad.
class _CasillaPrivacidad extends StatelessWidget {
  const _CasillaPrivacidad({required this.valor, required this.onChanged});
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      initialValue: valor,
      validator: (_) =>
          valor ? null : 'Debes aceptar el aviso de privacidad para continuar',
      builder: (estado) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: valor,
                activeColor: AppColors.primary,
                onChanged: (v) {
                  onChanged(v ?? false);
                  estado.didChange(v);
                  // Al marcarla se quita el mensaje de error sin esperar otro envío.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (estado.mounted && estado.hasError) estado.validate();
                  });
                },
                semanticLabel: 'Acepto el aviso de privacidad',
              ),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Acepto el ', style: TextStyle(fontSize: 13)),
                    InkWell(
                      onTap: () => Get.toNamed(AppRoutes.privacidad),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'aviso de privacidad',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.enlace,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (estado.hasError)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                estado.errorText!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB3261E)),
              ),
            ),
        ],
      ),
    );
  }
}
