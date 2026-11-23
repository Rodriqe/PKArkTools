import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_version.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../data/sprites/sprite_manifest.g.dart';
import '../common/brand_mark.dart';
import '../common/format.dart';
import '../import/import_flow.dart';
import 'folder_section.dart';
import 'sprites_section.dart';
import 'update_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final compact = MediaQuery.sizeOf(context).width < 720;
    final pad = compact ? 16.0 : 32.0;

    Widget section(String title, Widget child, {String? body}) => Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.text.titleLarge),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(body, style: context.text.bodyMedium!.copyWith(color: context.tokens.muted)),
            ],
            const SizedBox(height: 12),
            child,
          ]),
        );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: EdgeInsets.fromLTRB(pad, compact ? 20 : 36, pad, 100),
              children: [
                Text(l10n.navSettings, style: compact ? context.text.displaySmall : context.text.displayMedium),
                const SizedBox(height: 28),
                const UpdateBanner(),
                section(l10n.folderSection, const ArcaFolderSection(), body: l10n.folderSectionDesc),
                section(
                  l10n.theme,
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark), icon: const Icon(Icons.dark_mode_rounded)),
                      ButtonSegment(value: ThemeMode.light, label: Text(l10n.themeLight), icon: const Icon(Icons.light_mode_rounded)),
                      ButtonSegment(value: ThemeMode.system, label: Text(l10n.themeSystem), icon: const Icon(Icons.contrast_rounded)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) => notifier.setThemeMode(s.first),
                  ),
                ),
                section(
                  l10n.language,
                  SegmentedButton<String>(
                    segments: [
                      const ButtonSegment(value: 'es', label: Text('Español')),
                      const ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: '', label: Text(l10n.languageSystem)),
                    ],
                    selected: {settings.locale?.languageCode ?? ''},
                    onSelectionChanged: (s) => notifier.setLocale(s.first.isEmpty ? null : Locale(s.first)),
                  ),
                ),
                section(
                  l10n.archiveExport,
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    FilledButton.tonalIcon(
                      onPressed: () => exportArcaZip(context, ref),
                      icon: const Icon(Icons.archive_outlined),
                      label: Text(l10n.archiveExport),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => restoreArcaZip(context, ref),
                      icon: const Icon(Icons.unarchive_outlined),
                      label: Text(l10n.archiveRestore),
                    ),
                  ]),
                  body: '${l10n.archiveExportDesc} ${l10n.archiveRestoreDesc}',
                ),
                section(l10n.spritesSection, const SpritesSection(), body: l10n.spritesSectionDesc),
                section(
                  l10n.sampleData,
                  OutlinedButton.icon(
                    onPressed: () => loadDemo(context, ref),
                    icon: const Icon(Icons.science_outlined),
                    label: Text(l10n.loadDemo),
                  ),
                  body: l10n.sampleDataDesc,
                ),
                section(
                  l10n.about,
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const BrandMark(size: 64),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('PKArkTools', style: context.text.titleLarge!.copyWith(fontFamily: AppTheme.display)),
                          Text(l10n.updateCurrent(kAppVersion),
                              style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    const UpdateAboutControls(),
                    const SizedBox(height: 12),
                    Text(
                        l10n.spritesCredits(kSpriteCommits['smogon/sprites']!.substring(0, 7),
                            kSpriteCommits['kwsch/PKHeX']!.substring(0, 7)),
                        style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: l10n.appTitle,
                        applicationVersion: kAppVersion,
                        applicationIcon: const Padding(padding: EdgeInsets.all(8), child: BrandMark(size: 72)),
                      ),
                      child: Text(l10n.licenses),
                    ),
                  ]),
                  body: l10n.aboutBody,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
