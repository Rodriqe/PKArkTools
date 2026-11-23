#!/usr/bin/env bash
# Monta el vídeo de demostración a partir de las tomas del emulador.
#
#   tool/record_demo_video.sh en && tool/record_demo_video.sh es   # tomas
#   tool/make_demo_video.sh                                        # montaje
#
# Entradas (.scratch/video/takes/): demo_<lang>.mp4 y demo_<lang>.scenes, que
# deja tool/record_demo_video.sh. Cada escena se recorta respecto a sus marcas
# de tiempo, se acelera un poco y se encaja en un marco de teléfono sobre el
# fondo oscuro de la marca, con un rótulo breve; entre escenas, fundidos.
#
# Salidas:
#   docs/media/pkarktools-demo.mp4    inglés, 1920×1080 (repo, ≤ 10 MB)
#   docs/media/pkarktools-demo.webp   inglés, 600 px, ~12 s (vista previa del README)
#   .scratch/video/fb/pkarktools-demo-es-vertical.mp4   español, 1080×1920 (Reels/historias)
#   .scratch/video/fb/pkarktools-demo-es-cuadrado.mp4   español, 1080×1080 (feed)
#
# Herramientas, dentro del workspace: ffmpeg estático en .ref/ffmpeg/bin (con
# libx264, libfreetype y libwebp) y Manrope (OFL) en .ref/fonts/Manrope-{500,700,800}.ttf
# (instancias estáticas de Google Fonts). Variables: FFMPEG, FFPROBE, FONTS.
# Sin música: pista AAC en silencio. Sin metadatos (-map_metadata -1).
set -euo pipefail
cd "$(dirname "$0")/.."
WS="$PWD"
FFMPEG="${FFMPEG:-$WS/.ref/ffmpeg/bin/ffmpeg}"
FFPROBE="${FFPROBE:-$WS/.ref/ffmpeg/bin/ffprobe}"
FONTS="${FONTS:-$WS/.ref/fonts}"
TAKES="$WS/.scratch/video/takes"
WORK="$WS/.scratch/video/work"
FB="$WS/.scratch/video/fb"
MEDIA="$WS/docs/media"
LOGO="$WS/apps/pkarktools/assets/branding/logo.png"
for f in "$FFMPEG" "$FFPROBE" "$FONTS/Manrope-700.ttf" "$FONTS/Manrope-500.ttf" "$FONTS/Manrope-800.ttf" "$LOGO"; do
  [ -e "$f" ] || { echo "falta $f (ver cabecera)" >&2; exit 1; }
done
mkdir -p "$WORK" "$FB" "$MEDIA"
cp "$FONTS"/Manrope-{500,700,800}.ttf "$WORK/"
cp "$LOGO" "$WORK/logo.png"
cd "$WORK"

ff() { "$FFMPEG" -hide_banner -loglevel error -y "$@"; }
dur() { "$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$1"; }
# Partir un texto en líneas de como mucho N caracteres.
wrap() { python3 -I -c 'import sys,textwrap; print("\n".join(textwrap.wrap(sys.argv[1], int(sys.argv[2]))))' "$1" "$2"; }

BG_TOP=0x1D2236   # tokens.raised
BG_BOTTOM=0x0C0E17
BEZEL=0x2C3352
ACCENT=0xF2C14E   # primary
MUTED=0x9AA1BD    # tokens.muted
XF=0.4            # fundido entre escenas (s)
REPO_URL="github.com/Rodriqe/PKArkTools"

# Escenas: nombre, desde (s tras su marca), hasta (s respecto a la marca
# siguiente; negativo = antes), velocidad.
SCENES=(
  "welcome  1.00 -0.10 1.00"
  "arca     0.90 -0.05 1.25"
  "filters  0.00 -1.00 1.30"
  "save     0.00  0.00 1.25"
  "editor   0.00  0.00 1.60"
  "origin   0.00  0.00 1.40"
  "legality 0.00  0.00 1.30"
  "save_arca 0.00 0.00 1.50"
  "compare  0.00  0.00 1.15"
)

caption() { # $1 = lang, $2 = escena
  case "$1:$2" in
    en:welcome) echo "Your saves, safe in your own folder" ;;
    en:arca) echo "Every save in one Ark, colored by version" ;;
    en:filters) echo "Filter by console, game or play time" ;;
    en:save) echo "Party and boxes, with icons" ;;
    en:editor) echo "Edit level, shiny and moves" ;;
    en:origin) echo "Origin, ribbons and marks" ;;
    en:legality) echo "Legality warnings, with safe fixes" ;;
    en:save_arca) echo "Save a new copy to the Ark" ;;
    en:compare) echo "Compare any two copies" ;;
    es:welcome) echo "Tus partidas, a salvo en tu propia carpeta" ;;
    es:arca) echo "Todas tus partidas en un Arca, con el color de cada versión" ;;
    es:filters) echo "Filtra por consola, juego u horas de juego" ;;
    es:save) echo "Equipo y cajas, con iconos" ;;
    es:editor) echo "Edita nivel, variocolor y movimientos" ;;
    es:origin) echo "Origen, cintas y marcas" ;;
    es:legality) echo "Avisos de legalidad y corrección segura" ;;
    es:save_arca) echo "Guarda una copia nueva en el Arca" ;;
    es:compare) echo "Compara dos copias cuando quieras" ;;
  esac
}
tagline() { [ "$1" = es ] && echo "Copias versionadas, lector y editor de tus partidas guardadas" || echo "Versioned backups, a reader and an editor for your game saves"; }
freeline() { [ "$1" = es ] && echo "Libre y de código abierto" || echo "Free & open source"; }

# Tiempo de una marca en el archivo .scenes.
mark() { awk -v n="$2" '$2 == n { print $1 }' "$TAKES/demo_$1.scenes"; }
next_mark() { # marca que sigue a la escena $2
  awk -v n="$2" 'f { print $1; exit } $2 == n { f = 1 }' "$TAKES/demo_$1.scenes"
}

# Una línea de texto (drawtext con archivo, sin problemas de comillas).
# $1 = id, $2 = texto, $3 = fuente, $4 = tamaño, $5 = color, $6 = x, $7 = y, $8 = inicio del fundido
# (Se llama dentro de $(…): el nombre del archivo sale del propio texto.)
dt() {
  local t; t="t_$(printf '%s' "$2" | shasum | cut -c1-12).txt"
  printf '%s' "$2" > "$t"
  printf "drawtext=textfile=%s:fontfile=%s:fontsize=%s:fontcolor=%s:x=%s:y=%s:alpha='if(lt(t,%s),0,min(1,(t-%s)/0.35))'" \
    "$t" "$3" "$4" "$5" "$6" "$7" "$8" "$8"
}

# Composición. $1 = layout (vertical | square | horizontal).
layout() {
  case "$1" in
    vertical) W=1080 H=1920 PH=1540 PX=-1 PY=330 ;;
    square) W=1080 H=1080 PH=1000 PX=570 PY=40 ;;
    horizontal) W=1920 H=1080 PH=1000 PX=1080 PY=40 ;;
  esac
  PW=$(((PH * 1080 / 2400) / 2 * 2))
  [ "$PX" = -1 ] && PX=$(((W - PW) / 2))
  R=$((PW * 9 / 100))
  B=6
}

assets() { # fondo, bisel y máscara del teléfono para el layout actual
  ff -f lavfi -i "gradients=s=${W}x${H}:c0=$BG_TOP:c1=$BG_BOTTOM:x0=0:y0=0:x1=$((W / 3)):y1=$H:speed=0:nb_colors=2" -frames:v 1 "bg_$1.png"
  local bw=$((PW + 2 * B)) bh=$((PH + 2 * B)) br=$((R + B))
  ff -f lavfi -i "color=c=$BEZEL:s=${bw}x${bh},format=rgba" -vf \
    "geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='255*clip($br+0.5-hypot(max(max($br-X,X-(W-1-$br)),0),max(max($br-Y,Y-(H-1-$br)),0)),0,1)'" \
    -frames:v 1 "bezel_$1.png"
  # Máscara de la pantalla: blanco dentro del rectángulo redondeado.
  ff -f lavfi -i "color=c=black:s=${PW}x${PH},format=gray" -vf \
    "geq=lum='255*clip($R+0.5-hypot(max(max($R-X,X-(W-1-$R)),0),max(max($R-Y,Y-(H-1-$R)),0)),0,1)'" \
    -frames:v 1 "mask_$1.png"
}

# Rótulos de una escena según el layout. Imprime la cadena de filtros.
captions() { # $1 = lang, $2 = texto
  local f="" i=0 line lines
  case "$LAYOUT" in
    vertical)
      lines=$(wrap "$2" 26)
      local n; n=$(printf '%s\n' "$lines" | wc -l | tr -d ' ')
      local y0=$(((PY - n * 74) / 2 + 6))
      while IFS= read -r line; do
        f+=",$(dt c "$line" Manrope-800.ttf 62 white '(w-text_w)/2' $((y0 + i * 74)) 0.15)"
        i=$((i + 1))
      done <<< "$lines"
      ;;
    *)
      local size=60 lh=74 left=80 chars=15
      [ "$LAYOUT" = horizontal ] && { size=72 lh=90 left=250 chars=18; }
      lines=$(wrap "$2" $chars)
      local n; n=$(printf '%s\n' "$lines" | wc -l | tr -d ' ')
      local y0=$(((H - n * lh) / 2))
      f+=",drawbox=x=$left:y=$((y0 - 40)):w=64:h=8:color=$ACCENT:t=fill"
      while IFS= read -r line; do
        f+=",$(dt c "$line" Manrope-800.ttf $size white $left $((y0 + i * lh)) 0.15)"
        i=$((i + 1))
      done <<< "$lines"
      ;;
  esac
  printf '%s' "$f"
}

# Marca pequeña (logo + nombre) en los layouts con columna de texto.
brand_inputs() { [ "$LAYOUT" = vertical ] || printf '%s' "-loop 1 -i logo.png"; }
brand_filter() { # $1 = etiqueta de entrada, $2 = índice del logo
  if [ "$LAYOUT" = vertical ]; then printf '[%s]null' "$1"; return; fi
  local left=80 top=60 s=64
  [ "$LAYOUT" = horizontal ] && { left=250; top=80; s=72; }
  printf '[%s:v]scale=%s:%s[lg];[%s][lg]overlay=%s:%s,%s,%s' "$2" "$s" "$s" "$1" "$left" "$top" \
    "$(dt b PKArkTools Manrope-800.ttf $((s * 6 / 10)) white $((left + s + 18)) $((top + s / 2 - s * 6 / 20 - 2)) 0)" \
    "$(dt u "$REPO_URL" Manrope-500.ttf $((s * 4 / 10)) $MUTED $left "$((H - top - s * 4 / 10))" 0)"
}

clip_scene() { # $1 = lang, $2 = escena, $3 = desde, $4 = hasta(rel.), $5 = velocidad, $6 = salida
  local m nm ss to d
  m=$(mark "$1" "$2"); nm=$(next_mark "$1" "$2")
  ss=$(python3 -I -c "print(round($m + $3, 3))")
  to=$(python3 -I -c "print(round($nm + $4, 3))")
  d=$(python3 -I -c "print(round(($to - $ss) / $5, 3))")
  local cap; cap=$(captions "$1" "$(caption "$1" "$2")")
  # shellcheck disable=SC2046
  ff -loop 1 -framerate 30 -i "bg_$LAYOUT.png" -ss "$ss" -to "$to" -i "$TAKES/demo_$1.mp4" \
    -loop 1 -i "bezel_$LAYOUT.png" -loop 1 -i "mask_$LAYOUT.png" $(brand_inputs) \
    -filter_complex "[1:v]setpts=(PTS-STARTPTS)/$5,fps=30,scale=$PW:$PH:flags=lanczos,format=yuva420p[s];[3:v]format=gray[m];[s][m]alphamerge[ph];\
[0:v][2:v]overlay=$((PX - B)):$((PY - B))[a];[a][ph]overlay=$PX:$PY:eof_action=repeat[c];\
$(brand_filter c 4)$cap,format=yuv420p[v]" \
    -map "[v]" -t "$d" -r 30 -an -c:v libx264 -preset veryfast -crf 12 "$6"
}

card() { # $1 = lang, $2 = title|end, $3 = salida, $4 = duración
  local s=$((H < W ? H * 36 / 100 : W * 40 / 100))
  [ "$2" = end ] && s=$((s * 80 / 100))
  local ly=$(((H - s) / 2 - H * 10 / 100))
  local ty=$((ly + s + 40)) f
  f="[1:v]scale=$s:$s,format=rgba,fade=t=in:st=0.1:d=0.6:alpha=1[lg];[0:v][lg]overlay=(W-w)/2:$ly"
  f+=",$(dt n PKArkTools Manrope-800.ttf $((s * 30 / 100)) white '(w-text_w)/2' $ty 0.35)"
  local y2=$((ty + s * 30 / 100 + 34))
  if [ "$2" = title ]; then
    local i=0 line
    while IFS= read -r line; do
      f+=",$(dt g "$line" Manrope-500.ttf $((s * 12 / 100)) $MUTED '(w-text_w)/2' $((y2 + i * s * 17 / 100)) 0.7)"
      i=$((i + 1))
    done <<< "$(wrap "$(tagline "$1")" $((W > 1100 ? 70 : 34)))"
  else
    f+=",$(dt fr "$(freeline "$1")" Manrope-800.ttf $((s * 15 / 100)) $ACCENT '(w-text_w)/2' $y2 0.6)"
    f+=",$(dt ur "$REPO_URL" Manrope-700.ttf $((s * 12 / 100)) white '(w-text_w)/2' $((y2 + s * 26 / 100)) 0.9)"
    f+=",$(dt pl "Android · iOS · macOS · Windows · Linux" Manrope-500.ttf $((s * 9 / 100)) $MUTED '(w-text_w)/2' $((y2 + s * 46 / 100)) 1.1)"
  fi
  ff -loop 1 -framerate 30 -i "bg_$LAYOUT.png" -loop 1 -framerate 30 -i logo.png \
    -filter_complex "$f,format=yuv420p[v]" -map "[v]" -t "$4" -r 30 -c:v libx264 -preset veryfast -crf 12 "$3"
}

# Une las piezas con fundidos y codifica la versión final.
assemble() { # $1 = salida, resto = piezas; usa ENC (array) para el códec final
  local out="$1"; shift
  local n=$# inputs=() f="" off=0 prev="0:v" i=1 d
  for p in "$@"; do inputs+=(-i "$p"); done
  d=$(dur "$1"); off=$(python3 -I -c "print(round($d - $XF, 3))")
  for p in "${@:2}"; do
    local o="x$i"
    [ "$i" -eq $((n - 1)) ] && o="v"
    f+="[$prev][$i:v]xfade=transition=fade:duration=$XF:offset=${off}[$o];"
    d=$(dur "$p"); off=$(python3 -I -c "print(round($off + $d - $XF, 3))")
    prev="$o"; i=$((i + 1))
  done
  ff "${inputs[@]}" -f lavfi -i anullsrc=r=48000:cl=stereo \
    -filter_complex "${f%;}" -map "[v]" -map "$n:a" -shortest \
    "${ENC[@]}" -c:a aac -b:a 64k -map_metadata -1 -map_chapters -1 -movflags +faststart "$out"
}

build() { # $1 = lang, $2 = layout, $3 = salida
  LAYOUT="$2"; layout "$2"; assets "$2"
  local parts=() k=0
  card "$1" title "p_${1}_${2}_00.mp4" 3.0; parts+=("p_${1}_${2}_00.mp4")
  for s in "${SCENES[@]}"; do
    # shellcheck disable=SC2086
    set -- "$1" "$2" "$3" $s
    k=$((k + 1))
    local out; out="p_${1}_${2}_$(printf %02d $k).mp4"
    clip_scene "$1" "$4" "$5" "$6" "$7" "$out"
    parts+=("$out")
  done
  card "$1" end "p_${1}_${2}_99.mp4" 4.0; parts+=("p_${1}_${2}_99.mp4")
  assemble "$3" "${parts[@]}"
  printf '%s  %s s  %s\n' "$3" "$(dur "$3")" "$(du -h "$3" | cut -f1)"
}

for l in en es; do
  [ -s "$TAKES/demo_$l.mp4" ] && [ -s "$TAKES/demo_$l.scenes" ] || { echo "faltan las tomas «$l»: tool/record_demo_video.sh $l" >&2; exit 1; }
done

# Facebook (español): H.264 High, 30 fps, ≤ 60 s, ≤ 30 MB.
ENC=(-c:v libx264 -preset slow -crf 20 -maxrate 4M -bufsize 8M -pix_fmt yuv420p -profile:v high -r 30)
build es vertical "$FB/pkarktools-demo-es-vertical.mp4"
build es square "$FB/pkarktools-demo-es-cuadrado.mp4"

# Repo (inglés): 1080p ≤ 10 MB.
ENC=(-c:v libx264 -preset slow -crf 21 -maxrate 3M -bufsize 6M -pix_fmt yuv420p -profile:v high -r 30)
build en horizontal "$MEDIA/pkarktools-demo.mp4"

# Vista previa animada del README: composición cuadrada en inglés, 600 px,
# del Arca al editor (~12 s), en bucle.
ENC=(-c:v libx264 -preset veryfast -crf 16 -pix_fmt yuv420p -r 30)
build en square "$WORK/preview_square_en.mp4"
ff -ss 2.6 -t 12 -i "$WORK/preview_square_en.mp4" -an \
  -vf "fps=12,scale=600:600:flags=lanczos" -c:v libwebp_anim -lossless 0 -quality 62 -compression_level 6 \
  -loop 0 -map_metadata -1 "$MEDIA/pkarktools-demo.webp"
printf '%s  %s\n' "$MEDIA/pkarktools-demo.webp" "$(du -h "$MEDIA/pkarktools-demo.webp" | cut -f1)"
