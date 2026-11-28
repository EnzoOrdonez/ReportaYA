import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:reportaya/controllers/auth_controller.dart';
import 'package:reportaya/screens/auth/login_screen.dart';
import 'package:reportaya/screens/auth/register_screen.dart';
import 'package:reportaya/screens/legal/aviso_privacidad_screen.dart';
import 'package:reportaya/widgets/aviso_alcance.dart';
import 'package:reportaya/services/despertador.dart';
import 'package:reportaya/widgets/foto_picker.dart';

import 'fuentes.dart';

/// Pruebas de widgets: validacion de formularios, tamanio minimo de pantalla
/// (360 x 640 dp, RNF-05) y texto ampliado al 200 % (RNF-07).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // GetStorage guarda la sesion en un archivo; en pruebas se usa una carpeta temporal.
    final dir = Directory.systemTemp.createTempSync('reportaya_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
    await GetStorage.init();
    await cargarFuentesReales();
  });

  setUp(() {
    Get.testMode = true;
    Get.put(AuthController(), permanent: true);
    Get.put(Despertador(), permanent: true);
  });

  tearDown(Get.reset);

  Future<void> montar(
    WidgetTester t,
    Widget pantalla, {
    double escala = 1.0,
    Size tam = const Size(360, 640),
  }) async {
    t.view.physicalSize = tam;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFA27EFF)),
        ),
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: escala,
          maxScaleFactor: escala,
          child: pantalla,
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Login: los campos vacios muestran el mensaje de obligatorio', (
    t,
  ) async {
    await montar(t, const LoginScreen());
    await t.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
    await t.pump();
    expect(find.text('Este campo es obligatorio'), findsNWidgets(2));
  });

  testWidgets(
    'Registro: DNI, telefono, correo y contrasena invalidos muestran su mensaje',
    (t) async {
      await montar(t, const RegisterScreen(), tam: const Size(360, 1400));
      final campos = find.byType(TextFormField);
      await t.enterText(campos.at(0), 'Ana');
      await t.enterText(campos.at(1), 'Quispe');
      await t.enterText(campos.at(2), '1234567');
      await t.enterText(campos.at(3), '98765');
      await t.enterText(campos.at(4), 'ana-sin-arroba');
      await t.enterText(campos.at(5), 'ana');
      await t.enterText(campos.at(6), '1234567');
      await t.tap(find.widgetWithText(ElevatedButton, 'Registrarse'));
      await t.pump();
      expect(find.text('Debe tener 8 dígitos numéricos'), findsOneWidget);
      expect(find.text('Debe tener 9 dígitos numéricos'), findsOneWidget);
      expect(find.text('Correo inválido'), findsOneWidget);
      expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
      expect(
        find.text('Debes aceptar el aviso de privacidad para continuar'),
        findsOneWidget,
      );
      // Al marcar la casilla el mensaje desaparece.
      await t.ensureVisible(find.byType(Checkbox));
      await t.tap(find.byType(Checkbox));
      await t.pump();
      await t.pump();
      expect(
        find.text('Debes aceptar el aviso de privacidad para continuar'),
        findsNothing,
      );
    },
  );

  for (final escala in [1.0, 2.0]) {
    testWidgets(
      'Login en 360 x 640 con texto al ${(escala * 100).round()} % sin desbordes',
      (t) async {
        await montar(t, const LoginScreen(), escala: escala);
        expect(t.takeException(), isNull);
        expect(find.text('Iniciar Sesión'), findsWidgets);
      },
    );

    testWidgets(
      'Registro en 360 x 640 con texto al ${(escala * 100).round()} % sin desbordes',
      (t) async {
        await montar(t, const RegisterScreen(), escala: escala);
        expect(t.takeException(), isNull);
        expect(find.byType(TextFormField), findsNWidgets(7));
      },
    );
  }

  testWidgets(
    'Login: los botones tienen etiqueta y area tactil de 48 dp (pautas de Android)',
    (t) async {
      final h = t.ensureSemantics();
      await montar(t, const LoginScreen());
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      h.dispose();
    },
  );

  testWidgets('Login: contraste del texto (WCAG 2.1, 4.5:1)', (t) async {
    final h = t.ensureSemantics();
    await montar(t, const LoginScreen());
    await expectLater(t, meetsGuideline(textContrastGuideline));
    h.dispose();
  });

  testWidgets('Registro: pautas de etiqueta, area tactil y contraste', (
    t,
  ) async {
    final h = t.ensureSemantics();
    await montar(t, const RegisterScreen(), tam: const Size(360, 1400));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await expectLater(t, meetsGuideline(textContrastGuideline));
    h.dispose();
  });

  testWidgets(
    'Selector de fotos: boton accesible "Agregar foto" y tope de 3 fotos',
    (t) async {
      final h = t.ensureSemantics();
      await montar(
        t,
        Scaffold(
          body: FotoPickerField(onChanged: (_) {}, accent: Colors.purple),
        ),
      );
      expect(find.bySemanticsLabel('Agregar foto'), findsOneWidget);
      expect(
        const FotoPickerField(onChanged: print, accent: Colors.purple).max,
        3,
      );
      h.dispose();
    },
  );

  testWidgets(
    'Aviso de privacidad (RF-21) y de alcance (RF-20): contenido, area tactil y contraste',
    (t) async {
      final h = t.ensureSemantics();
      await montar(
        t,
        const AvisoPrivacidadScreen(),
        tam: const Size(360, 2400),
      );
      for (final titulo in [
        'Qué datos se recogen',
        'Para qué se usan',
        'Quién puede verlos',
        'Por cuánto tiempo',
        'Tus derechos',
      ]) {
        expect(find.text(titulo), findsOneWidget);
      }
      expect(find.text('20221789@aloe.ulima.edu.pe'), findsOneWidget);
      expect(find.textContaining('105 Policía'), findsOneWidget);
      expect(find.textContaining('116 Bomberos'), findsOneWidget);
      expect(find.textContaining('106 SAMU'), findsOneWidget);
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      h.dispose();
    },
  );

  for (final escala in [1.0, 2.0]) {
    testWidgets(
      'Aviso de alcance en 360 dp con texto al ${(escala * 100).round()} % sin desbordes',
      (t) async {
        await montar(
          t,
          const Scaffold(body: SingleChildScrollView(child: AvisoAlcance())),
          escala: escala,
        );
        expect(t.takeException(), isNull);
        expect(find.textContaining('simulación académica'), findsOneWidget);
      },
    );
  }
}
