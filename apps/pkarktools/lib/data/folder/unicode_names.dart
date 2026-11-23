import 'nfc_table.dart';

Map<int, int>? _nfdPairs;

/// Descompone una cadena en NFD (inversa de [toNfc] con la misma tabla).
///
/// smbfs en macOS: una vez listada una carpeta, sus entradas pueden no
/// encontrarse por la ruta en NFC pero sí por la de NFD.
String toNfd(String s) {
  var plain = true;
  for (final c in s.codeUnits) {
    if (c >= 0xC0) {
      plain = false;
      break;
    }
  }
  if (plain) return s;
  final rev = _nfdPairs ??= {for (final e in nfcPairs.entries) e.value: e.key};
  final out = <int>[];
  void add(int r) {
    if (r >= 0xAC00 && r <= 0xD7A3) {
      final i = r - 0xAC00;
      out
        ..add(0x1100 + i ~/ (21 * 28))
        ..add(0x1161 + (i % (21 * 28)) ~/ 28);
      if (i % 28 != 0) out.add(0x11A7 + i % 28);
      return;
    }
    final pair = rev[r];
    if (pair == null) {
      out.add(r);
      return;
    }
    add(pair >> 21);
    out.add(pair & 0x1FFFFF);
  }

  for (final r in s.runes) {
    add(r);
  }
  return String.fromCharCodes(out);
}

/// Compone una cadena en NFC (forma canónica compuesta).
///
/// macOS devuelve los nombres de los volúmenes de red (smbfs, AFP) en NFD:
/// «Pokémon» llega como «Poke» + acento combinante + «mon». El Arca compara
/// rutas como texto, así que todas las rutas listadas se componen. Cubre la
/// composición canónica de Unicode (latín, griego, cirílico, kana con
/// dakuten…) y el hangul; las marcas se componen en el orden en que llegan
/// (el de NFD).
String toNfc(String s) {
  var plain = true;
  for (final c in s.codeUnits) {
    if (c >= 0x300) {
      plain = false;
      break;
    }
  }
  if (plain) return s;
  final out = <int>[];
  for (final r in s.runes) {
    if (out.isNotEmpty) {
      final last = out.last;
      // Hangul: L + V → LV; LV + T → LVT.
      if (last >= 0x1100 && last < 0x1113 && r >= 0x1161 && r < 0x1176) {
        out[out.length - 1] = 0xAC00 + ((last - 0x1100) * 21 + (r - 0x1161)) * 28;
        continue;
      }
      if (last >= 0xAC00 && last <= 0xD7A3 && (last - 0xAC00) % 28 == 0 && r > 0x11A7 && r < 0x11C3) {
        out[out.length - 1] = last + (r - 0x11A7);
        continue;
      }
      final c = nfcPairs[(last << 21) | r];
      if (c != null) {
        out[out.length - 1] = c;
        continue;
      }
    }
    out.add(r);
  }
  return String.fromCharCodes(out);
}
