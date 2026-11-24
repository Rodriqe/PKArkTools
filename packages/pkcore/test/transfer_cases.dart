import 'dart:io';
import 'dart:math';

import 'package:pkcore/pkcore.dart';

/// Casos de transferencia (uno o más por salto de generación). Los
/// comparten `test/transfer_test.dart` y `tool/transfer_oracle.dart`.
///
/// El Pokémon de origen es sintético y legal: lo genera PKHeX a partir de
/// sus plantillas de encuentro (`tool/transfer_oracle.sh`) y se versiona en
/// `test/data/transfer/<id>.src.<ext>`.
class TransferCase {
  const TransferCase(this.id, this.from, this.to, this.species, this.pkhexVersion);
  final String id;
  final GameVersion from, to;
  final int species;

  /// Versión de origen en PKHeX (`GameVersion`), para generar el origen.
  final String pkhexVersion;

  PkFormat get sourceFormat => PkFormat.forGame(from);
  String get sourceFile => '$transferDataDir/$id.src.${sourceFormat.extension}';

  /// Pokémon de origen (el archivo generado por PKHeX).
  Pkm source() => Pkm.fromFile(sourceFormat, File(sourceFile).readAsBytesSync())!..dataGame = from;

  TransferResult convert() => PkTransfer.convert(source(), from, to,
      trainer: destTrainer, today: transferDay, random: Random(_seed(id) ^ 0x5EED));
}

int _seed(String s) => s.codeUnits.fold(17, (a, c) => (a * 31 + c) & 0x7FFFFFFF);

const transferDataDir = 'test/data/transfer';

final DateTime transferDay = DateTime(2026, 11, 24);
const sourceTrainer = TrainerData(name: 'ASH', tid: 24680, sid: 13579, gender: 0);
const destTrainer = TransferTrainer(name: 'MISTY', tid: 11111, sid: 22222, gender: 1, language: 2);

const _rb = GameVersion.redBlue, _y = GameVersion.yellow, _gs = GameVersion.goldSilver, _c = GameVersion.crystal;
const _rs = GameVersion.rubySapphire, _e = GameVersion.emerald, _fr = GameVersion.fireRedLeafGreen;
const _dp = GameVersion.diamondPearl, _pt = GameVersion.platinum, _hg = GameVersion.heartGoldSoulSilver;
const _bw = GameVersion.blackWhite, _b2 = GameVersion.black2White2;
const _xy = GameVersion.xy, _or = GameVersion.omegaRubyAlphaSapphire;
const _sm = GameVersion.sunMoon, _us = GameVersion.ultraSunUltraMoon, _gg = GameVersion.letsGo;
const _sw = GameVersion.swordShield, _bd = GameVersion.brilliantDiamondShiningPearl, _la = GameVersion.legendsArceus;
const _sv = GameVersion.scarletViolet, _za = GameVersion.legendsZA;

const transferCases = <TransferCase>[
  // Gen 1 ↔ Gen 2 (Cápsula del Tiempo) y Consola Virtual → Gen 7.
  TransferCase('rb-gs', _rb, _gs, 16, 'RD'),
  TransferCase('gs-rb', _gs, _rb, 19, 'GD'),
  TransferCase('rb-us', _rb, _us, 16, 'RD'),
  TransferCase('y-sm', _y, _sm, 19, 'YW'),
  TransferCase('c-us', _c, _us, 161, 'C'),
  // Pal Park.
  TransferCase('e-dp', _e, _dp, 263, 'E'),
  TransferCase('fr-hg', _fr, _hg, 16, 'FR'),
  TransferCase('rs-pt', _rs, _pt, 263, 'R'),
  // Poké Transfer.
  TransferCase('dp-bw', _dp, _bw, 396, 'D'),
  TransferCase('hg-b2', _hg, _b2, 161, 'HG'),
  // Poké Transporter.
  TransferCase('bw-xy', _bw, _xy, 504, 'B'),
  TransferCase('b2-or', _b2, _or, 504, 'B2'),
  // Pokémon Bank.
  TransferCase('xy-sm', _xy, _sm, 661, 'X'),
  TransferCase('or-us', _or, _us, 263, 'OR'),
  // HOME desde 3DS.
  TransferCase('us-sw', _us, _sw, 25, 'US'),
  TransferCase('us-sv', _us, _sv, 731, 'US'),
  TransferCase('us-bd', _us, _bd, 25, 'US'),
  TransferCase('us-la', _us, _la, 25, 'US'),
  TransferCase('us-za', _us, _za, 25, 'US'),
  // Let's Go → HOME.
  TransferCase('gg-sw', _gg, _sw, 25, 'GP'),
  TransferCase('gg-sv', _gg, _sv, 25, 'GP'),
  // Entre juegos de Switch.
  TransferCase('sw-sv', _sw, _sv, 819, 'SW'),
  TransferCase('sv-sw', _sv, _sw, 819, 'SL'),
  TransferCase('bd-sv', _bd, _sv, 396, 'BD'),
  TransferCase('la-sv', _la, _sv, 25, 'PLA'),
  TransferCase('sv-za', _sv, _za, 25, 'SL'),
  TransferCase('sw-bd', _sw, _bd, 25, 'SW'),
  TransferCase('sv-la', _sv, _la, 25, 'SL'),
  // Cadenas largas.
  TransferCase('e-sv', _e, _sv, 25, 'E'),
  TransferCase('dp-sw', _dp, _sw, 54, 'D'),
  TransferCase('rb-sv', _rb, _sv, 25, 'RD'),
];
