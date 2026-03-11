// ─────────────────────────────────────────────────────────────────────────────
// pubspec.yaml — add:
//   webview_flutter: ^4.7.0
//
// android/app/src/main/AndroidManifest.xml — inside <application> tag add:
//   <uses-permission android:name="android.permission.INTERNET"/>
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';
import '../utils/translated_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  static const bg1         = Color(0xFF060D1A);
  static const bg2         = Color(0xFF0D1B2A);
  static const navy        = Color(0xFF003844);
  static const navyLight   = Color(0xFF004F61);
  static const orange      = Color(0xFFFF8C00);
  static const orangeLight = Color(0xFFFF9A5C);
  static const white70     = Color(0xB3FFFFFF);
  static const white45     = Color(0x73FFFFFF);
  static const white38     = Color(0x61FFFFFF);
  static const white20     = Color(0x33FFFFFF);
  static const white12     = Color(0x1FFFFFFF);
  static const white08     = Color(0x14FFFFFF);
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT MODEL  (self-contained — no dependency on ProductModel)
// ─────────────────────────────────────────────────────────────────────────────
class _Prod {
  final int          id;
  final String       name;
  final String       desc;
  final String       type;
  final String       catKey;
  final String?      subcat;
  final String       baseUrl;
  final List<int>    hpa;
  final List<String> utc;
  final List<int>    fcst;
  final List<String> cities;
  final List<String> cityUrls;

  const _Prod({
    required this.id,
    required this.name,
    required this.desc,
    required this.type,
    required this.catKey,
    this.subcat,
    required this.baseUrl,
    this.hpa      = const [],
    this.utc      = const [],
    this.fcst     = const [],
    this.cities   = const [],
    this.cityUrls = const [],
  });

  bool get hasHpa   => hpa.isNotEmpty;
  bool get hasUtc   => utc.isNotEmpty;
  bool get hasFcst  => fcst.isNotEmpty;
  bool get hasCity  => cities.isNotEmpty;
  bool get isStatic => type == 'static';
}

// ─────────────────────────────────────────────────────────────────────────────
// URL BUILDER
// ─────────────────────────────────────────────────────────────────────────────
String _buildUrl(
    _Prod p, String date, String? utc, int? hpa, int? fcst, String? city) {
  if (p.isStatic) return p.baseUrl;
  String url = p.baseUrl;
  url = url.replaceAll('{date}', date.replaceAll('-', ''));
  url = url.replaceAll('{utc}',  utc  ?? '');
  url = url.replaceAll('{hpa}',  hpa?.toString() ?? '');
  url = url.replaceAll('{fcst}',
      fcst != null ? fcst.toString().padLeft(3, '0') : '');
  url = url.replaceAll('{city}', city ?? '');
  return url;
}

// ─────────────────────────────────────────────────────────────────────────────
// CHART VIEWER SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ChartViewerScreen extends StatefulWidget {
  final _Prod prod;
  const ChartViewerScreen({super.key, required this.prod});

  @override
  State<ChartViewerScreen> createState() => _ChartViewerState();
}

class _ChartViewerState extends State<ChartViewerScreen>
    with SingleTickerProviderStateMixin {

  // ── param state ────────────────────────────────────────────────────────────
  late String  _date;
  String?      _utc;
  int?         _hpa;
  int?         _fcst;
  String?      _cityUrl;
  String?      _cityName;
  bool         _paramsExpanded = true;

  // ── webview state ──────────────────────────────────────────────────────────
  WebViewController? _webCtrl;
  bool   _loading     = false;
  int    _progress    = 0;
  int    _httpStatus  = 0;       // last HTTP status code
  bool   _hasError    = false;
  String _errorMsg    = '';
  bool   _webReady    = false;   // controller initialised

  // ── animation ──────────────────────────────────────────────────────────────
  late AnimationController _bgCtrl;
  late Animation<double>   _bgA;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _bgA = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);

    final p = widget.prod;
    _date    = _today();
    _utc     = p.utc.isNotEmpty  ? p.utc.first  : null;
    _hpa     = p.hpa.isNotEmpty  ? p.hpa.first  : null;
    _fcst    = p.fcst.isNotEmpty ? p.fcst.first : null;
    if (p.cities.isNotEmpty) {
      _cityName = p.cities.first;
      _cityUrl  =
      p.cityUrls.isNotEmpty ? p.cityUrls.first : p.cities.first;
    }
    _initWebView();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String get _builtUrl =>
      _buildUrl(widget.prod, _date, _utc, _hpa, _fcst, _cityUrl);

  // ── WebView init ───────────────────────────────────────────────────────────
  void _initWebView() {
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_T.bg1)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _loading    = true;
          _hasError   = false;
          _progress   = 0;
          _httpStatus = 0;
        }),
        onProgress: (p) => setState(() => _progress = p),
        onPageFinished: (_) => setState(() => _loading = false),

        // ── Catch HTTP errors (304, 404, 500 …) ──────────────────────
        onHttpError: (HttpResponseError error) {
          setState(() {
            _httpStatus = error.response?.statusCode ?? 0;
            _hasError   = true;
            _loading    = false;
            _errorMsg   = _httpStatusMessage(_httpStatus);
          });
        },

        // ── Catch network / SSL / timeout errors ─────────────────────
        onWebResourceError: (WebResourceError error) {
          // Ignore sub-resource errors (images, CSS, etc.);
          // only fail on main-frame errors.
          if (error.isForMainFrame ?? true) {
            setState(() {
              _hasError  = true;
              _loading   = false;
              _errorMsg  = _webErrorMessage(error);
            });
          }
        },

        // ── Intercept navigation ──────────────────────────────────────
        onNavigationRequest: (NavigationRequest req) {
          // Allow all navigation within the same host
          return NavigationDecision.navigate;
        },
      ));

    setState(() {
      _webCtrl  = ctrl;
      _webReady = true;
    });

    ctrl.loadRequest(Uri.parse(_builtUrl));
  }

  // ── Reload with current params ─────────────────────────────────────────────
  void _loadChart() {
    if (_webCtrl == null) { _initWebView(); return; }
    setState(() { _loading = true; _hasError = false; _progress = 0; });
    _webCtrl!.loadRequest(Uri.parse(_builtUrl));
  }

  // ── HTTP status → user message ─────────────────────────────────────────────
  String _httpStatusMessage(int code) {
    switch (code) {
      case 304: return 'HTTP 304 — The server returned "Not Modified".\n'
          'This usually means the URL is correct but the server is '
          'asking the browser to use a cached version. '
          'The chart should still display. If not, try reloading.';
      case 401:
      case 403: return 'HTTP $code — Access denied.\n'
          'This resource requires authentication or is restricted.';
      case 404: return 'HTTP 404 — Chart not found.\n'
          'The file may not exist for the selected date/parameters yet.';
      case 500:
      case 502:
      case 503: return 'HTTP $code — Server error.\n'
          'The NCMRWF server is temporarily unavailable. Try again later.';
      default:  return 'HTTP $code — Unexpected server response.';
    }
  }

  String _webErrorMessage(WebResourceError e) {
    final desc = e.description.toLowerCase();
    if (desc.contains('net::err_internet_disconnected') ||
        desc.contains('net::err_network_changed')) {
      return 'No internet connection.\nPlease check your network and retry.';
    }
    if (desc.contains('net::err_name_not_resolved')) {
      return 'Could not reach the server.\n'
          'Check your connection or try again later.';
    }
    if (desc.contains('net::err_connection_timed_out') ||
        desc.contains('net::err_timed_out')) {
      return 'Connection timed out.\nThe server took too long to respond.';
    }
    if (desc.contains('net::err_ssl')) {
      return 'SSL / certificate error.\n'
          'The server\'s security certificate could not be verified.';
    }
    return 'Failed to load page.\n${e.description}';
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final p = widget.prod;
    return Scaffold(
      backgroundColor: _T.bg1,
      appBar: _buildAppBar(),
      body: Stack(children: [
        // animated bg visible before/during load
        _AnimBg(anim: _bgA),

        SafeArea(
          child: Column(children: [

            // ── PARAM PANEL ──────────────────────────────────────────
            if (!p.isStatic) _buildParamPanel(p),

            // ── URL BAR ───────────────────────────────────────────────
            _buildUrlBar(),

            // ── PROGRESS BAR ──────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _loading
                  ? LinearProgressIndicator(
                key: const ValueKey('bar'),
                value: _progress > 0 ? _progress / 100 : null,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor:
                const AlwaysStoppedAnimation<Color>(_T.orange),
                minHeight: 3,
              )
                  : const SizedBox(key: ValueKey('empty'), height: 3),
            ),

            // ── WEBVIEW AREA ──────────────────────────────────────────
            Expanded(
              child: _hasError
                  ? _buildErrorState()
                  : _webReady
                  ? Stack(children: [
                WebViewWidget(controller: _webCtrl!),
                if (_loading) _buildLoadingOverlay(),
              ])
                  : _buildLoadingOverlay(),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── APP BAR ────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() => AppBar(
    backgroundColor: _T.navy,
    foregroundColor: Colors.white,
    elevation: 0,
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.prod.name,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      if (widget.prod.desc.isNotEmpty)
        Text(widget.prod.desc,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
    ]),
    actions: [
      // Reload
      IconButton(
        tooltip: 'Reload',
        icon: const Icon(Icons.refresh_rounded, size: 22),
        onPressed: () => _webCtrl?.reload(),
      ),
      // WebView back
      IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 17),
        onPressed: () async {
          if (_webCtrl != null && await _webCtrl!.canGoBack()) {
            _webCtrl!.goBack();
          }
        },
      ),
      // WebView forward
      IconButton(
        tooltip: 'Forward',
        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
        onPressed: () async {
          if (_webCtrl != null && await _webCtrl!.canGoForward()) {
            _webCtrl!.goForward();
          }
        },
      ),
    ],
  );

  // ── URL BAR ────────────────────────────────────────────────────────────────
  Widget _buildUrlBar() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
    ),
    child: Row(children: [
      Icon(
        _hasError
            ? Icons.warning_amber_rounded
            : _loading
            ? Icons.pending_outlined
            : Icons.lock_outline_rounded,
        size: 13,
        color: _hasError ? Colors.orangeAccent : _T.white38,
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          _builtUrl,
          style: TextStyle(
            fontSize: 11,
            color: _hasError ? Colors.orangeAccent.withOpacity(0.8) : _T.white45,
            fontFamily: 'monospace',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // copy URL
      GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: _builtUrl));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tl('URL copied to clipboard')),
              backgroundColor: _T.navyLight,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(Icons.copy_rounded, size: 14, color: _T.white38),
        ),
      ),
    ]),
  );

  // ── PARAM PANEL ────────────────────────────────────────────────────────────
  Widget _buildParamPanel(_Prod p) => Container(
    color: _T.navyLight.withOpacity(0.97),
    child: Column(children: [
      InkWell(
        onTap: () => setState(() => _paramsExpanded = !_paramsExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const Icon(Icons.tune_rounded, size: 15, color: Colors.white54),
            const SizedBox(width: 8),
            Text(tl('FORECAST PARAMETERS'),
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const Spacer(),
            Icon(
              _paramsExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white38,
              size: 20,
            ),
          ]),
        ),
      ),
      if (_paramsExpanded)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Column(children: [
            // Row 1 — Date + UTC
            Row(children: [
              Expanded(child: _DateChip(
                  date: _date,
                  onPick: (v) => setState(() => _date = v))),
              if (p.utc.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(child: _DDChip<String>(
                  icon: Icons.access_time_rounded,
                  label: 'UTC',
                  value: _utc,
                  items: p.utc
                      .map((u) =>
                      DropdownMenuItem(value: u, child: Text('${u}Z')))
                      .toList(),
                  onChanged: (v) => setState(() => _utc = v),
                )),
              ],
            ]),
            const SizedBox(height: 8),
            // Row 2 — hPa + City + Forecast
            Row(children: [
              if (p.hpa.isNotEmpty)
                Expanded(child: _DDChip<int>(
                  icon: Icons.layers_rounded,
                  label: 'Pressure',
                  value: _hpa,
                  items: p.hpa
                      .map((h) => DropdownMenuItem(
                      value: h, child: Text('$h hPa')))
                      .toList(),
                  onChanged: (v) => setState(() => _hpa = v),
                )),
              if (p.hpa.isNotEmpty &&
                  (p.fcst.isNotEmpty || p.cities.isNotEmpty))
                const SizedBox(width: 8),
              if (p.cities.isNotEmpty)
                Expanded(child: _DDChip<String>(
                  icon: Icons.location_city_rounded,
                  label: 'City',
                  value: _cityName,
                  items: List.generate(
                    p.cities.length,
                        (i) => DropdownMenuItem(
                        value: p.cities[i],
                        child: Text(p.cities[i],
                            overflow: TextOverflow.ellipsis)),
                  ),
                  onChanged: (v) {
                    final idx = p.cities.indexOf(v ?? '');
                    setState(() {
                      _cityName = v;
                      _cityUrl  = idx >= 0 && idx < p.cityUrls.length
                          ? p.cityUrls[idx]
                          : v;
                    });
                  },
                )),
              if (p.cities.isNotEmpty && p.fcst.isNotEmpty)
                const SizedBox(width: 8),
              if (p.fcst.isNotEmpty)
                Expanded(child: _DDChip<int>(
                  icon: Icons.schedule_rounded,
                  label: 'Forecast',
                  value: _fcst,
                  items: p.fcst
                      .map((h) => DropdownMenuItem(
                      value: h,
                      child: Text(h == 0 ? tl('Analysis') : '+${h}h')))
                      .toList(),
                  onChanged: (v) => setState(() => _fcst = v),
                )),
            ]),
            const SizedBox(height: 10),
            // LOAD CHART button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_T.orangeLight, _T.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _T.orange.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart_rounded, size: 18),
                  label: Text(tl('Load Chart'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _loadChart,
                ),
              ),
            ),
          ]),
        ),
    ]),
  );

  // ── LOADING OVERLAY ────────────────────────────────────────────────────────
  Widget _buildLoadingOverlay() => Container(
    color: _T.bg1,
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 52, height: 52,
          child: CircularProgressIndicator(
            value: _progress > 0 ? _progress / 100 : null,
            color: _T.orange,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 18),
        TranslatedText(
          _progress > 0 ? 'Loading chart… $_progress%' : tl('Connecting to server…'),
          style: const TextStyle(color: _T.white38, fontSize: 13),
        ),
        if (_progress > 0) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress / 100,
                backgroundColor: Colors.white.withOpacity(0.10),
                valueColor: const AlwaysStoppedAnimation<Color>(_T.orange),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ]),
    ),
  );

  // ── ERROR STATE ────────────────────────────────────────────────────────────
  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.10),
            shape: BoxShape.circle,
            border:
            Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Icon(
            _httpStatus == 304
                ? Icons.info_outline_rounded
                : _httpStatus == 404
                ? Icons.find_in_page_outlined
                : Icons.cloud_off_rounded,
            size: 44,
            color: Colors.orangeAccent,
          ),
        ),
        const SizedBox(height: 20),
        TranslatedText(
          _httpStatus == 304
              ? 'Cache Response (304)'
              : _httpStatus == 404
              ? 'Chart Not Found (404)'
              : _httpStatus > 0
              ? 'Server Error ($_httpStatus)'
              : 'Connection Error',
          style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TranslatedText(
          _errorMsg,
          style: const TextStyle(
              color: _T.white38, fontSize: 12, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // show built URL for debug
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border:
            Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Text(
            _builtUrl,
            style: const TextStyle(
                fontSize: 10,
                color: _T.white38,
                fontFamily: 'monospace'),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        // if 304 — still try to show the webview
        if (_httpStatus == 304)
          _actionBtn(
            icon: Icons.visibility_rounded,
            label: tl('Show Anyway'),
            onPressed: () => setState(() => _hasError = false),
          ),
        const SizedBox(height: 10),
        _actionBtn(
          icon: Icons.refresh_rounded,
          label: tl('Retry'),
          onPressed: _loadChart,
          outlined: true,
        ),
      ]),
    ),
  );

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool outlined = false,
  }) =>
      SizedBox(
        width: 200,
        height: 44,
        child: outlined
            ? OutlinedButton.icon(
          icon: Icon(icon, size: 17),
          label: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: onPressed,
        )
            : DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_T.orangeLight, _T.orange]),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                  color: _T.orange.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: ElevatedButton.icon(
            icon: Icon(icon, size: 17),
            label: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: onPressed,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED BG
// ─────────────────────────────────────────────────────────────────────────────
class _AnimBg extends StatelessWidget {
  final Animation<double> anim;
  const _AnimBg({required this.anim});

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Stack(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_T.bg1, _T.bg2],
            ),
          ),
        ),
        Positioned(
          top: -60 + anim.value * 30,
          right: -60 + anim.value * 20,
          child: Container(
            width: s.width * .7,
            height: s.width * .7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _T.orange.withOpacity(.13),
                _T.orange.withOpacity(.03),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: 60 - anim.value * 30,
          left: -60 + anim.value * 15,
          child: Container(
            width: s.width * .6,
            height: s.width * .6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF1565C0).withOpacity(.16),
                const Color(0xFF1565C0).withOpacity(.04),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHIP WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _DateChip extends StatelessWidget {
  final String date;
  final ValueChanged<String> onPick;
  const _DateChip({required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
        builder: (ctx, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
                primary: _T.orange,
                surface: Color(0xFF003844)),
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        onPick('${picked.year}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}');
      }
    },
    child: _chipBox(Row(children: [
      const Icon(Icons.calendar_today_rounded,
          size: 15, color: Colors.white54),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tl('DATE'),
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700)),
            Text(date,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      const Icon(Icons.edit_calendar_outlined,
          size: 13, color: Colors.white30),
    ])),
  );
}

class _DDChip<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _DDChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => _chipBox(Row(children: [
    Icon(icon, size: 15, color: Colors.white54),
    const SizedBox(width: 8),
    Expanded(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          dropdownColor: const Color(0xFF004F61),
          icon: const Icon(Icons.expand_more_rounded,
              color: Colors.white38, size: 16),
          hint: Text(tl(label),
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12)),
          selectedItemBuilder: (ctx) => items
              .map((item) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(tl(label).toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700)),
              DefaultTextStyle(
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    overflow: TextOverflow.ellipsis),
                child: item.child,
              ),
            ],
          ))
              .toList(),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    ),
  ]));
}

Widget _chipBox(Widget child) => Container(
  height: 52,
  padding: const EdgeInsets.symmetric(horizontal: 10),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.07),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: Colors.white.withOpacity(0.12)),
  ),
  child: child,
);