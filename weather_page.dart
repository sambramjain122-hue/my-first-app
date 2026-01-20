import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// Weather code mapping for icons and description
const Map<int, Map<String, dynamic>> weatherCodeMap = {
  0: {"desc": "Clear sky", "icon": "☀"},
  1: {"desc": "Mainly clear", "icon": "🌤"},
  2: {"desc": "Partly cloudy", "icon": "⛅"},
  3: {"desc": "Overcast", "icon": "☁"},
  45: {"desc": "Fog", "icon": "🌫"},
  48: {"desc": "Depositing rime fog", "icon": "🌫"},
  51: {"desc": "Drizzle: Light", "icon": "🌦"},
  53: {"desc": "Drizzle: Moderate", "icon": "🌧"},
  55: {"desc": "Drizzle: Dense", "icon": "🌧"},
  61: {"desc": "Rain: Light", "icon": "🌧"},
  63: {"desc": "Rain: Moderate", "icon": "🌧"},
  65: {"desc": "Rain: Heavy", "icon": "🌧"},
  71: {"desc": "Snow fall: Light", "icon": "🌨"},
  73: {"desc": "Snow fall: Moderate", "icon": "❄"},
  75: {"desc": "Snow fall: Heavy", "icon": "❄"},
  80: {"desc": "Rain showers: Light", "icon": "🌧"},
  81: {"desc": "Rain showers: Moderate", "icon": "🌧"},
  82: {"desc": "Rain showers: Violent", "icon": "⛈"},
  95: {"desc": "Thunderstorm", "icon": "⚡"},
};

class WeatherPage extends StatefulWidget {
  const WeatherPage({Key? key}) : super(key: key);

  @override
  _WeatherPageState createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  bool loading = true;
  bool error = false;
  String cityName = "Your Location";
  Map<String, dynamic>? currentWeather;
  List<Map<String, dynamic>> hourlyForecast = [];
  List<Map<String, dynamic>> dailyForecast = [];
  bool isDay = true;

  // Animation controllers
  late AnimationController _sunMoonController;

  Future<void> 
  enableLocationPermission() async {
  // Check if location services are enabled
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    await Geolocator.openLocationSettings();
    return;
  }

  // Check permission status
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  // If user permanently denied
  if (permission == LocationPermission.deniedForever) {
    await Geolocator.openAppSettings();
  }
}

  @override
  void initState() {
    super.initState();
    _sunMoonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    enableLocationPermission();
     fetchWeatherByCity("Belthangady");
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sunMoonController.dispose();
    super.dispose();
  }

  Future<void> fetchWeatherByCity(String city) async {
    setState(() {
      loading = true;
      error = false;
    });

    try {
      final geoUrl =
          "https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(city)}&count=5&language=en&format=json";
      final geoResponse = await http.get(Uri.parse(geoUrl));
      final geoData = json.decode(geoResponse.body);

      if (geoData["results"] == null || geoData["results"].isEmpty) {
        throw Exception("City not found");
      }

      final location = geoData["results"][0];
      final latitude = location["latitude"];
      final longitude = location["longitude"];
      final fullName =
          location["country"] != null ? "${location["name"]}, ${location["country"]}" : location["name"];

      await fetchWeatherData(latitude, longitude, fullName);
    } catch (e) {
      setState(() {
        error = true;
        loading = false;
      });
    }
  }

  Future<void> fetchWeatherData(double lat, double lon, String city) async {
    setState(() {
      loading = true;
      error = false;
    });

    try {
      final url =
          "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&hourly=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=6";

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      final current = data["current_weather"];
      final currentTime = DateTime.parse(current["time"]);
      final hourly = data["hourly"];
      final hourlyTimes = List<String>.from(hourly["time"]);
      final hourlyIndex = hourlyTimes.indexWhere((time) => DateTime.parse(time).isAfter(currentTime));
      final hourlyIsDay = hourly["is_day"][hourlyIndex == -1 ? 0 : hourlyIndex] == 1;

      // Current weather
      setState(() {
        cityName = city;
        currentWeather = current;
        isDay = hourlyIsDay;

        hourlyForecast = List.generate(
          24,
          (i) {
            final index = i + (hourlyIndex == -1 ? 0 : hourlyIndex);
            if (index >= hourlyTimes.length) return {};
            return {
              "time": hourlyTimes[index],
              "temp": hourly["temperature_2m"][index],
              "apparent": hourly["apparent_temperature"][index],
              "humidity": hourly["relative_humidity_2m"][index],
              "weatherCode": hourly["weather_code"][index],
            };
          },
        );

        final daily = data["daily"];
        dailyForecast = List.generate(5, (i) {
          final index = i + 1;
          if (index >= daily["time"].length) return {};
          return {
            "day": daily["time"][index],
            "max": daily["temperature_2m_max"][index],
            "min": daily["temperature_2m_min"][index],
            "weatherCode": daily["weather_code"][index],
          };
        });

        loading = false;
      });
    } catch (e) {
      setState(() {
        error = true;
        loading = false;
      });
    }
  }

  Widget buildWeatherCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget buildHourlyForecast() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: hourlyForecast.length,
        itemBuilder: (context, index) {
          final hourData = hourlyForecast[index];
          if (hourData.isEmpty) return const SizedBox();
          final hour = DateTime.parse(hourData["time"]).hour;
          final code = hourData["weatherCode"];
          final icon = weatherCodeMap[code]?["icon"] ?? "";
          final temp = hourData["temp"].round();
          return Container(
            width: 100,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("$hour:00", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text("$temp°C", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildDailyForecast() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: dailyForecast.map((dayData) {
        final date = DateTime.parse(dayData["day"]);
        final dayName = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][date.weekday % 7];
        final icon = weatherCodeMap[dayData["weatherCode"]]?["icon"] ?? "";
        return Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              children: [
                Text(dayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text("${dayData["max"].round()}° / ${dayData["min"].round()}°",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: isDay
                  ? const LinearGradient(colors: [Color(0xFF87CEEB), Color(0xFFB0E0E6)])
                  : const LinearGradient(colors: [Color(0xFF1C2333), Color(0xFF3C4B64)]),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("Error fetching weather data"),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                  onPressed:() => fetchWeatherByCity("Belthangady"),
                                  child: const Text("Retry")),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              // Search
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        hintText: "Enter city name...",
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.8),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(50),
                                            borderSide: BorderSide.none),
                                      ),
                                      onSubmitted: (value) {
                                        if (value.isNotEmpty) fetchWeatherByCity(value);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: const CircleBorder(),
                                        padding: const EdgeInsets.all(16),
                                      ),
                                      onPressed: () {
                                        if (_searchController.text.isNotEmpty) {
                                          fetchWeatherByCity(_searchController.text);
                                        }
                                      },
                                      child: const Icon(Icons.search)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Current weather
                              Text(cityName,
                                  style: const TextStyle(
                                      fontSize: 28, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              Text(
                                weatherCodeMap[currentWeather?["weathercode"] ?? 0]?["icon"] ??
                                    "",
                                style: const TextStyle(fontSize: 72),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${currentWeather?["temperature"]?.round() ?? "--"}°C",
                                style: const TextStyle(
                                    fontSize: 64, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              // Weather details cards
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  buildWeatherCard(
                                      "Feels Like",
                                      "${currentWeather?["temperature"]?.round() ?? "--"}°C"),
                                  buildWeatherCard(
                                      "Humidity",
                                      "${hourlyForecast.isNotEmpty ? hourlyForecast[0]["humidity"] : "--"}%"),
                                  buildWeatherCard(
                                      "Wind",
                                      "${currentWeather?["windspeed"]?.round() ?? "--"} km/h"),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Hourly forecast
                              buildHourlyForecast(),
                              const SizedBox(height: 24),
                              // 5-day forecast
                              buildDailyForecast(),
                            ],
                          ),
                        ),
            ),
          )
        ],
      ),
    );
  }
}