import 'dart:math' as math;
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

class _HomeConverterScreenState extends State<HomeConverterScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _divisaController = TextEditingController(text: '100');
  final TextEditingController _bsController = TextEditingController();
  final TextEditingController _customRateController = TextEditingController();

  final NumberFormat _fmt = NumberFormat('#,##0.00', 'es_VE');
  final NumberFormat _rateFmt = NumberFormat('#,##0.0000', 'es_VE');

  BcvData? _bcv;
  BinanceP2PData? _p2p;
  bool _isLoading = true;
  bool _usarTasaNueva = false;
  String _selectedMode = 'USD'; // 'USD', 'EUR', 'USDT', 'PROPIA'
  String _lastSyncText = 'Cargando...';

  // Historial de cálculos en memoria
  final List<Map<String, dynamic>> _history = [];

  // Animación del botón refrescar
  late AnimationController _refreshAnimController;

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loadRates();
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
    _divisaController.dispose();
    _bsController.dispose();
    _customRateController.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    setState(() => _isLoading = true);
    _refreshAnimController.repeat();

    final bcv = await ApiService.fetchBcvRates();
    final p2p = await ApiService.fetchBinanceP2P();

    final now = DateTime.now();
    final timeStr = DateFormat('hh:mm a').format(now);

    setState(() {
      _bcv = bcv;
      _p2p = p2p;
      _isLoading = false;
      _lastSyncText = 'Hoy $timeStr';
    });

    _refreshAnimController.forward(from: 0);

    if (bcv != null) {
      await WidgetService.updateRatesWidget(bcv: bcv, p2p: p2p);
    }

    _recalcularDesdeDivisa();
  }

  double get _tasaActiva {
    if (_selectedMode == 'PROPIA') {
      final custom = double.tryParse(_customRateController.text.replaceAll(',', '.')) ?? 0.0;
      return custom > 0 ? custom : (_bcv?.usd ?? 1.0);
    }

    if (_bcv == null) return 1.0;

    if (_selectedMode == 'USD') {
      return (_usarTasaNueva && _bcv!.hayTasaNueva && _bcv!.tasaNuevaUsd != null)
          ? _bcv!.tasaNuevaUsd!
          : _bcv!.usd;
    } else if (_selectedMode == 'EUR') {
      return (_usarTasaNueva && _bcv!.hayTasaNueva && _bcv!.tasaNuevaEur != null)
          ? _bcv!.tasaNuevaEur!
          : _bcv!.eur;
    } else if (_selectedMode == 'USDT') {
      return _p2p?.rate ?? _bcv!.usd;
    }
    return _bcv!.usd;
  }

  void _recalcularDesdeDivisa([String? val]) {
    final text = val ?? _divisaController.text;
    final divisa = double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
    final bs = divisa * _tasaActiva;
    _bsController.text = bs > 0 ? _fmt.format(bs) : '';
    setState(() {});
  }

  void _recalcularDesdeBs(String val) {
    final bs = double.tryParse(val.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
    final tasa = _tasaActiva;
    final divisa = tasa > 0 ? (bs / tasa) : 0.0;
    _divisaController.text = divisa > 0 ? divisa.toStringAsFixed(2) : '';
    setState(() {});
  }

  void _aplicarOperador(String op) {
    HapticFeedback.lightImpact();
    if (op == 'C') {
      _divisaController.text = '';
      _bsController.text = '';
      setState(() {});
      return;
    }

    if (op == '=') {
      _resolverExpresion();
      return;
    }

    final cur = _divisaController.text;
    _divisaController.text = cur + op;
    setState(() {});
  }

  void _sumarPreset(double add) {
    HapticFeedback.lightImpact();
    final current = double.tryParse(_divisaController.text.replaceAll(',', '.')) ?? 0.0;
    final total = current + add;
    _divisaController.text = total.toStringAsFixed(total % 1 == 0 ? 0 : 2);
    _recalcularDesdeDivisa();
  }

  void _resolverExpresion() {
    try {
      final expr = _divisaController.text.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-');
      // Evaluación aritmética simple y segura
      final clean = expr.replaceAll(RegExp(r'[^0-9\+\-\*\/\.\(\)]'), '');
      if (clean.isEmpty) return;

      // Solución para expresiones directas
      final res = _evaluarAritmetica(clean);
      if (res != null) {
        _divisaController.text = res.toStringAsFixed(res % 1 == 0 ? 0 : 2);
        _recalcularDesdeDivisa();
      }
    } catch (_) {}
  }

  double? _evaluarAritmetica(String exp) {
    try {
      // Soporte rápido para sumas, restas, productos y divisiones secuenciales
      final tokens = RegExp(r'([0-9\.]+|[\+\-\*\/])').allMatches(exp).map((m) => m.group(0)!).toList();
      if (tokens.isEmpty) return null;

      double acc = double.tryParse(tokens[0]) ?? 0.0;
      for (int i = 1; i < tokens.length - 1; i += 2) {
        final op = tokens[i];
        final nextVal = double.tryParse(tokens[i + 1]) ?? 0.0;
        if (op == '+') acc += nextVal;
        if (op == '-') acc -= nextVal;
        if (op == '*') acc *= nextVal;
        if (op == '/' && nextVal != 0) acc /= nextVal;
      }
      return acc;
    } catch (_) {
      return null;
    }
  }

  void _copiarMontoBancario() {
    final divisa = double.tryParse(_divisaController.text.replaceAll(',', '.')) ?? 0.0;
    final montoBs = divisa * _tasaActiva;

    // Formato estricto para Pago Móvil / Banca venezolana: XXXX,XX
    final textoBancario = montoBs.toStringAsFixed(2).replaceAll('.', ',');
    Clipboard.setData(ClipboardData(text: textoBancario));
    HapticFeedback.mediumImpact();

    // Guardar en historial
    setState(() {
      _history.insert(0, {
        'divisa': divisa,
        'simbolo': _selectedMode == 'EUR' ? '€' : (_selectedMode == 'USDT' ? 'USDT' : '\$'),
        'bs': montoBs,
        'tasa': _tasaActiva,
        'hora': DateFormat('hh:mm a').format(DateTime.now()),
      });
      if (_history.length > 20) _history.removeLast();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Copiado para banco: $textoBancario Bs', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Spreads porcentuales
  String _calcularSpread(double base, double comp) {
    if (base <= 0 || comp <= 0) return '0.00%';
    final diff = ((comp - base) / base) * 100;
    final sign = diff >= 0 ? '+' : '';
    return '$sign${diff.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    final tasaUsd = (_usarTasaNueva && _bcv?.hayTasaNueva == true) ? (_bcv?.tasaNuevaUsd ?? 0) : (_bcv?.usd ?? 0);
    final tasaEur = (_usarTasaNueva && _bcv?.hayTasaNueva == true) ? (_bcv?.tasaNuevaEur ?? 0) : (_bcv?.eur ?? 0);
    final tasaUsdt = _p2p?.rate ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Slate 950 exacto de Valo Web
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // ==========================================
            // 🌟 1. CABECERA ESTILO VALO PWA
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Badge VALO
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5)),
                          ),
                          child: const Text(
                            'VALO',
                            style: TextStyle(
                              color: Color(0xFF60A5FA),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badge Versión
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                          ),
                          child: const Text(
                            'v1.8.1',
                            style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    // Acciones de cabecera
                    Row(
                      children: [
                        // Botón de Refrescar con giro táctil
                        GestureDetector(
                          onTap: _isLoading ? null : _loadRates,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withOpacity(0.8),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Center(
                              child: RotationTransition(
                                turns: _refreshAnimController,
                                child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ==========================================
            // 🟢 2. BARRA DE SINCRONIZACIÓN SUTIL
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF10B981).withOpacity(0.6), blurRadius: 6, spreadRadius: 1),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Sincronización Automática',
                            style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        _isLoading ? 'Actualizando...' : _lastSyncText,
                        style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // 🏛️ 3. HERO PANEL DE COTIZACIONES
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withOpacity(0.9), // Slate 900
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      // Encabezado del Hero
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TASAS OFICIALES Y DE MERCADO',
                            style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                          ),
                          if (_bcv?.hayTasaNueva == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                              ),
                              child: const Text('✨ Tasa Nueva', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Dólar BCV y Euro BCV lado a lado
                      Row(
                        children: [
                          // Dólar BCV Card
                          Expanded(
                            child: _buildHeroRateCard(
                              emoji: '💵',
                              label: 'Dólar BCV',
                              rate: _rateFmt.format(tasaUsd),
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Euro BCV Card
                          Expanded(
                            child: _buildHeroRateCard(
                              emoji: '💶',
                              label: 'Euro BCV',
                              rate: _rateFmt.format(tasaEur),
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Binance P2P USDT Card
                      _buildHeroRateCard(
                        emoji: '🪙',
                        label: 'USDT P2P (Binance)',
                        rate: _rateFmt.format(tasaUsdt),
                        color: const Color(0xFFF59E0B),
                        isFullWidth: true,
                      ),
                      const SizedBox(height: 12),

                      // Spreads duales
                      Row(
                        children: [
                          Expanded(
                            child: _buildSpreadPill('USD vs USDT', _calcularSpread(tasaUsd, tasaUsdt), const Color(0xFF3B82F6)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSpreadPill('EUR vs USDT', _calcularSpread(tasaEur, tasaUsdt), const Color(0xFFA855F7)),
                          ),
                        ],
                      ),

                      // ==========================================
                      // ✨ 4. BANNER TASA NUEVA MAÑANA
                      // ==========================================
                      if (_bcv?.hayTasaNueva == true) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Text('✨', style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('¡Nueva Tasa BCV Emitida!', style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text(
                                          'Rige ${_bcv?.tasaNuevaFechaTexto ?? 'próximo día hábil'}: Bs. ${_rateFmt.format(_bcv?.tasaNuevaUsd ?? 0)}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Conmutador Tasa Hoy / Tasa Nueva
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _usarTasaNueva = false);
                                        _recalcularDesdeDivisa();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: !_usarTasaNueva ? const Color(0xFF3B82F6).withOpacity(0.2) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: !_usarTasaNueva ? const Color(0xFF3B82F6) : Colors.transparent),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '📅 Tasa Hoy',
                                          style: TextStyle(
                                            color: !_usarTasaNueva ? const Color(0xFF60A5FA) : Colors.white54,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _usarTasaNueva = true);
                                        _recalcularDesdeDivisa();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _usarTasaNueva ? const Color(0xFFF59E0B).withOpacity(0.2) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: _usarTasaNueva ? const Color(0xFFF59E0B) : Colors.transparent),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '✨ Tasa Nueva',
                                          style: TextStyle(
                                            color: _usarTasaNueva ? const Color(0xFFFBBF24) : Colors.white54,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // 🧮 5. SECCIÓN PRINCIPAL DEL CONVERSOR
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SELECTOR DE DIVISAS
                      Row(
                        children: [
                          _buildCurrencyTab('USD', '💵 Dólar'),
                          _buildCurrencyTab('EUR', '💶 Euro'),
                          _buildCurrencyTab('USDT', '🪙 USDT'),
                          _buildCurrencyTab('PROPIA', '✍️ Propia'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Input si selecciona Tasa Propia
                      if (_selectedMode == 'PROPIA') ...[
                        TextField(
                          controller: _customRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Ingresa tu tasa personalizada (Bs)',
                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                            prefixText: 'Bs. ',
                            prefixStyle: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                            filled: true,
                            fillColor: const Color(0xFF0B0F19),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onChanged: (_) => _recalcularDesdeDivisa(),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // INPUTS BIDIRECCIONALES (Divisa ⇄ Bolívares)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Input Divisas
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedMode == 'EUR' ? 'Euros (€)' : (_selectedMode == 'USDT' ? 'USDT' : 'Dólares (\$)'),
                                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _divisaController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    prefixText: _selectedMode == 'EUR' ? '€ ' : '\$ ',
                                    prefixStyle: const TextStyle(color: Color(0xFF60A5FA), fontSize: 20, fontWeight: FontWeight.bold),
                                    filled: true,
                                    fillColor: const Color(0xFF0B0F19),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  onChanged: _recalcularDesdeDivisa,
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            child: Text('⇄', style: TextStyle(color: Colors.white38, fontSize: 22)),
                          ),
                          // Input Bolívares
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Bolívares (Bs)', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _bsController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    prefixText: 'Bs ',
                                    prefixStyle: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.bold),
                                    filled: true,
                                    fillColor: const Color(0xFF0B0F19),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  onChanged: _recalcularDesdeBs,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // BOTONES PRESET (+10, +50, +100)
                      Row(
                        children: [
                          _buildPresetChip('+10', 10),
                          const SizedBox(width: 8),
                          _buildPresetChip('+50', 50),
                          const SizedBox(width: 8),
                          _buildPresetChip('+100', 100),
                          const Spacer(),
                          // Botón borrar
                          GestureDetector(
                            onTap: () => _aplicarOperador('C'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                              ),
                              child: const Text('Limpiar C', style: TextStyle(color: Color(0xFFF87171), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // BARRA DE OPERADORES MATEMÁTICOS (+, -, *, /, =)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F19),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildOpButton('+'),
                            _buildOpButton('−'),
                            _buildOpButton('×'),
                            _buildOpButton('÷'),
                            _buildOpButton('('),
                            _buildOpButton(')'),
                            _buildOpButton('=', isEquals: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // CAJA DE RESULTADO FINAL EN VERDE ESMERALDA
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F19),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL EN BOLÍVARES', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                            const SizedBox(height: 4),
                            Text(
                              _bsController.text.isNotEmpty ? 'Bs. ${_bsController.text}' : 'Bs. 0,00',
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 32, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // BOTÓN COPIAR PARA BANCA / PAGO MÓVIL
                      ElevatedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copiar para Pago Móvil / Banco', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _copiarMontoBancario,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // 📜 6. HISTORIAL DE CÁLCULOS
            // ==========================================
            if (_history.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'HISTORIAL RECIENTE',
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _history.clear()),
                        child: const Text('Borrar', style: TextStyle(color: Color(0xFFF87171), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _history[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item['simbolo']} ${item['divisa']}  →  Bs. ${_fmt.format(item['bs'])}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text('Tasa: Bs. ${_rateFmt.format(item['tasa'])} • ${item['hora']}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.reply_rounded, color: Color(0xFF60A5FA), size: 18),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _divisaController.text = item['divisa'].toString();
                                _recalcularDesdeDivisa();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _history.length,
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 50)),
          ],
        ),
      ),
    );
  }

  // WIDGETS AUXILIARES
  Widget _buildHeroRateCard({
    required String emoji,
    required String label,
    required String rate,
    required Color color,
    bool isFullWidth = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isFullWidth ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: isFullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isFullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            rate.isNotEmpty ? 'Bs. $rate' : 'Bs. ---',
            style: TextStyle(
              color: Colors.white,
              fontSize: isFullWidth ? 18 : 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadPill(String title, String spread, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(spread, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildCurrencyTab(String mode, String label) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedMode = mode);
          _recalcularDesdeDivisa();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF60A5FA) : Colors.white54,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double add) {
    return GestureDetector(
      onTap: () => _sumarPreset(add),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildOpButton(String op, {bool isEquals = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _aplicarOperador(op),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isEquals ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            op,
            style: TextStyle(
              color: isEquals ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
