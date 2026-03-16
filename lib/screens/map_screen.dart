import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/weather_provider.dart';
import '../providers/app_providers.dart';
import '../utils/app_strings.dart';
import '../utils/translated_text.dart';
import '../services/translator_service.dart';
import '../utils/weather_condition_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE-LEVEL SINGLETONS
// ─────────────────────────────────────────────────────────────────────────────
final _sharedHttpClient = http.Client();
final _coordValueCache  = <String, String>{};

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a size scaled to screen width: base value was designed for 390px wide screen.
double _rw(BuildContext context, double base) =>
    base * MediaQuery.of(context).size.width / 390.0;

/// Returns a size scaled to screen height: base value was designed for 844px tall screen.
double _rh(BuildContext context, double base) =>
    base * MediaQuery.of(context).size.height / 844.0;

/// Clamp a responsive value between [min] and [max].
double _rc(double value, double min, double max) => value.clamp(min, max);

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS & DATE HELPERS
// ─────────────────────────────────────────────────────────────────────────────
const String _ncmrwfApiBase = 'https://api.ncmrwf.gov.in';
const String _appId         = '921155810533297639420383389872';
const String _wmsPressure   = '850';

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String get _wmsDateStr      => _fmtDate(DateTime.now().toUtc());
String get _apiDateTimeStr  => '${_wmsDateStr}-hr-00-00-00';
String get _odateToday      => _wmsDateStr;
String get _odateYesterday  => _fmtDate(DateTime.now().toUtc().subtract(const Duration(days: 1)));

// ─────────────────────────────────────────────────────────────────────────────
// APP STRINGS — all translatable keys used in this file
// ─────────────────────────────────────────────────────────────────────────────
extension _S on AppStrings {
  // Map screen
  static const String weatherPortal       = 'Weather Guidance Portal';
  static const String loadingChart        = 'Loading chart…';
  static const String noMeteogramData     = 'No meteogram data available';
  static const String connectApi          = AppStrings.connectAPI;

  // Chart titles
  static const String tempChartTitle      = 'Temperature (°C)';
  static const String humidChartTitle     = 'Relative Humidity (%)';
  static const String rainWindChartTitle  = 'Rainfall (mm/hr) & Wind';
  static const String windLabel           = 'Wind ↑';

  // Popup labels
  static const String temperatureLabel    = 'TEMPERATURE';
  static const String humidityLabel       = 'HUMIDITY';
  static const String rainfallLabel       = 'RAINFALL';
  static const String accRainfallLabel    = 'ACC. RAINFALL';

  // Sheet subtitles
  static const String skewTSubtitle       = 'Skew-T Log-P Diagram';
  static const String epsSubtitle         = 'Control Forecast & ENS Distribution';
  static const String epsFallback         = 'EPS Ensemble Forecast';
  static const String controlRun          = 'Control Run';
  static const String ensembleMembers     = 'Ensemble Members';
  static const String temperature         = 'Temperature';
  static const String dewpoint            = 'Dewpoint';
}

// ─────────────────────────────────────────────────────────────────────────────
// FORECAST STEP
// ─────────────────────────────────────────────────────────────────────────────
class _ForecastStep {
  final DateTime dt;
  final String   dateStr;
  final String   dateTimeStr;
  const _ForecastStep({required this.dt, required this.dateStr, required this.dateTimeStr});
}

List<_ForecastStep> _buildForecastSteps() {
  final base  = DateTime.now().toUtc();
  final start = DateTime.utc(base.year, base.month, base.day);
  final steps = <_ForecastStep>[];
  for (int h = 0; h <= 4 * 24; h += 6) {
    final dt    = start.add(Duration(hours: h));
    final dStr  = _fmtDate(dt);
    final dtStr = '$dStr-hr-${dt.hour.toString().padLeft(2, '0')}-00-00';
    steps.add(_ForecastStep(dt: dt, dateStr: dStr, dateTimeStr: dtStr));
  }
  return steps;
}

// ─────────────────────────────────────────────────────────────────────────────
// ISOLATE PARSE
// ─────────────────────────────────────────────────────────────────────────────
List<MeteogramEntry> _parseMeteogramIsolate(String body) {
  try {
    final json   = jsonDecode(body) as Map<String, dynamic>;
    final output = json['output'] as List<dynamic>;
    return output.map((e) => MeteogramEntry.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) { debugPrint('[isolate] meteogram parse error: $e'); return []; }
}

// ─────────────────────────────────────────────────────────────────────────────
// NCMRWF API SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class _NcmrwfApiService {
  static Future<String?> fetchCoordValue({
    required String endpoint, required double lat, required double lon,
    String? pressure, bool isRetry = false,
  }) async {
    final cacheKey = '$endpoint-${lat.toStringAsFixed(2)}-${lon.toStringAsFixed(2)}';
    if (_coordValueCache.containsKey(cacheKey)) return _coordValueCache[cacheKey];
    try {
      final params = <String, String>{
        'appid': _appId, 'date': _apiDateTimeStr, 'odate': _odateToday,
        'lat': lat.toStringAsFixed(6), 'lon': lon.toStringAsFixed(6),
      };
      if (pressure != null) params['pressure'] = pressure;
      final uri = Uri.parse('$_ncmrwfApiBase/$endpoint/').replace(queryParameters: params);
      final res = await _sharedHttpClient
          .get(uri, headers: {'Accept': 'application/json', 'User-Agent': 'ncmrwf_weather_app/1.0'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body  = res.body.trim();
        if (body.isEmpty) return null;
        final json  = jsonDecode(body);
        final value = json['output'] ?? json['value'] ?? json['data'] ?? json['result'];
        if (value == null) return null;
        final str = value.toString();
        _coordValueCache[cacheKey] = str;
        return str;
      }
    } catch (e) {
      if (!isRetry) {
        await Future.delayed(const Duration(seconds: 2));
        return fetchCoordValue(endpoint: endpoint, lat: lat, lon: lon, pressure: pressure, isRetry: true);
      }
    }
    return null;
  }

  static Future<List<MeteogramEntry>> fetchMeteogram({required double lat, required double lon}) async {
    try {
      final params = {'appid': _appId, 'coords': '$lat,$lon', 'date': _apiDateTimeStr, 'odate': _odateToday};
      final uri = Uri.parse('$_ncmrwfApiBase/meteogram/').replace(queryParameters: params);
      final res = await _sharedHttpClient
          .get(uri, headers: {'Accept': 'application/json', 'User-Agent': 'ncmrwf_weather_app/1.0'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return await compute(_parseMeteogramIsolate, res.body);
    } catch (e) { debugPrint('[meteogram] error: $e'); }
    return [];
  }

  static String verticalProfileUrl({required double lat, required double lon}) {
    final params = {'appid': _appId, 'coords': '$lat,$lon', 'odate': '${_odateYesterday}-hr-00-00-00'};
    return Uri.parse('$_ncmrwfApiBase/vprofile/').replace(queryParameters: params).toString();
  }

  static String epsgramUrl({required double lat, required double lon}) {
    final now      = DateTime.now().toUtc();
    final dateStr  = '${_fmtDate(now)}-hr-00-00-00';
    final odateStr = _fmtDate(now.subtract(const Duration(days: 1)));
    final params   = {'appid': _appId, 'coords': '$lat,$lon', 'date': dateStr, 'odate': odateStr};
    return Uri.parse('$_ncmrwfApiBase/eps/').replace(queryParameters: params).toString();
  }

  static Future<String> reverseGeocode({required double lat, required double lon}) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(queryParameters: {
        'lat': lat.toStringAsFixed(6), 'lon': lon.toStringAsFixed(6), 'format': 'json', 'zoom': '10',
      });
      final res = await _sharedHttpClient
          .get(uri, headers: {'User-Agent': 'ncmrwf_weather_app/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = json['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final parts = <String>[];
          final city  = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'];
          if (city  != null) parts.add(city  as String);
          final state = addr['state'];
          if (state != null) parts.add(state as String);
          if (parts.isNotEmpty) return parts.join(', ');
        }
        return (json['display_name'] as String? ?? '').split(',').take(2).join(',');
      }
    } catch (e) { debugPrint('geocode err: $e'); }
    return 'lat=${lat.toStringAsFixed(3)}, lon=${lon.toStringAsFixed(3)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────
class MeteogramEntry {
  final String time;
  final double airTemperature, relativeHumidity, windSpeed, windFromDirection, rainfall;
  const MeteogramEntry({
    required this.time, required this.airTemperature, required this.relativeHumidity,
    required this.windSpeed, required this.windFromDirection, required this.rainfall,
  });
  factory MeteogramEntry.fromJson(Map<String, dynamic> j) => MeteogramEntry(
    time: j['time'] as String,
    airTemperature:    (j['air_temperature']    as num).toDouble(),
    relativeHumidity:  (j['relative_humidity']  as num).toDouble(),
    windSpeed:         (j['wind_speed']          as num).toDouble(),
    windFromDirection: (j['wind_from_direction'] as num).toDouble(),
    rainfall:          (j['rainfall']            as num).toDouble(),
  );
  String get hourLabel { final p = time.split('-'); return p.length >= 5 ? '${p[3]}:00' : time; }
  String get dayLabel  { final p = time.split('-'); return p.length >= 3 ? '${p[2]}/${p[1]}' : time; }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEATHER LAYER MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _WeatherLayer {
  final String id, labelKey, wmsBaseUrl, coordEndpoint, unit;
  final IconData icon;
  final List<Color> legendColors;
  final List<String> legendLabels;
  const _WeatherLayer({
    required this.id, required this.labelKey, required this.icon,
    required this.wmsBaseUrl, required this.coordEndpoint, required this.unit,
    required this.legendColors, required this.legendLabels,
  });
}

const List<_WeatherLayer> _layers = [
  _WeatherLayer(
    id: 'temperature', labelKey: AppStrings.temperature, icon: Icons.thermostat_rounded,
    wmsBaseUrl: 'https://api.ncmrwf.gov.in/temperature/', coordEndpoint: 'temperature', unit: '°C',
    legendColors: [Color(0xFF4575B4),Color(0xFF74ADD1),Color(0xFFABD9E9),Color(0xFFE0F3F8),Color(0xFFFEE090),Color(0xFFFDAE61),Color(0xFFF46D43),Color(0xFFD73027)],
    legendLabels: ['-40','-20','-10','0','15','25','35','50'],
  ),
  _WeatherLayer(
    id: 'humidity', labelKey: AppStrings.humidity, icon: Icons.water_drop_rounded,
    wmsBaseUrl: 'https://api.ncmrwf.gov.in/humidity/', coordEndpoint: 'humidity', unit: '%',
    legendColors: [Color(0xFFFFF9C4),Color(0xFFFFF176),Color(0xFFFFEE58),Color(0xFF81D4FA),Color(0xFF29B6F6),Color(0xFF0288D1),Color(0xFF01579B),Color(0xFF003366)],
    legendLabels: ['0','10','20','40','60','70','80','100'],
  ),
  _WeatherLayer(
    id: 'rainfall', labelKey: AppStrings.rainfall, icon: Icons.grain_rounded,
    wmsBaseUrl: 'https://api.ncmrwf.gov.in/rainfall/', coordEndpoint: 'rainfall', unit: 'mm',
    legendColors: [Color(0xFFE8F5E9),Color(0xFFC8E6C9),Color(0xFFA5D6A7),Color(0xFF66BB6A),Color(0xFF2E7D32),Color(0xFF0D47A1),Color(0xFF4A148C)],
    legendLabels: ['0','0.5','2','5','10','50','200'],
  ),
  _WeatherLayer(
    id: 'acurain', labelKey: AppStrings.accRainfall, icon: Icons.water_rounded,
    wmsBaseUrl: 'https://api.ncmrwf.gov.in/acurain/', coordEndpoint: 'acurain', unit: 'mm',
    legendColors: [Color(0xFFF3E5F5),Color(0xFFE1BEE7),Color(0xFFCE93D8),Color(0xFFAB47BC),Color(0xFF7B1FA2),Color(0xFF4A148C),Color(0xFF1A0030)],
    legendLabels: ['0','5','10','25','50','100','200+'],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// INDIA SHAPEFILE OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
typedef _ShapeData = List<List<List<double>>>;

Future<_ShapeData> _loadShapeData() async {
  try {
    final raw     = await rootBundle.loadString('assets/data/india_states_compact.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map<List<List<double>>>((poly) {
      return (poly as List<dynamic>).map<List<double>>((ring) {
        return (ring as List<dynamic>).map<double>((v) => (v as num).toDouble()).toList();
      }).toList();
    }).toList();
  } catch (e) { debugPrint('[shapefile] load error: $e'); return []; }
}

class _IndiaShapeOverlay extends StatefulWidget {
  final bool visible;
  const _IndiaShapeOverlay({required this.visible});
  @override State<_IndiaShapeOverlay> createState() => _IndiaShapeOverlayState();
}

class _IndiaShapeOverlayState extends State<_IndiaShapeOverlay> {
  _ShapeData _shapes = [];
  bool _loaded = false;

  @override void initState() {
    super.initState();
    _loadShapeData().then((data) {
      if (mounted) setState(() { _shapes = data; _loaded = true; });
    });
  }

  @override Widget build(BuildContext context) {
    if (!widget.visible || !_loaded || _shapes.isEmpty) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    return RepaintBoundary(
      child: CustomPaint(painter: _ShapePainter(shapes: _shapes, camera: camera), size: Size.infinite),
    );
  }
}

class _ShapePainter extends CustomPainter {
  final _ShapeData shapes;
  final MapCamera  camera;
  _ShapePainter({required this.shapes, required this.camera});

  @override void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFFFFFFFF)..strokeWidth = 1.6
      ..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)..strokeWidth = 3.0
      ..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;

    for (final polygon in shapes) {
      for (final ring in polygon) {
        if (ring.length < 4) continue;
        final path = ui.Path(); bool started = false;
        for (int i = 0; i < ring.length - 1; i += 2) {
          final pt = camera.latLngToScreenPoint(LatLng(ring[i + 1], ring[i]));
          if (!started) { path.moveTo(pt.x, pt.y); started = true; }
          else            path.lineTo(pt.x, pt.y);
        }
        canvas.drawPath(path, shadowPaint);
        canvas.drawPath(path, borderPaint);
      }
    }
  }

  @override bool shouldRepaint(covariant _ShapePainter old) => old.camera != camera || old.shapes != shapes;
}

// ─────────────────────────────────────────────────────────────────────────────
// MAP SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  int _selectedLayer = 0;
  final MapController _mapController = MapController();
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;
  bool    _showLegend       = true;
  bool    _showShapeOverlay = true;
  LatLng? _tappedLatLng;
  Offset? _tappedScreen;
  bool    _showPopup        = false;
  final GlobalKey _mapKey   = GlobalKey();
  DateTime? _lastTapTime;

  late List<_ForecastStep> _steps;
  int    _sliderIndex = 0;
  bool   _isPlaying   = false;
  Timer? _playTimer;

  @override void initState() {
    super.initState();
    _steps    = _buildForecastSteps();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override void dispose() { _fadeCtrl.dispose(); _playTimer?.cancel(); super.dispose(); }

  void _switchLayer(int idx) {
    if (idx == _selectedLayer) return;
    _fadeCtrl.reset();
    setState(() { _selectedLayer = idx; _showPopup = false; });
    _fadeCtrl.forward();
  }

  void _onMapTap(TapPosition tapPos, LatLng point) {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 500) return;
    _lastTapTime = now;
    final pt = _mapController.camera.latLngToScreenPoint(point);
    setState(() { _tappedLatLng = point; _tappedScreen = Offset(pt.x, pt.y); _showPopup = true; });
  }

  void _closePopup() => setState(() => _showPopup = false);

  void _openMeteogram(LatLng pt) {
    _closePopup();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => _MeteogramSheet(point: pt));
  }
  void _openVerticalProfile(LatLng pt) {
    _closePopup();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => _VerticalProfileSheet(point: pt));
  }
  void _openEPSgram(LatLng pt) {
    _closePopup();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => _EPSgramSheet(point: pt));
  }

  Map<String, String> _wmsParams({String? pressure}) {
    final step = _steps[_sliderIndex];
    final odateFixed = step.dt.hour == 0
        ? _fmtDate(step.dt.subtract(const Duration(days: 1)))
        : step.dateStr;
    return {
      'service': 'WMS', 'request': 'GetMap',
      'appid': _appId, 'styles': '',
      'date': step.dateTimeStr, 'odate': odateFixed,
      if (pressure != null) 'pressure': pressure,
      'srs': 'EPSG:3857',
    };
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsProvider>();
    final mq     = MediaQuery.of(context);
    final sw     = mq.size.width;
    final isWide = sw >= 600; // tablet/large phone

    return Consumer<WeatherProvider>(builder: (ctx, wp, _) {
      final layer     = _layers[_selectedLayer];
      final centerLat = wp.latitude  != 0.0 ? wp.latitude  : 20.5937;
      final centerLon = wp.longitude != 0.0 ? wp.longitude : 78.9629;

      // Responsive slider panel height
      final sliderH = isWide ? 140.0 : 128.0;

      return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: Stack(children: [

          // ── FULL-SCREEN MAP ─────────────────────────────────────────────
          Positioned.fill(
            key: _mapKey,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(centerLat, centerLon),
                initialZoom: 5.0, minZoom: 2.0, maxZoom: 12.0,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.example.new_ncmrwf_app', maxZoom: 19,
                ),
                if (_selectedLayer == 0)
                  TileLayer(
                    key: ValueKey('layer_temperature_$_sliderIndex'),
                    wmsOptions: WMSTileLayerOptions(
                      baseUrl: 'https://api.ncmrwf.gov.in/temperature/?',
                      layers: const ['dhurbi:road'], format: 'image/png', transparent: true, version: '1.1.1',
                      otherParameters: _wmsParams(pressure: '850'),
                    ),
                    userAgentPackageName: 'com.example.new_ncmrwf_app',
                  ),
                if (_selectedLayer == 1)
                  TileLayer(
                    key: ValueKey('layer_humidity_$_sliderIndex'),
                    wmsOptions: WMSTileLayerOptions(
                      baseUrl: 'https://api.ncmrwf.gov.in/humidity/?',
                      layers: const ['dhurbi:road'], format: 'image/png', transparent: true, version: '1.1.1',
                      otherParameters: _wmsParams(pressure: '850'),
                    ),
                    userAgentPackageName: 'com.example.new_ncmrwf_app',
                  ),
                if (_selectedLayer == 2)
                  TileLayer(
                    key: ValueKey('layer_rainfall_$_sliderIndex'),
                    wmsOptions: WMSTileLayerOptions(
                      baseUrl: 'https://api.ncmrwf.gov.in/rainfall/?',
                      layers: const ['dhurbi:road'], format: 'image/png', transparent: true, version: '1.1.1',
                      otherParameters: _wmsParams(),
                    ),
                    userAgentPackageName: 'com.example.new_ncmrwf_app',
                  ),
                if (_selectedLayer == 3)
                  TileLayer(
                    key: ValueKey('layer_acurain_$_sliderIndex'),
                    wmsOptions: WMSTileLayerOptions(
                      baseUrl: 'https://api.ncmrwf.gov.in/acurain/?',
                      layers: const ['dhurbi:road'], format: 'image/png', transparent: true, version: '1.1.1',
                      otherParameters: _wmsParams(),
                    ),
                    userAgentPackageName: 'com.example.new_ncmrwf_app',
                  ),
                _IndiaShapeOverlay(visible: _showShapeOverlay),
                if (wp.latitude != 0.0 && wp.longitude != 0.0)
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(wp.latitude, wp.longitude),
                      width:  _rc(_rw(context, 140), 100, 180),
                      height: _rc(_rh(context, 72),   56,  90),
                      child: _LocationMarker(wp: wp, layer: _layers[_selectedLayer]),
                    ),
                  ]),
              ],
            ),
          ),

          // ── TOP BAR ─────────────────────────────────────────────────────
          Positioned(top: 0, left: 0, right: 0,
            child: SafeArea(bottom: false, child: Padding(
              padding: EdgeInsets.fromLTRB(
                _rc(_rw(context, 10), 8, 16),
                _rc(_rh(context, 8),  6, 12),
                _rc(_rw(context, 10), 8, 16),
                0,
              ),
              child: Row(children: [
                // Title pill
                Expanded(child: _GlassCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: _rc(_rw(context, 12), 8, 18),
                    vertical:   _rc(_rh(context,  9), 6, 12),
                  ),
                  child: Row(children: [
                    Container(
                      width:  _rc(_rw(context, 28), 22, 38),
                      height: _rc(_rw(context, 28), 22, 38),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0D47A1).withOpacity(0.85)),
                      child: Icon(Icons.satellite_alt_rounded, color: Colors.white,
                          size: _rc(_rw(context, 14), 11, 18)),
                    ),
                    SizedBox(width: _rc(_rw(context, 8), 6, 12)),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TranslatedText(
                          _S.weatherPortal,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: _rc(_rw(context, 13), 10, 16),
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (wp.placeName.isNotEmpty)
                          Text(wp.placeName,
                              style: GoogleFonts.dmSans(
                                  color: Colors.white54,
                                  fontSize: _rc(_rw(context, 10), 8, 13)),
                              overflow: TextOverflow.ellipsis),
                      ],
                    )),
                  ]),
                )),
                SizedBox(width: _rc(_rw(context, 6), 4, 10)),

                _GlassIconBtn(
                  icon: _showLegend ? Icons.layers_rounded : Icons.layers_outlined,
                  active: _showLegend,
                  onTap: () => setState(() => _showLegend = !_showLegend),
                  size: _rc(_rw(context, 38), 30, 48),
                  iconSize: _rc(_rw(context, 17), 14, 22),
                ),
                SizedBox(width: _rc(_rw(context, 6), 4, 10)),

                _GlassIconBtn(
                  icon: _showShapeOverlay ? Icons.crop_free_rounded : Icons.border_clear_rounded,
                  active: _showShapeOverlay,
                  onTap: () => setState(() => _showShapeOverlay = !_showShapeOverlay),
                  size: _rc(_rw(context, 38), 30, 48),
                  iconSize: _rc(_rw(context, 17), 14, 22),
                ),

                if (wp.latitude != 0.0) ...[
                  SizedBox(width: _rc(_rw(context, 6), 4, 10)),
                  _GlassIconBtn(
                    icon: Icons.my_location_rounded,
                    onTap: () => _mapController.move(LatLng(wp.latitude, wp.longitude), 6),
                    size: _rc(_rw(context, 38), 30, 48),
                    iconSize: _rc(_rw(context, 17), 14, 22),
                  ),
                ],
              ]),
            )),
          ),

          // ── LAYER CHIPS ─────────────────────────────────────────────────
          Positioned(
            top: mq.padding.top + _rc(_rh(context, 64), 54, 80),
            left: 0, right: 0,
            child: SizedBox(
              height: _rc(_rh(context, 40), 34, 52),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: _rc(_rw(context, 10), 8, 16)),
                itemCount: _layers.length,
                itemBuilder: (ctx, i) {
                  final sel = i == _selectedLayer;
                  final l   = _layers[i];
                  return GestureDetector(
                    onTap: () => _switchLayer(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      margin: EdgeInsets.only(right: _rc(_rw(context, 8), 6, 12)),
                      padding: EdgeInsets.symmetric(
                        horizontal: _rc(_rw(context, 14), 10, 20),
                        vertical:   _rc(_rh(context,  7),  5, 10),
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: sel
                            ? const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight)
                            : null,
                        color: sel ? null : Colors.black.withOpacity(0.48),
                        border: Border.all(
                          color: sel ? const Color(0xFF42A5F5) : Colors.white.withOpacity(0.22),
                          width: sel ? 1.5 : 1.0,
                        ),
                        boxShadow: sel
                            ? [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.40),
                            blurRadius: 10, spreadRadius: 1)]
                            : null,
                      ),
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(l.icon,
                                color: sel ? Colors.white : Colors.white70,
                                size: _rc(_rw(context, 13), 10, 17)),
                            SizedBox(width: _rc(_rw(context, 6), 4, 9)),
                            TranslatedText(l.labelKey,
                                style: GoogleFonts.dmSans(
                                  color: sel ? Colors.white : Colors.white70,
                                  fontSize: _rc(_rw(context, 12), 10, 15),
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                )),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── ZOOM CONTROLS ───────────────────────────────────────────────
          Positioned(
            left: _rc(_rw(context, 10), 8, 16),
            bottom: sliderH + _rc(_rh(context, 14), 10, 20),
            child: _buildZoomControls(context),
          ),

          // ── LEGEND ──────────────────────────────────────────────────────
          if (_showLegend)
            Positioned(
              left: _rc(_rw(context, 58), 48, 72),
              right: _rc(_rw(context, 10), 8, 16),
              bottom: sliderH + _rc(_rh(context, 12), 8, 18),
              child: _GlassCard(
                padding: EdgeInsets.symmetric(
                  horizontal: _rc(_rw(context, 12), 8, 18),
                  vertical:   _rc(_rh(context,  8), 6, 12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Icon(layer.icon, color: Colors.white60,
                        size: _rc(_rw(context, 11), 9, 15)),
                    SizedBox(width: _rc(_rw(context, 5), 4, 8)),
                    FutureBuilder<String>(
                      future: TranslatorService.translate(layer.labelKey),
                      initialData: layer.labelKey,
                      builder: (_, s) => Text(
                        '${s.data}  (${layer.unit})',
                        style: GoogleFonts.dmSans(
                          color: Colors.white60,
                          fontSize: _rc(_rw(context, 10), 8, 13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                  SizedBox(height: _rc(_rh(context, 5), 4, 8)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: _rc(_rh(context, 9), 7, 13),
                      child: Row(
                        children: layer.legendColors
                            .map((c) => Expanded(child: ColoredBox(color: c)))
                            .toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: _rc(_rh(context, 3), 2, 5)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: layer.legendLabels.map((l) => Text(l,
                        style: GoogleFonts.dmSans(
                            color: Colors.white38,
                            fontSize: _rc(_rw(context, 8), 7, 11)))).toList(),
                  ),
                ]),
              ),
            ),

          // ── TAP POPUP ───────────────────────────────────────────────────
          if (_showPopup && _tappedLatLng != null && _tappedScreen != null)
            _buildFloatingPopup(layer, wp, context),

          // ── FORECAST TIMELINE SLIDER ────────────────────────────────────
          Positioned(bottom: 0, left: 0, right: 0,
            child: _ForecastSliderPanel(
              steps        : _steps,
              selectedIndex: _sliderIndex,
              isPlaying    : _isPlaying,
              layer        : layer,
              panelHeight  : sliderH,
              onChanged    : (i) => setState(() { _sliderIndex = i; _showPopup = false; }),
              onPlayPause  : () {
                setState(() => _isPlaying = !_isPlaying);
                if (_isPlaying) {
                  _playTimer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
                    if (!mounted) { _playTimer?.cancel(); return; }
                    setState(() {
                      _sliderIndex = (_sliderIndex + 1) % _steps.length;
                      if (_sliderIndex == 0) { _isPlaying = false; _playTimer?.cancel(); }
                    });
                  });
                } else {
                  _playTimer?.cancel();
                  _playTimer = null;
                }
              },
            ),
          ),
        ]),
      );
    });
  }

  Widget _buildZoomControls(BuildContext context) {
    final btnSize  = _rc(_rw(context, 38), 30, 50);
    final iconSize = _rc(_rw(context, 20), 16, 26);
    return ClipRRect(
      borderRadius: BorderRadius.circular(_rc(_rw(context, 12), 8, 16)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(_rc(_rw(context, 12), 8, 16)),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _ZoomBtn(icon: Icons.add_rounded,    iconSize: iconSize, btnSize: btnSize,
                onTap: () => _mapController.move(_mapController.camera.center,
                    (_mapController.camera.zoom + 1).clamp(2.0, 12.0))),
            Container(height: 1, width: btnSize * 0.85, color: Colors.white12),
            _ZoomBtn(icon: Icons.remove_rounded, iconSize: iconSize, btnSize: btnSize,
                onTap: () => _mapController.move(_mapController.camera.center,
                    (_mapController.camera.zoom - 1).clamp(2.0, 12.0))),
          ]),
        ),
      ),
    );
  }

  Widget _buildFloatingPopup(_WeatherLayer layer, WeatherProvider wp, BuildContext context) {
    final sw       = MediaQuery.of(context).size.width;
    final popupW   = _rc(sw * 0.55, 180, 260);
    const popupH   = 210.0;
    const pinGap   = 10.0;
    final RenderBox? box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    final mapW = box?.size.width  ?? sw;
    final mapH = box?.size.height ?? MediaQuery.of(context).size.height;
    final left = (_tappedScreen!.dx - popupW / 2).clamp(6.0, mapW - popupW - 6.0);
    final top  = (_tappedScreen!.dy - popupH - pinGap).clamp(6.0, mapH - popupH - 6.0);
    return Positioned(left: left, top: top,
      child: _TapPopup(
        layer: layer, point: _tappedLatLng!, wp: wp,
        popupWidth: popupW,
        onClose: _closePopup,
        onMeteogram:       () => _openMeteogram(_tappedLatLng!),
        onVerticalProfile: () => _openVerticalProfile(_tappedLatLng!),
        onEPSgram:         () => _openEPSgram(_tappedLatLng!),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORECAST SLIDER PANEL — fully responsive
// ─────────────────────────────────────────────────────────────────────────────
class _ForecastSliderPanel extends StatefulWidget {
  final List<_ForecastStep> steps;
  final int                 selectedIndex;
  final bool                isPlaying;
  final _WeatherLayer       layer;
  final double              panelHeight;
  final ValueChanged<int>   onChanged;
  final VoidCallback        onPlayPause;

  const _ForecastSliderPanel({
    required this.steps, required this.selectedIndex, required this.isPlaying,
    required this.layer,  required this.onChanged,    required this.onPlayPause,
    this.panelHeight = 128.0,
  });

  @override State<_ForecastSliderPanel> createState() => _ForecastSliderPanelState();
}

class _ForecastSliderPanelState extends State<_ForecastSliderPanel> {
  final _scrollCtrl = ScrollController();

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  @override void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  @override void didUpdateWidget(covariant _ForecastSliderPanel old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  void _scrollToSelected() {
    if (!_scrollCtrl.hasClients) return;
    const dotW = 24.0;
    final vp     = _scrollCtrl.position.viewportDimension;
    final target = widget.selectedIndex * dotW - vp / 2 + dotW / 2;
    _scrollCtrl.animateTo(target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  String get _dateLabel {
    final s = widget.steps[widget.selectedIndex];
    return '${_days[(s.dt.weekday - 1) % 7]}, ${s.dt.day} ${_months[s.dt.month - 1]} ${s.dt.year}';
  }
  String get _timeLabel => '${widget.steps[widget.selectedIndex].dt.hour.toString().padLeft(2, '0')}:00 UTC';

  @override
  Widget build(BuildContext context) {
    final mq         = MediaQuery.of(context);
    final safeBottom = mq.padding.bottom;
    final sw         = mq.size.width;

    // Responsive sizes within the panel
    final playBtnSize  = _rc(_rw(context, 42), 34, 54);
    final dateFontSize = _rc(_rw(context, 14), 11, 18);
    final timeFontSize = _rc(_rw(context, 11),  9, 14);
    final badgeFontSz  = _rc(_rw(context, 11),  9, 14);
    final hPad         = _rc(_rw(context, 14), 10, 20);

    const Color panelBg     = Color(0xFFE3F2FD);
    const Color panelBorder = Color(0xFF90CAF9);
    const Color dotActive   = Color(0xFF1565C0);
    const Color dotDay      = Color(0xFF1E88E5);
    const Color dotOther    = Color(0xFFBBDEFB);
    const Color textPrimary = Color(0xFF0D2B5E);
    const Color textSub     = Color(0xFF5B8CB7);
    const Color badgeBg     = Color(0xFFBBDEFB);
    const Color badgeBorder = Color(0xFF64B5F6);

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        border: const Border(top: BorderSide(color: panelBorder, width: 1.5)),
        boxShadow: [BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.12), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      height: widget.panelHeight + safeBottom,
      child: Column(children: [

        // ── Header ─────────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, _rc(_rh(context, 10), 8, 14), hPad, 2),
          child: Row(children: [

            // Play/Pause button
            GestureDetector(
              onTap: widget.onPlayPause,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: playBtnSize, height: playBtnSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: widget.isPlaying
                        ? [const Color(0xFF1565C0), const Color(0xFF1E88E5)]
                        : [const Color(0xFF42A5F5), const Color(0xFF1565C0)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.45),
                    blurRadius: widget.isPlaying ? 16 : 8,
                    spreadRadius: widget.isPlaying ? 3 : 0,
                  )],
                ),
                child: Icon(
                  widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: _rc(_rw(context, 22), 16, 28),
                ),
              ),
            ),
            SizedBox(width: _rc(_rw(context, 12), 8, 18)),

            // Date & time — translated
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                TranslatedText(
                  _dateLabel,
                  style: GoogleFonts.dmSans(color: textPrimary, fontSize: dateFontSize, fontWeight: FontWeight.w800),
                ),
                TranslatedText(
                  _timeLabel,
                  style: GoogleFonts.dmSans(color: textSub, fontSize: timeFontSize, fontWeight: FontWeight.w500),
                ),
              ]),
            ),

            // Layer badge
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: _rc(_rw(context, 10), 7, 14),
                vertical:   _rc(_rh(context,  5), 3,  8),
              ),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: badgeBorder, width: 1.2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.layer.icon, color: dotActive,
                    size: _rc(_rw(context, 12), 10, 16)),
                SizedBox(width: _rc(_rw(context, 5), 3, 8)),
                TranslatedText(widget.layer.labelKey,
                    style: GoogleFonts.dmSans(
                        color: textPrimary, fontSize: badgeFontSz, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),

        // ── Progress bar ────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, _rc(_rh(context, 6), 4, 9), hPad, 2),
          child: LayoutBuilder(builder: (_, c) {
            final frac = widget.steps.isEmpty ? 0.0 : widget.selectedIndex / (widget.steps.length - 1);
            return ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(children: [
                Container(height: 4, color: dotOther),
                FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1565C0)]),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ]),
            );
          }),
        ),

        // ── Dot timeline ────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller     : _scrollCtrl,
            scrollDirection: Axis.horizontal,
            physics        : const ClampingScrollPhysics(),
            padding        : EdgeInsets.symmetric(horizontal: hPad),
            itemCount      : widget.steps.length,
            itemBuilder    : (ctx, i) {
              final s     = widget.steps[i];
              final isSel = i == widget.selectedIndex;
              final isDay = s.dt.hour == 0;
              final isMid = s.dt.hour == 12;

              final dotSel   = _rc(_rw(context, 14), 11, 18);
              final dotBig   = _rc(_rw(context,  8),  6, 11);
              final dotSmall = _rc(_rw(context,  5),  4,  7);
              final dotWidth = _rc(_rw(context, 24), 20, 30);

              return GestureDetector(
                onTap: () => widget.onChanged(i),
                child: SizedBox(
                  width: dotWidth,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(
                      height: _rc(_rh(context, 16), 13, 20),
                      child: isDay
                          ? TranslatedText(
                        _days[(s.dt.weekday - 1) % 7],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                            color: textPrimary,
                            fontSize: _rc(_rw(context, 9), 7, 12),
                            fontWeight: FontWeight.w800),
                      )
                          : isMid
                          ? TranslatedText(
                        '12',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                            color: textSub,
                            fontSize: _rc(_rw(context, 8), 6, 11)),
                      )
                          : const SizedBox.shrink(),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width : isSel ? dotSel : (isDay ? dotBig : dotSmall),
                      height: isSel ? dotSel : (isDay ? dotBig : dotSmall),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSel ? dotActive : (isDay ? dotDay : dotOther),
                        border: isSel ? Border.all(color: Colors.white, width: 2) : null,
                        boxShadow: isSel
                            ? [BoxShadow(color: dotActive.withOpacity(0.50),
                            blurRadius: 10, spreadRadius: 2)]
                            : null,
                      ),
                    ),
                    SizedBox(height: _rc(_rh(context, 3), 2, 5)),
                    SizedBox(
                      height: _rc(_rh(context, 13), 10, 17),
                      child: isSel
                          ? TranslatedText(
                        '${s.dt.hour.toString().padLeft(2, '0')}h',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                            color: dotActive,
                            fontSize: _rc(_rw(context, 9), 7, 12),
                            fontWeight: FontWeight.w800),
                      )
                          : const SizedBox.shrink(),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),

        SizedBox(height: safeBottom),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _GlassCard({required this.child, this.padding = const EdgeInsets.all(10)});

  @override Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.52),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.13)),
        ),
        child: child,
      ),
    ),
  );
}

class _GlassIconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  final bool         active;
  final double       size;
  final double       iconSize;

  const _GlassIconBtn({
    required this.icon, required this.onTap,
    this.active = false, this.size = 38, this.iconSize = 17,
  });

  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.29),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF0D47A1).withOpacity(0.85)
                : Colors.black.withOpacity(0.48),
            borderRadius: BorderRadius.circular(size * 0.29),
            border: Border.all(color: Colors.white.withOpacity(active ? 0.28 : 0.14)),
          ),
          child: Icon(icon, color: active ? Colors.white : Colors.white70, size: iconSize),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCATION MARKER
// ─────────────────────────────────────────────────────────────────────────────
class _LocationMarker extends StatelessWidget {
  final WeatherProvider wp;
  final _WeatherLayer   layer;
  const _LocationMarker({required this.wp, required this.layer});

  String get _value {
    switch (layer.id) {
      case 'temperature': return wp.liveTemperatureC    != 0.0 ? '${wp.liveTemperatureC.toStringAsFixed(1)}°C' : '--°C';
      case 'humidity':    return wp.liveHumidityPercent != 0.0 ? '${wp.liveHumidityPercent.toStringAsFixed(0)}%' : '--%';
      case 'rainfall':    return '${wp.liveRainMm.toStringAsFixed(1)} mm';
      case 'acurain':     return '${wp.accumulatedRainMm.toStringAsFixed(1)} mm';
      default:            return '--';
    }
  }

  IconData get _icon {
    switch (layer.id) {
      case 'temperature': return Icons.thermostat_rounded;
      case 'humidity':    return Icons.water_drop_rounded;
      default:            return Icons.grain_rounded;
    }
  }

  @override Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _rc(_rw(context, 10), 7, 14),
            vertical:   _rc(_rh(context,  5), 3,  8),
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.60),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_icon, color: Colors.white70, size: _rc(_rw(context, 11), 9, 15)),
            SizedBox(width: _rc(_rw(context, 4), 3, 6)),
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(wp.placeName.split(',').first,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: _rc(_rw(context, 9), 7, 12),
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis),
              Text(_value, style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: _rc(_rw(context, 12), 10, 16),
                  fontWeight: FontWeight.w800)),
            ]),
          ]),
        ),
      ),
    ),
    Container(width: 2, height: 8, color: Colors.white.withOpacity(0.8)),
    Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// TAP POPUP
// ─────────────────────────────────────────────────────────────────────────────
class _TapPopup extends StatefulWidget {
  final _WeatherLayer layer; final LatLng point; final WeatherProvider wp; final double popupWidth;
  final VoidCallback onClose, onMeteogram, onVerticalProfile, onEPSgram;
  const _TapPopup({
    required this.layer, required this.point, required this.wp,
    required this.onClose, required this.onMeteogram, required this.onVerticalProfile, required this.onEPSgram,
    this.popupWidth = 215,
  });
  @override State<_TapPopup> createState() => _TapPopupState();
}

class _TapPopupState extends State<_TapPopup> {
  int    _selectedOption = 0;
  String _liveValue      = '…';
  String _locationName   = '…';
  bool   _isLoading      = true;
  bool   _failed         = false;

  @override void initState() { super.initState(); _fetchAll(); }

  Future<void> _fetchAll() async {
    setState(() { _isLoading = true; _failed = false; });
    final results = await Future.wait([
      _NcmrwfApiService.fetchCoordValue(
          endpoint: widget.layer.coordEndpoint,
          lat: widget.point.latitude, lon: widget.point.longitude, pressure: _wmsPressure),
      _NcmrwfApiService.reverseGeocode(lat: widget.point.latitude, lon: widget.point.longitude),
    ]);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      final raw  = results[0] as String?;
      if (raw != null) {
        final d = double.tryParse(raw);
        _liveValue = d != null ? '${d.toStringAsFixed(1)} ${widget.layer.unit}' : '$raw ${widget.layer.unit}';
      } else { _liveValue = 'N/A'; }
      _failed       = raw == null;
      _locationName = results[1] as String;
    });
  }

  String get _paramLabelKey {
    switch (widget.layer.id) {
      case 'temperature': return _S.temperatureLabel;
      case 'humidity':    return _S.humidityLabel;
      case 'rainfall':    return _S.rainfallLabel;
      case 'acurain':     return _S.accRainfallLabel;
      default:            return widget.layer.id.toUpperCase();
    }
  }

  @override Widget build(BuildContext context) {
    final fs = _rc(_rw(context, 10), 9, 13);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.popupWidth,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: EdgeInsets.fromLTRB(
                _rc(_rw(context, 12), 9, 16), _rc(_rh(context, 9), 7, 12),
                _rc(_rw(context,  8), 6, 12), _rc(_rh(context, 9), 7, 12)),
            decoration: const BoxDecoration(color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.location_on_rounded, size: _rc(_rw(context, 10), 8, 13),
                      color: const Color(0xFF1565C0)),
                  SizedBox(width: _rc(_rw(context, 3), 2, 5)),
                  Expanded(child: Text(_locationName,
                      style: GoogleFonts.dmSans(fontSize: fs, fontWeight: FontWeight.w600, color: Colors.black87),
                      overflow: TextOverflow.ellipsis, maxLines: 2)),
                ]),
                SizedBox(height: _rc(_rh(context, 4), 3, 6)),
                Row(children: [
                  TranslatedText('$_paramLabelKey: ',
                      style: GoogleFonts.dmSans(fontSize: fs, fontWeight: FontWeight.w700, color: Colors.black54)),
                  if (_isLoading)
                    SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: const Color(0xFF1565C0)))
                  else ...[
                    Text(_liveValue, style: GoogleFonts.dmSans(
                        fontSize: _rc(_rw(context, 11), 9, 14), fontWeight: FontWeight.w800,
                        color: _failed ? Colors.red[400] : const Color(0xFF1565C0))),
                    if (_failed) ...[
                      SizedBox(width: _rc(_rw(context, 5), 3, 8)),
                      GestureDetector(onTap: _fetchAll,
                          child: Icon(Icons.refresh_rounded,
                              size: _rc(_rw(context, 14), 11, 18),
                              color: const Color(0xFF1565C0))),
                    ],
                  ],
                ]),
              ])),
              GestureDetector(onTap: widget.onClose,
                  child: Padding(padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: _rc(_rw(context, 15), 12, 20), color: Colors.black45))),
            ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                _rc(_rw(context, 12), 9, 16), _rc(_rh(context, 8), 6, 12),
                _rc(_rw(context, 12), 9, 16), _rc(_rh(context,10), 7, 14)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _RadioOption(labelKey: AppStrings.meteogram,       value: 0, groupValue: _selectedOption,
                  onChanged: (v) => setState(() => _selectedOption = v!)),
              _RadioOption(labelKey: AppStrings.verticalProfile, value: 1, groupValue: _selectedOption,
                  onChanged: (v) => setState(() => _selectedOption = v!)),
              _RadioOption(labelKey: AppStrings.epsgram,         value: 2, groupValue: _selectedOption,
                  onChanged: (v) => setState(() => _selectedOption = v!)),
              SizedBox(height: _rc(_rh(context, 10), 7, 14)),
              SizedBox(
                width: double.infinity,
                height: _rc(_rh(context, 36), 30, 46),
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedOption == 0)      widget.onMeteogram();
                    else if (_selectedOption == 1) widget.onVerticalProfile();
                    else                           widget.onEPSgram();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    padding: EdgeInsets.zero,
                  ),
                  child: TranslatedText(AppStrings.viewDetails,
                      style: GoogleFonts.dmSans(
                          fontSize: _rc(_rw(context, 12), 10, 15),
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  final String labelKey; final int value, groupValue; final ValueChanged<int?> onChanged;
  const _RadioOption({required this.labelKey, required this.value, required this.groupValue, required this.onChanged});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(value), behavior: HitTestBehavior.opaque,
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Row(children: [
      Radio<int>(value: value, groupValue: groupValue, onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact, activeColor: const Color(0xFF1565C0)),
      SizedBox(width: _rc(_rw(context, 4), 3, 7)),
      TranslatedText(labelKey, style: GoogleFonts.dmSans(
          fontSize: _rc(_rw(context, 12), 10, 15), color: Colors.black87, fontWeight: FontWeight.w500)),
    ])),
  );
}

class _ZoomBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  final double       iconSize;
  final double       btnSize;
  const _ZoomBtn({required this.icon, required this.onTap, this.iconSize = 20, this.btnSize = 38});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(width: btnSize, height: btnSize * 0.95,
        child: Icon(icon, color: Colors.white, size: iconSize)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BASE SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _BaseSheet extends StatelessWidget {
  final String titleKey, subtitle; final List<Widget> chartWidgets; final Future<String>? locationFuture;
  const _BaseSheet({required this.titleKey, required this.subtitle, required this.chartWidgets, this.locationFuture});

  @override Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return DraggableScrollableSheet(
      initialChildSize: 0.82, minChildSize: 0.40, maxChildSize: 0.95, expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: EdgeInsets.fromLTRB(
                _rc(_rw(context, 16), 12, 24), _rc(_rh(context, 12), 10, 16),
                _rc(_rw(context,  8), 6,  12), _rc(_rh(context,  4),  3,  6)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TranslatedText(titleKey, style: GoogleFonts.dmSans(
                    fontSize: _rc(_rw(context, 18), 14, 24),
                    fontWeight: FontWeight.w800, color: Colors.black87)),
                SizedBox(height: _rc(_rh(context, 2), 1, 4)),
                if (locationFuture != null)
                  FutureBuilder<String>(future: locationFuture, builder: (_, snap) {
                    final loc = snap.data ?? '';
                    return Row(children: [
                      Icon(Icons.location_on_rounded,
                          size: _rc(_rw(context, 11), 9, 15), color: const Color(0xFF1565C0)),
                      SizedBox(width: _rc(_rw(context, 3), 2, 5)),
                      Expanded(child: Text(loc.isNotEmpty ? loc : subtitle,
                          style: GoogleFonts.dmSans(
                              fontSize: _rc(_rw(context, 11), 9, 14), color: Colors.black54),
                          overflow: TextOverflow.ellipsis)),
                    ]);
                  })
                else Text(subtitle, style: GoogleFonts.dmSans(
                    fontSize: _rc(_rw(context, 10), 8, 13), color: Colors.black45)),
              ])),
              IconButton(icon: Icon(Icons.close_rounded,
                  size: _rc(_rw(context, 20), 16, 26), color: Colors.black45),
                  onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: ListView.separated(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(
                _rc(_rw(context, 16), 10, 24), _rc(_rh(context, 14), 10, 20),
                _rc(_rw(context, 16), 10, 24), _rc(_rh(context, 32), 24, 48)),
            itemCount: chartWidgets.length,
            separatorBuilder: (_, __) => SizedBox(height: _rc(_rh(context, 10), 8, 16)),
            itemBuilder: (_, i) => chartWidgets[i],
          )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METEOGRAM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _MeteogramSheet extends StatefulWidget {
  final LatLng point;
  const _MeteogramSheet({required this.point});
  @override State<_MeteogramSheet> createState() => _MeteogramSheetState();
}

class _MeteogramSheetState extends State<_MeteogramSheet> {
  late Future<_MeteogramData> _future;
  @override void initState() { super.initState(); _future = _loadData(); }

  Future<_MeteogramData> _loadData() async {
    final results = await Future.wait([
      _NcmrwfApiService.fetchMeteogram(lat: widget.point.latitude, lon: widget.point.longitude),
      _NcmrwfApiService.reverseGeocode(lat: widget.point.latitude, lon: widget.point.longitude),
    ]);
    return _MeteogramData(entries: results[0] as List<MeteogramEntry>, locationName: results[1] as String);
  }

  @override Widget build(BuildContext context) {
    // Chart height scales with screen — taller on tablets
    final chartH1 = _rc(_rh(context, 180), 140, 260);
    final chartH2 = _rc(_rh(context, 200), 160, 280);

    return DraggableScrollableSheet(
      initialChildSize: 0.92, minChildSize: 0.50, maxChildSize: 0.97, expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: FutureBuilder<_MeteogramData>(future: _future, builder: (ctx, snap) {
          final locationName = snap.data?.locationName ?? '';
          return Column(children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  _rc(_rw(context, 16), 12, 24), _rc(_rh(context, 12), 10, 16),
                  _rc(_rw(context,  8),  6, 12), _rc(_rh(context,  4),  3,  6)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TranslatedText(AppStrings.meteogram, style: GoogleFonts.dmSans(
                      fontSize: _rc(_rw(context, 18), 14, 24),
                      fontWeight: FontWeight.w800, color: Colors.black87)),
                  SizedBox(height: _rc(_rh(context, 2), 1, 4)),
                  if (locationName.isNotEmpty) Row(children: [
                    Icon(Icons.location_on_rounded,
                        size: _rc(_rw(context, 11), 9, 15), color: const Color(0xFF1565C0)),
                    SizedBox(width: _rc(_rw(context, 3), 2, 5)),
                    Expanded(child: Text(locationName,
                        style: GoogleFonts.dmSans(
                            fontSize: _rc(_rw(context, 11), 9, 14), color: Colors.black54),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                ])),
                IconButton(icon: Icon(Icons.close_rounded,
                    size: _rc(_rw(context, 20), 16, 26), color: Colors.black45),
                    onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: () {
              if (snap.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snap.hasError || !snap.hasData || snap.data!.entries.isEmpty)
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.cloud_off_rounded, size: _rc(_rw(context, 48), 36, 64), color: Colors.grey[300]),
                  SizedBox(height: _rc(_rh(context, 12), 9, 18)),
                  TranslatedText(_S.noMeteogramData,
                      style: GoogleFonts.dmSans(color: Colors.grey[500],
                          fontSize: _rc(_rw(context, 13), 11, 17))),
                ]));
              final data = snap.data!.entries;
              return ListView(controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(0, _rc(_rh(context, 8), 6, 12), 0, _rc(_rh(context, 32), 24, 48)),
                  children: [
                    _MiniChartCard(
                      title: _S.tempChartTitle, titleIsKey: true,
                      icon: Icons.thermostat_rounded, accentColor: const Color(0xFFE53935),
                      child: SizedBox(height: chartH1, child: CustomPaint(
                          painter: _TemperatureChartPainter(data: data), child: Container())),
                    ),
                    SizedBox(height: _rc(_rh(context, 12), 9, 18)),
                    _MiniChartCard(
                      title: _S.humidChartTitle, titleIsKey: true,
                      icon: Icons.water_drop_rounded, accentColor: const Color(0xFF7986CB),
                      child: SizedBox(height: chartH1, child: CustomPaint(
                          painter: _HumidityChartPainter(data: data), child: Container())),
                    ),
                    SizedBox(height: _rc(_rh(context, 12), 9, 18)),
                    _MiniChartCard(
                      title: _S.rainWindChartTitle, titleIsKey: true,
                      icon: Icons.grain_rounded, accentColor: const Color(0xFF00BCD4),
                      child: SizedBox(height: chartH2, child: CustomPaint(
                          painter: _RainfallWindChartPainter(data: data), child: Container())),
                    ),
                  ]);
            }()),
          ]);
        }),
      ),
    );
  }
}

class _MeteogramData {
  final List<MeteogramEntry> entries; final String locationName;
  const _MeteogramData({required this.entries, required this.locationName});
}

// ─────────────────────────────────────────────────────────────────────────────
// MINI CHART CARD
// ─────────────────────────────────────────────────────────────────────────────
class _MiniChartCard extends StatelessWidget {
  final String   title;
  final bool     titleIsKey; // true → wrap with TranslatedText
  final IconData icon;
  final Color    accentColor;
  final Widget   child;
  const _MiniChartCard({
    required this.title, required this.icon,
    required this.accentColor, required this.child,
    this.titleIsKey = false,
  });

  @override Widget build(BuildContext context) {
    final iconBoxSz = _rc(_rw(context, 28), 22, 38);
    final iconSz    = _rc(_rw(context, 15), 12, 20);
    final titleFs   = _rc(_rw(context, 13), 11, 17);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: _rc(_rw(context, 12), 8, 18)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: accentColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              _rc(_rw(context, 14), 10, 20), _rc(_rh(context, 12), 9, 16),
              _rc(_rw(context, 14), 10, 20), _rc(_rh(context,  6), 4,  9)),
          child: Row(children: [
            Container(
              width: iconBoxSz, height: iconBoxSz,
              decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: accentColor, size: iconSz),
            ),
            SizedBox(width: _rc(_rw(context, 8), 6, 12)),
            Expanded(
              child: titleIsKey
                  ? TranslatedText(title, style: GoogleFonts.dmSans(
                  fontSize: titleFs, fontWeight: FontWeight.w700, color: const Color(0xFF1A2B45)))
                  : Text(title, style: GoogleFonts.dmSans(
                  fontSize: titleFs, fontWeight: FontWeight.w700, color: const Color(0xFF1A2B45))),
            ),
          ]),
        ),
        Container(height: 1, color: Colors.grey.shade100),
        Padding(padding: EdgeInsets.all(_rc(_rw(context, 8), 6, 12)), child: child),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHART PAINTERS  (unchanged logic, kept compact)
// ─────────────────────────────────────────────────────────────────────────────
class _TemperatureChartPainter extends CustomPainter {
  final List<MeteogramEntry> data;
  _TemperatureChartPainter({required this.data});
  @override void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const lPad = 42.0, rPad = 12.0, tPad = 10.0, bPad = 30.0;
    final cL = lPad, cR = size.width - rPad, cT = tPad, cB = size.height - bPad;
    final cW = cR - cL, cH = cB - cT, n = data.length;
    final vals = data.map((e) => e.airTemperature).toList();
    final minV = (vals.reduce(math.min) / 5).floor() * 5.0;
    final maxV = (vals.reduce(math.max) / 5).ceil()  * 5.0 + 5.0;
    final range = maxV - minV;
    double xOf(int i) => cL + (i / (n - 1)) * cW;
    double yOf(double v) => cB - ((v - minV) / range) * cH;
    final gridP = Paint()..color = Colors.grey.shade100..strokeWidth = 1;
    for (int g = 0; g <= 4; g++) canvas.drawLine(Offset(cL, yOf(minV + g * (range / 4))), Offset(cR, yOf(minV + g * (range / 4))), gridP);
    _drawDayLines(canvas, data, n, xOf, cT, cB, gridP);
    final path = ui.Path()..moveTo(xOf(0), cB);
    for (int i = 0; i < n; i++) path.lineTo(xOf(i), yOf(vals[i]));
    path..lineTo(xOf(n - 1), cB)..close();
    canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset(0, cT), Offset(0, cB),
        [const Color(0xFFE53935).withOpacity(0.30), const Color(0xFFE53935).withOpacity(0.02)])..style = PaintingStyle.fill);
    final lp = ui.Path();
    for (int i = 0; i < n; i++) { i == 0 ? lp.moveTo(xOf(i), yOf(vals[i])) : lp.lineTo(xOf(i), yOf(vals[i])); }
    canvas.drawPath(lp, Paint()..color = const Color(0xFFE53935)..strokeWidth = 2.0..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);
    _drawYAxis(canvas, minV, maxV, 4, yOf, cL, '°', const Color(0xFFE53935));
    _drawXTimeAxis(canvas, data, n, xOf, cB, size.width);
  }
  @override bool shouldRepaint(covariant _TemperatureChartPainter o) => o.data != data;
}

class _HumidityChartPainter extends CustomPainter {
  final List<MeteogramEntry> data;
  _HumidityChartPainter({required this.data});
  @override void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const lPad = 42.0, rPad = 12.0, tPad = 10.0, bPad = 30.0;
    final cL = lPad, cR = size.width - rPad, cT = tPad, cB = size.height - bPad;
    final cW = cR - cL, cH = cB - cT, n = data.length;
    final vals = data.map((e) => e.relativeHumidity).toList();
    double xOf(int i) => cL + (i / (n - 1)) * cW;
    double yOf(double v) => cB - (v / 100.0) * cH;
    final gridP = Paint()..color = Colors.grey.shade100..strokeWidth = 1;
    for (int g = 0; g <= 5; g++) canvas.drawLine(Offset(cL, cB - (g / 5) * cH), Offset(cR, cB - (g / 5) * cH), gridP);
    _drawDayLines(canvas, data, n, xOf, cT, cB, gridP);
    final path = ui.Path()..moveTo(xOf(0), cB);
    for (int i = 0; i < n; i++) path.lineTo(xOf(i), yOf(vals[i]));
    path..lineTo(xOf(n - 1), cB)..close();
    canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset(0, cT), Offset(0, cB),
        [const Color(0xFF7986CB).withOpacity(0.30), const Color(0xFF7986CB).withOpacity(0.02)])..style = PaintingStyle.fill);
    final lp = ui.Path();
    for (int i = 0; i < n; i++) { i == 0 ? lp.moveTo(xOf(i), yOf(vals[i])) : lp.lineTo(xOf(i), yOf(vals[i])); }
    canvas.drawPath(lp, Paint()..color = const Color(0xFF7986CB)..strokeWidth = 2.0..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);
    _drawYAxis(canvas, 0, 100, 5, (v) => cB - (v / 100.0) * cH, cL, '%', const Color(0xFF7986CB));
    _drawXTimeAxis(canvas, data, n, xOf, cB, size.width);
  }
  @override bool shouldRepaint(covariant _HumidityChartPainter o) => o.data != data;
}

class _RainfallWindChartPainter extends CustomPainter {
  final List<MeteogramEntry> data;
  _RainfallWindChartPainter({required this.data});
  @override void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const lPad = 42.0, rPad = 12.0, tPad = 10.0, bPad = 52.0;
    final cL = lPad, cR = size.width - rPad, cT = tPad, cB = size.height - bPad;
    final cW = cR - cL, cH = cB - cT, n = data.length;
    final rains  = data.map((e) => e.rainfall).toList();
    final maxRain = rains.reduce(math.max).clamp(0.5, double.infinity);
    double xOf(int i) => cL + (i / (n - 1)) * cW;
    double barH(double r) => (r / maxRain) * cH;
    final gridP = Paint()..color = Colors.grey.shade100..strokeWidth = 1;
    for (int g = 0; g <= 4; g++) canvas.drawLine(Offset(cL, cT + (1 - g / 4) * cH), Offset(cR, cT + (1 - g / 4) * cH), gridP);
    _drawDayLines(canvas, data, n, xOf, cT, cB, gridP);
    final barW = math.max(2.0, (cW / n) * 0.65);
    for (int i = 0; i < n; i++) {
      final h = barH(rains[i]);
      if (h < 0.5) continue;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(xOf(i) - barW / 2, cB - h, barW, h), const Radius.circular(2)),
          Paint()..color = const Color(0xFF00BCD4).withOpacity(0.80));
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int g = 0; g <= 4; g++) {
      final v = maxRain * g / 4; final y = cT + (1 - g / 4) * cH;
      tp.text = TextSpan(text: v.toStringAsFixed(g == 0 ? 0 : 1),
          style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 8, fontWeight: FontWeight.w600));
      tp.layout(); tp.paint(canvas, Offset(cL - tp.width - 3, y - tp.height / 2));
    }
    _drawXTimeAxis(canvas, data, n, xOf, cB, size.width);
    final arrowY = cB + 22.0;
    final arrowP = Paint()..color = const Color(0xFF546E7A)..strokeWidth = 1.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final step = (n / 28).ceil().clamp(1, 8);
    for (int i = 0; i < n; i += step) {
      final x = xOf(i); final dir = data[i].windFromDirection * math.pi / 180.0;
      const len = 7.0, headLen = 3.5;
      final ex = x + math.sin(dir) * len, ey = arrowY - math.cos(dir) * len;
      canvas.drawLine(Offset(x, arrowY), Offset(ex, ey), arrowP);
      canvas.drawLine(Offset(ex, ey), Offset(ex - math.sin(dir + 2.5) * headLen, ey + math.cos(dir + 2.5) * headLen), arrowP);
      canvas.drawLine(Offset(ex, ey), Offset(ex - math.sin(dir - 2.5) * headLen, ey + math.cos(dir - 2.5) * headLen), arrowP);
    }
    tp.text = const TextSpan(text: 'Wind ↑',
        style: TextStyle(color: Color(0xFF546E7A), fontSize: 8, fontWeight: FontWeight.w600));
    tp.layout(); tp.paint(canvas, Offset(cL - tp.width - 3, arrowY - tp.height / 2));
  }
  @override bool shouldRepaint(covariant _RainfallWindChartPainter o) => o.data != data;
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED CHART HELPERS
// ─────────────────────────────────────────────────────────────────────────────
void _drawDayLines(Canvas canvas, List<MeteogramEntry> data, int n,
    double Function(int) xOf, double cT, double cB, Paint gridP) {
  for (int i = 1; i < n; i++) {
    final parts = data[i].time.split('-');
    if (parts.length >= 4 && (int.tryParse(parts[3]) ?? 1) == 0) {
      canvas.drawLine(Offset(xOf(i), cT), Offset(xOf(i), cB),
          Paint()..color = Colors.grey.shade200..strokeWidth = 1);
    }
  }
}

void _drawYAxis(Canvas canvas, double minV, double maxV, int ticks,
    double Function(double) yOf, double cL, String suffix, Color color) {
  final tp = TextPainter(textDirection: TextDirection.ltr);
  for (int g = 0; g <= ticks; g++) {
    final v = minV + g * (maxV - minV) / ticks;
    tp.text = TextSpan(text: '${v.toInt()}$suffix',
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w600));
    tp.layout(); tp.paint(canvas, Offset(cL - tp.width - 3, yOf(v) - tp.height / 2));
  }
}

void _drawXTimeAxis(Canvas canvas, List<MeteogramEntry> data, int n,
    double Function(int) xOf, double cB, double totalWidth) {
  const dayNames = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  final tp = TextPainter(textDirection: TextDirection.ltr);
  String? lastDay;
  for (int i = 0; i < n; i++) {
    final parts = data[i].time.split('-');
    if (parts.length < 4) continue;
    final hour = int.tryParse(parts[3]) ?? 1;
    if (hour == 0 || i == 0) {
      final dt    = DateTime(int.tryParse(parts[0]) ?? 2026, int.tryParse(parts[1]) ?? 1, int.tryParse(parts[2]) ?? 1);
      final label = '${dayNames[(dt.weekday - 1) % 7]} ${dt.day}';
      if (label == lastDay) continue; lastDay = label;
      tp.text = TextSpan(text: label, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 8, fontWeight: FontWeight.w700));
      tp.layout();
      tp.paint(canvas, Offset(xOf(i).clamp(0.0, totalWidth - tp.width - 4) + 2, cB + 4));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEGEND HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _LegendItem extends StatelessWidget {
  final Color color; final String label; final bool isDash, isDot, isArrow;
  const _LegendItem({required this.color, required this.label, this.isDash = false, this.isDot = false, this.isArrow = false});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    SizedBox(width: 20, height: 14, child: CustomPaint(
        painter: _LegendSymbolPainter(color: color, isDash: isDash, isDot: isDot, isArrow: isArrow))),
    SizedBox(width: _rc(_rw(context, 4), 3, 7)),
    TranslatedText(label, style: GoogleFonts.dmSans(
        fontSize: _rc(_rw(context, 10), 8, 13), color: Colors.black54)),
  ]);
}

class _LegendSymbolPainter extends CustomPainter {
  final Color color; final bool isDash, isDot, isArrow;
  const _LegendSymbolPainter({required this.color, required this.isDash, required this.isDot, required this.isArrow});
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;
    final cy = size.height / 2;
    if (isDash) { canvas.drawLine(Offset(0, cy), Offset(size.width, cy), p); }
    else if (isDot) { canvas.drawCircle(Offset(size.width / 2, cy), 4, p..style = PaintingStyle.fill); }
    else if (isArrow) {
      canvas.drawLine(Offset(size.width / 2, size.height - 2), Offset(size.width / 2, 2), p);
      canvas.drawLine(Offset(size.width / 2, 2), Offset(size.width / 2 - 3, 6), p);
      canvas.drawLine(Offset(size.width / 2, 2), Offset(size.width / 2 + 3, 6), p);
    }
  }
  @override bool shouldRepaint(covariant _LegendSymbolPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// VERTICAL PROFILE SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _VerticalProfileSheet extends StatefulWidget {
  final LatLng point;
  const _VerticalProfileSheet({required this.point});
  @override State<_VerticalProfileSheet> createState() => _VerticalProfileSheetState();
}
class _VerticalProfileSheetState extends State<_VerticalProfileSheet> {
  late Future<String> _locationFuture;
  @override void initState() {
    super.initState();
    _locationFuture = _NcmrwfApiService.reverseGeocode(lat: widget.point.latitude, lon: widget.point.longitude);
  }
  @override Widget build(BuildContext context) => _BaseSheet(
    titleKey: AppStrings.verticalProfile, subtitle: _S.skewTSubtitle,
    locationFuture: _locationFuture,
    chartWidgets: [
      _ApiImageWidget(
        imageUrl: _NcmrwfApiService.verticalProfileUrl(lat: widget.point.latitude, lon: widget.point.longitude),
        fallbackTitle: _S.skewTSubtitle, fallbackTitleIsKey: true,
        fallbackIcon: Icons.ssid_chart_rounded, fallbackColor: const Color(0xFFE8F5E9),
        height: _rc(_rh(context, 380), 280, 520),
      ),
      Wrap(spacing: _rc(_rw(context, 16), 12, 22), children: [
        _LegendDot(color: const Color(0xFFB71C1C), label: _S.temperature, labelIsKey: true),
        _LegendDot(color: const Color(0xFF1B5E20), label: _S.dewpoint,    labelIsKey: true),
      ]),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EPS GRAM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _EPSgramSheet extends StatefulWidget {
  final LatLng point;
  const _EPSgramSheet({required this.point});
  @override State<_EPSgramSheet> createState() => _EPSgramSheetState();
}
class _EPSgramSheetState extends State<_EPSgramSheet> {
  late Future<String> _locationFuture;
  @override void initState() {
    super.initState();
    _locationFuture = _NcmrwfApiService.reverseGeocode(lat: widget.point.latitude, lon: widget.point.longitude);
  }
  @override Widget build(BuildContext context) => _BaseSheet(
    titleKey: AppStrings.epsgram, subtitle: _S.epsSubtitle,
    locationFuture: _locationFuture,
    chartWidgets: [
      _ApiImageWidget(
        imageUrl: _NcmrwfApiService.epsgramUrl(lat: widget.point.latitude, lon: widget.point.longitude),
        fallbackTitle: _S.epsFallback, fallbackTitleIsKey: true,
        fallbackIcon: Icons.bar_chart_rounded, fallbackColor: const Color(0xFFFFF3E0),
        height: _rc(_rh(context, 480), 360, 640),
      ),
      Wrap(spacing: _rc(_rw(context, 16), 12, 22), children: [
        _LegendDot(color: const Color(0xFF1565C0), label: _S.controlRun,       labelIsKey: true),
        _LegendDot(color: const Color(0xFF78909C), label: _S.ensembleMembers,  labelIsKey: true),
      ]),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// API IMAGE WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _ApiImageWidget extends StatelessWidget {
  final String   imageUrl, fallbackTitle;
  final bool     fallbackTitleIsKey;
  final IconData fallbackIcon;
  final Color    fallbackColor;
  final double   height;

  const _ApiImageWidget({
    required this.imageUrl, required this.fallbackTitle,
    required this.fallbackIcon, required this.fallbackColor,
    this.height = 300, this.fallbackTitleIsKey = false,
  });

  @override Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: double.infinity, height: height,
      decoration: BoxDecoration(
          color: fallbackColor,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10)),
      child: Image.network(imageUrl, fit: BoxFit.contain,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          final pct = progress.expectedTotalBytes != null
              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
              : null;
          return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(value: pct, color: const Color(0xFF1565C0), strokeWidth: 2),
            SizedBox(height: _rc(_rh(context, 12), 9, 18)),
            TranslatedText(_S.loadingChart, style: GoogleFonts.dmSans(
                fontSize: _rc(_rw(context, 12), 10, 15), color: Colors.grey[500])),
          ]);
        },
        errorBuilder: (ctx, error, st) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(fallbackIcon, size: _rc(_rw(context, 48), 36, 64), color: Colors.grey[300]),
          SizedBox(height: _rc(_rh(context, 10), 7, 14)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _rc(_rw(context, 16), 12, 24)),
            child: fallbackTitleIsKey
                ? TranslatedText(fallbackTitle, textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: _rc(_rw(context, 13), 11, 17),
                    color: Colors.grey[600], fontWeight: FontWeight.w600))
                : Text(fallbackTitle, textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: _rc(_rw(context, 13), 11, 17),
                    color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ),
          SizedBox(height: _rc(_rh(context, 6), 4, 9)),
          TranslatedText(_S.connectApi, style: GoogleFonts.dmSans(
              fontSize: _rc(_rw(context, 10), 8, 13), color: Colors.grey[400])),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LEGEND DOT
// ─────────────────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  final bool   labelIsKey;
  const _LegendDot({required this.color, required this.label, this.labelIsKey = false});

  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width:  _rc(_rw(context, 10), 8, 14),
      height: _rc(_rw(context, 10), 8, 14),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
    SizedBox(width: _rc(_rw(context, 4), 3, 7)),
    labelIsKey
        ? TranslatedText(label, style: GoogleFonts.dmSans(
        fontSize: _rc(_rw(context, 11), 9, 14), color: Colors.black54))
        : Text(label, style: GoogleFonts.dmSans(
        fontSize: _rc(_rw(context, 11), 9, 14), color: Colors.black54)),
  ]);
}

// Backward compat stubs
class _CombinedMeteogramChart extends StatelessWidget {
  final List<MeteogramEntry> data;
  const _CombinedMeteogramChart({required this.data});
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
class _CombinedMeteogramPainter extends CustomPainter {
  final List<MeteogramEntry> data;
  _CombinedMeteogramPainter({required this.data});
  @override void paint(Canvas canvas, Size size) {}
  @override bool shouldRepaint(covariant _CombinedMeteogramPainter o) => false;
}