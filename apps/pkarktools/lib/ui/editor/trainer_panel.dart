import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../editing/draft.dart';
import '../../theme/app_theme.dart';
import '../common/adaptive.dart';
import '../common/format.dart';

/// Edición del entrenador: nombre, IDs, dinero, tiempo jugado y género.
class TrainerPanel extends ConsumerStatefulWidget {
  const TrainerPanel({super.key, required this.snapshotId, required this.editor});
  final int snapshotId;
  final SaveEditor editor;

  @override
  ConsumerState<TrainerPanel> createState() => _TrainerPanelState();
}

class _TrainerPanelState extends ConsumerState<TrainerPanel> {
  late TrainerData _orig;
  late final _name = TextEditingController();
  late final _tid = TextEditingController();
  late final _sid = TextEditingController();
  late final _money = TextEditingController();
  late final _h = TextEditingController();
  late final _m = TextEditingController();
  late final _s = TextEditingController();
  int? _gender;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant TrainerPanel old) {
    super.didUpdateWidget(old);
    if (widget.editor != old.editor || widget.editor.readTrainer() != _orig) _reset();
  }

  void _reset() {
    _orig = widget.editor.readTrainer();
    _name.text = _orig.name;
    _tid.text = '${_orig.tid}';
    _sid.text = '${_orig.sid}';
    _money.text = '${_orig.money}';
    _h.text = '${_orig.playTime.inHours}';
    _m.text = '${_orig.playTime.inMinutes % 60}';
    _s.text = '${_orig.playTime.inSeconds % 60}';
    _gender = _orig.gender;
  }

  @override
  void dispose() {
    for (final c in [_name, _tid, _sid, _money, _h, _m, _s]) {
      c.dispose();
    }
    super.dispose();
  }

  TrainerData get _current {
    int n(TextEditingController c, int max) => (int.tryParse(c.text) ?? 0).clamp(0, max);
    return _orig.copyWith(
      name: _name.text,
      tid: n(_tid, 65535),
      sid: n(_sid, 65535),
      money: n(_money, widget.editor.maxMoney),
      playTime: Duration(hours: n(_h, 65535), minutes: n(_m, 59), seconds: n(_s, 59)),
      gender: _gender,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final fields = widget.editor.trainerFields;
    if (fields.isEmpty) return Text(l10n.trainerNotEditable, style: context.text.bodyLarge!.copyWith(color: tokens.muted));
    final changed = _current != _orig;
    final six = widget.editor.game.usesSixDigitIds;
    final id32 = (int.tryParse(_tid.text) ?? 0) | ((int.tryParse(_sid.text) ?? 0) << 16);
    final digits = [FilteringTextInputFormatter.digitsOnly];

    Widget field(TextEditingController c, String label, {bool number = true, int? maxLength, String? helper}) => TextField(
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number ? digits : null,
          maxLength: maxLength,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label, counterText: '', helperText: helper),
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, c) {
          final two = c.maxWidth >= 520;
          final w = two ? (c.maxWidth - 16) / 2 : c.maxWidth;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            if (fields.contains(TrainerField.name))
              SizedBox(width: w, child: field(_name, l10n.trainerName, number: false, maxLength: widget.editor.maxTrainerNameLength)),
            if (fields.contains(TrainerField.money))
              SizedBox(width: w, child: field(_money, l10n.money, helper: l10n.moneyMax(widget.editor.maxMoney))),
            if (fields.contains(TrainerField.tid))
              SizedBox(
                width: w,
                child: field(_tid, l10n.trainerIdLong,
                    helper: six ? l10n.visibleId((id32 % 1000000).toString().padLeft(6, '0')) : null),
              ),
            if (fields.contains(TrainerField.sid))
              SizedBox(
                width: w,
                child: field(_sid, l10n.secretId, helper: six ? l10n.visibleId((id32 ~/ 1000000).toString().padLeft(4, '0')) : null),
              ),
            if (fields.contains(TrainerField.playTime))
              SizedBox(
                width: w,
                child: Row(children: [
                  Expanded(child: field(_h, l10n.hours)),
                  const SizedBox(width: 10),
                  Expanded(child: field(_m, l10n.minutes)),
                  const SizedBox(width: 10),
                  Expanded(child: field(_s, l10n.seconds)),
                ]),
              ),
            if (fields.contains(TrainerField.gender) && _gender != null)
              SizedBox(
                width: w,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.trainerGender, style: context.text.labelMedium!.copyWith(color: tokens.muted)),
                  const SizedBox(height: 6),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 0, label: Text(l10n.male)),
                      ButtonSegment(value: 1, label: Text(l10n.female)),
                    ],
                    selected: {_gender!.clamp(0, 1)},
                    onSelectionChanged: (v) => setState(() => _gender = v.first),
                  ),
                ]),
              ),
          ]);
        }),
        const SizedBox(height: 22),
        ApplyBar(
          note: l10n.trainerIdNote,
          revertLabel: l10n.revert,
          applyLabel: l10n.applyChanges,
          onRevert: changed ? () => setState(_reset) : null,
          onApply: changed
              ? () {
                  ref.read(draftProvider(widget.snapshotId).notifier).apply(SetTrainerEdit(_current));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.trainerApplied)));
                }
              : null,
        ),
      ]),
    );
  }
}
