import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/sprites/sprite_cache.dart';
import '../../data/sprites/sprites.dart';

/// Icono descargado bajo demanda; mientras carga, sin conexión o si no
/// existe, muestra [fallback].
///
/// Proporciones: cada icono se dibuja con su lienzo original, sin recortar
/// ni estirar, a la escala que [SpriteLayout] calcula para su grupo y el
/// tamaño del hueco. Así dos Pokémon (o dos objetos) en huecos iguales
/// conservan el tamaño relativo del juego y los píxeles salen cuadrados.
class SpriteImage extends StatefulWidget {
  const SpriteImage({
    super.key,
    required this.sprite,
    required this.size,
    this.fallback,
    this.semanticLabel,
    this.pixelated = true,
  });

  final SpriteRef? sprite;
  final double size;
  final Widget? fallback;
  final String? semanticLabel;

  /// Arte de píxeles: escala entera y sin suavizar (vecino más próximo).
  /// Los iconos dibujados (tipos, cintas) se escalan con suavizado.
  final bool pixelated;

  @override
  State<SpriteImage> createState() => _SpriteImageState();
}

/// Geometría común a todos los iconos (pura, para poder probarla).
abstract final class SpriteLayout {
  /// Escala (píxeles físicos por píxel del sprite) para los iconos de
  /// [group] en un hueco de [box] píxeles físicos: el lienzo de referencia
  /// del grupo cabe entero (BoxFit.contain). Con [pixelated], la mayor escala
  /// entera que cabe cuando ocupa al menos el 80 % del hueco; si no, la
  /// fracción que cabe (uniforme, sin deformar, con suavizado).
  static double scaleFor(String group, double box, {bool pixelated = true}) {
    final (cw, ch) = Sprites.canvas[group] ?? (68, 56);
    final fit = box / (cw > ch ? cw : ch);
    if (!pixelated || fit < 1) return fit;
    // Escala entera solo si apenas desperdicia hueco (≤ 20 %); si no (p. ej.
    // ×1,9 → ×1 dejaría el sprite a la mitad), la fracción exacta, suavizada.
    final whole = fit.floorToDouble();
    return whole / fit >= 0.8 ? whole : fit;
  }

  /// Rectángulo (en píxeles lógicos) donde se dibuja una imagen de
  /// [imageW]×[imageH] centrada en un hueco de [size] lógicos, a la escala del
  /// grupo, alineado a píxeles físicos para que no haya columnas más anchas.
  static Rect destRect(String group, int imageW, int imageH, double size, double dpr, {bool pixelated = true}) {
    final box = size * dpr;
    var s = scaleFor(group, box, pixelated: pixelated);
    // Un icono más grande que el lienzo del grupo (no debería haberlo) se
    // reduce lo justo para caber, sin deformarlo.
    final over = (imageW * s > box || imageH * s > box) ? box / (imageW > imageH ? imageW : imageH) : null;
    if (over != null) s = pixelated && over >= 1 ? over.floorToDouble() : over;
    final w = imageW * s, h = imageH * s;
    final left = pixelated ? ((box - w) / 2).roundToDouble() : (box - w) / 2;
    final top = pixelated ? ((box - h) / 2).roundToDouble() : (box - h) / 2;
    return Rect.fromLTWH(left / dpr, top / dpr, w / dpr, h / dpr);
  }
}

class _SpriteImageState extends State<SpriteImage> {
  Uint8List? _bytes;
  ui.Image? _image;
  int _gen = -1;

  SpriteCache get _cache => SpriteCache.instance;

  @override
  void initState() {
    super.initState();
    _cache.generation.addListener(_reload);
    _resolve();
  }

  @override
  void didUpdateWidget(SpriteImage old) {
    super.didUpdateWidget(old);
    if (old.sprite != widget.sprite) _resolve();
  }

  @override
  void dispose() {
    _cache.generation.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (_gen != _cache.generation.value) _resolve();
  }

  void _set(Uint8List? b) {
    if (identical(b, _bytes)) return;
    _bytes = b;
    _image = null;
    final ref = widget.sprite;
    if (b == null || ref == null) return;
    final hit = _Decoded.cache[ref.key];
    if (hit != null && identical(hit.bytes, b)) {
      _image = hit.image;
      return;
    }
    _Decoded.decode(ref.key, b).then((img) {
      if (!mounted || !identical(_bytes, b)) return;
      if (img == null) {
        // Bytes que pasaron la validación pero no se pueden decodificar: se
        // descartan (memoria y disco) y se piden de nuevo una sola vez.
        _cache.invalidate(ref).then((again) {
          if (again && mounted && widget.sprite == ref) _resolve(force: true);
        });
        return;
      }
      setState(() => _image = img);
    });
  }

  void _resolve({bool force = false}) {
    _gen = _cache.generation.value;
    final ref = widget.sprite;
    if (ref == null) {
      _set(null);
      return;
    }
    final hit = force ? null : _cache.peek(ref);
    if (hit != null) {
      _set(hit);
      return;
    }
    if (force) {
      _bytes = null;
      _image = null;
    }
    _set(null);
    _cache.load(ref).then((b) {
      if (!mounted || widget.sprite != ref) return;
      setState(() => _set(b));
    });
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    final ref = widget.sprite;
    if (img == null || ref == null) return widget.fallback ?? SizedBox.square(dimension: widget.size);
    return Semantics(
      label: widget.semanticLabel,
      image: widget.semanticLabel != null,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _SpritePainter(img, ref.group, MediaQuery.maybeDevicePixelRatioOf(context) ?? 1, widget.pixelated),
      ),
    );
  }
}

/// Sprites ya decodificados (compartidos entre widgets).
class _Decoded {
  _Decoded(this.bytes, this.image);
  final Uint8List bytes;
  final ui.Image image;

  static final Map<String, _Decoded> cache = {};
  static final Map<String, Future<ui.Image?>> _pending = {};

  static Future<ui.Image?> decode(String key, Uint8List bytes) => _pending.putIfAbsent(key, () async {
        try {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          codec.dispose();
          if (cache.length > 300) cache.remove(cache.keys.first);
          cache[key] = _Decoded(bytes, frame.image);
          return frame.image;
        } catch (_) {
          return null;
        } finally {
          unawaited(Future<void>.microtask(() => _pending.remove(key)));
        }
      });
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.image, this.group, this.dpr, this.pixelated);
  final ui.Image image;
  final String group;
  final double dpr;
  final bool pixelated;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final r = SpriteLayout.destRect(group, image.width, image.height, size.shortestSide, dpr, pixelated: pixelated);
    final dst = r.shift(Offset((size.width - size.shortestSide) / 2, (size.height - size.shortestSide) / 2));
    // Vecino más próximo solo con escala entera ≥ 1: con una fracción saldrían
    // columnas de píxeles de anchos distintos; ahí se suaviza.
    final k = dst.width * dpr / image.width;
    final sharp = pixelated && k >= 1 && (k - k.roundToDouble()).abs() < 1e-6;
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = sharp ? FilterQuality.none : FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.image != image || old.dpr != dpr || old.group != group || old.pixelated != pixelated;
}
