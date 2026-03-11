// lib/providers/app_providers.dart
//
// ✅ SettingsProvider.setLanguage() now calls TranslatorService.setLanguage()
//    which internally fires TranslatorService.notifier.changed() — this causes
//    ALL TranslatedText / WithTranslation / ScreenTranslator widgets across
//    every screen to rebuild simultaneously.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_model.dart';
import '../services/translator_service.dart';

// ─── SETTINGS PROVIDER ────────────────────────────────────────────────────────
class SettingsProvider extends ChangeNotifier {
  String _languageCode = 'en';
  String get languageCode => _languageCode;

  SettingsProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('language_code') ?? 'en';
      await TranslatorService.init(saved);
      if (saved != _languageCode) {
        _languageCode = saved;
        notifyListeners();
      }
    } catch (_) {
      await TranslatorService.init('en');
    }
  }

  /// Change language: persists to SharedPrefs, updates TranslatorService
  /// (which fires LanguageNotifier → all TranslatedText widgets rebuild),
  /// and notifyListeners() for any Consumer<SettingsProvider> widgets.
  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    // This clears cache AND fires TranslatorService.notifier.changed()
    await TranslatorService.setLanguage(code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', code);
    } catch (_) {}
    notifyListeners();
  }

  /// Alias used by Login screen dropdown
  Future<void> onLanguageChanged(String code) => setLanguage(code);
}

// ─── FAVORITES PROVIDER ───────────────────────────────────────────────────────
class FavoritesProvider extends ChangeNotifier {
  static const String _storageKey  = 'favorites_list';
  static const int    maxFavorites = 5;

  final List<FavoriteLocation> _favorites = [];
  List<FavoriteLocation> get favorites => List.unmodifiable(_favorites);
  bool get isFull => _favorites.length >= maxFavorites;

  Future<void> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List decoded = json.decode(raw) as List;
        _favorites.clear();
        _favorites.addAll(
          decoded.map((e) => FavoriteLocation.fromJson(e as Map<String, dynamic>)),
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final encoded = json.encode(_favorites.map((f) => f.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  Future<bool> addFavorite(FavoriteLocation location) async {
    if (_favorites.length >= maxFavorites) return false;
    final exists = _favorites.any(
          (f) => f.latitude == location.latitude && f.longitude == location.longitude,
    );
    if (!exists) {
      _favorites.add(location);
      notifyListeners();
      await _save();
      return true;
    }
    return false;
  }

  Future<void> removeFavorite(double lat, double lon) async {
    _favorites.removeWhere((f) => f.latitude == lat && f.longitude == lon);
    notifyListeners();
    await _save();
  }
}