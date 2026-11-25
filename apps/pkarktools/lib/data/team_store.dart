import 'dart:convert';
import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';

import 'folder/arca_folder.dart';
import 'folder/arca_layout.dart';

/// Un equipo leído del Arca con el archivo en el que está.
class StoredTeam {
  StoredTeam(this.team, this.path);
  final ChampionsTeam team;

  /// Ruta relativa a la raíz del Arca (`Competitive/Teams/Lluvia.json`).
  String path;
}

/// Equipos de Competitivo guardados en `Competitive/Teams/` de la carpeta
/// del Arca (se copian con todo lo demás). Un JSON legible por equipo, con
/// nombre según el equipo; nunca se mandan a ningún sitio.
///
/// Las escrituras son atómicas (`writeReplace`: temporal + renombrar, el
/// mismo mecanismo que el resto del Arca en todas las plataformas) y se
/// comprueban releyendo el archivo.
class TeamStore {
  TeamStore(this.folder);
  final ArcaFolder folder;

  static const dir = ArcaLayout.teamsDir;

  /// Equipos de la carpeta. Los archivos que no se pueden leer se devuelven
  /// aparte (no se tocan).
  Future<({List<StoredTeam> teams, List<String> unreadable})> list() async {
    final teams = <StoredTeam>[];
    final bad = <String>[];
    for (final rel in await folder.listFiles(dir)) {
      final name = rel.split('/').last;
      // Temporales, ocultos y marcadores de la nube no; una copia de conflicto
      // («Lluvia (1).json») sí: es un equipo válido que el usuario decide.
      final reason = ArcaLayout.ignoreReason('x/$name');
      if (!name.toLowerCase().endsWith('.json') || (reason != null && reason != IgnoreReason.conflictCopy)) continue;
      try {
        teams.add(StoredTeam(ChampionsTeam.decode(utf8.decode(await folder.read(rel))), rel));
      } catch (_) {
        bad.add(rel);
      }
    }
    teams.sort((a, b) => a.team.name.toLowerCase().compareTo(b.team.name.toLowerCase()));
    return (teams: teams, unreadable: bad);
  }

  /// Nombre de archivo libre para [team] (sin chocar con otro equipo).
  Future<String> _pathFor(ChampionsTeam team, {String? current}) async {
    final taken = {
      for (final f in await folder.listFiles(dir))
        if (f != current) f.toLowerCase(),
    };
    final base = ArcaLayout.safeSegment(team.name.trim().isEmpty ? 'Team' : team.name.trim());
    for (var n = 1; ; n++) {
      final rel = '$dir/${n == 1 ? base : '$base ($n)'}.json';
      if (!taken.contains(rel.toLowerCase())) return rel;
    }
  }

  /// Guarda [stored] (nuevo si `path` está vacío). Si el nombre cambió, el
  /// archivo pasa a llamarse como el equipo y el anterior se borra después
  /// de comprobar el nuevo.
  Future<StoredTeam> save(ChampionsTeam team, {StoredTeam? previous}) async {
    team.updatedAt = DateTime.now().toUtc();
    final old = previous?.path;
    var rel = old;
    final wanted = await _pathFor(team, current: old);
    if (old == null || _stem(old) != _stem(wanted)) rel = wanted;
    final bytes = Uint8List.fromList(utf8.encode(team.encode()));
    await folder.writeReplace(rel!, bytes);
    final back = await folder.read(rel);
    if (!_same(back, bytes)) throw StateError('El equipo no se guardó bien ($rel)');
    if (old != null && old != rel) {
      try {
        await folder.delete(old);
      } catch (_) {}
    }
    return StoredTeam(team, rel);
  }

  /// Equipo nuevo a partir de otro (otro id, «… (copia)»).
  Future<StoredTeam> duplicate(StoredTeam s, String newName) => save(s.team.duplicate(newName));

  Future<void> delete(StoredTeam s) => folder.delete(s.path);

  /// Importa un `.json` de equipo exportado en otro dispositivo: siempre
  /// como un equipo nuevo (nuevo id), sin pisar ninguno.
  Future<StoredTeam> importJson(String text) async {
    final t = ChampionsTeam.decode(text);
    return save(ChampionsTeam(name: t.name, members: t.members));
  }

  static String _stem(String rel) {
    final name = rel.split('/').last;
    return name.toLowerCase();
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
