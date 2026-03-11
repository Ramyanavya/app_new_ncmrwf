import 'dart:ui';
import '../utils/translated_text.dart';
import '../utils/time_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

// pubspec.yaml:  webview_flutter: ^4.7.0
//                google_fonts: ^6.1.0
// AndroidManifest.xml inside <application>:
//   <uses-permission android:name="android.permission.INTERNET"/>

// ─────────────────────────────────────────────────────────────────────────────
// THEME  — now powered by TimeTheme (time-aware: dawn / day / dusk / night)
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  // Pull live palette once; widgets that need re-evaluation call _T.theme again.
  static TimeTheme get theme => TimeTheme.of();

  // Convenience shortcuts ─ these are computed properties, not constants,
  // so the palette can vary without touching every widget.
  static Color get bg1 => theme.bgGradient[0];
  static Color get bg2 => theme.bgGradient[1];
  static Color get bg3 => theme.bgGradient.length > 2
      ? theme.bgGradient[2]
      : theme.bgGradient[1];

  static const scrim1 = Color(0x14000000);
  static const scrim2 = Color(0x2E000000);
  static const scrim3 = Color(0x8C000000);

  static Color get amber  => theme.accent;
  static Color get amber2 => theme.accent.withOpacity(0.75);
  static Color get blue   => const Color(0xFF64B5F6);
  static const green  = Color(0xFF81C784);

  static const white   = Colors.white;
  static const white70 = Color(0xB3FFFFFF);
  static const white60 = Color(0x99FFFFFF);
  static const white38 = Color(0x61FFFFFF);
  static const white25 = Color(0x40FFFFFF);
  static const white20 = Color(0x33FFFFFF);
  static const white15 = Color(0x26FFFFFF);
  static const white12 = Color(0x1EFFFFFF);
  static const white10 = Color(0x1AFFFFFF);
}

// ─────────────────────────────────────────────────────────────────────────────
// FROSTED GLASS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _FrostCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double blurSigma;
  final double bgOpacity;
  final Color? tint;
  final bool hasBorder;

  const _FrostCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.blurSigma = 18,
    this.bgOpacity = 0.18,
    this.tint,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: (tint ?? Colors.white).withOpacity(bgOpacity),
          borderRadius: BorderRadius.circular(radius),
          border: hasBorder
              ? Border.all(color: Colors.white.withOpacity(0.20), width: 1)
              : null,
        ),
        child: child,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _Cat {
  final String id;
  final String name;
  final IconData icon;
  final int count;
  final bool hasSubcats;
  const _Cat(this.id, this.name, this.icon, this.count,
      {this.hasSubcats = false});
}

const List<_Cat> _kCats = [
  _Cat('Wind',                'Wind',                Icons.air_rounded,            25),
  _Cat('Precipitation',       'Precipitation',        Icons.water_drop_rounded,     24),
  _Cat('Temperature',         'Temperature',          Icons.thermostat_rounded,     34),
  _Cat('Meteogram',           'Meteogram',            Icons.show_chart_rounded,      2),
  _Cat('Weekly Charts(ERP)',  'Weekly Charts (ERP)',  Icons.date_range_rounded,     37),
  _Cat('Ensemble Prediction', 'Ensemble Prediction',  Icons.hub_rounded,            10),
  _Cat('Low Pressure System', 'Low Pressure System',  Icons.cyclone_rounded,         4),
  _Cat('Air Quality',         'Air Quality',          Icons.air_rounded,            30),
  _Cat('Special Products',    'Special Products',     Icons.star_border_rounded,    28),
  _Cat('IMD Services',        'IMD Services',         Icons.flag_outlined,           3),
  _Cat('Mithuna AI',          'Mithuna AI',           Icons.auto_awesome_rounded,    7, hasSubcats: true),
  _Cat('BIMSTEC Products',    'BIMSTEC Products',     Icons.public_rounded,         24),
  _Cat('Observations',        'Observations',         Icons.satellite_alt_rounded,   9),
];

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _Prod {
  final int id;
  final String name;
  final String desc;
  final String type;
  final String catKey;
  final String? subcat;
  final String baseUrl;
  final String imageUrl;
  final List<int> hpa;
  final List<String> utc;
  final List<int> fcst;
  final List<String> cities;
  final List<String> cityUrls;

  const _Prod({
    required this.id,
    required this.name,
    required this.desc,
    required this.type,
    required this.catKey,
    this.subcat,
    required this.baseUrl,
    required this.imageUrl,
    this.hpa = const [],
    this.utc = const [],
    this.fcst = const [],
    this.cities = const [],
    this.cityUrls = const [],
  });

  bool get hasHpa  => hpa.isNotEmpty;
  bool get hasUtc  => utc.isNotEmpty;
  bool get hasFcst => fcst.isNotEmpty;
  bool get hasCity => cities.isNotEmpty;
  bool get isStatic => type == 'static';
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLETE PRODUCT DATA
// ─────────────────────────────────────────────────────────────────────────────
final List<_Prod> _kProducts = [
  _Prod(id:1, catKey:'Wind', name:'Wind Forecast – Global Model',
      desc:'Wind forecast global', type:'date_hpa_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/wind-forecast-global.png',
      hpa:[200,500,700,850,925], utc:['00','12'],
      fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/1'),
  _Prod(id:2, catKey:'Wind', name:'Wind MSLP – Global Model',
      desc:'Wind forecast MSLP', type:'date_hpa_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/wind-forecast-mslp.png',
      hpa:[200,500,700,850,925], utc:['00','12'],
      fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/3'),
  _Prod(id:3, catKey:'Wind', name:'Wind Forecast – Regional Model',
      desc:'Wind forecast regional', type:'date_hpa_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/wind-forecast-regional.png',
      hpa:[850,925,1000], utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/9'),
  _Prod(id:4, catKey:'Wind', name:'Wind Forecast – Ensemble Prediction',
      desc:'Wind forecast ensemble', type:'date_hpa_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/wind-forecast-ensemble.png',
      hpa:[200,500,700,850,925], utc:['00','12'],
      fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/16'),
  _Prod(id:5, catKey:'Wind', name:'Wind Ensemble Stamps',
      desc:'Wind ensemble stamps', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/wind-ensemble-stamps.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/18'),
  _Prod(id:6, catKey:'Wind', name:'Wind Full Field – Weekly Charts',
      desc:'Wind 850, 500, 200 hPa full field', type:'date_hpa',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-wind-850hPa-full-field-extended.png',
      hpa:[200,500,850],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa/31'),
  _Prod(id:7, catKey:'Wind', name:'Wind Anomaly – Weekly Charts',
      desc:'Wind 850, 500, 200 hPa anomaly', type:'date_hpa',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-wind-850hPa-anomaly-extended.png',
      hpa:[200,500,850],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa/32'),
  _Prod(id:8, catKey:'Wind', name:'Afro Asia Wind Forecast – Special Products',
      desc:'Afro Asia (wind forecast)', type:'date_hpa_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/services-for-neighbouring-region-afro-asia-wind-forecast.png',
      hpa:[850,925], utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/70'),
  _Prod(id:9, catKey:'Wind', name:'Kenya Wind Forecast – Special Products',
      desc:'Kenya (wind forecast)', type:'date_hpa_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/services-for-neighbouring-region-kenya-wind-forecast.png',
      hpa:[850,925], utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/72'),
  _Prod(id:10, catKey:'Wind', name:'Qatar Wind Forecast – Special Products',
      desc:'Qatar (wind forecast)', type:'date_hpa_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/services-for-neighbouring-region-qatar-wind-forecast.png',
      hpa:[850,925], utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/74'),
  _Prod(id:11, catKey:'Wind', name:'Diurnal Windgust – Subdaily Charts',
      desc:'Subdaily charts of diurnal windgust', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/subdaily-charts-diurnal-windgust.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/76'),
  _Prod(id:12, catKey:'Wind', name:'Solar and Wind Energy Products',
      desc:'Solar and wind energy products', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/solar-and-wind-energy-products.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/83'),
  _Prod(id:13, catKey:'Wind', name:'Wind Forecast Deterministic – Bangladesh',
      desc:'Wind forecast deterministic (Bangladesh)', type:'date_hpa_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Bangladesh-wind.png',
      hpa:[850,925], fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_fcst/133'),
  _Prod(id:14, catKey:'Wind', name:'Wind Forecast Deterministic – Bhutan',
      desc:'Wind Forecast Deterministic (Bhutan)', type:'date_hpa_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Bhutan-wind.png',
      hpa:[850,925], fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_fcst/144'),
  _Prod(id:15, catKey:'Wind', name:'Wind Forecast Deterministic – Myanmar',
      desc:'Wind Forecast Deterministic (Myanmar)', type:'date_hpa_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Myanmar-wind.png',
      hpa:[850,925], fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_fcst/149'),
  _Prod(id:16, catKey:'Wind', name:'Wind Forecast Deterministic – Nepal',
      desc:'Wind Forecast Deterministic (Nepal)', type:'date_hpa_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Nepal-wind.png',
      hpa:[850,925], fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_fcst/154'),
  _Prod(id:17, catKey:'Wind', name:'Wind Forecast Deterministic – Sri Lanka',
      desc:'Wind Forecast Deterministic (Srilanka)', type:'date_hpa_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/wind-forecast-srilanka.png',
      hpa:[850,925], fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_fcst/159'),
  _Prod(id:18, catKey:'Wind', name:'Wind Forecast Deterministic – Thailand',
      desc:'Wind Forecast Deterministic (Thailand)', type:'date_hpa_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/wind-forecast-thailand.png',
      hpa:[850,925], fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_fcst/164'),
  _Prod(id:19, catKey:'Wind', name:'Wind Forecast – NCMRWF Products',
      desc:'Wind Forecast NCMRWF', type:'date_hpa_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Imd-wind.png',
      hpa:[200,500,700,850,925], utc:['00','12'],
      fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/205'),
  _Prod(id:20, catKey:'Wind', name:'Pangu Wind Forecast – AIML Model',
      desc:'Pangu-Weather: a deep learning-based system developed by Huawei. Initialised with NCMRWF analysis at 0.25° resolution.',
      type:'date_hpa_utc_fcst', subcat:'AIML Model',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/wind-forecast-Ai.png',
      hpa:[200,500,850], utc:['00','12'],
      fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/208'),
  _Prod(id:21, catKey:'Wind', name:'Pangu MSLP – AIML Model',
      desc:'Pangu-Weather: a deep learning-based system developed by Huawei. Initialised with NCMRWF analysis at 0.25° resolution.',
      type:'date_utc_fcst', subcat:'AIML Model',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/forecast-mslp-Ai.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/209'),
  _Prod(id:22, catKey:'Wind', name:'FourCastNet Wind Forecast – AIML Model',
      desc:'FourCastNet v2-small developed by NVIDIA. Initialised with NCMRWF analysis at 0.25° resolution.',
      type:'date_hpa_utc_fcst', subcat:'AIML Model',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/forecastnet-wind-Ai.png',
      hpa:[200,500,850], utc:['00','12'],
      fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/210'),
  _Prod(id:23, catKey:'Wind', name:'FourCastNet MSLP – AIML Model',
      desc:'FourCastNet v2-small developed by NVIDIA. Initialised with NCMRWF analysis at 0.25° resolution.',
      type:'date_utc_fcst', subcat:'AIML Model',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/forecastnet-mslp-Ai.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/211'),
  _Prod(id:24, catKey:'Wind', name:'GraphCast Wind Forecast – AIML Model',
      desc:'GraphCast (Google DeepMind). Initialised with NCMRWF analysis at 0.25° resolution.',
      type:'date_hpa_utc_fcst', subcat:'AIML Model',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/GraphCast-wind-Ai.png',
      hpa:[200,500,850], utc:['00','12'],
      fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/212'),
  _Prod(id:25, catKey:'Wind', name:'GraphCast MSLP – AIML Model',
      desc:'GraphCast (Google DeepMind). Initialised with NCMRWF analysis at 0.25° resolution.',
      type:'date_utc_fcst', subcat:'AIML Model',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/GraphCast-mslp-Ai.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/213'),
  // PRECIPITATION
  _Prod(id:401, catKey:'Precipitation', name:'Rain Forecast – Global Model',
      desc:'Rain forecast global', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/rain-forecast-global.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/2'),
  _Prod(id:402, catKey:'Precipitation', name:'All India Rainfall – Global Model',
      desc:'All India rainfall information global model', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/all-india-rainfall-global.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/5'),
  _Prod(id:403, catKey:'Precipitation', name:'Subdivisional Rainfall Global – Global Model',
      desc:'Subdivisional rainfall information global model', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/subdivisional-rainfall-global.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/6'),
  _Prod(id:404, catKey:'Precipitation', name:'Rain Forecast – Regional Model',
      desc:'Rain forecast regional', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/rain-forecast-regional.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/10'),
  _Prod(id:405, catKey:'Precipitation', name:'Rainfall Probability – Ensemble Prediction',
      desc:'Rainfall probability ensemble', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/rain-ensemble-stamps.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/13'),
  _Prod(id:406, catKey:'Precipitation', name:'Rain Full Field – Weekly Charts',
      desc:'Atmosphere rain full field', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-rain-full-field-extended.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/25'),
  _Prod(id:407, catKey:'Precipitation', name:'Rain Anomaly – Weekly Charts',
      desc:'Atmosphere rain anomaly', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-rain-anomaly-extended.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/26'),
  _Prod(id:408, catKey:'Precipitation', name:'Afro Asia Rain Forecast – Special Products',
      desc:'Afro Asia (rain forecast)', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/services-for-neighbouring-region-afro-asia-rain-forecast.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/71'),
  _Prod(id:409, catKey:'Precipitation', name:'Kenya Rain Forecast – Special Products',
      desc:'Kenya (rain forecast)', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/services-for-neighbouring-region-kenya-rain-forecast.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/73'),
  _Prod(id:410, catKey:'Precipitation', name:'Qatar Rain Forecast – Special Products',
      desc:'Qatar (rain forecast)', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/services-for-neighbouring-region-qatar-rain-forecast.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/75'),
  _Prod(id:411, catKey:'Precipitation', name:'Diurnal Rainfall – Special Products',
      desc:'Subdaily charts of diurnal rainfall', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/subdaily-charts-diurnal-rainfall.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/78'),
  _Prod(id:412, catKey:'Precipitation', name:'Rainfall – Observations',
      desc:'Observations of rainfall', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/rainfall-observations.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/93'),
  _Prod(id:413, catKey:'Precipitation', name:'NRT 1-Hour Rainfall – Observations',
      desc:'NRT 1hour rainfall', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/nrt-1hour-rainfall-nrt-observations.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/100'),
  _Prod(id:414, catKey:'Precipitation', name:'NRT 3-Hour Rainfall – Observations',
      desc:'NRT 3hour rainfall', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/nrt-3hour-rainfall-nrt-observations.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/101'),
  _Prod(id:415, catKey:'Precipitation', name:'NRT 6-Hour Rainfall – Observations',
      desc:'NRT 6hour rainfall', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/nrt-6hour-rainfall-nrt-observations.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/102'),
  _Prod(id:416, catKey:'Precipitation', name:'Rain Forecast Deterministic – Bangladesh',
      desc:'Rain forecast deterministic (Bangladesh)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Bangladesh-Rain.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/134'),
  _Prod(id:417, catKey:'Precipitation', name:'Rain Forecast Deterministic – Bhutan',
      desc:'Rain Forecast Deterministic (Bhutan)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Bhutan-Rain.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/145'),
  _Prod(id:418, catKey:'Precipitation', name:'Rainfall Forecast Deterministic – Myanmar',
      desc:'Rainfall Forecast Deterministic (Myanmar)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Myanmar-Rain.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/150'),
  _Prod(id:419, catKey:'Precipitation', name:'Rain Forecast Deterministic – Nepal',
      desc:'Rain forecast deterministic (Nepal)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Nepal-Rain.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/155'),
  _Prod(id:420, catKey:'Precipitation', name:'Rain Forecast Deterministic – Sri Lanka',
      desc:'Rain forecast deterministic (Srilanka)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/rain-forecast-srilanka.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/160'),
  _Prod(id:421, catKey:'Precipitation', name:'Rain Forecast Deterministic – Thailand',
      desc:'Rain forecast deterministic (Thailand)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/rain-forecast-thailand.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/165'),
  _Prod(id:422, catKey:'Precipitation', name:'Rain Forecast – NCMRWF Products',
      desc:'Rain Forecast NCMRWF', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/rain-imd.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/206'),
  _Prod(id:423, catKey:'Precipitation', name:'GraphCast Rain Forecast – AIML Model',
      desc:'GraphCast (Google DeepMind). Initialised with NCMRWF analysis at 0.25° resolution.',
      type:'date_utc_fcst', subcat:'AIML Model',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/GraphCast-rain-Ai.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/214'),
  _Prod(id:424, catKey:'Precipitation', name:'Rain Ensemble Stamps – Ensemble Prediction',
      desc:'Rain ensemble stamps', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/rain-ensemble-stamps.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/17'),
  // TEMPERATURE
  _Prod(id:501, catKey:'Temperature', name:'Maximum Temperature Probability Ensemble',
      desc:'Maximum temperature probability ensemble', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/maximum-temperature-probability-ensemble.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/21'),
  _Prod(id:502, catKey:'Temperature', name:'Minimum Temperature Probability Ensemble',
      desc:'Minimum temperature probability ensemble', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/minimum-temperature-probability-ensemble.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/22'),
  _Prod(id:503, catKey:'Temperature', name:'Tmin Full Field – Weekly Charts',
      desc:'Atmosphere Temperature (Tmin) full field', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-minimum-temperature-full-field-extended.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/27'),
  _Prod(id:504, catKey:'Temperature', name:'Tmax Full Field – Weekly Charts',
      desc:'Atmosphere Temperature (Tmax) full field', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-maximum-temperature-full-field-extended.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/28'),
  _Prod(id:505, catKey:'Temperature', name:'Tmin Anomaly – Weekly Charts',
      desc:'Atmosphere Temperature (Tmin) anomaly', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-minimum-temperature-anomaly-extended.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/29'),
  _Prod(id:506, catKey:'Temperature', name:'Tmax Anomaly – Weekly Charts',
      desc:'Atmosphere Temperature (Tmax) anomaly', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-maximum-temperature-anomaly-extended.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/30'),
  _Prod(id:507, catKey:'Temperature', name:'Sea Surface Temperature Mean (Arctic)',
      desc:'Mean Arctic sea surface temperature', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/sea-surface-temperature-mean-arctic.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/40'),
  _Prod(id:508, catKey:'Temperature', name:'Sea Surface Temperature Anomaly (Arctic)',
      desc:'Anomaly Arctic sea surface temperature', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/sea-surface-temperature-Anomaly-arctic.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/41'),
  _Prod(id:509, catKey:'Temperature', name:'Sea Surface Temperature Mean (Antarctic)',
      desc:'Mean Antarctic sea surface temperature', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/sea-surface-temperature-Mean-Antarctic.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/50'),
  _Prod(id:510, catKey:'Temperature', name:'Sea Surface Temperature Anomaly (Antarctic)',
      desc:'Anomaly Antarctic sea surface temperature', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/sea-surface-temperature-Anomaly-Antarctic.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/51'),
  _Prod(id:511, catKey:'Temperature', name:'Sea Surface Temperature Mean (Ocean)',
      desc:'Mean ocean sea surface temperature (SST)', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/sea-surface-temperature-mean-ocean.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/56'),
  _Prod(id:512, catKey:'Temperature', name:'Sea Surface Temperature Anomaly (Ocean)',
      desc:'Anomaly ocean sea surface temperature (SST)', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/sea-surface-temperature-Anomaly-ocean.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/57'),
  _Prod(id:513, catKey:'Temperature', name:'Diurnal Cloud Top Temperature – Special Products',
      desc:'Aviation products of diurnal cloud top temperature', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/aviation-products-diurnal-cloud-top-temperature.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/82'),
  _Prod(id:514, catKey:'Temperature', name:'Max Temp – Observations',
      desc:'Max Temp of temperature in observations', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/temperature-max-temp-observations.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/96'),
  _Prod(id:515, catKey:'Temperature', name:'Max Temp Tendency – Observations',
      desc:'Max Temp Tendency of temperature in observations', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/temperature-max-temp-tendency-observations.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/97'),
  _Prod(id:516, catKey:'Temperature', name:'Min Temp – Observations',
      desc:'Min Temp of temperature in observations', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/temperature-min-temp-observations.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/98'),
  _Prod(id:517, catKey:'Temperature', name:'Min Temp Tendency – Observations',
      desc:'Min Temp Tendency of temperature in observations', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/temperature-min-temp-tendency-observations.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/99'),
  _Prod(id:518, catKey:'Temperature', name:'Temperature (330m DM-Chem) – Urban Model',
      desc:'Temperature for DM-Chem', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/temperature-urban-model.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/107'),
  _Prod(id:519, catKey:'Temperature', name:'Temperature (NCUM 1.5km) – Urban Model',
      desc:'Temperature for DM-Chem', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Temperture2-urban-model.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/110'),
  _Prod(id:520, catKey:'Temperature', name:'330m Surface Temperature Verification – Urban Model',
      desc:'330m-Surface-Temperature-verification for DM-Chem', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/330m-Surface-Temperature-verification-urban-model.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/121'),
  _Prod(id:521, catKey:'Temperature', name:'1.5km Surface Temperature Verification – Urban Model',
      desc:'1.5km-Surface-Temperature-verification for DM-Chem', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/1.5km-Surface-Temperature-verification-urban-model.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/124'),
  _Prod(id:522, catKey:'Temperature', name:'Surface Temperature (330m) – Urban Model',
      desc:'Surface-Temperature(330m) for DM-Chem', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Surface-Temperature(330m).png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/127'),
  _Prod(id:523, catKey:'Temperature', name:'Min Temp Deterministic – Bangladesh',
      desc:'Minimum temperature deterministic (Bangladesh)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Minimum-temperature-Bangladesh.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/135'),
  _Prod(id:524, catKey:'Temperature', name:'Max Temp Deterministic – Bangladesh',
      desc:'Maximum temperature deterministic (Bangladesh)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Maximum-temperature-Bangladesh.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/137'),
  _Prod(id:525, catKey:'Temperature', name:'Min Temp Deterministic – Bhutan',
      desc:'Minimum temperature deterministic (Bhutan)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Minimum-temperature-Bhutan.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/146'),
  _Prod(id:526, catKey:'Temperature', name:'Max Temp Deterministic – Bhutan',
      desc:'Maximum Temperature Deterministic (Bhutan)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Maximum-temperature-Bhutan.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/147'),
  _Prod(id:527, catKey:'Temperature', name:'Min Temp Deterministic – Myanmar',
      desc:'Minimum temperature deterministic (Myanmar)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Minimum-temperature-Myanmar.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/151'),
  _Prod(id:528, catKey:'Temperature', name:'Max Temp Deterministic – Myanmar',
      desc:'Maximum temperature deterministic (Myanmar)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Maximum-temperature-Myanmar.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/152'),
  _Prod(id:529, catKey:'Temperature', name:'Min Temp Deterministic – Nepal',
      desc:'Minimum temperature deterministic (Nepal)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/minimum-temperature-nepal.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/156'),
  _Prod(id:530, catKey:'Temperature', name:'Max Temp Deterministic – Nepal',
      desc:'Maximum temperature deterministic (Nepal)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/maximum-temperature-nepal.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/157'),
  _Prod(id:531, catKey:'Temperature', name:'Min Temp Deterministic – Sri Lanka',
      desc:'Minimum temperature deterministic (Srilanka)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/minimum-temperature-srilanka.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/161'),
  _Prod(id:532, catKey:'Temperature', name:'Max Temp Deterministic – Sri Lanka',
      desc:'Maximum temperature deterministic (Srilanka)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/maximum-temperature-srilanka.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/162'),
  _Prod(id:533, catKey:'Temperature', name:'Min Temp Deterministic – Thailand',
      desc:'Minimum temperature deterministic (Thailand)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/minimum-temperature-thailand.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/166'),
  _Prod(id:534, catKey:'Temperature', name:'Max Temp Deterministic – Thailand',
      desc:'Maximum temperature deterministic (Thailand)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/maximum-temperature-thailand.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/167'),
  // METEOGRAM
  _Prod(id:801, catKey:'Meteogram', name:'Meteogram – Global Model',
      desc:'Meteogram charts – city wise', type:'date_city',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/meteogram-global.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_city/4'),
  _Prod(id:802, catKey:'Meteogram', name:'Ocean Meteogram – Special Products',
      desc:'Ocean meteogram of point based products', type:'date_city',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/point-based-products-ocean-meteogram.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_city/91'),
  // WEEKLY CHARTS
  _Prod(id:901, catKey:'Weekly Charts(ERP)', name:'Rain Full Field – Weekly Charts',
      desc:'Atmosphere rain full field', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-rain-full-field-extended.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/25'),
  _Prod(id:902, catKey:'Weekly Charts(ERP)', name:'Rain Anomaly – Weekly Charts',
      desc:'Atmosphere rain anomaly', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-rain-anomaly-extended.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/26'),
  _Prod(id:903, catKey:'Weekly Charts(ERP)', name:'Tmin Full Field – Weekly Charts',
      desc:'Atmosphere Temperature (Tmin) full field', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-minimum-temperature-full-field-extended.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/27'),
  _Prod(id:904, catKey:'Weekly Charts(ERP)', name:'Tmax Full Field – Weekly Charts',
      desc:'Atmosphere Temperature (Tmax) full field', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-minimum-temperature-full-field-extended.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/28'),
  _Prod(id:905, catKey:'Weekly Charts(ERP)', name:'Tmin Anomaly – Weekly Charts',
      desc:'Atmosphere Temperature (Tmin) anomaly', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-minimum-temperature-anomaly-extended.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/29'),
  _Prod(id:906, catKey:'Weekly Charts(ERP)', name:'Tmax Anomaly – Weekly Charts',
      desc:'Atmosphere Temperature (Tmax) anomaly', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-maximum-temperature-anomaly-extended.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/30'),
  _Prod(id:907, catKey:'Weekly Charts(ERP)', name:'Wind Full Field – Weekly Charts',
      desc:'Wind 850, 500, 200 hPa full field', type:'date_hpa',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-wind-850hPa-full-field-extended.png',
      hpa:[200,500,850],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa/31'),
  _Prod(id:908, catKey:'Weekly Charts(ERP)', name:'Wind Anomaly – Weekly Charts',
      desc:'Wind 850, 500, 200 hPa anomaly', type:'date_hpa',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/atmosphere-wind-850hPa-anomaly-extended.png',
      hpa:[200,500,850],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa/32'),
  _Prod(id:909, catKey:'Weekly Charts(ERP)', name:'Sea Ice Concentration Mean (Arctic)',
      desc:'Mean Arctic sea ice concentration', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/sea-ice-concentration-mean-arctic.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/33'),
  _Prod(id:910, catKey:'Weekly Charts(ERP)', name:'Sea Ice Concentration Anomaly (Arctic)',
      desc:'Anomaly Arctic sea ice concentration', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/sea-ice-concentration-Anomaly-arctic.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/34'),
  _Prod(id:929, catKey:'Weekly Charts(ERP)', name:'MJO – Weekly Charts',
      desc:'MJO ISO', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/mjo-iso.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/54'),
  // ENSEMBLE PREDICTION
  _Prod(id:701, catKey:'Ensemble Prediction', name:'Geo Potential Height',
      desc:'Geo potential height ensemble', type:'date_hpa_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/geo-potential-height-ensemble.png',
      hpa:[200,500,700,850,925], utc:['00','12'],
      fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/12'),
  _Prod(id:702, catKey:'Ensemble Prediction', name:'Rainfall Probability',
      desc:'Rainfall probability ensemble', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/rainfall-probability-ensemble.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/13'),
  _Prod(id:703, catKey:'Ensemble Prediction', name:'MSLP – Ensemble Prediction',
      desc:'MSLP ensemble', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/mslp-ensemble.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/14'),
  _Prod(id:704, catKey:'Ensemble Prediction', name:'EPSgrams',
      desc:'EPSgrams charts – city wise', type:'date_utc_city',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/EPSgrams-ensemble.png',
      utc:['00','12'],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_city/15'),
  _Prod(id:710, catKey:'Ensemble Prediction', name:'Static Images – Tropical Cyclones',
      desc:'Tropical cyclones of static images', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/tropical-cyclones-static-images.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/special-products/statiscyclone'),
  // LOW PRESSURE SYSTEM
  _Prod(id:1001, catKey:'Low Pressure System', name:'Tropical Cyclone Tracks',
      desc:'Tropical cyclones of tracks', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/tropical-cyclones-tracks.png',
      baseUrl:''),
  _Prod(id:1002, catKey:'Low Pressure System', name:'Static Images – Tropical Cyclones',
      desc:'Tropical cyclones of static images', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/tropical-cyclones-static-images.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/special-products/statiscyclone'),
  _Prod(id:1003, catKey:'Low Pressure System', name:'Strike Probability – Tropical Cyclones',
      desc:'Tropical cyclones of strike probability', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/tropical-cyclones-strike-probability.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/STRIKE/strike.html'),
  _Prod(id:1004, catKey:'Low Pressure System', name:'TCHP – Tropical Cyclones',
      desc:'Tropical cyclones of TCHP', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/tropical-cyclones-tchp.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/ERP-OCEAN/ocean/TCHP_animation.gif'),
  // AIR QUALITY (subset)
  _Prod(id:1101, catKey:'Air Quality', name:'Dust Forecast – Global Model',
      desc:'Dust forecast information for global products', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/dust-forecast-global.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/7'),
  _Prod(id:1102, catKey:'Air Quality', name:'Minimum Visibility – Urban Model',
      desc:'Minimum Visibility Seasonal of Urban Model', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/minimum-visibility-seasonal-urban-model.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/103'),
  _Prod(id:1106, catKey:'Air Quality', name:'Temperature (330m) – Urban Model',
      desc:'Temperature for DM-Chem', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/temperature-urban-model.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/107'),
  _Prod(id:1112, catKey:'Air Quality', name:'IGI Delhi – Urban Model',
      desc:'IGI-Delhi for DM-Chem', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/IGI-Delhi-urban-model.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/113'),
  _Prod(id:1129, catKey:'Air Quality', name:'Global Visibility Fog Forecast – Urban Model',
      desc:'Global Visibility - Fog Forecast', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/vis_fcst.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/200'),
  _Prod(id:1130, catKey:'Air Quality', name:'Regional Visibility Fog Forecast – Urban Model',
      desc:'Regional Visibility - Fog Forecast', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/vis_reg.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/201'),
  // SPECIAL PRODUCTS (subset)
  _Prod(id:1201, catKey:'Special Products', name:'Lightning',
      desc:'Lightning (Special Products, Severe Weather)', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/severe-weather-lightning.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/65'),
  _Prod(id:1202, catKey:'Special Products', name:'Weather Outlook',
      desc:'Weather outlook (Special Products, Severe Weather)', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/severe-weather-weather-outlook.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/66'),
  _Prod(id:1203, catKey:'Special Products', name:'Heat Index',
      desc:'Heat Index (Special Products, Severe Weather)', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/severe-weather-heat-index.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/69'),
  _Prod(id:1217, catKey:'Special Products', name:'Solar and Wind Energy Products',
      desc:'Solar and wind energy products', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/solar-and-wind-energy-products.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/83'),
  _Prod(id:1224, catKey:'Special Products', name:'MJO Monitoring',
      desc:'MJO Monitoring of probabilistic products', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/probabilistic-products-mjo-monitoring.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/mjo-charts.php'),
  _Prod(id:1226, catKey:'Special Products', name:'RPLB Daily Forecast – Global Lightning Threat',
      desc:'Cloud to Ground lightning threat from RPLB scheme using NCUM-G model (12km resolution).', type:'date_only',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/accumalated.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_only/202'),
  // IMD SERVICES
  _Prod(id:1301, catKey:'IMD Services', name:'Wind Forecast – NCMRWF Products',
      desc:'Wind Forecast NCMRWF', type:'date_hpa_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Imd-wind.png',
      hpa:[200,500,700,850,925], utc:['00','12'],
      fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/205'),
  _Prod(id:1302, catKey:'IMD Services', name:'Rain Forecast – NCMRWF Products',
      desc:'Rain Forecast NCMRWF', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/rain-imd.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/206'),
  _Prod(id:1303, catKey:'IMD Services', name:'MSLP Forecast – NCMRWF Products',
      desc:'MSLP Forecast NCMRWF', type:'date_utc_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/mslp-imd.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/207'),
  // MITHUNA AI
  _Prod(id:1501, catKey:'Mithuna AI', name:'Pangu Wind Forecast – AIML Model',
      desc:'Pangu-Weather by Huawei. Initialised with NCMRWF analysis at 0.25° resolution.',
      type:'date_hpa_utc_fcst', subcat:'AIML Model',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/wind-forecast-Ai.png',
      hpa:[200,500,850], utc:['00','12'],
      fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/208'),
  _Prod(id:1505, catKey:'Mithuna AI', name:'GraphCast Wind Forecast – AIML Model',
      desc:'GraphCast (Google DeepMind). Initialised with NCMRWF analysis at 0.25° resolution.',
      type:'date_hpa_utc_fcst', subcat:'AIML Model',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/GraphCast-wind-Ai.png',
      hpa:[200,500,850], utc:['00','12'],
      fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_utc_fcst/212'),
  _Prod(id:1507, catKey:'Mithuna AI', name:'GraphCast Rain Forecast – AIML Model',
      desc:'GraphCast (Google DeepMind). Initialised with NCMRWF analysis at 0.25° resolution.',
      type:'date_utc_fcst', subcat:'AIML Model',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/GraphCast-rain-Ai.png',
      utc:['00','12'], fcst:[0,24,48,72,96,120,144,168,192,216,240],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_utc_fcst/214'),
  // BIMSTEC PRODUCTS
  _Prod(id:1601, catKey:'BIMSTEC Products', name:'Wind Forecast Deterministic – Bangladesh',
      desc:'Wind forecast deterministic (Bangladesh)', type:'date_hpa_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Bangladesh-wind.png',
      hpa:[850,925], fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_fcst/133'),
  _Prod(id:1602, catKey:'BIMSTEC Products', name:'Rain Forecast Deterministic – Bangladesh',
      desc:'Rain forecast deterministic (Bangladesh)', type:'date_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Bangladesh-Rain.png',
      fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_fcst/134'),
  _Prod(id:1613, catKey:'BIMSTEC Products', name:'Wind Forecast Deterministic – Nepal',
      desc:'Wind Forecast Deterministic (Nepal)', type:'date_hpa_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/Nepal-wind.png',
      hpa:[850,925], fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_fcst/154'),
  _Prod(id:1617, catKey:'BIMSTEC Products', name:'Wind Forecast Deterministic – Sri Lanka',
      desc:'Wind Forecast Deterministic (Srilanka)', type:'date_hpa_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/wind-forecast-srilanka.png',
      hpa:[850,925], fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_fcst/159'),
  _Prod(id:1621, catKey:'BIMSTEC Products', name:'Wind Forecast Deterministic – Thailand',
      desc:'Wind Forecast Deterministic (Thailand)', type:'date_hpa_fcst',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/wind-forecast-thailand.png',
      hpa:[850,925], fcst:[1,2,3,4,5,6,7,8,9,10],
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/date_hpa_fcst/164'),
  // OBSERVATIONS
  _Prod(id:1701, catKey:'Observations', name:'Rainfall – Observations',
      desc:'Observations of rainfall', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/rainfall-observations.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/93'),
  _Prod(id:1702, catKey:'Observations', name:'Radar – Observations',
      desc:'Observations of radar', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/radar-observations.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/94'),
  _Prod(id:1703, catKey:'Observations', name:'Max Temp – Observations',
      desc:'Max Temp of temperature in observations', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/temperature-max-temp-observations.png',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/96'),
  _Prod(id:1707, catKey:'Observations', name:'NRT 1-Hour Rainfall – Observations',
      desc:'NRT 1hour rainfall', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/nrt-1hour-rainfall-nrt-observations.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/100'),
  _Prod(id:1709, catKey:'Observations', name:'NRT 6-Hour Rainfall – Observations',
      desc:'NRT 6hour rainfall', type:'static',
      imageUrl:'https://nwp.ncmrwf.gov.in/ncmrwf_thumbnails_images/nrt-6hour-rainfall-nrt-observations.gif',
      baseUrl:'https://nwp.ncmrwf.gov.in/forecast-dashboard/product/static_links/102'),
];

// ─────────────────────────────────────────────────────────────────────────────
// URL BUILDER
// ─────────────────────────────────────────────────────────────────────────────
String _buildUrl(_Prod p, String date, String? utc, int? hpa, int? fcst, String? city) {
  if (p.isStatic) return p.baseUrl;
  String url = p.baseUrl;
  url = url.replaceAll('{date}', date.replaceAll('-', ''));
  url = url.replaceAll('{utc}',  utc  ?? '');
  url = url.replaceAll('{hpa}',  hpa?.toString() ?? '');
  url = url.replaceAll('{fcst}', fcst != null ? fcst.toString().padLeft(3, '0') : '');
  url = url.replaceAll('{city}', city ?? '');
  return url;
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashState();
}

class _DashState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {

  // ── resolved once per build so the entire screen uses one consistent palette
  late TimeTheme _tt;

  String  _selCat      = 'Wind';
  String  _search      = '';
  String  _catSearch   = '';
  bool    _drawerOpen  = false;

  final TextEditingController _searchCtrl    = TextEditingController();
  final TextEditingController _catSearchCtrl = TextEditingController();
  late AnimationController    _bgCtrl;
  late Animation<double>      _bgA;

  @override
  void initState() {
    super.initState();
    _tt = TimeTheme.of();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: _tt.statusBar,
      statusBarIconBrightness: Brightness.light,
    ));
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _bgA = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _searchCtrl.dispose();
    _catSearchCtrl.dispose();
    super.dispose();
  }

  List<_Prod> get _filtered {
    var list = _kProducts.where((p) => p.catKey == _selCat).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) =>
      p.name.toLowerCase().contains(q) ||
          p.desc.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  List<_Cat> get _filteredCats {
    if (_catSearch.isEmpty) return _kCats;
    final q = _catSearch.toLowerCase();
    return _kCats.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  _Cat get _curCat => _kCats.firstWhere((c) => c.id == _selCat);

  void _navigate(_Prod p) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChartViewerScreen(prod: p)));

  @override
  Widget build(BuildContext context) {
    _tt = TimeTheme.of(); // refresh palette on rebuild
    final w    = MediaQuery.of(context).size.width;
    final wide = w >= 700;
    return Scaffold(
      backgroundColor: _tt.bgGradient.first,
      body: Stack(children: [
        _ForecastBackground(anim: _bgA, tt: _tt),
        const Positioned.fill(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_T.scrim1, _T.scrim2, _T.scrim3],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        )),
        SafeArea(child: wide
            ? Row(children: [
          SizedBox(width: 280, child: _sidebar(closeable: false)),
          Expanded(child: _mainArea()),
        ])
            : _mainArea()),
        if (!wide && _drawerOpen) ...[
          GestureDetector(
              onTap: () => setState(() => _drawerOpen = false),
              child: Container(color: Colors.black54)),
          Positioned(
              top: 0, bottom: 0, left: 0, width: w * 0.82,
              child: SafeArea(child: _sidebar(closeable: true))),
        ],
      ]),
    );
  }

  Widget _topBar() {
    final wide = MediaQuery.of(context).size.width >= 700;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(children: [
        if (!wide) ...[
          _iconBtn(Icons.menu_rounded,
                  () => setState(() => _drawerOpen = !_drawerOpen)),
          const SizedBox(width: 10),
        ],
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NCMRWF',
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w900, letterSpacing: 0.6, height: 1.1),
                overflow: TextOverflow.ellipsis),
            TranslatedText('NWP Model Guidance',
                style: GoogleFonts.dmSans(
                    color: Colors.white70, fontSize: 11,
                    fontWeight: FontWeight.w500, letterSpacing: 0.1, height: 1.2),
                overflow: TextOverflow.ellipsis),
          ],
        )),
        // Period badge (Dawn / Day / Dusk / Night)
        _FrostCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          radius: 20, blurSigma: 10, bgOpacity: 0.22,
          tint: _tt.accent,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: _T.green,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _T.green.withOpacity(0.7), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 6),
            Text(_tt.periodLabel,
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ]),
        ),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    ),
  );

  Widget _mainArea() => Column(children: [
    _topBar(),
    const SizedBox(height: 14),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: _FrostCard(
        padding: EdgeInsets.zero,
        radius: 16, blurSigma: 14, bgOpacity: 0.18,
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: tl('Search products…'),
            hintStyle: GoogleFonts.dmSans(color: _T.white38, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: _T.white38, size: 18),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                icon: const Icon(Icons.clear_rounded, color: _T.white38, size: 16),
                onPressed: () { setState(() { _searchCtrl.clear(); _search = ''; }); })
                : null,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: InputBorder.none,
          ),
        ),
      ),
    ),
    const SizedBox(height: 14),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Container(width: 3, height: 22,
            decoration: BoxDecoration(
                color: _tt.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Text(_curCat.name,
            style: GoogleFonts.dmSans(
                color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w800))),
        _FrostCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          radius: 20, blurSigma: 10, bgOpacity: 0.20,
          hasBorder: true,
          child: Text('${_filtered.length} ${tl("products")}',
              style: GoogleFonts.dmSans(
                  color: _tt.accent, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    ),
    const SizedBox(height: 10),
    Expanded(child: _productList()),
  ]);

  Widget _productList() {
    final list = _filtered;
    if (list.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.search_off_rounded, size: 48, color: _T.white38),
        const SizedBox(height: 12),
        TranslatedText('No products found',
            style: GoogleFonts.dmSans(color: _T.white38, fontSize: 15)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
      itemCount: list.length,
      itemBuilder: (_, i) =>
          _ProductCard(prod: list[i], onViewChart: _navigate, tt: _tt),
    );
  }

  Widget _sidebar({required bool closeable}) {
    final cats = _filteredCats;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          // Use the appBarBg tint from TimeTheme for the sidebar backdrop
          color: _tt.appBarBg.withOpacity(0.55),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.layers_rounded, color: _tt.accent, size: 18),
                    const SizedBox(width: 8),
                    TranslatedText('Categories',
                        style: GoogleFonts.dmSans(
                            color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  ]),
                  const SizedBox(height: 2),
                  TranslatedText('Select a product category',
                      style: GoogleFonts.dmSans(
                          color: _T.white38, fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  _FrostCard(
                    padding: EdgeInsets.zero,
                    radius: 12, blurSigma: 10, bgOpacity: 0.15,
                    child: TextField(
                      controller: _catSearchCtrl,
                      onChanged: (v) => setState(() => _catSearch = v),
                      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: tl('Search categories…'),
                        hintStyle: GoogleFonts.dmSans(color: _T.white38, fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, color: _T.white38, size: 16),
                        suffixIcon: _catSearch.isNotEmpty
                            ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: _T.white38, size: 14),
                            onPressed: () => setState(() {
                              _catSearchCtrl.clear();
                              _catSearch = '';
                            }))
                            : null,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Divider(color: _tt.divider, height: 1),
            Expanded(
              child: cats.isEmpty
                  ? Center(child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.search_off_rounded, color: _T.white38, size: 32),
                  const SizedBox(height: 10),
                  TranslatedText('No categories found',
                      style: GoogleFonts.dmSans(color: _T.white38, fontSize: 12),
                      textAlign: TextAlign.center),
                ]),
              ))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: cats.length,
                itemBuilder: (_, i) {
                  final cat   = cats[i];
                  final isSel = _selCat == cat.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selCat = cat.id;
                        _search = '';
                        _searchCtrl.clear();
                      });
                      if (closeable) setState(() => _drawerOpen = false);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        // Selected row: use theme cardBg
                        color: isSel ? _tt.cardBg : Colors.transparent,
                        border: isSel
                            ? Border.all(color: Colors.white.withOpacity(0.30), width: 1)
                            : null,
                      ),
                      child: Row(children: [
                        Icon(cat.icon,
                            size: 18,
                            color: isSel ? _tt.accent : Colors.white.withOpacity(0.55)),
                        const SizedBox(width: 12),
                        Expanded(child: TranslatedText(cat.name,
                            style: GoogleFonts.dmSans(
                                color: isSel ? Colors.white : Colors.white.withOpacity(0.75),
                                fontSize: 13,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w400))),
                        if (isSel)
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(color: _tt.accent, shape: BoxShape.circle),
                          ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final _Prod prod;
  final void Function(_Prod) onViewChart;
  final TimeTheme tt;
  const _ProductCard({required this.prod, required this.onViewChart, required this.tt});

  @override
  Widget build(BuildContext context) {
    final p = prod;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: _FrostCard(
        padding: EdgeInsets.zero,
        radius: 22, blurSigma: 16, bgOpacity: 0.18,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Stack(children: [
              AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(p.imageUrl, fit: BoxFit.cover,
                    loadingBuilder: (_, child, prog) => prog == null ? child
                        : Container(
                        color: _T.white10,
                        child: Center(child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: tt.accent.withOpacity(0.6),
                            value: prog.expectedTotalBytes != null
                                ? prog.cumulativeBytesLoaded / prog.expectedTotalBytes!
                                : null))),
                    errorBuilder: (_, __, ___) => Container(
                        color: _T.white10,
                        child: const Center(child: Icon(Icons.image_not_supported_outlined,
                            color: _T.white20, size: 36)))),
              ),
              Positioned.fill(child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.55)])))),
              Positioned(top: 10, right: 10,
                  child: _FrostCard(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    radius: 8, blurSigma: 10, bgOpacity: 0.30,
                    child: Text(
                        p.type.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.dmSans(
                            fontSize: 8, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: 0.8)),
                  )),
              if (p.subcat == 'AIML Model')
                Positioned(top: 10, left: 10,
                    child: _FrostCard(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      radius: 8, blurSigma: 8, bgOpacity: 0.60,
                      tint: tt.accent,
                      child: Text('AI·ML',
                          style: GoogleFonts.dmSans(
                              fontSize: 8, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: 1.0)),
                    )),
            ]),
          ),
          // Accent divider now uses the TimeTheme accent gradient
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [tt.accent, tt.sheetGrad1]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TranslatedText(p.name,
                  style: GoogleFonts.dmSans(
                      color: Colors.white, fontWeight: FontWeight.w800,
                      fontSize: 15, height: 1.3)),
              const SizedBox(height: 5),
              TranslatedText(p.desc,
                  style: GoogleFonts.dmSans(color: _T.white60, fontSize: 12, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              _chips(p, tt),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => onViewChart(p),
                child: _FrostCard(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  radius: 30, blurSigma: 12, bgOpacity: 0.22,
                  tint: tt.accent,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    TranslatedText('View Charts',
                        style: GoogleFonts.dmSans(
                            color: Colors.white, fontWeight: FontWeight.w700,
                            fontSize: 14, letterSpacing: 0.2)),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chips(_Prod p, TimeTheme tt) {
    final items = <Widget>[];
    if (p.hasHpa)   items.add(_Chip(Icons.layers_rounded,        '${p.hpa.length} ${tl("hPa levels")}', tt));
    if (p.hasUtc)   items.add(_Chip(Icons.access_time_rounded,   p.utc.map((u) => '${u}Z').join(', '), tt));
    if (p.hasFcst)  items.add(_Chip(Icons.schedule_rounded,      '+${p.fcst.last}h ${tl("forecast")}', tt));
    if (p.hasCity)  items.add(_Chip(Icons.location_city_rounded, '${p.cities.length} ${tl("cities")}', tt));
    if (p.isStatic) items.add(_Chip(Icons.image_rounded,         tl('Static image'), tt));
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: items);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final TimeTheme tt;
  const _Chip(this.icon, this.label, this.tt);

  @override
  Widget build(BuildContext context) => _FrostCard(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    radius: 20, blurSigma: 6, bgOpacity: 0.14,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: tt.accent),
      const SizedBox(width: 5),
      TranslatedText(label,
          style: GoogleFonts.dmSans(
              fontSize: 11, color: _T.white70, fontWeight: FontWeight.w500)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED BACKGROUND — now driven by TimeTheme colours
// ─────────────────────────────────────────────────────────────────────────────
class _ForecastBackground extends StatelessWidget {
  final Animation<double> anim;
  final TimeTheme tt;
  const _ForecastBackground({required this.anim, required this.tt});

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Stack(children: [
        Container(decoration: BoxDecoration(gradient: tt.linearGradient)),
        Positioned(
          top: -80 + anim.value * 40,
          right: -60 + anim.value * 30,
          child: Container(
            width: s.width * 0.70,
            height: s.width * 0.70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                tt.accent.withOpacity(0.18),
                tt.accent.withOpacity(0.05),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: 60 - anim.value * 40,
          left: -80 + anim.value * 20,
          child: Container(
            width: s.width * 0.65,
            height: s.width * 0.65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                tt.sheetGrad2.withOpacity(0.28),
                tt.sheetGrad2.withOpacity(0.07),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHART VIEWER SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ChartViewerScreen extends StatefulWidget {
  final _Prod prod;
  const ChartViewerScreen({super.key, required this.prod});
  @override State<ChartViewerScreen> createState() => _ChartViewerState();
}

class _ChartViewerState extends State<ChartViewerScreen>
    with SingleTickerProviderStateMixin {

  late String  _date;
  String?      _utc;
  int?         _hpa;
  int?         _fcst;
  String?      _cityUrl;

  WebViewController? _webCtrl;
  bool   _loading    = false;
  int    _progress   = 0;
  int    _httpStatus = 0;
  bool   _hasError   = false;
  String _errorMsg   = '';
  bool   _webReady   = false;

  late AnimationController _bgCtrl;
  late Animation<double>   _bgA;
  late TimeTheme           _tt;

  @override
  void initState() {
    super.initState();
    _tt = TimeTheme.of();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _bgA = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);

    final p = widget.prod;
    _date    = _today();
    _utc     = p.utc.isNotEmpty  ? p.utc.first  : null;
    _hpa     = p.hpa.isNotEmpty  ? p.hpa.first  : null;
    _fcst    = p.fcst.isNotEmpty ? p.fcst.first : null;
    if (p.cities.isNotEmpty) {
      _cityUrl = p.cityUrls.isNotEmpty ? p.cityUrls.first : p.cities.first;
    }
    _initWebView();
  }

  @override
  void dispose() { _bgCtrl.dispose(); super.dispose(); }

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-'
        '${d.day.toString().padLeft(2,'0')}';
  }

  String get _builtUrl =>
      _buildUrl(widget.prod, _date, _utc, _hpa, _fcst, _cityUrl);

  void _initWebView() {
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_tt.bgGradient.first)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted:  (_) => setState(() {
          _loading = true; _hasError = false;
          _progress = 0; _httpStatus = 0;
        }),
        onProgress:     (p) => setState(() => _progress = p),
        onPageFinished: (_) => setState(() => _loading = false),
        onHttpError: (HttpResponseError e) => setState(() {
          _httpStatus = e.response?.statusCode ?? 0;
          _hasError = true; _loading = false;
          _errorMsg = _httpMsg(_httpStatus);
        }),
        onWebResourceError: (WebResourceError e) {
          if (e.isForMainFrame ?? true) setState(() {
            _hasError = true; _loading = false; _errorMsg = _webMsg(e);
          });
        },
        onNavigationRequest: (_) => NavigationDecision.navigate,
      ));
    setState(() { _webCtrl = ctrl; _webReady = true; });
    ctrl.loadRequest(Uri.parse(_builtUrl));
  }

  void _reload() {
    if (_webCtrl == null) { _initWebView(); return; }
    setState(() { _loading = true; _hasError = false; _progress = 0; });
    _webCtrl!.loadRequest(Uri.parse(_builtUrl));
  }

  String _httpMsg(int c) {
    if (c == 304) return 'HTTP 304 — Served from cache. Chart should still display.';
    if (c == 401 || c == 403) return 'HTTP $c — Access denied.';
    if (c == 404) return 'HTTP 404 — Chart not found for selected parameters.';
    if (c >= 500) return 'HTTP $c — Server error. Try again later.';
    return 'HTTP $c — Unexpected response.';
  }

  String _webMsg(WebResourceError e) {
    final d = e.description.toLowerCase();
    if (d.contains('err_internet_disconnected') ||
        d.contains('err_network_changed')) return 'No internet connection.';
    if (d.contains('err_name_not_resolved')) return 'Could not reach the server.';
    if (d.contains('timed_out')) return 'Connection timed out.';
    if (d.contains('err_ssl')) return 'SSL certificate error.';
    return 'Failed to load.\n${e.description}';
  }

  @override
  Widget build(BuildContext context) {
    _tt = TimeTheme.of();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: _tt.statusBar,
      statusBarIconBrightness: Brightness.light,
    ));
    return Scaffold(
      backgroundColor: _tt.bgGradient.first,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: _tt.appBarBg.withOpacity(0.55),
                border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.12))),
              ),
            ),
          ),
        ),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.prod.name,
              style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (widget.prod.desc.isNotEmpty)
            Text(widget.prod.desc,
                style: GoogleFonts.dmSans(fontSize: 11, color: _T.white60),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          _appBarBtn(Icons.refresh_rounded, () => _webCtrl?.reload()),
          _appBarBtn(Icons.arrow_back_ios_rounded, () async {
            if (_webCtrl != null && await _webCtrl!.canGoBack()) {
              _webCtrl!.goBack();
            }
          }),
          _appBarBtn(Icons.arrow_forward_ios_rounded, () async {
            if (_webCtrl != null && await _webCtrl!.canGoForward()) {
              _webCtrl!.goForward();
            }
          }),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(children: [
        _ForecastBackground(anim: _bgA, tt: _tt),
        const Positioned.fill(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [_T.scrim1, _T.scrim2, _T.scrim3],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        )),
        SafeArea(child: Column(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _loading
                ? LinearProgressIndicator(
                key: const ValueKey('bar'),
                value: _progress > 0 ? _progress / 100 : null,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation<Color>(_tt.accent),
                minHeight: 2)
                : const SizedBox(key: ValueKey('empty'), height: 2),
          ),
          Expanded(child: _hasError
              ? _errorState()
              : _webReady
              ? Stack(children: [
            WebViewWidget(controller: _webCtrl!),
            if (_loading) _loadingOverlay(),
          ])
              : _loadingOverlay()),
        ])),
      ]),
    );
  }

  Widget _appBarBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
        ),
      ),
    ),
  );

  Widget _loadingOverlay() => Container(
    color: Colors.transparent,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      _FrostCard(
        padding: const EdgeInsets.all(22),
        radius: 50, blurSigma: 20, bgOpacity: 0.20,
        child: CircularProgressIndicator(
            value: _progress > 0 ? _progress / 100 : null,
            color: _tt.accent, strokeWidth: 3),
      ),
      const SizedBox(height: 18),
      Text(_progress > 0 ? 'Loading… $_progress%' : 'Connecting to server…',
          style: GoogleFonts.dmSans(color: _T.white60, fontSize: 13)),
      if (_progress > 0) ...[
        const SizedBox(height: 12),
        SizedBox(
          width: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: _progress / 100,
                backgroundColor: Colors.white.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation<Color>(_tt.accent),
                minHeight: 3),
          ),
        ),
      ],
    ])),
  );

  Widget _errorState() => Center(
    child: Padding(padding: const EdgeInsets.all(36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _FrostCard(
          padding: const EdgeInsets.all(22),
          radius: 50, blurSigma: 16, bgOpacity: 0.18,
          tint: _httpStatus == 304 ? Colors.blue : Colors.red,
          child: Icon(
              _httpStatus == 304 ? Icons.info_outline_rounded
                  : _httpStatus == 404 ? Icons.find_in_page_outlined
                  : Icons.cloud_off_rounded,
              size: 44, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          _httpStatus == 304 ? 'Cache Response (304)'
              : _httpStatus == 404 ? 'Chart Not Found (404)'
              : _httpStatus > 0 ? 'Server Error ($_httpStatus)'
              : 'Connection Error',
          style: GoogleFonts.dmSans(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(_errorMsg,
            style: GoogleFonts.dmSans(color: _T.white60, fontSize: 12, height: 1.6),
            textAlign: TextAlign.center),
        const SizedBox(height: 28),
        if (_httpStatus == 304) ...[
          _actionBtn(Icons.visibility_rounded, 'Show Anyway',
                  () => setState(() => _hasError = false)),
          const SizedBox(height: 10),
        ],
        _actionBtn(Icons.refresh_rounded, 'Try Again', _reload, outlined: true),
      ]),
    ),
  );

  Widget _actionBtn(IconData icon, String label, VoidCallback onPressed,
      {bool outlined = false}) {
    if (outlined) {
      return GestureDetector(
        onTap: onPressed,
        child: _FrostCard(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          radius: 28, blurSigma: 12, bgOpacity: 0.15,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.dmSans(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      );
    }
    return GestureDetector(
      onTap: onPressed,
      child: _FrostCard(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
        radius: 28, blurSigma: 12, bgOpacity: 0.30,
        tint: _tt.accent,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.dmSans(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
      ),
    );
  }
}