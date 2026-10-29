/// A reference to the visuals of an activity, place or person.
///
/// [symbol] is a stable key resolved to an icon by `widgets/symbol_icons.dart`.
/// [pictogramUrl] points to an ARASAAC pictogram (HTTPS only).
/// [photoUrl] is reserved for approved institution photos; when it is null the
/// UI shows a calm illustrated placeholder instead.
class VisualRef {
  final String symbol;
  final String? pictogramUrl;
  final String? photoUrl;

  const VisualRef({
    required this.symbol,
    this.pictogramUrl,
    this.photoUrl,
  });

  /// Builds an ARASAAC pictogram reference from its numeric id.
  const VisualRef.arasaac(this.symbol, int pictogramId, {this.photoUrl})
      : pictogramUrl =
            'https://static.arasaac.org/pictograms/$pictogramId/${pictogramId}_500.png';
}
