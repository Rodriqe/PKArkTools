import 'dart:async';

import 'package:pkarktools/data/sprites/sprite_cache.dart';

/// Configuración global de los tests: sin red ni disco para los iconos
/// (los widgets usan su avatar de iniciales). Los tests de iconos instalan
/// su propia caché falsa.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SpriteCache.instance = SpriteCache.disabled();
  await testMain();
}
