# Oráculo PKHeX

Consola C# que carga un save con [PKHeX.Core](https://github.com/kwsch/PKHeX)
(GPL-3.0) y lo vuelca a JSON con el mismo esquema que
`packages/pkcore/tool/pkhex_dump.dart`, para comparar lectura y legalidad
campo por campo con pkcore.

PKHeX no se versiona aquí: el proyecto lo referencia en `.ref/PKHeX`.

```bash
git clone https://github.com/kwsch/PKHeX .ref/PKHeX   # una vez
tool/compare_with_pkhex.sh <save> [--legality-detail]
```

Requiere .NET SDK 10. El script fija `NUGET_PACKAGES`, `DOTNET_CLI_HOME` y
`TMPDIR` dentro del workspace y escribe los JSON en `.scratch/compare/` (los de
saves reales contienen datos personales: no se versionan).

Comandos de la consola (`dotnet <bin>/PkhexOracle.dll …`):

- `dump <save> [out.json]`: entrenador, equipo y cajas (todos los campos),
  inventario, Pokédex y el veredicto de `LegalityAnalysis` con cada aviso.
- `roundtrip <save>`: carga y reescribe sin cambios; cuenta bytes distintos.
  Ojo: con Colosseum/XD PKHeX descifra el archivo de entrada en memoria, así
  que el recuento sale alto aunque el resultado sea idéntico; usa `write`.
- `write <in> <out>`: carga y escribe sin cambios (para comparar con `cmp`).
- Las imágenes de Memory Card de GameCube se abren como en PKHeX.WinForms
  (`SAV3GCMemoryCard`), si tienen un solo save de Pokémon.
- `edit <in> <out>`: edición simple (dinero y primer Pokémon de la caja 1) para
  el round-trip cruzado con `pkhex_dump.dart --edit`.
- `forms <dir>`: tabla (juego, especie, forma) de todos los juegos de Gen 3–9
  (tipos, stats base, habilidades, género, preevolución), formas presentes y
  nombres de forma. La usa `tool/gen_form_data.sh`, que regenera
  `packages/pkcore/lib/src/data/generated/form_names.dart` y la tabla
  versionada `packages/pkcore/test/data/form_oracle.csv.gz` del test
  `form_data_pkhex_test.dart` (no necesita PKHeX para ejecutarse).
- `shadows <dir>`: encuentros oscuros de Colosseum y XD (`shadow_oracle.csv`:
  id oscuro, especie, nivel, lugar, medidor, Ball fija, amistad base,
  movimientos y semillas de origen del RNG de GameCube cuyo PID/IV pasa los
  bloqueos del equipo del entrenador y `LegalityAnalysis`). La usa
  `tool/gen_gc_shadow_data.sh`, que regenera
  `packages/pkcore/lib/src/data/generated/gc_shadow_data.dart` (crear Pokémon
  oscuros como los genera el juego).
