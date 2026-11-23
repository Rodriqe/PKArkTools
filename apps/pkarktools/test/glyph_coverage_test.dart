// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/src/data/generated/encounter_data.dart';
import 'package:pkcore/src/data/generated/event_labels.dart';
import 'package:pkcore/src/data/generated/form_names.dart';
import 'package:pkcore/src/data/generated/game_text.dart';
import 'package:pkcore/src/data/generated/ribbon_data.dart';
import 'package:pkcore/src/data/generated/species_data.dart';

/// Code points del `cmap` de una fuente TrueType/OpenType (formatos 4 y 12).
Set<int> _cmap(String path) {
  final d = ByteData.sublistView(File(path).readAsBytesSync());
  final tables = d.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < tables; i++) {
    final rec = 12 + i * 16;
    if (String.fromCharCodes([for (var k = 0; k < 4; k++) d.getUint8(rec + k)]) == 'cmap') cmap = d.getUint32(rec + 8);
  }
  expect(cmap, isNot(-1), reason: '$path sin tabla cmap');
  final out = <int>{};
  final n = d.getUint16(cmap + 2);
  for (var i = 0; i < n; i++) {
    final platform = d.getUint16(cmap + 4 + i * 8);
    if (platform != 0 && platform != 3) continue; // solo Unicode / Windows
    final sub = cmap + d.getUint32(cmap + 4 + i * 8 + 4);
    switch (d.getUint16(sub)) {
      case 4:
        final segs = d.getUint16(sub + 6) ~/ 2;
        final ends = sub + 14, starts = ends + segs * 2 + 2, deltas = starts + segs * 2, ranges = deltas + segs * 2;
        for (var s = 0; s < segs; s++) {
          final end = d.getUint16(ends + s * 2), start = d.getUint16(starts + s * 2);
          final delta = d.getUint16(deltas + s * 2), rangeOff = d.getUint16(ranges + s * 2);
          for (var c = start; c <= end && c != 0xFFFF; c++) {
            final glyph = rangeOff == 0
                ? (c + delta) & 0xFFFF
                : d.getUint16(ranges + s * 2 + rangeOff + (c - start) * 2);
            if (glyph != 0) out.add(c);
          }
        }
      case 12:
        final groups = d.getUint32(sub + 12);
        for (var g = 0; g < groups; g++) {
          final start = d.getUint32(sub + 16 + g * 12), end = d.getUint32(sub + 20 + g * 12);
          for (var c = start; c <= end; c++) {
            out.add(c);
          }
        }
    }
  }
  return out;
}

/// Todas las cadenas de nombres que la app muestra en español e inglés.
Map<String, Iterable<String>> _names() {
  final locations = <String>[
    for (final MapEntry(:key, :value) in kLocationNames.entries)
      if (key.endsWith('_es') || key.endsWith('_en'))
        for (final line in value.split('\n'))
          if (line.split('\t') case [final id, final name] when id != '0') name,
  ];
  String arb(String lang) => File('lib/l10n/app_$lang.arb').readAsStringSync();
  Iterable<String> arbValues(String lang) => [
        for (final MapEntry(:key, :value) in (jsonDecode(arb(lang)) as Map<String, Object?>).entries)
          if (!key.startsWith('@') && value is String) value,
      ];
  return {
    'especies': [...kSpeciesNamesEs, ...kSpeciesNamesEn],
    'formas': [...kFormNamePool, ...kFormsEs, ...kFormsEn, for (final f in SpecialForms.all) f.variant],
    'movimientos': [...kMovesEs, ...kMovesEn],
    'habilidades': [...kAbilitiesEs, ...kAbilitiesEn],
    'naturalezas y tipos': [...kNaturesEs, ...kNaturesEn, ...kTypesEs, ...kTypesEn],
    'objetos': [
      ...kItemsEs, ...kItemsG3Es, ...kItemsG2Es, ...kItemsG1Es, //
      ...kItemsEn, ...kItemsG3En, ...kItemsG2En, ...kItemsG1En,
    ],
    'lugares': locations,
    'cintas': [for (final (es, en) in kRibbonNames.values) ...[es, en]],
    'eventos': [
      for (final MapEntry(:key, :value) in kEventLabels.entries)
        if (key.endsWith('_es') || key.endsWith('_en')) value,
    ],
    'interfaz (arb)': [...arbValues('es'), ...arbValues('en')],
    // Literales de la interfaz fuera de los arb (atajos, avisos, flechas).
    'interfaz (símbolos)': const ['⌘Z', '⇧⌘Z', '⚠', '✦', '→', '←', '—', '–', '…', '·', '•', '×', '°', 'Nº', 'é', "'"],
  };
}

void main() {
  test('el tema usa los respaldos de símbolos empaquetados', () {
    final theme = AppTheme.dark();
    expect(theme.textTheme.bodyMedium!.fontFamilyFallback, AppTheme.symbolFallback);
    expect(theme.textTheme.headlineSmall!.fontFamilyFallback, AppTheme.symbolFallback);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final family in AppTheme.symbolFallback) {
      expect(pubspec, contains('family: $family'));
    }
  });

  test('cada carácter de los nombres es/en tiene glifo en Manrope o en el respaldo', () {
    final manrope = _cmap('assets/fonts/Manrope.ttf');
    final fallback = {
      ..._cmap('assets/fonts/NotoSansSymbols-Subset.ttf'),
      ..._cmap('assets/fonts/NotoSansSymbols2-Subset.ttf'),
    };
    expect(manrope, containsAll('Pokémon'.runes.toSet()));
    expect(fallback, containsAll('♂♀★⚠⌘⇧✦'.runes.toSet()));
    final missing = <String, Set<String>>{};
    var checked = 0;
    for (final MapEntry(key: group, value: strings) in _names().entries) {
      for (final s in strings) {
        for (final r in s.runes) {
          if (r < 0x20 || r == 0x7F) continue; // \n, \t de las tablas
          checked++;
          if (!manrope.contains(r) && !fallback.contains(r)) {
            missing.putIfAbsent(group, () => {}).add('${String.fromCharCode(r)} U+${r.toRadixString(16).toUpperCase()}');
          }
        }
      }
    }
    expect(checked, greaterThan(100000));
    expect(missing, isEmpty, reason: 'caracteres sin glifo: $missing');
  });

  test('Bricolage (nombres en la cuadrícula de la Dex) cae en el respaldo para ♂/♀', () {
    final bricolage = _cmap('assets/fonts/BricolageGrotesque.ttf');
    final fallback = _cmap('assets/fonts/NotoSansSymbols-Subset.ttf');
    for (final r in '♂♀'.runes) {
      expect(bricolage.contains(r) || fallback.contains(r), isTrue);
    }
  });

  test('el lugar 0 de Gen 5+ («－－－», «——») se describe como desconocido', () {
    for (final version in [20, 24, 50]) {
      expect(EncounterTables.locationName(version, 0, DataLanguage.en), 'an unknown place');
      expect(EncounterTables.locationName(version, 0, DataLanguage.es), 'un lugar desconocido');
    }
  });
}
