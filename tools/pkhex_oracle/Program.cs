// Oráculo PKHeX para PKArkTools.
//
//   dump <save> [out.json]        vuelca el save a JSON (esquema común con tool/pkhex_dump.dart)
//   roundtrip <save>              carga y vuelve a escribir sin cambios; cuenta bytes distintos
//   edit <in> <out>               edición simple (dinero, nivel/movimiento del primer Pokémon de caja)
//   forms <outdir>                tabla (especie, forma, juego) y nombres de forma (FormTable.cs)
//
// Los volcados de saves reales contienen datos personales: guárdalos en .scratch/.
using System.Text.Json;
using System.Text.Json.Nodes;
using PKHeX.Core;

static class Program
{
    static int Main(string[] args)
    {
        if (args.Length == 2 && args[0] == "forms")
            return FormTable.Run(args[1]);
        if (args.Length < 2)
        {
            Console.Error.WriteLine("uso: dump <save> [out.json] | roundtrip <save> | edit <in> <out> | forms <outdir>");
            return 2;
        }
        var data = File.ReadAllBytes(args[1]);
        if (!SaveUtil.TryGetSaveFile(data, out var sav, args[1]))
        {
            Console.Error.WriteLine($"PKHeX no reconoce el save: {args[1]}");
            return 1;
        }
        switch (args[0])
        {
            case "dump":
                var json = Dump(sav).ToJsonString(new JsonSerializerOptions { WriteIndented = true });
                if (args.Length > 2) File.WriteAllText(args[2], json); else Console.WriteLine(json);
                return 0;
            case "roundtrip":
                var output = sav.Write().ToArray();
                var diff = 0;
                for (var i = 0; i < Math.Min(output.Length, data.Length); i++)
                    if (output[i] != data[i]) diff++;
                Console.WriteLine($"PKHeX round-trip: {output.Length} vs {data.Length} bytes, distintos={diff}");
                return 0;
            case "edit":
                sav.Money = 123456;
                var box = sav.GetBoxData(0);
                var idx = Array.FindIndex(box, p => p.Species != 0);
                var pk = box[idx];
                pk.CurrentLevel = (byte)Math.Min(100, pk.CurrentLevel + 1);
                pk.Move4 = (ushort)Move.Tackle;
                pk.Move4_PP = pk.GetMovePP(pk.Move4, pk.Move4_PPUps);
                pk.RefreshChecksum();
                sav.SetBoxSlotAtIndex(pk, 0, idx);
                File.WriteAllBytes(args[2], sav.Write().ToArray());
                Console.WriteLine($"PKHeX edit: dinero=123456, caja 1 hueco {idx}: nivel {pk.CurrentLevel}, mov4=Placaje");
                return 0;
        }
        return 2;
    }

    static JsonObject Dump(SaveFile sav)
    {
        var root = new JsonObject
        {
            ["source"] = "pkhex",
            ["game"] = sav.Version.ToString(),
            ["checksumsValid"] = sav.ChecksumsValid,
            ["checksumInfo"] = sav.ChecksumInfo,
            ["trainer"] = new JsonObject
            {
                ["name"] = sav.OT,
                ["tid16"] = sav.TID16,
                ["sid16"] = sav.SID16,
                ["money"] = sav.Money,
                ["playTime"] = $"{sav.PlayedHours}:{sav.PlayedMinutes:00}:{sav.PlayedSeconds:00}",
                ["badges"] = Badges(sav),
            },
        };
        var slots = new JsonArray();
        var party = sav.PartyData;
        for (var i = 0; i < sav.PartyCount; i++)
            slots.Add(Mon($"party:{i}", party[i], sav));
        for (var b = 0; b < sav.BoxCount; b++)
        {
            var box = sav.GetBoxData(b);
            for (var s = 0; s < box.Length; s++)
                if (box[s].Species != 0)
                    slots.Add(Mon($"box:{b}:{s}", box[s], sav));
        }
        root["slots"] = slots;

        var items = new SortedDictionary<int, int>();
        foreach (var pouch in sav.Inventory.Pouches)
            foreach (var it in pouch.Items)
                if (it.Index != 0 && it.Count > 0)
                    items[it.Index] = items.GetValueOrDefault(it.Index) + it.Count;
        var inv = new JsonObject();
        foreach (var (k, v) in items) inv[k.ToString()] = v;
        root["items"] = inv;

        var seen = new JsonArray();
        var caught = new JsonArray();
        for (ushort sp = 1; sp <= sav.MaxSpeciesID; sp++)
        {
            if (sav.GetSeen(sp)) seen.Add(sp);
            if (sav.GetCaught(sp)) caught.Add(sp);
        }
        root["pokedex"] = new JsonObject { ["seen"] = seen, ["caught"] = caught };
        return root;
    }

    static JsonNode? Badges(SaveFile sav)
    {
        var p = sav.GetType().GetProperty("Badges");
        return p?.GetValue(sav) is { } v ? JsonValue.Create(Convert.ToInt32(v)) : null;
    }

    static JsonArray Arr(params int[] v)
    {
        var a = new JsonArray();
        foreach (var x in v) a.Add(x);
        return a;
    }

    static JsonObject Mon(string slot, PKM pk, SaveFile sav)
    {
        var la = new LegalityAnalysis(pk);
        var issues = new JsonArray();
        foreach (var r in la.Results)
        {
            if (r.Judgement == Severity.Valid) continue;
            issues.Add(new JsonObject
            {
                ["id"] = r.Identifier.ToString(),
                ["code"] = r.Result.ToString(),
                ["severity"] = r.Judgement.ToString(),
            });
        }
        for (var i = 0; i < 4; i++)
        {
            if (la.Info.Moves[i] is { IsParsed: true, Valid: false } m)
                issues.Add(new JsonObject { ["id"] = $"Move{i + 1}", ["code"] = m.Info.Method.ToString(), ["severity"] = "Invalid" });
            if (la.Info.Relearn[i] is { IsParsed: true, Valid: false } r)
                issues.Add(new JsonObject { ["id"] = $"RelearnMove{i + 1}", ["code"] = r.Info.Method.ToString(), ["severity"] = "Invalid" });
        }
        string encounter;
        try { encounter = la.EncounterMatch.LongName; } catch { encounter = "?"; }
        return new JsonObject
        {
            ["slot"] = slot,
            ["species"] = pk.Species,
            ["form"] = pk.Form,
            ["nickname"] = pk.Nickname,
            ["isNicknamed"] = pk.IsNicknamed,
            ["level"] = pk.CurrentLevel,
            ["exp"] = pk.EXP,
            ["pid"] = pk.PID,
            ["ec"] = pk.EncryptionConstant,
            ["nature"] = (int)pk.Nature,
            ["statNature"] = (int)pk.StatAlignment,
            ["ability"] = pk.Ability,
            ["heldItem"] = pk.HeldItem,
            ["moves"] = Arr(pk.Move1, pk.Move2, pk.Move3, pk.Move4),
            ["pp"] = Arr(pk.Move1_PP, pk.Move2_PP, pk.Move3_PP, pk.Move4_PP),
            ["ppUps"] = Arr(pk.Move1_PPUps, pk.Move2_PPUps, pk.Move3_PPUps, pk.Move4_PPUps),
            ["relearn"] = Arr(pk.RelearnMove1, pk.RelearnMove2, pk.RelearnMove3, pk.RelearnMove4),
            ["ivs"] = Arr(pk.IV_HP, pk.IV_ATK, pk.IV_DEF, pk.IV_SPA, pk.IV_SPD, pk.IV_SPE),
            ["evs"] = Arr(pk.EV_HP, pk.EV_ATK, pk.EV_DEF, pk.EV_SPA, pk.EV_SPD, pk.EV_SPE),
            ["shiny"] = pk.IsShiny,
            ["isEgg"] = pk.IsEgg,
            ["ball"] = pk.Ball,
            ["ot"] = pk.OriginalTrainerName,
            ["tid16"] = pk.TID16,
            ["sid16"] = pk.SID16,
            ["metLocation"] = pk.MetLocation,
            ["metLevel"] = pk.MetLevel,
            ["version"] = (int)pk.Version,
            ["fateful"] = pk.FatefulEncounter,
            ["checksumValid"] = pk.ChecksumValid,
            ["legality"] = new JsonObject
            {
                ["valid"] = la.Valid,
                ["encounter"] = encounter,
                ["issues"] = issues,
            },
        };
    }
}
