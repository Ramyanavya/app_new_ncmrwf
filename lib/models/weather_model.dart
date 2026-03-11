// lib/models/weather_model.dart

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _degToDir(double deg) {
  const dirs = [
    'N','NNE','NE','ENE','E','ESE','SE','SSE',
    'S','SSW','SW','WSW','W','WNW','NW','NNW',
  ];
  final idx = ((deg + 11.25) / 22.5).floor() % 16;
  return dirs[idx];
}

// ── ROOT FIX ──────────────────────────────────────────────────────────────────
// NCMRWF API returns hourly time as NAIVE UTC: "2026-03-06 03:00:00"
// No 'Z', no '+05:30'. DateTime.tryParse() treats naive strings as LOCAL (IST).
// So "03:00:00" → 3 AM IST in Dart memory. But it is 3 AM UTC = 8:30 AM IST.
// Fix: replace space with T AND append Z → "2026-03-06T03:00:00Z"
// Dart now parses as UTC. .toLocal() → 8:30 AM IST. Label shows "8AM". ✅
// ─────────────────────────────────────────────────────────────────────────────
String _toUtcIso(String raw) {
  if (raw.isEmpty) return raw;
  var s = raw.trim().replaceFirst(' ', 'T');
  // Only append Z if no timezone info present
  if (!s.endsWith('Z') && !s.contains('+') &&
      !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
    s = '${s}Z';
  }
  return s;
}

/// Returns display label like "8AM", "3PM" from a UTC ISO string.
/// The input MUST already be UTC ISO (with Z) — use _toUtcIso() first.
String _formatHourLabel(String utcIso) {
  try {
    final dt = DateTime.tryParse(utcIso)?.toLocal();
    if (dt == null) return utcIso;
    final h = dt.hour;
    if (h == 0)  return '12AM';
    if (h == 12) return '12PM';
    if (h < 12)  return '${h}AM';
    return '${h - 12}PM';
  } catch (_) { return utcIso; }
}

int _parsePressureHpa(dynamic raw) {
  if (raw == null) return 1013;
  final val = (raw as num).toDouble();
  if (val > 2000) return (val / 100).round();
  return val.round();
}

// ─────────────────────────────────────────────────────────────────────────────
// WIND & HUMIDITY HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Safely reads wind speed from API JSON.
/// NCMRWF may use 'wind_speed', 'windspeed', or 'wind_spd'.
double _parseWindSpeed(Map<String, dynamic> json) {
  final raw = json['wind_speed'] ?? json['windspeed'] ?? json['wind_spd'];
  return (raw as num?)?.toDouble() ?? 0.0;
}

/// Safely reads wind direction degrees from API JSON.
/// May come as num (degrees) or String — handles both.
double _parseWindDeg(Map<String, dynamic> json) {
  final raw = json['wind_direction'];
  if (raw is num)    return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? 0.0;
  return 0.0;
}

/// Safely reads humidity from API JSON.
/// NCMRWF may use 'humidity' or 'relative_humidity'.
double _parseHumidity(Map<String, dynamic> json) {
  final raw = json['humidity'] ?? json['relative_humidity'];
  return (raw as num?)?.toDouble() ?? 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// CURRENT WEATHER
// ─────────────────────────────────────────────────────────────────────────────
class CurrentWeather {
  final double latitude;
  final double longitude;
  final double temperatureC;
  final double feelsLikeC;
  final double windSpeedKmh;
  final String windDirection;
  final double humidityPercent;
  final int    pressureMb;
  final String condition;
  final String? dataTime;
  final double rainMm;
  final double visibilityKm;
  final double uvIndex;

  CurrentWeather({
    required this.latitude,
    required this.longitude,
    required this.temperatureC,
    required this.feelsLikeC,
    required this.windSpeedKmh,
    required this.windDirection,
    required this.humidityPercent,
    required this.pressureMb,
    required this.condition,
    this.dataTime,
    this.rainMm       = 0.0,
    this.visibilityKm = 10.0,
    this.uvIndex      = 0.0,
  });

  factory CurrentWeather.stub({
    required double temperatureC,
    required String condition,
    required String placeName,
    double latitude        = 0.0,
    double longitude       = 0.0,
    double feelsLikeC      = 0.0,
    double windSpeedKmh    = 0.0,
    String windDirection   = 'N',
    double humidityPercent = 0.0,
    int    pressureMb      = 1013,
    double rainMm          = 0.0,
    double visibilityKm    = 10.0,
    double uvIndex         = 0.0,
  }) => CurrentWeather(
    latitude:        latitude,
    longitude:       longitude,
    temperatureC:    temperatureC,
    feelsLikeC:      feelsLikeC != 0.0 ? feelsLikeC : temperatureC,
    windSpeedKmh:    windSpeedKmh,
    windDirection:   windDirection,
    humidityPercent: humidityPercent,
    pressureMb:      pressureMb,
    condition:       condition,
    rainMm:          rainMm,
    visibilityKm:    visibilityKm,
    uvIndex:         uvIndex,
  );

  factory CurrentWeather.fromNcmrwfJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? {};
    final cur = json['current']  as Map<String, dynamic>? ?? {};

    // ✅ WIND: use shared helper — handles 'wind_speed'/'windspeed'/'wind_spd'
    final windSpeed = _parseWindSpeed(cur);
    // ✅ WIND DIR: use shared helper — handles num or String degrees
    final windDeg   = _parseWindDeg(cur);
    // ✅ HUMIDITY: use shared helper — handles 'humidity'/'relative_humidity'
    final humidity  = _parseHumidity(cur);

    final rainRaw = (cur['rain'] as num?)?.toDouble() ?? 0.0;

    return CurrentWeather(
      latitude:        (loc['lat']         as num?)?.toDouble() ?? 0.0,
      longitude:       (loc['lon']         as num?)?.toDouble() ?? 0.0,
      temperatureC:    (cur['temperature'] as num?)?.toDouble() ?? 0.0,
      feelsLikeC:      (cur['feels_like']  as num?)?.toDouble() ?? 0.0,
      windSpeedKmh:    windSpeed,
      windDirection:   _degToDir(windDeg),
      humidityPercent: humidity,
      pressureMb:      _parsePressureHpa(cur['pressure']),
      condition:       cur['condition']    as String?            ?? 'Clear',
      dataTime:        cur['time']         as String?,
      rainMm:          rainRaw < 0 ? 0.0 : rainRaw,
      visibilityKm:    (cur['visibility']  as num?)?.toDouble() ?? 10.0,
      uvIndex:         (cur['uv_index']    as num?)?.toDouble() ?? 0.0,
    );
  }

  factory CurrentWeather.fromJson(Map<String, dynamic> json) =>
      CurrentWeather.fromNcmrwfJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// DAY FORECAST
// ─────────────────────────────────────────────────────────────────────────────
class DayForecast {
  final String date;
  final String day;
  final double temperatureC;
  final double tempMin;
  final double tempMax;
  final String condition;
  final double rainTotal;
  // ✅ ADDED: windDirection per day so Wind tab no longer hardcodes 'SSE'
  final String windDirection;

  DayForecast({
    required this.date,
    required this.day,
    required this.temperatureC,
    required this.tempMin,
    required this.tempMax,
    required this.condition,
    this.rainTotal     = 0.0,
    this.windDirection = 'N', // ✅ default 'N' if API doesn't provide it
  });

  factory DayForecast.fromNcmrwfJson(Map<String, dynamic> json) {
    const days    = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final dateStr = json['date'] as String? ?? '';
    final dt      = DateTime.tryParse(dateStr);
    final tMin    = (json['temp_min']  as num?)?.toDouble() ?? 0.0;
    final tMax    = (json['temp_max']  as num?)?.toDouble() ?? 0.0;

    // ✅ WIND DIR: parse from daily API response using shared helper
    final windDeg = _parseWindDeg(json);

    return DayForecast(
      date:          dateStr,
      day:           dt != null ? days[dt.weekday - 1] : '',
      temperatureC:  (tMin + tMax) / 2,
      tempMin:       tMin,
      tempMax:       tMax,
      condition:     json['condition']   as String? ?? 'Clear',
      rainTotal:     (json['rain_total'] as num?)?.toDouble() ?? 0.0,
      windDirection: _degToDir(windDeg), // ✅ real direction from API
    );
  }

  factory DayForecast.fromJson(Map<String, dynamic> json) =>
      DayForecast.fromNcmrwfJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// HOURLY WEATHER
// ─────────────────────────────────────────────────────────────────────────────
class HourlyWeather {
  final String label;
  final String datetime; // always stored as UTC ISO with Z: "2026-03-06T03:00:00Z"
  final double temperatureC;
  final double feelsLikeC;
  final double windSpeedKmh;
  final String windDirection;
  final double humidityPercent;
  final String condition;
  final double rainMm;
  final double uvIndex;

  HourlyWeather({
    required this.label,
    required this.datetime,
    required this.temperatureC,
    required this.feelsLikeC,
    required this.windSpeedKmh,
    required this.windDirection,
    required this.humidityPercent,
    required this.condition,
    this.rainMm  = 0.0,
    this.uvIndex = 0.0,
  });

  factory HourlyWeather.fromNcmrwfJson(Map<String, dynamic> json) {
    // ✅ TIME: API may use 'time' OR 'datetime' — check both
    final timeStr = ((json['time'] ?? json['datetime'] ?? '') as Object).toString();

    // ✅ WIND SPEED: use shared helper — handles all key variants
    final windSpeed = _parseWindSpeed(json);
    // ✅ WIND DIR: use shared helper — handles num or String degrees
    final windDeg   = _parseWindDeg(json);
    // ✅ HUMIDITY: use shared helper — handles all key variants
    final humidity  = _parseHumidity(json);

    final rainRaw = (json['rain'] as num?)?.toDouble() ?? 0.0;

    // ✅ Convert "2026-03-06 03:00:00" → "2026-03-06T03:00:00Z" (UTC)
    final utcIso = _toUtcIso(timeStr);

    return HourlyWeather(
      label:           _formatHourLabel(utcIso),
      datetime:        utcIso,
      temperatureC:    (json['temperature'] as num?)?.toDouble() ?? 0.0,
      feelsLikeC:      (json['feels_like']  as num?)?.toDouble() ?? 0.0,
      windSpeedKmh:    windSpeed,
      windDirection:   _degToDir(windDeg),
      humidityPercent: humidity,
      condition:       json['condition']    as String?            ?? 'Clear',
      rainMm:          rainRaw < 0 ? 0.0 : rainRaw,
      uvIndex:         (json['uv_index']    as num?)?.toDouble()  ?? 0.0,
    );
  }

  factory HourlyWeather.fromJson(Map<String, dynamic> json) =>
      HourlyWeather.fromNcmrwfJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// TREND POINT
// ─────────────────────────────────────────────────────────────────────────────
class TrendPoint {
  final String day;
  final String date;
  final double temperatureC;

  TrendPoint({
    required this.day,
    required this.date,
    required this.temperatureC,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
    day:          json['day']            as String,
    date:         json['date']           as String,
    temperatureC: (json['temperature_c'] as num).toDouble(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FAVOURITE LOCATION
// ─────────────────────────────────────────────────────────────────────────────
class FavoriteLocation {
  final String name;
  final double latitude;
  final double longitude;

  FavoriteLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() =>
      {'name': name, 'latitude': latitude, 'longitude': longitude};

  factory FavoriteLocation.fromJson(Map<String, dynamic> json) =>
      FavoriteLocation(
        name:      json['name']      as String,
        latitude:  (json['latitude']  as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT MODEL
// ─────────────────────────────────────────────────────────────────────────────
class ProductModel {
  final int    id;
  final String productName;
  final String productAlias;
  final String description;
  final String productType;
  final String baseUrl;
  final List<dynamic>        baseUrlRules;
  final Map<String, dynamic> params;
  final List<String>         tags;
  final bool   isStatic;
  final bool   staticRedirect;
  final List<String>         staticLinks;
  final bool   isActive;
  final Map<String, dynamic>? dateRule;

  ProductModel({
    required this.id,
    required this.productName,
    required this.productAlias,
    required this.description,
    required this.productType,
    required this.baseUrl,
    required this.baseUrlRules,
    required this.params,
    required this.tags,
    required this.isStatic,
    required this.staticRedirect,
    required this.staticLinks,
    required this.isActive,
    this.dateRule,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
    id:             json['id']             ?? 0,
    productName:    json['product_name']   ?? '',
    productAlias:   json['product_alias']  ?? '',
    description:    json['description']    ?? '',
    productType:    json['product_type']   ?? '',
    baseUrl:        json['base_url']       ?? '',
    baseUrlRules:   json['base_url_rules'] ?? [],
    params:         Map<String, dynamic>.from(json['params'] ?? {}),
    tags:           List<String>.from(json['tags']           ?? []),
    isStatic:       json['is_static']      ?? false,
    staticRedirect: json['static_redirect']?? false,
    staticLinks:    List<String>.from(json['static_links']   ?? []),
    isActive:       json['is_active']      ?? true,
    dateRule:       json['date_rule'] != null
        ? Map<String, dynamic>.from(json['date_rule'])
        : null,
  );

  List<int> get hpaLevels {
    final raw = params['hpa'];
    if (raw == null) return [];
    return List<int>.from(raw.map((e) => int.tryParse(e.toString()) ?? e));
  }

  List<String> get utcValues {
    final raw = params['utc'];
    if (raw == null) return [];
    return List<String>.from(raw.map((e) => e.toString()));
  }

  List<int> get forecastHours {
    final fh = params['forecast_hours'];
    if (fh == null) return [];
    final values = List<int>.from(
      (fh['values'] as List).map((e) => int.tryParse(e.toString()) ?? 0),
    );
    final mode = fh['mode'] ?? 'index';
    final step = int.tryParse(fh['step']?.toString() ?? '24') ?? 24;
    if (mode == 'step') return values.map((v) => v * step).toList();
    return values;
  }

  List<String> get cities {
    final raw = params['cities'];
    if (raw == null) return [];
    return List<String>.from(raw);
  }

  List<String> get cityUrls {
    final raw = params['city_url'];
    if (raw == null) return [];
    return List<String>.from(raw);
  }

  bool get hasHpa          => productType.contains('hpa');
  bool get hasUtc          => productType.contains('utc');
  bool get hasForecastHour => productType.contains('fcst');
  bool get hasCity         => productType.contains('city');
  bool get isStaticLinks   =>
      productType == 'static_links' || (isStatic && staticLinks.isNotEmpty);

  String get displayName {
    final src = productAlias.isNotEmpty ? productAlias : productName;
    return src
        .split(RegExp(r'[-_]'))
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String get categoryLabel =>
      tags.isNotEmpty ? tags.first : productType;
}