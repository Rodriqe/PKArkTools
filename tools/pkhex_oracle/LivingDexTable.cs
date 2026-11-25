// Living Dex (comando `livingdex <outdir> [versión]`): por cada versión de un
// juego principal (Gen 1–9) y cada especie/forma guardable en caja que el juego
// admite, un Pokémon legal creado por PKHeX a partir de un encuentro real de esa
// versión, sin intercambios ni eventos: huevo (eclosionado), estático/regalo o
// salvaje, y la evolución cuando la especie es una evolución del encuentro.
//
//   livingdex.jsonl  una línea por (versión, especie, forma): plantilla
//                    (entrenador de prueba ARKA 12345/54321) o el motivo por el
//                    que no se puede crear, tipo de encuentro, bloqueo de
//                    variocolor y el modo de re-ID que pkcore puede aplicar:
//      free  PID libre: pkcore elige un PID que conserva género, naturaleza,
//            habilidad (y letra de Unown / evolución de Wurmple) y cumple la
//            petición de variocolor con el ID del save (huevos, Gen 6+).
//      m1    Gen 3–4 Method 1: pkcore genera PID+IV con el LCRNG (estáticos).
//      keep  correlación que pkcore no reproduce: se conserva el PID/IV de la
//            plantilla (o la alternativa si con el ID del save sería variocolor);
//            el variocolor no se puede generar.
// Cada modo se comprueba aquí aplicando la misma transformación con otro
// entrenador (ZETA 22222/33333, normal y variocolor) y `LegalityAnalysis`.
//
// Lo usa tool/gen_living_dex_data.py para generar la tabla de pkcore.
using System.Text.Json.Nodes;
using PKHeX.Core;

static class LivingDexTable
{
    // Versiones de cada juego principal (ids de PKHeX `GameVersion`).
    static readonly GameVersion[][] Games =
    [
        [GameVersion.RD, GameVersion.GN], [GameVersion.YW], [GameVersion.GD, GameVersion.SI], [GameVersion.C],
        [GameVersion.R, GameVersion.S], [GameVersion.E], [GameVersion.FR, GameVersion.LG],
        [GameVersion.D, GameVersion.P], [GameVersion.Pt], [GameVersion.HG, GameVersion.SS],
        [GameVersion.B, GameVersion.W], [GameVersion.B2, GameVersion.W2],
        [GameVersion.X, GameVersion.Y], [GameVersion.OR, GameVersion.AS],
        [GameVersion.SN, GameVersion.MN], [GameVersion.US, GameVersion.UM],
        [GameVersion.GP, GameVersion.GE], [GameVersion.SW, GameVersion.SH],
        [GameVersion.BD, GameVersion.SP], [GameVersion.PLA], [GameVersion.SL, GameVersion.VL], [GameVersion.ZA],
    ];

    static SimpleTrainerInfo Trainer(GameVersion v, bool alt = false) => new(v)
    {
        OT = alt ? "ZETA" : "ARKA",
        TID16 = alt ? (ushort)22222 : (ushort)12345,
        SID16 = alt ? (ushort)33333 : (ushort)54321,
        Gender = alt ? (byte)1 : (byte)0,
        Language = 2,
    };

    static readonly Random Rng = new(20261125);

    public static int Run(string outDir, string? only)
    {
        Directory.CreateDirectory(outDir);
        EncounterMovesetGenerator.PriorityList = [EncounterTypeGroup.Egg, EncounterTypeGroup.Static, EncounterTypeGroup.Slot];
        var path = Path.Combine(outDir, only == null ? "livingdex.jsonl" : $"livingdex_{only}.jsonl");
        using var w = new StreamWriter(path);
        foreach (var game in Games)
        {
            if (only != null && !game.Any(v => v.ToString() == only)) continue;
            var first = new Dictionary<(ushort, byte), (JsonObject Row, PKM? Pk)>();
            foreach (var v in game) RunVersion(w, v, game, first);
            w.Flush();
        }
        return 0;
    }

    /// La otra versión del par reutiliza la plantilla de la primera (campo `vs`) si PKHeX la
    /// acepta con esa versión de origen y la especie tiene encuentro propio en ella.
    static void RunVersion(StreamWriter w, GameVersion v, GameVersion[] game, Dictionary<(ushort, byte), (JsonObject Row, PKM? Pk)> first)
    {
        var isFirst = v == game[0];
        var pending = new List<JsonObject>();
        var pt = GameData.GetPersonal(v);
        int ok = 0, none = 0;
        var counts = new Dictionary<string, int>();
        for (ushort s = 1; s <= pt.MaxSpeciesID; s++)
        {
            var fc = pt[s].FormCount;
            // Unown en Gen 2–3: la letra sale de los DV / del PID (una sola entrada en la tabla personal).
            var unownLetters = s == (int)Species.Unown && v.Generation is 2 or 3;
            if (unownLetters) fc = (byte)(v.Generation == 2 ? 26 : 28);
            for (byte f = 0; f < Math.Max((byte)1, fc); f++)
            {
                if (!pt.IsPresentInGame(s, unownLetters ? (byte)0 : f)) continue;
                if (Excluded(s, f, v) is { } why)
                {
                    w.WriteLine(new JsonObject { ["v"] = (int)v, ["s"] = s, ["f"] = f, ["skip"] = why }.ToJsonString());
                    continue;
                }
                if (!isFirst && first.TryGetValue((s, f), out var prev) && prev.Pk is { } ppk && SharedWith(ppk, v, s, f))
                {
                    ((JsonArray)prev.Row["vs"]!).Add((int)v);
                    ok++;
                    continue;
                }
                JsonObject row;
                try { row = Row(v, s, f); }
                catch (Exception e) { row = new JsonObject { ["v"] = (int)v, ["s"] = s, ["f"] = f, ["err"] = e.GetType().Name + ": " + e.Message }; }
                if (row["tpl"] is null) none++; else ok++;
                if (row["mode"] is JsonValue m) counts[m.ToString()] = counts.GetValueOrDefault(m.ToString()) + 1;
                row["vs"] = new JsonArray((int)v);
                if (isFirst) first[(s, f)] = (row, LastPk);
                pending.Add(row);
            }
        }
        // La primera versión se escribe al final del par (cuando ya sabe con qué versiones se comparte).
        if (isFirst && game.Length > 1) { Held.AddRange(pending); }
        else
        {
            foreach (var r in Held) w.WriteLine(r.ToJsonString());
            Held.Clear();
            foreach (var r in pending) w.WriteLine(r.ToJsonString());
        }
        Console.Error.WriteLine($"{v}: {ok} creables, {none} sin encuentro; modos {string.Join(' ', counts.Select(kv => kv.Key + "=" + kv.Value))}");
    }

    static readonly List<JsonObject> Held = [];
    [ThreadStatic] static PKM? LastPk;

    static bool SharedWith(PKM pk, GameVersion v, ushort s, byte f)
    {
        if (pk.Format <= 2) return true; // Gen 1–2: sin versión de origen
        var c = pk.Clone();
        c.Version = v;
        c.RefreshChecksum();
        if (!Valid(c)) return false;
        return EncounterMovesetGenerator.GenerateEncounters(Blank(v, s, f), Trainer(v), ReadOnlyMemory<ushort>.Empty, v)
            .Any(e => !e.GetType().Name.StartsWith("EncounterTrade") && e is not MysteryGift);
    }

    /// Formas que no se guardan en caja (o no se pueden tener a la vez que otra).
    static string? Excluded(ushort s, byte f, GameVersion v)
    {
        var fmt = (byte)v.Generation;
        if (FormInfo.IsBattleOnlyForm(s, f, fmt)) return "battle";
        if (FormInfo.IsFusedForm(s, f, fmt)) return "fused";
        if (FormInfo.IsTotemForm(s, f, v.Context)) return "totem";
        if (FormInfo.IsLordForm(s, f, v.Context)) return "lord";
        // Gen 6: los cortes de Furfrou y Hoopa desatado vuelven a la forma base al dejarlos en
        // la caja (PKHeX `CheckFurfrou6`: la forma solo existe en el equipo).
        if (v.Generation == 6 && f != 0 && s is (ushort)Species.Furfrou or (ushort)Species.Hoopa) return "boxrevert";
        // Vivillon Elegante y Poké Ball: solo por evento.
        if (s is (ushort)Species.Scatterbug or (ushort)Species.Spewpa or (ushort)Species.Vivillon && (f == 19 || (f == 18 && v.Generation <= 7))) return "eventform";
        // Pikachu con gorra / cosplay, Floette eterna, Pichu picoreja, Eevee/Pikachu compañero:
        // los decide el encuentro (si no hay, no saldrán).
        return null;
    }

    static PKM Blank(GameVersion v, ushort s, byte f)
    {
        var pk = EntityBlank.GetBlank(Trainer(v));
        pk.Species = s;
        pk.Form = s == (int)Species.Unown && v.Generation <= 2 ? (byte)0 : f;
        pk.Version = v;
        if (GenderFor(s, f) == Gender.Female) pk.Gender = 1;
        return pk;
    }

    static Gender GenderFor(ushort s, byte f) => (Species)s switch
    {
        Species.Meowstic or Species.Indeedee or Species.Basculegion or Species.Oinkologne => f == 1 ? Gender.Female : Gender.Male,
        _ => Gender.Random,
    };

    static int Kind(IEncounterable e) => e switch
    {
        IEncounterEgg => 0,
        _ when e.GetType().Name == "EncounterStatic8U" => 3,
        _ when e.GetType().Name.Contains("Static") || e.GetType().Name.Contains("Gift") => 1,
        _ => 2,
    };

    static JsonObject Row(GameVersion v, ushort s, byte f)
    {
        var row = new JsonObject { ["v"] = (int)v, ["s"] = s, ["f"] = f };
        LastPk = null;
        var blank = Blank(v, s, f);
        var tr = Trainer(v);
        var encs = EncounterMovesetGenerator.GenerateEncounters(blank, tr, ReadOnlyMemory<ushort>.Empty, v)
            .Where(e => !e.GetType().Name.StartsWith("EncounterTrade") && e is not MysteryGift && e.Version != GameVersion.GO
                // Entree Forest (Dream World, en línea): fuera. Max Lair: el último recurso.
                && !e.GetType().Name.Contains("Entree"))
            .OrderBy(Kind)
            .Take(s == (int)Species.Unown ? 4000 : 24).ToList();
        if (encs.Count == 0) { row["err"] = "noenc"; return row; }
        row["nenc"] = encs.Count;
        string? firstErr = null;
        foreach (var enc in encs)
        {
            PKM? pk = null;
            string err = "";
            var tries = s == (int)Species.Unown ? (v.Generation == 2 || v.Context == EntityContext.Gen8b ? 600 : 60) : 6;
            for (var k = 0; k < tries && pk == null; k++) pk = Make(enc, tr, s, f, out err);
            if (pk == null) { firstErr ??= err; continue; }
            // Solo encuentros de esta versión (PKHeX puede dar un huevo de otra del mismo formato).
            if (pk.Format >= 3 && pk.Version != v) { firstErr ??= "otherversion"; continue; }
            row["kind"] = new[] { "egg", "static", "wild", "static" }[Kind(enc)];
            row["enc"] = enc.LongName;
            row["encSpecies"] = enc.Species;
            row["shinyFixed"] = enc.Shiny is PKHeX.Core.Shiny.Always or PKHeX.Core.Shiny.AlwaysSquare or PKHeX.Core.Shiny.AlwaysStar;
            row["level"] = pk.CurrentLevel;
            // Encuentro que exige un objeto de evento (Isla Lejana, Ticket Libertad…): «encuentro del destino».
            if (pk.FatefulEncounter) row["fateful"] = true;
            row["fmt"] = pk.GetType().Name.ToLowerInvariant();
            row["tpl"] = Bytes(pk);
            LastPk = pk;
            // Modo de re-ID que acepta PKHeX.
            LastProbe = "";
            EncSpecies = enc.Species;
            var (mode, smode) = Probe(pk);
            row["mode"] = mode;
            if (smode != null) row["smode"] = smode;
            else if (LastProbe!.Contains("shiny mismatch") || enc.Shiny == PKHeX.Core.Shiny.Never) row["locked"] = true;
            if ((mode != "free" || smode == null) && LastProbe is { Length: > 0 }) row["probe"] = LastProbe.Length > 600 ? LastProbe[..600] : LastProbe;
            if (mode == "keep")
            {
                // Alternativa (otra tirada) por si con el ID del save la plantilla fuese variocolor.
                for (var k = 0; k < 6; k++)
                {
                    var alt = Make(enc, tr, s, f, out _);
                    if (alt != null && alt.PID != pk.PID && ProbeKeep(alt)) { row["alt"] = Bytes(alt); break; }
                }
            }
            return row;
        }
        row["err"] = firstErr ?? "?";
        return row;
    }

    static string Bytes(PKM pk)
    {
        if (pk is GBPKM gb)
        {
            // Gen 1–2: estructura + OT + apodo (pkcore los recompone).
            return Convert.ToBase64String(gb.Data);
        }
        var b = new byte[pk.SIZE_STORED];
        pk.WriteDecryptedDataStored(b);
        return Convert.ToBase64String(b);
    }

    static bool Valid(PKM pk) => new LegalityAnalysis(pk).Valid;

    /// Crea el Pokémon del encuentro y, si es una preevolución, lo evoluciona al nivel mínimo legal.
    static PKM? Make(IEncounterable enc, ITrainerInfo tr, ushort s, byte f, out string err)
    {
        err = "";
        PKM pk;
        var crit = new EncounterCriteria { Shiny = PKHeX.Core.Shiny.Never, Gender = GenderFor(s, f), Form = s == (int)Species.Unown && tr.Version.Generation >= 3 ? (sbyte)f : (sbyte)-1 };
        try { pk = ((IEncounterConvertible)enc).ConvertToPKM(tr, crit); }
        catch (Exception e) { err = "convert: " + e.Message; return null; }
        if (pk.IsShiny) { err = "shiny"; return null; }
        if (s == (int)Species.Unown && pk.Format >= 3 && pk.Form != f) { err = "letter"; return null; }
        if (pk.Species != s || pk.Form != f)
        {
            // Evolución; las de intercambio necesitan haber pasado por otro entrenador (Gen 6+:
            // entrenador anterior y su recuerdo, como al cambiarlo y recibirlo de vuelta).
            var evolved = Evolve(pk, enc, s, f, null);
            var plainErr = EvolveErr;
            if (evolved == null && pk.Format >= 6) evolved = Evolve(pk, enc, s, f, tr);
            if (evolved == null) EvolveErr = plainErr + " || traded: " + EvolveErr;
            if (evolved == null) { err = EvolveErr ?? "evolve"; return null; }
            pk = evolved;
        }
        else
        {
            Finish(pk);
            if (!Valid(pk)) FixUp(pk, pk.CurrentLevel);
        }
        if (!Valid(pk)) { err = Report(pk); return null; }
        return pk;
    }

    static PKM? Evolve(PKM src, IEncounterable enc, ushort s, byte f, ITrainerInfo? traded)
    {
        var pk = src.Clone();
        if (traded != null && pk is IHandlerUpdate hu)
        {
            var partner = new SimpleTrainerInfo(traded.Version) { OT = "Ark", TID16 = 1, SID16 = 2, Gender = 0, Language = traded.Language };
            hu.UpdateHandler(partner);
            hu.UpdateHandler(traded);
        }
        else if (traded != null)
        {
            // DBPR (PB8) no implementa IHandlerUpdate: el entrenador del intercambio se escribe
            // como lo hace PKHeX (`PKH.UpdateHandler`) y el Pokémon vuelve a su OT.
            pk.HandlingTrainerName = "Ark";
            pk.HandlingTrainerGender = 0;
            if (pk is IHandlerLanguage hl) hl.HandlingTrainerLanguage = (byte)traded.Language;
            pk.HandlingTrainerFriendship = pk.PersonalInfo.BaseFriendship;
            pk.CurrentHandler = 0;
        }
        pk.Species = s;
        pk.Form = f;
        if (!pk.IsNicknamed) pk.ClearNickname();
        var hi = 100;
        if (!FixUp(pk, (byte)hi)) { EvolveErr = Report(pk); return null; }
        int lo = Math.Max(enc.LevelMin, pk.MetLevel);
        while (lo < hi)
        {
            var mid = (lo + hi) / 2;
            var t = pk.Clone();
            if (FixUp(t, (byte)mid)) hi = mid; else lo = mid + 1;
        }
        FixUp(pk, (byte)hi);
        return pk;
    }

    static string Report(PKM pk)
    {
        var r = new LegalityAnalysis(pk).Report();
        return r.Length > 1500 ? r[..1500] : r;
    }

    static bool FixUp(PKM pk, byte level)
    {
        pk.CurrentLevel = level;
        // Objeto que fija la forma (Arceus, Genesect, Silvally, Ogerpon, Giratina/Dialga/Palkia Origen…).
        if (pk is not PA8)
        {
            var item = FormItem.GetItem(pk.Species, pk.Form);
            if (pk.Species == (int)Species.Giratina && pk.Form == 1) item = pk.Format <= 8 ? (ushort)112 : (ushort)1779;
            if (pk.Format >= 9 && pk.Species == (int)Species.Dialga && pk.Form == 1) item = 1777;
            if (pk.Format >= 9 && pk.Species == (int)Species.Palkia && pk.Form == 1) item = 1778;
            if (item != 0) pk.HeldItem = item;
        }
        var pi = pk.PersonalInfo;
        if (pi.Genderless) pk.Gender = 2;
        else if (pi.OnlyMale) pk.Gender = 0;
        else if (pi.OnlyFemale) pk.Gender = 1;
        pk.RefreshAbility(pk.AbilityNumber >> 1);
        // Milotic: Feebas evoluciona con Belleza alta (concursos de Gen 3–5).
        if (pk.Species == (int)Species.Milotic && (pk.Format <= 5 || pk is PB8) && pk is IContestStats cs && cs.ContestBeauty < 170) { cs.ContestBeauty = 170; cs.ContestSheen = 255; }
        // Furfrou/Hoopa: días restantes; evoluciones por contador (Annihilape, Gholdengo…).
        if (pk is IFormArgument fa)
        {
            var max = FormArgumentUtil.GetFormArgumentMax(pk.Species, pk.Form, pk.Context);
            var min = FormArgumentUtil.GetFormArgumentMinEvolution(pk.Species, EncSpecies);
            if (min > 0) fa.FormArgument = min;
            else if (max > 0 && max < 10 && pk.Form != 0) fa.FormArgument = max;
        }
        if (pk is PK9 p9 && pk.Species == (int)Species.Ogerpon)
            p9.TeraTypeOriginal = p9.TeraTypeOverride = (MoveType)((pk.Form & 3) switch { 0 => (int)MoveType.Grass, 1 => (int)MoveType.Water, 2 => (int)MoveType.Fire, _ => (int)MoveType.Rock });
        Finish(pk);
        for (var pass = 0; pass < 3 && !Valid(pk); pass++)
        {
            var la = new LegalityAnalysis(pk);
            Span<ushort> moves = stackalloc ushort[4];
            la.GetMoveSet(moves);
            pk.SetMoves(moves);
            if (pass == 1) { pk.RelearnMove1 = pk.RelearnMove2 = pk.RelearnMove3 = pk.RelearnMove4 = 0; }
            else pk.SetRelearnMoves(new LegalityAnalysis(pk));
            if (pk is ITechRecord t) t.SetRecordFlags(pk, TechnicalRecordApplicatorOption.None);
            if (pk is IMoveShop8Mastery ms)
            {
                ms.ClearMoveShopFlags();
                var l2 = new LegalityAnalysis(pk);
                if (l2.EncounterMatch is IMasteryInitialMoveShop8 shop) shop.SetInitialMastery(pk, l2.EncounterMatch);
                ms.SetMoveShopFlags(pk);
            }
            Finish(pk);
        }
        if (!Valid(pk) && pk.Species is 664 or 665 or 666 && pk is IRegionOrigin ro && pk.Format <= 7) Vivillon(pk, ro);
        return Valid(pk);
    }

    /// Gen 6–7: país/región de la consola que dan el dibujo de Vivillon de la forma.
    static void Vivillon(PKM pk, IRegionOrigin ro)
    {
        for (byte c = 1; c < 255; c++)
            for (byte r = 0; r < 128; r++)
            {
                if (Vivillon3DS.GetPattern(c, r) != pk.Form) continue;
                for (byte cr = 0; cr < 7; cr++)
                {
                    if (!Vivillon3DS.IsPatternValid(pk.Form, cr)) continue;
                    ro.Country = c; ro.Region = r; ro.ConsoleRegion = cr;
                    pk.RefreshChecksum();
                    if (Valid(pk)) return;
                    break;
                }
            }
    }

    static void Finish(PKM pk)
    {
        // Subido de nivel: algo de experiencia sobre el umbral y algunos EV (si no, PKHeX avisa Fishy).
        if (pk.CurrentLevel > Math.Max((byte)1, pk.MetLevel) && pk.Format >= 3)
        {
            var lvl = pk.CurrentLevel;
            var exp = Experience.GetEXP(lvl, pk.PersonalInfo.EXPGrowth);
            var next = lvl < 100 ? Experience.GetEXP((byte)(lvl + 1), pk.PersonalInfo.EXPGrowth) : exp + 1;
            if (pk.EXP == exp && next > exp + 1) pk.EXP = exp + Math.Min(37u, next - exp - 1);
            if (pk.EVTotal == 0 && pk is not PB7 && pk is not PA8 && pk is not PA9) pk.EV_HP = Math.Min(252, 4 * (lvl - pk.MetLevel));
        }
        if (pk is IScaledSizeValue sv) { sv.ResetHeight(); sv.ResetWeight(); }
        if (pk is PB7 b7) { b7.AwakeningMinimum(); b7.ResetCalculatedValues(); }
        if (pk is PA9 z && z.PersonalInfo is IPermitPlus pp) z.SetPlusFlags(pp, PlusRecordApplicatorOption.LegalCurrent);
        if (pk is PK9 p9 && p9.ObedienceLevel < pk.MetLevel) p9.ObedienceLevel = pk.MetLevel;
        if (pk is PA9 a9 && a9.ObedienceLevel < pk.MetLevel) a9.ObedienceLevel = pk.MetLevel;
        pk.HealPP();
        pk.ResetPartyStats();
        pk.RefreshChecksum();
    }

    // ------------------------------------------------------------------ re-ID

    /// Modo para el Pokémon normal y, aparte, para el variocolor (null si no se puede).
    static (string Normal, string? Shiny) Probe(PKM tpl)
    {
        var modes = tpl.Format switch { <= 2 => new[] { "free" }, 3 or 4 => ["free", "m1"], _ => ["free"] };
        var normal = modes.FirstOrDefault(m => ProbeMode(tpl, m, false)) ?? (ProbeKeep(tpl) ? "keep" : "bad");
        var shiny = modes.FirstOrDefault(m => ProbeMode(tpl, m, true));
        return (normal, shiny);
    }

    static bool ProbeKeep(PKM tpl)
    {
        var pk = tpl.Clone();
        ReId(pk, Trainer(tpl.Version, alt: true));
        if (pk.IsShiny || !Valid(pk)) { LastProbe += "keep: " + Report(pk) + " || "; return false; }
        return true;
    }

    /// Aplica el modo con el entrenador alternativo varias veces.
    static bool ProbeMode(PKM tpl, string mode, bool shiny)
    {
        var b = Trainer(tpl.Version, alt: true);
        for (var k = 0; k < (mode == "m1" ? 12 : 4); k++)
        {
            var pk = tpl.Clone();
            ReId(pk, b);
            if (!Reroll(pk, mode, shiny)) return false;
            pk.RefreshChecksum();
            if (pk.IsShiny != shiny || !Valid(pk)) { LastProbe += $"{mode}/{shiny} pid={pk.PID:X8}: " + Report(pk) + " || "; return false; }
        }
        return true;
    }

    [ThreadStatic] static string? LastProbe;
    [ThreadStatic] static string? EvolveErr;
    [ThreadStatic] static ushort EncSpecies;

    static void ReId(PKM pk, ITrainerInfo t)
    {
        pk.OriginalTrainerName = t.OT;
        pk.TID16 = t.TID16;
        pk.SID16 = t.SID16;
        if (pk.Format >= 3) pk.OriginalTrainerGender = t.Gender; // Gen 2: solo Cristal lo guarda (con el lugar)
        pk.RefreshChecksum();
    }

    static bool Reroll(PKM pk, string mode, bool shiny)
    {
        if (pk is GBPKM gb) return RerollGb(gb, shiny);
        return mode switch
        {
            "free" => RerollFree(pk, shiny),
            "m1" => RerollM1(pk, shiny),
            _ => false,
        };
    }

    // Gen 2: DV variocolor (Def/Vel/Esp = 10, Ata ∈ {2,3,6,7,10,11,14,15}); conserva letra de Unown y género.
    static bool RerollGb(GBPKM pk, bool shiny)
    {
        var letter = pk.Species == (int)Species.Unown ? pk.Form : -1;
        var gender = pk.Gender;
        for (var k = 0; k < 100000; k++)
        {
            int atk = Rng.Next(16), def = Rng.Next(16), spe = Rng.Next(16), spc = Rng.Next(16);
            if (shiny) { def = spe = spc = 10; atk = new[] { 2, 3, 6, 7, 10, 11, 14, 15 }[Rng.Next(8)]; }
            pk.IV_ATK = atk; pk.IV_DEF = def; pk.IV_SPE = spe; pk.IV_SPA = spc;
            if (letter >= 0 && pk.Form != letter) continue;
            if (pk.Format == 2 && pk.Gender != gender) continue;
            if (pk.IsShiny != shiny && pk.Format == 2) continue;
            pk.ResetPartyStats();
            return true;
        }
        return false;
    }

    static bool IsShinyPid(uint id32, uint pid, int threshold) => ((id32 >> 16) ^ (id32 & 0xFFFF) ^ (pid >> 16) ^ (pid & 0xFFFF)) < threshold;

    /// PID nuevo que conserva lo que el PID decide (género, naturaleza, habilidad, Unown, Wurmple).
    static bool RerollFree(PKM pk, bool shiny)
    {
        var gen = pk.Format;
        var thr = gen <= 5 ? 8 : 16;
        var pid0 = pk.PID;
        var gr = pk.PersonalInfo.Gender;
        uint tsv = (uint)(pk.TID16 ^ pk.SID16);
        for (var k = 0; k < 2_000_000; k++)
        {
            uint hi = (uint)Rng.Next(0x10000), lo;
            if (shiny) lo = hi ^ tsv ^ (uint)(gen >= 8 ? 1 + Rng.Next(15) : Rng.Next(thr));
            else lo = (uint)Rng.Next(0x10000);
            uint pid = (hi << 16) | lo;
            if (IsShinyPid(pk.ID32, pid, thr) != shiny) continue;
            if (gen <= 5)
            {
                // Byte bajo igual: mismo género con la proporción de la especie del encuentro (Mothim, Gallade…).
                if ((pid & 0xFF) != (pid0 & 0xFF)) continue;
                // PID variocolor «de tarjeta» de Gen 5 (PKHeX G5MGShiny): parte baja < 0x100.
                if (shiny && (pid & 0xFFFF) < 0x100) continue;
                if (gen <= 4 && pid % 25 != pid0 % 25) continue;
                if (gen <= 4 && (pid & 1) != (pid0 & 1)) continue;
                if (gen == 5 && ((pid >> 16) & 1) != ((pid0 >> 16) & 1)) continue;
                // Gen 5 salvajes/estáticos: bit 31 ^ bit 0 ^ (TID^SID)&1 (PKHeX MonochromeRNG.GetBitXor).
                if (gen == 5 && G5Xor(pid0, Tid0, Sid0) == 0 && G5Xor(pid, pk.TID16, pk.SID16) != 0) continue;
                if (gen == 3 && pk.Species == (int)Species.Unown && EntityPID.GetUnownForm3(pid) != EntityPID.GetUnownForm3(pid0)) continue;
                if (IsBit15Line(pk.Species) && (pid & 0x8000) != (pid0 & 0x8000)) continue;
                if (IsWurmpleLine(pk.Species) && WurmpleUtil.GetWurmpleEvoVal(pid) != WurmpleUtil.GetWurmpleEvoVal(pid0)) continue;
            }
            pk.PID = pid;
            if (gen <= 5 && pk.Format >= 3 && pk is not PK3) { }
            return true;
        }
        return false;
    }

    static uint G5Xor(uint pid, int tid, int sid) => (uint)(((tid ^ sid) & 1) ^ (int)(pid & 1) ^ (int)(pid >> 31));
    const int Tid0 = 12345, Sid0 = 54321;

    static bool IsBit15Line(ushort s) => s is >= 29 and <= 34 or 313 or 314;

    static bool IsWurmpleLine(ushort s) => s is (ushort)Species.Wurmple or (ushort)Species.Silcoon or (ushort)Species.Beautifly or (ushort)Species.Cascoon or (ushort)Species.Dustox;

    /// Method 1 (Gen 3–4): PID y IV de cuatro tiradas consecutivas del LCRNG.
    static bool RerollM1(PKM pk, bool shiny)
    {
        var gr = GameData.GetPersonal(pk.Version)[EncSpecies].Gender;
        var gender = pk.Gender;
        var pid0 = pk.PID;
        for (var k = 0; k < 4_000_000; k++)
        {
            uint seed = (uint)Rng.NextInt64(0, 1L << 32);
            uint a = LCRNG.Next(seed), b = LCRNG.Next(a), c = LCRNG.Next(b), d = LCRNG.Next(c);
            uint pid = (b & 0xFFFF0000) | (a >> 16);
            if (IsShinyPid(pk.ID32, pid, 8) != shiny) continue;
            if (gr is not (0 or 254 or 255) && EntityGender.GetFromPIDAndRatio(pid, gr) != EntityGender.GetFromPIDAndRatio(pid0, gr)) continue;
            if (pk.Species == (int)Species.Unown && pk.Format == 3 && EntityPID.GetUnownForm3(pid) != EntityPID.GetUnownForm3(pid0)) continue;
            if (IsWurmpleLine(pk.Species) && WurmpleUtil.GetWurmpleEvoVal(pid) != WurmpleUtil.GetWurmpleEvoVal(pid0)) continue;
            uint iv1 = c >> 16, iv2 = d >> 16;
            pk.PID = pid;
            pk.IV_HP = (int)(iv1 & 31); pk.IV_ATK = (int)((iv1 >> 5) & 31); pk.IV_DEF = (int)((iv1 >> 10) & 31);
            pk.IV_SPE = (int)(iv2 & 31); pk.IV_SPA = (int)((iv2 >> 5) & 31); pk.IV_SPD = (int)((iv2 >> 10) & 31);
            if (pk is PK3 p3) p3.AbilityBit = (pid & 1) == 1 && p3.PersonalInfo.Ability2 != 0 && p3.PersonalInfo.Ability1 != p3.PersonalInfo.Ability2;
            else pk.RefreshAbility((int)(pid & 1));
            if (pk.Format == 4) pk.Gender = EntityGender.GetFromPIDAndRatio(pid, gr);
            pk.ResetPartyStats();
            return true;
        }
        return false;
    }
}
