import 'package:audioplayers/audioplayers.dart';

/// Helper audio untuk game — memutar BGM, pop, dan miss dari asset files.
///
/// File audio dihasilkan oleh script `generate_bgm.dart` dan disimpan
/// di `assets/audio/`. Menggunakan AssetSource untuk playback yang reliable.
class GameAudioHelper {
  final AudioPlayer _popPlayer = AudioPlayer();
  final AudioPlayer _missPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();
  bool _bgmPlaying = false;

  /// Inisialisasi — konfigurasi audio context agar SFX tidak menghentikan BGM.
  Future<void> init() async {
    // Konfigurasi pop/miss agar TIDAK merebut audio focus dari BGM
    final sfxContext = AudioContext(
      android: AudioContextAndroid(
        audioFocus: AndroidAudioFocus.none,
        usageType: AndroidUsageType.game,
        contentType: AndroidContentType.sonification,
      ),
    );
    await _popPlayer.setAudioContext(sfxContext);
    await _missPlayer.setAudioContext(sfxContext);

    // BGM menggunakan audio context untuk media
    final bgmContext = AudioContext(
      android: AudioContextAndroid(
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        usageType: AndroidUsageType.game,
        contentType: AndroidContentType.music,
      ),
    );
    await _bgmPlayer.setAudioContext(bgmContext);

    // Listener: ulangi BGM saat selesai
    _bgmPlayer.onPlayerComplete.listen((_) {
      if (_bgmPlaying) {
        _bgmPlayer.play(AssetSource('audio/bgm.wav'));
      }
    });
  }

  bool get isReady => true;

  /// Memainkan efek suara pop saat berhasil mengenai polutan.
  Future<void> playPop() async {
    try {
      await _popPlayer.stop();
      await _popPlayer.play(AssetSource('audio/pop.wav'));
      _ensureBgmPlaying();
    } catch (_) {}
  }

  /// Memainkan efek suara miss saat polutan lolos.
  Future<void> playMiss() async {
    try {
      await _missPlayer.stop();
      await _missPlayer.play(AssetSource('audio/miss.wav'));
      _ensureBgmPlaying();
    } catch (_) {}
  }

  /// Cek dan restart BGM jika terganggu oleh SFX.
  void _ensureBgmPlaying() async {
    if (!_bgmPlaying) return;
    await Future.delayed(const Duration(milliseconds: 200));
    if (_bgmPlayer.state != PlayerState.playing && _bgmPlaying) {
      await _bgmPlayer.play(AssetSource('audio/bgm.wav'));
    }
  }

  /// Memulai musik latar.
  Future<void> startBgm() async {
    _bgmPlaying = true;
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.play(AssetSource('audio/bgm.wav'));
    } catch (_) {}
  }

  /// Menghentikan musik latar.
  Future<void> stopBgm() async {
    _bgmPlaying = false;
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  void dispose() {
    _bgmPlaying = false;
    _popPlayer.dispose();
    _missPlayer.dispose();
    _bgmPlayer.dispose();
  }
}
