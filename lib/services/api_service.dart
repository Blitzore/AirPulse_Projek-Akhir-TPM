import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service untuk mengambil data AQI, cuaca, dan kurs dari API publik.
class ApiService {
  /// Mengambil data AQI real-time dan cuaca berdasarkan koordinat.
  static Future<Map<String, dynamic>?> getAQIData(double lat, double lon) async {
    final aqiUrl = Uri.parse(
      'https://air-quality-api.open-meteo.com/v1/air-quality'
      '?latitude=$lat&longitude=$lon&current=european_aqi,pm10,pm2_5,carbon_monoxide',
    );
    final weatherUrl = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m',
    );

    try {
      final responses = await Future.wait([http.get(aqiUrl), http.get(weatherUrl)]);
      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final aqiData = jsonDecode(responses[0].body);
        final weatherData = jsonDecode(responses[1].body);
        aqiData['current']['temperature_2m'] = weatherData['current']['temperature_2m'];
        aqiData['current']['relative_humidity_2m'] = weatherData['current']['relative_humidity_2m'];
        return aqiData;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Mengambil prakiraan AQI per jam untuk timeline perencana.
  static Future<Map<String, dynamic>?> getHourlyAQIForecast(double lat, double lon) async {
    final url = Uri.parse(
      'https://air-quality-api.open-meteo.com/v1/air-quality'
      '?latitude=$lat&longitude=$lon&hourly=european_aqi&timezone=auto&forecast_days=4',
    );
    try {
      final response = await http.get(url);
      return response.statusCode == 200 ? jsonDecode(response.body) : null;
    } catch (_) {
      return null;
    }
  }

  /// Mengambil kurs mata uang terbaru berbasis IDR.
  static Future<Map<String, dynamic>?> getExchangeRates() async {
    final url = Uri.parse('https://open.er-api.com/v6/latest/IDR');
    try {
      final response = await http.get(url);
      return response.statusCode == 200 ? jsonDecode(response.body) : null;
    } catch (_) {
      return null;
    }
  }
}
