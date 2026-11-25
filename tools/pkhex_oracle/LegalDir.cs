// Legalidad de archivos sueltos (comando `legal <carpeta> [out.jsonl]`): cada
// .pk3 … .pa9 de la carpeta se carga con PKHeX (`EntityFormat.GetFromBytes`,
// con el contexto que indica la extensión) y se pasa por `LegalityAnalysis`.
// Una línea JSON por archivo: archivo, especie, válido, encuentro y avisos.
// Lo usan tool/check_events_pkhex.sh y tool/check_living_dex_pkhex.sh.
using System.Text.Json.Nodes;
using PKHeX.Core;

static class LegalDir
{
    static EntityContext ContextOf(string ext) => ext switch
    {
        ".pk1" => EntityContext.Gen1,
        ".pk2" => EntityContext.Gen2,
        ".pk3" => EntityContext.Gen3,
        ".pk4" => EntityContext.Gen4,
        ".pk5" => EntityContext.Gen5,
        ".pk6" => EntityContext.Gen6,
        ".pk7" => EntityContext.Gen7,
        ".pb7" => EntityContext.Gen7b,
        ".pk8" => EntityContext.Gen8,
        ".pb8" => EntityContext.Gen8b,
        ".pa8" => EntityContext.Gen8a,
        ".pk9" => EntityContext.Gen9,
        ".pa9" => EntityContext.Gen9a,
        _ => EntityContext.None,
    };

    public static int Run(string dir, string? outPath)
    {
        var lines = new List<string>();
        int total = 0, bad = 0;
        foreach (var f in Directory.EnumerateFiles(dir).Order())
        {
            var ctx = ContextOf(Path.GetExtension(f));
            if (ctx == EntityContext.None) continue;
            var pk = EntityFormat.GetFromBytes(File.ReadAllBytes(f), ctx);
            var row = new JsonObject { ["file"] = Path.GetFileName(f) };
            total++;
            if (pk is null)
            {
                row["valid"] = false;
                row["error"] = "PKHeX no reconoce el archivo";
                bad++;
                lines.Add(row.ToJsonString());
                continue;
            }
            var la = new LegalityAnalysis(pk);
            var issues = new JsonArray();
            foreach (var r in la.Results)
            {
                if (r.Judgement == Severity.Valid) continue;
                issues.Add($"{r.Judgement}:{r.Identifier}:{r.Result}");
            }
            for (var i = 0; i < 4; i++)
            {
                if (la.Info.Moves[i] is { IsParsed: true, Valid: false } m) issues.Add($"Invalid:Move{i + 1}:{m.Info.Method}");
                if (la.Info.Relearn[i] is { IsParsed: true, Valid: false } r) issues.Add($"Invalid:Relearn{i + 1}:{r.Info.Method}");
            }
            string enc;
            try { enc = la.EncounterMatch.LongName; } catch { enc = "?"; }
            row["species"] = pk.Species;
            row["form"] = pk.Form;
            row["shiny"] = pk.IsShiny;
            row["valid"] = la.Valid;
            row["encounter"] = enc;
            row["issues"] = issues;
            if (!la.Valid) { bad++; row["report"] = la.Report(); }
            lines.Add(row.ToJsonString());
        }
        if (outPath != null) File.WriteAllLines(outPath, lines); else lines.ForEach(Console.WriteLine);
        Console.Error.WriteLine($"legal: {total} archivos, {bad} inválidos");
        return 0;
    }
}
