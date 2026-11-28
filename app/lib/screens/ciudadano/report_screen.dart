import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/reportes_controller.dart';
import '../../models/models.dart';
import '../../services/servicio_geocoding.dart';
import '../../services/servicio_ubicacion.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/custom_toast.dart';
import '../../widgets/foto_picker.dart';
import '../../widgets/map_view.dart';
import '../../widgets/common/gradient_header.dart';
import '../../widgets/common/detail_widgets.dart';
import '../../widgets/aviso_alcance.dart';
import 'main_tabs.dart';

const int kTituloMin = 5;
const int kTituloMax = 100;
const int kDescripcionMin = 20;
const int kDescripcionMax = 1000;

/// Vista 04 Reportar (CU-04). Crea un reporte en estado PENDIENTE.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _auth = Get.find<AuthController>();
  final _reportes = Get.find<ReportesController>();
  final _geo =
      ServicioGeocoding(); // frontend: geocodifica coordenadas del mapa

  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _referenciaCtrl = TextEditingController(); // HU-17: referencia opcional
  String _tipo = TipoProblema.INFRAESTRUCTURA;
  double? _lat, _lng;
  String? _direccion;
  bool _geocodificando = false;
  List<FotoLocal> _fotos = [];
  int _pickerVersion = 0; // cambia su key para reiniciar el selector al enviar
  bool _enviando = false;

  // RF-04: ubicación del dispositivo, pedida una vez y en primer plano.
  final _ubicacion = ServicioUbicacion();
  bool _buscandoUbicacion = false;
  String? _avisoUbicacion;
  bool _ubicacionBloqueada = false;
  bool _ubicacionManual = false; // un toque en el mapa manda sobre el GPS
  bool _gpsAutomaticoHecho = false;
  int _secuenciaGeo = 0; // descarta direcciones de toques anteriores
  Worker? _vigilaPestana;

  @override
  void initState() {
    super.initState();
    // La pestaña Reportar vive en un IndexedStack: se construye al abrir la
    // app, así que el GPS se pide recién cuando el ciudadano la abre.
    final tabs = Get.find<TabsController>();
    _vigilaPestana = ever<int>(tabs.index, (i) {
      if (i == MainTabs.indiceReportar) _gpsAlAbrir();
    });
    if (tabs.index.value == MainTabs.indiceReportar) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _gpsAlAbrir());
    }
  }

  @override
  void dispose() {
    _vigilaPestana?.dispose();
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _referenciaCtrl.dispose();
    super.dispose();
  }

  void _gpsAlAbrir() {
    if (_gpsAutomaticoHecho || _lat != null) return;
    _gpsAutomaticoHecho = true;
    _usarMiUbicacion(automatico: true);
  }

  Future<void> _usarMiUbicacion({bool automatico = false}) async {
    if (_buscandoUbicacion) return;
    if (!automatico) _ubicacionManual = false;
    setState(() {
      _buscandoUbicacion = true;
      _avisoUbicacion = null;
      _ubicacionBloqueada = false;
    });
    final r = await _ubicacion.obtenerActual();
    if (!mounted) return;
    setState(() => _buscandoUbicacion = false);
    // Si mientras tanto el ciudadano marcó el punto a mano, se respeta.
    if (_ubicacionManual) return;
    if (r.exito) {
      await _onUbicacionSeleccionada(r.lat!, r.lng!, manual: false);
    } else {
      setState(() {
        _avisoUbicacion = r.motivo;
        _ubicacionBloqueada = r.negadoPermanente && !kIsWeb;
      });
    }
  }

  static const _demoAssetsInicial = [
    'assets/img/sample/poste_1.png',
    'assets/img/sample/semaforo_1.png',
    'assets/img/sample/basura_1.png',
    'assets/img/sample/hueco_1.png',
    'assets/img/sample/hueco_2.png',
    'assets/img/sample/vidrio_1.png',
    'assets/img/sample/generic_inicial.png',
  ];

  Future<void> _onUbicacionSeleccionada(
    double lat,
    double lng, {
    bool manual = true,
  }) async {
    final turno = ++_secuenciaGeo;
    setState(() {
      if (manual) _ubicacionManual = true;
      _lat = lat;
      _lng = lng;
      _avisoUbicacion = null;
      _ubicacionBloqueada = false;
      _geocodificando = true;
    });
    final dir = await _geo.obtenerDireccion(lat, lng);
    if (mounted && turno == _secuenciaGeo) {
      setState(() {
        _direccion = dir.direccionCompleta;
        _geocodificando = false;
      });
    }
  }

  Future<void> _enviar() async {
    final titulo = _tituloCtrl.text.trim();
    final descripcion = _descCtrl.text.trim();
    if (titulo.length < kTituloMin) {
      AppToast.error('El título debe tener al menos $kTituloMin caracteres');
      return;
    }
    if (descripcion.length < kDescripcionMin) {
      AppToast.error(
        'La descripción debe tener al menos $kDescripcionMin caracteres',
      );
      return;
    }
    if (_lat == null) {
      AppToast.error('Selecciona una ubicación en el mapa');
      return;
    }
    if (_fotos.isEmpty) {
      AppToast.error('Adjunta al menos una foto del incidente');
      return;
    }
    if (!await _confirmarEnvio(titulo)) return;
    setState(() => _enviando = true);
    try {
      final creado = await _reportes.crearReporte(
        CrearReporteRequest(
          titulo: titulo,
          descripcion: descripcion,
          cuentaId: _auth.cuentaId,
          tipoProblema: _tipo,
          ubicacion: CrearUbicacionRequest(
            latitud: _lat!,
            longitud: _lng!,
            direccion: _direccionConReferencia(),
          ),
        ),
        nombreCiudadano: _auth.usuario.value?.nombre,
        fotosBase64: _fotos.map((f) => f.toBase64()).toList(),
      );
      AppToast.success('Reporte #${creado.id} enviado. Estado: Pendiente');
      _reset();
      Get.find<TabsController>().go(3);
    } catch (e) {
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Dirección geocodificada más la referencia que escribió el ciudadano.
  String? _direccionConReferencia() {
    final ref = _referenciaCtrl.text.trim();
    if (ref.isEmpty) return _direccion;
    return [
      if (_direccion != null && _direccion!.isNotEmpty) _direccion!,
      'Referencia: $ref',
    ].join(' · ');
  }

  void _reset() {
    _tituloCtrl.clear();
    _descCtrl.clear();
    _referenciaCtrl.clear();
    setState(() {
      _tipo = TipoProblema.INFRAESTRUCTURA;
      _lat = null;
      _lng = null;
      _direccion = null;
      _fotos = [];
      _pickerVersion++; // fuerza un selector nuevo y vacio
      _ubicacionManual = false;
      _gpsAutomaticoHecho = false; // al volver a Reportar se vuelve a ubicar
      _avisoUbicacion = null;
      _ubicacionBloqueada = false;
    });
  }

  /// HU-03 CA1: el ciudadano revisa un resumen antes de confirmar el envío.
  Future<bool> _confirmarEnvio(String titulo) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('¿Enviar este reporte?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filaResumen(Icons.title, titulo),
            _filaResumen(AppColors.iconoTipo(_tipo), TipoProblema.label(_tipo)),
            _filaResumen(
              Icons.place,
              _direccionConReferencia() ??
                  '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
            ),
            _filaResumen(
              Icons.photo_camera,
              _fotos.length == 1 ? '1 foto' : '${_fotos.length} fotos',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.enlace),
            child: const Text('Confirmar envío'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Widget _filaResumen(IconData icono, String texto) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 14))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F8),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const GradientHeader(title: 'Reportar Incidencia', compact: true),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AvisoAlcance(),
                const SizedBox(height: 14),
                _label('Título'),
                _input(
                  _tituloCtrl,
                  'Ej. Hueco en la pista',
                  maxLength: kTituloMax,
                ),
                const SizedBox(height: 14),
                _label('Tipo de problema'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TipoProblema.values.map((t) {
                    final on = _tipo == t;
                    return ChoiceChip(
                      avatar: Icon(
                        AppColors.iconoTipo(t),
                        size: 16,
                        color: on ? Colors.white : AppColors.primary,
                      ),
                      label: Text(TipoProblema.label(t)),
                      selected: on,
                      onSelected: (_) => setState(() => _tipo = t),
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: on ? Colors.white : const Color(0xFF555555),
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _label('Descripción detallada'),
                _input(
                  _descCtrl,
                  'Describe la incidencia con detalle',
                  maxLines: 4,
                  maxLength: kDescripcionMax,
                ),
                const SizedBox(height: 14),
                _label('Ubicación: usa tu ubicación o toca el mapa'),
                MapPickerView(
                  initialLat: _lat,
                  initialLng: _lng,
                  onLocationPicked: _onUbicacionSeleccionada,
                  height: 200,
                  onUsarMiUbicacion: _usarMiUbicacion,
                  buscandoUbicacion: _buscandoUbicacion,
                ),
                if (_buscandoUbicacion)
                  _estadoUbicacion('Buscando tu ubicación...', cargando: true)
                else if (_avisoUbicacion != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_off,
                          size: 16,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _avisoUbicacion!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B4E16),
                            ),
                          ),
                        ),
                        if (_ubicacionBloqueada)
                          TextButton(
                            onPressed: _ubicacion.abrirAjustes,
                            child: const Text('Abrir ajustes'),
                          ),
                      ],
                    ),
                  ),
                if (_geocodificando)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Obteniendo dirección...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_direccion != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place,
                          size: 14,
                          color: Color(0xFF7C3AED),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _direccion!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                _input(
                  _referenciaCtrl,
                  'Referencia (opcional): frente al parque, junto al paradero...',
                  maxLength: 120,
                ),
                const SizedBox(height: 4),
                _label('Fotos (${_fotos.length}/3, mínimo 1)'),
                FotoPickerField(
                  key: ValueKey(_pickerVersion),
                  accent: AppColors.primary,
                  max: 3,
                  demoAssets: _demoAssetsInicial,
                  onChanged: (fotos) => setState(() => _fotos = fotos),
                ),
                const SizedBox(height: 22),
                WideButton(
                  'Enviar reporte',
                  AppColors.primary,
                  _enviando ? null : _enviar,
                  icon: Icons.send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoUbicacion(String texto, {bool cargando = false}) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        if (cargando)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        const SizedBox(width: 8),
        Text(
          texto,
          style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
        ),
      ],
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF444444),
      ),
    ),
  );

  // Límites de HU-03 (título 5-100, descripción 20-1000), iguales en el backend.
  Widget _input(
    TextEditingController c,
    String hint, {
    int maxLines = 1,
    int? maxLength,
  }) => TextField(
    controller: c,
    maxLines: maxLines,
    maxLength: maxLength,
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
