import 'dart:typed_data';

/// Represents a decoded ThumbHash image with RGBA pixel data.
///
/// The [rgba] buffer contains pixel data in row-major order,
/// with 4 bytes per pixel (R, G, B, A).
///
/// Example:
/// ```dart
/// final image = thumbHashToRGBA(hash);
/// print('Image size: ${image.width}x${image.height}');
/// print('Total pixels: ${image.rgba.length ~/ 4}');
/// ```
class ThumbHashImage {
  /// The width of the image in pixels.
  final int width;

  /// The height of the image in pixels.
  final int height;

  /// The RGBA pixel data, row-by-row.
  ///
  /// Length is always `width * height * 4`.
  /// Each pixel is 4 consecutive bytes: Red, Green, Blue, Alpha (0-255 each).
  final Uint8List rgba;

  /// Creates a new ThumbHash image.
  const ThumbHashImage({
    required this.width,
    required this.height,
    required this.rgba,
  });

  /// Total number of pixels in the image.
  int get pixelCount => width * height;

  /// Gets a specific pixel's RGBA values as a list [r, g, b, a].
  ///
  /// [x] and [y] are 0-indexed coordinates.
  /// Returns values in range 0-255.
  List<int> getPixel(int x, int y) {
    assert(x >= 0 && x < width, 'x must be in range [0, $width)');
    assert(y >= 0 && y < height, 'y must be in range [0, $height)');
    final i = (y * width + x) * 4;
    return [rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]];
  }

  @override
  String toString() => 'ThumbHashImage(${width}x$height, ${rgba.length} bytes)';
}

/// Represents an RGBA color with values in range 0.0 to 1.0.
///
/// This is the format returned by [thumbHashToAverageRGBA] and matches
/// the original ThumbHash specification.
///
/// Example:
/// ```dart
/// final color = thumbHashToAverageRGBA(hash);
/// print('Average color: R=${color.r}, G=${color.g}, B=${color.b}, A=${color.a}');
/// ```
class ThumbHashColor {
  /// Red component (0.0 to 1.0).
  final double r;

  /// Green component (0.0 to 1.0).
  final double g;

  /// Blue component (0.0 to 1.0).
  final double b;

  /// Alpha component (0.0 to 1.0).
  final double a;

  /// Creates a new ThumbHash color.
  const ThumbHashColor({
    required this.r,
    required this.g,
    required this.b,
    required this.a,
  });

  /// Creates a color with full opacity.
  const ThumbHashColor.opaque({
    required this.r,
    required this.g,
    required this.b,
  }) : a = 1.0;

  /// Converts to 8-bit RGBA values (0-255).
  ///
  /// Returns a list of [r, g, b, a] as integers.
  List<int> toRGBA8() => [
        (r * 255).round().clamp(0, 255),
        (g * 255).round().clamp(0, 255),
        (b * 255).round().clamp(0, 255),
        (a * 255).round().clamp(0, 255),
      ];

  /// Converts to a 32-bit ARGB integer (for use with Flutter Color).
  ///
  /// Format: 0xAARRGGBB
  int toARGB32() {
    final a8 = (a * 255).round().clamp(0, 255);
    final r8 = (r * 255).round().clamp(0, 255);
    final g8 = (g * 255).round().clamp(0, 255);
    final b8 = (b * 255).round().clamp(0, 255);
    return (a8 << 24) | (r8 << 16) | (g8 << 8) | b8;
  }

  @override
  String toString() =>
      'ThumbHashColor(r: ${r.toStringAsFixed(3)}, g: ${g.toStringAsFixed(3)}, '
      'b: ${b.toStringAsFixed(3)}, a: ${a.toStringAsFixed(3)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThumbHashColor &&
          r == other.r &&
          g == other.g &&
          b == other.b &&
          a == other.a;

  @override
  int get hashCode => Object.hash(r, g, b, a);
}
