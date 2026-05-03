import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layar kuis edukasi tentang polusi udara dan kesehatan pernapasan.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _score = 0;
  int _highScore = 0;
  int _currentIndex = 0;
  bool _isFinished = false;
  int? _selectedAnswer;
  bool _isAnswered = false;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Gas apa yang paling banyak dihasilkan dari kendaraan bermotor dan berbahaya jika dihirup dalam ruang tertutup?',
      'options': ['Oksigen (O2)', 'Karbon Monoksida (CO)', 'Nitrogen (N2)', 'Hidrogen (H2)'],
      'answer': 1,
      'explanation': 'Karbon Monoksida (CO) adalah gas beracun tidak berbau dari sisa pembakaran mesin yang bisa mematikan jika terhirup di ruang tertutup.',
    },
    {
      'question': 'Partikel polutan yang ukurannya lebih kecil dari 2.5 mikrometer disebut?',
      'options': ['PM 10', 'Ozon', 'PM 2.5', 'Aerosol'],
      'answer': 2,
      'explanation': 'PM 2.5 adalah debu sangat halus yang ukurannya 30x lebih kecil dari rambut manusia, mampu masuk ke aliran darah.',
    },
    {
      'question': 'Masker jenis apa yang paling efektif menyaring partikel PM 2.5?',
      'options': ['Masker Kain', 'Masker Bedah', 'Masker N95', 'Masker Scuba'],
      'answer': 2,
      'explanation': 'Masker N95 dirancang khusus untuk menyaring 95% partikel udara, termasuk PM2.5, tidak seperti masker kain biasa.',
    },
    {
      'question': 'Indeks Standar Pencemar Udara (ISPU) yang dikategorikan SANGAT TIDAK SEHAT berada di rentang angka?',
      'options': ['0 - 50', '51 - 100', '101 - 199', '200 - 299'],
      'answer': 3,
      'explanation': 'Rentang 200-299 dikategorikan sangat tidak sehat dan dapat merugikan kesehatan secara meluas bagi semua populasi.',
    },
    {
      'question': 'Berikut ini adalah dampak buruk polusi udara bagi kesehatan manusia, kecuali...',
      'options': ['Katarak', 'Asma', 'ISPA', 'Kanker Paru'],
      'answer': 0,
      'explanation': 'Katarak adalah penyakit mata akibat radiasi UV atau penuaan, bukan secara langsung karena polusi udara pernapasan.',
    },
    {
      'question': 'Aktivitas manusia mana yang menjadi penyumbang terbesar efek rumah kaca?',
      'options': ['Mendaur ulang kertas', 'Pembakaran bahan bakar fosil', 'Menanam pohon', 'Menggunakan panel surya'],
      'answer': 1,
      'explanation': 'Membakar batu bara, minyak bumi, dan gas melepaskan miliaran ton emisi karbon ke atmosfer setiap tahunnya.',
    },
    {
      'question': 'Polutan apa yang dapat menyebabkan hujan asam?',
      'options': ['Sulfur Dioksida (SO2)', 'Karbondioksida (CO2)', 'Metana (CH4)', 'Oksigen (O2)'],
      'answer': 0,
      'explanation': 'SO2 dan Nitrogen Oksida (NOx) bereaksi dengan air di udara membentuk asam sulfat penyebab hujan asam.',
    },
    {
      'question': 'Waktu yang paling disarankan untuk berolahraga di luar ruangan agar terhindar dari polusi kendaraan yang tinggi adalah?',
      'options': ['Pagi hari sebelum jam 6', 'Siang hari bolong', 'Jam pulang kerja sore', 'Tengah malam'],
      'answer': 0,
      'explanation': 'Pagi buta (sebelum jam 6) biasanya memiliki tingkat emisi kendaraan terendah karena aktivitas lalu lintas belum padat.',
    },
    {
      'question': 'Lapisan di atmosfer yang berfungsi melindungi bumi dari radiasi UV matahari adalah...',
      'options': ['Troposfer', 'Lapisan Ozon', 'Eksosfer', 'Mesosfer'],
      'answer': 1,
      'explanation': 'Ozon (O3) di lapisan stratosfer bertindak sebagai perisai penyerap UV, namun ozon di permukaan tanah justru merupakan polutan beracun.',
    },
    {
      'question': 'Alat yang sering diletakkan di dalam rumah untuk membersihkan udara dari virus dan polutan disebut?',
      'options': ['Air Conditioner (AC)', 'Air Purifier', 'Exhaust Fan', 'Vacuum Cleaner'],
      'answer': 1,
      'explanation': 'Air Purifier dengan filter HEPA didesain khusus untuk menjebak debu, bakteri, dan partikel udara kotor di dalam ruangan.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _questions.shuffle();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _highScore = prefs.getInt('quiz_highscore') ?? 0);
  }

  Future<void> _saveHighScore(int score) async {
    if (score > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('quiz_highscore', score);
      setState(() => _highScore = score);
    }
  }

  void _answerQuestion(int index) {
    if (_isAnswered) return;
    setState(() {
      _selectedAnswer = index;
      _isAnswered = true;
    });
    if (index == _questions[_currentIndex]['answer']) _score += 10;
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _selectedAnswer = null;
      });
    } else {
      _saveHighScore(_score);
      setState(() => _isFinished = true);
    }
  }

  void _restartQuiz() {
    setState(() {
      _score = 0;
      _currentIndex = 0;
      _isFinished = false;
      _isAnswered = false;
      _selectedAnswer = null;
      _questions.shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kuis Udara Bersih')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.teal.shade50, Colors.white]),
        ),
        padding: const EdgeInsets.all(16.0),
        child: _isFinished ? _buildResult() : _buildQuiz(),
      ),
    );
  }

  Widget _buildQuiz() {
    final question = _questions[_currentIndex];
    final int correctAnswer = question['answer'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: Colors.grey[300],
          color: Colors.teal,
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
        ),
        const SizedBox(height: 16),
        Text(
          'Soal ${_currentIndex + 1} dari ${_questions.length}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(question['question'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView(
            children: (question['options'] as List<String>).asMap().entries.map((entry) {
              final idx = entry.key;
              final text = entry.value;

              Color btnColor = Colors.white;
              Color textColor = Colors.black87;
              if (_isAnswered) {
                if (idx == correctAnswer) {
                  btnColor = Colors.green;
                  textColor = Colors.white;
                } else if (idx == _selectedAnswer) {
                  btnColor = Colors.red;
                  textColor = Colors.white;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnColor,
                    foregroundColor: textColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isAnswered ? null : () => _answerQuestion(idx),
                  child: Text(text, style: const TextStyle(fontSize: 16)),
                ),
              );
            }).toList(),
          ),
        ),
        if (_isAnswered) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedAnswer == correctAnswer ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _selectedAnswer == correctAnswer ? Colors.green : Colors.red),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _selectedAnswer == correctAnswer ? 'Bener Banget! 🎉' : 'Kurang Tepat! 😢',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _selectedAnswer == correctAnswer ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(question['explanation'], style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _nextQuestion,
            child: const Text('Lanjut ke Soal Berikutnya', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  Widget _buildResult() {
    return Center(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.orange, size: 80),
              const SizedBox(height: 16),
              const Text('Kuis Selesai!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Text('Skor Anda', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              Text('$_score', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal)),
              const SizedBox(height: 16),
              Text('Skor Tertinggi: $_highScore', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _restartQuiz,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Main Lagi', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
