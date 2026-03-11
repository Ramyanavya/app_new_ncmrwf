// lib/screens/favorites_screen.dart
// ✅ Time-aware theming via TimeTheme.of() — dawn / day / dusk / night
// ✅ Weather-condition-aware accent via WeatherConditionTheme.of(condition, hour: h)
// ✅ Theme rebuilds every minute via _minuteTimer so colors shift automatically

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import '../providers/weather_provider.dart';
import '../models/weather_model.dart';
import '../services/translator_service.dart';
import '../utils/weather_condition_theme.dart';
import '../utils/time_theme.dart';
import '../widgets/location_search.dart';
import '../utils/app_strings.dart';
import '../utils/translated_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IST helper — keeps theme in sync across tabs
// ─────────────────────────────────────────────────────────────────────────────
DateTime _nowIST() =>
    DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

// ─────────────────────────────────────────────────────────────────────────────
// FAVORITES SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    // Rebuild every minute so dawn/dusk/night transitions apply live
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  void _openSearchAndAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationSearchSheet(
        onLocationSelected: (name, lat, lon) async {
          final fp = context.read<FavoritesProvider>();
          final added = await fp.addFavorite(
            FavoriteLocation(name: name, latitude: lat, longitude: lon),
          );
          if (context.mounted) {
            Navigator.pop(context);
            String msg;
            if (added) {
              msg = await TranslatorService.translate(AppStrings.locationAdded);
            } else if (fp.isFull) {
              msg = await TranslatorService.translate(AppStrings.favoritesLimitReached);
            } else {
              msg = await TranslatorService.translate(AppStrings.locationAlreadyAdded);
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white)),
                backgroundColor: Colors.black.withOpacity(0.7),
              ));
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WeatherProvider>(
      builder: (ctx, wp, _) {
        // ── Resolve both palettes ──────────────────────────────────────────
        final istHour   = _nowIST().hour;
        final tt        = TimeTheme.of(istHour);                        // structural bg/card
        final condition = wp.currentWeather?.condition ?? 'partly cloudy';
        final condTheme = WeatherConditionTheme.of(condition, hour: istHour); // accent/icon tint

        // Primary accent comes from weather condition; fallback to TimeTheme accent
        final accent = condTheme.accentColor;

        return Scaffold(
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              // Use TimeTheme's gradient as the structural background
              gradient: tt.linearGradient,
            ),
            child: SafeArea(
              child: Column(children: [

                // ── Top bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        // Time-of-day tinted icon container
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withOpacity(0.25),
                            border: Border.all(color: accent.withOpacity(0.4)),
                          ),
                          child: Icon(Icons.star_rounded, color: accent, size: 18),
                        ),
                        const SizedBox(width: 10),
                        TranslatedText(AppStrings.favorites,
                            style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                      ]),
                      Consumer<FavoritesProvider>(
                        builder: (_, fp, __) => GestureDetector(
                          onTap: fp.isFull
                              ? () async {
                            final msg = await TranslatorService.translate(
                                AppStrings.favoritesLimitReached);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(msg,
                                    style: GoogleFonts.dmSans(color: Colors.white)),
                                backgroundColor: Colors.black.withOpacity(0.7),
                              ));
                            }
                          }
                              : () => _openSearchAndAdd(context),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  // Use TimeTheme cardBg for frosted button
                                  color: fp.isFull
                                      ? tt.cardBg.withOpacity(0.08)
                                      : tt.cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: accent.withOpacity(fp.isFull ? 0.15 : 0.40)),
                                ),
                                child: Icon(
                                  fp.isFull
                                      ? Icons.location_off_outlined
                                      : Icons.add_location_alt_outlined,
                                  color: fp.isFull ? Colors.white38 : accent,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Time-of-day badge ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                  child: Row(children: [
                    _TimeOfDayBadge(hour: istHour, accent: accent, tt: tt),
                  ]),
                ),

                // ── Limit indicator ──────────────────────────────────────
                Consumer<FavoritesProvider>(builder: (_, fp, __) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${fp.favorites.length} / ${FavoritesProvider.maxFavorites}',
                            style: GoogleFonts.dmSans(
                                color: Colors.white60, fontSize: 11)),
                        const SizedBox(width: 6),
                        ...List.generate(FavoritesProvider.maxFavorites, (i) =>
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              margin: const EdgeInsets.only(left: 3),
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < fp.favorites.length
                                    ? accent
                                    : Colors.white24,
                                boxShadow: i < fp.favorites.length
                                    ? [BoxShadow(
                                    color: accent.withOpacity(0.5),
                                    blurRadius: 4)]
                                    : null,
                              ),
                            )),
                      ],
                    ),
                  );
                }),

                // ── Divider tinted by TimeTheme divider color ─────────────
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      tt.divider,
                      Colors.transparent,
                    ]),
                  ),
                ),
                const SizedBox(height: 8),

                // ── List ─────────────────────────────────────────────────
                Expanded(
                  child: Consumer<FavoritesProvider>(builder: (_, fp, __) {
                    if (fp.favorites.isEmpty) {
                      return _buildEmpty(context, condTheme, accent, tt);
                    }
                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                      itemCount: fp.favorites.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final fav = fp.favorites[i];
                        return Dismissible(
                          key: Key('${fav.latitude}_${fav.longitude}'),
                          direction: DismissDirection.endToStart,
                          background: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red.withOpacity(.30),
                              child: const Icon(Icons.delete_rounded,
                                  color: Colors.white),
                            ),
                          ),
                          onDismissed: (_) =>
                              fp.removeFavorite(fav.latitude, fav.longitude),
                          child: GestureDetector(
                            onTap: () => context
                                .read<WeatherProvider>()
                                .fetchWeatherForLocation(
                                lat: fav.latitude,
                                lon: fav.longitude,
                                name: fav.name),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    // TimeTheme cardBg for frosted list tiles
                                    color: tt.cardBg,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                        color: accent.withOpacity(0.25)),
                                  ),
                                  child: Row(children: [
                                    // Accent-tinted location icon
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 500),
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accent.withOpacity(0.20),
                                        border: Border.all(
                                            color: accent.withOpacity(0.35)),
                                      ),
                                      child: Icon(Icons.location_on_rounded,
                                          color: accent, size: 22),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: TranslatedText(fav.name,
                                            style: GoogleFonts.dmSans(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700),
                                            overflow: TextOverflow.ellipsis)),
                                    Icon(Icons.chevron_right_rounded,
                                        color: accent.withOpacity(0.6),
                                        size: 20),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, WeatherConditionTheme condTheme,
      Color accent, TimeTheme tt) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                // TimeTheme cardBg for the empty-state icon container
                color: tt.cardBg,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: accent.withOpacity(0.35)),
              ),
              child: Icon(Icons.star_outline_rounded, color: accent, size: 44),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TranslatedText(AppStrings.noFavorites,
            style: GoogleFonts.dmSans(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TranslatedText(AppStrings.addFavoritesHint,
            style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => _openSearchAndAdd(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  // TimeTheme sheetGrad1 tint for the CTA button
                  color: tt.sheetGrad1.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: accent.withOpacity(0.40)),
                  boxShadow: [
                    BoxShadow(
                        color: accent.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_location_alt_outlined, color: accent, size: 18),
                  const SizedBox(width: 8),
                  TranslatedText(AppStrings.addLocation,
                      style: GoogleFonts.dmSans(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIME-OF-DAY BADGE — small indicator showing current period
// Now uses TimeTheme for its container background
// ─────────────────────────────────────────────────────────────────────────────
class _TimeOfDayBadge extends StatelessWidget {
  final int hour;
  final Color accent;
  final TimeTheme tt;
  const _TimeOfDayBadge({
    required this.hour,
    required this.accent,
    required this.tt,
  });

  String get _label {
    if (hour >= 5  && hour < 8)  return '🌅 Dawn';
    if (hour >= 8  && hour < 12) return '☀️ Morning';
    if (hour >= 12 && hour < 17) return '🌤 Afternoon';
    if (hour >= 17 && hour < 19) return '🌇 Dusk';
    if (hour >= 19 && hour < 21) return '🌆 Evening';
    return '🌙 Night';
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 600),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      // TimeTheme cardBg for the badge background, accent for the border
      color: tt.cardBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: tt.divider),
    ),
    child: Text(_label,
        style: GoogleFonts.dmSans(
            color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}