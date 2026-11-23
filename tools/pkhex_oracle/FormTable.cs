// Tabla (especie, forma, juego) desde PKHeX: tipos, stats base, habilidades,
// género, preevolución y nombres de forma. La usan tool/gen_form_data.py (nombres
// de forma) y el test de pkcore `form_data_pkhex_test.dart` (tabla versionada).
using System.Text;
using System.Text.Json;
using PKHeX.Core;

static class FormTable
{
    // Clave de tabla de pkcore (GameDataTable.key) → tabla personal y contexto de PKHeX.
    static readonly (string Key, IPersonalTable Table, EntityContext Context)[] Games =
    [
        ("rs", PersonalTable.RS, EntityContext.Gen3),
        ("e", PersonalTable.E, EntityContext.Gen3),
        ("fr", PersonalTable.FR, EntityContext.Gen3),
        ("dp", PersonalTable.DP, EntityContext.Gen4),
        ("pt", PersonalTable.Pt, EntityContext.Gen4),
        ("hgss", PersonalTable.HGSS, EntityContext.Gen4),
        ("bw", PersonalTable.BW, EntityContext.Gen5),
        ("b2w2", PersonalTable.B2W2, EntityContext.Gen5),
        ("xy", PersonalTable.XY, EntityContext.Gen6),
        ("ao", PersonalTable.AO, EntityContext.Gen6),
        ("sm", PersonalTable.SM, EntityContext.Gen7),
        ("uu", PersonalTable.USUM, EntityContext.Gen7),
        ("gg", PersonalTable.GG, EntityContext.Gen7b),
        ("swsh", PersonalTable.SWSH, EntityContext.Gen8),
        ("bdsp", PersonalTable.BDSP, EntityContext.Gen8b),
        ("la", PersonalTable.LA, EntityContext.Gen8a),
        ("sv", PersonalTable.SV, EntityContext.Gen9),
        ("za", PersonalTable.ZA, EntityContext.Gen9a),
    ];

    public static int Run(string outDir)
    {
        Directory.CreateDirectory(outDir);
        var csv = new StringBuilder();
        csv.Append("# Generado por tools/pkhex_oracle (forms) desde PKHeX.Core (GPL-3.0).\n");
        csv.Append("# juego,especie,forma,tipo1,tipo2,ps,atq,def,atqesp,defesp,vel,hab1,hab2,habO,genero,preevolucion\n");
        var en = GameInfo.GetStrings("en");
        var es = GameInfo.GetStrings("es");
        var names = new SortedDictionary<string, SortedDictionary<int, string[][]>>();
        var presence = new StringBuilder("# juego,especie,formas,mascara de formas presentes\n");
        var rows = 0;
        foreach (var (key, table, context) in Games)
        {
            var tree = EvolutionTree.GetEvolutionTree(context);
            var ctxNames = names.TryGetValue(context.ToString(), out var n) ? n : names[context.ToString()] = new();
            for (ushort species = 1; species <= table.MaxSpeciesID; species++)
            {
                var baseInfo = table[species, 0];
                var count = Math.Max((int)baseInfo.FormCount, 1);
                if (count > 1 || species is (ushort)Species.Unown or (ushort)Species.Castform or (ushort)Species.Deoxys)
                {
                    var listEn = FormConverter.GetFormList(species, en.Types, en.forms, GameInfo.GenderSymbolUnicode, context);
                    var listEs = FormConverter.GetFormList(species, es.Types, es.forms, GameInfo.GenderSymbolUnicode, context);
                    if (listEn.Length > 1)
                        ctxNames[species] = [listEn, listEs];
                }
                long mask = 0;
                for (byte form = 0; form < Math.Max(count, 32); form++)
                {
                    if (!table.IsPresentInGame(species, form))
                        continue;
                    mask |= 1L << form;
                    var p = table[species, form];
                    // GetPreEvolutions va de la base hacia arriba: la última es la inmediata.
                    var pre = tree.Reverse.GetPreEvolutions(species, form).LastOrDefault();
                    var ab = new int[3];
                    for (var i = 0; i < p.AbilityCount && i < 3; i++)
                        ab[i] = p.GetAbilityAtIndex(i);
                    csv.Append($"{key},{species},{form},{p.Type1},{p.Type2},{p.HP},{p.ATK},{p.DEF},{p.SPA},{p.SPD},{p.SPE},");
                    csv.Append($"{ab[0]},{ab[1]},{ab[2]},{p.Gender},");
                    csv.Append(pre.Species == 0 ? "" : $"{pre.Species}-{pre.Form}");
                    csv.Append('\n');
                    rows++;
                }
                presence.Append($"{key},{species},{count},{mask}\n");
            }
        }
        File.WriteAllText(Path.Combine(outDir, "form_oracle.csv"), csv.ToString());
        File.WriteAllText(Path.Combine(outDir, "form_presence.csv"), presence.ToString());
        var opts = new JsonSerializerOptions { WriteIndented = false, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping };
        File.WriteAllText(Path.Combine(outDir, "form_names.json"), JsonSerializer.Serialize(names, opts));
        Console.WriteLine($"forms: {rows} filas (especie, forma, juego) en {outDir}");
        return 0;
    }
}
