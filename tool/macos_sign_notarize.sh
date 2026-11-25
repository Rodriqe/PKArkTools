#!/usr/bin/env bash
# Firma con Developer ID, notariza y grapa la app de macOS y la empaqueta en
# un DMG firmado y notarizado y en el zip que usa el actualizador de la app
# (busca el asset que termina en `-macos.zip`, ver
# apps/pkarktools/lib/data/update/app_update.dart).
#
# Uso: tool/macos_sign_notarize.sh <PKArkTools.app> <etiqueta> [carpeta-salida]
#   Salida: PKArkTools-<etiqueta>-macos.zip y, si hay certificado,
#           PKArkTools-<etiqueta>-macos.dmg.
#
# Secretos (variables de entorno, todas opcionales):
#   MACOS_CERT_P12_BASE64  .p12 de "Developer ID Application" en base64
#   MACOS_CERT_PASSWORD    contraseña del .p12
#   APPLE_API_KEY_P8_BASE64, APPLE_API_KEY_ID, APPLE_API_ISSUER_ID
#                          clave de la API de App Store Connect (notarytool)
#   APPLE_TEAM_ID          equipo; si se da, el certificado debe ser de él
#
# Sin MACOS_CERT_P12_BASE64 se hace lo de siempre (zip de la app con la firma
# ad hoc de `flutter build`) y se avisa; sin la clave de la API se firma pero
# no se notariza. Nunca falla por faltar secretos. Nada se imprime de ellos:
# no uses `set -x` aquí.
set -euo pipefail

app=${1:?uso: $0 <PKArkTools.app> <etiqueta> [carpeta-salida]}
label=${2:?falta la etiqueta}
out=${3:-.}
here=$(cd "$(dirname "$0")" && pwd)
entitlements="$here/../apps/pkarktools/macos/Runner/Release.entitlements"
name="PKArkTools-${label}-macos"
zip_out="$out/$name.zip"
dmg_out="$out/$name.dmg"

notice() { if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::notice::$*"; else echo "NOTA: $*"; fi; }
warn() { if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::warning::$*"; else echo "AVISO: $*" >&2; fi; }
die() { if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::error::$*"; else echo "ERROR: $*" >&2; fi; exit 1; }

[ -d "$app" ] || die "no existe $app"
mkdir -p "$out"

zip_app() { rm -f "$zip_out"; ditto -c -k --sequesterRsrc --keepParent "$app" "$zip_out"; }

if [ -z "${MACOS_CERT_P12_BASE64:-}" ]; then
  notice "No MACOS_CERT_P12_BASE64 secret: the macOS app stays ad-hoc signed and is not notarized (Gatekeeper asks for right-click → Open)."
  zip_app
  echo "$zip_out"
  exit 0
fi

notarize=1
for v in APPLE_API_KEY_P8_BASE64 APPLE_API_KEY_ID APPLE_API_ISSUER_ID; do
  if [ -z "${!v:-}" ]; then notarize=0; fi
done

# --- Llavero temporal ---------------------------------------------------------
work=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/macsign.XXXXXX")
keychain="$work/signing.keychain-db"
old_keychains=()
while IFS= read -r k; do
  k=${k#"${k%%[![:space:]]*}"}; k=${k%\"}; k=${k#\"}
  [ -n "$k" ] && old_keychains+=("$k")
done < <(security list-keychains -d user)

cleanup() {
  if [ ${#old_keychains[@]} -gt 0 ]; then
    security list-keychains -d user -s "${old_keychains[@]}" || true
  fi
  security delete-keychain "$keychain" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

umask 077
kc_pass=$(openssl rand -hex 24)
printf '%s' "$MACOS_CERT_P12_BASE64" | base64 -D > "$work/cert.p12"
security create-keychain -p "$kc_pass" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$kc_pass" "$keychain"
security import "$work/cert.p12" -k "$keychain" -P "${MACOS_CERT_PASSWORD:-}" -f pkcs12 \
  -T /usr/bin/codesign -T /usr/bin/security > /dev/null
rm -f "$work/cert.p12"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$kc_pass" "$keychain" > /dev/null
security list-keychains -d user -s "$keychain" ${old_keychains[@]+"${old_keychains[@]}"}

identity_line=$(security find-identity -v -p codesigning "$keychain" | grep 'Developer ID Application' | head -n 1 || true)
[ -n "$identity_line" ] || die "the .p12 does not contain a valid 'Developer ID Application' identity"
identity=$(awk '{print $2}' <<< "$identity_line")
if [ -n "${APPLE_TEAM_ID:-}" ] && ! grep -q "($APPLE_TEAM_ID)" <<< "$identity_line"; then
  die "the Developer ID certificate does not belong to team APPLE_TEAM_ID"
fi
# El repo y sus logs de Actions son públicos: nunca imprimas la identidad
# (nombre del owner y Team ID), el Key ID, el Issuer ID ni salidas de
# codesign/spctl con Authority=/origin=. Solo códigos de salida.
echo "Signing identity: found"

# --- Firma: de dentro hacia fuera ---------------------------------------------
# Primero cada dylib, framework, app o xpc anidado (los más profundos antes,
# gracias a -depth) con hardened runtime y sello de tiempo; luego la app con
# los entitlements de release. No se usa --deep: firmaría todo con los
# entitlements de la app y Apple lo desaconseja para firmar.
sign() { codesign --force --timestamp --options runtime --sign "$identity" --keychain "$keychain" "$@"; }

while IFS= read -r -d '' item; do
  sign "$item"
done < <(find "$app/Contents" -depth \( -name '*.dylib' -o -name '*.framework' -o -name '*.xpc' -o -name '*.app' \) -print0)

# Ejecutables sueltos en Contents/MacOS que no sean el principal (si los hay).
main_exe=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")
while IFS= read -r -d '' exe; do
  [ "$(basename "$exe")" = "$main_exe" ] || sign "$exe"
done < <(find "$app/Contents/MacOS" -type f -perm -u+x -print0)

sign --entitlements "$entitlements" "$app"
codesign --verify --deep --strict "$app" > /dev/null 2>&1 || die "codesign --verify failed for the app"
echo "codesign --verify (app): valid"

# --- Notarización -------------------------------------------------------------
submit() {
  local file=$1 result status id
  result=$(xcrun notarytool submit "$file" --key "$work/key.p8" --key-id "$APPLE_API_KEY_ID" \
    --issuer "$APPLE_API_ISSUER_ID" --wait --timeout 1h --output-format json) || true
  status=$(plutil -extract status raw -o - - <<< "$result" 2>/dev/null || echo unknown)
  id=$(plutil -extract id raw -o - - <<< "$result" 2>/dev/null || echo '')
  echo "Notarization of $(basename "$file"): $status ${id:+(id $id)}"
  if [ "$status" != "Accepted" ]; then
    if [ -n "$id" ]; then
      # Solo la lista de problemas del log (el log completo trae datos de la cuenta).
      xcrun notarytool log "$id" --key "$work/key.p8" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID" 2>/dev/null \
        | plutil -extract issues json -o - - 2>/dev/null || echo "(no issues list in the notarization log)"
    fi
    die "notarization of $(basename "$file") failed ($status)"
  fi
}

if [ "$notarize" = 1 ]; then
  printf '%s' "$APPLE_API_KEY_P8_BASE64" | base64 -D > "$work/key.p8"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$work/notarize.zip"
  submit "$work/notarize.zip"
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
else
  warn "No App Store Connect API key secrets (APPLE_API_KEY_P8_BASE64, APPLE_API_KEY_ID, APPLE_API_ISSUER_ID): the macOS app is signed but NOT notarized."
fi

# Zip para el actualizador, con la app ya grapada.
zip_app

# --- DMG ----------------------------------------------------------------------
stage="$work/dmg"
mkdir -p "$stage"
ditto "$app" "$stage/$(basename "$app")"
ln -s /Applications "$stage/Applications"
rm -f "$dmg_out"
hdiutil create -volname PKArkTools -srcfolder "$stage" -fs HFS+ -format UDZO -ov "$dmg_out" > /dev/null
codesign --force --timestamp --sign "$identity" --keychain "$keychain" "$dmg_out"
codesign --verify "$dmg_out" > /dev/null 2>&1 || die "codesign --verify failed for the DMG"
echo "codesign --verify (DMG): valid"

if [ "$notarize" = 1 ]; then
  submit "$dmg_out"
  xcrun stapler staple "$dmg_out"
  xcrun stapler validate "$dmg_out"
  # Comprobación final: lo que diría Gatekeeper a un usuario.
  # Sin --verbose: spctl imprimiría origin= con el nombre y el Team ID.
  spctl --assess --type execute "$app" > /dev/null 2>&1 || die "Gatekeeper (spctl) rejected the app"
  echo "spctl (app): accepted"
  spctl --assess --type open --context context:primary-signature "$dmg_out" > /dev/null 2>&1 || die "Gatekeeper (spctl) rejected the DMG"
  echo "spctl (DMG): accepted"
fi

echo "$zip_out"
echo "$dmg_out"
