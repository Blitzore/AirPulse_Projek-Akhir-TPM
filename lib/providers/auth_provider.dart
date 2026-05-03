import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';
import '../utils/encryption_helper.dart';

/// Provider autentikasi — mengelola login, register, sesi, dan biometrik.
///
/// Menggunakan dua kunci SharedPreferences:
/// - `user_email`: sesi aktif (dihapus saat logout)
/// - `last_login_email`: akun terakhir untuk biometrik (persisten)
class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isBiometricAuthenticated = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isBiometricAuthenticated => _isBiometricAuthenticated;

  /// Memeriksa status login dari sesi tersimpan saat app dimulai.
  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email != null) {
      final user = await DBHelper().getUserByEmail(email);
      if (user != null) {
        _currentUser = user;
        // Jika biometrik aktif, wajib verifikasi dulu sebelum masuk
        _isBiometricAuthenticated = user.isBiometricEnabled != 1;
      }
    }
    _isInitializing = false;
    notifyListeners();
  }

  void setBiometricAuthenticated(bool val) {
    _isBiometricAuthenticated = val;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final user = await DBHelper().loginUser(email, EncryptionHelper.hashPassword(password));

    _isLoading = false;
    if (user != null) {
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', user.email);
      // Simpan juga untuk biometrik (tidak terhapus saat logout)
      await prefs.setString('last_login_email', user.email);
      notifyListeners();
      return true;
    }
    notifyListeners();
    return false;
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final newUser = UserModel(
      name: name,
      email: email,
      password: EncryptionHelper.hashPassword(password),
    );
    final result = await DBHelper().registerUser(newUser);

    _isLoading = false;
    notifyListeners();
    return result != -1;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    // Hapus sesi aktif, tapi TETAP simpan last_login_email untuk biometrik
    await prefs.remove('user_email');
    _currentUser = null;
    _isBiometricAuthenticated = false;
    notifyListeners();
  }

  Future<void> updateBiometricStatus(bool isEnabled) async {
    if (_currentUser != null) {
      _currentUser!.isBiometricEnabled = isEnabled ? 1 : 0;
      await DBHelper().updateUser(_currentUser!);
      notifyListeners();
    }
  }
}
