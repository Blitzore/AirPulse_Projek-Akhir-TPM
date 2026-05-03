import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Script untuk menghasilkan file WAV BGM game.
/// Jalankan: dart run lib/utils/generate_bgm.dart
void main() async {
  final bgm = _generateGameBgm();
  final file = File('assets/audio/bgm.wav');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bgm);
  print('BGM generated: ${file.path} (${bgm.length} bytes)');

  final pop = _generatePopSound();
  final popFile = File('assets/audio/pop.wav');
  await popFile.writeAsBytes(pop);
  print('Pop generated: ${popFile.path} (${pop.length} bytes)');

  final miss = _generateMissSound();
  final missFile = File('assets/audio/miss.wav');
  await missFile.writeAsBytes(miss);
  print('Miss generated: ${missFile.path} (${miss.length} bytes)');
}

Uint8List _generateGameBgm() {
  const sampleRate = 44100;
  const bpm = 90.0;
  const beatDuration = 60.0 / bpm;
  const bars = 8;
  const beatsPerBar = 4;
  const totalBeats = bars * beatsPerBar;
  final duration = totalBeats * beatDuration;
  final numSamples = (sampleRate * duration).toInt();
  final samples = Float64List(numSamples);

  // Chord progression: Cm - Ab - Eb - Bb (i - VI - III - VII)
  const chords = [
    [130.81, 155.56, 196.00], // Cm
    [130.81, 155.56, 196.00], // Cm
    [207.65, 261.63, 311.13], // Ab
    [207.65, 261.63, 311.13], // Ab
    [155.56, 196.00, 233.08], // Eb
    [155.56, 196.00, 233.08], // Eb
    [116.54, 146.83, 174.61], // Bb
    [116.54, 146.83, 174.61], // Bb
  ];

  // Melodi sederhana (nada-nada pentatonik C minor)
  const melody = [
    523.25, 0, 466.16, 0, 392.00, 0, 349.23, 0,
    311.13, 0, 349.23, 0, 392.00, 0, 466.16, 0,
    523.25, 0, 0, 466.16, 392.00, 0, 311.13, 0,
    349.23, 0, 392.00, 0, 466.16, 523.25, 0, 0,
  ];

  for (int i = 0; i < numSamples; i++) {
    double t = i / sampleRate;
    double val = 0;

    // Beat tracking
    int currentBeat = (t / beatDuration).floor();
    double beatPhase = (t % beatDuration) / beatDuration;
    int currentBar = currentBeat ~/ beatsPerBar;
    if (currentBar >= bars) currentBar = bars - 1;

    // === PAD (chord sustain) ===
    final chord = chords[currentBar];
    for (final freq in chord) {
      // Gelombang sawtooth yang difilter (lebih hangat dari sine)
      double wave = 0;
      for (int h = 1; h <= 4; h++) {
        wave += sin(2 * pi * freq * h * t) / h;
      }
      val += wave * 0.06;
    }

    // === BASS (root note, octave bawah) ===
    double bassFreq = chord[0] / 2;
    double bassEnv = beatPhase < 0.1 ? beatPhase / 0.1 : exp(-(beatPhase - 0.1) * 3);
    val += sin(2 * pi * bassFreq * t) * bassEnv * 0.15;

    // === MELODY ===
    int melodyIdx = currentBeat % melody.length;
    double melodyFreq = melody[melodyIdx].toDouble();
    if (melodyFreq > 0) {
      double melEnv = beatPhase < 0.05 ? beatPhase / 0.05 : exp(-beatPhase * 4);
      // Triangle wave untuk melodi (lebih lembut)
      double phase = (melodyFreq * t) % 1.0;
      double triWave = 4 * (phase - (phase + 0.5).floor()).abs() - 1;
      val += triWave * melEnv * 0.12;
    }

    // === HI-HAT (noise burst setiap beat) ===
    if (beatPhase < 0.03) {
      val += (Random(i).nextDouble() * 2 - 1) * 0.04 * (1 - beatPhase / 0.03);
    }

    // Fade in/out global
    double fade = 1.0;
    if (t < 0.5) fade = t / 0.5;
    if (t > duration - 0.5) fade = (duration - t) / 0.5;

    samples[i] = (val * fade).clamp(-0.95, 0.95);
  }

  return _encodeWav(samples, sampleRate);
}

Uint8List _generatePopSound() {
  const sampleRate = 44100;
  const duration = 0.1;
  final numSamples = (sampleRate * duration).toInt();
  final samples = Float64List(numSamples);

  for (int i = 0; i < numSamples; i++) {
    double t = i / sampleRate;
    double env = exp(-t * 40);
    // Nada tinggi + harmonik
    samples[i] = sin(2 * pi * 1200 * t) * env * 0.7;
    samples[i] += sin(2 * pi * 1800 * t) * env * 0.3;
    // Noise burst di awal untuk "pop"
    if (t < 0.01) {
      samples[i] += (Random(i).nextDouble() * 2 - 1) * (1 - t / 0.01) * 0.5;
    }
  }

  return _encodeWav(samples, sampleRate);
}

Uint8List _generateMissSound() {
  const sampleRate = 44100;
  const duration = 0.3;
  final numSamples = (sampleRate * duration).toInt();
  final samples = Float64List(numSamples);

  for (int i = 0; i < numSamples; i++) {
    double t = i / sampleRate;
    double freq = 300 - (t / duration) * 200; // pitch drop
    double env = exp(-t * 8);
    samples[i] = sin(2 * pi * freq * t) * env * 0.6;
    samples[i] += sin(2 * pi * freq * 0.5 * t) * env * 0.3;
  }

  return _encodeWav(samples, sampleRate);
}

Uint8List _encodeWav(Float64List samples, int sampleRate) {
  const bitsPerSample = 16;
  const numChannels = 1;
  final dataSize = samples.length * 2;
  final fileSize = 36 + dataSize;

  final buffer = ByteData(44 + dataSize);
  int offset = 0;

  // RIFF header
  for (final c in [0x52, 0x49, 0x46, 0x46]) buffer.setUint8(offset++, c);
  buffer.setUint32(offset, fileSize, Endian.little); offset += 4;
  for (final c in [0x57, 0x41, 0x56, 0x45]) buffer.setUint8(offset++, c);

  // fmt chunk
  for (final c in [0x66, 0x6D, 0x74, 0x20]) buffer.setUint8(offset++, c);
  buffer.setUint32(offset, 16, Endian.little); offset += 4;
  buffer.setUint16(offset, 1, Endian.little); offset += 2;
  buffer.setUint16(offset, numChannels, Endian.little); offset += 2;
  buffer.setUint32(offset, sampleRate, Endian.little); offset += 4;
  buffer.setUint32(offset, sampleRate * numChannels * bitsPerSample ~/ 8, Endian.little); offset += 4;
  buffer.setUint16(offset, numChannels * bitsPerSample ~/ 8, Endian.little); offset += 2;
  buffer.setUint16(offset, bitsPerSample, Endian.little); offset += 2;

  // data chunk
  for (final c in [0x64, 0x61, 0x74, 0x61]) buffer.setUint8(offset++, c);
  buffer.setUint32(offset, dataSize, Endian.little); offset += 4;

  for (final sample in samples) {
    buffer.setInt16(offset, (sample.clamp(-1.0, 1.0) * 32767).toInt(), Endian.little);
    offset += 2;
  }

  return buffer.buffer.asUint8List();
}
