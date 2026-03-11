import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/weather_model.dart';

class ProductProvider extends ChangeNotifier {
  // ── State ────────────────────────────────────────────────────────────────
  String selectedCategory = '';
  List<ProductModel> allProducts = [];
  List<ProductModel> products = [];
  bool isLoading = false;
  String? errorMessage;

  // ── Config ───────────────────────────────────────────────────────────────
  // TODO: When sir gives the real API URL:
  //   1. Set _useMockData = false
  //   2. Set _baseUrl to the real URL
  static const bool _useMockData = true;
  static const String _baseUrl = 'http://192.168.8.59:8000/api/v2/products';
  static const String _imageBaseUrl = 'https://nwp.ncmrwf.gov.in';

  // ── Category → tag mapping ────────────────────────────────────────────────
  static const Map<String, List<String>> _categoryTagMap = {
    'Wind': ['wind'],
    'Precipitation': ['rainfall', 'precipitation', 'rain'],
    'Temperature': ['temperature'],
    'Meteogram': ['meteogram'],
    'Weekly Charts(ERP)': ['extended range', 'erf', 'erp', 'weekly'],
    'Ensemble Prediction': ['ensemble'],
    'Low Pressure System': ['cyclone', 'low pressure'],
    'Air Quality': ['air quality', 'aqi', 'pm2.5', 'urban model'],
    'Special Products': ['special products', 'services for neighbouring'],
    'IMD Services': ['imd'],
    'Mithuna AI': ['mithuna', 'ai weather'],
    'BIMSTEC Products': ['bimstec'],
    'Observations': ['observation', 'satellite', 'radar'],
  };

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> fetchAllProducts() async {
    if (allProducts.isNotEmpty) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    if (_useMockData) {
      await Future.delayed(const Duration(milliseconds: 600));
      allProducts = _buildMockProducts();
    } else {
      try {
        final response = await http
            .get(Uri.parse('$_baseUrl/getAllProducts'))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<dynamic> rawList =
          data is List ? data : (data['data'] ?? data['products'] ?? []);
          allProducts = rawList
              .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
              .where((p) => p.isActive)
              .toList();
        } else {
          errorMessage = 'Server error: ${response.statusCode}';
        }
      } catch (e) {
        errorMessage = 'Network error: ${e.toString()}';
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadProducts(String category) async {
    selectedCategory = category;
    products = [];
    notifyListeners();

    if (allProducts.isEmpty && errorMessage == null) {
      await fetchAllProducts();
    }

    final keywords = _categoryTagMap[category] ?? [category.toLowerCase()];
    products = allProducts.where((p) {
      final allTags = p.tags.map((t) => t.toLowerCase()).toList();
      final nameAndDesc =
      '${p.productName} ${p.description} ${p.productAlias}'.toLowerCase();
      return keywords.any((kw) =>
      allTags.any((tag) => tag.contains(kw)) ||
          nameAndDesc.contains(kw));
    }).toList();

    notifyListeners();
  }

  Future<List<String>> fetchProductImages({
    required int productId,
    String? date,
    String? utc,
    int? hpa,
    int? forecastHour,
    String? cityUrl,
  }) async {
    if (_useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      // Return 3 placeholder weather-style images per product
      return [
        'https://picsum.photos/seed/$productId/800/450',
        'https://picsum.photos/seed/${productId + 10}/800/450',
        'https://picsum.photos/seed/${productId + 20}/800/450',
      ];
    }

    try {
      final body = <String, dynamic>{'productId': productId};
      if (date != null) body['date'] = date;
      if (utc != null) body['utc'] = utc;
      if (hpa != null) body['hpa'] = hpa;
      if (forecastHour != null) body['forecastHour'] = forecastHour;
      if (cityUrl != null) body['city'] = cityUrl;

      final response = await http
          .post(
        Uri.parse('$_baseUrl/getProduct'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final inner = data['data'] ?? data;
        if (inner is Map) {
          final urlField = inner['url'] ?? inner['image_url'];
          if (urlField is String && urlField.isNotEmpty) {
            return [_resolveUrl(urlField)];
          }
          final urlsField = inner['urls'];
          if (urlsField is List) {
            return urlsField
                .map((u) => _resolveUrl(u.toString()))
                .where((u) => u.isNotEmpty)
                .toList();
          }
        }
      }
    } catch (_) {}
    return [];
  }

  String _resolveUrl(String path) {
    if (path.startsWith('http')) return path;
    return '$_imageBaseUrl$path';
  }

  static String get todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Mock Data ─────────────────────────────────────────────────────────────
  // Based on real product structures from the Postman collection.
  // Replace with real API when available (_useMockData = false).

  List<ProductModel> _buildMockProducts() {
    return [
      // ── WIND ──────────────────────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 1, 'product_name': 'wind-forecast-global-model',
        'product_alias': 'Wind Forecast (Global)',
        'description': 'Upper air wind forecast from NCUM Global Model',
        'product_type': 'date_hpa_utc_fcst',
        'base_url': '/Data/mihir/{date}/{utc}/NCUM-G/Wind/{hpa}hPa/wind_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'hpa': [200, 500, 700, 850, 925], 'utc': ['00', '12'],
          'forecast_hours': {'mode': 'step', 'values': [0,1,2,3,4,5,6,7], 'step': 24}},
        'tags': ['wind', 'wind forecast', 'global model', 'ncum'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 2, 'product_name': 'wind-mslp-global-model',
        'product_alias': 'Wind & MSLP (Global)',
        'description': 'Mean Sea Level Pressure and Wind from NCUM Global',
        'product_type': 'date_utc_fcst',
        'base_url': '/Data/mihir/{date}/{utc}/NCUM-G/MSLP/mslp_wind_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'utc': ['00', '12'],
          'forecast_hours': {'mode': 'step', 'values': [0,1,2,3,4,5,6,7,8,9,10], 'step': 24}},
        'tags': ['wind', 'mslp', 'wind forecast', 'global model'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 3, 'product_name': 'wind-forecast-regional-model',
        'product_alias': 'Wind Forecast (Regional)',
        'description': 'Wind forecast from NCUM Regional Model at 12km resolution',
        'product_type': 'date_hpa_utc_fcst',
        'base_url': '/Data/mihir/{date}/{utc}/NCUM-R/Wind/{hpa}hPa/wind_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'hpa': [850, 925, 1000], 'utc': ['00', '12'],
          'forecast_hours': {'mode': 'step', 'values': [0,1,2,3,4,5], 'step': 24}},
        'tags': ['wind', 'wind forecast', 'regional model', 'ncum regional', '12km'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 4, 'product_name': 'wind-forecast-ensemble',
        'product_alias': 'Wind Forecast (Ensemble)',
        'description': 'Wind forecast ensemble from 12km NEPS model',
        'product_type': 'date_hpa_fcst',
        'base_url': '/Data/mihir/{date}/12-km-ENSEMBLE-Outputs/Wind-Forecast/wind{hpa}-day{forecast_hour}.png',
        'base_url_rules': [],
        'params': {'hpa': [200, 500, 700, 850, 925],
          'forecast_hours': {'mode': 'step', 'values': [0,1,2,3,4,5,6,7,8,9,10], 'step': 24}},
        'tags': ['wind', 'wind forecast', 'ensemble', 'ensemble prediction', '12km resolution'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 5, 'product_name': 'wind-850hpa-anomaly-extended',
        'product_alias': 'Wind 850 hPa Anomaly (ERP)',
        'description': 'Wind 850 hPa anomaly from Extended Range Forecast',
        'product_type': 'date_hpa',
        'base_url': '/Data/mihir/{date}/ERF_PROD/850hPa/Anomaly/winds.{hpa}_anomaly.png',
        'base_url_rules': [],
        'params': {'hpa': [850, 500, 200]},
        'tags': ['wind', 'wind forecast', 'extended range forecast', 'anomaly', 'atmosphere wind anomaly'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),

      // ── PRECIPITATION ─────────────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 11, 'product_name': 'rainfall-forecast-global',
        'product_alias': 'Rainfall Forecast (Global)',
        'description': 'Daily accumulated rainfall forecast from NCUM Global',
        'product_type': 'date_utc_fcst',
        'base_url': '/Data/mihir/{date}/{utc}/NCUM-G/Rainfall/rain_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'utc': ['00', '12'],
          'forecast_hours': {'mode': 'step', 'values': [1,2,3,4,5,6,7,8,9,10], 'step': 24}},
        'tags': ['rainfall', 'rain', 'precipitation', 'rainfall forecast', 'global model'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 12, 'product_name': 'rainfall-forecast-regional',
        'product_alias': 'Rainfall Forecast (Regional)',
        'description': 'Rainfall forecast from NCUM Regional Model',
        'product_type': 'date_utc_fcst',
        'base_url': '/Data/mihir/{date}/{utc}/NCUM-R/Rainfall/rain_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'utc': ['00', '12'],
          'forecast_hours': {'mode': 'step', 'values': [1,2,3,4,5], 'step': 24}},
        'tags': ['rainfall', 'rain', 'precipitation', 'rainfall forecast', 'regional model'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 13, 'product_name': 'rainfall-ensemble-probability',
        'product_alias': 'Rainfall Probability (Ensemble)',
        'description': 'Probability of rainfall exceedance from ensemble system',
        'product_type': 'date_fcst',
        'base_url': '/Data/mihir/{date}/12-km-ENSEMBLE-Outputs/Rainfall/rain-pqpf-day{forecast_hour}.png',
        'base_url_rules': [],
        'params': {'forecast_hours': {'mode': 'index', 'values': [1,2,3,4,5,6,7,8,9,10], 'step': 24}},
        'tags': ['rainfall', 'rain', 'precipitation', 'ensemble', 'rainfall probability'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),

      // ── TEMPERATURE ───────────────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 21, 'product_name': 'surface-temperature-global',
        'product_alias': 'Surface Temperature (Global)',
        'description': '2m surface temperature forecast from NCUM Global',
        'product_type': 'date_utc_fcst',
        'base_url': '/Data/mihir/{date}/{utc}/NCUM-G/Temperature/temp2m_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'utc': ['00', '12'],
          'forecast_hours': {'mode': 'step', 'values': [0,1,2,3,4,5,6,7], 'step': 24}},
        'tags': ['temperature', 'surface temperature', '2m temperature', 'global model'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 22, 'product_name': 'maximum-temperature-forecast',
        'product_alias': 'Maximum Temperature',
        'description': 'Daily maximum temperature forecast',
        'product_type': 'date_utc_fcst',
        'base_url': '/Data/mihir/{date}/{utc}/NCUM-G/Temperature/maxtemp_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'utc': ['00', '12'],
          'forecast_hours': {'mode': 'step', 'values': [1,2,3,4,5], 'step': 24}},
        'tags': ['temperature', 'maximum temperature', 'max temp', 'daily max'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 23, 'product_name': 'minimum-temperature-forecast',
        'product_alias': 'Minimum Temperature',
        'description': 'Daily minimum temperature forecast',
        'product_type': 'date_utc_fcst',
        'base_url': '/Data/mihir/{date}/{utc}/NCUM-G/Temperature/mintemp_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'utc': ['00', '12'],
          'forecast_hours': {'mode': 'step', 'values': [1,2,3,4,5], 'step': 24}},
        'tags': ['temperature', 'minimum temperature', 'min temp', 'daily min'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),

      // ── METEOGRAM ─────────────────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 31, 'product_name': 'city-meteogram',
        'product_alias': 'City Meteogram',
        'description': 'Weather meteogram for major Indian cities',
        'product_type': 'date_city',
        'base_url': '/Data/mihir/{date}/CMPROD/{city}.png',
        'base_url_rules': [],
        'params': {
          'cities': ['Delhi', 'Mumbai', 'Chennai', 'Kolkata', 'Bengaluru', 'Hyderabad', 'Pune', 'Ahmedabad'],
          'city_url': ['delhi_india', 'mumbai_india', 'chennai_india', 'kolkata_india',
            'bengaluru_india', 'hyderabad_india', 'pune_india', 'ahmedabad_india'],
        },
        'tags': ['meteogram', 'city meteogram', 'weather graph', 'city wise forecast'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 32, 'product_name': 'ocean-meteogram',
        'product_alias': 'Ocean Meteogram',
        'description': 'Ocean meteogram for coastal stations',
        'product_type': 'date_city',
        'base_url': '/Data/mihir/{date}/CMPROD/{city}.png',
        'base_url_rules': [],
        'params': {
          'cities': ['Mumbai', 'Chennai', 'Vishakhapatnam', 'Paradeep', 'Haldia', 'Port Blair'],
          'city_url': ['mumbai_india', 'chennai_india', 'vishakhapatnam_india',
            'paradeep_india', 'haldia_india', 'port_blai_india'],
        },
        'tags': ['meteogram', 'ocean meteogram', 'point based products', 'coastal'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),

      // ── WEEKLY CHARTS (ERP) ───────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 41, 'product_name': 'wind-weekly-chart-erp',
        'product_alias': 'Wind Weekly Chart (ERP)',
        'description': 'Weekly wind chart from Extended Range Prediction system',
        'product_type': 'date_hpa',
        'base_url': '/Data/mihir/{date}/ERF_PROD/{hpa}hPa/wind_weekly.png',
        'base_url_rules': [],
        'params': {'hpa': [850, 500, 200]},
        'tags': ['wind', 'extended range', 'erp', 'weekly', 'weekly charts'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'weekly', 'weekday': 'THU', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 42, 'product_name': 'rainfall-weekly-chart-erp',
        'product_alias': 'Rainfall Weekly Chart (ERP)',
        'description': 'Weekly rainfall from Extended Range Prediction system',
        'product_type': 'date_only',
        'base_url': '/Data/mihir/{date}/ERF_PROD/Rainfall/rainfall_weekly.png',
        'base_url_rules': [],
        'params': {},
        'tags': ['rainfall', 'extended range', 'erp', 'weekly', 'weekly charts'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'weekly', 'weekday': 'THU', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 43, 'product_name': 'temperature-weekly-chart-erp',
        'product_alias': 'Temperature Weekly Chart (ERP)',
        'description': 'Weekly temperature anomaly from Extended Range Prediction',
        'product_type': 'date_only',
        'base_url': '/Data/mihir/{date}/ERF_PROD/Temperature/temp_weekly.png',
        'base_url_rules': [],
        'params': {},
        'tags': ['temperature', 'extended range', 'erp', 'weekly', 'weekly charts'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'weekly', 'weekday': 'THU', 'offset': 0},
      }),

      // ── ENSEMBLE PREDICTION ───────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 51, 'product_name': 'ensemble-wind-12km',
        'product_alias': 'Ensemble Wind (12km)',
        'description': 'Multi-member ensemble wind forecast at 12km resolution',
        'product_type': 'date_hpa_fcst',
        'base_url': '/Data/mihir/{date}/12-km-ENSEMBLE-Outputs/Wind-Forecast/wind{hpa}-day{forecast_hour}.png',
        'base_url_rules': [],
        'params': {'hpa': [200, 500, 700, 850, 925],
          'forecast_hours': {'mode': 'step', 'values': [0,1,2,3,4,5,6,7,8,9,10], 'step': 24}},
        'tags': ['wind', 'ensemble', 'ensemble prediction', 'multi model', '12km resolution'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 52, 'product_name': 'ensemble-rainfall-probability',
        'product_alias': 'Ensemble Rainfall Probability',
        'description': 'Probabilistic rainfall forecast from ensemble prediction system',
        'product_type': 'date_fcst',
        'base_url': '/Data/mihir/{date}/12-km-ENSEMBLE-Outputs/Rainfall/rain-prob-day{forecast_hour}.png',
        'base_url_rules': [],
        'params': {'forecast_hours': {'mode': 'index', 'values': [1,2,3,4,5,6,7,8,9,10], 'step': 24}},
        'tags': ['rainfall', 'ensemble', 'ensemble prediction', 'rainfall probability'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 53, 'product_name': 'mjo-iso',
        'product_alias': 'MJO / ISO',
        'description': 'Madden-Julian Oscillation forecast from CNCUM model',
        'product_type': 'date_only',
        'base_url': '/Data/mihir/{date}/ERF_MJO_PROD/MJO/MJO/mjo_phase_cncum_forecast.gif',
        'base_url_rules': [],
        'params': {},
        'tags': ['mjo', 'iso', 'mjo-iso', 'extended range forecast', 'ensemble'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'weekly', 'weekday': 'THU', 'offset': 0},
      }),

      // ── LOW PRESSURE ──────────────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 61, 'product_name': 'cyclone-track-forecast',
        'product_alias': 'Cyclone Track Forecast',
        'description': 'Predicted cyclone track from NCUM Global Model',
        'product_type': 'date_utc_fcst',
        'base_url': '/Data/mihir/{date}/{utc}/Cyclone/track_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'utc': ['00', '12'],
          'forecast_hours': {'mode': 'step', 'values': [0,1,2,3,4,5], 'step': 24}},
        'tags': ['cyclone', 'low pressure', 'low pressure system', 'cyclone track'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),

      // ── AIR QUALITY ───────────────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 71, 'product_name': 'aqi-forecast-urban',
        'product_alias': 'AQI Forecast (Urban)',
        'description': 'Air Quality Index forecast from urban model',
        'product_type': 'date_fcst',
        'base_url': '/Data/mihir/{date}/AQI/aqi_day{forecast_hour}.png',
        'base_url_rules': [],
        'params': {'forecast_hours': {'mode': 'index', 'values': [1,2,3,4,5], 'step': 24}},
        'tags': ['air quality', 'aqi', 'urban model', 'urban', 'pollution forecast'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 72, 'product_name': 'maximum-pm25-seasonal-urban-model',
        'product_alias': 'Maximum PM2.5 (Seasonal)',
        'description': 'Maximum PM2.5 Seasonal output from Urban Model',
        'product_type': 'static_links',
        'base_url': '',
        'base_url_rules': [],
        'params': {},
        'tags': ['air quality', 'pm2.5', 'urban model', 'seasonal', 'maximum PM2.5'],
        'is_static': true, 'static_redirect': false,
        'static_links': ['/DM-Seasonal/maximum-PM.png'],
        'is_active': true, 'date_rule': null,
      }),

      // ── SPECIAL PRODUCTS ──────────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 74, 'product_name': 'services-for-neighbouring-region-qatar-wind',
        'product_alias': 'Qatar Wind Forecast',
        'description': 'Wind forecast for Qatar region (Afro-Asia services)',
        'product_type': 'date_hpa_utc_fcst',
        'base_url': '',
        'base_url_rules': [
          {'when': {'forecast_hour': 0}, 'url': '/Data/mihir/{date}/{utc}/Afro-Asia/Qatar/Wind-Forecast/qat_ana{hpa}w.png'},
          {'when': {'forecast_hour': '*'}, 'url': '/Data/mihir/{date}/{utc}/Afro-Asia/Qatar/Wind-Forecast/qat_{forecast_hour}fcst{hpa}w.png'},
        ],
        'params': {'hpa': [850, 1000], 'utc': ['00', '12'],
          'forecast_hours': {'mode': 'index', 'values': [0,1,2,3,4,5,6,7,8,9,10], 'step': 24}},
        'tags': ['special products', 'services for neighbouring region', 'qatar', 'wind forecast'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 81, 'product_name': 'afro-asia-wind-forecast',
        'product_alias': 'Afro-Asia Wind Forecast',
        'description': 'Wind forecast for the Afro-Asia region',
        'product_type': 'date_hpa_utc_fcst',
        'base_url': '/Data/mihir/{date}/{utc}/Afro-Asia/wind_{hpa}_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'hpa': [850, 500, 200], 'utc': ['00', '12'],
          'forecast_hours': {'mode': 'step', 'values': [0,1,2,3,4,5], 'step': 24}},
        'tags': ['special products', 'afro asia', 'wind forecast', 'neighbouring region'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),

      // ── IMD SERVICES ──────────────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 91, 'product_name': 'imd-weather-services',
        'product_alias': 'IMD Weather Services',
        'description': 'Integrated weather services and forecast from IMD',
        'product_type': 'date_only',
        'base_url': '/Data/imd/{date}/services/weather_services.png',
        'base_url_rules': [],
        'params': {},
        'tags': ['imd', 'imd services', 'india meteorological department'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),

      // ── MITHUNA AI ────────────────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 101, 'product_name': 'mithuna-ai-weather-prediction',
        'product_alias': 'Mithuna AI Forecast',
        'description': 'AI-based weather prediction using Mithuna deep learning model',
        'product_type': 'date_utc_fcst',
        'base_url': '/Data/mithuna/{date}/{utc}/forecast_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'utc': ['00', '12'],
          'forecast_hours': {'mode': 'step', 'values': [0,1,2,3,4,5,6,7,8,9,10], 'step': 24}},
        'tags': ['mithuna', 'mithuna ai', 'ai weather', 'deep learning', 'machine learning forecast'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),

      // ── BIMSTEC ───────────────────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 111, 'product_name': 'rain-forecast-deterministic-bangladesh',
        'product_alias': 'Rain Forecast (Bangladesh)',
        'description': 'Deterministic rain forecast for Bangladesh from BCWC',
        'product_type': 'date_fcst',
        'base_url': '/Data/mihir/{date}/BCWC_bangladesh/Subdivisional-Rainfall-Probability/rain-pqpf-day{forecast_hour}.png',
        'base_url_rules': [],
        'params': {'forecast_hours': {'mode': 'index', 'values': [1,2,3,4,5,6,7,8,9,10], 'step': 24}},
        'tags': ['bimstec', 'rainfall forecast', 'bangladesh', 'rainfall probability'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 112, 'product_name': 'bimstec-regional-weather',
        'product_alias': 'BIMSTEC Regional Weather',
        'description': 'Regional weather forecast for BIMSTEC nations',
        'product_type': 'date_utc_fcst',
        'base_url': '/Data/mihir/{date}/{utc}/BIMSTEC/weather_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'utc': ['00', '12'],
          'forecast_hours': {'mode': 'step', 'values': [1,2,3,4,5], 'step': 24}},
        'tags': ['bimstec', 'regional', 'bimstec products', 'south asia'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),

      // ── OBSERVATIONS ──────────────────────────────────────────────────────
      ProductModel.fromJson({
        'id': 121, 'product_name': 'satellite-observations-live',
        'product_alias': 'Satellite Observations',
        'description': 'Live satellite imagery and observations',
        'product_type': 'date_utc_fcst',
        'base_url': '/Data/obs/{date}/{utc}/satellite/img_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'utc': ['00', '06', '12', '18'],
          'forecast_hours': {'mode': 'direct', 'values': [0,1,2,3], 'step': 6}},
        'tags': ['observation', 'satellite', 'satellite observations', 'live'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
      ProductModel.fromJson({
        'id': 122, 'product_name': 'radar-observations-live',
        'product_alias': 'Radar Observations',
        'description': 'Live Doppler radar observations across India',
        'product_type': 'date_utc_fcst',
        'base_url': '/Data/obs/{date}/{utc}/radar/img_{forecast_hour}h.png',
        'base_url_rules': [],
        'params': {'utc': ['00', '06', '12', '18'],
          'forecast_hours': {'mode': 'direct', 'values': [0,1,2,3], 'step': 6}},
        'tags': ['observation', 'radar', 'radar observations', 'doppler', 'live'],
        'is_static': false, 'static_redirect': false, 'static_links': [], 'is_active': true,
        'date_rule': {'rule': 'daily', 'offset': 0},
      }),
    ];
  }
}