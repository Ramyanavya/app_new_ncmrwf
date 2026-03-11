import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_providers.dart';
import '../services/translator_service.dart';
import '../utils/app_strings.dart';
import '../utils/time_theme.dart'; // ← NEW

// ─────────────────────────────────────────────────────────────────────────────
// Frosted card — tint driven by TimeTheme accent
// ─────────────────────────────────────────────────────────────────────────────
class _FrostCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  const _FrostCard({
    required this.child,
    this.padding = const EdgeInsets.all(0),
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final tt = TimeTheme.of();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: tt.cardBg,
        border: Border.all(color: Colors.white.withOpacity(0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: tt.bgGradient.last.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _SettingsBody();
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {

  // ── grab once so the whole screen uses the same period ──────────────────
  final TimeTheme _tt = TimeTheme.of();

  void _showAboutSheet() => _showContentSheet(
      title: AppStrings.aboutApp, content: AppStrings.aboutContent,
      icon: Icons.info_outline_rounded);

  void _showPrivacySheet() => _showContentSheet(
      title: AppStrings.privacy, content: AppStrings.privacyContent,
      icon: Icons.privacy_tip_outlined);

  void _showDataSourceSheet() => _showContentSheet(
      title: AppStrings.dataSourceTitle, content: AppStrings.dataSourceDesc,
      icon: Icons.cloud_outlined);

  void _showContentSheet({
    required String title,
    required String content,
    required IconData icon,
  }) {
    final tt = _tt;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(
        tt: tt,
        child: DraggableScrollableSheet(
          initialChildSize: 0.55, minChildSize: 0.35, maxChildSize: 0.92,
          expand: false,
          builder: (_, sc) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Center(child: _DragHandle()),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.20),
                      border: Border.all(color: Colors.white.withOpacity(0.50), width: 1),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: TranslatorService.translate(title),
                      initialData: title,
                      builder: (_, s) => Text(s.data ?? title,
                          style: GoogleFonts.dmSans(
                              fontSize: 18, fontWeight: FontWeight.w700,
                              color: Colors.white),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Divider(color: Colors.white.withOpacity(0.30), height: 16),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
                  child: FutureBuilder<String>(
                    future: TranslatorService.translate(content),
                    initialData: content,
                    builder: (_, s) => Text(s.data ?? content,
                        style: GoogleFonts.dmSans(
                            fontSize: 14, height: 1.75,
                            color: Colors.white.withOpacity(0.92))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFaqSheet() {
    final tt = _tt;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(
        tt: tt,
        child: DraggableScrollableSheet(
          initialChildSize: 0.65, minChildSize: 0.45, maxChildSize: 0.95,
          expand: false,
          builder: (_, sc) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Center(child: _DragHandle()),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.20),
                      border: Border.all(color: Colors.white.withOpacity(0.50), width: 1),
                    ),
                    child: const Icon(Icons.help_outline_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: TranslatorService.translate(AppStrings.faqsSub),
                      initialData: AppStrings.faqsSub,
                      builder: (_, s) => Text(s.data ?? AppStrings.faqsSub,
                          style: GoogleFonts.dmSans(
                              fontSize: 17, fontWeight: FontWeight.w700,
                              color: Colors.white),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Divider(color: Colors.white.withOpacity(0.30), height: 14),
              ),
              Expanded(
                child: ListView.separated(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
                  itemCount: AppStrings.faqList.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.white.withOpacity(0.20), height: 28),
                  itemBuilder: (_, i) {
                    final faq = AppStrings.faqList[i];
                    return _FaqItem(q: faq['q'] ?? '', a: faq['a'] ?? '');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _googleFormUrl = 'https://forms.gle/bBU479dr1r3qwUdA7';

  Future<void> _showFeedbackSheet() async {
    final uri = Uri.parse(_googleFormUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open the feedback form.',
            style: GoogleFonts.dmSans(color: Colors.white)),
        backgroundColor: _tt.bgGradient.last,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _onLanguageChanged(String? code) async {
    if (code == null) return;
    await context.read<SettingsProvider>().onLanguageChanged(code);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tt = _tt;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: tt.statusBar,
      statusBarIconBrightness: Brightness.light,
    ));

    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: tt.bgGradient.first,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: tt.appBarBg,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.25),
              border: Border.all(color: Colors.white.withOpacity(0.50)),
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
          ),
        ),
        title: Text(AppStrings.settings,
            style: GoogleFonts.dmSans(
                fontSize: 20, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: 0.2)),
      ),
      body: Stack(children: [
        // ── Time-aware background ──────────────────────────────────────────
        Container(decoration: BoxDecoration(gradient: tt.linearGradient)),

        // ── Subtle radial scatter ──────────────────────────────────────────
        Positioned(
          top: -60, right: -40,
          child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Colors.white.withOpacity(0.10),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        // ── Star/moon scatter for night ────────────────────────────────────
        if (tt.periodLabel == 'Night') ..._nightParticles(),

        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            physics: const BouncingScrollPhysics(),
            children: [

              // ── Period badge ─────────────────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withOpacity(0.12),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_periodIcon(tt.periodLabel),
                        size: 12, color: tt.accent),
                    const SizedBox(width: 5),
                    Text(tt.periodLabel,
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: Colors.white.withOpacity(0.80),
                            fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  ]),
                ),
              ),

              _SectionLabel('Language', accent: tt.accent),
              const SizedBox(height: 10),
              _FrostCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.28),
                        border: Border.all(color: Colors.white.withOpacity(0.60)),
                      ),
                      child: const Icon(Icons.language, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: settings.languageCode,
                          dropdownColor: tt.bgGradient[1],
                          style: GoogleFonts.dmSans(
                              color: Colors.white, fontSize: 14,
                              fontWeight: FontWeight.w600),
                          iconEnabledColor: Colors.white,
                          isExpanded: true,
                          items: TranslatorService.supportedLanguages.map((lang) {
                            return DropdownMenuItem<String>(
                              value: lang['code'],
                              child: Text(
                                '${lang['native']}  (${lang['name']})',
                                style: GoogleFonts.dmSans(
                                    color: Colors.white, fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                            );
                          }).toList(),
                          onChanged: _onLanguageChanged,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 26),

              _SectionLabel('Information', accent: tt.accent),
              const SizedBox(height: 10),
              _FrostCard(
                child: Column(children: [
                  _InfoTile(icon: Icons.info_outline_rounded,
                      label: AppStrings.aboutApp,
                      onTap: _showAboutSheet, isFirst: true),
                  _TileDivider(),
                  _InfoTile(icon: Icons.help_outline_rounded,
                      label: AppStrings.faqs, onTap: _showFaqSheet),
                  _TileDivider(),
                  _InfoTile(icon: Icons.privacy_tip_outlined,
                      label: AppStrings.privacy, onTap: _showPrivacySheet),
                  _TileDivider(),
                  _InfoTile(icon: Icons.cloud_outlined,
                      label: AppStrings.dataSource,
                      onTap: _showDataSourceSheet, isLast: true),
                ]),
              ),

              const SizedBox(height: 26),

              _SectionLabel('Feedback', accent: tt.accent),
              const SizedBox(height: 10),
              _FrostCard(
                child: _InfoTile(
                  icon: Icons.rate_review_outlined,
                  label: 'Send Feedback',
                  onTap: _showFeedbackSheet,
                  isFirst: true,
                  isLast: true,
                  accentColor: tt.accent,
                ),
              ),

              const SizedBox(height: 40),

              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white.withOpacity(0.18),
                    border: Border.all(color: Colors.white.withOpacity(0.40), width: 1),
                  ),
                  child: Text(
                    '${AppStrings.appName}  ·  ${AppStrings.aboutVersion}',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500, letterSpacing: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  IconData _periodIcon(String label) {
    switch (label) {
      case 'Dawn':  return Icons.wb_twilight_rounded;
      case 'Dusk':  return Icons.wb_twilight_rounded;
      case 'Night': return Icons.nightlight_round;
      default:      return Icons.wb_sunny_rounded;
    }
  }

  List<Widget> _nightParticles() => [
    Positioned(top: 60,  right: 50,  child: _Star(size: 3, opacity: 0.70)),
    Positioned(top: 100, right: 120, child: _Star(size: 2, opacity: 0.50)),
    Positioned(top: 80,  left: 80,   child: _Star(size: 2, opacity: 0.60)),
    Positioned(top: 150, left: 160,  child: _Star(size: 3, opacity: 0.55)),
    Positioned(top: 40,  left: 200,  child: _Star(size: 2, opacity: 0.45)),
    Positioned(top: 200, right: 60,  child: _Star(size: 2, opacity: 0.40)),
  ];
}

// ── tiny star dot for night ────────────────────────────────────────────────
class _Star extends StatelessWidget {
  final double size;
  final double opacity;
  const _Star({required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
      boxShadow: [BoxShadow(
          color: Colors.white.withOpacity(opacity * 0.6),
          blurRadius: 4)],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FAQ item
// ─────────────────────────────────────────────────────────────────────────────
class _FaqItem extends StatelessWidget {
  final String q, a;
  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.90),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: FutureBuilder<String>(
          future: TranslatorService.translate(q),
          initialData: q,
          builder: (_, s) => Text(s.data ?? q,
              style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Colors.white, height: 1.5)),
        )),
      ]),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.only(left: 17),
        child: FutureBuilder<String>(
          future: TranslatorService.translate(a),
          initialData: a,
          builder: (_, s) => Text(s.data ?? a,
              style: GoogleFonts.dmSans(
                  fontSize: 13, height: 1.7,
                  color: Colors.white.withOpacity(0.88))),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet wrapper — colours driven by TimeTheme
// ─────────────────────────────────────────────────────────────────────────────
class _SheetWrapper extends StatelessWidget {
  final Widget child;
  final TimeTheme tt;
  const _SheetWrapper({required this.child, required this.tt});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [tt.sheetGrad1, tt.sheetGrad2],
      ),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.40), width: 1.2)),
    ),
    child: child,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _DragHandle extends StatelessWidget {
  const _DragHandle();
  @override
  Widget build(BuildContext context) => Container(
      width: 44, height: 4,
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.50),
          borderRadius: BorderRadius.circular(2)));
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color accent;
  const _SectionLabel(this.label, {required this.accent});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 2),
    child: Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(
              color: accent, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 7),
      Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
            fontSize: 11, fontWeight: FontWeight.w800,
            color: Colors.white.withOpacity(0.80),
            letterSpacing: 1.4),
      ),
    ]),
  );
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 68, color: Colors.white.withOpacity(0.20));
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isFirst, isLast;
  final Color? accentColor;

  const _InfoTile({
    required this.icon, required this.label, required this.onTap,
    this.isFirst = false, this.isLast = false, this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = accentColor ?? Colors.white;
    final topR = isFirst ? const Radius.circular(20) : Radius.zero;
    final botR = isLast  ? const Radius.circular(20) : Radius.zero;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.only(
            topLeft: topR, topRight: topR,
            bottomLeft: botR, bottomRight: botR),
        splashColor: Colors.white.withOpacity(0.15),
        highlightColor: Colors.white.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withOpacity(accentColor != null ? 0.18 : 0.22),
                border: Border.all(
                    color: c.withOpacity(accentColor != null ? 0.50 : 0.55),
                    width: 1),
              ),
              child: Icon(icon, color: c, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: FutureBuilder<String>(
                future: TranslatorService.translate(label),
                initialData: label,
                builder: (_, s) => Text(s.data ?? label,
                    style: GoogleFonts.dmSans(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
              child: Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.80), size: 18),
            ),
          ]),
        ),
      ),
    );
  }
}