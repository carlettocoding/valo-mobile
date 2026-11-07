# 📱 Valo Mobile — Conversor & Analítica Financiera (Android & iOS)

Aplicación móvil nativa del ecosistema **Valo**, diseñada para ofrecer la máxima agilidad en la conversión de divisas, consulta de cotizaciones oficiales del Banco Central de Venezuela (BCV), mercado paralelo (Binance P2P) y **Widgets nativos interactivos para la pantalla de inicio y bloqueo del iPhone y Android**.

---

## 🏛️ Arquitectura del Proyecto

Este proyecto combina la portabilidad multiplataforma de **Flutter** con la potencia de componentes nativos de **SwiftUI**:

* **95% Core Multiplataforma (Dart / Flutter):**
  * Lógica matemática, conversión bidireccional y evaluador aritmético.
  * Conexión en tiempo real con DolarVzla (BCV) y CriptoYa (Binance P2P).
  * Detección de **Tasa Emitida para Mañana / Próxima Vigencia** del BCV.
  * Formateo bancario estricto a 2 decimales (`XXXX,XX`) con copia rápida para Pago Móvil.
  * Sincronización offline con `SharedPreferences`.
* **5% Componentes Nativos (SwiftUI / WidgetKit):**
  * Widget nativo para la Pantalla de Inicio (Small y Medium) en iOS.
  * Widget para la Pantalla de Bloqueo (*Lock Screen*) en iOS 16/17/18+.
  * Sincronización en segundo plano mediante un contenedor compartido (`App Group`).

---

## 🚀 Compilación en la Nube (Sin Mac) con GitHub Actions

Gracias al pipeline preconfigurado en `.github/workflows/build.yml`, **no necesitas tener una computadora Mac** para generar los instaladores.

### Paso a Paso para Generar tu APK e IPA:

1. **Crea tu nuevo repositorio en GitHub:**
   * Entra a [github.com/new](https://github.com/new).
   * Nómbralo por ejemplo `valo-mobile` o `valo-app`.
   * Mantén el repositorio público (para tener minutos de compilación ilimitados y gratuitos) o privado.

2. **Sube esta carpeta a tu repositorio:**
   ```bash
   cd valo-mobile
   git init
   git branch -M main
   git remote add origin https://github.com/TU_USUARIO/valo-mobile.git
   git add .
   git commit -m "feat: inicializacion de Valo Mobile con soporte de widgets"
   git push -u origin main
   ```

3. **Disparar la compilación manual:**
   * En tu repositorio de GitHub, haz clic en la pestaña **Actions**.
   * En el menú lateral izquierdo, selecciona **"Build Mobile Apps (Android & iOS)"**.
   * Haz clic en el botón desplegable **`Run workflow`** y presiona el botón verde.

4. **Descargar los instaladores:**
   * En unos 4 a 6 minutos, la compilación finalizará con éxito.
   * Haz clic en la ejecución completada y en la sección **Artifacts** encontrarás:
     * `valo-android-release` (archivo `.apk` listo para instalar en cualquier Android).
     * `valo-ios-release` (archivo `.ipa` empaquetado para instalar en tu iPhone).

---

## 📲 ¿Cómo instalar el `.ipa` en tu iPhone desde Windows?

Una vez descargado el archivo `.ipa` de GitHub Actions:

1. **Vía Sideloadly (La forma más rápida):**
   * Descarga [Sideloadly](https://sideloadly.io/) en tu PC Windows.
   * Conecta tu iPhone por cable USB.
   * Arrastra el archivo `Valo-iOS-Release.ipa` dentro de Sideloadly.
   * Introduce tu Apple ID gratuito y presiona **Start**.
   * ¡Listo! La app se instalará en tu iPhone. En tu teléfono ve a *Ajustes > General > Gestión de dispositivos* para confiar en tu certificado y activar el *Modo Desarrollador* en *Privacidad y Seguridad*.
2. **Agregar los Widgets en tu iPhone:**
   * Mantén presionada cualquier parte vacía de tu pantalla de inicio hasta que los iconos bailen.
   * Toca el botón **`+`** en la esquina superior izquierda.
   * Busca **Valo** en la lista y añade el Widget pequeño o mediano.

---

## ⚖️ Fuentes de Datos Oficiales y Resiliencia

* **Dólar y Euro Oficial (BCV):** `https://rates.dolarvzla.com/bcv/current.json` (con fallback a `dolarapi.com`).
* **Binance P2P (USDT):** Proveedor estricto **CriptoYa** (`https://criptoya.com/api/binancep2p/USDT/VES/1`).
* **Regla Estricta:** Prohibido el uso de Yadio. Ante fallo de red, se mantiene la última tasa guardada en el dispositivo.

---

## 👤 Autor

Desarrollado con dedicación por **Carlitos** como parte del ecosistema de calculadoras financieras.
Repositorio principal del ecosistema: [carlettocoding/calculadora-arbitraje](https://github.com/carlettocoding/calculadora-arbitraje).

