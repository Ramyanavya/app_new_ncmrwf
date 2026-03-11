import '../models/weather_model.dart';
import 'local_notification_service.dart';

class WeatherAlertService {
  static String _lastAlert = "";

  static Future<void> checkAndSend(CurrentWeather weather) async {
    String alert = "";

    final temp = weather.temperatureC;
    final condition = weather.condition.toLowerCase();

    if (condition.contains("storm") || condition.contains("thunder")) {
      alert = "⚠️ Storm Alert! Stay indoors and stay safe.";
    } else if (condition.contains("rain")) {
      alert = "🌧️ It is rainy. Don’t forget an umbrella.";
    } else if (temp >= 35) {
      alert = "☀️ It is very hot today. Stay hydrated.";
    } else if (temp <= 15) {
      alert = "❄️ Cold weather today. Stay warm.";
    } else if (condition.contains("sunny")) {
      alert = "☀️ Clear sunny weather today.";
    }

    if (alert.isNotEmpty && alert != _lastAlert) {
      _lastAlert = alert;
      await LocalNotificationService.showWeatherAlert(alert);
    }
  }
}