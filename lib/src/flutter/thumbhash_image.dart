import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../models.dart';
import '../png_encoder.dart';
import '../thumbhash_base.dart';

/// A Flutter-friendly wrapper for ThumbHash operations.
///
/// This class provides a convenient way to work with ThumbHash in Flutter
/// applications. It can decode ThumbHash bytes and provide:
/// - An [ImageProvider] for use with Flutter's [Image] widget
/// - The average color of the image
/// - The approximate aspect ratio
///
/// Example usage:
/// ```dart
/// // From base64 string (most common)
/// final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
///
/// // Use in a Flutter widget
/// Image(image: hash.toImage())
///
/// // Get the average color for a background
/// final color = hash.toAverageColor();
/// Container(color: color)
/// ```
class ThumbHash {
  /// The raw ThumbHash bytes.
  final Uint8List _data;

  /// Cached decoded image (lazy initialization).
  ThumbHashImage? _cachedImage;

  /// Cached PNG bytes (lazy initialization).
  Uint8List? _cachedPng;

  /// Creates a ThumbHash from raw bytes.
  ///
  /// [bytes] should be the decoded ThumbHash (typically 25-35 bytes).
  ///
  /// Example:
  /// ```dart
  /// final bytes = Uint8List.fromList([0xDC, 0xE7, ...]);
  /// final hash = ThumbHash.fromBytes(bytes);
  /// ```
  ThumbHash.fromBytes(TypedData bytes) : _data = bytes.buffer.asUint8List();

  /// Creates a ThumbHash from a list of integers.
  ///
  /// [list] should contain the ThumbHash byte values (0-255).
  ///
  /// Example:
  /// ```dart
  /// final list = [0xDC, 0xE7, 0x11, 0x25, ...];
  /// final hash = ThumbHash.fromIntList(list);
  /// ```
  ThumbHash.fromIntList(List<int> list) : _data = Uint8List.fromList(list);

  /// Creates a ThumbHash from a base64-encoded string.
  ///
  /// This is the most common way to create a ThumbHash, as base64
  /// is typically used to store and transmit ThumbHash data.
  ///
  /// [encoded] is the base64 string (standard or URL-safe encoding).
  ///
  /// Example:
  /// ```dart
  /// final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
  /// ```
  factory ThumbHash.fromBase64(String encoded) {
    return ThumbHash.fromBytes(base64.decode(base64.normalize(encoded)));
  }

  /// Creates a ThumbHash from a base64-encoded string asynchronously.
  ///
  /// This method decodes the base64 string and pre-decodes the RGBA data
  /// in a separate isolate, so the ThumbHash is ready to use immediately
  /// without blocking the main thread.
  ///
  /// [encoded] is the base64 string (standard or URL-safe encoding).
  ///
  /// Example:
  /// ```dart
  /// final hash = await ThumbHash.fromBase64Async('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
  /// // RGBA is already decoded, toImage() is instant
  /// Image(image: hash.toImage())
  /// ```
  static Future<ThumbHash> fromBase64Async(String encoded) async {
    final bytes = base64.decode(base64.normalize(encoded));
    final hash = ThumbHash.fromBytes(bytes);
    // Pre-decode RGBA in isolate so it's cached and ready
    await hash.toRGBAAsync();
    return hash;
  }

  /// Gets the raw ThumbHash bytes.
  ///
  /// This can be useful for serialization or comparison.
  Uint8List get bytes => _data;

  /// Decodes the ThumbHash to RGBA pixel data.
  ///
  /// Returns a [ThumbHashImage] with width, height, and RGBA pixel data.
  /// The result is cached for subsequent calls.
  ///
  /// Example:
  /// ```dart
  /// final image = hash.toRGBA();
  /// print('Decoded size: ${image.width}x${image.height}');
  /// ```
  ThumbHashImage toRGBA() {
    return _cachedImage ??= thumbHashToRGBA(_data);
  }

  /// Creates an [ImageProvider] for use with Flutter's [Image] widget.
  ///
  /// This is the primary way to display a ThumbHash placeholder in Flutter.
  /// The result is a small PNG image (typically 32x32 pixels or smaller).
  ///
  /// Example:
  /// ```dart
  /// Image(
  ///   image: hash.toImage(),
  ///   fit: BoxFit.cover,
  /// )
  /// ```
  ImageProvider toImage() {
    _cachedPng ??= thumbHashImageToPng(toRGBA());
    return MemoryImage(_cachedPng!);
  }

  /// Gets the PNG bytes for the decoded ThumbHash image.
  ///
  /// This can be useful if you need to save or transmit the decoded image.
  /// The result is cached for subsequent calls.
  ///
  /// Example:
  /// ```dart
  /// final pngBytes = hash.toPngBytes();
  /// await File('placeholder.png').writeAsBytes(pngBytes);
  /// ```
  Uint8List toPngBytes() {
    return _cachedPng ??= thumbHashImageToPng(toRGBA());
  }

  // ==========================================================================
  // ASYNC METHODS
  // ==========================================================================

  /// Decodes the ThumbHash to RGBA pixel data asynchronously.
  ///
  /// This runs the decoding in a separate isolate to avoid blocking
  /// the main thread, which is useful for UI applications.
  ///
  /// Returns a [Future] that completes with a [ThumbHashImage] containing
  /// width, height, and RGBA pixel data.
  /// The result is cached for subsequent calls (both sync and async).
  ///
  /// Example:
  /// ```dart
  /// final image = await hash.toRGBAAsync();
  /// print('Decoded size: ${image.width}x${image.height}');
  /// ```
  Future<ThumbHashImage> toRGBAAsync() async {
    if (_cachedImage != null) return _cachedImage!;
    _cachedImage = await thumbHashToRGBAAsync(_data);
    return _cachedImage!;
  }

  /// Gets the PNG bytes for the decoded ThumbHash image asynchronously.
  ///
  /// This runs both the decoding and PNG encoding in separate isolates
  /// to avoid blocking the main thread.
  ///
  /// The result is cached for subsequent calls (both sync and async).
  ///
  /// Example:
  /// ```dart
  /// final pngBytes = await hash.toPngBytesAsync();
  /// await File('placeholder.png').writeAsBytes(pngBytes);
  /// ```
  Future<Uint8List> toPngBytesAsync() async {
    if (_cachedPng != null) return _cachedPng!;
    final image = await toRGBAAsync();
    _cachedPng = await thumbHashImageToPngAsync(image);
    return _cachedPng!;
  }

  /// Creates an [ImageProvider] for use with Flutter's [Image] widget asynchronously.
  ///
  /// This runs the decoding and PNG encoding in separate isolates
  /// to avoid blocking the main thread.
  ///
  /// Example:
  /// ```dart
  /// final imageProvider = await hash.toImageAsync();
  /// Image(
  ///   image: imageProvider,
  ///   fit: BoxFit.cover,
  /// )
  /// ```
  Future<ImageProvider> toImageAsync() async {
    final png = await toPngBytesAsync();
    return MemoryImage(png);
  }

  /// Gets the average color of the image as a Flutter [Color].
  ///
  /// This is useful for setting a background color while the actual
  /// image is loading, or for extracting the dominant color.
  ///
  /// Example:
  /// ```dart
  /// Container(
  ///   color: hash.toAverageColor(),
  ///   child: Image(image: hash.toImage()),
  /// )
  /// ```
  Color toAverageColor() {
    final rgba = thumbHashToAverageRGBA(_data);
    return Color.fromARGB(
      (rgba.a * 255).round(),
      (rgba.r * 255).round(),
      (rgba.g * 255).round(),
      (rgba.b * 255).round(),
    );
  }

  /// Gets the average color as a [ThumbHashColor] (0.0-1.0 range).
  ///
  /// This is the raw color data without Flutter-specific conversion.
  ///
  /// Example:
  /// ```dart
  /// final color = hash.toAverageRGBA();
  /// print('Average luminance: ${(color.r + color.g + color.b) / 3}');
  /// ```
  ThumbHashColor toAverageRGBA() {
    return thumbHashToAverageRGBA(_data);
  }

  /// Gets the approximate aspect ratio of the original image.
  ///
  /// Returns width / height. For example:
  /// - 16:9 landscape returns ~1.78
  /// - 1:1 square returns 1.0
  /// - 9:16 portrait returns ~0.56
  ///
  /// Example:
  /// ```dart
  /// final ratio = hash.toAspectRatio();
  /// AspectRatio(
  ///   aspectRatio: ratio,
  ///   child: Image(image: hash.toImage(), fit: BoxFit.cover),
  /// )
  /// ```
  double toAspectRatio() {
    return thumbHashToApproximateAspectRatio(_data);
  }

  /// Whether the original image has an alpha channel (transparency).
  bool get hasAlpha => (_data[2] & 0x80) != 0;

  /// Whether the original image is landscape orientation.
  bool get isLandscape => (_data[4] & 0x80) != 0;

  /// Whether the original image is portrait orientation.
  bool get isPortrait => !isLandscape && toAspectRatio() < 1.0;

  /// The size of the ThumbHash data in bytes.
  int get byteLength => _data.length;

  @override
  String toString() {
    final ratio = toAspectRatio();
    return 'ThumbHash(${_data.length} bytes, '
        'aspect: ${ratio.toStringAsFixed(2)}, '
        'hasAlpha: $hasAlpha)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThumbHash && _bytesEqual(_data, other._data);

  @override
  int get hashCode => Object.hashAll(_data);

  /// Compares two byte arrays for equality.
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
