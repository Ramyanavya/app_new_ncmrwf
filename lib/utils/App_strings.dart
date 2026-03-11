

class AppStrings {
  // ── App ────────────────────────────────────────────────────────
  static const String appName           = 'NCMRWF Weather';
  static const String fetchingLocation  = 'Fetching location...';
  static const String retry             = 'Retry';
  static const String unableToLoad      = 'Unable to load weather data';
  static const String close             = 'Close';

  // ── Forecast screen ───────────────────────────────────────────
  static const String weatherForecast   = 'Weather Forecast';
  static const String feelsLike         = 'Feels like';
  static const String humidity          = 'Humidity';
  static const String wind              = 'Wind';
  static const String pressure          = 'Pressure';           // ← was hardcoded
  static const String level             = 'Level';
  static const String tenDayForecast    = '10-Day Forecast';
  static const String now               = 'Now';
  static const String pressureLevel     = 'Pressure Level';
  static const String temperatureTrend  = 'Temperature Trend';
  static const String tapToSelectDay    = 'Tap to select day';
  static const String direction         = 'Direction';
  static const String moderate          = 'Moderate';
  static const String high              = 'High';
  static const String low               = 'Low';
  static const String min               = 'Min';
  static const String max               = 'Max';
  static const String rainfall          = 'Rainfall';
  static const String updated           = 'Updated';

  // ── Weather conditions ────────────────────────────────────────
  static const String sunny             = 'Sunny';
  static const String cloudy            = 'Cloudy';
  static const String partlyCloudy      = 'Partly Cloudy';
  static const String rainy             = 'Rainy';
  static const String stormy            = 'Stormy';
  static const String mist              = 'Mist';
  static const String foggy             = 'Foggy';
  static const String hazy              = 'Hazy';
  static const String windy             = 'Windy';
  static const String cold              = 'Cold';
  static const String hot               = 'Hot';
  static const String clear             = 'Clear';
  static const String overcast          = 'Overcast';
  static const String drizzle           = 'Drizzle';
  static const String thunderstorm      = 'Thunderstorm';
  static const String snow              = 'Snow';

  // ── Days of week ──────────────────────────────────────────────
  static const String monday            = 'Monday';
  static const String tuesday           = 'Tuesday';
  static const String wednesday         = 'Wednesday';
  static const String thursday          = 'Thursday';
  static const String friday            = 'Friday';
  static const String saturday          = 'Saturday';
  static const String sunday            = 'Sunday';

  // ── Day abbreviations (used in forecast strip) ────────────────
  static const String mon               = 'Mon';
  static const String tue               = 'Tue';
  static const String wed               = 'Wed';
  static const String thu               = 'Thu';
  static const String fri               = 'Fri';
  static const String sat               = 'Sat';
  static const String sun               = 'Sun';

  // ── Months ───────────────────────────────────────────────────
  static const String jan               = 'Jan';
  static const String feb               = 'Feb';
  static const String mar               = 'Mar';
  static const String apr               = 'Apr';
  static const String may               = 'May';
  static const String jun               = 'Jun';
  static const String jul               = 'Jul';
  static const String aug               = 'Aug';
  static const String sep               = 'Sep';
  static const String oct               = 'Oct';
  static const String nov               = 'Nov';
  static const String dec               = 'Dec';

  // ── Nav tabs ──────────────────────────────────────────────────
  static const String forecast          = 'Home';
  static const String products          = 'Products';
  static const String favorites         = 'Favorites';
  static const String settings          = 'Settings';

  // ── Products / Map screen ─────────────────────────────────────
  static const String weatherMap        = 'Weather Map';
  static const String mapDate           = 'Map date';
  static const String temperature       = 'Temperature';
  static const String switchLocation    = 'Switch Location';
  static const String active            = 'Active';
  static const String temperatureAnalysis = 'Temperature Analysis';
  static const String windAnalysis        = 'Wind Analysis';
  static const String humidityAnalysis    = 'Humidity Analysis';
  static const String surfaceTemp         = 'Surface Temp';
  static const String tenDaySummary       = '10-Day Summary Table';
  static const String loadForecastFirst   = 'Load forecast first from the Forecast tab';
  static const String connectAPI          = 'Connect API to render chart';
  static const String meteogram           = 'Meteogram';
  static const String verticalProfile     = 'Vertical Profile';
  static const String epsgram            = 'EPSgram';
  static const String viewDetails         = 'View Details';
  static const String accRainfall         = 'Acc. Rainfall';

  // ── Favorites screen ──────────────────────────────────────────
  static const String noFavorites           = 'No favorites yet';
  static const String addFavoritesHint      = 'Search and add locations to favorites';
  static const String addLocation           = 'Add Location';
  static const String addCurrent            = 'Add Current';
  static const String locationAdded         = 'Added to favorites!';
  static const String locationAlreadyAdded  = 'Location already in favorites';
  static const String favoritesLimitReached = 'Favorites limit reached (max 5)';
  static const String favoritesFull         = 'Limit reached';
  static const String searchHint            = 'Search city, village, district...';
  static const String useDefaultLocation    = 'Use default location (New Delhi)';
  static const String noFavoritesYet        = 'No favorites yet. Add from the Favorites tab.';

  // ── Settings screen ───────────────────────────────────────────
  static const String language          = 'Language / भाषा';
  static const String about             = 'About';
  static const String aboutApp          = 'About the App';
  static const String aboutVersion      = 'Version 1.0.0';
  static const String faqs             = 'FAQs';
  static const String faqsSub          = 'Frequently Asked Questions';
  static const String privacy           = 'Privacy Policy';
  static const String privacySub        = 'How we handle your data';
  static const String dataSource        = 'Data Source';
  static const String dataSourceTitle   = 'NCMRWF NWP Data';

  static const String aboutContent =
      'NCMRWF Weather Forecast App provides real-time weather data from the '
      'National Centre for Medium Range Weather Forecasting.\n\n'
      'Version: 1.0.0\n'
      'Data: NWP Model (925mb, 850mb, 700mb, 500mb, 200mb)\n'
      'Coverage: India and surrounding regions';

  static const String privacyContent =
      'The National Centre for Medium Range Weather Forecasting (NCMRWF) is committed to protecting your privacy. We collect minimal personal data necessary for providing our services and do not share your information with third parties without your consent. Your data is used solely for analytical purposes to improve our services. By using our website, you agree to the collection and use of information as outlined in this policy.';

  static const String dataSourceDesc =
      'Weather data from National Centre for Medium Range Weather Forecasting '
      '(NCMRWF), Ministry of Earth Sciences, Government of India.';

  // ── FAQs ──────────────────────────────────────────────────────
  static const List<Map<String, String>> faqList = [
    {
      'q': 'What data does this app use?',
      'a': 'The app uses NWP data from NCMRWF — temperature, wind and humidity '
          'at 925mb, 850mb, 700mb, 500mb and 200mb pressure levels.',
    },
    {
      'q': 'What is a pressure level?',
      'a': '925mb is near the surface (~750m), while 200mb is very high (~12km). '
          'For surface weather, 925mb is most relevant.',
    },
    {
      'q': 'How accurate is the forecast?',
      'a': 'NCMRWF NWP model provides forecasts up to 10 days. '
          'Short-range (1-3 days) forecasts are most accurate.',
    },
    {
      'q': 'How do I change the language?',
      'a': 'Go to Settings → Language and tap English or Hindi. '
          'The entire app changes immediately.',
    },
    {
      'q': 'How often is the data updated?',
      'a': 'NC data files update every 6 or 12 hours. Pull down to refresh.',
    },
  ];

  // Products screen labels (used as map keys — translated at runtime)
  static const String surfaceTempLabel   = 'Surface Temp';
  static const String feelsLikeLabel     = 'Feels Like';
  static const String minTenDay          = 'Min (10-day)';
  static const String maxTenDay          = 'Max (10-day)';
  static const String speed              = 'Speed';
  static const String relativeHumidity   = 'Relative Humidity';
  static const String category           = 'Category';
  static const String day                = 'Day';
  static const String temp               = 'Temp';
  static const String today              = 'Today';
}