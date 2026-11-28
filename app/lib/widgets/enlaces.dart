import 'package:url_launcher/url_launcher.dart';

import 'custom_toast.dart';

/// Abre el marcador del teléfono con [numero] (no llama solo).
Future<void> abrirTelefono(String numero) async {
  final ok = await launchUrl(Uri(scheme: 'tel', path: numero));
  if (!ok) AppToast.info('Marca el $numero desde tu teléfono.');
}

/// Abre la app de correo con [correo] como destinatario.
Future<void> abrirCorreo(String correo, {String? asunto}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: correo,
    query: asunto == null ? null : 'subject=${Uri.encodeComponent(asunto)}',
  );
  final ok = await launchUrl(uri);
  if (!ok) AppToast.info('Escribe a $correo.');
}
