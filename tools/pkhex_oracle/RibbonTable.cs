// Tabla Ribbon Master desde PKHeX (comando `ribbons <outdir>`):
//   ribbon_oracle.csv  por especie y forma: el origen que permite más cintas (del más
//                      antiguo al más nuevo), los juegos por los que puede pasar (cadena
//                      de evoluciones por contexto, PKHeX `EvolutionHistory`) y las cintas
//                      que PKHeX da por válidas (`RibbonApplicator.SetAllValidRibbons`).
// Lo usan tool/gen_ribbon_master_data.py (tabla de rutas de pkcore) y el test
// `ribbon_master_pkhex_test.dart` (tabla versionada).
//
// Método: para cada especie/forma se piden a PKHeX todos los encuentros que pueden
// acabar en ella (también como preevolución), se convierte cada candidato al formato
// más reciente donde existe la forma (Pal Park, Poké Transfer, Banco, HOME), se
// evoluciona, se sube a nivel 100 con afecto máximo y se aplican todas las cintas
// válidas; para Gen 3–5 se repite en PK5 (las cintas de concurso y combate de
// Gen 3/4 solo existen ahí). Gana el candidato con más cintas obtenibles jugando
// (sin eventos); a igualdad, el más antiguo y que no sea de evento.
using System.Text;
using PKHeX.Core;

static class RibbonTable
{
    static readonly EntityContext[] Contexts =
    [
        EntityContext.Gen1, EntityContext.Gen2, EntityContext.Gen3, EntityContext.Gen4, EntityContext.Gen5,
        EntityContext.Gen6, EntityContext.Gen7, EntityContext.Gen7b, EntityContext.Gen8, EntityContext.Gen8a,
        EntityContext.Gen8b, EntityContext.Gen9, EntityContext.Gen9a,
    ];

    // Formato final: el más reciente donde existe la forma (para que PKHeX considere todos
    // los juegos de HOME por los que puede pasar).
    static readonly (IPersonalTable Table, Type Type, GameVersion Version)[] Finals =
    [
        (PersonalTable.SV, typeof(PK9), GameVersion.SL),
        (PersonalTable.SWSH, typeof(PK8), GameVersion.SW),
        (PersonalTable.BDSP, typeof(PB8), GameVersion.BD),
        (PersonalTable.LA, typeof(PA8), GameVersion.PLA),
        (PersonalTable.ZA, typeof(PA9), GameVersion.ZA),
        (PersonalTable.USUM, typeof(PK7), GameVersion.US),
        (PersonalTable.SM, typeof(PK7), GameVersion.SN),
        (PersonalTable.AO, typeof(PK6), GameVersion.OR),
        (PersonalTable.B2W2, typeof(PK5), GameVersion.B2),
        (PersonalTable.HGSS, typeof(PK4), GameVersion.HG),
        (PersonalTable.E, typeof(PK3), GameVersion.E),
        (PersonalTable.GG, typeof(PB7), GameVersion.GP),
    ];

    // Cintas que se repartieron en eventos: no cuentan para elegir el origen.
    static readonly HashSet<string> EventRibbons =
    [
        "RibbonCountry", "RibbonNational", "RibbonEarth", "RibbonWorld", "RibbonClassic", "RibbonPremier", "RibbonEvent",
        "RibbonBirthday", "RibbonSpecial", "RibbonSouvenir", "RibbonWishing", "RibbonChampionBattle",
        "RibbonChampionRegional", "RibbonChampionNational", "RibbonChampionWorld", "RibbonOnceInALifetime",
        "RibbonPartner", "RibbonRecord",
    ];

    public static int Run(string outDir)
    {
        Directory.CreateDirectory(outDir);
        var sb = new StringBuilder();
        sb.Append("# Generado por tools/pkhex_oracle (ribbons) desde PKHeX.Core (GPL-3.0).\n");
        sb.Append("# especie,forma,formato final,generacion de origen,version de origen,tipo de encuentro,evento,sombra,nivel,");
        sb.Append("cadenas por contexto (ctx=especie-forma/...;),cintas validas (|),recuerdo concurso,recuerdo combate,banderas\n");
        var rows = 0;
        var missing = 0;
        foreach (var (species, form) in Targets())
        {
            var best = Best(species, form);
            if (best == null)
            {
                missing++;
                sb.Append($"{species},{form},,,,,,,,,,,,\n");
                continue;
            }
            sb.Append(best);
            sb.Append('\n');
            rows++;
        }
        File.WriteAllText(Path.Combine(outDir, "ribbon_oracle.csv"), sb.ToString());
        Console.WriteLine($"ribbons: {rows} especies/formas con origen, {missing} sin encuentro en {outDir}");
        return 0;
    }

    static IEnumerable<(ushort, byte)> Targets()
    {
        var max = PersonalTable.SV.MaxSpeciesID;
        foreach (var (t, _, _) in Finals)
            max = Math.Max(max, t.MaxSpeciesID);
        for (ushort species = 1; species <= max; species++)
        {
            var forms = new SortedSet<byte>();
            foreach (var (t, _, _) in Finals)
            {
                if (species > t.MaxSpeciesID)
                    continue;
                var count = Math.Max((int)t[species, 0].FormCount, 1);
                for (byte f = 0; f < count; f++)
                {
                    if (!t.IsPresentInGame(species, f))
                        continue;
                    if (f != 0 && (FormInfo.IsBattleOnlyForm(species, f, 9) || FormInfo.IsTotemForm(species, f) || FormInfo.IsLordForm(species, f, EntityContext.Gen8a)))
                        continue;
                    forms.Add(f);
                }
            }
            if (OnlySpecies != 0 && species != OnlySpecies)
                continue;
            foreach (var f in forms)
                yield return (species, f);
        }
    }

    static readonly bool Debug = Environment.GetEnvironmentVariable("RIBBON_DEBUG") == "1";
    static readonly int OnlySpecies = int.TryParse(Environment.GetEnvironmentVariable("RIBBON_ONLY"), out var o) ? o : 0;

    sealed record Result(string Row, int Score, int Generation, bool Event, bool Go);

    static string? Best(ushort species, byte form)
    {
        Result? best = null;
        foreach (var (table, type, version) in Finals)
        {
            if (species > table.MaxSpeciesID || !table.IsPresentInGame(species, form))
                continue;
            foreach (var enc in Candidates(species, form, type, version))
            {
                Result? r;
                try { r = Evaluate(species, form, type, version, enc); }
                catch (Exception e) { r = null; if (Debug) Console.Error.WriteLine($"  {enc}: {e.Message}"); }
                if (Debug) Console.Error.WriteLine($"{species}-{form} {enc.GetType().Name} {enc.Version} g{enc.Generation}: {r?.Score.ToString() ?? "x"}");
                if (r == null)
                    continue;
                if (best == null || Better(r, best))
                    best = r;
            }
            break; // solo el formato final más reciente
        }
        return best?.Row;
    }

    static bool Better(Result a, Result b)
    {
        if (a.Event != b.Event)
            return !a.Event; // un origen jugable gana a uno de evento
        if (a.Score != b.Score)
            return a.Score > b.Score;
        if (a.Go != b.Go)
            return !a.Go; // a igualdad, un juego principal antes que GO
        return a.Generation < b.Generation;
    }

    static IEnumerable<IEncounterable> Candidates(ushort species, byte form, Type type, GameVersion version)
    {
        var pk = EntityBlank.GetBlank(type);
        pk.Species = species;
        pk.Form = form;
        pk.Gender = pk.GetSaneGender();
        pk.CurrentLevel = 100;
        pk.Version = version;
        pk.Language = (int)LanguageID.English;
        var tr = new SimpleTrainerInfo(version);
        var seen = new HashSet<string>();
        IEnumerable<IEncounterable> all;
        try
        {
            EncounterMovesetGenerator.OptimizeCriteria(pk, tr);
            var versions = GameUtil.GetVersionsWithinRange(pk, pk.Context).Where(v => v.Context != EntityContext.None).ToArray();
            all = EncounterMovesetGenerator.GenerateEncounters(pk, ReadOnlyMemory<ushort>.Empty, new ReadOnlyMemory<GameVersion>(versions)).ToList();
        }
        catch (Exception e) { if (Debug) Console.Error.WriteLine($"gen {species}-{form}: {e.Message}"); yield break; }
        if (Debug) Console.Error.WriteLine($"{species}-{form}: {all.Count()} encuentros");
        foreach (var enc in all)
        {
            var key = $"{enc.GetType().Name}|{enc.Version}|{enc.Species}|{enc.Form}|{(enc.LevelMin <= 50 ? 0 : 1)}|{enc is IShadow3}";
            if (!seen.Add(key))
                continue;
            yield return enc;
        }
    }

    static bool IsEvent(IEncounterable enc) => enc switch
    {
        MysteryGift => true,
        EncounterGift3 or EncounterGift3JPN or EncounterGift3NY => true,
        EncounterGift1 or EncounterGift2 => true,
        EncounterTrade4RanchGift => true,
        EncounterStatic3 { FatefulEncounter: true } => true, // tickets repartidos (Isla Lejana, Isla Ombligo…)
        EncounterStatic4 { FatefulEncounter: true } => true,
        _ => false,
    };

    static Result? Evaluate(ushort species, byte form, Type type, GameVersion version, IEncounterable enc)
    {
        var tr = new SimpleTrainerInfo(version);
        var origin = enc.ConvertToPKM(tr);
        var pk = EntityConverter.ConvertToType(origin.Clone(), type, out _);
        if (pk == null)
        {
            if (Debug) Console.Error.WriteLine($"  convert {origin.GetType().Name}->{type.Name} fallo");
            return null;
        }
        Prepare(pk, species, form);
        var la = new LegalityAnalysis(pk);
        if (la.EncounterMatch is EncounterInvalid)
        {
            if (Debug) Console.Error.WriteLine($"  invalid: {string.Join(" / ", la.Results.Where(z => !z.Valid).Select(z => z.Identifier + ":" + z.Result))}");
            return null;
        }
        RibbonApplicator.SetAllValidRibbons(la);
        var ribbons = new SortedSet<string>(StringComparer.Ordinal);
        foreach (var ri in RibbonInfo.GetRibbonInfo(pk))
            if (ri.HasRibbon || ri.RibbonCount > 0)
                ribbons.Add(ri.Name);
        // Espada/Escudo: un Pokémon de otro juego entra en Combate Clasificatorio tras
        // volverse «apto para combatir» (BattleVersion). PKHeX lo exige para la cinta.
        if (!ribbons.Contains("RibbonMasterRank") && pk is PK8 && enc.Generation < 8)
        {
            var bv = (PK8)pk.Clone();
            bv.BattleVersion = GameVersion.SW;
            bv.RefreshChecksum();
            var lab = new LegalityAnalysis(bv);
            if (lab.EncounterMatch is not EncounterInvalid)
            {
                RibbonApplicator.SetAllValidRibbons(lab);
                if (bv.RibbonMasterRank)
                    ribbons.Add("RibbonMasterRank");
            }
        }
        var mem = pk as IRibbonSetMemory6;
        var memContest = mem?.RibbonCountMemoryContest ?? 0;
        var memBattle = mem?.RibbonCountMemoryBattle ?? 0;
        var history = new LegalityAnalysis(pk).Info.EvoChainsAllGens;

        // Gen 3–5: las cintas de concurso/combate de Gen 3 y 4 solo existen en PK3–PK5.
        if (enc.Generation is >= 3 and <= 5 && type != typeof(PK3) && type != typeof(PK4))
        {
            var pk5 = EntityConverter.ConvertToType(origin.Clone(), typeof(PK5), out _);
            if (pk5 != null)
            {
                var g5 = history.Gen5.Length > 0 ? history.Gen5[0] : (history.Gen4.Length > 0 ? history.Gen4[0] : default);
                if (g5.Species != 0)
                    Prepare(pk5, g5.Species, g5.Form);
                var la5 = new LegalityAnalysis(pk5);
                if (la5.EncounterMatch is not EncounterInvalid)
                {
                    RibbonApplicator.SetAllValidRibbons(la5);
                    foreach (var ri in RibbonInfo.GetRibbonInfo(pk5))
                        if (ri.HasRibbon || ri.RibbonCount > 0)
                            ribbons.Add(ri.Name);
                }
            }
        }
        var chains = new StringBuilder();
        foreach (var ctx in Contexts)
        {
            var evos = history.Get(ctx);
            if (evos.Length == 0)
                continue;
            chains.Append(ctx).Append('=');
            for (var i = 0; i < evos.Length; i++)
            {
                if (i > 0) chains.Append('/');
                chains.Append(evos[i].Species).Append('-').Append(evos[i].Form);
            }
            chains.Append(';');
        }
        var score = ribbons.Count(r => !EventRibbons.Contains(r) && !r.StartsWith("RibbonMark") && !r.StartsWith("RibbonCountMemory")
                                       && !r.StartsWith("HasContest") && !r.StartsWith("HasBattle"));
        // Las de evento que trae el propio encuentro no se cuentan, pero la Nacional/Tierra
        // de Colosseum/XD sí se ganan jugando.
        if (ribbons.Contains("RibbonNational")) score++;
        if (ribbons.Contains("RibbonEarth")) score++;
        var shadow = enc is IShadow3 ? 1 : 0;
        // Banderas: V = alguna etapa en DBPR no tiene voz (Huella a cualquier nivel); M = singular.
        var flags = "";
        foreach (var e in history.Gen8b)
            if (PersonalInfo8BDSP.IsVoiceless(e.Species)) { flags += "V"; break; }
        if (SpeciesCategory.IsMythical(species)) flags += "M";
        var ev = IsEvent(enc);
        var row = $"{species},{form},{type.Name},{enc.Generation},{enc.Version},{enc.GetType().Name},{(ev ? 1 : 0)},{shadow},{enc.LevelMin},"
                  + $"{chains},{string.Join('|', ribbons)},{memContest},{memBattle},{flags}";
        return new Result(row, score, enc.Generation, ev, enc.Version == GameVersion.GO);
    }

    static void Prepare(PKM pk, ushort species, byte form)
    {
        pk.Species = species;
        pk.Form = form;
        pk.CurrentLevel = 100;
        if (pk is IAffection a)
            a.OriginalTrainerAffection = 255;
        pk.CurrentFriendship = 255;
        // Con rastreador de HOME, PKHeX considera todos los juegos de HOME por los que puede pasar.
        if (pk is IHomeTrack h)
            h.Tracker = 0x1234_5678_9ABC_DEF0;
        pk.RefreshChecksum();
    }
}
