import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Utilidades de interfaz adaptativa: teléfono frente a escritorio, atajos de
/// teclado por plataforma, barras desplazables con desvanecido en los bordes y
/// hojas inferiores en lugar de diálogos en el teléfono.

/// Anchura por debajo de la cual la interfaz se trata como teléfono.
const double kPhoneBreakpoint = 600;

extension AdaptiveX on BuildContext {
  /// `true` en un teléfono (o una ventana estrecha).
  bool get isPhone => MediaQuery.sizeOf(this).width < kPhoneBreakpoint;
}

/// `true` en plataformas de escritorio (teclado físico habitual).
bool get isDesktopPlatform => switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => true,
      _ => false,
    };

/// Atajos de teclado que se anuncian en la interfaz.
enum AppShortcut { undo, redo }

/// Texto del atajo en la plataforma actual (`⌘Z`, `Ctrl+Z`…) o null en
/// plataformas táctiles, donde no se muestran.
String? shortcutHint(AppShortcut s, [TargetPlatform? platform]) {
  final p = platform ?? defaultTargetPlatform;
  final mac = p == TargetPlatform.macOS;
  final desktop = mac || p == TargetPlatform.windows || p == TargetPlatform.linux;
  if (!desktop) return null;
  return switch (s) {
    AppShortcut.undo => mac ? '⌘Z' : 'Ctrl+Z',
    AppShortcut.redo => mac ? '⇧⌘Z' : 'Ctrl+Y',
  };
}

/// [label] con su atajo entre paréntesis si la plataforma los muestra.
String withShortcut(String label, AppShortcut s, [TargetPlatform? platform]) {
  final hint = shortcutHint(s, platform);
  return hint == null ? label : '$label ($hint)';
}

// ------------------------------------------------------------ desvanecido

/// Contenido desplazable en horizontal con un desvanecido en el borde que
/// tiene más contenido: indica que se puede deslizar sin ocupar espacio.
class EdgeFadeScroller extends StatefulWidget {
  const EdgeFadeScroller({super.key, required this.child, this.controller, this.padding = EdgeInsets.zero, this.fade = 28});
  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final double fade;

  @override
  State<EdgeFadeScroller> createState() => _EdgeFadeScrollerState();
}

class _EdgeFadeScrollerState extends State<EdgeFadeScroller> {
  ScrollController? _own;
  ScrollController get _ctrl => widget.controller ?? (_own ??= ScrollController());
  bool _start = false, _end = false;

  void _update() {
    if (!_ctrl.hasClients) return;
    final pos = _ctrl.position;
    if (!pos.hasContentDimensions) return;
    final start = pos.pixels > pos.minScrollExtent + 1;
    final end = pos.pixels < pos.maxScrollExtent - 1;
    if (start == _start && end == _end) return;
    setState(() {
      _start = start;
      _end = end;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _update();
    });
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scroller = NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _update();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _update();
          return false;
        },
        child: SingleChildScrollView(
          controller: _ctrl,
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite && c.maxWidth > 0 ? c.maxWidth : 1.0;
      final f = (widget.fade / w).clamp(0.0, 0.3);
      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          colors: [
            _start ? Colors.transparent : Colors.black,
            Colors.black,
            Colors.black,
            _end ? Colors.transparent : Colors.black,
          ],
          stops: [0, f, 1 - f, 1],
        ).createShader(rect),
        child: scroller,
      );
    });
  }
}

/// Fila de chips/pestañas desplazable con desvanecido que mantiene visible el
/// elemento seleccionado (se centra al cambiar).
class ScrollingChipRow extends StatefulWidget {
  const ScrollingChipRow({super.key, required this.children, this.selectedIndex, this.spacing = 8, this.padding = EdgeInsets.zero});
  final List<Widget> children;
  final int? selectedIndex;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  State<ScrollingChipRow> createState() => _ScrollingChipRowState();
}

class _ScrollingChipRowState extends State<ScrollingChipRow> {
  final _keys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  @override
  void didUpdateWidget(ScrollingChipRow old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: true));
    }
  }

  void _reveal({required bool animate}) {
    final i = widget.selectedIndex;
    if (!mounted || i == null || i < 0 || i >= _keys.length) return;
    final ctx = _keys[i].currentContext;
    final box = ctx?.findRenderObject();
    if (ctx == null || box == null) return;
    // Solo la fila horizontal: Scrollable.ensureVisible movería también la
    // página vertical que la contiene.
    Scrollable.of(ctx, axis: Axis.horizontal).position.ensureVisible(
      box,
      alignment: 0.5,
      duration: animate ? const Duration(milliseconds: 280) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    while (_keys.length < widget.children.length) {
      _keys.add(GlobalKey());
    }
    return EdgeFadeScroller(
      padding: widget.padding,
      child: Row(children: [
        for (var i = 0; i < widget.children.length; i++) ...[
          if (i > 0) SizedBox(width: widget.spacing),
          KeyedSubtree(key: _keys[i], child: widget.children[i]),
        ],
      ]),
    );
  }
}

/// Una pestaña de [SectionTabs].
class SectionTab<T> {
  const SectionTab(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Pestañas en píldora: una sola línea desplazable, la seleccionada rellena
/// con el acento y siempre visible; objetivos táctiles de 48 px. Sustituye a
/// `SegmentedButton`, que en un teléfono parte palabras o se desborda.
class SectionTabs<T> extends StatelessWidget {
  const SectionTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
    this.accent,
    this.dense = false,
  });
  final List<SectionTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color? accent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = this.accent ?? context.colors.primary;
    final index = tabs.indexWhere((t) => t.value == selected);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: ScrollingChipRow(
        selectedIndex: index,
        spacing: 6,
        children: [
          for (final t in tabs)
            _Pill(
              label: t.label,
              icon: t.icon,
              selected: t.value == selected,
              accent: accent,
              tokens: tokens,
              dense: dense,
              onTap: () => onChanged(t.value),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.tokens,
    required this.dense,
    required this.onTap,
  });
  final String label;
  final IconData? icon;
  final bool selected;
  final Color accent;
  final ArcaTokens tokens;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? context.colors.onSurface : tokens.muted;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : tokens.raised,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? accent.withValues(alpha: 0.75) : tokens.hairline, width: selected ? 1.4 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: dense ? 44 : 48),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 18),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: selected ? accent : tokens.muted),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: context.text.labelLarge!.copyWith(color: fg),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ hojas y diálogos

/// Muestra [builder] como hoja inferior en el teléfono y como diálogo en
/// pantallas anchas. En la hoja, el contenido recibe el safe area inferior.
Future<T?> showAdaptiveSheet<T>({required BuildContext context, required WidgetBuilder builder, bool dialogOnWide = true}) {
  if (context.isPhone || !dialogOnWide) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: builder,
    );
  }
  return showDialog<T>(context: context, builder: builder);
}

/// Confirmación: hoja inferior con botones a lo ancho en el teléfono,
/// `AlertDialog` en escritorio. Devuelve `true` si se confirma.
Future<bool> confirmAdaptive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required String cancel,
  IconData? icon,
  bool destructive = false,
}) async {
  final colors = Theme.of(context).colorScheme;
  final style = destructive ? FilledButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError) : null;
  final bool? ok;
  if (context.isPhone) {
    ok = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Icon(icon, size: 28, color: destructive ? colors.error : colors.primary),
              ),
              const SizedBox(height: 12),
            ],
            Text(title, style: ctx.text.headlineSmall),
            const SizedBox(height: 10),
            Text(body, style: ctx.text.bodyLarge!.copyWith(color: ctx.tokens.muted)),
            const SizedBox(height: 24),
            FilledButton(style: style, onPressed: () => Navigator.pop(ctx, true), child: Text(confirm)),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(cancel),
            ),
          ]),
        ),
      ),
    );
  } else {
    ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: icon == null ? null : Icon(icon),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancel)),
          FilledButton(style: style, onPressed: () => Navigator.pop(ctx, true), child: Text(confirm)),
        ],
      ),
    );
  }
  return ok == true;
}

// ------------------------------------------------------------ aplicar

/// Pie de un formulario: nota opcional, «Revertir» y «Aplicar». En el
/// teléfono la nota va encima y los botones se reparten el ancho (48 px).
class ApplyBar extends StatelessWidget {
  const ApplyBar({
    super.key,
    required this.revertLabel,
    required this.applyLabel,
    required this.onRevert,
    required this.onApply,
    this.note,
  });
  final String revertLabel;
  final String applyLabel;
  final VoidCallback? onRevert;
  final VoidCallback? onApply;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final noteText = note == null ? null : Text(note!, style: context.text.bodySmall!.copyWith(color: context.tokens.muted));
    final revert = TextButton(onPressed: onRevert, child: Text(revertLabel, maxLines: 1, overflow: TextOverflow.ellipsis));
    final apply = FilledButton(onPressed: onApply, child: Text(applyLabel, maxLines: 1, overflow: TextOverflow.ellipsis));
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 480) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (noteText != null) ...[noteText, const SizedBox(height: 12)],
          Row(children: [
            Expanded(flex: 2, child: SizedBox(height: 48, child: revert)),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: SizedBox(height: 48, child: apply)),
          ]),
        ]);
      }
      return Row(children: [
        if (noteText != null) Expanded(child: noteText) else const Spacer(),
        const SizedBox(width: 12),
        revert,
        const SizedBox(width: 8),
        apply,
      ]);
    });
  }
}
