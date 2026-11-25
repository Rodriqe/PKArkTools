#!/usr/bin/env node
// Casos de referencia de la calculadora de daño de Champions: el simulador de
// Pokémon Showdown (mod champions) monta un combate real con cada caso y
// calcula las 16 tiradas del primer golpe (y del segundo con Parental Bond).
//
//   node tool/showdown_ref/damage_ref.js .scratch/sd/ps [n] > packages/pkcore/test/data/champions_damage_ref.json
//
// Casos: unos fijos que buscan los bordes (inmunidades, críticos, ataques a
// varios objetivos, bayas, Multiscale, Parental Bond, Mega Sol…) y el resto
// al azar (semilla fija) entre las especies permitidas en la regulación
// vigente, con sus habilidades, objetos y movimientos de Champions.
'use strict';
const fs = require('fs');
const path = require('path');
const ps = path.resolve(process.argv[2] || '.scratch/sd/ps');
const N = Number(process.argv[3] || 260);
const { Dex, Battle, PRNG } = require(path.join(ps, 'dist/sim'));
const dex = Dex.mod('champions');
const prng = new PRNG([7, 7, 7, 7]);
const STATS = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];
const tr = (n, b) => b ? (n >>> 0) % (2 ** b) : n >>> 0;

const champ = JSON.parse(fs.readFileSync(path.join(__dirname, '../../data/champions/champions.json'), 'utf8'));
const allowed = champ.allowed.map(id => dex.species.get(id)).filter(s => s.exists);
const megas = champ.megas.map(id => dex.species.get(id)).filter(s => s.exists);

// Lo que modela la calculadora (packages/pkcore/lib/src/tools/champions_damage.dart).
const unsupportedAbilities = new Set(('analytic supremeoverlord stakeout unaware friendguard cloudnine airlock heavymetal ' +
  'lightmetal protosynthesis quarkdrive flowergift powerspot battery steelyspirit aurabreak fairyaura darkaura ' +
  'neutralizinggas gorillatactics libero protean stancechange disguise iceface merciless rivalry toxicboost flareboost ' +
  'defeatist slowstart plus minus unseenfist piercingdrill sturdy contrary simple trace imposter').split(' '));
const unsupportedMoves = new Set(('assurance avalanche beatup comeuppance counter endeavor expandingforce ficklebeam ' +
  'finalgambit fissure guillotine hardpress horndrill infernalparade lashout lastrespects metalburst mirrorcoat ' +
  'mistyexplosion payback ragefist ragingbull risingvoltage round sheercold spitup stompingtantrum superfang ' +
  'temperflare terrainpulse tripleaxel watershuriken aurawheel gravapple barbbarrage fling beakblast focuspunch ' +
  'shellsidearm pollenpuff struggle futuresight doomdesire').split(' '));
const items = ('silverpowder blackglasses dragonfang magnet fairyfeather blackbelt charcoal sharpbeak spelltag miracleseed ' +
  'softsand nevermeltice silkscarf poisonbarb twistedspoon hardstone metalcoat mysticwater tangaberry colburberry ' +
  'habanberry wacanberry roseliberry chopleberry occaberry cobaberry kasibberry rindoberry shucaberry yacheberry ' +
  'kebiaberry payapaberry chartiberry babiriberry passhoberry chilanberry lifeorb expertbelt muscleband wiseglasses ' +
  'choicescarf airballoon leftovers').split(' ');

function learnset(s) {
  const base = s.isMega ? dex.species.get(s.baseSpecies) : s;
  const l = dex.species.getLearnsetData(base.id);
  return l && l.learnset ? Object.keys(l.learnset) : [];
}
function damagingMoves(s) {
  return learnset(s).map(id => dex.moves.get(id)).filter(m => m.exists && !m.isNonstandard &&
    m.category !== 'Status' && !unsupportedMoves.has(m.id) && !m.ohko).map(m => m.id);
}
const pick = a => a[prng.random(a.length)];
function randomSp() {
  const sp = [0, 0, 0, 0, 0, 0];
  let left = prng.random(67);
  while (left > 0) { const i = prng.random(6); if (sp[i] < 32) { sp[i]++; left--; } }
  return sp;
}

// Un lado del combate en el formato de ChampionsSide.toJson (Dart).
function side(s, opts = {}) {
  const isMega = !!s.isMega;
  const base = isMega ? dex.species.get(s.baseSpecies) : s;
  let abilities = Object.values(base.abilities).map(a => dex.abilities.get(a).id);
  abilities = abilities.filter(a => !unsupportedAbilities.has(a));
  return {
    species: base.id,
    ...(isMega ? { mega: s.id } : {}),
    nature: opts.nature || pick(dex.natures.all()).name,
    sp: opts.sp || randomSp(),
    ability: opts.ability ?? (abilities.length ? pick(abilities) : ''),
    item: isMega ? dex.items.get(s.requiredItem).id : (opts.item ?? (prng.random(3) ? pick(items) : '')),
    moves: [],
    boosts: opts.boosts || {},
    status: opts.status || '',
    hpPercent: opts.hpPercent || 100,
  };
}

function showdownSet(sd) {
  const sp = dex.species.get(sd.mega || sd.species);
  const ability = sd.mega ? Object.values(sp.abilities)[0] : sd.ability;
  return {
    species: sp.name, ability, item: sd.item, nature: sd.nature, level: 50, moves: ['protect'],
    evs: Object.fromEntries(STATS.map((k, i) => [k, sd.sp[i]])), ivs: Object.fromEntries(STATS.map(k => [k, 31])),
  };
}

const weathers = { none: '', sun: 'sunnyday', rain: 'raindance', sand: 'sandstorm', snow: 'snowscape' };
const terrains = { none: '', electric: 'electricterrain', grassy: 'grassyterrain', psychic: 'psychicterrain', misty: 'mistyterrain' };

/** Monta el combate del caso y devuelve [battle, atacante, defensor]. */
function setup(c) {
  const b = new Battle({ formatid: c.field.doubles ? 'gen9championsvgc2026regmc' : 'gen9championsbssregmc', seed: [1, 2, 3, 4] });
  // En dobles, un compañero neutro (Snorlax con Inmunidad: sin efectos sobre el daño).
  const filler = { species: 'Snorlax', ability: 'Immunity', item: '', nature: 'Hardy', level: 50, moves: ['protect'] };
  const team = sd => c.field.doubles ? [showdownSet(sd), filler] : [showdownSet(sd)];
  b.setPlayer('p1', { team: team(c.attacker) });
  b.setPlayer('p2', { team: team(c.defender) });
  b.makeChoices(c.field.doubles ? 'team 12' : 'team 1', c.field.doubles ? 'team 12' : 'team 1');
  const a = b.p1.active[0], d = b.p2.active[0];
  b.field.clearWeather();
  b.field.clearTerrain();
  if (weathers[c.field.weather]) b.field.setWeather(weathers[c.field.weather], a);
  if (terrains[c.field.terrain]) b.field.setTerrain(terrains[c.field.terrain], a);
  for (const sc of Object.keys(b.p2.sideConditions)) b.p2.removeSideCondition(sc);
  if (c.field.reflect) b.p2.addSideCondition('reflect', d);
  if (c.field.lightScreen) b.p2.addSideCondition('lightscreen', d);
  if (c.field.auroraVeil) b.p2.addSideCondition('auroraveil', d);
  for (const [p, sd] of [[a, c.attacker], [d, c.defender]]) {
    p.clearBoosts();
    for (const [k, v] of Object.entries(sd.boosts)) p.boosts[k] = v;
    // Estado puesto a mano (p. ej. quemado de antes de que hubiera Campo de Niebla).
    p.clearStatus();
    if (sd.status) { p.status = sd.status; p.statusState = b.initEffectState({ id: sd.status, target: p }); }
    p.hp = sd.hpPercent >= 100 ? p.maxhp : Math.max(1, Math.min(p.maxhp, Math.floor(p.maxhp * sd.hpPercent / 100)));
    for (const v of Object.keys(p.volatiles)) p.removeVolatile(v);
  }
  if (c.field.helpingHand) a.addVolatile('helpinghand', a);
  for (const p of b.getAllActive()) p.updateSpeed();
  return [b, a, d];
}

function activeMove(b, a, d, c, hit) {
  let move = b.dex.getActiveMove(c.move);
  b.activeMove = move; b.activePokemon = a; b.activeTarget = d;
  b.singleEvent('ModifyType', move, null, a, d, move, move);
  b.singleEvent('ModifyMove', move, null, a, d, move, move);
  move = b.runEvent('ModifyType', a, d, move, move);
  move = b.runEvent('ModifyMove', a, d, move, move);
  b.activeMove = move;
  if (c.field.crit) move.willCrit = true;
  else if (!move.willCrit) move.willCrit = false;
  move.spreadHit = c.field.doubles && c.field.spread && ['allAdjacentFoes', 'allAdjacent'].includes(move.target);
  if (hit) { move.multihitType = 'parentalbond'; move.hit = hit; }
  return move;
}

function battleAbility(sd) {
  return sd.mega ? dex.abilities.get(Object.values(dex.species.get(sd.mega).abilities)[0]).id : sd.ability;
}

function evaluate(c) {
  if ([c.attacker, c.defender].some(sd => unsupportedAbilities.has(battleAbility(sd)))) return { tie: true };
  // Inmunidades (TryHit: habilidades, campo psíquico; y tipos en getDamage).
  {
    const [b, a, d] = setup(c);
    if (a.speed === d.speed) return { tie: true };
    const move = activeMove(b, a, d, c);
    const ok = b.runEvent('TryHit', d, a, move);
    if (!ok) return { immune: true };
    if (!d.runImmunity(move)) return { immune: true };
  }
  const parental = c.attacker.ability === 'parentalbond' || (c.attacker.mega && dex.species.get(c.attacker.mega).abilities[0] === 'Parental Bond');
  const out = { immune: false, rolls: [] };
  const hits = parental && !dex.moves.get(c.move).multihit ? [1, 2] : [0];
  for (const hit of hits) {
    const rolls = [];
    for (let r = 15; r >= 0; r--) {
      const [b, a, d] = setup(c);
      const move = activeMove(b, a, d, c, hit || undefined);
      if (move.spreadHit && hit) { move.multihitType = undefined; }
      if (hit === 2) {
        // Segundo golpe: sin la baya ni Multiscale (el primero ya golpeó).
        if (d.item && d.getItem().isBerry) d.setItem('');
        if (d.hp === d.maxhp) d.hp = d.maxhp - 1;
      }
      b.randomizer = bd => tr(tr(bd * (100 - r)) / 100);
      const dmg = b.actions.getDamage(a, d, move, true);
      if (dmg === false || dmg === null || dmg === undefined) return { immune: true };
      rolls.push(dmg);
    }
    if (hit === 2 && !c.field.spread) out.hit2 = rolls; else if (hit !== 2) out.rolls = rolls;
  }
  return out;
}

function randomCase() {
  const doubles = prng.random(10) < 7;
  const aS = prng.random(5) === 0 && megas.length ? pick(megas) : pick(allowed);
  const dS = prng.random(6) === 0 && megas.length ? pick(megas) : pick(allowed);
  const moves = damagingMoves(aS);
  if (!moves.length) return null;
  const st = prng.random(10);
  return {
    attacker: side(aS, {
      boosts: prng.random(4) === 0 ? { [pick(['atk', 'spa'])]: prng.random(5) - 2 } : {},
      status: st === 0 ? 'brn' : st === 1 ? 'par' : '',
      hpPercent: prng.random(6) === 0 ? pick([20, 33, 50]) : 100,
    }),
    defender: side(dS, {
      boosts: prng.random(4) === 0 ? { [pick(['def', 'spd'])]: prng.random(5) - 2 } : {},
      status: prng.random(10) === 0 ? pick(['psn', 'brn']) : '',
      hpPercent: prng.random(8) === 0 ? 60 : 100,
    }),
    move: pick(moves),
    field: {
      doubles,
      weather: prng.random(3) === 0 ? pick(['sun', 'rain', 'sand', 'snow']) : 'none',
      terrain: prng.random(4) === 0 ? pick(['electric', 'grassy', 'psychic', 'misty']) : 'none',
      reflect: prng.random(6) === 0,
      lightScreen: prng.random(6) === 0,
      auroraVeil: prng.random(10) === 0,
      helpingHand: doubles && prng.random(6) === 0,
      crit: prng.random(7) === 0,
      spread: prng.random(5) !== 0,
    },
  };
}

// Casos fijos de bordes.
const S = id => dex.species.get(id);
const F = (o = {}) => ({ doubles: true, weather: 'none', terrain: 'none', reflect: false, lightScreen: false,
  auroraVeil: false, helpingHand: false, crit: false, spread: true, ...o });
const fixed = [];
function edge(a, aOpts, dS, dOpts, move, field) {
  const legal = s => s.exists && s.tier !== 'Illegal' && !s.isNonstandard;
  if (!legal(a) || !legal(dS)) { process.stderr.write(`caso fijo omitido: ${a.id} → ${dS.id}\n`); return; }
  fixed.push({ attacker: side(a, aOpts), defender: side(dS, dOpts), move, field: F(field) });
}
edge(S('garchomp'), { ability: 'roughskin', item: 'lifeorb', nature: 'Jolly', sp: [2, 32, 0, 0, 0, 32] }, S('incineroar'), { ability: 'intimidate', item: '', nature: 'Careful', sp: [32, 0, 0, 0, 32, 2] }, 'earthquake', {});
edge(S('garchomp'), { ability: 'roughskin', item: '', nature: 'Adamant' }, S('corviknight'), { ability: 'pressure', item: '' }, 'earthquake', {});
edge(S('garchomp'), { ability: 'roughskin', item: '' }, S('rotomwash'), { ability: 'levitate', item: '' }, 'earthquake', {});
edge(S('garchomp'), { ability: 'roughskin', item: '' }, S('excadrill'), { ability: 'sandrush', item: 'airballoon' }, 'earthquake', {});
edge(S('kingambit'), { ability: 'defiant', item: '' }, S('gengar'), { ability: 'cursedbody', item: '' }, 'bodyslam', {});
edge(S('pikachu'), { ability: 'static', item: 'lightball' }, S('garchomp'), { ability: 'roughskin', item: '' }, 'thunderbolt', {});
edge(S('garchomp'), { ability: 'roughskin', item: '' }, S('rotomwash'), { ability: 'levitate', item: '' }, 'dragonclaw', { auroraVeil: true }); edge(S('rotomwash'), { ability: 'levitate', item: '' }, S('gyarados'), { ability: 'intimidate', item: '' }, 'thunderbolt', {});
edge(S('charizard'), { ability: 'blaze', item: 'charcoal', hpPercent: 20 }, S('venusaur'), { ability: 'chlorophyll', item: 'occaberry' }, 'flamethrower', { weather: 'sun' });
edge(S('incineroar'), { ability: 'intimidate', item: '' }, S('dragonite'), { ability: 'multiscale', item: '' }, 'flareblitz', { crit: true });
edge(S('dragonite'), { ability: 'innerfocus', item: '' }, S('dragonite'), { ability: 'multiscale', item: 'yacheberry' }, 'icepunch', {});
edge(S('kangaskhanmega'), {}, S('incineroar'), { ability: 'intimidate', item: '' }, 'doubleedge', { doubles: false });
edge(S('meganiummega'), {}, S('incineroar'), { ability: 'intimidate', item: '' }, 'weatherball', { weather: 'rain' });
edge(S('garchomp'), { ability: 'roughskin', item: '' }, S('incineroar'), { ability: 'intimidate', item: '' }, 'rockslide', { spread: true, reflect: true });
edge(S('garchomp'), { ability: 'roughskin', item: '' }, S('incineroar'), { ability: 'intimidate', item: '' }, 'rockslide', { doubles: false, reflect: true });
edge(S('scizor'), { ability: 'technician', item: '' }, S('gardevoir'), { ability: 'trace', item: '' }, 'bulletpunch', {});
edge(S('gengar'), { ability: 'cursedbody', item: '' }, S('kangaskhan'), { ability: 'scrappy', item: '' }, 'shadowball', {});

const cases = [];
let ties = 0;
const all = [...fixed];
while (all.length < N + 400) { const c = randomCase(); if (c) all.push(c); }
for (const c of all) {
  if (cases.length >= fixed.length + N && cases.length >= fixed.length) break;
  const e = evaluate(c);
  if (e.tie) { ties++; continue; }
  cases.push({ ...c, expected: e });
}
process.stdout.write(JSON.stringify({
  source: 'Pokémon Showdown sim, mod champions (getDamage con cada tirada forzada)',
  skipped_speed_ties_or_unsupported: ties, cases,
}) + '\n');
process.stderr.write(`cases=${cases.length} immune=${cases.filter(c => c.expected.immune).length} skipped=${ties}\n`);
