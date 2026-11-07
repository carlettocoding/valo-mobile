import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rate_data.dart';

class ApiService {
  static const Duration timeoutDuration = Duration(seconds: 4);

  /// 1. Consulta del Dólar y Euro Oficial (BCV)
  static Future<BcvData?> fetchBcvRates() async {
    // Proveedor Primario: DolarVzla (rates.dolarvzla.com) con cache-busting
    try {
      final uri = Uri.parse('https://rates.dolarvzla.com/bcv/current.json?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bcv = BcvData.fromJson(data);
        await _cacheBcv(bcv);
        return bcv;
      }
    } catch (_) {
      // Fallback silencioso a proveedor secundario
    }

    // Fallback: DolarAPI Oficial
    try {
      final uriUsd = Uri.parse('https://ve.dolarapi.com/v1/dolares/oficial');
      final uriEur = Uri.parse('https://ve.dolarapi.com/v1/euros/oficial');

      final results = await Future.wait([
        http.get(uriUsd).timeout(timeoutDuration),
        http.get(uriEur).timeout(timeoutDuration),
      ]);

      if (results[0].statusCode == 200 && results[1].statusCode == 200) {
        final dataUsd = jsonDecode(results[0].body);
        final dataEur = jsonDecode(results[1].body);

        final bcv = BcvData(
          usd: double.tryParse(dataUsd['promedio']?.toString() ?? '') ?? 0.0,
          eur: double.tryParse(dataEur['promedio']?.toString() ?? '') ?? 0.0,
          date: dataUsd['fechaActualizacion']?.toString() ?? '',
          hayTasaNueva: false,
        );
        await _cacheBcv(bcv);
        return bcv;
      }
    } catch (_) {
      // Sin conexión externa
    }

    // Si no hay red, recuperar la última cotización guardada en caché local
    return _loadCachedBcv();
  }

  /// 2. Consulta de Binance P2P (USDT Paralelo)
  /// Regla estricta del proyecto: Solo CriptoYa. Prohibido Yadio.
  static Future<BinanceP2PData?> fetchBinanceP2P() async {
    try {
      final uri = Uri.parse('https://criptoya.com/api/binancep2p/USDT/VES/1');
      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final p2p = BinanceP2PData.fromJson(data);
        await _cacheBinanceP2P(p2p);
        return p2p;
      }
    } catch (_) {
      // Fallback a caché local
    }

    return _loadCachedBinanceP2P();
  }

  // Métodos auxiliares de persistencia offline
  static Future<void> _cacheBcv(BcvData bcv) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('cached_bcv_usd', bcv.usd);
    await prefs.setDouble('cached_bcv_eur', bcv.eur);
    await prefs.setBool('cached_hay_nueva', bcv.hayTasaNueva);
    if (bcv.tasaNuevaUsd != null) {
      await prefs.setDouble('cached_nueva_usd', bcv.tasaNuevaUsd!);
    }
  }

  static Future<BcvData?> _loadCachedBcv() async {
    final prefs = await SharedPreferences.getInstance();
    final usd = prefs.getDouble('cached_bcv_usd');
    final eur = prefs.getDouble('cached_bcv_eur');
    final hayNueva = prefs.getBool('cached_hay_nueva') ?? false;
    final nuevaUsd = prefs.getDouble('cached_nueva_usd');

    if (usd != null && eur != null && usd > 0) {
      return BcvData(
        usd: usd,
        eur: eur,
        date: 'Caché local',
        hayTasaNueva: hayNueva,
        tasaNuevaUsd: nuevaUsd,
      );
    }
    return null;
  }

  static Future<void> _cacheBinanceP2P(BinanceP2PData p2p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('cached_p2p_rate', p2p.rate);
  }

  static Future<BinanceP2PData?> _loadCachedBinanceP2P() async {
    final prefs = await SharedPreferences.getInstance();
    final rate = prefs.getDouble('cached_p2p_rate');
    if (rate != null && rate > 0) {
      return BinanceP2PData(rate: rate, ask: rate, bid: rate);
    }
    return null;
  }
}

