/// Modelo de datos para las tasas oficiales del Banco Central de Venezuela (BCV)
class BcvData {
  final double usd;
  final double eur;
  final String date;
  final double? previousUsd;
  final double? previousEur;
  final bool hayTasaNueva;
  final double? tasaNuevaUsd;
  final double? tasaNuevaEur;
  final String? tasaNuevaFechaTexto;

  BcvData({
    required this.usd,
    required this.eur,
    required this.date,
    this.previousUsd,
    this.previousEur,
    this.hayTasaNueva = false,
    this.tasaNuevaUsd,
    this.tasaNuevaEur,
    this.tasaNuevaFechaTexto,
  });

  factory BcvData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>?;
    final previous = json['previous'] as Map<String, dynamic>?;

    if (current != null && previous != null) {
      final curUsd = double.tryParse(current['usd'].toString()) ?? 0.0;
      final curEur = double.tryParse(current['eur'].toString()) ?? 0.0;
      final prevUsd = double.tryParse(previous['usd'].toString()) ?? 0.0;
      final prevEur = double.tryParse(previous['eur'].toString()) ?? 0.0;
      final currentDateStr = current['date']?.toString() ?? '';

      // Comprobar si la fecha de la tasa emitida es posterior a hoy (Tasa Nueva para Mañana)
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final isFuture = currentDateStr.compareTo(todayStr) > 0;

      if (isFuture) {
        return BcvData(
          usd: prevUsd > 0 ? prevUsd : curUsd,
          eur: prevEur > 0 ? prevEur : curEur,
          date: todayStr,
          previousUsd: prevUsd,
          previousEur: prevEur,
          hayTasaNueva: true,
          tasaNuevaUsd: curUsd,
          tasaNuevaEur: curEur,
          tasaNuevaFechaTexto: "Mañana $currentDateStr",
        );
      } else {
        return BcvData(
          usd: curUsd,
          eur: curEur,
          date: currentDateStr,
          previousUsd: prevUsd,
          previousEur: prevEur,
          hayTasaNueva: false,
        );
      }
    }

    return BcvData(
      usd: double.tryParse(json['usd']?.toString() ?? '') ?? 0.0,
      eur: double.tryParse(json['eur']?.toString() ?? '') ?? 0.0,
      date: json['date']?.toString() ?? '',
    );
  }
}

/// Modelo de datos para Binance P2P (vía CriptoYa)
class BinanceP2PData {
  final double rate;
  final double ask;
  final double bid;

  BinanceP2PData({
    required this.rate,
    required this.ask,
    required this.bid,
  });

  factory BinanceP2PData.fromJson(Map<String, dynamic> json) {
    final askVal = double.tryParse(json['ask']?.toString() ?? '') ?? 0.0;
    final bidVal = double.tryParse(json['bid']?.toString() ?? '') ?? 0.0;
    final avg = (askVal > 0 && bidVal > 0) ? (askVal + bidVal) / 2 : (askVal > 0 ? askVal : bidVal);

    return BinanceP2PData(
      rate: avg,
      ask: askVal,
      bid: bidVal,
    );
  }
}

