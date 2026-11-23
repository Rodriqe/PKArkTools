import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/arca_repository.dart';
import '../../l10n/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  bool get isSpanish => Localizations.localeOf(this).languageCode == 'es';
}

String gameTitle(BuildContext context, GameVersion game, [int? versionId]) => context.isSpanish
    ? (GameTitles.nameEs(versionId) ?? game.nameEs)
    : (GameTitles.nameEn(versionId) ?? game.nameEn);

String platformName(BuildContext context, Platform p) => context.isSpanish ? p.nameEs : p.nameEn;

String speciesName(BuildContext context, int species) =>
    Species.name(species, context.isSpanish ? SpeciesLanguage.es : SpeciesLanguage.en);

String formatDate(BuildContext context, DateTime dt, {bool withTime = false}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final d = DateFormat.yMMMd(locale).format(dt);
  return withTime ? '$d, ${DateFormat.Hm(locale).format(dt)}' : d;
}

String formatPlayTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return m == 0 ? '$h h' : '$h h $m min';
}

String formatBytes(int n) {
  if (n >= 1024 * 1024) return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(n / 1024).toStringAsFixed(n % 1024 == 0 ? 0 : 1)} KB';
}

String originLabel(BuildContext context, String code) => switch (ImportOrigin.fromCode(code)) {
      ImportOrigin.file => context.l10n.originFile,
      ImportOrigin.folder => context.l10n.originFolder,
      ImportOrigin.saf => context.l10n.originSaf,
      ImportOrigin.demo => context.l10n.originDemo,
      ImportOrigin.restoreBackup => context.l10n.originRestore,
      ImportOrigin.edit => context.l10n.originEdit,
      ImportOrigin.adopted => context.l10n.originAdopted,
      ImportOrigin.migrated => context.l10n.originMigrated,
    };

String formatMoney(BuildContext context, int money) =>
    NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(money);
