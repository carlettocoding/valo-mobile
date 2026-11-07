import WidgetKit
import SwiftUI

// ==========================================
// 📦 1. MODELO DE ENTRADA DEL WIDGET
// ==========================================
struct ValoRateEntry: TimelineEntry {
    let date: Date
    let bcvUsd: String
    let bcvEur: String
    let hayTasaNueva: Bool
    let tasaNuevaUsd: String?
    let tasaNuevaFecha: String?
    let usdtP2p: String?
    let lastSync: String
}

// ==========================================
// 🔄 2. PROVEEDOR DE LECTURA (APP GROUP)
// ==========================================
struct Provider: TimelineProvider {
    let appGroupId = "group.com.carlitos.valo.dev"

    func placeholder(in context: Context) -> ValoRateEntry {
        ValoRateEntry(
            date: Date(),
            bcvUsd: "Bs. 755,1552",
            bcvEur: "Bs. 820,4010",
            hayTasaNueva: true,
            tasaNuevaUsd: "Bs. 758,2040",
            tasaNuevaFecha: "Mañana",
            usdtP2p: "Bs. 915,50",
            lastSync: "05:00 PM"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ValoRateEntry) -> ()) {
        completion(readFromUserDefaults())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ValoRateEntry>) -> ()) {
        let entry = readFromUserDefaults()
        // Recargar cada 30 minutos automáticamente si el sistema lo permite
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func readFromUserDefaults() -> ValoRateEntry {
        let sharedDefaults = UserDefaults(suiteName: appGroupId)
        let usd = sharedDefaults?.string(forKey: "bcv_usd") ?? "Bs. ---"
        let eur = sharedDefaults?.string(forKey: "bcv_eur") ?? "Bs. ---"
        let hayNueva = sharedDefaults?.bool(forKey: "hay_tasa_nueva") ?? false
        let nuevaUsd = sharedDefaults?.string(forKey: "tasa_nueva_usd")
        let nuevaFecha = sharedDefaults?.string(forKey: "tasa_nueva_fecha")
        let p2p = sharedDefaults?.string(forKey: "usdt_p2p")
        let syncTime = sharedDefaults?.string(forKey: "last_sync_time") ?? "Reciente"

        return ValoRateEntry(
            date: Date(),
            bcvUsd: usd,
            bcvEur: eur,
            hayTasaNueva: hayNueva,
            tasaNuevaUsd: nuevaUsd,
            tasaNuevaFecha: nuevaFecha,
            usdtP2p: p2p,
            lastSync: syncTime
        )
    }
}

// ==========================================
// 🎨 3. INTERFAZ EN SWIFTUI PARA EL WIDGET
// ==========================================
struct ValoWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        case .accessoryRectangular: // Lock Screen rectangular de iOS 16/17/18
            lockScreenRectangularView
        default:
            smallWidgetView
        }
    }

    // A. Widget Pequeño (Pantalla de Inicio)
    var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("VALO")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.blue)
                Spacer()
                Text(entry.lastSync)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Dólar Oficial BCV")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Text(entry.bcvUsd)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            if entry.hayTasaNueva, let nueva = entry.tasaNuevaUsd {
                HStack(spacing: 4) {
                    Text("✨")
                        .font(.system(size: 10))
                    Text(nueva)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(red: 0.06, green: 0.09, blue: 0.16) // Slate 900
        }
    }

    // B. Widget Mediano (Pantalla de Inicio con Dólar, Euro y USDT)
    var mediumWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("VALO • COTIZACIONES")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.blue)
                Spacer()
                Text("Actualizado: \(entry.lastSync)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                // Tarjeta Dólar
                VStack(alignment: .leading, spacing: 3) {
                    Text("Dólar BCV").font(.system(size: 11)).foregroundColor(.secondary)
                    Text(entry.bcvUsd).font(.system(size: 15, weight: .bold)).foregroundColor(.blue)
                    if entry.hayTasaNueva, let nueva = entry.tasaNuevaUsd {
                        Text("✨ \(nueva)").font(.system(size: 10, weight: .semibold)).foregroundColor(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                // Tarjeta Euro
                VStack(alignment: .leading, spacing: 3) {
                    Text("Euro BCV").font(.system(size: 11)).foregroundColor(.secondary)
                    Text(entry.bcvEur).font(.system(size: 15, weight: .bold)).foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                // Tarjeta USDT P2P
                VStack(alignment: .leading, spacing: 3) {
                    Text("Binance P2P").font(.system(size: 11)).foregroundColor(.secondary)
                    Text(entry.usdtP2p ?? "---").font(.system(size: 15, weight: .bold)).foregroundColor(.yellow)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(red: 0.06, green: 0.09, blue: 0.16)
        }
    }

    // C. Widget en Pantalla de Bloqueo (Lock Screen)
    var lockScreenRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "banknote")
                Text("Dólar BCV")
                    .font(.caption2)
                    .textCase(.uppercase)
            }
            Text(entry.bcvUsd)
                .font(.headline)
                .bold()
            if entry.hayTasaNueva, let nueva = entry.tasaNuevaUsd {
                Text("Mañana: \(nueva)")
                    .font(.caption2)
            }
        }
    }
}

// ==========================================
// 🚀 4. DEFINICIÓN DEL WIDGET
// ==========================================
@main
struct ValoWidget: Widget {
    let kind: String = "ValoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ValoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Valo Tasas")
        .description("Consulta las cotizaciones del BCV y Binance P2P en tu pantalla.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

