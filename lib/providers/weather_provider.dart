// lib/providers/weather_provider.dart
//
// ✅ FIX: initAndRefresh() no longer calls initFromCache() internally.
// ✅ FIX: Removed locationKey gate — alert fires on every fetch.
// ✅ FIX: Now calls WeatherAlertService.checkAndSendLive() with
//    liveTemperatureC / liveWindSpeedKmh / liveRainMm so the temperature
//    shown in the notification matches the app display exactly.

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';
import '../services/local_notification_service.dart';
import '../services/weather_alert_service.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../widgets/weather_widget.dart';
import 'dart:convert' show jsonDecode;

enum WeatherStatus { initial, loading, loaded, error }

enum LocationFailReason {
  none,
  permissionDenied,
  permissionPermanentlyDenied,
  serviceDisabled,
  gpsFailed,
}

final _sharedHttpClient = http.Client();
final _coordValueCache  = <String, String>{};

const _kCachedLat   = 'wp_lat';
const _kCachedLon   = 'wp_lon';
const _kCachedPlace = 'wp_place';
const _kCachedTemp  = 'wp_temp';
const _kCachedCond  = 'wp_cond';

List<DayForecast> _parseForecast(String body) {
  try {
    final decoded = _decodeJson(body);
    if (decoded is List) {
      return decoded.map((e) => DayForecast.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (decoded is Map && decoded.containsKey('forecast')) {
      final list = decoded['forecast'] as List;
      return list.map((e) => DayForecast.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (e) { debugPrint('[parse] forecast error: $e'); }
  return [];
}

List<HourlyWeather> _parseHourly(String body) {
  try {
    final decoded = _decodeJson(body);
    if (decoded is List) {
      return decoded.map((e) => HourlyWeather.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (decoded is Map && decoded.containsKey('hourly')) {
      final list = decoded['hourly'] as List;
      return list.map((e) => HourlyWeather.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (e) { debugPrint('[parse] hourly error: $e'); }
  return [];
}

dynamic _decodeJson(String body) =>
    (body.isEmpty) ? <dynamic>[] : _jsonDecode(body);
dynamic _jsonDecode(String s) => jsonDecode(s);

String _localDateStr(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

// ─────────────────────────────────────────────────────────────────────────────
class WeatherProvider extends ChangeNotifier {
  final WeatherService  _weatherService  = WeatherService();
  final LocationService _locationService = LocationService();

  WeatherStatus       _status             = WeatherStatus.initial;
  CurrentWeather?     _currentWeather;
  List<DayForecast>   _forecast           = [];
  List<HourlyWeather> _hourly             = [];
  List<TrendPoint>    _trend              = [];
  double              _minTemp            = 0;
  double              _maxTemp            = 0;
  String              _errorMessage       = '';
  String              _placeName          = '';
  String              _loadingDetail      = '';
  bool                _usingStaleData     = false;
  double              _latitude           = 28.6139;
  double              _longitude          = 77.2090;
  LocationFailReason  _locationFailReason = LocationFailReason.none;
  bool                _silentRefreshing   = false;

  DateTime? _lastFetchTime;

  // ── Getters ────────────────────────────────────────────────────────────────
  WeatherStatus       get status             => _status;
  CurrentWeather?     get currentWeather     => _currentWeather;
  List<DayForecast>   get forecast           => _forecast;
  List<HourlyWeather> get hourly             => _hourly;
  List<TrendPoint>    get trend              => _trend;
  double              get minTemp            => _minTemp;
  double              get maxTemp            => _maxTemp;
  String              get errorMessage       => _errorMessage;
  String              get placeName          => _placeName;
  String              get loadingDetail      => _loadingDetail;
  bool                get usingStaleData     => _usingStaleData;
  double              get latitude           => _latitude;
  double              get longitude          => _longitude;
  LocationFailReason  get locationFailReason => _locationFailReason;
  bool                get silentRefreshing   => _silentRefreshing;

  // ── Hourly helpers ─────────────────────────────────────────────────────────
  HourlyWeather? _nearestHourly(DateTime target) {
    if (_hourly.isEmpty) return null;
    HourlyWeather? best;
    Duration bestDiff = const Duration(days: 9999);
    for (final h in _hourly) {
      final dt = DateTime.tryParse(h.datetime)?.toLocal();
      if (dt == null) continue;
      final diff = dt.difference(target).abs();
      if (diff < bestDiff) { bestDiff = diff; best = h; }
    }
    return best;
  }

  List<HourlyWeather> hourlyForDate(DateTime date) {
    final targetStr = _localDateStr(date);
    return _hourly.where((h) {
      final dt = DateTime.tryParse(h.datetime)?.toLocal();
      if (dt == null) return false;
      return _localDateStr(dt) == targetStr;
    }).toList();
  }

  // ── DIURNAL MODEL ──────────────────────────────────────────────────────────
  double _diurnalTempForHour(int hour) {
    final todayStr = _localDateStr(DateTime.now());
    DayForecast? todayFc;
    for (final df in _forecast) {
      final ds = df.date.length >= 10 ? df.date.substring(0, 10) : df.date;
      if (ds == todayStr) { todayFc = df; break; }
    }

    if (todayFc == null) {
      return _nearestHourly(DateTime.now())?.temperatureC
          ?? _currentWeather?.temperatureC
          ?? 0.0;
    }

    final tMin = todayFc.tempMin;
    final tMax = todayFc.tempMax;
    final h    = hour % 24;

    if (h >= 6 && h <= 14) return tMin + (tMax - tMin) * ((h - 6)  / 8.0);
    if (h > 14 && h <= 22) return tMax - (tMax - tMin) * ((h - 14) / 8.0);
    return tMin;
  }

  // ── Live slot getter ───────────────────────────────────────────────────────
  HourlyWeather? get _liveSlot => _nearestHourly(DateTime.now());

  // ── TEMPERATURE ────────────────────────────────────────────────────────────
  double get liveTemperatureC {
    if (_forecast.isEmpty) {
      return _liveSlot?.temperatureC ?? _currentWeather?.temperatureC ?? 0.0;
    }
    return _diurnalTempForHour(DateTime.now().hour);
  }

  double get liveFeelsLikeC {
    if (_forecast.isEmpty) {
      return _liveSlot?.feelsLikeC ?? _currentWeather?.feelsLikeC ?? 0.0;
    }
    return _diurnalTempForHour(DateTime.now().hour) - 1;
  }

  // ── WIND ───────────────────────────────────────────────────────────────────
  double get liveWindSpeedKmh {
    final val = _liveSlot?.windSpeedKmh ?? _currentWeather?.windSpeedKmh ?? 0.0;
    debugPrint('[WeatherProvider] liveWind=$val km/h '
        '| slot=${_liveSlot?.datetime} '
        '| slotDir=${_liveSlot?.windDirection}');
    return val;
  }

  // ── HUMIDITY ───────────────────────────────────────────────────────────────
  double get liveHumidityPercent {
    final val = _liveSlot?.humidityPercent ?? _currentWeather?.humidityPercent ?? 0.0;
    debugPrint('[WeatherProvider] liveHumidity=$val% '
        '| slot=${_liveSlot?.datetime}');
    return val;
  }

  String get liveCondition => _liveSlot?.condition ?? _currentWeather?.condition ?? 'Clear';
  double get liveRainMm    => _liveSlot?.rainMm    ?? _currentWeather?.rainMm    ?? 0.0;

  double get accumulatedRainMm {
    final today       = DateTime.now();
    final todayHourly = hourlyForDate(today);
    if (todayHourly.isNotEmpty) {
      return todayHourly.fold(0.0, (sum, h) => sum + h.rainMm);
    }
    if (_forecast.isNotEmpty) {
      final todayStr = _localDateStr(today);
      try {
        return _forecast.firstWhere((f) {
          final dateStr = f.date.length >= 10 ? f.date.substring(0, 10) : f.date;
          return dateStr == todayStr;
        }).rainTotal;
      } catch (_) {}
    }
    return 0.0;
  }

  // ── Cache-first init ───────────────────────────────────────────────────────
  Future<void> initFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat   = prefs.getDouble(_kCachedLat);
      final lon   = prefs.getDouble(_kCachedLon);
      final place = prefs.getString(_kCachedPlace) ?? '';
      final temp  = prefs.getDouble(_kCachedTemp);
      final cond  = prefs.getString(_kCachedCond) ?? 'Clear';

      if (lat != null && lon != null && temp != null) {
        _latitude  = lat;
        _longitude = lon;
        _placeName = place;
        _currentWeather = CurrentWeather.stub(
          temperatureC: temp,
          condition   : cond,
          placeName   : place,
        );
        _status = WeatherStatus.loaded;
        notifyListeners();
        debugPrint('[WeatherProvider] Cache-first: $place ${temp}°C ($cond)');
      } else {
        _latitude  = 28.6139;
        _longitude = 77.2090;
        _placeName = 'New Delhi, Delhi';
        _currentWeather = CurrentWeather.stub(
          temperatureC: 32,
          condition   : 'Clear',
          placeName   : 'New Delhi, Delhi',
        );
        _status = WeatherStatus.loaded;
        notifyListeners();
        debugPrint('[WeatherProvider] No cache — showing Delhi stub instantly');
      }
    } catch (e) {
      debugPrint('[WeatherProvider] Cache read error (non-fatal): $e');
    }
  }

  // ── initAndRefresh ─────────────────────────────────────────────────────────
  Future<void> initAndRefresh() async {
    if (_status == WeatherStatus.loaded) {
      debugPrint('[WeatherProvider] Cache hit — silently refreshing');
      _silentRefresh();
    } else {
      debugPrint('[WeatherProvider] No cache — fetching with loading spinner');
      fetchWeatherForCurrentLocation();
    }
  }

  // ── Helper: send alert using live computed values ─────────────────────────
  // Called after every successful fetch so notification temp matches app display
  Future<void> _sendAlert() async {
    if (_currentWeather == null) return;
    try {
      await WeatherAlertService.checkAndSendLive(
        weather:  _currentWeather!,
        liveTemp: liveTemperatureC,  // ← diurnal model value (matches app)
        liveWind: liveWindSpeedKmh,
        liveRain: liveRainMm,
      );
    } catch (e) {
      debugPrint('[WeatherProvider] Alert (non-fatal): $e');
    }
  }

  // ── Silent background refresh ──────────────────────────────────────────────
  Future<void> _silentRefresh() async {
    if (_silentRefreshing) return;
    _silentRefreshing = true;
    notifyListeners();

    try {
      WeatherService.clearCache();

      double lat   = _latitude;
      double lon   = _longitude;
      String place = _placeName;

      try {
        final permission     = await Geolocator.checkPermission();
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (permission != LocationPermission.deniedForever && serviceEnabled) {
          final position = await _locationService.getCurrentPosition();
          if (position != null) {
            lat   = position['lat']  as double;
            lon   = position['lon']  as double;
            place = position['name'] as String? ?? _placeName;
          }
        }
      } catch (e) {
        debugPrint('[WeatherProvider] Silent GPS failed, using cached coords: $e');
      }

      _latitude  = lat;
      _longitude = lon;

      final results = await Future.wait([
        _weatherService.getCurrentWeather(lat: lat, lon: lon),
        _weatherService.getForecast(lat: lat, lon: lon),
        _weatherService.getHourly(lat: lat, lon: lon),
        _weatherService.getTrend(lat: lat, lon: lon),
      ]);

      _currentWeather = results[0] as CurrentWeather;
      _forecast       = results[1] as List<DayForecast>;
      _hourly         = results[2] as List<HourlyWeather>;
      final td        = results[3] as Map<String, dynamic>;
      _trend = (td['trend'] as List)
          .map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
          .toList();
      _minTemp          = (td['min_temp'] as num).toDouble();
      _maxTemp          = (td['max_temp'] as num).toDouble();
      _usingStaleData   = _weatherService.isUsingStaleCache;
      _placeName        = place;
      _status           = WeatherStatus.loaded;
      _silentRefreshing = false;
      notifyListeners();

      await _saveToCache();

      debugPrint('[WeatherProvider] Silent refresh done — '
          'temp=${liveTemperatureC.toStringAsFixed(1)}°C | '
          'wind=${liveWindSpeedKmh.toStringAsFixed(1)} km/h | '
          'humidity=${liveHumidityPercent.toStringAsFixed(0)}%');

      try {
        await WeatherWidgetUpdater.update(this);
        debugPrint('[WeatherProvider] Home screen widget updated ✅');
      } catch (e) {
        debugPrint('[WeatherProvider] Widget update (non-fatal): $e');
      }

      // ✅ Uses liveTemperatureC so notification matches app display
      await _sendAlert();

    } catch (e) {
      _silentRefreshing = false;
      notifyListeners();
      debugPrint('[WeatherProvider] Silent refresh failed: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kCachedLat,   _latitude);
      await prefs.setDouble(_kCachedLon,   _longitude);
      await prefs.setString(_kCachedPlace, _placeName);
      if (_currentWeather != null) {
        await prefs.setDouble(_kCachedTemp, liveTemperatureC);
        await prefs.setString(_kCachedCond, _currentWeather!.condition);
      }
    } catch (e) {
      debugPrint('[WeatherProvider] Cache write error (non-fatal): $e');
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────
  Future<void> fetchWeatherForCurrentLocation() async {
    if (_isDebouncedNow()) return;

    _setLoading('Detecting location…');
    _locationFailReason = LocationFailReason.none;
    WeatherService.clearCache();

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        _locationFailReason = LocationFailReason.permissionPermanentlyDenied;
        _setError('Location permission permanently denied.\nPlease enable it in app settings.');
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationFailReason = LocationFailReason.serviceDisabled;
        _setError('Location services are turned off.\nPlease enable GPS on your device.');
        return;
      }
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _latitude  = position['lat']  as double;
        _longitude = position['lon']  as double;
        _placeName = position['name'] as String? ?? 'Current Location';
      } else {
        _locationFailReason = LocationFailReason.gpsFailed;
        _latitude  = 28.6139;
        _longitude = 77.2090;
        _placeName = 'New Delhi, Delhi';
      }
      await _fetchAll();
    } catch (e) {
      debugPrint('[WeatherProvider] $e');
      _setError(e.toString());
    }
  }

  Future<void> fetchWeatherForLocation({
    required double lat, required double lon, required String name,
  }) async {
    if (_isDebouncedNow()) return;
    _latitude  = lat;
    _longitude = lon;
    WeatherService.clearCache();
    _setLoading(name);
    await _fetchAll();
  }

  Future<void> refresh() {
    WeatherService.clearCache();
    _coordValueCache.clear();
    return _fetchAll();
  }

  Future<void> openLocationSettings() => _locationService.openAppSettings();

  bool _isDebouncedNow() {
    final now = DateTime.now();
    if (_lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMilliseconds < 500) {
      debugPrint('[WeatherProvider] debounced');
      return true;
    }
    _lastFetchTime = now;
    return false;
  }

  void _setLoading(String place) {
    _status        = WeatherStatus.loading;
    _placeName     = place;
    _loadingDetail = 'Connecting to NCMRWF server…';
    notifyListeners();
  }

  void _setError(String message) {
    _status       = WeatherStatus.error;
    _errorMessage = message
        .replaceAll('Exception: ', '')
        .replaceAll('exception: ', '');
    notifyListeners();
  }

  Future<void> _fetchAll({bool isRetry = false}) async {
    _loadingDetail = 'Connecting to NCMRWF server…';
    notifyListeners();

    try {
      final results = await Future.wait([
        _weatherService.getCurrentWeather(lat: _latitude, lon: _longitude),
        _weatherService.getForecast(lat: _latitude, lon: _longitude),
        _weatherService.getHourly(lat: _latitude, lon: _longitude),
        _weatherService.getTrend(lat: _latitude, lon: _longitude),
      ]);

      _currentWeather = results[0] as CurrentWeather;
      _forecast       = results[1] as List<DayForecast>;
      _hourly         = results[2] as List<HourlyWeather>;

      final trendData = results[3] as Map<String, dynamic>;
      _trend    = (trendData['trend'] as List)
          .map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
          .toList();
      _minTemp        = (trendData['min_temp'] as num).toDouble();
      _maxTemp        = (trendData['max_temp'] as num).toDouble();
      _loadingDetail  = '';
      _usingStaleData = _weatherService.isUsingStaleCache;
      _status         = WeatherStatus.loaded;
      notifyListeners();

      debugPrint('[WeatherProvider] Loaded: ${_forecast.length} days, '
          '${_hourly.length} hourly slots');
      debugPrint('[WeatherProvider] '
          'temp=${liveTemperatureC.toStringAsFixed(1)}°C | '
          'wind=${liveWindSpeedKmh.toStringAsFixed(1)} km/h | '
          'humidity=${liveHumidityPercent.toStringAsFixed(0)}%');

      await _saveToCache();

      try {
        await WeatherWidgetUpdater.update(this);
        debugPrint('[WeatherProvider] Widget updated after full fetch ✅');
      } catch (e) {
        debugPrint('[WeatherProvider] Widget update (non-fatal): $e');
      }

      // ✅ Uses liveTemperatureC so notification matches app display
      await _sendAlert();

      if (_usingStaleData) _scheduleBackgroundRefresh();

    } catch (e) {
      if (!isRetry) {
        debugPrint('[WeatherProvider] Fetch failed — retrying in 2s… ($e)');
        await Future.delayed(const Duration(seconds: 2));
        return _fetchAll(isRetry: true);
      }
      debugPrint('[WeatherProvider] Final error: $e');
      _setError(e.toString());
    }
  }

  void _scheduleBackgroundRefresh() {
    Future.delayed(const Duration(seconds: 30), () async {
      if (_status != WeatherStatus.loaded) return;
      debugPrint('[WeatherProvider] Background refresh…');
      WeatherService.clearCache();
      try {
        final results = await Future.wait([
          _weatherService.getCurrentWeather(lat: _latitude, lon: _longitude),
          _weatherService.getForecast(lat: _latitude, lon: _longitude),
          _weatherService.getHourly(lat: _latitude, lon: _longitude),
          _weatherService.getTrend(lat: _latitude, lon: _longitude),
        ]);
        _currentWeather = results[0] as CurrentWeather;
        _forecast       = results[1] as List<DayForecast>;
        _hourly         = results[2] as List<HourlyWeather>;
        final td        = results[3] as Map<String, dynamic>;
        _trend          = (td['trend'] as List)
            .map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
            .toList();
        _minTemp        = (td['min_temp'] as num).toDouble();
        _maxTemp        = (td['max_temp'] as num).toDouble();
        _usingStaleData = _weatherService.isUsingStaleCache;
        notifyListeners();
        await _saveToCache();
        try {
          await WeatherWidgetUpdater.update(this);
          debugPrint('[WeatherProvider] Background refresh + widget updated ✅');
        } catch (e) {
          debugPrint('[WeatherProvider] Widget update (non-fatal): $e');
        }
        // ✅ Uses liveTemperatureC so notification matches app display
        await _sendAlert();
      } catch (e) {
        debugPrint('[WeatherProvider] Background refresh failed: $e');
      }
    });
  }
}