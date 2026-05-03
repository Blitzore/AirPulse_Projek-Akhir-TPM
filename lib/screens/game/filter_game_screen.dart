import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/game_audio_helper.dart';

/// Mini game interaktif "Filter Udara" — tap polutan yang jatuh sebelum
/// mencapai batas bawah. Semakin lama bertahan, semakin cepat polutan jatuh.
class FilterGameScreen extends StatefulWidget {
  const FilterGameScreen({super.key});

  @override
  State<FilterGameScreen> createState() => _FilterGameScreenState();
}

class _Particle {
  double x;
  double y;
  final String type;
  final Color color;
  final double size;
  double speed;
  bool alive = true;
  double popScale = 0.0; // animasi pop saat ditap

  _Particle({
    required this.x,
    required this.y,
    required this.type,
    required this.color,
    required this.size,
    required this.speed,
  });
}

class _FilterGameScreenState extends State<FilterGameScreen> with SingleTickerProviderStateMixin {
  static const _pollutants = [
    {'type': 'PM2.5', 'color': Color(0xFFFF6B6B), 'size': 48.0},
    {'type': 'PM10', 'color': Color(0xFFFFB347), 'size': 54.0},
    {'type': 'CO', 'color': Color(0xFF9B59B6), 'size': 50.0},
    {'type': 'SO2', 'color': Color(0xFF3498DB), 'size': 46.0},
    {'type': 'NO2', 'color': Color(0xFF1ABC9C), 'size': 52.0},
  ];

  final _random = Random();
  final List<_Particle> _particles = [];
  final GameAudioHelper _audio = GameAudioHelper();

  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _audioReady = false;
  double _speedMultiplier = 1.0;

  Timer? _spawnTimer;
  Timer? _gameTimer;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _loadHighScore();
    _initAudio();
  }

  Future<void> _initAudio() async {
    await _audio.init();
    setState(() => _audioReady = _audio.isReady);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _highScore = prefs.getInt('filter_game_highscore') ?? 0);
  }

  Future<void> _saveHighScore() async {
    if (_score > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('filter_game_highscore', _score);
      setState(() => _highScore = _score);
    }
  }

  void _startGame() {
    setState(() {
      _score = 0;
      _lives = 3;
      _isPlaying = true;
      _isGameOver = false;
      _speedMultiplier = 1.0;
      _particles.clear();
      _elapsed = Duration.zero;
      _lastTick = Duration.zero;
    });

    _ticker.start();
    if (_audioReady) _audio.startBgm();

    _spawnTimer?.cancel();
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!_isPlaying) return;
      _spawnParticle();
    });

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isPlaying) return;
      _speedMultiplier += 0.25;
    });
  }

  void _spawnParticle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final pollutant = _pollutants[_random.nextInt(_pollutants.length)];
    final size = pollutant['size'] as double;

    _particles.add(_Particle(
      x: _random.nextDouble() * (screenWidth - size - 32) + 16,
      y: -size,
      type: pollutant['type'] as String,
      color: pollutant['color'] as Color,
      size: size,
      speed: (1.2 + _random.nextDouble() * 1.0) * _speedMultiplier,
    ));
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying) return;
    final dt = (elapsed - _lastTick).inMilliseconds / 16.0;
    _lastTick = elapsed;
    _elapsed = elapsed;

    final screenHeight = MediaQuery.of(context).size.height;
    final bottomLimit = screenHeight - 140;

    setState(() {
      for (final p in _particles) {
        if (!p.alive) continue;
        p.y += p.speed * dt;

        if (p.y > bottomLimit) {
          p.alive = false;
          _lives--;
          if (_audioReady) _audio.playMiss();
          if (_lives <= 0) _endGame();
        }
      }
      _particles.removeWhere((p) => !p.alive);
    });
  }

  void _tapParticle(_Particle particle) {
    if (!_isPlaying || !particle.alive) return;
    setState(() {
      particle.alive = false;
      _score++;
    });
    if (_audioReady) _audio.playPop();
  }

  void _endGame() {
    _isPlaying = false;
    _isGameOver = true;
    _ticker.stop();
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    if (_audioReady) _audio.stopBgm();
    _saveHighScore();
  }

  String _formatTime(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('Filter Udara', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A1628),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isPlaying ? _buildGame() : _buildMenu(),
    );
  }

  Widget _buildMenu() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF00B4D8), Color(0xFF0077B6)]),
                boxShadow: [BoxShadow(color: const Color(0xFF00B4D8).withOpacity(0.4), blurRadius: 30, spreadRadius: 5)],
              ),
              child: const Icon(Icons.air, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 32),
            const Text('Filter Udara', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
              'Tap polutan sebelum jatuh ke bawah!\nSemakin lama, semakin cepat.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            if (_isGameOver) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text('Game Over!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    const SizedBox(height: 8),
                    Text('Skor: $_score', style: const TextStyle(fontSize: 20, color: Colors.white)),
                    Text('Waktu: ${_formatTime(_elapsed)}', style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text('Skor Tertinggi: $_highScore', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _pollutants.map((p) {
                return Chip(
                  backgroundColor: (p['color'] as Color).withOpacity(0.2),
                  avatar: CircleAvatar(backgroundColor: p['color'] as Color, radius: 8),
                  label: Text(p['type'] as String, style: TextStyle(color: p['color'] as Color, fontWeight: FontWeight.bold, fontSize: 12)),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: const Color(0xFF00B4D8).withOpacity(0.5),
                ),
                onPressed: _startGame,
                child: Text(
                  _isGameOver ? 'Main Lagi' : 'Mulai Game',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    return Stack(
      children: [
        // Partikel yang jatuh — area sentuh diperbesar 20px di tiap sisi
        ..._particles.where((p) => p.alive).map((p) {
          const hitPadding = 20.0;
          return Positioned(
            left: p.x - hitPadding,
            top: p.y - hitPadding,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _tapParticle(p),
              child: SizedBox(
                width: p.size + hitPadding * 2,
                height: p.size + hitPadding * 2,
                child: Center(
                  child: Container(
                    width: p.size,
                    height: p.size,
                    decoration: BoxDecoration(
                      color: p.color,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: p.color.withOpacity(0.6), blurRadius: 12, spreadRadius: 3)],
                    ),
                    child: Center(
                      child: Text(
                        p.type,
                        style: TextStyle(color: Colors.white, fontSize: p.size * 0.22, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),

        // HUD
        Positioned(
          top: 8,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    i < _lives ? Icons.favorite : Icons.favorite_border,
                    color: i < _lives ? Colors.redAccent : Colors.grey,
                    size: 28,
                  ),
                )),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(_formatTime(_elapsed), style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF00B4D8).withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text('$_score', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Garis batas bawah
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.redAccent.withOpacity(0.6), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Text(
            '— batas filter —',
            style: TextStyle(color: Colors.redAccent.withOpacity(0.5), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
