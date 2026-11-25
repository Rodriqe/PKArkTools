#!/usr/bin/env node
// Valores de referencia de las estadísticas de Champions calculados por el
// simulador de Pokémon Showdown (mod champions, formato VGC vigente).
//   node tool/showdown_ref/stats_ref.js .scratch/sd/ps > packages/pkcore/test/data/champions_stats_ref.json
'use strict';
const path = require('path');
const ps = path.resolve(process.argv[2] || '.scratch/sd/ps');
const { Dex, Battle, PRNG } = require(path.join(ps, 'dist/sim'));
const dex = Dex.mod('champions');
const prng = new PRNG([1, 2, 3, 4]);
const STATS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];
const species = dex.species.all().filter(s => s.exists && s.num > 0 && s.tier !== 'Illegal' && !s.isNonstandard);
const natures = dex.natures.all().map(n => n.name);
const out = [];
function randomSp() {
  const sp = [0, 0, 0, 0, 0, 0];
  let left = prng.random(67);
  while (left > 0) {
    const i = prng.random(6);
    if (sp[i] < 32) { sp[i]++; left--; } else if (sp.every(v => v === 32)) break;
  }
  return sp;
}
for (let i = 0; i < 400; i++) {
  const s = i < species.length ? species[i] : prng.sample(species);
  const nature = prng.sample(natures);
  const sp = i % 7 === 0 ? [32, 32, 2, 0, 0, 0] : randomSp();
  const set = {
    species: s.name, ability: Object.values(s.abilities)[0], moves: ['protect'], nature, level: 50,
    evs: Object.fromEntries(STATS.map((k, j) => [k, sp[j]])), ivs: Object.fromEntries(STATS.map(k => [k, 31])),
  };
  const b = new Battle({ formatid: 'gen9championsvgc2026regmc' });
  b.setPlayer('p1', { team: [set] });
  b.setPlayer('p2', { team: [set] });
  const p = b.p1.pokemon[0];
  out.push({ species: s.id, nature, sp, stats: [p.maxhp, ...STATS.slice(1).map(k => p.storedStats[k])] });
}
process.stdout.write(JSON.stringify({ source: 'Pokémon Showdown sim, mod champions', cases: out }, null, 0) + '\n');
