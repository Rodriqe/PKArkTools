import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../common/format.dart';

/// Texto en el idioma de la app. Las herramientas (Showdown, calculadora,
/// cajas, formato oficial, tarjeta y emuladores) llevan sus textos aquí
/// en vez de en los `.arb` para no chocar con otras ramas al fusionar.

/// Origen del menú de compartir (iPad y macOS lo necesitan).
Rect? shareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) return box.localToGlobal(Offset.zero) & box.size;
  return null;
}

/// Comparte texto con el menú del sistema; si no hay menú (escritorio sin
/// soporte, tests) lo copia al portapapeles.
Future<void> shareText(BuildContext context, String text, {String? subject}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final copied = context.l10n.toolsCopiedToClipboard;
  try {
    final r = await SharePlus.instance.share(
      ShareParams(text: text, subject: subject, sharePositionOrigin: shareOrigin(context)),
    );
    if (r.status != ShareResultStatus.unavailable) return;
  } catch (_) {}
  await Clipboard.setData(ClipboardData(text: text));
  messenger?.showSnackBar(SnackBar(content: Text(copied)));
}

/// Comparte un archivo (PNG de la tarjeta) con el menú del sistema.
Future<bool> shareFile(BuildContext context, Uint8List bytes, String name, String mime) async {
  try {
    final r = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: name, mimeType: mime)],
        fileNameOverrides: [name],
        sharePositionOrigin: shareOrigin(context),
      ),
    );
    return r.status != ShareResultStatus.unavailable;
  } catch (_) {
    return false;
  }
}

Future<void> copyText(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final msg = context.l10n.toolsCopiedToClipboard;
  await Clipboard.setData(ClipboardData(text: text));
  messenger?.showSnackBar(SnackBar(content: Text(msg)));
}
