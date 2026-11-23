import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arca_session.dart';
import '../../data/folder/folder_access.dart';
import '../../theme/app_theme.dart';
import '../common/brand_mark.dart';
import '../common/format.dart';
import 'folder_flows.dart';

/// Primer arranque: explica el Arca en una frase y pide elegir la carpeta.
/// También sirve, con [accessLost], para volver a elegirla si se perdió el
/// permiso.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.accessLost = false});
  final bool accessLost;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _progress = FolderProgress();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _run(Future<OpenedFolder?> Function() obtain) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      final opened = await obtain();
      if (opened == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      error = await runSetUp(ref, opened, _progress);
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _retry() async {
    setState(() => _busy = true);
    await ref.read(arcaSetupProvider.notifier).retry();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = ref.watch(arcaSetupProvider);
    final access = ref.watch(folderAccessProvider);
    final legacy = setup is SetupNeeded ? setup.legacyCount : 0;
    final lost = setup is SetupAccessLost ? setup : null;
    final networkLost = lost != null && lost.location.network;
    final networkName = lost == null ? '' : (lost.location.volume.isEmpty ? lost.location.label : lost.location.volume);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final compact = MediaQuery.sizeOf(context).width < 600;

    final errorText = _error == null
        ? null
        : _error!.startsWith('migration:')
            ? l10n.migrationFailures(int.parse(_error!.substring(10)))
            : l10n.folderPickFailed(_error!);

    final hero = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const _Mark(),
      const SizedBox(height: 28),
      Text(
        (lost != null ? l10n.folderSection : l10n.onbEyebrow).toUpperCase(),
        style: context.text.labelLarge!.copyWith(color: context.colors.primary, letterSpacing: 1.4),
      ),
      const SizedBox(height: 10),
      Text(networkLost ? l10n.networkLostTitle : (lost != null ? l10n.accessLostTitle : l10n.onbTitle),
          style: compact ? context.text.displaySmall : context.text.displayMedium),
      const SizedBox(height: 14),
      Text(networkLost ? l10n.networkLostBody(networkName) : (lost != null ? l10n.accessLostBody : l10n.onbBody),
          style: context.text.bodyLarge!.copyWith(color: context.tokens.muted, height: 1.5)),
      if (lost != null) ...[
        const SizedBox(height: 16),
        _Note(
          icon: networkLost ? Icons.portable_wifi_off_rounded : Icons.folder_off_rounded,
          text: '${lost.location.label}\n${lost.message}',
        ),
      ] else ...[
        const SizedBox(height: 20),
        _Note(
          icon: access.suggestion == FolderSuggestion.documents ? Icons.folder_special_rounded : Icons.cloud_rounded,
          text: switch (access.suggestion) {
            FolderSuggestion.iCloudDrive => l10n.onbSuggestICloud,
            FolderSuggestion.googleDrive => l10n.onbSuggestGoogleDrive,
            FolderSuggestion.oneDrive => l10n.onbSuggestOneDrive,
            FolderSuggestion.syncthing => l10n.onbSuggestSyncthing,
            FolderSuggestion.documents => l10n.onbSuggestDocuments,
          },
        ),
        if (legacy > 0) ...[
          const SizedBox(height: 10),
          _Note(icon: Icons.move_down_rounded, text: l10n.onbLegacy(legacy)),
        ],
      ],
      const SizedBox(height: 28),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _busy
            ? SizedBox(key: const ValueKey('busy'), width: 420, child: FolderProgressView(progress: _progress))
            : _Actions(key: const ValueKey('actions'), stacked: compact, children: [
                if (networkLost)
                  FilledButton.icon(
                    key: const ValueKey('network-retry'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18)),
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.accessRetry),
                  ),
                if (networkLost)
                  OutlinedButton.icon(
                    key: const ValueKey('network-choose-other'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
                    onPressed: () => _run(access.pick),
                    icon: const Icon(Icons.create_new_folder_rounded),
                    label: Text(l10n.accessChooseOther),
                  )
                else
                FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18)),
                  onPressed: () => _run(access.pick),
                  icon: const Icon(Icons.create_new_folder_rounded),
                  label: Text(lost != null ? l10n.accessChooseAgain : l10n.onbChoose),
                ),
                if (lost != null && !networkLost)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.accessRetry),
                  ),
                if (!networkLost)
                  TextButton(
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18)),
                    onPressed: () => _run(access.appLocal),
                    child: Text(l10n.onbUseLocal),
                  ),
              ]),
      ),
      if (errorText != null) ...[
        const SizedBox(height: 16),
        Text(errorText, style: context.text.bodyMedium!.copyWith(color: context.colors.error)),
      ],
      const SizedBox(height: 16),
      Text(l10n.onbLater, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
    ]);

    final preview = _FolderPreview(providers: access.suggestion.providers);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.9, -0.9),
            radius: 1.4,
            colors: [context.tokens.glow, context.tokens.base],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 48, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Expanded(flex: 11, child: hero),
                        const SizedBox(width: 56),
                        Expanded(flex: 9, child: preview),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        hero,
                        if (lost == null) ...[const SizedBox(height: 36), preview],
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) => const BrandMark(size: 88);
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.tokens.raised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.tokens.hairline),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: context.text.bodyMedium!.copyWith(height: 1.45))),
        ]),
      );
}

/// Vista previa de cómo queda la carpeta (datos de ejemplo).
class _FolderPreview extends StatelessWidget {
  const _FolderPreview({required this.providers});
  final List<String> providers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mono = context.text.bodyMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    Widget row(int depth, IconData icon, String name, {Color? color, bool dim = false}) => Padding(
          padding: EdgeInsets.only(left: depth * 20.0, top: 5, bottom: 5),
          child: Row(children: [
            Icon(icon, size: 18, color: color ?? context.tokens.muted),
            const SizedBox(width: 10),
            Flexible(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: mono.copyWith(color: dim ? context.tokens.muted : null)),
            ),
          ]),
        );
    final folder = context.colors.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: context.tokens.raised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.tokens.hairline),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 40, offset: const Offset(0, 18))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in providers)
            Chip(
              label: Text(p),
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.cloud_done_rounded, size: 16, color: folder),
            ),
        ]),
        const SizedBox(height: 18),
        row(0, Icons.folder_rounded, 'PKArkTools', color: folder),
        row(1, Icons.description_outlined, 'README.txt', dim: true),
        row(1, Icons.folder_rounded, 'Pokémon Esmeralda', color: folder),
        row(2, Icons.folder_rounded, 'MAY (12345)', color: folder),
        row(3, Icons.sd_card_rounded, '2026-11-20_183042_3fa9c2d1.sav', color: context.tokens.shiny),
        row(3, Icons.data_object_rounded, '2026-11-20_183042_3fa9c2d1.sav.json', dim: true),
        row(3, Icons.sd_card_rounded, '2026-11-22_091507_b81e004a.sav', color: context.tokens.shiny),
        row(3, Icons.data_object_rounded, '2026-11-22_091507_b81e004a.sav.json', dim: true),
        row(1, Icons.folder_rounded, 'Pokémon Espada - Escudo', color: folder),
        const SizedBox(height: 18),
        Divider(color: context.tokens.hairline, height: 1),
        const SizedBox(height: 16),
        for (final (icon, text) in [
          (Icons.no_accounts_rounded, l10n.onbPointNoAccount),
          (Icons.account_tree_rounded, l10n.onbPointReadable),
          (Icons.lock_clock_rounded, l10n.onbPointSafe),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(icon, size: 18, color: folder),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: context.text.bodyMedium)),
            ]),
          ),
      ]),
    );
  }
}

/// Acciones del onboarding: en fila en escritorio, apiladas a lo ancho en el
/// teléfono (objetivos grandes, sin cortes).
class _Actions extends StatelessWidget {
  const _Actions({super.key, required this.stacked, required this.children});
  final bool stacked;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => stacked
      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
        ])
      : Wrap(spacing: 12, runSpacing: 12, children: children);
}
