// Idioma y destino de las capturas offscreen.
//
//   --dart-define=SHOTS_LANG=en|es   (por defecto en: el repo es en inglés)
//   --dart-define=SHOTS_OUT=<carpeta> (por defecto ../../docs/screenshots)
//
// Los tests de capturas buscan los textos por su versión en español; [tr] los
// traduce al idioma de la captura con los .arb (o con [en] si no son de la app).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;

const shotsLang = String.fromEnvironment('SHOTS_LANG', defaultValue: 'en');
const shotsOut = String.fromEnvironment('SHOTS_OUT', defaultValue: '../../docs/screenshots');

bool get shotsSpanish => shotsLang == 'es';

Locale get shotsLocale => shotsSpanish ? const Locale('es', 'ES') : const Locale('en', 'US');

Map<String, String>? _esToEn;

/// Texto [es] de la interfaz en el idioma de la captura.
String tr(String es, [String? en]) {
  if (shotsSpanish) return es;
  if (en != null) return en;
  _esToEn ??= () {
    Map<String, Object?> load(String l) =>
        jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync()) as Map<String, Object?>;
    final esArb = load('es'), enArb = load('en');
    return {
      for (final e in esArb.entries)
        if (!e.key.startsWith('@') && e.value is String && enArb[e.key] is String) e.value as String: enArb[e.key] as String,
    };
  }();
  final v = _esToEn![es];
  if (v == null) throw StateError('Sin traducción para «$es»: pásala como segundo argumento de tr().');
  return v;
}

/// Archivo de captura `<shotsOut>/<rel>.png`, creando la carpeta.
File shotFile(String rel) => File('$shotsOut/$rel.png')..parent.createSync(recursive: true);
