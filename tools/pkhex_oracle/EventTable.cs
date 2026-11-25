// Base de eventos (Mystery Gift) desde PKHeX (comando `events <outdir>`):
//   events.jsonl  una línea JSON por evento de Pokémon de la base de PKHeX
//                 (`EncounterEvent.MGDB_G4…G9A` y los regalos de Gen 3 de
//                 `EncountersWC3`: Encounter_WC3, PCNY y PCJP).
//
// Por evento: formato y posición en la base, nº y título de tarjeta, tipo de
// variocolor, versiones e idiomas con los que PKHeX lo da por legal, qué datos
// toma del entrenador que lo recibe (OT, ID, género), fechas (tarjeta y ventana
// de distribución), la tarjeta en bruto (para exportarla) y una plantilla: el
// Pokémon que genera `ConvertToPKM` con un entrenador de prueba, validado con
// `LegalityAnalysis`, más variantes PID/IV/naturaleza (todas legales) para que
// pkcore cree Pokémon distintos sin portar cada método RNG.
//
// Lo usa tool/gen_event_data.py para generar la tabla de pkcore.
using System.Globalization;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using PKHeX.Core;

static class EventTable
{
    const int Variants = 8;
    static readonly int[] Languages = [1, 2, 3, 4, 5, 7, 8, 9, 10];

    static T[] Field<T>(string type, string name)
    {
        var t = typeof(EncounterEvent).Assembly.GetType("PKHeX.Core." + type)!;
        return (T[])t.GetField(name, BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic)!.GetValue(null)!;
    }

    public static int Run(string outDir, string? only = null)
    {
        Directory.CreateDirectory(outDir);
        var sources = new List<(string Db, IEncounterable[] List)>
        {
            ("wc3", Field<IEncounterable>("EncountersWC3", "Encounter_WC3")),
            ("pcny", Field<IEncounterable>("EncountersWC3", "PCNY")),
            ("pcjp", Field<IEncounterable>("EncountersWC3", "PCJP")),
            ("pcd", EncounterEvent.MGDB_G4),
            ("pgf", EncounterEvent.MGDB_G5),
            ("wc6", EncounterEvent.MGDB_G6),
            ("wc7", EncounterEvent.MGDB_G7),
            ("wb7", EncounterEvent.MGDB_G7GG),
            ("wc8", EncounterEvent.MGDB_G8),
            ("wb8", EncounterEvent.MGDB_G8B),
            ("wa8", EncounterEvent.MGDB_G8A),
            ("wc9", EncounterEvent.MGDB_G9),
            ("wa9", EncounterEvent.MGDB_G9A),
        };
        var path = Path.Combine(outDir, only == null ? "events.jsonl" : $"events_{only}.jsonl");
        using var w = new StreamWriter(path);
        int rows = 0, invalid = 0;
        foreach (var (db, list) in sources)
        {
            if (only != null && db != only) continue;
            int dbRows = 0, dbInvalid = 0;
            for (var i = 0; i < list.Length; i++)
            {
                var g = list[i];
                if (g is MysteryGift mg && !mg.IsEntity) continue;
                JsonObject row;
                try { row = Row(db, i, g); }
                catch (Exception e) { row = new JsonObject { ["db"] = db, ["index"] = i, ["species"] = g.Species, ["err"] = e.GetType().Name + ": " + e.Message }; }
                if (row["tpl"] is null) { invalid++; dbInvalid++; }
                w.WriteLine(row.ToJsonString());
                rows++; dbRows++;
            }
            Console.Error.WriteLine($"{db}: {dbRows} eventos, {dbInvalid} sin plantilla legal");
        }
        Console.WriteLine($"events: {rows} eventos ({invalid} sin plantilla legal) → {path}");
        return 0;
    }

    static SimpleTrainerInfo Trainer(GameVersion v, int lang, bool alt = false) => new(v)
    {
        OT = alt ? "ZETA" : "ARKA",
        TID16 = alt ? (ushort)22222 : (ushort)12345,
        SID16 = alt ? (ushort)33333 : (ushort)54321,
        Gender = alt ? (byte)1 : (byte)0,
        Language = lang,
    };

    static PKM? Make(IEncounterable g, ITrainerInfo tr)
    {
        PKM pk;
        try { pk = ((IEncounterConvertible)g).ConvertToPKM(tr); } catch { return null; }
        Fixup(pk, tr);
        return pk;
    }

    static readonly Random Rng = new(20261124);

    /// Lo que el juego (o HOME) completa al recibir el regalo y `ConvertToPKM` deja a cero
    /// (pkcore aplica lo mismo: fecha de hoy, rastreador de HOME, entrenador actual).
    static void Fixup(PKM pk, ITrainerInfo tr)
    {
        if (pk.Format >= 4 && pk.MetDate is null && !pk.IsEgg)
            pk.MetDate = DateOnly.FromDateTime(DateTime.Now);
        if (pk.IsEgg && !new LegalityAnalysis(pk).Valid && new LegalityAnalysis(pk).Report().Contains("Met Date"))
        {
            var keep = pk.MetDate;
            pk.MetDate = null;
            if (!new LegalityAnalysis(pk).Valid) pk.MetDate = keep;
        }
        if (pk is IHomeTrack h && h.Tracker == 0 && new LegalityAnalysis(pk).Results.Any(r => r.Judgement == Severity.Invalid && r.Identifier == CheckIdentifier.Memory || r.Identifier == CheckIdentifier.Trainer || r.Identifier == CheckIdentifier.Encounter))
        {
            var la = new LegalityAnalysis(pk);
            if (!la.Valid && la.Report().Contains("HOME"))
                h.Tracker = (ulong)Rng.NextInt64(1, long.MaxValue);
        }
        if (pk is IHandlerUpdate && pk.CurrentHandler == 0 && !new LegalityAnalysis(pk).Valid
            && new LegalityAnalysis(pk).Report().Contains("Current handler cannot be the OT"))
        {
            pk.CurrentHandler = 1;
            pk.HandlingTrainerName = tr.OT;
            pk.HandlingTrainerGender = tr.Gender;
            if (pk is IHandlerLanguage hl) hl.HandlingTrainerLanguage = (byte)tr.Language;
        }
        pk.RefreshChecksum();
    }

    static bool Legal(PKM? pk, out string report)
    {
        report = "";
        if (pk is null) { report = "ConvertToPKM falló"; return false; }
        var la = new LegalityAnalysis(pk);
        if (!la.Valid) report = la.Report();
        return la.Valid;
    }

    static GameVersion[] Candidates(IEncounterable g)
    {
        var ctx = g.Context;
        var all = GameUtil.GameVersions.Where(v => v.Context == ctx && v != GameVersion.GO && (int)v <= 52).ToList();
        // La versión propia del regalo primero (p. ej. Rubí para un WC3 de Rubí).
        all.Sort((a, b) => (g.Version.Contains(b) ? 1 : 0) - (g.Version.Contains(a) ? 1 : 0));
        return [.. all];
    }

    static JsonObject Row(string db, int index, IEncounterable g)
    {
        var row = new JsonObject
        {
            ["db"] = db,
            ["index"] = index,
            ["species"] = g.Species,
            ["form"] = g.Form,
            ["level"] = g.LevelMin,
            ["egg"] = g.IsEgg,
            ["shiny"] = g.Shiny.ToString(),
            ["version"] = (int)g.Version,
            ["gen"] = g.Generation,
            ["context"] = g.Context.ToString(),
        };
        if (g is MysteryGift mg)
        {
            row["card"] = mg.CardID;
            row["title"] = mg.CardTitle.Replace('　', ' ').Trim();
            if (mg is DataMysteryGift dm) row["raw"] = Convert.ToBase64String(dm.Data);
            var home = mg.GetType().GetProperty("IsHOMEGift")?.GetValue(mg);
            if (home is true) row["home"] = true;
        }
        if (g is EncounterGift3 g3)
        {
            row["method"] = g3.Method.ToString();
            row["otName"] = g3.OriginalTrainerName;
        }
        if (g is EncounterGift3NY ny) row["method"] = "PCNY " + ny.Distribution;
        if (g is EncounterGift3JPN jp) row["method"] = "PCJP " + jp.Distribution;
        var date = g.GetType().GetProperty("Date")?.GetValue(g);
        if (date is DateOnly d) row["date"] = d.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        if (g is IEncounterServerDate sd && sd.IsDateRestricted)
        {
            DistributionWindow? win = g switch
            {
                WB7 x when x.GetDistributionWindow(out var a) => a,
                WC8 x when x.GetDistributionWindow(out var a) => a,
                WA8 x when x.GetDistributionWindow(out var a) => a,
                WB8 x when x.GetDistributionWindow(out var a) => a,
                WC9 x when x.GetDistributionWindow(out var a) => a,
                WA9 x when x.GetDistributionWindow(out var a) => a,
                _ => null,
            };
            if (win is { } wv)
            {
                row["winStart"] = wv.Start.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                if (wv.End is { } e) row["winEnd"] = e.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                row["winGen"] = wv.GetGenerateDate().ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            }
        }

        // 1) Primera combinación versión/idioma legal (inglés primero).
        var versions = Candidates(g);
        PKM? tpl = null;
        GameVersion tv = 0;
        int tl = 0;
        string firstReport = "";
        foreach (var lang in Languages.OrderBy(l => l == 2 ? 0 : 1))
        {
            foreach (var v in versions)
            {
                var pk = Make(g, Trainer(v, lang));
                if (Legal(pk, out var rep)) { tpl = pk; tv = v; tl = lang; break; }
                if (firstReport.Length == 0) firstReport = rep;
            }
            if (tpl != null) break;
        }
        if (tpl == null)
        {
            row["err"] = firstReport.Length > 400 ? firstReport[..400] : firstReport;
            return row;
        }
        row["tplVersion"] = (int)tv;
        row["tplLang"] = tl;
        row["format"] = tpl.GetType().Name.ToLowerInvariant();
        var stored = new byte[tpl.SIZE_STORED];
        tpl.WriteDecryptedDataStored(stored);
        row["tpl"] = Convert.ToBase64String(stored);

        // 2) Versiones e idiomas aceptados.
        var okVersions = new JsonArray();
        var locByVer = new JsonObject();
        foreach (var v in versions)
        {
            var pv = Make(g, Trainer(v, tl));
            if (!Legal(pv, out _)) continue;
            okVersions.Add((int)v);
            if (pv!.MetLocation != tpl.MetLocation || pv.EggLocation != tpl.EggLocation)
                locByVer[((int)v).ToString()] = $"{pv.MetLocation}|{pv.EggLocation}";
        }
        row["versions"] = okVersions;
        if (locByVer.Count > 0) row["locByVer"] = locByVer;
        var okLangs = new JsonArray();
        var pkLangs = new SortedSet<int>();
        var otByLang = new JsonObject();
        var nickByLang = new JsonObject();
        foreach (var lang in Languages)
        {
            var pk = Make(g, Trainer(tv, lang));
            if (!Legal(pk, out _)) continue;
            okLangs.Add(lang);
            pkLangs.Add(pk!.Language);
            if (pk!.OriginalTrainerName != tpl.OriginalTrainerName) otByLang[lang.ToString()] = pk.OriginalTrainerName;
            if (pk.Nickname != tpl.Nickname || pk.Language != tpl.Language)
                nickByLang[lang.ToString()] = $"{pk.Language}|{(pk.IsNicknamed ? 1 : 0)}|{pk.Nickname}";
        }
        row["langs"] = okLangs;
        row["pkLangs"] = new JsonArray([.. pkLangs.Select(l => (JsonNode)l)]);
        if (otByLang.Count > 0) row["otByLang"] = otByLang;
        if (nickByLang.Count > 0) row["nickByLang"] = nickByLang;

        // 3) Datos que vienen del receptor (comparando dos entrenadores distintos).
        var other = Make(g, Trainer(tv, tl, alt: true));
        if (other != null)
        {
            row["recvOt"] = other.OriginalTrainerName != tpl.OriginalTrainerName;
            row["recvId"] = other.ID32 != tpl.ID32;
            row["recvGender"] = other.OriginalTrainerGender != tpl.OriginalTrainerGender;
            row["recvLang"] = other.Language != tpl.Language;
            row["altLegal"] = Legal(other, out _);
        }
        row["metDate"] = tpl.MetDate?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        row["metToday"] = tpl.MetDate == DateOnly.FromDateTime(DateTime.Now);
        if (tpl.IsEgg) row["eggToday"] = tpl.EggMetDate == DateOnly.FromDateTime(DateTime.Now);

        // 4) Variantes PID/EC/IV/naturaleza/habilidad/género, todas legales.
        var vars = new JsonArray();
        var seen = new HashSet<uint> { tpl.PID };
        for (var k = 0; k < Variants * 3 && vars.Count < Variants; k++)
        {
            var pk = Make(g, Trainer(tv, tl));
            if (pk == null || !seen.Add(pk.PID ^ (uint)pk.IV32_HashOrZero()) || !Legal(pk, out _)) continue;
            vars.Add(Variant(pk));
        }
        row["variants"] = vars;
        return row;
    }

    static int IV32_HashOrZero(this PKM pk) => pk.IV_HP | (pk.IV_ATK << 5) | (pk.IV_DEF << 10) | (pk.IV_SPE << 15) | (pk.IV_SPA << 20) | (pk.IV_SPD << 25);

    /// PID(4) EC(4) IV×6 naturaleza naturaleza-stat nº habilidad género altura peso = 20 bytes.
    static string Variant(PKM pk)
    {
        var b = new byte[20];
        BitConverter.TryWriteBytes(b.AsSpan(0), pk.PID);
        BitConverter.TryWriteBytes(b.AsSpan(4), pk.EncryptionConstant);
        b[8] = (byte)pk.IV_HP; b[9] = (byte)pk.IV_ATK; b[10] = (byte)pk.IV_DEF;
        b[11] = (byte)pk.IV_SPE; b[12] = (byte)pk.IV_SPA; b[13] = (byte)pk.IV_SPD;
        b[14] = (byte)pk.Nature; b[15] = (byte)pk.StatAlignment;
        b[16] = (byte)pk.AbilityNumber; b[17] = pk.Gender;
        if (pk is IScaledSize s) { b[18] = s.HeightScalar; b[19] = s.WeightScalar; }
        return Convert.ToBase64String(b);
    }
}
