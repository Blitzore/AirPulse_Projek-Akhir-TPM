import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/api_service.dart';
import '../../database/db_helper.dart';

/// Layar peta interaktif — menampilkan data AQI berdasarkan pencarian kota
/// atau long-press pada peta.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentPosition;
  LatLng? _selectedPosition;
  String _selectedCity = '';
  Map<String, dynamic>? _selectedAqiData;
  bool _isLoading = true;

  final _mapController = MapController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      ).catchError((_) async {
        return await Geolocator.getLastKnownPosition() ??
            Position(longitude: 106.8456, latitude: -6.2088, timestamp: DateTime.now(), accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1);
      });

      final aqiData = await ApiService.getAQIData(position.latitude, position.longitude);

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _selectedPosition = _currentPosition;
        _selectedCity = 'Lokasi Saat Ini';
        _selectedAqiData = aqiData;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_currentPosition!, 12.0);
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchCity() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        await _fetchAndShowAqi(LatLng(loc.latitude, loc.longitude), query, saveToHistory: true);
      }
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kota tidak ditemukan.')));
    }
  }

  Future<void> _fetchAndShowAqi(LatLng point, String locationName, {bool saveToHistory = false}) async {
    setState(() => _isLoading = true);
    try {
      final aqiData = await ApiService.getAQIData(point.latitude, point.longitude);
      setState(() {
        _selectedPosition = point;
        _selectedCity = locationName;
        _selectedAqiData = aqiData;
        _isLoading = false;
      });

      _mapController.move(point, 11.0);

      if (aqiData?['current'] != null) {
        final aqi = aqiData!['current']['european_aqi'] ?? 0;
        if (saveToHistory) {
          await DBHelper().insertAqiHistory(locationName, aqi, _getAqiStatus(aqi));
        }
        if (mounted) _showAqiBottomSheet(aqiData['current'], locationName);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _onMapLongPress(TapPosition tapPosition, LatLng point) async {
    final placemarks = await placemarkFromCoordinates(point.latitude, point.longitude).catchError((_) => <Placemark>[]);
    String name = placemarks.isNotEmpty
        ? '${placemarks.first.locality ?? placemarks.first.subAdministrativeArea}'
        : 'Lokasi Terpilih';
    if (name.isEmpty || name == 'null') name = 'Lokasi Terpilih';
    await _fetchAndShowAqi(point, name);
  }

  void _showAqiBottomSheet(Map<String, dynamic> currentData, String city) {
    final aqi = currentData['european_aqi'] ?? 0;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kualitas Udara di $city', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 40,
              backgroundColor: _getAqiColor(aqi),
              child: Text('$aqi', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 8),
            Text(_getAqiStatus(aqi), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _getAqiColor(aqi))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPollutantInfo('PM 2.5', '${currentData['pm2_5']}'),
                _buildPollutantInfo('PM 10', '${currentData['pm10']}'),
                _buildPollutantInfo('Suhu', '${currentData['temperature_2m']} °C'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollutantInfo(String name, String val) {
    return Column(
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(val, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Color _getAqiColor(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow.shade700;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    return Colors.purple;
  }

  String _getAqiStatus(int aqi) {
    if (aqi <= 50) return 'Baik';
    if (aqi <= 100) return 'Sedang';
    if (aqi <= 150) return 'Tidak Sehat (Sensitif)';
    if (aqi <= 200) return 'Tidak Sehat';
    return 'Berbahaya';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Peta Kualitas Udara'), backgroundColor: Colors.white),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-6.2088, 106.8456),
              initialZoom: 5.0,
              onLongPress: _onMapLongPress,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.airpulse',
              ),
              MarkerLayer(
                markers: [
                  if (_currentPosition != null && _selectedPosition != _currentPosition)
                    Marker(point: _currentPosition!, width: 40, height: 40, child: const Icon(Icons.circle, color: Colors.blue, size: 20)),
                  if (_selectedPosition != null && _selectedAqiData != null)
                    Marker(
                      point: _selectedPosition!,
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: () {
                          if (_selectedAqiData!['current'] != null) {
                            _showAqiBottomSheet(_selectedAqiData!['current'], _selectedCity);
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _getAqiColor(_selectedAqiData!['current']['european_aqi']),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Text(
                                '${_selectedAqiData!['current']['european_aqi']}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Icon(Icons.location_on, color: _getAqiColor(_selectedAqiData!['current']['european_aqi']), size: 40),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Search bar
          Positioned(
            top: 16, left: 16, right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(hintText: 'Cari kota (misal: Jakarta)', border: InputBorder.none),
                        onSubmitted: (_) => _searchCity(),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.send, color: Color(0xFF00B4D8)), onPressed: _searchCity),
                  ],
                ),
              ),
            ),
          ),

          // Petunjuk penggunaan
          const Positioned(
            bottom: 16, left: 16, right: 80,
            child: Card(
              color: Colors.white70,
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('💡 Tekan lama (Long Press) di peta untuk cek AQI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Color(0xFF0077B6)),
        onPressed: () {
          if (_currentPosition != null) {
            _mapController.move(_currentPosition!, 12.0);
            _fetchAndShowAqi(_currentPosition!, 'Lokasi Saat Ini');
          }
        },
      ),
    );
  }
}
