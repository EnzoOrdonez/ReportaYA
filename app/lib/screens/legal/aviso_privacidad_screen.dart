import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../configs/version_app.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/aviso_alcance.dart';
import '../../widgets/enlaces.dart';

/// RF-21: aviso de privacidad que se muestra antes del registro y que se puede
/// volver a consultar desde el login y desde el perfil.
/// Marco: Ley 29733 y su Reglamento (D. S. 016-2024-JUS).
class AvisoPrivacidadScreen extends StatelessWidget {
  const AvisoPrivacidadScreen({super.key});

  static const secciones = <(String, String)>[
    (
      'Quién trata tus datos',
      'El equipo del proyecto ReportaYA (Grupo 3) del curso Proyecto de '
          'Desarrollo de Software de la Universidad de Lima. ReportaYA es un '
          'prototipo académico y no pertenece a ninguna municipalidad.',
    ),
    (
      'Qué datos se recogen',
      'Al registrarte: nombres, apellidos, DNI, teléfono, correo, usuario y '
          'contraseña (se guarda cifrada con BCrypt, nunca en texto). Al '
          'reportar: título, descripción, tipo de problema, el punto que '
          'marcas en el mapa con su dirección, las fotos y las fechas de cada '
          'cambio de estado. La app usa la ubicación de tu equipo solo cuando '
          'creas un reporte o tocas "Mi ubicación", y nunca en segundo plano.',
    ),
    (
      'Para qué se usan',
      'Para crear y proteger tu cuenta, registrar tus reportes, asignarlos a '
          'un técnico, mostrarte su avance y enviarte el código para '
          'recuperar tu contraseña. No se venden ni se usan para publicidad.',
    ),
    (
      'Quién puede verlos',
      'Tú, el operador municipal del prototipo y el técnico asignado a tu '
          'reporte. Otros ciudadanos solo ven en el mapa el título, el tipo, '
          'el estado y la ubicación del reporte, sin tu nombre ni tus fotos.',
    ),
    (
      'Servicios externos',
      'Render (Estados Unidos) aloja el servidor y la base de datos; Brevo '
          '(Unión Europea) envía el correo de recuperación; OpenStreetMap '
          'muestra el mapa y convierte el punto marcado en una dirección. '
          'Solo reciben lo necesario para cada tarea.',
    ),
    (
      'Por cuánto tiempo',
      'Mientras dure el desarrollo y la evaluación del proyecto en el ciclo '
          '2026-2. Al terminar, la base de datos del prototipo se elimina.',
    ),
    (
      'Tus derechos',
      'Puedes pedir acceso, rectificación, cancelación u oposición (derechos '
          'ARCO) escribiendo al correo de contacto. Si no recibes respuesta, '
          'puedes acudir a la Autoridad Nacional de Protección de Datos '
          'Personales del Ministerio de Justicia y Derechos Humanos.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F8),
      appBar: AppBar(
        title: const Text('Aviso de privacidad'),
        backgroundColor: AppColors.enlace,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AvisoAlcance(),
          const SizedBox(height: 16),
          for (final (titulo, texto) in secciones) ...[
            Semantics(
              header: true,
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2D3A),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              texto,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF444444),
              ),
            ),
            const SizedBox(height: 14),
          ],
          const Text(
            'Contacto',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D3A),
            ),
          ),
          TextButton.icon(
            onPressed: () => abrirCorreo(
              kCorreoContacto,
              asunto: 'ReportaYA: datos personales',
            ),
            icon: const Icon(Icons.mail_outline),
            label: const Text(kCorreoContacto),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size(48, 48),
              foregroundColor: AppColors.enlace,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Versión del aviso: $kVersionAvisoPrivacidad · App $kVersionApp',
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 16),
          if (Navigator.of(context).canPop())
            FilledButton(
              onPressed: Get.back,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.enlace,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Entendido'),
            ),
        ],
      ),
    );
  }
}
