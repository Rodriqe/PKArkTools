// Oráculo de transferencias entre juegos (EntityConverter de PKHeX).
//
//   transfer <manifest.json> <out.json>
//
// El manifiesto es una lista de casos:
//   [{ "id": "pk4-pk5-1", "src": "a.pk4", "dest": "pk5", "ours": "a.pk5" }, …]
// Para cada caso carga el origen (formato por extensión), analiza su
// legalidad, lo convierte con EntityConverter.ConvertToType al formato
// destino y analiza la legalidad del resultado de PKHeX y, si se da, la del
// archivo convertido por pkcore ("ours"). La salida usa el mismo volcado por
// Pokémon que `dump` (Program.Mon).
using System.Text.Json;
using System.Text.Json.Nodes;
using PKHeX.Core;

static class TransferOracle
{
    public static int Run(string manifestPath, string outPath)
    {
        // Entrenador fijo para los campos del último entrenador (HT) que pone el conversor.
        RecentTrainerCache.SetRecentTrainer(new SimpleTrainerInfo(GameVersion.SW)
        {
            OT = "ARCA", TID16 = 12345, SID16 = 54321, Gender = 0, Language = (int)LanguageID.English,
        });
        EntityConverter.AllowIncompatibleConversion = EntityCompatibilitySetting.DisallowIncompatible;
        var dir = Path.GetDirectoryName(Path.GetFullPath(manifestPath))!;
        var cases = JsonNode.Parse(File.ReadAllText(manifestPath))!.AsArray();
        var results = new JsonArray();
        foreach (var c in cases)
        {
            var id = c!["id"]!.GetValue<string>();
            var src = Load(Path.Combine(dir, c["src"]!.GetValue<string>()));
            var destType = TypeOf(c["dest"]!.GetValue<string>());
            var item = new JsonObject { ["id"] = id, ["source"] = Program.Mon("src", src, null) };
            var converted = EntityConverter.ConvertToType(src, destType, out var result);
            item["result"] = result.ToString();
            if (converted is not null)
            {
                item["pkhex"] = Program.Mon("pkhex", converted, null);
                if (c["pkhexOut"] is { } po)
                {
                    var buf = new byte[converted.SIZE_PARTY];
                    converted.WriteDecryptedDataParty(buf);
                    File.WriteAllBytes(Path.Combine(dir, po.GetValue<string>()), buf);
                }
            }
            if (c["ours"] is { } ours)
                item["ours"] = Program.Mon("ours", Load(Path.Combine(dir, ours.GetValue<string>())), null);
            results.Add(item);
        }
        File.WriteAllText(outPath, results.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
        return 0;
    }

    static PKM Load(string path)
    {
        var data = File.ReadAllBytes(path);
        var ext = Path.GetExtension(path).TrimStart('.').ToLowerInvariant();
        PKM pk = ext switch
        {
            "pk1" => PokeList1.ReadFromSingle(data),
            "pk2" => PokeList2.ReadFromSingle(data),
            "pk3" => new PK3(data),
            "ck3" => new CK3(data),
            "xk3" => new XK3(data),
            "pk4" => new PK4(data),
            "pk5" => new PK5(data),
            "pk6" => new PK6(data),
            "pk7" => new PK7(data),
            "pb7" => new PB7(data),
            "pk8" => new PK8(data),
            "pb8" => new PB8(data),
            "pa8" => new PA8(data),
            "pk9" => new PK9(data),
            "pa9" => new PA9(data),
            _ => throw new ArgumentException($"extensión desconocida: {ext}"),
        };
        return pk;
    }

    static Type TypeOf(string ext) => ext switch
    {
        "pk1" => typeof(PK1), "pk2" => typeof(PK2), "pk3" => typeof(PK3), "pk4" => typeof(PK4),
        "pk5" => typeof(PK5), "pk6" => typeof(PK6), "pk7" => typeof(PK7), "pb7" => typeof(PB7),
        "pk8" => typeof(PK8), "pb8" => typeof(PB8), "pa8" => typeof(PA8), "pk9" => typeof(PK9),
        "pa9" => typeof(PA9),
        _ => throw new ArgumentException($"formato destino desconocido: {ext}"),
    };
}
