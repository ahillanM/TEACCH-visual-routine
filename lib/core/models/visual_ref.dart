import 'dart:typed_data';

/// A reference to the visuals of an activity, place or person.
///
/// [symbol] is a stable key resolved to an icon by `widgets/symbol_icons.dart`.
/// [pictogramUrl] points to an ARASAAC pictogram (HTTPS only).
/// [photoUrl] is a custom activity photo (a short-lived signed URL from
/// private Storage, never persisted); when it is null the UI falls back to
/// the pictogram, then the symbol.
/// [photoBytes] is the same photo held in memory (offline demo only).
class VisualRef {
  final String symbol;
  final String? pictogramUrl;
  final String? photoUrl;
  final Uint8List? photoBytes;

  const VisualRef({
    required this.symbol,
    this.pictogramUrl,
    this.photoUrl,
    this.photoBytes,
  });

  /// Builds an ARASAAC pictogram reference from its numeric id.
  const VisualRef.arasaac(this.symbol, int pictogramId, {this.photoUrl})
    : pictogramUrl =
          'https://static.arasaac.org/pictograms/$pictogramId/${pictogramId}_500.png',
      photoBytes = null;

  bool get hasPhoto => photoUrl != null || photoBytes != null;

  VisualRef withPhotoBytes(Uint8List? bytes) => VisualRef(
    symbol: symbol,
    pictogramUrl: pictogramUrl,
    photoUrl: null,
    photoBytes: bytes,
  );
}
