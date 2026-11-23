import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../data/arca_repository.dart';
import '../data/db/arca_database.dart';
import '../providers.dart';

/// Borrador de edición de un snapshot: el archivo original nunca se toca.
///
/// Las ediciones se apilan; deshacer reconstruye el editor desde los bytes
/// del snapshot aplicando las ediciones anteriores.
class DraftState {
  const DraftState({
    required this.snapshotId,
    this.editor,
    this.edits = const [],
    this.cursor = 0,
    this.revision = 0,
    this.error,
  });

  final int snapshotId;
  final SaveEditor? editor;

  /// Ediciones registradas (las posteriores a [cursor] son "rehacer").
  final List<SaveEditOp> edits;

  /// Número de ediciones aplicadas.
  final int cursor;

  /// Aumenta con cada cambio, para refrescar las vistas.
  final int revision;
  final Object? error;

  bool get loaded => editor != null;
  bool get dirty => cursor > 0;
  bool get canUndo => cursor > 0;
  bool get canRedo => cursor < edits.length;
  List<SaveEditOp> get applied => edits.sublist(0, cursor);

  DraftState copyWith({SaveEditor? editor, List<SaveEditOp>? edits, int? cursor, Object? error}) => DraftState(
        snapshotId: snapshotId,
        editor: editor ?? this.editor,
        edits: edits ?? this.edits,
        cursor: cursor ?? this.cursor,
        revision: revision + 1,
        error: error,
      );
}

class DraftController extends Notifier<DraftState> {
  DraftController(this.snapshotId);

  final int snapshotId;
  Uint8List? _base;
  Snapshot? _snapshot;

  @override
  DraftState build() {
    _load();
    return DraftState(snapshotId: snapshotId);
  }

  ArcaRepository get _repo => ref.read(arcaRepositoryProvider);

  Future<void> _load() async {
    try {
      final snap = await _repo.snapshot(snapshotId);
      final bytes = await _repo.snapshotBytes(snap);
      _snapshot = snap;
      _base = bytes;
      state = state.copyWith(editor: SaveEditor.open(bytes));
    } catch (e) {
      state = state.copyWith(error: e);
    }
  }

  SaveEditor _rebuild(List<SaveEditOp> edits) {
    final e = SaveEditor.open(_base!);
    for (final op in edits) {
      op.applyTo(e);
    }
    return e;
  }

  /// Aplica una edición. Si el formato la rechaza lanza [SaveEditException] y el borrador no cambia.
  void apply(SaveEditOp op) {
    final editor = state.editor;
    // Un save dañado se abre en solo lectura: las ediciones se ignoran (la vista lo explica).
    if (editor == null || editor.readOnly) return;
    try {
      op.applyTo(editor);
    } on Object {
      // El editor pudo quedar a medias: se reconstruye antes de propagar el error.
      state = state.copyWith(editor: _rebuild(state.applied));
      rethrow;
    }
    state = state.copyWith(edits: [...state.applied, op], cursor: state.cursor + 1);
  }

  void undo() {
    if (!state.canUndo) return;
    final cursor = state.cursor - 1;
    state = state.copyWith(editor: _rebuild(state.edits.sublist(0, cursor)), cursor: cursor);
  }

  void redo() {
    if (!state.canRedo) return;
    final op = state.edits[state.cursor];
    op.applyTo(state.editor!);
    state = state.copyWith(cursor: state.cursor + 1);
  }

  void discard() {
    if (_base == null) return;
    state = state.copyWith(editor: _rebuild(const []), edits: const [], cursor: 0);
  }

  /// Archivo listo para el juego/emulador con las ediciones aplicadas.
  ///
  /// Antes de entregarlo se relee y se comprueban checksums y contenido
  /// ([SaveEditor.buildVerified]); sin cambios se devuelve el original intacto.
  Uint8List buildFile() => state.dirty ? state.editor!.buildVerified() : Uint8List.fromList(_base!);

  /// Copia del snapshot con todos los checksums recalculados, para un save con
  /// daño leve ([SaveDamage.minor]): mismos datos, verificaciones correctas.
  /// Se relee y se comprueba antes de devolverla; el snapshot no se toca.
  Uint8List buildRepairedFile() => SaveEditor.open(_base!).buildRepaired();

  /// Guarda el borrador como un snapshot nuevo en el Arca. Devuelve su id.
  Future<int?> saveToArca(String note) async {
    final snap = _snapshot;
    if (snap == null || !state.dirty) return null;
    final bytes = buildFile();
    final out = await _repo.saveEdited(bytes,
        slotId: snap.slotId, fileName: snap.fileName, note: note, sourcePath: snap.sourcePath);
    final id = switch (out) {
      ImportAdded(:final snapshotId) => snapshotId,
      ImportDuplicate() => null,
      ImportFailed(:final reason) => throw StateError(reason),
    };
    discard();
    return id;
  }

  String? get fileName => _snapshot?.fileName;
}

final draftProvider = NotifierProvider.family<DraftController, DraftState, int>(DraftController.new);
