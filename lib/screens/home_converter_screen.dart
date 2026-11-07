import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/rate_data.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';

class HomeConverterScreen extends StatefulWidget {
  const HomeConverterScreen({super.key});

  @override
  State<HomeConverterScreen> createState() => _HomeConverterScreenState();
}

class _HomeConverterScreenState extends State<HomeConverterScreen> {
  final TextEditingController _amountController = TextEditingController(text: '100');
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'es_VE');
  final NumberFormat _rateFmt = NumberFormat('#,##0.0000', 'es_VE');

  BcvData? _bcv;
  BinanceP2PData? _p2p;
  bool _isLoading = true;
  bool _usarTasaNueva = false;
  String _selectedCurrency = 'USD_BCV'; // 'USD_BCV', 'EUR_BCV', 'USDT_P2P'

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    setState(() => _isLoading = true);
    final bcv = await ApiService.fetchBcvRates();
    final p2p = await ApiService.fetchBinanceP2P();

    setState(() {
      _bcv = bcv;
      _p2p = p2p;
      _isLoading = false;
    });

    if (bcv != null) {
      await WidgetService.updateRatesWidget(bcv: bcv, p2p: p2p);
    }
  }

  double get _currentActiveRate {
    if (_bcv == null) return 0.0;

    if (_selectedCurrency == 'USD_BCV') {
      return (_usarTasaNueva && _bcv!.hayTasaNueva && _bcv!.tasaNuevaUsd != null)
          ? _bcv!.tasaNuevaUsd!
          : _bcv!.usd;
    } else if (_selectedCurrency == 'EUR_BCV') {
      return (_usarTasaNueva && _bcv!.hayTasaNueva && _bcv!.tasaNuevaEur != null)
          ? _bcv!.tasaNuevaEur!
          : _bcv!.eur;
    } else if (_selectedCurrency == 'USDT_P2P') {
      return _p2p?.rate ?? 0.0;
    }
    return _bcv!.usd;
  }

  double get _calculatedBs {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    return amount * _currentActiveRate;
  }

  void _copiarMontoBancario() {
    final montoBs = _calculatedBs;
    // Formato bancario estricto: XXXX,XX (2 decimales con coma, sin separador de miles)
    final textoBancario = montoBs.toStringAsFixed(2).replaceAll('.', ',');
    Clipboard.setData(ClipboardData(text: textoBancario));
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Monto copiado para banca móvil: $textoBancario"),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF3B82F6)),
              ),
              child: const Text('VALO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF60A5FA))),
            ),
            const SizedBox(width: 8),
            const Text('Conversor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _isLoading ? null : _loadRates,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. BANNER TASA NUEVA MAÑANA (Si está emitida)
              if (_bcv?.hayTasaNueva == true) ...[
                _buildNuevaTasaBanner(),
                const SizedBox(height: 16),
              ],

              // 2. PANEL HERO DE TASAS
              _buildHeroRatesPanel(),
              const SizedBox(height: 20),

              // 3. TARJETA DE CONVERSIÓN
              _buildConverterCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNuevaTasaBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tasa Emitida para Mañana', style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      'USD: Bs. ${_rateFmt.format(_bcv?.tasaNuevaUsd ?? 0)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: _usarTasaNueva,
            activeColor: const Color(0xFFF59E0B),
            onChanged: (val) {
              HapticFeedback.selectionClick();
              setState(() => _usarTasaNueva = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroRatesPanel() {
    final tasaUsd = (_usarTasaNueva && _bcv?.hayTasaNueva == true) ? (_bcv?.tasaNuevaUsd ?? 0) : (_bcv?.usd ?? 0);
    final tasaEur = (_usarTasaNueva && _bcv?.hayTasaNueva == true) ? (_bcv?.tasaNuevaEur ?? 0) : (_bcv?.eur ?? 0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildRateCard('Dólar BCV', 'Bs. ${_rateFmt.format(tasaUsd)}', const Color(0xFF3B82F6), 'USD_BCV'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRateCard('Euro BCV', 'Bs. ${_rateFmt.format(tasaEur)}', const Color(0xFF10B981), 'EUR_BCV'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRateCard('USDT Binance P2P', 'Bs. ${_rateFmt.format(_p2p?.rate ?? 0)}', const Color(0xFFF59E0B), 'USDT_P2P', fullWidth: true),
      ],
    );
  }

  Widget _buildRateCard(String title, String rateStr, Color accentColor, String id, {bool fullWidth = false}) {
    final isSelected = _selectedCurrency == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCurrency = id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(rateStr, style: TextStyle(color: Colors.white, fontSize: fullWidth ? 18 : 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildConverterCard() {
    final montoBs = _calculatedBs;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Monto en Divisas', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: const TextStyle(fontSize: 26, color: Color(0xFF60A5FA)),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          const Text('Total en Bolívares (VES)', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            'Bs. ${_fmt.format(montoBs)}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar para Pago Móvil / Banco', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _copiarMontoBancario,
          ),
        ],
      ),
    );
  }
}

