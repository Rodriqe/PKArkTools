// Tabla de Pokémon oscuros de Colosseum y XD desde PKHeX (comando `shadows <outdir>`):
//   shadow_oracle.csv  por encuentro oscuro (PKHeX `Encounters3Colo.Shadow` y
//                      `Encounters3XD.Shadow`, sin los de e-Reader): juego, id oscuro,
//                      especie, nivel, lugar, medidor de corazón, Ball fija, amistad base, movimientos y
//                      semillas de origen del RNG de GameCube (XDRNG) cuyo PID/IV pasa los
//                      bloqueos del equipo del entrenador NPC (`LockFinder`).
// Lo usa tool/gen_gc_shadow_data.py para generar la tabla de pkcore con la que se
// crean Pokémon oscuros como los generaría el juego.
//
// Cada semilla se comprueba entera con PKHeX: se crea el Pokémon con
// `ConvertToPKM`, se le ponen el PID, los IV y la habilidad de la semilla y
// `LegalityAnalysis` debe darlo por válido (si no, se descarta).
using System.Globalization;
using System.Reflection;
using System.Text;
using PKHeX.Core;

static class ShadowTable
{
    const int SeedsPerEncounter = 12;
    const uint Mult = 0x000343FD, Add = 0x00269EC3;

    static uint Next(uint s) => unchecked(s * Mult + Add);

    /// (iv1, iv2, bit de habilidad, PID) a partir de la semilla de origen
    /// (origen → IV, IV, habilidad, PID alto, PID bajo), como `MethodCXD.SetRandom`.
    public static (uint Iv1, uint Iv2, uint Ability, uint Pid) Roll(uint origin)
    {
        var s = Next(origin);
        var iv1 = (s >> 16) & 0x7FFF;
        s = Next(s);
        var iv2 = (s >> 16) & 0x7FFF;
        s = Next(s);
        var ab = (s >> 16) & 1;
        s = Next(s);
        var hi = s >> 16;
        s = Next(s);
        var lo = s >> 16;
        return (iv1, iv2, ab, (hi << 16) | lo);
    }

    static T[] Field<T>(string type, string name)
    {
        var t = typeof(EncounterShadow3XD).Assembly.GetType("PKHeX.Core." + type)!;
        return (T[])t.GetField(name, BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic)!.GetValue(null)!;
    }

    public static int Run(string outDir)
    {
        Directory.CreateDirectory(outDir);
        var sb = new StringBuilder("game,index,species,level,location,gauge,ball,friendship,moves,seeds\n");
        var rnd = new Random(20261124);
        var tr = new SimpleTrainerInfo(GameVersion.CXD) { OT = "ARK", TID16 = 12345, SID16 = 54321, Language = (int)LanguageID.English };
        var rows = 0;
        foreach (var e in Field<EncounterShadow3Colo>("Encounters3Colo", "Shadow"))
        {
            if (e.IsEReader) continue;
            var seeds = Seeds(e, e.PartyPrior.Span, xd: false, rnd, tr, () => (e with { PartyPrior = ReadOnlyMemory<TeamLock>.Empty }).ConvertToPKM(tr));
            sb.Append(Row("colo", e.Index, e.Species, e.Level, e.Location, e.Gauge, 0, e.Moves, seeds));
            rows++;
        }
        foreach (var e in Field<EncounterShadow3XD>("Encounters3XD", "Shadow"))
        {
            var seeds = Seeds(e, e.PartyPrior.Span, xd: true, rnd, tr, () => (e with { PartyPrior = ReadOnlyMemory<TeamLock>.Empty }).ConvertToPKM(tr));
            sb.Append(Row("xd", e.Index, e.Species, e.Level, e.Location, e.Gauge, (int)e.FixedBall, e.Moves, seeds));
            rows++;
        }
        File.WriteAllText(Path.Combine(outDir, "shadow_oracle.csv"), sb.ToString());
        Console.WriteLine($"shadows: {rows} encuentros → {outDir}/shadow_oracle.csv");
        return 0;
    }

    static string Row(string game, int index, int species, int level, int location, int gauge, int ball, Moveset m, List<uint> seeds) =>
        string.Create(CultureInfo.InvariantCulture,
            $"{game},{index},{species},{level},{location},{gauge},{ball},{PersonalTable.E[species].BaseFriendship},{m.Move1};{m.Move2};{m.Move3};{m.Move4},{string.Join(';', seeds.Select(s => s.ToString("X8")))}\n");

    static List<uint> Seeds(IShadow3 enc, ReadOnlySpan<TeamLock> teams, bool xd, Random rnd, ITrainerInfo tr, Func<G3PKM> make)
    {
        var list = new List<uint>();
        var tries = 0;
        var fails = 0;
        // Plantilla una sola vez y sin bloqueos (ConvertToPKM con bloqueos busca su propio PID y puede tardar minutos).
        var template = make();
        var clock = System.Diagnostics.Stopwatch.StartNew();
        var locks = enc.PartyPrior;
        var hung = 0;
        while (list.Count < SeedsPerEncounter && tries++ < 20_000_000 && clock.Elapsed.TotalSeconds < 120 && hung < 8)
        {
            var origin = (uint)rnd.NextInt64(0, 1L << 32);
            if (teams.Length != 0)
            {
                // `TeamLockResult` de PKHeX no termina con algunas semillas de XD (repetición
                // anti-variocolor que no avanza): se abandona la semilla tras 300 ms.
                var ok = Timed(() => LockFinder.IsAllShadowLockValid(locks.Span, origin));
                if (ok is null) hung++;
                if (ok != true)
                    continue;
            }
            var (iv1, iv2, ab, pid) = Roll(origin);
            var pk = (G3PKM)template.Clone();
            pk.PID = pid;
            pk.IV_HP = (int)(iv1 & 0x1F); pk.IV_ATK = (int)((iv1 >> 5) & 0x1F); pk.IV_DEF = (int)((iv1 >> 10) & 0x1F);
            pk.IV_SPE = (int)(iv2 & 0x1F); pk.IV_SPA = (int)((iv2 >> 5) & 0x1F); pk.IV_SPD = (int)((iv2 >> 10) & 0x1F);
            pk.RefreshAbility((int)ab); // bit de habilidad solo si la especie tiene dos
            if (xd && pk.IsShiny) continue;
            pk.ResetPartyStats();
            pk.RefreshChecksum();
            LegalityAnalysis? la = null;
            var valid = Timed(() => (la = new LegalityAnalysis(pk)).Valid);
            if (valid is null) { hung++; continue; }
            if (valid == false)
            {
                if (fails++ == 0)
                    Console.Error.WriteLine($"{(xd ? "XD" : "Colo")} #{pk.Species}: {la!.Report()}");
                if (fails > 200)
                    break;
                continue;
            }
            list.Add(origin);
        }
        Console.Error.WriteLine($"{(xd ? "XD" : "Colo")} {((IEncounterable)enc).Name}: {list.Count} semillas en {tries} intentos, {fails} rechazadas por PKHeX, {hung} colgadas");
        return list;
    }

    /// Resultado de [f], o null si no termina en 300 ms (el hilo se abandona).
    static bool? Timed(Func<bool> f)
    {
        var t = Task.Factory.StartNew(f, CancellationToken.None, TaskCreationOptions.LongRunning, TaskScheduler.Default);
        return t.Wait(300) ? t.Result : null;
    }
}
