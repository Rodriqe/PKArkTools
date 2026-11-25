import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arca_session.dart' show arcaRepositoryProvider, folderAccessProvider;
import '../../data/emulators/emulator_service.dart';
import '../../data/emulators/emulators.dart';
import '../../data/folder/folder_access.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import 'tools_common.dart';

/// Ajustes → Emuladores: vincular carpetas de saves (con permiso del
/// usuario), detectar las rutas conocidas y respaldarlas en el Arca.
class EmulatorsSection extends ConsumerStatefulWidget {
  const EmulatorsSection({super.key, this.detect = Emulators.detectDesktop});

  /// Detección de carpetas por defecto (inyectable en tests).
  final Future<List<(Emulator, String)>> Function() detect;

  @override
  ConsumerState<EmulatorsSection> createState() => _EmulatorsSectionState();
}

class _EmulatorsSectionState extends ConsumerState<EmulatorsSection> {
  List<(Emulator, String)>? _detected;
  final Set<EmulatorLink> _busy = {};

  Future<bool> _askPermission(Emulator e, {String? path}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.folder_shared_outlined),
        title: Text(tr(ctx, '¿Dar acceso a la carpeta de ${e.name}?', 'Give access to the ${e.name} folder?')),
        content: Text(
          [
            tr(
              ctx,
              'PKArkTools solo leerá los saves de esa carpeta para copiarlos al Arca cuando pulses «Respaldar». Nunca escribe en ella.',
              'PKArkTools will only read the saves in that folder to copy them to the Ark when you press “Back up”. It never writes to it.',
            ),
            if (path != null) '\n$path',
            '\n${e.notes(es: ctx.isSpanish)}',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(ctx, 'Dar acceso', 'Allow'))),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _link() async {
    final e = await showDialog<Emulator>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr(ctx, 'Emulador', 'Emulator')),
        children: [
          for (final e in Emulators.all)
            SimpleDialogOption(
              key: ValueKey('emu-pick-${e.id}'),
              onPressed: () => Navigator.pop(ctx, e),
              child: Text(e.name),
            ),
        ],
      ),
    );
    if (e == null || !mounted) return;
    final defaults = Emulators.candidates(e, defaultTargetPlatform, env: const {}, home: null);
    if (!await _askPermission(e, path: defaults.isEmpty ? null : defaults.first)) return;
    final picked = await ref.read(folderAccessProvider).pick();
    if (picked == null) return;
    await ref.read(emulatorLinksProvider.notifier).add(EmulatorLink(e.id, picked.location));
  }

  Future<void> _linkDetected(Emulator e, String path) async {
    if (!await _askPermission(e, path: path)) return;
    await ref
        .read(emulatorLinksProvider.notifier)
        .add(EmulatorLink(e.id, ArcaLocation(LocationKind.path, value: path, label: path)));
  }

  Future<void> _backup(EmulatorLink link) async {
    final messenger = ScaffoldMessenger.of(context);
    final es = context.isSpanish;
    setState(() => _busy.add(link));
    try {
      final opened = await ref.read(folderAccessProvider).open(link.location);
      final r = await backupEmulatorFolder(opened.fs, ref.read(arcaRepositoryProvider));
      await ref.read(emulatorLinksProvider.notifier).markBackup(link, DateTime.now());
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            es
                ? 'Respaldo: ${r.added} nuevas, ${r.duplicates} ya estaban, ${r.skipped} archivos ignorados.'
                : 'Backup: ${r.added} new, ${r.duplicates} already there, ${r.skipped} files skipped.',
          ),
        ),
      );
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('${es ? 'No se pudo respaldar' : 'Backup failed'}: $err')));
    } finally {
      if (mounted) setState(() => _busy.remove(link));
    }
  }

  @override
  Widget build(BuildContext context) {
    final links = ref.watch(emulatorLinksProvider);
    final muted = context.text.bodySmall!.copyWith(color: context.tokens.muted);
    final desktop = defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux;
    final detected = _detected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              key: const ValueKey('emu-link'),
              onPressed: _link,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text(tr(context, 'Vincular carpeta de un emulador', 'Link an emulator folder')),
            ),
            if (desktop)
              OutlinedButton.icon(
                key: const ValueKey('emu-detect'),
                onPressed: () async {
                  final d = await widget.detect();
                  if (mounted) setState(() => _detected = d);
                },
                icon: const Icon(Icons.travel_explore_rounded),
                label: Text(tr(context, 'Buscar carpetas conocidas', 'Find known folders')),
              ),
          ],
        ),
        if (detected != null) ...[
          const SizedBox(height: 12),
          if (detected.isEmpty)
            Text(
              tr(
                context,
                'No se encontró ninguna carpeta de emulador en las rutas habituales.',
                'No emulator folder found in the usual locations.',
              ),
              style: muted,
            ),
          for (final (e, path) in detected)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sports_esports_outlined),
              title: Text(e.name),
              subtitle: Text(path),
              trailing: TextButton(
                onPressed: () => _linkDetected(e, path),
                child: Text(tr(context, 'Vincular', 'Link')),
              ),
            ),
        ],
        const SizedBox(height: 8),
        for (final l in links)
          ListTile(
            key: ValueKey('emu-link-${l.emulatorId}-${l.location.value}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_rounded),
            title: Text(l.emulator?.name ?? l.emulatorId),
            subtitle: Text(
              [
                l.location.label,
                if (l.lastBackup != null)
                  tr(
                    context,
                    'Último respaldo: ${formatDate(context, l.lastBackup!, withTime: true)}',
                    'Last backup: ${formatDate(context, l.lastBackup!, withTime: true)}',
                  ),
              ].join('\n'),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                _busy.contains(l)
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        tooltip: tr(context, 'Respaldar en el Arca', 'Back up to the Ark'),
                        onPressed: () => _backup(l),
                        icon: const Icon(Icons.backup_outlined),
                      ),
                IconButton(
                  tooltip: tr(context, 'Quitar', 'Remove'),
                  onPressed: () => ref.read(emulatorLinksProvider.notifier).remove(l),
                  icon: const Icon(Icons.link_off_rounded),
                ),
              ],
            ),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            tr(context, 'Compatibilidad por emulador', 'Compatibility by emulator'),
            style: context.text.titleSmall,
          ),
          children: [
            for (final e in Emulators.all)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.name),
                subtitle: Text(
                  [
                    e.consoles.map((c) => platformName(context, c)).join(', '),
                    e.notes(es: context.isSpanish),
                    if (e.canLaunchOn(defaultTargetPlatform))
                      tr(
                        context,
                        '«Abrir el juego» disponible en este sistema.',
                        '“Open the game” available on this system.',
                      ),
                  ].join('\n'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
