import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/sprites/sprite_cache.dart';
import '../../data/sprites/sprites.dart';

/// Icono descargado bajo demanda; mientras carga, sin conexión o si no
/// existe, muestra [fallback].
///
/// Tamaño y proporciones: cada icono se dibuja entero, sin recortar ni
/// estirar, a la escala que [SpriteLayout] calcula para su grupo y el tamaño
/// del hueco. La escala no depende del sprite (salvo los poquísimos que no
/// cabrían), así que todos los iconos de un grupo se ven coherentes, y se
/// elige para que el contenido típico del grupo llene casi todo el hueco.
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
  /// Solo se aplica a los grupos de arte de píxeles ([Sprites.isPixelArt]);
  /// los iconos dibujados (Pokémon de HOME, tipos, cintas) se suavizan.
  final bool pixelated;

  @override
  State<SpriteImage> createState() => _SpriteImageState();
}

/// Geometría común a todos los iconos (pura, para poder probarla).
abstract final class SpriteLayout {
  /// Escala (píxeles físicos por píxel del sprite) para [ref] en un hueco de
  /// [box] píxeles físicos.
  ///
  /// El lado de contenido de referencia del grupo ([Sprites.contentRef],
  /// percentil 92 de todo el set) llena [Sprites.fill] del hueco. Un sprite
  /// cuyo contenido no cabría a esa escala ([Sprites.needOf]) se reduce lo
  /// justo para no recortarse. Con [pixelated] (arte de píxeles), la mayor
  /// escala entera si aprovecha al menos el 80 % de esa escala; si no, la
  /// escala exacta (no entera, uniforme), que se pinta igualmente con vecino
  /// más próximo.
  static double scaleFor(SpriteRef ref, double box, {bool pixelated = true}) {
    var s = box * (Sprites.fill[ref.group] ?? 1) / Sprites.contentRef(ref.group);
    final need = Sprites.needOf(ref);
    if (need != null && need * s > box) s = box / need;
    if (!pixelated || s < 1) return s;
    final whole = s.floorToDouble();
    return whole / s >= 0.8 ? whole : s;
  }

  /// Rectángulo (en píxeles lógicos) donde se dibuja una imagen de
  /// [imageW]×[imageH] centrada en un hueco de [size] lógicos, a la escala del
  /// grupo; con [pixelated], alineado a píxeles físicos.
  static Rect destRect(SpriteRef ref, int imageW, int imageH, double size, double dpr, {bool pixelated = true}) {
    final box = size * dpr;
    final s = scaleFor(ref, box, pixelated: pixelated);
    final w = imageW * s, h = imageH * s;
    final left = pixelated ? ((box - w) / 2).roundToDouble() : (box - w) / 2;
    final top = pixelated ? ((box - h) / 2).roundToDouble() : (box - h) / 2;
    return Rect.fromLTWH(left / dpr, top / dpr, w / dpr, h / dpr);
  }

  /// Filtro al pintar: vecino más próximo para el arte de píxeles ampliado
  /// (también con escala no entera, para que no se emborrone); suavizado al
  /// reducir y para los iconos dibujados (HOME, tipos, cintas).
  static FilterQuality filterFor(double scale, {required bool pixelated}) =>
      pixelated && scale >= 1 ? FilterQuality.none : FilterQuality.medium;
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
        painter: _SpritePainter(
          img,
          ref,
          MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
          widget.pixelated && Sprites.isPixelArt(ref.group),
        ),
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
  _SpritePainter(this.image, this.ref, this.dpr, this.pixelated);
  final ui.Image image;
  final SpriteRef ref;
  final double dpr;
  final bool pixelated;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final r = SpriteLayout.destRect(ref, image.width, image.height, size.shortestSide, dpr, pixelated: pixelated);
    final dst = r.shift(Offset((size.width - size.shortestSide) / 2, (size.height - size.shortestSide) / 2));
    final k = dst.width * dpr / image.width;
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = SpriteLayout.filterFor(k, pixelated: pixelated));
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.image != image || old.dpr != dpr || old.ref != ref || old.pixelated != pixelated;
}
