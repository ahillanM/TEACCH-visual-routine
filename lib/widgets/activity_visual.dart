import 'package:flutter/material.dart';

import '../core/models/visual_ref.dart';
import '../theme.dart';
import 'symbol_icons.dart';

/// The large visual at the top of a card: a photo, a pictogram, or both.
///
/// Order of preference: custom photo (`photoUrl` / `photoBytes`), then the
/// pictogram, then the symbol icon, then a default icon. Without a photo the
/// "photo" layer is a calm illustrated tile (tinted background + symbol).
class ActivityVisual extends StatelessWidget {
  final VisualRef visual;
  final Color accent;
  final double height;
  final bool showPhoto;
  final bool showSymbol;
  final bool desaturate;
  final String semanticLabel;
  final BorderRadius borderRadius;

  const ActivityVisual({
    super.key,
    required this.visual,
    required this.accent,
    required this.semanticLabel,
    this.height = 160,
    this.showPhoto = true,
    this.showSymbol = true,
    this.desaturate = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.md)),
  });

  @override
  Widget build(BuildContext context) {
    final pictogram = showSymbol ? _pictogram(context) : null;
    final photoLayer = showPhoto ? _photoLayer(context) : null;

    Widget content;
    if (photoLayer != null && pictogram != null) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          photoLayer,
          Positioned(
            right: AppSpace.md,
            bottom: AppSpace.md,
            child: _PictogramBadge(size: height * 0.42, child: pictogram),
          ),
        ],
      );
    } else if (photoLayer != null) {
      content = photoLayer;
    } else {
      content = Container(
        color: context.palette.surface,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppSpace.md),
        child: pictogram ?? _symbolIcon(context, height * 0.5),
      );
    }

    if (desaturate) {
      content = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyscaleMatrix),
        child: Opacity(opacity: 0.75, child: content),
      );
    }

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(height: height, width: double.infinity, child: content),
      ),
    );
  }

  Widget _photoLayer(BuildContext context) {
    final url = visual.photoUrl;
    final placeholder = Container(
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.14)),
      alignment: showSymbol ? const Alignment(-0.6, 0) : Alignment.center,
      child: _symbolIcon(context, height * 0.45),
    );
    final bytes = visual.photoBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    if (url == null) return placeholder;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }

  Widget? _pictogram(BuildContext context) {
    final url = visual.pictogramUrl;
    if (url == null) return null;
    return Image.network(
      url,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => _symbolIcon(context, height * 0.35),
    );
  }

  Widget _symbolIcon(BuildContext context, double size) => Icon(
        SymbolIcons.of(visual.symbol),
        size: size,
        color: accent,
      );
}

class _PictogramBadge extends StatelessWidget {
  final double size;
  final Widget child;
  const _PictogramBadge({required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.palette.border),
      ),
      child: child,
    );
  }
}

const List<double> _greyscaleMatrix = [
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
];
