// Tablas de la Dex global desde PKHeX (comando `dex <outdir>`):
//   special_forms_oracle.csv  formas Mega/Primigenio/Ultra presentes por juego con su
//                             objeto activador, y especies/formas con Gigamax en SwSh.
//                             La usa `packages/pkcore/test/special_forms_test.dart`.
//   evolutions.csv            evoluciones (método, argumento, nivel) del juego más reciente
//                             que las tenga; la usa tool/gen_evolution_data.py.
using System.Text;
using PKHeX.Core;

static class DexTable
{
    static readonly (string Key, IPersonalTable Table)[] MegaGames =
    [
        ("xy", PersonalTable.XY),
        ("oras", PersonalTable.AO),
        ("sm", PersonalTable.SM),
        ("usum", PersonalTable.USUM),
        ("lgpe", PersonalTable.GG),
        ("za", PersonalTable.ZA),
    ];

    // Del más reciente al más antiguo: el primero con evoluciones para la especie/forma gana.
    static readonly (string Key, IPersonalTable Table, EntityContext Context)[] EvoContexts =
    [
        ("sv", PersonalTable.SV, EntityContext.Gen9),
        ("za", PersonalTable.ZA, EntityContext.Gen9a),
        ("la", PersonalTable.LA, EntityContext.Gen8a),
        ("swsh", PersonalTable.SWSH, EntityContext.Gen8),
        ("bdsp", PersonalTable.BDSP, EntityContext.Gen8b),
        ("usum", PersonalTable.USUM, EntityContext.Gen7),
        ("lgpe", PersonalTable.GG, EntityContext.Gen7b),
        ("oras", PersonalTable.AO, EntityContext.Gen6),
        ("b2w2", PersonalTable.B2W2, EntityContext.Gen5),
        ("hgss", PersonalTable.HGSS, EntityContext.Gen4),
        ("e", PersonalTable.E, EntityContext.Gen3),
        ("c", PersonalTable.C, EntityContext.Gen2),
        ("y", PersonalTable.Y, EntityContext.Gen1),
    ];

    public static int Run(string outDir)
    {
        Directory.CreateDirectory(outDir);
        var sf = new StringBuilder();
        sf.Append("# Generado por tools/pkhex_oracle (dex) desde PKHeX.Core (GPL-3.0).\n");
        sf.Append("# tipo,juego,especie,forma,objeto  (tipo: mega | primal | ultra | gmax)\n");
        foreach (var (key, table) in MegaGames)
        {
            for (ushort species = 1; species <= table.MaxSpeciesID; species++)
            {
                var count = Math.Max((int)table[species, 0].FormCount, 1);
                for (byte form = 1; form < count; form++)
                {
                    if (!table.IsPresentInGame(species, form))
                        continue;
                    string? kind = null;
                    if (FormInfo.IsMegaForm(species, form)) kind = "mega";
                    else if (FormInfo.IsPrimalForm(species, form)) kind = "primal";
                    else if (species == (ushort)Species.Necrozma && form == 3) kind = "ultra";
                    if (kind == null)
                        continue;
                    var item = ItemStorage9ZA.GetExpectedMegaStoneOrPrimalOrb(species, form);
                    sf.Append($"{kind},{key},{species},{form},{item}\n");
                }
            }
        }
        var swsh = PersonalTable.SWSH;
        for (ushort species = 1; species <= swsh.MaxSpeciesID; species++)
        {
            var count = Math.Max((int)swsh[species, 0].FormCount, 1);
            for (byte form = 0; form < count; form++)
            {
                if (!swsh.IsPresentInGame(species, form))
                    continue;
                if (Gigantamax.CanToggle(species, form))
                    sf.Append($"gmax,swsh,{species},{form},0\n");
            }
        }
        File.WriteAllText(Path.Combine(outDir, "special_forms_oracle.csv"), sf.ToString());

        var evo = new StringBuilder();
        evo.Append("# Generado por tools/pkhex_oracle (dex) desde PKHeX.Core (GPL-3.0).\n");
        evo.Append("# especie,forma,juego,destino,formaDestino,metodo,argumento,nivel\n");
        var rows = 0;
        for (ushort species = 1; species <= 1025; species++)
        {
            for (byte form = 0; form < 32; form++)
            {
                foreach (var (key, table, context) in EvoContexts)
                {
                    if (species > table.MaxSpeciesID || !table.IsPresentInGame(species, form))
                        continue;
                    var tree = EvolutionTree.GetEvolutionTree(context);
                    var fw = tree.Forward.GetForward(species, form).Span;
                    var any = false;
                    foreach (var m in fw)
                    {
                        if (m.Species == 0 || m.Method == EvolutionType.None)
                            continue;
                        var dest = m.GetDestinationForm(form);
                        evo.Append($"{species},{form},{key},{m.Species},{dest},{(int)m.Method},{m.Argument},{m.Level}\n");
                        any = true;
                        rows++;
                    }
                    if (any)
                        break;
                }
            }
        }
        File.WriteAllText(Path.Combine(outDir, "evolutions.csv"), evo.ToString());
        Console.WriteLine($"dex: formas especiales y {rows} evoluciones en {outDir}");
        return 0;
    }
}
