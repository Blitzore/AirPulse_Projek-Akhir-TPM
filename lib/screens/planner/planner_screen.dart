import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import 'select_map_screen.dart';

/// Layar perencana aktivitas — menampilkan prakiraan AQI 24 jam
/// dengan kemampuan menjadwalkan notifikasi pada waktu tertentu.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  LatLng? _selectedLocation;
  String _locationName = 'Lokasi Saat Ini';
  List<Map<String, dynamic>> _forecastList = [];
  bool _isLoading = false;
  String _statusMsg = '';

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      ).catchError((_) async {
        return await Geolocator.getLastKnownPosition() ??
            Position(longitude: 106.8456, latitude: -6.2088, timestamp: DateTime.now(), accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1);
      });
      _selectedLocation = LatLng(position.latitude, position.longitude);
      _fetchForecast();
    } catch (_) {
      _selectedLocation = const LatLng(-6.2088, 106.8456);
      _locationName = 'Jakarta (Default)';
      _fetchForecast();
    }
  }

  Future<void> _searchLocation() async {
    if (_searchController.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final locations = await locationFromAddress(_searchController.text);
      if (locations.isNotEmpty) {
        _selectedLocation = LatLng(locations.first.latitude, locations.first.longitude);
        _locationName = _searchController.text;
        _fetchForecast();
      } else {
        setState(() { _isLoading = false; _statusMsg = 'Lokasi tidak ditemukan.'; });
      }
    } catch (_) {
      setState(() { _isLoading = false; _statusMsg = 'Gagal mencari lokasi.'; });
    }
  }

  Future<void> _openMap() async {
    final picked = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => const SelectMapScreen()));
    if (picked != null) {
      _selectedLocation = picked;
      _locationName = 'Koordinat Kustom';
      _fetchForecast();
    }
  }

  /// Mengambil prakiraan AQI per jam dari API dan memfilter 24 jam ke depan.
  Future<void> _fetchForecast() async {
    if (_selectedLocation == null) return;
    setState(() { _isLoading = true; _statusMsg = ''; _forecastList = []; });

    final data = await ApiService.getHourlyAQIForecast(_selectedLocation!.latitude, _selectedLocation!.longitude);

    if (data?['hourly'] != null) {
      final times = data!['hourly']['time'] as List;
      final aqis = data['hourly']['european_aqi'] as List;
      final now = DateTime.now();
      final upcoming = <Map<String, dynamic>>[];

      for (int i = 0; i < times.length && upcoming.length < 24; i++) {
        final dt = DateTime.parse(times[i]);
        if (dt.isAfter(now.subtract(const Duration(hours: 1)))) {
          upcoming.add({'time': dt, 'aqi': aqis[i] ?? 0});
        }
      }

      setState(() => _forecastList = upcoming);
      if (upcoming.isEmpty) _statusMsg = 'Tidak ada data prakiraan tersedia.';
    } else {
      setState(() => _statusMsg = 'Gagal mengambil data prakiraan dari satelit.');
    }
    setState(() => _isLoading = false);
  }

  /// Menjadwalkan notifikasi untuk blok waktu prakiraan yang dipilih.
  Future<void> _setAlarm(Map<String, dynamic> forecast) async {
    final blockTime = forecast['time'] as DateTime;
    final aqi = forecast['aqi'] as int;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(blockTime),
    );
    if (picked == null) return;

    var scheduledDate = DateTime(blockTime.year, blockTime.month, blockTime.day, picked.hour, picked.minute);
    if (scheduledDate.isBefore(DateTime.now())) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    try {
      await NotificationService.scheduleNotification(
        id: scheduledDate.millisecondsSinceEpoch ~/ 100000,
        title: 'Waktunya Beraktivitas!',
        body: 'Prakiraan AQI di $_locationName adalah $aqi (${_getAqiStatus(aqi)}). Cek aplikasi untuk nilai aktualnya!',
        scheduledDate: scheduledDate,
      );
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notifikasi disetel untuk ${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  /// Menampilkan dialog daftar alarm/notifikasi yang sedang aktif.
  Future<void> _showPendingAlarms() async {
    final pendingList = await NotificationService.getPendingNotifications();
    List<PendingNotificationRequest> pending = List.from(pendingList);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF03045E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Daftar Alarm Aktif', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: pending.isEmpty
                    ? const Text('Belum ada alarm yang disetel.', style: TextStyle(color: Colors.white70))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: pending.length,
                        itemBuilder: (context, index) {
                          final alarm = pending[index];
                          String timeStr = 'Waktu tidak diketahui';
                          if (alarm.payload != null) {
                            try {
                              final dt = DateTime.parse(alarm.payload!);
                              timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            } catch (_) {}
                          }

                          return Card(
                            color: Colors.white.withOpacity(0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              title: Text(alarm.title ?? 'Alarm', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(alarm.body ?? 'Tanpa deskripsi', style: const TextStyle(color: Colors.white70)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(4)),
                                    child: Text('Jam: $timeStr', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.redAccent),
                                onPressed: () async {
                                  await NotificationService.cancelNotification(alarm.id);
                                  setStateDialog(() => pending.removeAt(index));
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alarm berhasil dibatalkan.')));
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getAqiStatus(int aqi) {
    if (aqi <= 50) return 'Baik';
    if (aqi <= 100) return 'Sedang';
    if (aqi <= 150) return 'Tidak Sehat (Sensitif)';
    if (aqi <= 200) return 'Tidak Sehat';
    return 'Berbahaya';
  }

  Color _getAqiColor(int aqi) {
    if (aqi <= 50) return const Color(0xFF00E676);
    if (aqi <= 100) return const Color(0xFFFFEA00);
    if (aqi <= 150) return const Color(0xFFFF9100);
    if (aqi <= 200) return const Color(0xFFFF1744);
    return const Color(0xFFD50000);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perencana Aktivitas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF03045E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm_on, color: Colors.tealAccent),
            onPressed: _showPendingAlarms,
            tooltip: 'Jadwal Aktif',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF03045E), Color(0xFF0077B6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Pencarian lokasi
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white.withOpacity(0.05),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Cari Kota (misal: Jakarta)',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        suffixIcon: IconButton(icon: const Icon(Icons.search, color: Colors.white70), onPressed: _searchLocation),
                      ),
                      onSubmitted: (_) => _searchLocation(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFF00B4D8), borderRadius: BorderRadius.circular(12)),
                    child: IconButton(icon: const Icon(Icons.map, color: Colors.white), onPressed: _openMap, tooltip: 'Pilih di Peta'),
                  ),
                ],
              ),
            ),

            // Label lokasi terpilih
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Prakiraan AQI: $_locationName', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),

            // Timeline prakiraan
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _forecastList.isEmpty
                      ? Center(child: Text(_statusMsg.isNotEmpty ? _statusMsg : 'Mencari data...', style: const TextStyle(color: Colors.white70)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _forecastList.length,
                          itemBuilder: (context, index) {
                            final forecast = _forecastList[index];
                            final dt = forecast['time'] as DateTime;
                            final aqi = forecast['aqi'] as int;
                            final aqiColor = _getAqiColor(aqi);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                                    child: Text('${dt.hour.toString().padLeft(2, '0')}:00', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('AQI: $aqi', style: TextStyle(color: aqiColor, fontSize: 20, fontWeight: FontWeight.bold)),
                                        Text(_getAqiStatus(aqi), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.notifications_active, color: Colors.tealAccent, size: 30),
                                    onPressed: () => _setAlarm(forecast),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
