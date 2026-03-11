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
// CONSTANTS & DATE HELPERS  (all unchanged)
// ─────────────────────────────────────────────────────────────────────────────
const String _ncmrwfApiBase = 'https://api.ncmrwf.gov.in';
const String _appId         = '921155810533297639420383389872';
const String _wmsPressure   = '850';

String get _wmsDateStr {
  final d = DateTime.now().toUtc();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
String get _apiDateTimeStr {
  final d   = DateTime.now().toUtc();
  final ymd = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return '$ymd-hr-00-00-00';
}
String get _odateToday => _wmsDateStr;
String get _odateYesterday {
  final d = DateTime.now().toUtc().subtract(const Duration(days: 1));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// FORECAST STEP  — one 6-hourly time slot
// ─────────────────────────────────────────────────────────────────────────────
class _ForecastStep {
  final DateTime dt;
  final String   dateStr;      // "YYYY-MM-DD"
  final String   dateTimeStr;  // "YYYY-MM-DD-hr-HH-00-00"
  const _ForecastStep({required this.dt, required this.dateStr, required this.dateTimeStr});
}

List<_ForecastStep> _buildForecastSteps() {
  final base  = DateTime.now().toUtc();
  final start = DateTime.utc(base.year, base.month, base.day);
  final steps = <_ForecastStep>[];
  for (int h = 0; h <= 10 * 24; h += 6) {
    final dt    = start.add(Duration(hours: h));
    final dStr  = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final dtStr = '$dStr-hr-${dt.hour.toString().padLeft(2, '0')}-00-00';
    steps.add(_ForecastStep(dt: dt, dateStr: dStr, dateTimeStr: dtStr));
  }
  return steps;
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP-LEVEL PARSE  (compute)
// ─────────────────────────────────────────────────────────────────────────────
List<MeteogramEntry> _parseMeteogramIsolate(String body) {
  try {
    final json   = jsonDecode(body) as Map<String, dynamic>;
    final output = json['output'] as List<dynamic>;
    return output.map((e) => MeteogramEntry.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) { debugPrint('[isolate] meteogram parse error: $e'); return []; }
}

// ─────────────────────────────────────────────────────────────────────────────
// NCMRWF API SERVICE  (unchanged logic)
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
    final params = {'appid': _appId, 'coords': '$lat,$lon', 'date': _apiDateTimeStr, 'odate': _odateYesterday};
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
// MODELS  (unchanged)
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
// WEATHER LAYER MODEL  (unchanged)
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
// INDIA SHAPEFILE OVERLAY  (unchanged logic)
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
  // ── unchanged state ──────────────────────────────────────────────────────
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

  // ── NEW: forecast slider state ────────────────────────────────────────────
  late List<_ForecastStep> _steps;
  int  _sliderIndex = 0;
  bool _isPlaying   = false;

  // Play timer — checked every tick
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
  void _openMeteogram(LatLng pt)       { _closePopup(); showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _MeteogramSheet(point: pt)); }
  void _openVerticalProfile(LatLng pt) { _closePopup(); showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _VerticalProfileSheet(point: pt)); }
  void _openEPSgram(LatLng pt)         { _closePopup(); showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _EPSgramSheet(point: pt)); }

  // WMS params driven by the current slider step
  // Add this helper anywhere at file level (near the other date helpers at the top)
  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';


// Replace your existing _wmsParams inside _MapScreenState:
  Map<String, String> _wmsParams({String? pressure}) {
    final step = _steps[_sliderIndex];

    // For 00UTC steps the model init date (odate) is the previous day
    final odateFixed = step.dt.hour == 0
        ? _formatDate(step.dt.subtract(const Duration(days: 1)))
        : step.dateStr;

    return {
      'service': 'WMS',
      'request': 'GetMap',
      'appid': _appId,
      'styles': '',
      'date': step.dateTimeStr,
      'odate': odateFixed,          // ← was always step.dateStr (wrong at 00UTC)
      if (pressure != null) 'pressure': pressure,
      'srs': 'EPSG:3857',
    };
    // NOTE: dataVal / data=NaN removed entirely — it's a point-API param, not WMS
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsProvider>();
    return Consumer<WeatherProvider>(builder: (ctx, wp, _) {
      final layer     = _layers[_selectedLayer];
      final centerLat = wp.latitude  != 0.0 ? wp.latitude  : 20.5937;
      final centerLon = wp.longitude != 0.0 ? wp.longitude : 78.9629;

      return Scaffold(
        backgroundColor: Colors.black,
        // extendBodyBehindAppBar keeps status bar area transparent
        extendBodyBehindAppBar: true,
        body: Stack(children: [

          // ── FULL-SCREEN MAP ───────────────────────────────────────────────
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

                // Temperature
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

                // Humidity
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

                // Rainfall  (no pressure, no data)
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

                // Accumulated Rainfall  (no pressure, no data)
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
                      width: 140, height: 72,
                      child: _LocationMarker(wp: wp, layer: _layers[_selectedLayer]),
                    ),
                  ]),
              ],
            ),
          ),

          // ── TOP BAR  (glass floating) ─────────────────────────────────────
          Positioned(top: 0, left: 0, right: 0,
            child: SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(children: [
                // Title pill
                Expanded(child: _GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0D47A1).withOpacity(0.85)),
                      child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('Weather Guidance Portal',
                          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                      if (wp.placeName.isNotEmpty)
                        Text(wp.placeName,
                            style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                    ])),
                  ]),
                )),
                const SizedBox(width: 6),

                // Legend toggle
                _GlassIconBtn(icon: _showLegend ? Icons.layers_rounded : Icons.layers_outlined,
                    active: _showLegend, onTap: () => setState(() => _showLegend = !_showLegend)),
                const SizedBox(width: 6),

                // Boundary toggle
                _GlassIconBtn(icon: _showShapeOverlay ? Icons.crop_free_rounded : Icons.border_clear_rounded,
                    active: _showShapeOverlay, onTap: () => setState(() => _showShapeOverlay = !_showShapeOverlay)),

                // My location
                if (wp.latitude != 0.0) ...[
                  const SizedBox(width: 6),
                  _GlassIconBtn(icon: Icons.my_location_rounded,
                      onTap: () => _mapController.move(LatLng(wp.latitude, wp.longitude), 6)),
                ],
              ]),
            )),
          ),

          // ── LAYER CHIPS  (below top bar) ──────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 0, right: 0,
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _layers.length,
                itemBuilder: (ctx, i) {
                  final sel = i == _selectedLayer;
                  final l   = _layers[i];
                  return GestureDetector(
                    onTap: () => _switchLayer(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                        boxShadow: sel ? [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.40), blurRadius: 10, spreadRadius: 1)] : null,
                      ),
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(l.icon, color: sel ? Colors.white : Colors.white70, size: 13),
                            const SizedBox(width: 6),
                            TranslatedText(l.labelKey, style: GoogleFonts.dmSans(
                                color: sel ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── ZOOM CONTROLS  (left, above slider) ───────────────────────────
          Positioned(
            left: 10,
            bottom: _ForecastSliderPanel.panelHeight + 14,
            child: _buildZoomControls(),
          ),

          // ── LEGEND  (above slider) ─────────────────────────────────────────
          if (_showLegend)
            Positioned(
              left: 58, right: 10,
              bottom: _ForecastSliderPanel.panelHeight + 12,
              child: _GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Icon(layer.icon, color: Colors.white60, size: 11),
                    const SizedBox(width: 5),
                    FutureBuilder<String>(
                      future: TranslatorService.translate(layer.labelKey),
                      initialData: layer.labelKey,
                      builder: (_, s) => Text('${s.data}  (${layer.unit})',
                          style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(borderRadius: BorderRadius.circular(3),
                      child: SizedBox(height: 9, child: Row(
                          children: layer.legendColors.map((c) => Expanded(child: ColoredBox(color: c))).toList()))),
                  const SizedBox(height: 3),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: layer.legendLabels.map((l) => Text(l,
                          style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 8))).toList()),
                ]),
              ),
            ),

          // ── TAP POPUP ──────────────────────────────────────────────────────
          if (_showPopup && _tappedLatLng != null && _tappedScreen != null)
            _buildFloatingPopup(layer, wp),

          // ── FORECAST TIMELINE SLIDER  (bottom) ────────────────────────────
          Positioned(bottom: 0, left: 0, right: 0,
            child: _ForecastSliderPanel(
              steps        : _steps,
              selectedIndex: _sliderIndex,
              isPlaying    : _isPlaying,
              layer        : layer,
              onChanged    : (i) => setState(() { _sliderIndex = i; _showPopup = false; }),
              onPlayPause: () {
                setState(() => _isPlaying = !_isPlaying);
                if (_isPlaying) {
                  _playTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
                    if (!mounted) { _playTimer?.cancel(); return; }
                    setState(() {
                      _sliderIndex = (_sliderIndex + 1) % _steps.length;
                      // Auto-stop when it loops back to start
                      if (_sliderIndex == 0) {
                        _isPlaying = false;
                        _playTimer?.cancel();
                      }
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

  Widget _buildZoomControls() => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _ZoomBtn(icon: Icons.add_rounded,    onTap: () => _mapController.move(_mapController.camera.center, (_mapController.camera.zoom + 1).clamp(2.0, 12.0))),
          Container(height: 1, width: 32, color: Colors.white12),
          _ZoomBtn(icon: Icons.remove_rounded, onTap: () => _mapController.move(_mapController.camera.center, (_mapController.camera.zoom - 1).clamp(2.0, 12.0))),
        ]),
      ),
    ),
  );

  Widget _buildFloatingPopup(_WeatherLayer layer, WeatherProvider wp) {
    const popupW = 215.0, popupH = 210.0, pinGap = 10.0;
    final RenderBox? box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    final mapW = box?.size.width  ?? 400.0;
    final mapH = box?.size.height ?? 600.0;
    final left = (_tappedScreen!.dx - popupW / 2).clamp(6.0, mapW - popupW - 6.0);
    final top  = (_tappedScreen!.dy - popupH - pinGap).clamp(6.0, mapH - popupH - 6.0);
    return Positioned(left: left, top: top,
      child: _TapPopup(
        layer: layer, point: _tappedLatLng!, wp: wp,
        onClose: _closePopup,
        onMeteogram: () => _openMeteogram(_tappedLatLng!),
        onVerticalProfile: () => _openVerticalProfile(_tappedLatLng!),
        onEPSgram: () => _openEPSgram(_tappedLatLng!),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORECAST SLIDER PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _ForecastSliderPanel extends StatefulWidget {
  // The fixed visual height of the panel (excluding safe-area padding)
  static const double panelHeight = 128.0;

  final List<_ForecastStep> steps;
  final int                 selectedIndex;
  final bool                isPlaying;
  final _WeatherLayer       layer;
  final ValueChanged<int>   onChanged;
  final VoidCallback        onPlayPause;

  const _ForecastSliderPanel({
    required this.steps, required this.selectedIndex, required this.isPlaying,
    required this.layer,  required this.onChanged,    required this.onPlayPause,
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
    const dotW = 22.0;
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
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // ── Light blue sky theme colours ──────────────────────────────────────
    const Color panelBg      = Color(0xFFE3F2FD);  // light blue 50
    const Color panelBorder  = Color(0xFF90CAF9);  // blue 200
    const Color dotActive    = Color(0xFF1565C0);  // blue 800  (selected dot)
    const Color dotDay       = Color(0xFF1E88E5);  // blue 600
    const Color dotOther     = Color(0xFFBBDEFB);  // blue 100
    const Color progressFill = Color(0xFF1565C0);
    const Color textPrimary  = Color(0xFF0D2B5E);
    const Color textSub      = Color(0xFF5B8CB7);
    const Color badgeBg      = Color(0xFFBBDEFB);
    const Color badgeBorder  = Color(0xFF64B5F6);

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        border: const Border(top: BorderSide(color: panelBorder, width: 1.5)),
        boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.12), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      height: _ForecastSliderPanel.panelHeight + safeBottom,
      child: Column(children: [

        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
          child: Row(children: [

            // Play/Pause — glowing teal-blue button
            GestureDetector(
              onTap: widget.onPlayPause,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42, height: 42,
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
                child: Icon(widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 12),

            // Date & time
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(_dateLabel, style: GoogleFonts.dmSans(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              Text(_timeLabel, style: GoogleFonts.dmSans(color: textSub,    fontSize: 11, fontWeight: FontWeight.w500)),
            ]),

            const Spacer(),

            // Layer badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: badgeBorder, width: 1.2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.layer.icon, color: dotActive, size: 12),
                const SizedBox(width: 5),
                TranslatedText(widget.layer.labelKey,
                    style: GoogleFonts.dmSans(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),

        // ── Progress bar ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
          child: LayoutBuilder(builder: (_, c) {
            final frac = widget.steps.isEmpty ? 0.0 : widget.selectedIndex / (widget.steps.length - 1);
            return ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(children: [
                Container(height: 4, color: dotOther),
                FractionallySizedBox(widthFactor: frac,
                    child: Container(height: 4,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1565C0)]),
                          borderRadius: BorderRadius.circular(3),
                        ))),
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
            padding        : const EdgeInsets.symmetric(horizontal: 14),
            itemCount      : widget.steps.length,
            itemBuilder    : (ctx, i) {
              final s     = widget.steps[i];
              final isSel = i == widget.selectedIndex;
              final isDay = s.dt.hour == 0;
              final isMid = s.dt.hour == 12;

              return GestureDetector(
                onTap: () => widget.onChanged(i),
                child: SizedBox(
                  width: 24,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

                    // Day / 12h label above
                    SizedBox(height: 16, child: isDay
                        ? Text(_days[(s.dt.weekday - 1) % 7],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(color: textPrimary, fontSize: 9, fontWeight: FontWeight.w800))
                        : isMid
                        ? Text('12', textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(color: textSub, fontSize: 8))
                        : const SizedBox.shrink()),

                    // Dot
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width : isSel ? 14 : (isDay ? 8 : 5),
                      height: isSel ? 14 : (isDay ? 8 : 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSel ? dotActive : (isDay ? dotDay : dotOther),
                        border: isSel ? Border.all(color: Colors.white, width: 2) : null,
                        boxShadow: isSel
                            ? [BoxShadow(color: dotActive.withOpacity(0.50), blurRadius: 10, spreadRadius: 2)]
                            : null,
                      ),
                    ),

                    // Hour label below selected
                    const SizedBox(height: 3),
                    SizedBox(height: 13, child: isSel
                        ? Text('${s.dt.hour.toString().padLeft(2, '0')}h',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(color: dotActive, fontSize: 9, fontWeight: FontWeight.w800))
                        : const SizedBox.shrink()),
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
  final IconData icon; final VoidCallback onTap; final bool active;
  const _GlassIconBtn({required this.icon, required this.onTap, this.active = false});

  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0D47A1).withOpacity(0.85) : Colors.black.withOpacity(0.48),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withOpacity(active ? 0.28 : 0.14)),
          ),
          child: Icon(icon, color: active ? Colors.white : Colors.white70, size: 17),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCATION MARKER  (unchanged logic)
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.60),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_icon, color: Colors.white70, size: 11),
            const SizedBox(width: 4),
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(wp.placeName.split(',').first,
                  style: GoogleFonts.dmSans(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
              Text(_value, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
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
// TAP POPUP  (unchanged logic)
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

  String get _paramLabel {
    switch (widget.layer.id) {
      case 'temperature': return 'TEMPERATURE';
      case 'humidity':    return 'HUMIDITY';
      case 'rainfall':    return 'RAINFALL';
      case 'acurain':     return 'ACC. RAINFALL';
      default:            return widget.layer.id.toUpperCase();
    }
  }

  @override Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      width: widget.popupWidth,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          decoration: const BoxDecoration(color: Color(0xFFF5F5F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.location_on_rounded, size: 10, color: Color(0xFF1565C0)),
                const SizedBox(width: 3),
                Expanded(child: Text(_locationName,
                    style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87),
                    overflow: TextOverflow.ellipsis, maxLines: 2)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Text('$_paramLabel: ', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black54)),
                if (_isLoading)
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF1565C0)))
                else ...[
                  Text(_liveValue, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800,
                      color: _failed ? Colors.red[400] : const Color(0xFF1565C0))),
                  if (_failed) ...[
                    const SizedBox(width: 5),
                    GestureDetector(onTap: _fetchAll, child: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF1565C0))),
                  ],
                ],
              ]),
            ])),
            GestureDetector(onTap: widget.onClose,
                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 15, color: Colors.black45))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _RadioOption(labelKey: AppStrings.meteogram,       value: 0, groupValue: _selectedOption, onChanged: (v) => setState(() => _selectedOption = v!)),
            _RadioOption(labelKey: AppStrings.verticalProfile, value: 1, groupValue: _selectedOption, onChanged: (v) => setState(() => _selectedOption = v!)),
            _RadioOption(labelKey: AppStrings.epsgram,         value: 2, groupValue: _selectedOption, onChanged: (v) => setState(() => _selectedOption = v!)),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 36,
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
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ]),
    ),
  );
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
      const SizedBox(width: 4),
      TranslatedText(labelKey, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500)),
    ])),
  );
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(width: 38, height: 36, child: Icon(icon, color: Colors.white, size: 20)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BASE SHEET  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _BaseSheet extends StatelessWidget {
  final String titleKey, subtitle; final List<Widget> chartWidgets; final Future<String>? locationFuture;
  const _BaseSheet({required this.titleKey, required this.subtitle, required this.chartWidgets, this.locationFuture});

  @override Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.82, minChildSize: 0.40, maxChildSize: 0.95, expand: false,
    builder: (ctx, scrollCtrl) => Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 8, 4), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TranslatedText(titleKey, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
            const SizedBox(height: 2),
            if (locationFuture != null)
              FutureBuilder<String>(future: locationFuture, builder: (_, snap) {
                final loc = snap.data ?? '';
                return Row(children: [
                  const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF1565C0)),
                  const SizedBox(width: 3),
                  Expanded(child: Text(loc.isNotEmpty ? loc : subtitle,
                      style: GoogleFonts.dmSans(fontSize: 11, color: Colors.black54), overflow: TextOverflow.ellipsis)),
                ]);
              })
            else Text(subtitle, style: GoogleFonts.dmSans(fontSize: 10, color: Colors.black45)),
          ])),
          IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: Colors.black45), onPressed: () => Navigator.pop(ctx)),
        ])),
        const Divider(height: 1),
        Expanded(child: ListView.separated(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          itemCount: chartWidgets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => chartWidgets[i],
        )),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// METEOGRAM SHEET  (unchanged)
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

  @override Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.92, minChildSize: 0.50, maxChildSize: 0.97, expand: false,
    builder: (ctx, scrollCtrl) => Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: FutureBuilder<_MeteogramData>(future: _future, builder: (ctx, snap) {
        final locationName = snap.data?.locationName ?? '';
        return Column(children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 8, 4), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TranslatedText(AppStrings.meteogram,
                  style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
              const SizedBox(height: 2),
              if (locationName.isNotEmpty) Row(children: [
                const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF1565C0)),
                const SizedBox(width: 3),
                Expanded(child: Text(locationName,
                    style: GoogleFonts.dmSans(fontSize: 11, color: Colors.black54), overflow: TextOverflow.ellipsis)),
              ]),
            ])),
            IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: Colors.black45), onPressed: () => Navigator.pop(ctx)),
          ])),
          const Divider(height: 1),
          Expanded(child: () {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError || !snap.hasData || snap.data!.entries.isEmpty)
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No meteogram data available', style: GoogleFonts.dmSans(color: Colors.grey[500], fontSize: 13)),
              ]));
            final data = snap.data!.entries;
            return ListView(controller: scrollCtrl, padding: const EdgeInsets.fromLTRB(0, 8, 0, 32), children: [
              // ── Chart 1: Temperature ──────────────────────────────────
              _MiniChartCard(
                title: 'Temperature (°C)',
                icon: Icons.thermostat_rounded,
                accentColor: const Color(0xFFE53935),
                child: SizedBox(height: 180, child: CustomPaint(
                    painter: _TemperatureChartPainter(data: data), child: Container())),
              ),
              const SizedBox(height: 12),
              // ── Chart 2: Relative Humidity ────────────────────────────
              _MiniChartCard(
                title: 'Relative Humidity (%)',
                icon: Icons.water_drop_rounded,
                accentColor: const Color(0xFF7986CB),
                child: SizedBox(height: 180, child: CustomPaint(
                    painter: _HumidityChartPainter(data: data), child: Container())),
              ),
              const SizedBox(height: 12),
              // ── Chart 3: Rainfall + Wind ──────────────────────────────
              _MiniChartCard(
                title: 'Rainfall (mm/hr) & Wind',
                icon: Icons.grain_rounded,
                accentColor: const Color(0xFF00BCD4),
                child: SizedBox(height: 200, child: CustomPaint(
                    painter: _RainfallWindChartPainter(data: data), child: Container())),
              ),
            ]);
          }()),
        ]);
      }),
    ),
  );
}

class _MeteogramData {
  final List<MeteogramEntry> entries; final String locationName;
  const _MeteogramData({required this.entries, required this.locationName});
}

// ─────────────────────────────────────────────────────────────────────────────
// MINI CHART CARD  — wrapper used by all 3 meteogram charts
// ─────────────────────────────────────────────────────────────────────────────
class _MiniChartCard extends StatelessWidget {
  final String    title;
  final IconData  icon;
  final Color     accentColor;
  final Widget    child;
  const _MiniChartCard({required this.title, required this.icon, required this.accentColor, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [BoxShadow(color: accentColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 15),
          ),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.dmSans(
              fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A2B45))),
        ]),
      ),
      Container(height: 1, color: Colors.grey.shade100),
      Padding(padding: const EdgeInsets.all(8), child: child),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CHART 1: TEMPERATURE
// ─────────────────────────────────────────────────────────────────────────────
class _TemperatureChartPainter extends CustomPainter {
  final List<MeteogramEntry> data;
  _TemperatureChartPainter({required this.data});

  @override void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const lPad = 42.0, rPad = 12.0, tPad = 10.0, bPad = 30.0;
    final cL = lPad, cR = size.width - rPad, cT = tPad, cB = size.height - bPad;
    final cW = cR - cL, cH = cB - cT;
    final n = data.length;
    final vals = data.map((e) => e.airTemperature).toList();
    final minV = (vals.reduce(math.min) / 5).floor() * 5.0;
    final maxV = (vals.reduce(math.max) / 5).ceil()  * 5.0 + 5.0;
    final range = maxV - minV;

    double xOf(int i) => cL + (i / (n - 1)) * cW;
    double yOf(double v) => cB - ((v - minV) / range) * cH;

    // Grid
    final gridP = Paint()..color = Colors.grey.shade100..strokeWidth = 1;
    for (int g = 0; g <= 4; g++) {
      final y = yOf(minV + g * (range / 4));
      canvas.drawLine(Offset(cL, y), Offset(cR, y), gridP);
    }
    _drawDayLines(canvas, data, n, xOf, cT, cB, gridP);

    // Gradient fill
    final path = ui.Path()..moveTo(xOf(0), cB);
    for (int i = 0; i < n; i++) path.lineTo(xOf(i), yOf(vals[i]));
    path..lineTo(xOf(n - 1), cB)..close();
    canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(
      Offset(0, cT), Offset(0, cB),
      [const Color(0xFFE53935).withOpacity(0.30), const Color(0xFFE53935).withOpacity(0.02)],
    )..style = PaintingStyle.fill);

    // Line
    final linePath = ui.Path();
    for (int i = 0; i < n; i++) { i == 0 ? linePath.moveTo(xOf(i), yOf(vals[i])) : linePath.lineTo(xOf(i), yOf(vals[i])); }
    canvas.drawPath(linePath, Paint()..color = const Color(0xFFE53935)..strokeWidth = 2.0..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);

    // Axes
    _drawYAxis(canvas, minV, maxV, 4, yOf, cL, '°', const Color(0xFFE53935));
    _drawXTimeAxis(canvas, data, n, xOf, cB, size.width);
  }

  @override bool shouldRepaint(covariant _TemperatureChartPainter o) => o.data != data;
}

// ─────────────────────────────────────────────────────────────────────────────
// CHART 2: RELATIVE HUMIDITY
// ─────────────────────────────────────────────────────────────────────────────
class _HumidityChartPainter extends CustomPainter {
  final List<MeteogramEntry> data;
  _HumidityChartPainter({required this.data});

  @override void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const lPad = 42.0, rPad = 12.0, tPad = 10.0, bPad = 30.0;
    final cL = lPad, cR = size.width - rPad, cT = tPad, cB = size.height - bPad;
    final cW = cR - cL, cH = cB - cT;
    final n = data.length;
    final vals = data.map((e) => e.relativeHumidity).toList();

    double xOf(int i) => cL + (i / (n - 1)) * cW;
    double yOf(double v) => cB - (v / 100.0) * cH;

    // Grid
    final gridP = Paint()..color = Colors.grey.shade100..strokeWidth = 1;
    for (int g = 0; g <= 5; g++) {
      final y = cB - (g / 5) * cH;
      canvas.drawLine(Offset(cL, y), Offset(cR, y), gridP);
    }
    _drawDayLines(canvas, data, n, xOf, cT, cB, gridP);

    // Gradient fill
    final path = ui.Path()..moveTo(xOf(0), cB);
    for (int i = 0; i < n; i++) path.lineTo(xOf(i), yOf(vals[i]));
    path..lineTo(xOf(n - 1), cB)..close();
    canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(
      Offset(0, cT), Offset(0, cB),
      [const Color(0xFF7986CB).withOpacity(0.30), const Color(0xFF7986CB).withOpacity(0.02)],
    )..style = PaintingStyle.fill);

    // Line
    final linePath = ui.Path();
    for (int i = 0; i < n; i++) { i == 0 ? linePath.moveTo(xOf(i), yOf(vals[i])) : linePath.lineTo(xOf(i), yOf(vals[i])); }
    canvas.drawPath(linePath, Paint()..color = const Color(0xFF7986CB)..strokeWidth = 2.0..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);

    // Axes
    _drawYAxis(canvas, 0, 100, 5, (v) => cB - (v / 100.0) * cH, cL, '%', const Color(0xFF7986CB));
    _drawXTimeAxis(canvas, data, n, xOf, cB, size.width);
  }

  @override bool shouldRepaint(covariant _HumidityChartPainter o) => o.data != data;
}

// ─────────────────────────────────────────────────────────────────────────────
// CHART 3: RAINFALL + WIND ARROWS
// ─────────────────────────────────────────────────────────────────────────────
class _RainfallWindChartPainter extends CustomPainter {
  final List<MeteogramEntry> data;
  _RainfallWindChartPainter({required this.data});

  @override void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const lPad = 42.0, rPad = 12.0, tPad = 10.0, bPad = 52.0;
    final cL = lPad, cR = size.width - rPad, cT = tPad, cB = size.height - bPad;
    final cW = cR - cL, cH = cB - cT;
    final n = data.length;
    final rains = data.map((e) => e.rainfall).toList();
    final maxRain = rains.reduce(math.max).clamp(0.5, double.infinity);

    double xOf(int i) => cL + (i / (n - 1)) * cW;
    double barH(double r) => (r / maxRain) * cH;

    // Grid
    final gridP = Paint()..color = Colors.grey.shade100..strokeWidth = 1;
    for (int g = 0; g <= 4; g++) {
      final y = cT + (1 - g / 4) * cH;
      canvas.drawLine(Offset(cL, y), Offset(cR, y), gridP);
    }
    _drawDayLines(canvas, data, n, xOf, cT, cB, gridP);

    // Rain bars
    final barW = math.max(2.0, (cW / n) * 0.65);
    for (int i = 0; i < n; i++) {
      final h = barH(rains[i]);
      if (h < 0.5) continue;
      final rect = Rect.fromLTWH(xOf(i) - barW / 2, cB - h, barW, h);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = const Color(0xFF00BCD4).withOpacity(0.80));
    }

    // Y axis
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int g = 0; g <= 4; g++) {
      final v = maxRain * g / 4;
      final y = cT + (1 - g / 4) * cH;
      tp.text = TextSpan(text: v.toStringAsFixed(g == 0 ? 0 : 1),
          style: TextStyle(color: const Color(0xFF00BCD4), fontSize: 8, fontWeight: FontWeight.w600));
      tp.layout(); tp.paint(canvas, Offset(cL - tp.width - 3, y - tp.height / 2));
    }

    // X time axis
    _drawXTimeAxis(canvas, data, n, xOf, cB, size.width);

    // Wind arrows below the bars
    final arrowY = cB + 22.0;
    final arrowP = Paint()..color = const Color(0xFF546E7A)..strokeWidth = 1.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final step = (n / 28).ceil().clamp(1, 8);
    for (int i = 0; i < n; i += step) {
      final x   = xOf(i);
      final dir = data[i].windFromDirection * math.pi / 180.0;
      const len = 7.0, headLen = 3.5;
      final ex = x + math.sin(dir) * len, ey = arrowY - math.cos(dir) * len;
      canvas.drawLine(Offset(x, arrowY), Offset(ex, ey), arrowP);
      canvas.drawLine(Offset(ex, ey), Offset(ex - math.sin(dir + 2.5) * headLen, ey + math.cos(dir + 2.5) * headLen), arrowP);
      canvas.drawLine(Offset(ex, ey), Offset(ex - math.sin(dir - 2.5) * headLen, ey + math.cos(dir - 2.5) * headLen), arrowP);
    }

    // "Wind" label
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
      final x = xOf(i).clamp(0.0, totalWidth - tp.width - 4);
      tp.paint(canvas, Offset(x + 2, cB + 4));
    }
  }
}

// Keep _CombinedMeteogramChart and painter for backward compat (unused now but avoids deletion errors)
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



// ─────────────────────────────────────────────────────────────────────────────
// LEGEND HELPERS  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _LegendItem extends StatelessWidget {
  final Color color; final String label; final bool isDash, isDot, isArrow;
  const _LegendItem({required this.color, required this.label, this.isDash = false, this.isDot = false, this.isArrow = false});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    SizedBox(width: 20, height: 14, child: CustomPaint(
        painter: _LegendSymbolPainter(color: color, isDash: isDash, isDot: isDot, isArrow: isArrow))),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: Colors.black54)),
  ]);
}

class _LegendSymbolPainter extends CustomPainter {
  final Color color; final bool isDash, isDot, isArrow;
  const _LegendSymbolPainter({required this.color, required this.isDash, required this.isDot, required this.isArrow});
  @override void paint(Canvas canvas, Size size) {
    final p  = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;
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
// VERTICAL PROFILE SHEET  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _VerticalProfileSheet extends StatefulWidget {
  final LatLng point;
  const _VerticalProfileSheet({required this.point});
  @override State<_VerticalProfileSheet> createState() => _VerticalProfileSheetState();
}
class _VerticalProfileSheetState extends State<_VerticalProfileSheet> {
  late Future<String> _locationFuture;
  @override void initState() { super.initState(); _locationFuture = _NcmrwfApiService.reverseGeocode(lat: widget.point.latitude, lon: widget.point.longitude); }
  @override Widget build(BuildContext context) => _BaseSheet(
    titleKey: AppStrings.verticalProfile, subtitle: 'Skew-T Log-P Diagram',
    locationFuture: _locationFuture,
    chartWidgets: [
      _ApiImageWidget(imageUrl: _NcmrwfApiService.verticalProfileUrl(lat: widget.point.latitude, lon: widget.point.longitude),
          fallbackTitle: 'Skew-T Log-P Diagram', fallbackIcon: Icons.ssid_chart_rounded, fallbackColor: const Color(0xFFE8F5E9), height: 380),
      Wrap(spacing: 16, children: const [
        _LegendDot(color: Color(0xFFB71C1C), label: 'Temperature'),
        _LegendDot(color: Color(0xFF1B5E20), label: 'Dewpoint'),
      ]),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EPS GRAM SHEET  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _EPSgramSheet extends StatefulWidget {
  final LatLng point;
  const _EPSgramSheet({required this.point});
  @override State<_EPSgramSheet> createState() => _EPSgramSheetState();
}
class _EPSgramSheetState extends State<_EPSgramSheet> {
  late Future<String> _locationFuture;
  @override void initState() { super.initState(); _locationFuture = _NcmrwfApiService.reverseGeocode(lat: widget.point.latitude, lon: widget.point.longitude); }
  @override Widget build(BuildContext context) => _BaseSheet(
    titleKey: AppStrings.epsgram, subtitle: 'Control Forecast & ENS Distribution',
    locationFuture: _locationFuture,
    chartWidgets: [
      _ApiImageWidget(imageUrl: _NcmrwfApiService.epsgramUrl(lat: widget.point.latitude, lon: widget.point.longitude),
          fallbackTitle: 'EPS Ensemble Forecast', fallbackIcon: Icons.bar_chart_rounded, fallbackColor: const Color(0xFFFFF3E0), height: 480),
      Wrap(spacing: 16, children: const [
        _LegendDot(color: Color(0xFF1565C0), label: 'Control Run'),
        _LegendDot(color: Color(0xFF78909C), label: 'Ensemble Members'),
      ]),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// API IMAGE WIDGET  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _ApiImageWidget extends StatelessWidget {
  final String imageUrl, fallbackTitle; final IconData fallbackIcon;
  final Color fallbackColor; final double height;
  const _ApiImageWidget({required this.imageUrl, required this.fallbackTitle,
    required this.fallbackIcon, required this.fallbackColor, this.height = 300});

  @override Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: double.infinity, height: height,
      decoration: BoxDecoration(color: fallbackColor, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
      child: Image.network(imageUrl, fit: BoxFit.contain,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          final pct = progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null;
          return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(value: pct, color: const Color(0xFF1565C0), strokeWidth: 2),
            const SizedBox(height: 12),
            Text('Loading chart…', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[500])),
          ]);
        },
        errorBuilder: (ctx, error, st) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(fallbackIcon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(fallbackTitle, textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600))),
          const SizedBox(height: 6),
          Text(AppStrings.connectAPI, style: GoogleFonts.dmSans(fontSize: 10, color: Colors.grey[400])),
        ]),
      ),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color; final String label;
  const _LegendDot({required this.color, required this.label});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: Colors.black54)),
  ]);
}

