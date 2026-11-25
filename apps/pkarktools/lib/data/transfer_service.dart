import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';

import 'arca_repository.dart';

/// Un Pokémon de la transferencia: origen, conversión y hueco de destino.
class TransferItem {
  TransferItem({required this.from, required this.source, required this.result, this.target, this.issues = const []});

  final SlotRef from;
  final Pkm source;
  final TransferResult result;

  /// Hueco del save de destino (null si no hay sitio o está bloqueado).
  final SlotRef? target;

  /// Avisos de legalidad del Pokémon convertido en el juego de destino.
  final List<LegalityIssue> issues;

  bool get ok => result.ok && target != null;
  TransferDiff? get diff => result.pk == null ? null : TransferDiff.of(source, result.pk!);
}

/// Motivo por el que un Pokémon no se puede mover (además de [TransferBlock]).
enum TransferSkip { noSpace, lockedSlot, lastInParty }

/// Plan de una transferencia de [items] de un save a otro.
class TransferPlan {
  TransferPlan(this.items, {required this.fromGame, required this.toGame, this.skips = const {}});

  final List<TransferItem> items;
  final GameVersion fromGame, toGame;

  /// Pokémon que no se pueden mover por motivos del save (sin sitio, hueco bloqueado…).
  final Map<SlotRef, TransferSkip> skips;

  List<TransferItem> get ready => [for (final i in items) if (i.ok && !skips.containsKey(i.from)) i];
  bool get viaHome => items.any((i) => i.result.viaHome);
  bool get canStopAtAlola => items.any((i) => i.result.canStopAtAlola);

  /// Algún Pokémon ya tiene rastreador de HOME: copiarlo crearía un clon.
  bool get hasTrackers => ready.any((i) => i.source.homeTracker != 0 || i.result.pk!.homeTracker != 0);
}

/// Resultado de aplicar un plan: los dos saves nuevos (el de origen solo al mover).
class TransferOutput {
  const TransferOutput({required this.destination, this.source, required this.count});
  final Uint8List destination;
  final Uint8List? source;
  final int count;
}

/// Transferencia de Pokémon entre dos saves del Arca («HOME local»).
abstract final class TransferService {
  /// Prepara la conversión de [refs] de [src] a [dst].
  ///
  /// Los huecos de destino se toman en orden desde [startBox] (o desde la
  /// primera caja); [startSlot] fija el primero si está libre.
  static TransferPlan plan({
    required SaveEditor src,
    required GameVersion fromGame,
    required List<SlotRef> refs,
    required SaveEditor dst,
    required GameVersion toGame,
    int startBox = 0,
    SlotRef? startSlot,
    bool move = true,
    int language = 2,
    DataLanguage dataLang = DataLanguage.es,
    DateTime? today,
  }) {
    final t = dst.readTrainer();
    final trainer = TransferTrainer(name: t.name, tid: t.tid, sid: t.sid, gender: t.gender ?? 0, language: language);
    final destJapanese = dst.format.isGameBoy && dst.party.isNotEmpty && dst.party.first.japanese;
    final taken = <SlotRef>{};
    final items = <TransferItem>[];
    final skips = <SlotRef, TransferSkip>{};
    var partyLeft = src.partyCount;
    final sorted = [...refs]..sort((a, b) => a.isParty == b.isParty ? 0 : (a.isParty ? 1 : -1));
    for (final ref in sorted) {
      final pk = src.get(ref);
      if (pk == null) continue;
      final r = PkTransfer.convert(pk, fromGame, toGame, trainer: trainer, today: today, destJapanese: destJapanese);
      SlotRef? target;
      if (r.ok) {
        if (move && src.isSlotLocked(ref)) {
          skips[ref] = TransferSkip.lockedSlot;
        } else if (move && ref.isParty && partyLeft <= 1) {
          skips[ref] = TransferSkip.lastInParty;
        } else {
          target = _nextFree(dst, taken, startBox, startSlot);
          if (target == null) {
            skips[ref] = TransferSkip.noSpace;
          } else {
            taken.add(target);
            if (move && ref.isParty) partyLeft--;
          }
        }
      }
      items.add(TransferItem(
        from: ref,
        source: pk,
        result: r,
        target: target,
        issues: r.pk == null ? const [] : Legality.check(r.pk!, toGame, lang: dataLang),
      ));
    }
    items.sort((a, b) => refs.indexOf(a.from).compareTo(refs.indexOf(b.from)));
    return TransferPlan(items, fromGame: fromGame, toGame: toGame, skips: skips);
  }

  static SlotRef? _nextFree(SaveEditor dst, Set<SlotRef> taken, int startBox, SlotRef? startSlot) {
    if (startSlot != null && !taken.contains(startSlot) && dst.get(startSlot) == null && !dst.isSlotLocked(startSlot)) {
      return startSlot;
    }
    for (var i = 0; i < dst.boxCount; i++) {
      final b = (startBox + i) % dst.boxCount;
      for (var s = 0; s < dst.boxSlotCount; s++) {
        final ref = SlotRef.box(b, s);
        if (taken.contains(ref) || dst.isSlotLocked(ref)) continue;
        if (dst.get(ref) == null) return ref;
      }
    }
    return null;
  }

  /// Aplica el plan sobre copias de los saves y devuelve los archivos
  /// verificados. Al mover, el Pokémon se quita del save de origen.
  static TransferOutput apply(TransferPlan plan, Uint8List srcBytes, Uint8List dstBytes, {bool move = true}) {
    final ready = plan.ready;
    if (ready.isEmpty) throw const SaveEditException('No hay Pokémon que transferir.');
    final dst = SaveEditor.open(dstBytes);
    for (final i in ready) {
      dst.set(i.target!, i.result.pk!);
    }
    final dstOut = dst.buildVerified();
    Uint8List? srcOut;
    if (move) {
      final src = SaveEditor.open(srcBytes);
      // Primero las cajas; el equipo de atrás adelante (al quitar se compacta).
      final refs = [for (final i in ready) i.from]..sort((a, b) {
          if (a.isParty != b.isParty) return a.isParty ? 1 : -1;
          return b.slot.compareTo(a.slot);
        });
      for (final r in refs) {
        src.set(r, null);
      }
      srcOut = src.buildVerified();
    }
    return TransferOutput(destination: dstOut, source: srcOut, count: ready.length);
  }

  /// Guarda los saves resultantes como copias nuevas en el Arca (los
  /// originales siguen en el historial).
  static Future<void> commit(
    ArcaRepository repo,
    TransferOutput out, {
    required int fromSlotId,
    required String fromFileName,
    required int toSlotId,
    required String toFileName,
    required String toNote,
    String? fromNote,
  }) async {
    final d = await repo.saveEdited(out.destination, slotId: toSlotId, fileName: toFileName, note: toNote);
    if (d is ImportFailed) throw StateError(d.reason);
    if (out.source != null) {
      final s = await repo.saveEdited(out.source!, slotId: fromSlotId, fileName: fromFileName, note: fromNote ?? toNote);
      if (s is ImportFailed) throw StateError(s.reason);
    }
  }
}
