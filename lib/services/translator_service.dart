// lib/services/translator_service.dart
//
// ✅ Google Translate free endpoint — no package needed (uses http).
// ✅ Batch translate: send multiple strings in one HTTP request.
// ✅ LanguageNotifier: a ChangeNotifier that fires whenever language changes,
//    allowing any widget to rebuild via Consumer<LanguageNotifier>.
// ✅ Persistence is owned by SettingsProvider (key: 'language_code').
//    TranslatorService just holds in-memory state + cache.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ── LanguageNotifier ──────────────────────────────────────────────────────────
// Register this as a provider in main.dart so ANY widget can rebuild on change:
//   ChangeNotifierProvider.value(value: TranslatorService.notifier)
class LanguageNotifier extends ChangeNotifier {
  void changed() => notifyListeners();
}

// ── TranslatorService ─────────────────────────────────────────────────────────
class TranslatorService {
  static String _langCode = 'en';
  static final Map<String, String> _cache = {};
  static final LanguageNotifier notifier = LanguageNotifier();

  // ── Supported languages ────────────────────────────────────────────────────
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English',    'native': 'English'},
    {'code': 'hi', 'name': 'Hindi',      'native': 'हिन्दी'},
    {'code': 'bn', 'name': 'Bengali',    'native': 'বাংলা'},
    {'code': 'te', 'name': 'Telugu',     'native': 'తెలుగు'},
    {'code': 'mr', 'name': 'Marathi',    'native': 'मराठी'},
    {'code': 'ta', 'name': 'Tamil',      'native': 'தமிழ்'},
    {'code': 'gu', 'name': 'Gujarati',   'native': 'ગુજરાતી'},
    {'code': 'kn', 'name': 'Kannada',    'native': 'ಕನ್ನಡ'},
    {'code': 'ml', 'name': 'Malayalam',  'native': 'മലയാളം'},
    {'code': 'pa', 'name': 'Punjabi',    'native': 'ਪੰਜਾਬੀ'},
    {'code': 'ur', 'name': 'Urdu',       'native': 'اردو'},
    {'code': 'or', 'name': 'Odia',       'native': 'ଓଡ଼ିଆ'},
    {'code': 'as', 'name': 'Assamese',   'native': 'অসমীয়া'},
    {'code': 'ar', 'name': 'Arabic',     'native': 'العربية'},
    {'code': 'fr', 'name': 'French',     'native': 'Français'},
    {'code': 'es', 'name': 'Spanish',    'native': 'Español'},
    {'code': 'zh', 'name': 'Chinese',    'native': '中文'},
    {'code': 'ja', 'name': 'Japanese',   'native': '日本語'},
    {'code': 'ko', 'name': 'Korean',     'native': '한국어'},
    {'code': 'ru', 'name': 'Russian',    'native': 'Русский'},
    {'code': 'de', 'name': 'German',     'native': 'Deutsch'},
    {'code': 'pt', 'name': 'Portuguese', 'native': 'Português'},
    {'code': 'it', 'name': 'Italian',    'native': 'Italiano'},
    {'code': 'tr', 'name': 'Turkish',    'native': 'Türkçe'},
    {'code': 'vi', 'name': 'Vietnamese', 'native': 'Tiếng Việt'},
    {'code': 'th', 'name': 'Thai',       'native': 'ภาษาไทย'},
    {'code': 'id', 'name': 'Indonesian', 'native': 'Bahasa Indonesia'},
    {'code': 'ms', 'name': 'Malay',      'native': 'Bahasa Melayu'},
    {'code': 'ne', 'name': 'Nepali',     'native': 'नेपाली'},
    {'code': 'si', 'name': 'Sinhala',    'native': 'සිංහල'},
  ];

  static String get languageCode => _langCode;
  static bool get isEnglish => _langCode == 'en';

  static String? getNativeName(String code) => supportedLanguages
      .firstWhere((l) => l['code'] == code, orElse: () => {'native': code})['native'];

  static String? getDisplayName(String code) => supportedLanguages
      .firstWhere((l) => l['code'] == code, orElse: () => {'name': code})['name'];

  // ── init — called by SettingsProvider after reading SharedPrefs ────────────
  static Future<void> init(String langCode) async {
    _langCode = langCode;
    _cache.clear();
  }

  // ── setLanguage — called by SettingsProvider.setLanguage() ─────────────────
  static Future<void> setLanguage(String code) async {
    if (_langCode == code) return;
    _langCode = code;
    _cache.clear();
    notifier.changed(); // notify all AutoTranslate / TranslatedText widgets
  }

  // ── translate single string (async, cached) ────────────────────────────────
  static Future<String> translate(String text) async {
    if (_langCode == 'en' || text.trim().isEmpty) return text;
    final key = '${_langCode}_$text';
    if (_cache.containsKey(key)) return _cache[key]!;
    try {
      final results = await translateBatch([text]);
      return results.isNotEmpty ? results[0] : text;
    } catch (_) {
      return text;
    }
  }

  // ── translateBatch — translate multiple strings in ONE HTTP call ───────────
  // Returns list of translated strings in same order as input.
  static Future<List<String>> translateBatch(List<String> texts) async {
    if (_langCode == 'en' || texts.isEmpty) return texts;

    // Split into cached vs uncached
    final toFetch = <int, String>{};
    final results = List<String>.from(texts);

    for (int i = 0; i < texts.length; i++) {
      final t = texts[i];
      if (t.trim().isEmpty) continue;
      final key = '${_langCode}_$t';
      if (_cache.containsKey(key)) {
        results[i] = _cache[key]!;
      } else {
        toFetch[i] = t;
      }
    }

    if (toFetch.isEmpty) return results;

    // Google Translate: join with \n separator, split result by \n
    // This is a well-known trick to batch-translate multiple strings in one call.
    final combined = toFetch.values.join('\n');
    try {
      final encoded = Uri.encodeComponent(combined);
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
            '?client=gtx&sl=en&tl=$_langCode&dt=t&q=$encoded',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final buffer = StringBuffer();
        for (final part in decoded[0] as List) {
          if (part[0] != null) buffer.write(part[0]);
        }
        final translatedCombined = buffer.toString().trim();
        final translatedParts = translatedCombined.split('\n');

        final indices = toFetch.keys.toList();
        for (int j = 0; j < indices.length; j++) {
          final origIdx = indices[j];
          final orig    = toFetch[origIdx]!;
          final trans   = j < translatedParts.length
              ? translatedParts[j].trim()
              : orig;
          if (trans.isNotEmpty) {
            _cache['${_langCode}_$orig'] = trans;
            results[origIdx] = trans;
          }
        }
      }
    } catch (_) {
      // network failure — return originals
    }
    return results;
  }

  // ── translateSync — returns cached value or original (no network) ──────────
  static String translateSync(String text) {
    if (_langCode == 'en' || text.isEmpty) return text;
    return _cache['${_langCode}_$text'] ?? text;
  }

  // ── preloadStrings — call this at screen init to warm the cache ────────────
  static Future<void> preloadStrings(List<String> strings) async {
    if (_langCode == 'en') return;
    final uncached = strings
        .where((s) => s.isNotEmpty && !_cache.containsKey('${_langCode}_$s'))
        .toList();
    if (uncached.isNotEmpty) await translateBatch(uncached);
  }
}