// lib/utils/translated_text.dart
//
// ✅ TranslatedText   — drop-in Text replacement. Listens to LanguageNotifier.
// ✅ WithTranslation  — builder widget for hint/label strings (e.g. TextField).
// ✅ AutoTranslateScreen — mixin for StatefulWidget screens: preloads all strings
//    at initState, rebuilds on language change. Use with _screenStrings list.
// ✅ T(context, text) — synchronous helper that returns cached translation or
//    schedules async fetch + rebuild. Use for strings inside build() methods.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/translator_service.dart';

// ─── TranslatedText ───────────────────────────────────────────────────────────

class TranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const TranslatedText(
      this.text, {
        super.key,
        this.style,
        this.textAlign,
        this.maxLines,
        this.overflow,
        this.softWrap,
      });

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  String _display = '';
  String _lastLang = '';
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _display = widget.text;
    _translate();
    // Listen to language changes globally
    TranslatorService.notifier.addListener(_onLangChange);
  }

  @override
  void dispose() {
    TranslatorService.notifier.removeListener(_onLangChange);
    super.dispose();
  }

  void _onLangChange() => _translate();

  @override
  void didUpdateWidget(TranslatedText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _translate();
  }

  Future<void> _translate() async {
    final lang = TranslatorService.languageCode;
    final result = await TranslatorService.translate(widget.text);
    if (mounted) {
      setState(() {
        _display  = result;
        _lastLang = lang;
        _lastText = widget.text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Trigger re-translate if lang or text changed since last build
    if (_lastLang != TranslatorService.languageCode ||
        _lastText != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _translate();
      });
    }
    return Text(
      _display.isEmpty ? widget.text : _display,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      softWrap: widget.softWrap,
    );
  }
}

// ─── WithTranslation ──────────────────────────────────────────────────────────
// For cases where you need the translated String directly (e.g. TextField hint).
//
// Usage:
//   WithTranslation(
//     text: 'Search city...',
//     builder: (hint) => TextField(decoration: InputDecoration(hintText: hint)),
//   )

class WithTranslation extends StatefulWidget {
  final String text;
  final Widget Function(String translated) builder;
  const WithTranslation({super.key, required this.text, required this.builder});

  @override
  State<WithTranslation> createState() => _WithTranslationState();
}

class _WithTranslationState extends State<WithTranslation> {
  String _translated = '';

  @override
  void initState() {
    super.initState();
    _translated = widget.text;
    _translate();
    TranslatorService.notifier.addListener(_translate);
  }

  @override
  void dispose() {
    TranslatorService.notifier.removeListener(_translate);
    super.dispose();
  }

  @override
  void didUpdateWidget(WithTranslation old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _translate();
  }

  Future<void> _translate() async {
    final result = await TranslatorService.translate(widget.text);
    if (mounted) setState(() => _translated = result);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_translated.isEmpty ? widget.text : _translated);
}

// ─── ScreenTranslator ─────────────────────────────────────────────────────────
// Wraps a screen's build output. Preloads a list of strings once and rebuilds
// the entire subtree whenever the language changes.
//
// Usage in a StatelessWidget screen:
//   @override
//   Widget build(BuildContext context) {
//     return ScreenTranslator(
//       strings: ['Forecast', 'Temperature', 'Wind', ...],
//       builder: (context) => Scaffold(...),
//     );
//   }

class ScreenTranslator extends StatefulWidget {
  final List<String> strings;
  final WidgetBuilder builder;
  const ScreenTranslator({
    super.key,
    required this.strings,
    required this.builder,
  });

  @override
  State<ScreenTranslator> createState() => _ScreenTranslatorState();
}

class _ScreenTranslatorState extends State<ScreenTranslator> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _preload();
    TranslatorService.notifier.addListener(_onLangChange);
  }

  @override
  void dispose() {
    TranslatorService.notifier.removeListener(_onLangChange);
    super.dispose();
  }

  Future<void> _preload() async {
    await TranslatorService.preloadStrings(widget.strings);
    if (mounted) setState(() => _ready = true);
  }

  void _onLangChange() async {
    setState(() => _ready = false);
    await TranslatorService.preloadStrings(widget.strings);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

// ─── tl() helper ─────────────────────────────────────────────────────────────
// Synchronous translation helper for use inside build() methods.
// Returns cached translation instantly, or returns original while async fetch
// runs in background (triggering setState on completion via TranslatedText).
//
// For best results, call TranslatorService.preloadStrings([...]) in initState
// so all strings are cached before build() runs.
//
// Usage:  Text(tl('Temperature'))
String tl(String text) => TranslatorService.translateSync(text);