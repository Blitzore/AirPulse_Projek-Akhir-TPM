import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';

/// Helper database SQLite untuk operasi CRUD pengguna dan riwayat AQI.
class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'airpulse.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT UNIQUE,
        password TEXT,
        photoUrl TEXT,
        isBiometricEnabled INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE aqi_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        city TEXT,
        aqi INTEGER,
        status TEXT,
        timestamp TEXT
      )
    ''');
  }

  // ── User ──

  Future<int> registerUser(UserModel user) async {
    final db = await database;
    try {
      return await db.insert('users', user.toMap());
    } catch (_) {
      return -1;
    }
  }

  Future<UserModel?> loginUser(String email, String password) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return maps.isNotEmpty ? UserModel.fromMap(maps.first) : null;
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    return maps.isNotEmpty ? UserModel.fromMap(maps.first) : null;
  }

  Future<int> updateUser(UserModel user) async {
    final db = await database;
    return db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  // ── Riwayat AQI ──

  Future<int> insertAqiHistory(String city, int aqi, String status) async {
    final db = await database;
    return db.insert('aqi_history', {
      'city': city,
      'aqi': aqi,
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAqiHistory() async {
    final db = await database;
    return db.query('aqi_history', orderBy: 'timestamp DESC', limit: 10);
  }
}
