// lib/main.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_ncmrwf_app/providers/products_provider.dart';
import 'package:new_ncmrwf_app/screens/Login_screen.dart';
import 'package:new_ncmrwf_app/services/auth_service.dart';
import 'package:new_ncmrwf_app/services/local_notification_service.dart';
import 'package:new_ncmrwf_app/utils/weather_condition_theme.dart';
import 'package:new_ncmrwf_app/utils/time_theme.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/weather_provider.dart';
import 'providers/app_providers.dart';
import 'screens/forecast_screen.dart';
import 'screens/map_screen.dart';
import 'screens/products_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/app_strings.dart';
import 'utils/translated_text.dart';
import 'services/translator_service.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // ── Providers ─────────────────────────────────────────────────────────────
  final settingsProvider = SettingsProvider();
  final favProvider      = FavoritesProvider();
  final weatherProvider  = WeatherProvider();

  await favProvider.loadFavorites();
  await weatherProvider.initFromCache();

  // ✅ AUTH: Check login state before runApp — fast disk reads < 10ms
  final bool sessionExpired = await AuthService.wasSessionExpired();
  final bool loggedIn       = await AuthService.isLoggedIn();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: weatherProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: favProvider),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider.value(value: TranslatorService.notifier),
      ],
      child: NCMRWFApp(
        isLoggedIn: loggedIn,
        sessionExpired: sessionExpired,
      ),
    ),
  );

  weatherProvider.initAndRefresh();

  // ✅ FIX: Delay heavy services by 3 seconds so OneSignal has time
  // to fully register the device before we add listeners
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(seconds: 3), _initHeavyServices);
  });
}

Future<void> _initHeavyServices() async {
  try {
    OneSignal.Debug.setLogLevel(OSLogLevel.none);
    OneSignal.initialize('966404a4-cd8a-4d04-b1f5-9a78a8b5e20d');
    await LocalNotificationService.initialize();

    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
    await OneSignal.Notifications.requestPermission(true);

    // ── Log subscription state ─────────────────────────────────────────────
    final playerId    = OneSignal.User.pushSubscription.id;
    final isOptedIn   = OneSignal.User.pushSubscription.optedIn;
    debugPrint('[OneSignal] Player ID: $playerId');
    debugPrint('[OneSignal] Opted in: $isOptedIn');

    // ── Watch for subscription changes ─────────────────────────────────────
    OneSignal.User.pushSubscription.addObserver((state) {
      debugPrint('[OneSignal] Subscription updated:');
      debugPrint('  id: ${state.current.id}');
      debugPrint('  optedIn: ${state.current.optedIn}');
    });

    // ── Notification arrives while app is OPEN ─────────────────────────────
    // OneSignal suppresses heads-up in foreground — show it via local plugin
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final n = event.notification;
      debugPrint('[OneSignal] Foreground notification: ${n.title}');
      LocalNotificationService.showWeatherAlert(
        n.title ?? 'Weather Alert',
        n.body  ?? '',
      );
      event.preventDefault(); // stop OneSignal's own display
    });

    // ── User TAPS a notification ───────────────────────────────────────────
    OneSignal.Notifications.addClickListener((event) {
      debugPrint('[OneSignal] Notification tapped: '
          '${event.notification.additionalData}');
      // Add navigation here later if needed:
      // navigatorKey.currentState?.pushNamed('/forecast');
    });

    debugPrint('[OneSignal] ✅ Heavy services initialized');
  } catch (e) {
    debugPrint('[main] deferred init error: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class NCMRWFApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool sessionExpired;

  const NCMRWFApp({
    super.key,
    required this.isLoggedIn,
    required this.sessionExpired,
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppStrings.appName,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF060D1A),
    ),
    home: isLoggedIn
        ? const MainShell()
        : LoginScreen(sessionExpired: sessionExpired),
  );
}

// ─── AppTimeTheme ─────────────────────────────────────────────────────────────
class AppTimeTheme {
  final List<Color> bgColors;
  final List<Color> glowColors;
  final Color accent;
  final String label;
  const AppTimeTheme({
    required this.bgColors,
    required this.glowColors,
    required this.accent,
    required this.label,
  });

  static AppTimeTheme forHour(int h) {
    if (h >= 5 && h < 9)
      return const AppTimeTheme(
          bgColors: [Color(0xFF0D2137), Color(0xFF1A3A5C), Color(0xFF1E4976)],
          glowColors: [Color(0xFF4FC3F7), Color(0xFFFFCC80)],
          accent: Color(0xFF81D4FA),
          label: 'Cool Morning');
    if (h >= 9 && h < 16)
      return const AppTimeTheme(
          bgColors: [Color(0xFF1C0A00), Color(0xFF3E1F00), Color(0xFF6D3A00)],
          glowColors: [Color(0xFFFF8C42), Color(0xFFFFD166)],
          accent: Color(0xFFFFB347),
          label: 'Hot Day');
    if (h >= 16 && h < 18)
      return const AppTimeTheme(
          bgColors: [Color(0xFF12213A), Color(0xFF1E3A5F), Color(0xFF2D5282)],
          glowColors: [Color(0xFFFFAB76), Color(0xFF80DEEA)],
          accent: Color(0xFFFFAB76),
          label: 'Mid Day');
    return const AppTimeTheme(
        bgColors: [Color(0xFF060D1A), Color(0xFF0D1B2A), Color(0xFF111F35)],
        glowColors: [Color(0xFF1565C0), Color(0xFF4A148C)],
        accent: Color(0xFF90CAF9),
        label: 'Night');
  }
}

// ─── Animated Background ──────────────────────────────────────────────────────
class AppAnimBg extends StatefulWidget {
  final AppTimeTheme theme;
  const AppAnimBg({super.key, required this.theme});
  @override
  State<AppAnimBg> createState() => _AppAnimBgState();
}

class _AppAnimBgState extends State<AppAnimBg>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Stack(children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: widget.theme.bgColors,
            ),
          ),
        ),
        Positioned(
          top: -60 + _a.value * 30, right: -60 + _a.value * 20,
          child: Container(
            width: s.width * .75, height: s.width * .75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                widget.theme.glowColors[0].withOpacity(.35),
                widget.theme.glowColors[0].withOpacity(.10),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: 80 - _a.value * 40, left: -80 + _a.value * 20,
          child: Container(
            width: s.width * .65, height: s.width * .65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                widget.theme.glowColors[1].withOpacity(.28),
                widget.theme.glowColors[1].withOpacity(.08),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Glass Card ───────────────────────────────────────────────────────────────
class AppGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;
  const AppGlassCard({
    super.key, required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 20,
    this.color, this.borderColor,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.28)),
        ),
        child: child,
      ),
    ),
  );
}

// ─── Notch Clipper ────────────────────────────────────────────────────────────
class _NotchClipper extends CustomClipper<Path> {
  final double notchRadius;
  final double cornerRadius;
  const _NotchClipper({required this.notchRadius, required this.cornerRadius});

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height, cx = w / 2;
    final nr = notchRadius, br = cornerRadius;
    return Path()
      ..moveTo(br, 0)
      ..lineTo(cx - nr - 14, 0)
      ..cubicTo(cx - nr + 2, 0, cx - nr, nr * 0.88, cx, nr * 0.88)
      ..cubicTo(cx + nr, nr * 0.88, cx + nr - 2, 0, cx + nr + 14, 0)
      ..lineTo(w - br, 0)
      ..quadraticBezierTo(w, 0, w, br)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(0, br)
      ..quadraticBezierTo(0, 0, br, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _NotchClipper old) =>
      old.notchRadius != notchRadius || old.cornerRadius != cornerRadius;
}

// ─── Notched Bar Painter ──────────────────────────────────────────────────────
class _NotchedBarPainter extends CustomPainter {
  final Color color;
  final double notchRadius;
  final double cornerRadius;
  const _NotchedBarPainter({
    required this.color, required this.notchRadius, required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, cx = w / 2;
    final nr = notchRadius, br = cornerRadius;
    final path = Path()
      ..moveTo(br, 0)
      ..lineTo(cx - nr - 14, 0)
      ..cubicTo(cx - nr + 2, 0, cx - nr, nr * 0.88, cx, nr * 0.88)
      ..cubicTo(cx + nr, nr * 0.88, cx + nr - 2, 0, cx + nr + 14, 0)
      ..lineTo(w - br, 0)
      ..quadraticBezierTo(w, 0, w, br)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(0, br)
      ..quadraticBezierTo(0, 0, br, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    final border = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(br, 0), Offset(cx - nr - 14, 0), border);
    canvas.drawLine(Offset(cx + nr + 14, 0), Offset(w - br, 0), border);
  }

  @override
  bool shouldRepaint(covariant _NotchedBarPainter old) => old.color != color;
}

// ─── MAIN SHELL ───────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  int _prevIdx = 0;

  Timer? _minuteTimer;

  late AnimationController _fabAnim;
  late Animation<double> _fabScale;
  late Animation<double> _fabRotate;

  final _screens = const [
    ForecastScreen(),
    DashboardScreen(),
    FavoritesScreen(),
    SettingsScreen(),
    MapScreen(),
  ];

  static const _tabLabels = [
    AppStrings.forecast,
    AppStrings.products,
    AppStrings.favorites,
    AppStrings.settings,
  ];

  static const _tabIcons = [
    (Icons.home,                 Icons.home),
    (Icons.grid_view_outlined,   Icons.grid_view_rounded),
    (Icons.star_outline_rounded, Icons.star_rounded),
    (Icons.settings_outlined,    Icons.settings),
  ];

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _fabScale = Tween<double>(begin: 1.0, end: 0.88).animate(
        CurvedAnimation(parent: _fabAnim, curve: Curves.easeInOut));
    _fabRotate = Tween<double>(begin: 0.0, end: 0.125).animate(
        CurvedAnimation(parent: _fabAnim, curve: Curves.easeInOut));

    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    _minuteTimer?.cancel();
    super.dispose();
  }

  void _onFabTap() async {
    await _fabAnim.forward();
    await _fabAnim.reverse();
    if (!mounted) return;
    setState(() {
      if (_idx == 4) {
        _idx = _prevIdx;
      } else {
        _prevIdx = _idx;
        _idx = 4;
      }
    });
  }

  Widget _buildTab(int tabIndex, int screenIndex, Color activeAccent) {
    final sel = _idx == screenIndex;
    return GestureDetector(
      onTap: () => setState(() => _idx = screenIndex),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: sel
                    ? activeAccent.withOpacity(0.22)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: sel
                    ? Border.all(color: activeAccent.withOpacity(0.35), width: 1)
                    : null,
              ),
              child: Icon(
                sel ? _tabIcons[tabIndex].$2 : _tabIcons[tabIndex].$1,
                color: sel ? activeAccent : Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            TranslatedText(
              _tabLabels[tabIndex],
              style: TextStyle(
                color: sel ? activeAccent : Colors.white,
                fontSize: 10,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsProvider>();
    final wp        = context.watch<WeatherProvider>();
    final condition = wp.currentWeather?.condition ?? 'sunny';

    final tt        = TimeTheme.of();
    final condTheme = WeatherConditionTheme.of(condition);
    final isNight = tt.periodLabel == 'Night';
    final Color navColor = isNight
        ? tt.sheetGrad2.withOpacity(0.97)          // #040A18 deep navy
        : condTheme.skyGradient.last.withOpacity(0.88);
    final activeAccent = tt.accent;

    final bool onMap = _idx == 4;
    final List<Color> fabGradient = onMap
        ? const [Color(0xFF26C6DA), Color(0xFF00838F)]
        : _fabGradientForPeriod(tt.periodLabel);
    final Color fabGlow = onMap
        ? const Color(0xFF00838F)
        : fabGradient.last;

    const double barHeight         = 70;
    const double fabR              = 29.0;
    const double notchR            = fabR + 9;
    const double cornerR           = 26.0;
    const double fabCenterAboveBar = 14.0;
    final double bottomPad         = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: SizedBox(
        height: barHeight + bottomPad + fabR + fabCenterAboveBar,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: barHeight + bottomPad,
              child: ClipPath(
                clipper: _NotchClipper(notchRadius: notchR, cornerRadius: cornerR),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: CustomPaint(
                    painter: _NotchedBarPainter(
                      color: navColor, notchRadius: notchR, cornerRadius: cornerR,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPad),
                      child: SizedBox(
                        height: barHeight,
                        child: Row(children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildTab(0, 0, activeAccent),
                                _buildTab(1, 1, activeAccent),
                              ],
                            ),
                          ),
                          SizedBox(width: notchR * 2 + 12),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildTab(2, 2, activeAccent),
                                _buildTab(3, 3, activeAccent),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: barHeight + bottomPad - fabR + fabCenterAboveBar,
              child: ScaleTransition(
                scale: _fabScale,
                child: GestureDetector(
                  onTap: _onFabTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: fabR * 2, height: fabR * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: fabGradient,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: fabGlow.withOpacity(0.60),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: AnimatedRotation(
                      turns: onMap ? 0.125 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(Icons.map,
                          color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _fabGradientForPeriod(String period) {
    switch (period) {
      case 'Dawn':
        return const [Color(0xFFFFAB91), Color(0xFFE64A19)];
      case 'Dusk':
        return const [Color(0xFFFF8A65), Color(0xFFBF360C)];
      case 'Night':
        return const [Color(0xFF5C6BC0), Color(0xFF283593)];
      default:
        return const [Color(0xFFFF9A5C), Color(0xFFFF5722)];
    }
  }
}