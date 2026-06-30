import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../chatbot/chatbot_screen.dart';
import 'pollutant_detail_screen.dart';

/// Dashboard utama — menampilkan data AQI real-time, cuaca, polutan,
/// serta mendengarkan sensor gyroscope (shake-to-refresh) dan
/// accelerometer (deteksi aktivitas lari + peringatan polusi).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? aqiData;
  bool isLoading = true;
  String locationMsg = 'Mencari lokasi...';

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;

  DateTime _lastShakeTime = DateTime.now();
  int _shakeCount = 0;

  bool _isMoving = false;
  DateTime _lastNotifTime = DateTime.now().subtract(const Duration(days: 1));

  // --- ML K-Nearest Neighbors (KNN) Variables ---
  final List<double> _magWindow = [];
  final int _windowSize = 25; // Jumlah sampel untuk ekstraksi fitur
  
  // Dataset KNN: [Mean, Variance] -> Label (0: Diam/Santai, 1: Berolahraga/Lari)
  final List<Map<String, dynamic>> _knnDataset = [
    {'f': [9.8, 0.2], 'label': 0},
    {'f': [9.8, 1.0], 'label': 0},
    {'f': [10.5, 3.0], 'label': 0},
    {'f': [11.5, 12.0], 'label': 1},
    {'f': [13.0, 25.0], 'label': 1},
    {'f': [15.0, 50.0], 'label': 1},
  ];

  // Algoritma KNN Sederhana
  int _classifyActivity(double mean, double variance) {
    List<Map<String, dynamic>> distances = [];
    for (var data in _knnDataset) {
      List<double> f = data['f'];
      double d = sqrt(pow(mean - f[0], 2) + pow(variance - f[1], 2));
      distances.add({'dist': d, 'label': data['label']});
    }
    distances.sort((a, b) => a['dist'].compareTo(b['dist']));
    
    // Ambil K=3 tetangga terdekat
    int lariCount = 0;
    for (int i = 0; i < 3; i++) {
      if (distances[i]['label'] == 1) lariCount++;
    }
    return lariCount >= 2 ? 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _fetchData();
    _initSensors();
  }

  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Inisialisasi listener gyroscope (shake) dan accelerometer (deteksi lari dengan ML KNN).
  void _initSensors() {
    _gyroSub = gyroscopeEventStream().listen((event) {
      if (event.x.abs() > 4.0 || event.y.abs() > 4.0 || event.z.abs() > 4.0) {
        final now = DateTime.now();
        if (now.difference(_lastShakeTime).inSeconds > 2) {
          _shakeCount = 0; // Reset jika terlalu lama tidak shake
        }
        if (now.difference(_lastShakeTime).inMilliseconds > 300) {
          _shakeCount++;
          _lastShakeTime = now;
          if (_shakeCount >= 3) {
            _shakeCount = 0;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sensor Gyro: Merefresh data...')));
              _fetchData().then((_) {
                if (aqiData?['current'] != null) {
                  int aqi = aqiData!['current']['european_aqi'] ?? 0;
                  NotificationService.showNotification(
                    id: 2,
                    title: 'Update Kualitas Udara',
                    body: 'Data diperbarui. AQI saat ini: $aqi (${_getAqiStatus(aqi)}).',
                  );
                }
              });
            }
          }
        }
      }
    });

    _accelSub = accelerometerEventStream().listen((event) async {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _magWindow.add(magnitude);

      if (_magWindow.length >= _windowSize) {
        // Ekstraksi Fitur (Mean & Variance)
        double sum = _magWindow.reduce((a, b) => a + b);
        double mean = sum / _windowSize;
        
        double sqDiffSum = 0;
        for (double m in _magWindow) {
          sqDiffSum += pow(m - mean, 2);
        }
        double variance = sqDiffSum / _windowSize;

        // Prediksi menggunakan K-Nearest Neighbors (KNN)
        int prediction = _classifyActivity(mean, variance);
        bool isCurrentlyMoving = prediction == 1;

        if (isCurrentlyMoving != _isMoving) {
          setState(() => _isMoving = isCurrentlyMoving);
        }

        if (isCurrentlyMoving && aqiData?['current'] != null) {
          int aqi = aqiData!['current']['european_aqi'] ?? 0;
          final prefs = await SharedPreferences.getInstance();
          double threshold = prefs.getDouble('aqi_threshold') ?? 60.0;
          final now = DateTime.now();
          if (aqi > threshold && now.difference(_lastNotifTime).inSeconds > 60) {
            _lastNotifTime = now;
            NotificationService.showNotification(
              id: 1,
              title: 'Peringatan Polusi Udara!',
              body: 'Model ML mendeteksi aktivitas olahraga saat AQI buruk ($aqi > batas $threshold).',
            );
          }
        }

        _magWindow.clear(); // Reset window untuk ekstraksi fitur selanjutnya
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    super.dispose();
  }

  /// Mendapatkan lokasi GPS dan mengambil data AQI dari API.
  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      locationMsg = 'Mendapatkan lokasi...';
    });

    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() { isLoading = false; locationMsg = 'GPS tidak aktif.'; });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() { isLoading = false; locationMsg = 'Izin lokasi ditolak.'; });
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() { isLoading = false; locationMsg = 'Izin lokasi ditolak permanen.'; });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      ).catchError((_) async {
        return await Geolocator.getLastKnownPosition() ??
            Position(longitude: 106.8456, latitude: -6.2088, timestamp: DateTime.now(), accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1);
      });

      setState(() => locationMsg = 'Lat: ${position.latitude.toStringAsFixed(2)}, Lon: ${position.longitude.toStringAsFixed(2)}');
      final data = await ApiService.getAQIData(position.latitude, position.longitude);
      setState(() { aqiData = data; isLoading = false; });
    } catch (_) {
      setState(() { isLoading = false; locationMsg = 'Gagal mendapatkan lokasi.'; });
    }
  }

  void _openChatbot() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghubungi AI. Pastikan API Key Gemini sudah diisi di file .env!'), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('AirPulse', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          if (_isMoving) const Icon(Icons.directions_run, color: Colors.orangeAccent),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchData),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF03045E), Color(0xFF0077B6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(locationMsg, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (aqiData?['current'] != null) ...[
                        _buildAqiCard(),
                        const SizedBox(height: 16),
                        _buildWeatherRow(),
                        const SizedBox(height: 16),
                        const Text('Detail Polutan (Klik untuk Info)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 12),
                        _buildPollutantRow(),
                        const SizedBox(height: 32),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 80.0),
                          child: Text(
                            '💡 Goyangkan (shake) HP Anda untuk refresh data.',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white54),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: Text('Gagal memuat data AQI.', style: TextStyle(color: Colors.white))),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00B4D8),
        onPressed: _openChatbot,
        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        label: const Text('AirBot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Widget builder terpisah untuk keterbacaan ──

  Widget _buildAqiCard() {
    final current = aqiData!['current'];
    final int aqi = current['european_aqi'];
    return _buildGlassCard(
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => PollutantDetailScreen(
            title: 'AQI (Air Quality Index)',
            value: '$aqi',
            unit: 'Indeks',
            description: 'AQI adalah skala yang mengukur kualitas udara di lokasi Anda. Skala ini membantu memahami seberapa bersih atau tercemar udara dan potensi dampaknya terhadap kesehatan.',
            interpretation: 'Angka ini mengindikasikan status: ${_getAqiStatus(aqi)}',
          ),
        )),
        child: Column(
          children: [
            const Text('Kualitas Udara (Klik Info)', style: TextStyle(fontSize: 18, color: Colors.white)),
            const SizedBox(height: 8),
            Text('$aqi', style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: _getAqiColor(aqi))),
            Text(_getAqiStatus(aqi), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherRow() {
    final current = aqiData!['current'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildClickableWeatherWidget(Icons.thermostat, '${current['temperature_2m']}', '°C', 'Suhu', 'Mengukur panas atau dinginnya udara sekitar. Jika diiringi kelembaban tinggi, suhu akan terasa lebih panas dari aslinya.'),
        _buildClickableWeatherWidget(Icons.water_drop, '${current['relative_humidity_2m']}', '%', 'Kelembaban', 'Mengukur jumlah uap air di udara. Kelembaban tinggi membuat keringat sulit menguap, sedangkan kelembaban rendah membuat kulit dan tenggorokan kering.'),
      ],
    );
  }

  Widget _buildPollutantRow() {
    final current = aqiData!['current'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildClickablePollutant('PM 2.5', '${current['pm2_5']}', 'Partikel sangat halus dari asap dan debu berukuran <2.5 mikron.', _getInterpretation(current['pm2_5'], 15)),
        _buildClickablePollutant('PM 10', '${current['pm10']}', 'Partikel debu kasar penyebab iritasi tenggorokan.', _getInterpretation(current['pm10'], 45)),
        _buildClickablePollutant('CO', '${current['carbon_monoxide']}', 'Gas beracun hasil pembakaran kendaraan.', _getInterpretation(current['carbon_monoxide'], 400)),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildClickableWeatherWidget(IconData icon, String value, String unit, String label, String desc) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PollutantDetailScreen(title: label, value: value, unit: unit, description: desc, interpretation: 'Ini adalah metrik cuaca standar.'),
      )),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: Colors.orangeAccent),
            const SizedBox(height: 4),
            Text('$value $unit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _buildClickablePollutant(String name, String value, String description, String interpret) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PollutantDetailScreen(title: name, value: value, unit: 'μg/m³', description: description, interpretation: interpret),
      )),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(name, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const Text('μg/m³', style: TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  // ── Helper functions ──

  String _getInterpretation(dynamic val, double safeLimit) {
    if (val == null) return 'Data Kosong';
    double numericVal = (val is int) ? val.toDouble() : val as double;
    return numericVal < safeLimit
        ? 'Kandungan saat ini berada di level AMAN (di bawah standar WHO).'
        : 'Kandungan saat ini MELEBIHI batas aman WHO. Berbahaya untuk jangka panjang!';
  }

  Color _getAqiColor(int? aqi) {
    if (aqi == null) return Colors.grey;
    if (aqi <= 50) return const Color(0xFF00E676);
    if (aqi <= 100) return const Color(0xFFFFEA00);
    if (aqi <= 150) return const Color(0xFFFF9100);
    if (aqi <= 200) return const Color(0xFFFF1744);
    return const Color(0xFFD50000);
  }

  String _getAqiStatus(int? aqi) {
    if (aqi == null) return 'Tidak Diketahui';
    if (aqi <= 50) return 'Baik';
    if (aqi <= 100) return 'Sedang';
    if (aqi <= 150) return 'Tidak Sehat (Sensitif)';
    if (aqi <= 200) return 'Tidak Sehat';
    return 'Berbahaya';
  }
}
