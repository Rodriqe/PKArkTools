# Instalar

| Sistema | Cómo |
|---|---|
| Android | APK de la página de *Releases* (o desde la propia app: Ajustes → Actualizaciones). |
| Windows | Instalador `…-windows-x64-setup.exe` o zip portátil. Sin firma: SmartScreen puede avisar (**Más información → Ejecutar de todas formas**). |
| macOS | `…-macos.dmg`: arrastra PKArkTools a Aplicaciones. Va firmada y notarizada por Apple, así que se abre con doble clic (si una build saliera sin notarizar, las notas del release lo dicen: la primera vez, clic derecho → **Abrir**). El actualizador de la app usa el `…-macos.zip`. |
| Linux | `tar.gz` con la carpeta `PKArkTools/`. |
| iPhone / iPad | `…-ios-unsigned.ipa` de la página de *Releases*, con **AltStore** y tu propio Apple ID (abajo). |

## iPhone y iPad con AltStore

PKArkTools no está en la App Store. Con [AltStore](https://altstore.io/) se
instala firmándola con **tu propio Apple ID** (gratis); no hace falta cuenta
de desarrollador ni *jailbreak*.

**Qué necesitas**: un Mac o PC con Windows en la misma red Wi‑Fi, el cable
del iPhone/iPad, tu Apple ID y el archivo `PKArkTools-vX.Y.Z-ios-unsigned.ipa`
de la página de
[*Releases*](https://github.com/Rodriqe/PKArkTools/releases/latest).

1. **AltServer en el ordenador**: descárgalo de altstore.io e instálalo
   (en Windows también hacen falta iTunes e iCloud de la web de Apple, no de
   la Microsoft Store).
2. **AltStore en el iPhone**: conecta el iPhone por cable, desbloquéalo y
   confía en el ordenador. En el menú de AltServer: **Install AltStore** → tu
   iPhone, e inicia sesión con tu Apple ID (se usa solo para firmar).
3. **Confía en el perfil**: Ajustes → General → VPN y gestión de
   dispositivos → tu Apple ID → **Confiar**. En iOS 16 o posterior activa
   también **Modo de desarrollador** (Ajustes → Privacidad y seguridad) y
   reinicia.
4. **Instala PKArkTools**: pasa el `.ipa` al iPhone (Archivos, AirDrop…),
   abre AltStore → **My Apps** → **+** y elige el `.ipa`.

**Refresco cada 7 días**: con un Apple ID gratuito la firma caduca a los
**7 días**. AltStore la renueva sola en segundo plano si AltServer está
abierto en el ordenador y ambos están en la misma Wi‑Fi; o hazlo a mano en
AltStore → My Apps → **Refresh All**. Si caduca, la app no abre, pero **tus
datos no se pierden**: el Arca está en la carpeta que elegiste (iCloud Drive,
En mi iPhone…). Una cuenta gratuita permite **3 apps** firmadas a la vez
(AltStore cuenta como una).

El `.ipa` de los *Releases* va **sin firmar** a propósito: AltStore lo vuelve
a firmar con tu Apple ID al instalarlo, así que no hace falta nada más. Lo
genera la integración continua en cada versión; aún no se ha probado en un
dispositivo real, así que si algo falla, avisa en un *issue*.

En la Unión Europea también existe **AltStore PAL** (mercado alternativo),
que no necesita el refresco semanal pero solo instala apps publicadas en una
fuente.

### Para desarrolladores: generar el `.ipa` en tu Mac

Si quieres probar una versión sin publicar, puedes generarlo desde el código
en un Mac con Xcode (es lo mismo que hace la integración continua):

```bash
cd apps/pkarktools
flutter build ios --release --no-codesign
mkdir -p ../../.scratch/ipa/Payload
cp -R build/ios/iphoneos/Runner.app ../../.scratch/ipa/Payload/
(cd ../../.scratch/ipa && zip -qry PKArkTools.ipa Payload)
```
