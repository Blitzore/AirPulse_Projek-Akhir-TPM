import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../database/db_helper.dart';
import '../../utils/biometric_helper.dart';
import 'register_screen.dart';
import '../main_screen.dart';

/// Layar login dengan opsi email/password dan biometrik.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await context.read<AuthProvider>().login(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      context.read<AuthProvider>().setBiometricAuthenticated(true);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login Berhasil!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login Gagal, cek username/password!')));
    }
  }

  void _biometricLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('last_login_email');
      if (savedEmail == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Belum ada akun tersimpan. Silakan login manual terlebih dahulu.')),
          );
        }
        return;
      }

      // Cek apakah user ini sudah mengaktifkan biometrik di profil
      final user = await DBHelper().getUserByEmail(savedEmail);
      if (user == null || user.isBiometricEnabled != 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fitur biometrik belum diaktifkan. Aktifkan di Profil > Keamanan.')),
          );
        }
        return;
      }

      final helper = BiometricHelper();
      if (await helper.hasBiometrics()) {
        final authenticated = await helper.authenticate();
        if (!mounted) return;
        if (authenticated) {
          // Pulihkan sesi aktif
          await prefs.setString('user_email', user.email);
          final auth = context.read<AuthProvider>();
          await auth.checkLoginStatus();
          auth.setBiometricAuthenticated(true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Biometrik sukses! Masuk sebagai ${user.name}')),
            );
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometrik dibatalkan atau gagal dikenali.')));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perangkat tidak mendukung biometrik atau belum disetup.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error Biometrik: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0077B6), Color(0xFF00B4D8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Card(
                color: const Color(0xFFF8F9FA),
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.air, size: 64, color: Color(0xFF0077B6)),
                        const SizedBox(height: 16),
                        const Text('AirPulse', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF03045E))),
                        const Text('Pantau Kualitas Udara Anda', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            filled: true,
                            fillColor: Colors.transparent,
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) => val!.isEmpty ? 'Username wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            filled: true,
                            fillColor: Colors.transparent,
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          obscureText: true,
                          validator: (val) => val!.isEmpty ? 'Password wajib diisi' : null,
                        ),
                        const SizedBox(height: 24),
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            if (auth.isLoading) return const CircularProgressIndicator();
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0077B6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _login,
                                child: const Text('MASUK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFF0077B6)),
                            ),
                            onPressed: _biometricLogin,
                            icon: const Icon(Icons.fingerprint, color: Color(0xFF0077B6)),
                            label: const Text('Login dengan Sidik Jari', style: TextStyle(color: Color(0xFF0077B6))),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: const Text('Belum punya akun? Daftar di sini'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
