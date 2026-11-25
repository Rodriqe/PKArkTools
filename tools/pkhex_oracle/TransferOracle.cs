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

// Tablas para el conversor de pkcore (packages/pkcore/lib/src/data/generated/transfer_data.dart).
//   transfertables <out.dart>
static class TransferTables
{
    static readonly int[] Languages = [1, 2, 3, 4, 5, 7, 8, 9, 10];

    public static int Run(string outPath)
    {
        var sb = new System.Text.StringBuilder();
        sb.AppendLine("// GENERADO por tools/pkhex_oracle (transfertables) desde PKHeX.Core. No editar a mano.");
        sb.AppendLine("// ignore_for_file: lines_longer_than_80_chars");
        sb.AppendLine();
        Names(sb, "kTransferNamesG4", 493, (s, l) => SpeciesName.GetSpeciesNameGeneration(s, l, 4));
        Names(sb, "kTransferNamesG6", 721, (s, l) => SpeciesName.GetSpeciesNameGeneration(s, l, 6));
        Names(sb, "kTransferNamesG7", 809, (s, l) => SpeciesName.GetSpeciesNameGeneration(s, l, 7));
        Names(sb, "kTransferNamesHome", 1025, (s, l) => SpeciesName.GetSpeciesNameImportHOME(s, l, 8));
        Ints(sb, "kBaseFriendshipSM", Enumerable.Range(0, 810).Select(s => (int)PersonalTable.USUM[(ushort)Math.Min(s, 807)].BaseFriendship));
        Ints(sb, "kItem3to4", Enumerable.Range(0, 377).Select(i => (int)ItemConverter.GetItemFuture3((ushort)i)));
        Ints(sb, "kItemFuture1", Enumerable.Range(0, 256).Select(i => (int)ItemConverter.GetItemFuture1((byte)i)));
        Ints(sb, "kHeldItemsBW", ItemStorage5.GetAllHeld().Select(i => (int)i));
        // Leyendas Arceus: altura y peso base por especie/forma (PA8.HeightAbsolute/WeightAbsolute).
        var la = new List<string>();
        for (ushort sp = 1; sp <= PersonalTable.LA.MaxSpeciesID; sp++)
        {
            var baseInfo = PersonalTable.LA[sp];
            for (byte f = 0; f < Math.Max((byte)1, baseInfo.FormCount); f++)
            {
                if (!PersonalTable.LA.IsPresentInGame(sp, f)) continue;
                var pi = PersonalTable.LA.GetFormEntry(sp, f);
                la.Add($"{sp},{f},{pi.Height},{pi.Weight}");
            }
        }
        sb.AppendLine("/// Leyendas Arceus: «especie,forma,altura,peso» de cada forma presente.");
        sb.AppendLine($"const String kLaHeightWeight = '{string.Join(";", la)}';");
        File.WriteAllText(outPath, sb.ToString());
        return 0;
    }

    static void Names(System.Text.StringBuilder sb, string name, int max, Func<ushort, int, string> get)
    {
        sb.AppendLine($"/// Nombres de especie (0‥{max}) por idioma (id de PKHeX), separados por «|».");
        sb.AppendLine($"const Map<int, String> {name} = <int, String>{{");
        foreach (var l in Languages)
        {
            var names = Enumerable.Range(0, max + 1).Select(s => get((ushort)s, l));
            var joined = string.Join("|", names).Replace("\\", "\\\\").Replace("'", "\\'").Replace("$", "\\$");
            sb.AppendLine($"  {l}: '{joined}',");
        }
        sb.AppendLine("};");
        sb.AppendLine();
    }

    static void Ints(System.Text.StringBuilder sb, string name, IEnumerable<int> values)
    {
        sb.AppendLine($"const List<int> {name} = <int>[{string.Join(",", values)}];");
        sb.AppendLine();
    }
}

// Orígenes legales para los casos de transferencia de pkcore.
//   transfersrc <cases.json> <outdir>
// cases.json: [{ "id", "version" (GameVersion de PKHeX, p. ej. "E"), "species", "form", "ext" }]
// Para cada caso busca un encuentro (salvaje o estático, sin regalos ni huevos)
// de esa especie en ese juego, lo convierte con el entrenador «ASH» y guarda
// el primero que PKHeX da por legal como <id>.src.<ext>.
static class TransferSources
{
    public static int Run(string casesPath, string outDir)
    {
        Directory.CreateDirectory(outDir);
        var cases = JsonNode.Parse(File.ReadAllText(casesPath))!.AsArray();
        var failed = 0;
        foreach (var c in cases)
        {
            var id = c!["id"]!.GetValue<string>();
            var version = Enum.Parse<GameVersion>(c["version"]!.GetValue<string>());
            var species = c["species"]!.GetValue<ushort>();
            var form = c["form"]?.GetValue<byte>() ?? 0;
            var ext = c["ext"]!.GetValue<string>();
            var tr = new SimpleTrainerInfo(version)
            {
                OT = "ASH", TID16 = 24680, SID16 = 13579, Gender = 0, Language = (int)LanguageID.English,
            };
            var blank = EntityBlank.GetBlank(TypeOf(ext));
            blank.Species = species;
            blank.Form = form;
            PKM? found = null;
            foreach (var enc in EncounterMovesetGenerator.GenerateEncounters(blank, tr, ReadOnlyMemory<ushort>.Empty, version))
            {
                if (enc is MysteryGift || enc.IsEgg || enc.Species != species || enc.Form != form) continue;
                var pk = enc.ConvertToPKM(tr);
                if (pk.GetType() != blank.GetType()) continue;
                if (!new LegalityAnalysis(pk).Valid) continue;
                found = pk;
                break;
            }
            if (found is null)
            {
                Console.Error.WriteLine($"{id}: sin encuentro legal de {species}-{form} en {version}");
                failed++;
                continue;
            }
            File.WriteAllBytes(Path.Combine(outDir, $"{id}.src.{ext}"), Bytes(found));
        }
        return failed == 0 ? 0 : 1;
    }

    static byte[] Bytes(PKM pk)
    {
        if (pk is PK1 pk1)
        {
            var buf = new byte[PokeList1.GetListLengthSingle(pk1.Japanese)];
            PokeList1.WriteToList(buf, pk1);
            return buf;
        }
        if (pk is PK2 pk2)
        {
            var buf = new byte[PokeList2.GetListLengthSingle(pk2.Japanese)];
            PokeList2.WriteToList(buf, pk2);
            return buf;
        }
        var data = new byte[pk.SIZE_PARTY];
        pk.WriteDecryptedDataParty(data);
        return data;
    }

    static Type TypeOf(string ext) => ext switch
    {
        "pk1" => typeof(PK1), "pk2" => typeof(PK2), "pk3" => typeof(PK3), "pk4" => typeof(PK4),
        "pk5" => typeof(PK5), "pk6" => typeof(PK6), "pk7" => typeof(PK7), "pb7" => typeof(PB7),
        "pk8" => typeof(PK8), "pb8" => typeof(PB8), "pa8" => typeof(PA8), "pk9" => typeof(PK9),
        "pa9" => typeof(PA9),
        _ => throw new ArgumentException(ext),
    };
}
