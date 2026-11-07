import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/rate_data.dart';

class WidgetService {
  static const String appGroupId = 'group.com.carlitos.valo.dev';
  static const String iOSWidgetName = 'ValoWidget';
  static const String androidWidgetName = 'ValoAppWidgetProvider';

  static final NumberFormat _rateFormat = NumberFormat('#,##0.0000', 'es_VE');

  /// Inicializar el App Group compartido en iOS
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }

  /// Actualizar los datos del Widget y solicitar recarga al sistema
  static Future<void> updateRatesWidget({
    required BcvData bcv,
    BinanceP2PData? p2p,
  }) async {
    try {
      // Guardar Dólar BCV Hoy
      await HomeWidget.saveWidgetData<String>('bcv_usd', _rateFormat.format(bcv.usd));
      // Guardar Euro BCV Hoy
      await HomeWidget.saveWidgetData<String>('bcv_eur', _rateFormat.format(bcv.eur));

      // Guardar Tasa Nueva para Mañana (si existe)
      if (bcv.hayTasaNueva && bcv.tasaNuevaUsd != null) {
        await HomeWidget.saveWidgetData<bool>('hay_tasa_nueva', true);
        await HomeWidget.saveWidgetData<String>('tasa_nueva_usd', _rateFormat.format(bcv.tasaNuevaUsd!));
        await HomeWidget.saveWidgetData<String>('tasa_nueva_fecha', bcv.tasaNuevaFechaTexto ?? 'Mañana');
      } else {
        await HomeWidget.saveWidgetData<bool>('hay_tasa_nueva', false);
      }

      // Guardar USDT P2P (si está disponible)
      if (p2p != null && p2p.rate > 0) {
        await HomeWidget.saveWidgetData<String>('usdt_p2p', _rateFormat.format(p2p.rate));
      }

      // Timestamp de última sincronización
      final now = DateTime.now();
      final timeStr = DateFormat('hh:mm a').format(now);
      await HomeWidget.saveWidgetData<String>('last_sync_time', timeStr);

      // Notificar a iOS y Android que recarguen sus widgets
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (e) {
      // Error silencioso en la sincronización del widget
    }
  }
}

