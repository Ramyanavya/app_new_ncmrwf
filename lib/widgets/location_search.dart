// lib/widgets/location_search.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../providers/weather_provider.dart';
import '../providers/app_providers.dart';
import '../services/translator_service.dart';
import '../utils/app_strings.dart';
import '../utils/translated_text.dart';
import '../main.dart';

class LocationSearchSheet extends StatefulWidget {
  /// When provided (e.g. from FavoritesScreen), tapping a result calls this
  /// callback instead of fetching weather. The sheet is closed by the caller.
  final void Function(String name, double lat, double lon)? onLocationSelected;

  const LocationSearchSheet({super.key, this.onLocationSelected});

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final _controller      = TextEditingController();
  final _scrollCtrl      = ScrollController();
  final _locationService = LocationService();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  final Map<String, String> _nameCache = {};

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _langCode => context.read<SettingsProvider>().languageCode;

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);

    final rawResults = await _locationService.searchPlaces(
      q,
      langCode: _langCode,
    );

    if (_langCode == 'hi') {
      for (final r in rawResults) {
        final short = r['short'] as String;
        final name  = r['name']  as String;
        if (_isEnglish(short) && !_nameCache.containsKey(short)) {
          _nameCache[short] = await TranslatorService.translate(short);
        }
        if (_isEnglish(name) && !_nameCache.containsKey(name)) {
          _nameCache[name] = await TranslatorService.translate(name);
        }
      }
    }

    if (mounted) {
      setState(() {
        _results = rawResults;
        _loading = false;
      });
    }
  }

  bool _isEnglish(String s) {
    if (s.isEmpty) return false;
    final ascii = s.codeUnits.where((c) => c < 128).length;
    return ascii / s.length > 0.7;
  }

  String _displayShort(Map<String, dynamic> r) {
    final short = r['short'] as String;
    if (_langCode != 'hi') return short;
    return _nameCache[short] ?? short;
  }

  String _displayName(Map<String, dynamic> r) {
    final name = r['name'] as String;
    if (_langCode != 'hi') return name;
    return _nameCache[name] ?? name;
  }

  /// Called when any result tile is tapped.
  /// If [onLocationSelected] is set → hand off to caller (favorites mode).
  /// Otherwise → fetch weather directly (normal mode).
  void _handleResultTap(String name, double lat, double lon) {
    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(name, lat, lon);
    } else {
      Navigator.pop(context);
      context.read<WeatherProvider>().fetchWeatherForLocation(
        lat: lat,
        lon: lon,
        name: name,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme     = AppTimeTheme.forHour(DateTime.now().hour);
    final mq        = MediaQuery.of(context);
    final keyboardH = mq.viewInsets.bottom;
    final screenH   = mq.size.height;
    final topPad    = mq.padding.top;
    final botPad    = mq.padding.bottom;

    final maxSheetH = (screenH - topPad - keyboardH) * 0.80;

    context.watch<SettingsProvider>();

    // In favorites mode, hide "Use current location" and "Use default" tiles
    final isFavMode = widget.onLocationSelected != null;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardH),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetH),
            child: Container(
              decoration: BoxDecoration(
                color: theme.bgColors[1].withOpacity(0.95),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.12))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Title when in favorites mode ────────────────
                      if (isFavMode) ...[
                        Row(children: [
                          Icon(Icons.star_outline_rounded,
                              color: theme.accent, size: 18),
                          const SizedBox(width: 8),
                          TranslatedText(
                            AppStrings.addLocation,
                            style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                        ]),
                        const SizedBox(height: 10),
                      ],

                      // ── Search field ────────────────────────────────
                      WithTranslation(
                        text: AppStrings.searchHint,
                        builder: (hint) => TextField(
                          controller: _controller,
                          autofocus: true,
                          style: GoogleFonts.dmSans(
                              color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle:
                            GoogleFonts.dmSans(color: Colors.white38),
                            prefixIcon: const Icon(Icons.search,
                                color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.15)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: theme.accent.withOpacity(0.7),
                                  width: 1.5),
                            ),
                            suffixIcon: _loading
                                ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.accent),
                              ),
                            )
                                : _controller.text.isNotEmpty
                                ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white38, size: 18),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _results = []);
                              },
                            )
                                : null,
                          ),
                          onChanged: _search,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // ── Quick-access tiles (normal mode only) ───────
                      if (!isFavMode) ...[
                        _SheetTile(
                          icon: Icons.my_location_rounded,
                          iconColor: theme.accent,
                          titleWidget: TranslatedText(
                            'Use current location',
                            style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            await context
                                .read<WeatherProvider>()
                                .fetchWeatherForCurrentLocation();
                          },
                        ),
                        _SheetTile(
                          icon: Icons.location_city_rounded,
                          iconColor: Colors.white38,
                          titleWidget: TranslatedText(
                            AppStrings.useDefaultLocation,
                            style: GoogleFonts.dmSans(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                                fontSize: 14),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            context
                                .read<WeatherProvider>()
                                .fetchWeatherForLocation(
                              lat: 28.6139,
                              lon: 77.2090,
                              name: _langCode == 'hi'
                                  ? 'नई दिल्ली'
                                  : 'New Delhi',
                            );
                          },
                        ),
                      ],

                      // Divider shown only when results are present
                      if (_results.isNotEmpty ||
                          (_controller.text.trim().length >= 2 && !_loading))
                        Divider(
                            color: Colors.white.withOpacity(0.10),
                            height: 8),
                    ]),
                  ),

                  Flexible(
                    child: _buildResultsArea(theme, botPad, keyboardH),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsArea(
      AppTimeTheme theme, double botPad, double keyboardH) {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CircularProgressIndicator(
              strokeWidth: 2, color: theme.accent),
        ),
      );
    }

    // Has results — show scrollable list
    if (_results.isNotEmpty) {
      return ListView.builder(
        controller: _scrollCtrl,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            16, 4, 16, keyboardH > 0 ? 8 : botPad + 8),
        itemCount: _results.length,
        itemBuilder: (ctx, i) {
          final r    = _results[i];
          final name = _displayShort(r);
          final lat  = r['lat'] as double;
          final lon  = r['lon'] as double;

          return _SheetTile(
            icon: widget.onLocationSelected != null
                ? Icons.star_border_rounded   // star icon in favorites mode
                : Icons.location_on_outlined,
            iconColor: widget.onLocationSelected != null
                ? theme.accent.withOpacity(0.7)
                : Colors.white38,
            titleWidget: Text(
              name,
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitleWidget: Text(
              _displayName(r),
              style:
              GoogleFonts.dmSans(color: Colors.white38, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _handleResultTap(name, lat, lon),
          );
        },
      );
    }

    if (_controller.text.trim().length >= 2) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, color: Colors.white24, size: 36),
          const SizedBox(height: 10),
          TranslatedText(
            'No locations found',
            style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 13),
          ),
        ]),
      );
    }

    return const SizedBox.shrink();
  }
}

class _SheetTile extends StatelessWidget {
  final IconData  icon;
  final Color     iconColor;
  final Widget    titleWidget;
  final Widget?   subtitleWidget;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.iconColor,
    required this.titleWidget,
    required this.onTap,
    this.subtitleWidget,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget,
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: 2),
                    subtitleWidget!,
                  ],
                ]),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Colors.white12, size: 18),
        ]),
      ),
    );
  }
}