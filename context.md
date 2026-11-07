# Contexto del Proyecto - Valo Mobile (Android & iOS + Widgets)

Este archivo actúa como la **Fuente de Verdad** y bitácora técnica para el desarrollo de la aplicación nativa móvil **Valo Mobile**. Se desprende del ecosistema maestro definido en `../context.md`.

---

## 🏛️ 1. Visión y Arquitectura

**Valo Mobile** es la versión nativa (Android e iOS) del conversor y monitor analítico financiero **Valo**, diseñada para ofrecer portabilidad total, rendimiento óptimo y soporte para **Widgets nativos en la Pantalla de Inicio y Pantalla de Bloqueo** en smartphones.

```
valo-mobile/
├── context.md                    <-- [ESTE ARCHIVO] Fuente de verdad de Valo Mobile
├── README.md                     <-- Guía del desarrollador y documentación de compilación
├── pubspec.yaml                  <-- Dependencias de Flutter (Core multi-plataforma)
├── .github/workflows/build.yml   <-- CI/CD en la nube: Compilación automática de APK e IPA
│
├── lib/                          <-- 95% Código Compartido en Flutter (Dart)
│   ├── main.dart                 <-- Punto de entrada, inyección de dependencias y temas
│   ├── models/                   <-- Modelos de tasas (BCV USD/EUR, Binance P2P, Histórico)
│   ├── services/                 <-- Clientes HTTP con cache-busting y servicio de Widgets
│   └── screens/                  <-- Pantalla principal del conversor y panel Hero
│
└── ios/ValoWidget/               <-- 5% Código Nativo en SwiftUI (WidgetKit para Apple)
    └── ValoWidget.swift          <-- Widget nativo para Home Screen y Lock Screen de iOS
```

### Principios Fundamentales:
1. **Un solo código base para Android e iOS:** Desarrollado en Flutter (Dart) para garantizar paridad visual y lógica en ambas plataformas.
2. **Widgets 100% Nativos:**
   * **En iOS:** Código nativo en SwiftUI utilizando `WidgetKit` y comunicándose con Flutter mediante un contenedor compartido (`App Group: group.com.carlitos.valo.dev`).
   * **En Android:** Widgets en pantalla de inicio sincronizados a través del paquete `home_widget`.
3. **Cero Dependencia de Mac local:** Compilación de la versión iOS (`.ipa`) automatizada en la nube mediante **GitHub Actions** en runners oficiales de macOS con Xcode.
4. **Desacoplado de la versión Web:** Valo Mobile dispone de su propio repositorio independiente y no colisiona con el despliegue web de `valo/`.

---

## ⚖️ 2. Reglas de Negocio Financieras (Heredadas de Valo Web)

1. **Proveedores Oficiales de Cotizaciones:**
   * **Dólar y Euro Oficial (BCV):** Proveedor primario `https://rates.dolarvzla.com/bcv/current.json` con fallback a `https://ve.dolarapi.com/v1/historicos/dolares/oficial`.
   * **USDT Paralelo (Binance P2P):** Proveedor estricto **CriptoYa** (`https://criptoya.com/api/binancep2p/USDT/VES/1`). Promedio exacto: `(ask + bid) / 2`.
   * **🚫 REGLA ESTRICTA:** Prohibido el uso o fallback a Yadio. Si no hay red, recurrir a la última tasa guardada en el almacenamiento local (`SharedPreferences`).
2. **Detección de Tasa Emitida para Mañana / Próxima Vigencia:**
   * Cuando el BCV publica en la tarde la tasa del siguiente día hábil, la app detecta que `current.date` es posterior a la fecha local de Venezuela.
   * La app activa el banner interactivo: `[ 📅 Tasa Hoy | ✨ Tasa Nueva ]`.
   * En el Widget de iOS se muestra una insignia dorada: `✨ Mañana: Bs. XX,XX`.
3. **Estándares Numéricos:**
   * Tasas oficiales mostradas con hasta **4 decimales exactos** (ej. `Bs. 755,1552`).
   * Copiado rápido para banca móvil estrictamente a **2 decimales con coma sin separador de miles** (`XXXX,XX`).

---

## 📱 3. Configuración del Paquete y Prevención de Colisiones

Para permitir instalar la versión de desarrollo/pruebas junto a la versión oficial sin sobreescrituras:

* **Nombre de la App (Dev):** `Valo (Beta)`
* **Package Name (Android):** `com.carlitos.valo.dev`
* **Bundle Identifier (iOS):** `com.carlitos.valo.dev`
* **App Group (iOS):** `group.com.carlitos.valo.dev`

---

## 📈 4. Estado Actual del Proyecto

* **Versión:** `v0.1.0-alpha`
* **Estado:** Estructura base inicial, pipeline de CI/CD listo, modelos de red preparados y plantilla de Widget nativo para iOS implementada.

