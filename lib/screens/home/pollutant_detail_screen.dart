import 'package:flutter/material.dart';

/// Layar detail untuk menampilkan informasi polutan/metrik cuaca.
class PollutantDetailScreen extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String description;
  final String interpretation;

  const PollutantDetailScreen({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.description,
    required this.interpretation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Info $title')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF03045E), Color(0xFF0077B6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF03045E))),
                        const SizedBox(height: 16),
                        Text(value, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Color(0xFF00B4D8))),
                        Text(unit, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Text(
                            interpretation,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text('Apa itu dan apa dampaknya?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Text(description, style: const TextStyle(fontSize: 16, height: 1.5), textAlign: TextAlign.justify),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
