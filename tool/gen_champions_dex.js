#!/usr/bin/env node
// Genera packages/pkcore/lib/src/data/generated/champions_dex.dart: los datos
// de combate de Pokémon Champions (especies y Megas con estadísticas base,
// tipos, habilidades y peso; movimientos; objetos; habilidades; qué
// movimientos aprende cada especie) a partir del mod `champions` de Pokémon
// Showdown (MIT).
//
//   node tool/gen_champions_dex.js .scratch/sd/ps
//
// <ps> es un checkout de smogon/pokemon-showdown ya compilado (`node build`),
// siempre dentro de .scratch/. Ver docs/champions-mecanicas.md.
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ps = path.resolve(process.argv[2] || '.scratch/sd/ps');
const out = path.resolve(__dirname, '../packages/pkcore/lib/src/data/generated/champions_dex.dart');
const { Dex } = require(path.join(ps, 'dist/sim'));
const dex = Dex.mod('champions');
const commit = execFileSync('git', ['-C', ps, 'rev-parse', 'HEAD']).toString().trim();

const STATS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];
const legal = s => s.exists && s.num > 0 && s.tier !== 'Illegal' && !s.isNonstandard;

// Especies (con sus Megas y formas) que existen en Champions.
const species = dex.species.all().filter(legal).sort((a, b) => a.num - b.num || a.id.localeCompare(b.id));
const speciesIds = new Set(species.map(s => s.id));

// Movimientos que se pueden aprender en Champions.
function learnset(s) {
  let cur = s;
  for (let i = 0; i < 4 && cur; i++) {
    const data = dex.species.getLearnsetData(cur.id);
    if (data && data.learnset) return Object.keys(data.learnset);
    // Megas y formas sin learnset propio: el de la especie de la que salen.
    const from = cur.changesFrom || (cur.forme ? cur.baseSpecies : null);
    cur = from ? dex.species.get(from) : null;
  }
  return [];
}
const learn = new Map(species.map(s => [s.id, learnset(s)]));
const moveIds = new Set();
for (const l of learn.values()) for (const m of l) moveIds.add(m);
const moves = [...moveIds].map(id => dex.moves.get(id)).filter(m => m.exists && !m.isNonstandard)
  .sort((a, b) => a.num - b.num);
const moveIndex = new Map(moves.map((m, i) => [m.id, i]));

const items = dex.items.all().filter(i => i.exists && !i.isNonstandard).sort((a, b) => a.num - b.num || a.id.localeCompare(b.id));
const abilityIds = new Set();
for (const s of species) for (const a of Object.values(s.abilities)) abilityIds.add(dex.abilities.get(a).id);
const abilities = [...abilityIds].map(id => dex.abilities.get(id)).sort((a, b) => a.num - b.num);

const FLAGS = ['contact', 'punch', 'bite', 'sound', 'pulse', 'slicing', 'bullet', 'wind', 'protect'];
const data = {
  source: { repo: 'smogon/pokemon-showdown', mod: 'champions', commit },
  // [id, nombre, num, [ps..vel], [tipos], [habilidades], peso kg, megaDe, objeto]
  species: species.map(s => [
    s.id, s.name, s.num, STATS.map(k => s.baseStats[k]), s.types,
    Object.values(s.abilities).map(a => dex.abilities.get(a).id), s.weightkg,
    s.isMega ? dex.species.get(s.baseSpecies).id : '', s.requiredItem ? dex.items.get(s.requiredItem).id : '',
  ]),
  // [id, nombre, num, tipo, categoría, potencia, objetivo, prioridad, flags, golpes, crit, extra]
  moves: moves.map(m => {
    const extra = {};
    if (m.willCrit) extra.willCrit = 1;
    if (m.recoil) extra.recoil = m.recoil;
    if (m.drain) extra.drain = m.drain;
    if (m.overrideOffensiveStat) extra.offStat = m.overrideOffensiveStat;
    if (m.overrideOffensivePokemon) extra.offMon = m.overrideOffensivePokemon;
    if (m.overrideDefensiveStat) extra.defStat = m.overrideDefensiveStat;
    if (m.ignoreDefensive) extra.ignoreDef = 1;
    if (m.ignoreEvasion) extra.ignoreEva = 1;
    if (m.damage) extra.fixed = m.damage;
    if (m.ohko) extra.ohko = 1;
    if (m.selfdestruct) extra.selfKO = 1;
    if (m.secondaries && m.secondaries.length) extra.sec = 1;
    if (m.hasCrashDamage) extra.crash = 1;
    if (m.mindBlownRecoil) extra.mindBlown = 1;
    if (m.multiaccuracy) extra.multiAcc = 1;
    if (m.breaksProtect) extra.breaksProtect = 1;
    return [
      m.id, m.name, m.num, m.type, m.category, m.basePower, m.target, m.priority,
      FLAGS.filter(f => m.flags[f]).join(' '),
      m.multihit ? (Array.isArray(m.multihit) ? m.multihit : [m.multihit, m.multihit]) : 0,
      m.critRatio || 1, extra,
    ];
  }),
  // [id, nombre, num]
  items: items.map(i => [i.id, i.name, i.num]),
  abilities: abilities.map(a => [a.id, a.name, a.num]),
  // id de especie -> índices de movimientos
  learnsets: Object.fromEntries(species.map(s => [s.id, learn.get(s.id).filter(m => moveIndex.has(m)).map(m => moveIndex.get(m))])),
};

const json = JSON.stringify(data);
const dart = `// GENERADO por tool/gen_champions_dex.js — no editar a mano.
// Fuente: Pokémon Showdown (MIT), mod data/mods/champions, commit ${commit}.
// ignore_for_file: lines_longer_than_80_chars

const kChampionsDexCommit = '${commit}';

const kChampionsDexJson = r'''
${json}
''';
`;
fs.writeFileSync(out, dart);
console.log(`species=${species.length} moves=${moves.length} items=${items.length} abilities=${abilities.length} bytes=${dart.length}`);
