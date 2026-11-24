#!/usr/bin/env python3
"""Genera el logo transparente y todos los iconos de la app a partir del logo del owner.

Uso (Pillow, numpy y scipy en un venv dentro de .scratch/):
    python3 -m venv .scratch/venv && .scratch/venv/bin/pip install pillow numpy scipy
    .scratch/venv/bin/python tool/gen_branding.py [.ref/branding/logo-transparente.png]

Fuente: el logo oficial con transparencia del owner (logo-transparente.png,
1600×1600 RGBA). Si se pasa una imagen sin transparencia (logo-original.png,
fondo blanco), se recorta el fondo automáticamente (paso 1).

Pasos:
  1. Fondo transparente: el blanco (y la sombra gris bajo la «V») conectado con
     el borde, más los huecos blancos interiores grandes, se vuelve
     transparente. En el borde del logo se «desmezcla» el blanco (alfa por
     píxel y color sin halo).
  2. Derivados en apps/pkarktools/assets/branding/ (logo, marca recortada para
     la interfaz, monocromo).
  3. Iconos de Android (adaptativo con fondo azul noche + monocromo
     para Android 13+ y PNG antiguos), iOS, macOS, Windows y Linux, y splash
     nativo (Android y iOS).

Iconos de la app (variante C): el logo completo, recortado a su contenido, a
~84 % del lado y centrado sobre el fondo azul noche de la app
(ArcaTokens.dark.base), sin sombra. Donde una máscara circular puede recortarlo
(zona segura del icono adaptativo, icono redondo antiguo) se reduce lo justo
para que todo el contenido quepa en el círculo.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
APP = os.path.join(ROOT, 'apps', 'pkarktools')
BRAND_DIR = os.path.join(APP, 'assets', 'branding')

# Fondo oscuro de la marca (= ArcaTokens.dark.base) y un tono algo más claro para el degradado.
BRAND_DARK = (0x15, 0x19, 0x27)
BRAND_DARK_2 = (0x24, 0x2A, 0x42)
# Proporción del lado del icono que ocupa el logo (lado mayor de su contenido).
ICON_LOGO = 0.84


def transparent(src):
    im = np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
    h, w, _ = im.shape
    mn, mx = im.min(2), im.max(2)
    sat = mx - mn
    yy = np.arange(h)[:, None].repeat(w, 1)
    # Blanco del fondo (con su ligera textura).
    white = (mn > 214) & (sat < 24)
    # Sombra bajo la «V»: gris poco saturado en la franja inferior.
    shadow = (yy > 0.80 * h) & (sat < 34) & (mn > 70)
    cand = white | shadow
    lab, n = ndimage.label(cand)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    # Huecos blancos interiores (entre alas, corona y triángulo).
    lab2, n2 = ndimage.label(white & ~bg)
    if n2:
        sizes = ndimage.sum(np.ones_like(mn), lab2, range(1, n2 + 1))
        means = ndimage.mean(mn, lab2, range(1, n2 + 1))
        big = [i + 1 for i, (s, m) in enumerate(zip(sizes, means)) if s > 600 and m > 236]
        bg |= np.isin(lab2, big)
    fg = ~bg
    # Limpia islas sueltas (ruido del fondo).
    lab3, n3 = ndimage.label(fg)
    if n3:
        sizes = ndimage.sum(np.ones_like(mn), lab3, range(1, n3 + 1))
        fg = np.isin(lab3, [i + 1 for i, s in enumerate(sizes) if s > 2000])
    # Borde: desmezcla del blanco en una franja de ~3 px.
    dist = ndimage.distance_transform_edt(fg)
    alpha = np.ones((h, w), np.float32)
    band = fg & (dist <= 3.0)
    # Alfa por luminancia mínima respecto a un borde dorado oscuro de referencia.
    ref = 95.0
    a_band = np.clip((255.0 - mn) / (255.0 - ref), 0.0, 1.0)
    alpha[band] = a_band[band]
    alpha[~fg] = 0.0
    # Suaviza el alfa sin ensanchar el contorno.
    alpha = ndimage.gaussian_filter(alpha, 0.6) * (dist > 0)
    alpha = np.clip(alpha, 0, 1)
    rgb = im.copy()
    a3 = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((rgb - (1 - a3) * 255.0) / a3, 0, 255)
    # En la franja, el color no puede ser más claro que el original (evita halos).
    rgb = np.where(band[..., None], np.minimum(rgb, im), im)
    out = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(out, 'RGBA')
    bbox = img.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    return img.crop(bbox)


def load_logo(src):
    """Logo con alfa: si la fuente ya es transparente se usa tal cual (recortada
    a su contenido y sin píxeles casi invisibles); si no, se quita el fondo."""
    img = Image.open(src)
    if img.mode == 'RGBA':
        a = np.asarray(img)
        corners = [a[0, 0, 3], a[0, -1, 3], a[-1, 0, 3], a[-1, -1, 3]]
        if max(corners) == 0:
            arr = a.copy()
            arr[arr[..., 3] < 6] = 0
            out = Image.fromarray(arr, 'RGBA')
            return out.crop(out.getchannel('A').getbbox())
    return transparent(src)


def square(img, size, pad=0.0):
    """Centra [img] en un lienzo cuadrado transparente con margen relativo [pad]."""
    inner = int(round(size * (1 - 2 * pad)))
    w, h = img.size
    s = inner / max(w, h)
    r = img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    canvas.paste(r, ((size - r.width) // 2, (size - r.height) // 2), r)
    return canvas


def place(logo, size, side):
    """Centra [logo] en un lienzo transparente de [size] px con su lado mayor a [side] px."""
    w, h = logo.size
    s = side / max(w, h)
    r = logo.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    canvas.paste(r, ((size - r.width) // 2, (size - r.height) // 2), r)
    return canvas


def circle_side(logo, radius):
    """Lado mayor máximo del logo (centrado) para que todo su contenido quepa en un círculo de [radius]."""
    a = np.asarray(logo.getchannel('A'))
    h, w = a.shape
    ys, xs = np.nonzero(a > 16)
    d = np.sqrt((xs + 0.5 - w / 2) ** 2 + (ys + 0.5 - h / 2) ** 2).max()
    return radius * max(w, h) / d


def dark_bg(size, radius=0.0, circle=False):
    """Fondo azul noche liso (opcionalmente cuadrado redondeado o círculo)."""
    bg = Image.new('RGBA', (size, size), BRAND_DARK + (255,))
    if radius > 0 or circle:
        # Máscara con supermuestreo para un borde suave.
        k = 4
        mask = Image.new('L', (size * k, size * k), 0)
        d = ImageDraw.Draw(mask)
        if circle:
            d.ellipse([0, 0, size * k - 1, size * k - 1], fill=255)
        else:
            d.rounded_rectangle([0, 0, size * k - 1, size * k - 1], radius=radius * size * k, fill=255)
        bg.putalpha(mask.resize((size, size), Image.LANCZOS))
    return bg


def icon(logo, size, radius=0.0, inset=0.0, circle=False):
    """Icono: logo a ICON_LOGO del lado sobre azul noche (con margen exterior [inset], estilo macOS)."""
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    inner = int(round(size * (1 - 2 * inset)))
    off = (size - inner) // 2
    canvas.alpha_composite(dark_bg(inner, radius, circle), (off, off))
    side = inner * ICON_LOGO
    if circle:
        side = min(side, circle_side(logo, inner * 0.5 * 0.98))
    canvas.alpha_composite(place(logo, inner, side), (off, off))
    return canvas


def mono(logo):
    """Silueta blanca (icono monocromo de Android 13+). Los contornos oscuros se
    vacían para que alas, corona, triángulo y «V» se lean como piezas separadas."""
    arr = np.asarray(logo).astype(np.float32)
    lum = 0.299 * arr[..., 0] + 0.587 * arr[..., 1] + 0.114 * arr[..., 2]
    lum = ndimage.median_filter(lum, 9)
    body = ndimage.binary_opening(lum > 72, iterations=3)
    body = body & (arr[..., 3] > 128)
    a = (ndimage.gaussian_filter(body.astype(np.float32), 1.2) * arr[..., 3]).astype(np.uint8)
    white = Image.new('RGBA', logo.size, (255, 255, 255, 0))
    white.putalpha(Image.fromarray(a, 'L'))
    return white


def save(img, *parts, opaque=False):
    path = os.path.join(*parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if opaque:
        bg = Image.new('RGB', img.size, BRAND_DARK)
        bg.paste(img, (0, 0), img)
        bg.save(path, optimize=True)
    else:
        img.save(path, optimize=True)
    return path


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, '.ref', 'branding', 'logo-transparente.png')
    logo = load_logo(src)

    # 1. Derivados versionados.
    save(square(logo, 1024, 0.04), BRAND_DIR, 'logo.png')
    save(square(logo, 256, 0.02), BRAND_DIR, 'logo_256.png')
    # Logo de la interfaz (BrandMark): recortado a su contenido, sin margen, 512 px de alto.
    save(logo.resize((round(logo.width * 512 / logo.height), 512), Image.LANCZOS), BRAND_DIR, 'logo_mark.png')
    save(square(mono(logo), 512, 0.04), BRAND_DIR, 'logo_mono.png')
    save(icon(logo, 1024, radius=0.22), BRAND_DIR, 'app_icon_1024.png')

    # 2. Android: adaptativo (108 dp; zona segura 66 dp) + monocromo + PNG antiguos.
    res = os.path.join(APP, 'android', 'app', 'src', 'main', 'res')
    densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    for name, k in densities.items():
        fg = int(108 * k)
        # Lo más grande posible sin salir del círculo seguro de 66 dp (ni pasar del 84 % de los 72 dp visibles).
        side = min(circle_side(logo, 33 * k), 72 * k * ICON_LOGO)
        save(place(logo, fg, side), res, f'mipmap-{name}', 'ic_launcher_foreground.png')
        save(square(mono(logo), fg, 0.25), res, f'mipmap-{name}', 'ic_launcher_monochrome.png')
        legacy = int(48 * k)
        save(icon(logo, legacy, radius=0.2), res, f'mipmap-{name}', 'ic_launcher.png')
        save(icon(logo, legacy, circle=True), res, f'mipmap-{name}', 'ic_launcher_round.png')
        # Splash (Android < 12): logo de 160 dp.
        save(square(logo, int(160 * k), 0.0), res, f'drawable-{name}', 'splash_logo.png')
    os.makedirs(os.path.join(res, 'mipmap-anydpi-v26'), exist_ok=True)
    adaptive = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
'''
    for n in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        open(os.path.join(res, 'mipmap-anydpi-v26', n), 'w').write(adaptive)
    hexc = '#%02X%02X%02X' % BRAND_DARK
    open(os.path.join(res, 'values', 'colors.xml'), 'w').write(f'''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">{hexc}</color>
    <color name="splash_background">{hexc}</color>
</resources>
''')
    splash = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Splash nativo (generado por tool/gen_branding.py): fondo oscuro de la marca y logo centrado. -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_background" />
    <item>
        <bitmap android:gravity="center" android:src="@drawable/splash_logo" />
    </item>
</layer-list>
'''
    for d in ('drawable', 'drawable-v21'):
        open(os.path.join(res, d, 'launch_background.xml'), 'w').write(splash)
    # Android 12+: icono animado del splash del sistema (máscara circular de 240 dp, logo en 160 dp).
    for name, k in densities.items():
        save(square(logo, int(288 * k), 0.22), res, f'drawable-{name}', 'splash_icon.png')
    os.makedirs(os.path.join(res, 'values-v31'), exist_ok=True)
    os.makedirs(os.path.join(res, 'values-night-v31'), exist_ok=True)
    for d in ('values-v31', 'values-night-v31'):
        open(os.path.join(res, d, 'styles.xml'), 'w').write('''<?xml version="1.0" encoding="utf-8"?>
<!-- Generado por tool/gen_branding.py: splash del sistema (Android 12+). -->
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowSplashScreenBackground">@color/splash_background</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/splash_icon</item>
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:forceDarkAllowed">false</item>
        <item name="android:windowFullscreen">false</item>
        <item name="android:windowDrawsSystemBarBackgrounds">false</item>
        <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
''')

    # 3. iOS: iconos opacos (sin alfa) y LaunchImage.
    ios = os.path.join(APP, 'ios', 'Runner', 'Assets.xcassets')
    contents = json.load(open(os.path.join(ios, 'AppIcon.appiconset', 'Contents.json')))
    for e in contents['images']:
        fn = e.get('filename')
        if not fn:
            continue
        pt = float(e['size'].split('x')[0])
        sc = int(e['scale'].replace('x', ''))
        px = int(round(pt * sc))
        save(icon(logo, px), ios, 'AppIcon.appiconset', fn, opaque=True)
    for fn, k in (('LaunchImage.png', 1), ('LaunchImage@2x.png', 2), ('LaunchImage@3x.png', 3)):
        save(square(logo, 160 * k, 0.0), ios, 'LaunchImage.imageset', fn)

    # 4. macOS: rejilla de Apple (cuadrado redondeado de 824/1024 con 100 px de margen y radio ~185 px).
    mac = os.path.join(APP, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    for px in (16, 32, 64, 128, 256, 512, 1024):
        save(icon(logo, px, radius=0.225, inset=100 / 1024), mac, f'app_icon_{px}.png')

    # 5. Windows (.ico multi-tamaño) y Linux (PNG que carga la ventana GTK).
    win = icon(logo, 256, radius=0.2)
    win.save(os.path.join(APP, 'windows', 'runner', 'resources', 'app_icon.ico'),
             sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    save(icon(logo, 512, radius=0.2), APP, 'linux', 'runner', 'app_icon.png')
    print('OK')


main()
