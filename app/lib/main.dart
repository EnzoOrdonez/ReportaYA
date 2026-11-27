import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'configs/api_config.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'controllers/auth_controller.dart';
import 'controllers/reportes_controller.dart';
import 'controllers/operador_reportes_controller.dart';
import 'controllers/tecnicos_controller.dart';
import 'controllers/tecnico_reportes_controller.dart';
import 'routes/app_routes.dart';
import 'services/despertador.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  ApiConfig.cargar(); // servidor elegido en la app (PC local o nube)
  await initializeDateFormatting('es', null);

  // Los datos ahora vienen del backend REST (ver lib/services/*, ApiClient).
  // Controladores globales (Ciudadano + Operador + Tecnico).
  Get.put(AuthController(), permanent: true);
  Get.put(ReportesController(), permanent: true);
  Get.put(OperadorReportesController(), permanent: true);
  Get.put(TecnicosController(), permanent: true);
  Get.put(TecnicoReportesController(), permanent: true);
  // Empieza a despertar el backend gratis de Render mientras se ve el login.
  Get.put(Despertador(), permanent: true).despertar();

  runApp(const ReportaYAApp());
}

class ReportaYAApp extends StatelessWidget {
  const ReportaYAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'ReportaYA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFA27EFF)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // Espanol para los textos del sistema y lo que lee el lector de pantalla.
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Diseno responsivo: en tablet o escritorio la app se centra con un ancho
      // de lectura maximo en lugar de estirarse a toda la ventana.
      builder: (context, child) => AnchoResponsivo(child: child!),
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.pages,
    );
  }
}

/// Limita el ancho util a [anchoMaximo] dp cuando la ventana es mas ancha
/// (web en escritorio, tablet en horizontal). En celulares no cambia nada.
class AnchoResponsivo extends StatelessWidget {
  const AnchoResponsivo({
    super.key,
    required this.child,
    this.anchoMaximo = 560,
  });

  final Widget child;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= anchoMaximo) return child;
    return ColoredBox(
      color: const Color(0xFFE9E6F5),
      child: Center(
        child: Container(
          width: anchoMaximo,
          decoration: const BoxDecoration(
            boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 24)],
          ),
          child: ClipRect(
            child: MediaQuery(
              data: mq.copyWith(size: Size(anchoMaximo, mq.size.height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
