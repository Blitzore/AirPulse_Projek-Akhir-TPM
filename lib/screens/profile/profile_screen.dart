import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../database/db_helper.dart';
import '../auth/login_screen.dart';
import '../game/quiz_screen.dart';
import '../game/filter_game_screen.dart';

/// Layar profil — menampilkan data pengguna, pengaturan notifikasi,
/// riwayat pencarian AQI, dan akses ke kuis edukasi.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, dynamic>> _history = [];
  double _notificationThreshold = 60.0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadThreshold();
  }

  Future<void> _loadHistory() async {
    final history = await DBHelper().getAqiHistory();
    setState(() => _history = history);
  }

  Future<void> _loadThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _notificationThreshold = prefs.getDouble('aqi_threshold') ?? 60.0);
  }

  Future<void> _saveThreshold(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('aqi_threshold', val);
    setState(() => _notificationThreshold = val);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Profil Saya')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header profil
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
              ),
              child: Column(
                children: [
                  const CircleAvatar(radius: 50, backgroundColor: Color(0xFF00B4D8), child: Icon(Icons.person, size: 50, color: Colors.white)),
                  const SizedBox(height: 16),
                  Text(user?.name ?? 'Nama User', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF03045E))),
                  Text(user?.email ?? 'email@example.com', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pengaturan keamanan biometrik
                  const Text('Keamanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF0077B6).withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.fingerprint, color: Color(0xFF0077B6)),
                      ),
                      title: const Text('Login Biometrik', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Aktifkan login sidik jari di halaman login'),
                      value: user?.isBiometricEnabled == 1,
                      activeColor: const Color(0xFF0077B6),
                      onChanged: (val) => context.read<AuthProvider>().updateBiometricStatus(val),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pengaturan batas notifikasi AQI
                  const Text('Pengaturan Notifikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Beri peringatan saat olahraga jika AQI melebihi: ${_notificationThreshold.toInt()}'),
                          Slider(
                            value: _notificationThreshold,
                            min: 20,
                            max: 150,
                            divisions: 13,
                            activeColor: const Color(0xFF0077B6),
                            label: _notificationThreshold.round().toString(),
                            onChanged: _saveThreshold,
                          ),
                          const Text('*Tips: Gunakan 60 untuk sensitif, 80 untuk standar', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Riwayat pencarian lokasi
                  const Text('Riwayat Pencarian Lokasi (SQLite)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Belum ada riwayat pencarian peta.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._history.map((h) => Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        leading: const Icon(Icons.history, color: Colors.grey),
                        title: Text(h['city'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('AQI: ${h['aqi']} (${h['status']})'),
                      ),
                    )),
                  const SizedBox(height: 24),

                  // Menu tambahan
                  _buildMenuItem(
                    icon: Icons.gamepad,
                    title: 'Kuis Udara Bersih',
                    subtitle: 'Tantang pengetahuan Anda!',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizScreen())),
                  ),
                  _buildMenuItem(
                    icon: Icons.filter_drama,
                    title: 'Filter Udara (Mini Game)',
                    subtitle: 'Tap polutan sebelum jatuh!',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FilterGameScreen())),
                  ),
                  _buildMenuItem(
                    icon: Icons.feedback,
                    title: 'Saran & Kesan',
                    subtitle: 'Mata Kuliah TPM',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          title: const Text('Saran & Kesan TPM', style: TextStyle(color: Color(0xFF0077B6))),
                          content: const Text('Projek akhirnya menantang untuk dikerjakan, penuh struggle untuk mencapai final seperti sekarang'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup', style: TextStyle(color: Color(0xFF0077B6)))),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Tombol logout
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Keluar dari Akun', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF00B4D8).withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: const Color(0xFF00B4D8)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
