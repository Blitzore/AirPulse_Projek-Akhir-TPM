import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Layar konversi mata uang real-time dan zona waktu global.
class ConversionScreen extends StatefulWidget {
  const ConversionScreen({super.key});

  @override
  State<ConversionScreen> createState() => _ConversionScreenState();
}

class _ConversionScreenState extends State<ConversionScreen> {
  Map<String, dynamic>? _rates;
  bool _isLoadingRates = true;
  final _amountController = TextEditingController(text: '1');

  String _selectedBaseCurrency = 'IDR';
  static const _availableCurrencies = ['IDR', 'USD', 'EUR', 'GBP', 'JPY', 'SGD', 'MYR', 'AUD'];
  Map<String, double> _currencyResults = {};

  late Timer _timer;
  DateTime _utcTime = DateTime.now().toUtc();

  String _selectedBaseTimezone = 'WIB';
  static const Map<String, int> _timezones = {
    'WIB (Waktu Indonesia Barat)': 7,
    'WITA (Waktu Indonesia Tengah)': 8,
    'WIT (Waktu Indonesia Timur)': 9,
    'London (GMT/BST)': 1,
    'New York (EST)': -5,
    'Tokyo (JST)': 9,
    'Sydney (AEST)': 10,
    'UTC (Universal)': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchRates();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _utcTime = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchRates() async {
    final data = await ApiService.getExchangeRates();
    setState(() {
      _rates = data?['rates'];
      _isLoadingRates = false;
    });
    _convertCurrency();
  }

  void _convertCurrency() {
    if (_rates == null || _amountController.text.isEmpty) {
      setState(() => _currencyResults.clear());
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final baseRateToIdr = (_rates![_selectedBaseCurrency] as num?)?.toDouble() ?? 1.0;
    final amountInIdr = amount / baseRateToIdr;

    final results = <String, double>{};
    for (final currency in _availableCurrencies) {
      if (currency != _selectedBaseCurrency) {
        final rate = (_rates![currency] as num?)?.toDouble() ?? 1.0;
        results[currency] = amountInIdr * rate;
      }
    }
    setState(() => _currencyResults = results);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Alat Bantu Global'),
          bottom: const TabBar(tabs: [Tab(text: 'Mata Uang'), Tab(text: 'Waktu')]),
        ),
        body: TabBarView(children: [_buildCurrencyTab(), _buildTimeTab()]),
      ),
    );
  }

  Widget _buildCurrencyTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBanner('Konversi mata uang global untuk mempermudah kalkulasi biaya pembelian masker/air purifier dari luar negeri.'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedBaseCurrency,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: _availableCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedBaseCurrency = val);
                      _convertCurrency();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Jumlah', border: OutlineInputBorder()),
                  onChanged: (_) => _convertCurrency(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingRates)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_rates == null)
            const Expanded(child: Center(child: Text('Gagal memuat kurs. Cek koneksi internet Anda.')))
          else
            Expanded(
              child: ListView(
                children: _currencyResults.entries.map((entry) {
                  return Card(
                    color: Colors.white,
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.withOpacity(0.1),
                        child: Text(entry.key, style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(entry.key),
                      trailing: Text(entry.value.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeTab() {
    final exactBaseKey = _timezones.keys.firstWhere((k) => k.startsWith(_selectedBaseTimezone), orElse: () => _timezones.keys.first);
    final baseOffset = _timezones[exactBaseKey] ?? 0;
    final baseTime = _utcTime.add(Duration(hours: baseOffset));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildInfoBanner('Konversi waktu ini berguna untuk mencocokkan jam pelaporan AQI dari stasiun internasional secara sinkron.'),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.teal.withOpacity(0.05),
          child: Column(
            children: [
              DropdownButton<String>(
                value: exactBaseKey,
                isExpanded: true,
                items: _timezones.keys.map((key) => DropdownMenuItem(value: key, child: Text(key))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBaseTimezone = val.split(' ')[0]);
                },
              ),
              const SizedBox(height: 8),
              Text(
                _formatTime(baseTime),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: _timezones.entries.map((entry) {
              if (entry.key == exactBaseKey) return const SizedBox.shrink();
              final targetTime = _utcTime.add(Duration(hours: entry.value));
              final diff = entry.value - baseOffset;
              final diffStr = diff > 0 ? '+$diff jam' : (diff < 0 ? '$diff jam' : 'Sama');

              return Card(
                color: Colors.white,
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.access_time_filled, color: Colors.teal),
                  title: Text(entry.key),
                  subtitle: Text('Selisih: $diffStr'),
                  trailing: Text(
                    '${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Helper ──

  Widget _buildInfoBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.blue))),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
