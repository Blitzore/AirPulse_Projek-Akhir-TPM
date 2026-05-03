import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

/// Layar pemilihan lokasi di peta — mengembalikan koordinat LatLng ke caller.
class SelectMapScreen extends StatefulWidget {
  const SelectMapScreen({super.key});

  @override
  State<SelectMapScreen> createState() => _SelectMapScreenState();
}

class _SelectMapScreenState extends State<SelectMapScreen> {
  LatLng? _selectedLocation;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      ).catchError((_) async {
        return await Geolocator.getLastKnownPosition() ??
            Position(longitude: 106.8456, latitude: -6.2088, timestamp: DateTime.now(), accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1);
      });
      setState(() => _selectedLocation = LatLng(position.latitude, position.longitude));
      _mapController.move(_selectedLocation!, 13.0);
    } catch (_) {
      setState(() => _selectedLocation = const LatLng(-6.2088, 106.8456));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF03045E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedLocation != null)
            TextButton.icon(
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Pilih', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context, _selectedLocation),
            ),
        ],
      ),
      body: Stack(
        children: [
          _selectedLocation == null
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation!,
                    initialZoom: 13.0,
                    onLongPress: (_, point) => setState(() => _selectedLocation = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.projek_akhir',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(point: _selectedLocation!, width: 40, height: 40, child: const Icon(Icons.location_pin, color: Colors.red, size: 40)),
                      ],
                    ),
                  ],
                ),
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
              child: const Text(
                'Tahan (Long Press) peta untuk memindahkan titik lokasi. Lalu tekan "Pilih" di kanan atas.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
