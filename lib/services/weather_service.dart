// lib/services/weather_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_model.dart';

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const String _appId  = '921155810533297639420383389872';
  static const _timeout       = Duration(seconds: 45);

  static _CacheEntry? _memCache;
  static const _prefixData    = 'wx_data_';
  static const _prefixTime    = 'wx_time_';

  // ─────────────────────────────────────────────────────────────────────────
  // DATE HELPER
  // ─────────────────────────────────────────────────────────────────────────
  String _fmtDate(DateTime d) =>
      '${d.year}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  // ─────────────────────────────────────────────────────────────────────────
  // URL STRATEGY
  // ─────────────────────────────────────────────────────────────────────────
  List<String> _buildUrls(double lat, double lon) {
    final urls   = <String>[];
    final utcNow = DateTime.now().toUtc();

    for (int daysBack = 0; daysBack <= 2; daysBack++) {
      final base    = DateTime.utc(utcNow.year, utcNow.month, utcNow.day)
          .subtract(Duration(days: daysBack));
      final dateStr = _fmtDate(base);

      // ✅ FIX: Snap to nearest past NWP run: 00, 06, 12, 18 UTC
      // NCMRWF only publishes at these 4 fixed UTC times.
      // Passing any other hour returns the same previous run anyway,
      // so we snap explicitly so cur['time'] reflects the correct run.
      int snappedHour = 0;
      if (daysBack == 0) {
        final h = utcNow.hour;
        if (h >= 18)      snappedHour = 18;
        else if (h >= 12) snappedHour = 12;
        else if (h >= 6)  snappedHour = 6;
        else              snappedHour = 0;
      }
      final currentHour = snappedHour.toString().padLeft(2, '0');
      final timeStr = '${dateStr}T$currentHour:00:00';

      urls.add(
        'https://api.ncmrwf.gov.in/appapi/'
            '?coords=${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}'
            '&odate=$dateStr'
            '&time=$timeStr'
            '&appid=$_appId',
      );
      debugPrint('[WeatherService] URL-$daysBack: odate=$dateStr time=$timeStr');
    }
    return urls;
  }

  // ── Persistent cache ──────────────────────────────────────────────────────
  Future<void> _saveToPrefs(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefixData + key, json.encode(data));
      await prefs.setString(_prefixTime + key, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[WeatherService] Prefs save error: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadFromPrefs(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_prefixData + key);
      if (raw == null) return null;
      return json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[WeatherService] Prefs load error: $e');
      return null;
    }
  }

  Future<void> _clearPrefs(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefixData + key);
      await prefs.remove(_prefixTime + key);
      debugPrint('[WeatherService] Cleared stale disk cache for $key');
    } catch (_) {}
  }

  // ── Single HTTP GET ───────────────────────────────────────────────────────
  Future<http.Response?> _get(String url) async {
    try {
      return await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(_timeout);
    } on SocketException {
      throw Exception('No internet connection.\nCheck your mobile data or Wi-Fi.');
    } on TimeoutException {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CORE FETCH
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _fetchRaw(double lat, double lon) async {
    final cacheKey = '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';

    // ✅ FIX: Bust cache when NWP run slot changes (00, 06, 12, 18 UTC)
    // This ensures when NCMRWF publishes a new model run,
    // the app fetches fresh data and cur['time'] updates correctly.
    if (_memCache != null && _memCache!.key == cacheKey) {
      final cachedHour = _memCache!.fetchedAt.toUtc().hour;
      final nowHour    = DateTime.now().toUtc().hour;
      int snap(int h) => h >= 18 ? 18 : h >= 12 ? 12 : h >= 6 ? 6 : 0;
      if (snap(cachedHour) != snap(nowHour)) {
        debugPrint('[WeatherService] NWP run slot changed '
            '${snap(cachedHour)}→${snap(nowHour)} UTC — busting cache');
        _memCache = null;
      }
    }

    // Memory cache — valid for 60 minutes only
    if (_memCache != null &&
        _memCache!.key == cacheKey &&
        DateTime.now().difference(_memCache!.fetchedAt).inMinutes < 60) {
      debugPrint('[WeatherService] ✅ Memory cache hit');
      return _memCache!.data;
    }

    final urls      = _buildUrls(lat, lon);
    bool noInternet  = false;
    String lastError = 'No response';

    Map<String, dynamic>? bestFallback;

    for (int urlIdx = 0; urlIdx < urls.length; urlIdx++) {
      final url   = urls[urlIdx];
      final label = 'URL-$urlIdx';

      for (int attempt = 0; attempt <= 2; attempt++) {
        if (attempt > 0) {
          final wait = [5, 15][attempt - 1];
          debugPrint('[WeatherService] Retry $attempt for $label in ${wait}s');
          await Future.delayed(Duration(seconds: wait));
        }

        debugPrint('[WeatherService] → $label attempt ${attempt + 1}');

        http.Response? res;
        try {
          res = await _get(url);
        } catch (e) {
          noInternet = true;
          lastError  = e.toString();
          break;
        }

        if (res == null) {
          lastError = 'Timeout ($label)';
          if (attempt < 2) continue;
          break;
        }

        debugPrint('[WeatherService] HTTP ${res.statusCode} ← $label');

        if (res.statusCode == 503 || res.statusCode == 502 || res.statusCode == 500) {
          lastError = 'Server ${res.statusCode} ($label)';
          if (attempt < 2) continue;
          break;
        }

        if (res.statusCode == 404) { lastError = '404 ($label)'; break; }
        if (res.statusCode != 200) { lastError = 'HTTP ${res.statusCode}'; break; }

        Map<String, dynamic> data;
        try {
          data = json.decode(res.body) as Map<String, dynamic>;
        } catch (_) {
          lastError = 'Bad JSON ($label)';
          continue;
        }

        if (!data.containsKey('current')) {
          lastError = 'Missing current ($label)';
          continue;
        }

        bestFallback ??= data;

        final v = _validate(data);
        debugPrint('[WeatherService] $label → $v');

        if (!v.isValid) {
          lastError = '${v.reason} ($label)';
          debugPrint('[WeatherService] ⚠️ $label failed validation — keeping as fallback');
          break;
        }

        await _clearPrefs(cacheKey);
        _memCache = _CacheEntry(key: cacheKey, data: data, fetchedAt: DateTime.now());
        await _saveToPrefs(cacheKey, data);
        debugPrint('[WeatherService] ✅ Success: $label | ${v.totalSlots} slots | next: ${v.nextSlot}');
        return data;
      }

      if (noInternet) break;
    }

    if (bestFallback != null) {
      debugPrint('[WeatherService] ⚠️ Using best fallback data (validation failed but data exists)');
      await _clearPrefs(cacheKey);
      _memCache = _CacheEntry(key: cacheKey, data: bestFallback!, fetchedAt: DateTime.now());
      await _saveToPrefs(cacheKey, bestFallback!);
      return bestFallback!;
    }

    if (noInternet) {
      final stale = await _loadFromPrefs(cacheKey);
      if (stale != null && stale.containsKey('current')) {
        debugPrint('[WeatherService] ⚠️ Offline — serving disk cache');
        _memCache       = _CacheEntry(key: cacheKey, data: stale, fetchedAt: DateTime.now());
        stale['_stale'] = true;
        return stale;
      }
      throw Exception('No internet connection.\nCheck your mobile data or Wi-Fi.');
    }

    throw Exception(
        'NCMRWF server unavailable.\nLast error: $lastError\nPlease retry in a few minutes.');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VALIDATE
  // ─────────────────────────────────────────────────────────────────────────
  _ValidationResult _validate(Map<String, dynamic> data) {
    final hourly = data['hourly'] as List?;
    if (hourly == null || hourly.isEmpty) {
      return const _ValidationResult(false, 'hourly list empty', 0, null);
    }

    final now    = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 2));

    debugPrint('[WeatherService] ── Hourly dump (${hourly.length} slots) ──'
        ' now=${now.hour}:${now.minute.toString().padLeft(2,'0')} IST');

    if (hourly.isNotEmpty) {
      final first = hourly[0] as Map<String, dynamic>;
      final windRaw  = first['wind_speed']    ?? first['windspeed']         ?? first['wind_spd']         ?? 'KEY_NOT_FOUND';
      final humRaw   = first['humidity']      ?? first['relative_humidity'] ?? 'KEY_NOT_FOUND';
      final wDirRaw  = first['wind_direction'] ?? 'KEY_NOT_FOUND';
      debugPrint('[WeatherService] ── WIND/HUMIDITY KEY CHECK ──');
      debugPrint('[WeatherService]   wind_speed  → $windRaw');
      debugPrint('[WeatherService]   humidity    → $humRaw');
      debugPrint('[WeatherService]   wind_dir    → $wDirRaw');
      debugPrint('[WeatherService]   all keys    → ${first.keys.toList()}');
    }

    String? nextSlot;
    bool    found = false;

    for (final raw in hourly) {
      final m     = raw as Map<String, dynamic>;
      final dtRaw = (m['time'] ?? m['datetime'] ?? m['dt'] ?? '').toString();
      final dt    = DateTime.tryParse(dtRaw)?.toLocal()
          ?? DateTime.tryParse('${dtRaw}Z')?.toLocal();
      if (dt == null) continue;

      final temp  = m['temperature'] ?? m['temp_c'] ?? m['temp'] ?? '?';
      final wind  = m['wind_speed']  ?? m['windspeed'] ?? m['wind_spd'] ?? '?';
      final hum   = m['humidity']    ?? m['relative_humidity'] ?? '?';
      debugPrint('[WeatherService]   '
          '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} '
          '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')} IST'
          ' → ${temp}°C | wind=${wind} | hum=${hum}%');

      if (dt.isAfter(cutoff)) {
        found    = true;
        nextSlot ??= '${dt.hour}:${dt.minute.toString().padLeft(2,'0')}';
      }
    }

    if (!found) {
      return _ValidationResult(
          false,
          'all ${hourly.length} slots are before ${cutoff.hour}:${cutoff.minute.toString().padLeft(2,'0')} IST',
          hourly.length,
          null);
    }

    return _ValidationResult(true, 'ok', hourly.length, nextSlot);
  }

  // ── Public API ────────────────────────────────────────────────────────────
  Future<CurrentWeather> getCurrentWeather({
    required double lat, required double lon,
  }) async {
    final data = await _fetchRaw(lat, lon);
    return CurrentWeather.fromNcmrwfJson(data);
  }

  Future<List<DayForecast>> getForecast({
    required double lat, required double lon, int days = 10,
  }) async {
    final data  = await _fetchRaw(lat, lon);
    final daily = data['daily'] as List? ?? [];
    return daily
        .take(days)
        .map((e) => DayForecast.fromNcmrwfJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<HourlyWeather>> getHourly({
    required double lat, required double lon,
  }) async {
    final data   = await _fetchRaw(lat, lon);
    final hourly = data['hourly'] as List? ?? [];
    return hourly
        .map((e) => HourlyWeather.fromNcmrwfJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getTrend({
    required double lat, required double lon,
  }) async {
    final data     = await _fetchRaw(lat, lon);
    final daily    = data['daily'] as List? ?? [];
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final trend = daily.map((e) {
      final m    = e as Map<String, dynamic>;
      final dStr = m['date'] as String? ?? '';
      final dt   = DateTime.tryParse(dStr);
      final tMin = (m['temp_min'] as num?)?.toDouble() ?? 0.0;
      final tMax = (m['temp_max'] as num?)?.toDouble() ?? 0.0;
      return {
        'day'          : dt != null ? dayNames[dt.weekday - 1] : dStr,
        'date'         : dStr,
        'temperature_c': (tMin + tMax) / 2.0,
      };
    }).toList();

    double minT = double.infinity, maxT = double.negativeInfinity;
    for (final d in daily) {
      final m  = d as Map<String, dynamic>;
      final mn = (m['temp_min'] as num?)?.toDouble() ?? 0.0;
      final mx = (m['temp_max'] as num?)?.toDouble() ?? 0.0;
      if (mn < minT) minT = mn;
      if (mx > maxT) maxT = mx;
    }

    return {
      'trend'   : trend,
      'min_temp': minT == double.infinity         ? 0.0  : minT,
      'max_temp': maxT == double.negativeInfinity ? 40.0 : maxT,
    };
  }

  bool get isUsingStaleCache => _memCache?.data['_stale'] == true;
  static void clearCache()   => _memCache = null;
}

// ─────────────────────────────────────────────────────────────────────────────
class _CacheEntry {
  final String               key;
  final Map<String, dynamic> data;
  final DateTime             fetchedAt;
  const _CacheEntry({required this.key, required this.data, required this.fetchedAt});
}

class _ValidationResult {
  final bool    isValid;
  final String  reason;
  final int     totalSlots;
  final String? nextSlot;
  const _ValidationResult(this.isValid, this.reason, this.totalSlots, this.nextSlot);
  @override
  String toString() => 'valid=$isValid | $reason | slots=$totalSlots | next=$nextSlot';
}