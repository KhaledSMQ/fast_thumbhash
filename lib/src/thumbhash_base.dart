import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'models.dart';

/// Ultra-fast ThumbHash encoder/decoder.
///
/// ThumbHash is a very compact representation of an image placeholder.
/// It encodes the image's average color and a low-resolution version
/// into a small byte array (typically 25-35 bytes).
///
/// This implementation is optimized for maximum performance:
/// - Separable 2D DCT/IDCT (~5x fewer operations than direct 2D)
/// - Pre-computed cosine values (avoid repeated math.cos calls)
/// - Float64List for better memory layout and cache efficiency
/// - Inlined operations to avoid allocations
/// - Unrolled loops for fixed-size P/Q/A channel coefficients
///
/// Based on the original ThumbHash algorithm by Evan Wallace.
/// See: https://github.com/evanw/thumbhash

// ============================================================================
// DECODE FUNCTIONS
// ============================================================================

/// Decodes a ThumbHash to an RGBA image.
///
/// RGB is not premultiplied by A (straight alpha).
///
/// [hash] is the ThumbHash bytes (typically from base64 decoding).
///
/// Returns a [ThumbHashImage] with width, height, and RGBA pixel data.
/// The output image is always approximately 32 pixels on its largest side.
///
/// Example:
/// ```dart
/// final hash = base64.decode('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
/// final image = thumbHashToRGBA(hash);
/// print('Size: ${image.width}x${image.height}');
/// ```
///
/// Throws [ArgumentError] if the hash is too short or malformed.
ThumbHashImage thumbHashToRGBA(Uint8List hash) {
  if (hash.length < 5) {
    throw ArgumentError('ThumbHash must be at least 5 bytes, got ${hash.length}');
  }

  // Parse header - all inlined for speed
  final header24 = hash[0] | (hash[1] << 8) | (hash[2] << 16);
  final header16 = hash[3] | (hash[4] << 8);

  // Pre-computed division constants for speed
  const inv63 = 0.015873015873015872; // 1/63
  const inv31_5 = 0.031746031746031744; // 1/31.5
  const inv31 = 0.03225806451612903; // 1/31
  const inv15 = 0.06666666666666667; // 1/15
  const inv7_5 = 0.13333333333333333; // 1/7.5

  final lDc = (header24 & 63) * inv63;
  final pDc = ((header24 >> 6) & 63) * inv31_5 - 1.0;
  final qDc = ((header24 >> 12) & 63) * inv31_5 - 1.0;
  final lScale = ((header24 >> 18) & 31) * inv31;
  final hasAlpha = (header24 >> 23) != 0;
  final pScale = ((header16 >> 3) & 63) * inv63 * 1.25;
  final qScale = ((header16 >> 9) & 63) * inv63 * 1.25;
  final isLandscape = (header16 >> 15) != 0;

  final lx = isLandscape ? (hasAlpha ? 5 : 7) : (header16 & 7);
  final ly = isLandscape ? (header16 & 7) : (hasAlpha ? 5 : 7);
  final lxFinal = lx < 3 ? 3 : lx;
  final lyFinal = ly < 3 ? 3 : ly;

  // Calculate required bytes based on header configuration
  final acStart = hasAlpha ? 6 : 5;
  final lAcCount = _countAc(lxFinal, lyFinal);
  // P and Q are always 3x3 = 5 coefficients each
  // A (if hasAlpha) is 5x5 = 14 coefficients
  final totalAcCount = lAcCount + 5 + 5 + (hasAlpha ? 14 : 0);
  final requiredBytes = acStart + ((totalAcCount + 1) >> 1);

  if (hash.length < requiredBytes) {
    throw ArgumentError(
      'ThumbHash is too short: got ${hash.length} bytes, but header indicates '
      '$requiredBytes bytes required (hasAlpha=$hasAlpha, lx=$lx, ly=$ly). '
      'The hash may be truncated or corrupted.',
    );
  }

  final aDc = hasAlpha ? (hash[5] & 15) * inv15 : 1.0;
  final aScale = hasAlpha ? ((hash[5] >> 4) & 15) * inv15 : 0.0;

  // Calculate image dimensions from aspect ratio (inlined, lx/ly already parsed)
  final ratio = lx / ly;
  final w = ratio > 1.0 ? 32 : (32.0 * ratio).round();
  final h = ratio > 1.0 ? (32.0 / ratio).round() : 32;

  // Decode AC coefficients inline - no intermediate objects
  var acIndex = 0;

  // L channel AC
  final lAc = Float64List(lAcCount);
  for (var i = 0; i < lAcCount; i++) {
    final data = hash[acStart + (acIndex >> 1)] >> ((acIndex & 1) << 2);
    lAc[i] = ((data & 15) * inv7_5 - 1.0) * lScale;
    acIndex++;
  }

  // P channel AC (always 5 coefficients for 3x3)
  final pAc = Float64List(5);
  for (var i = 0; i < 5; i++) {
    final data = hash[acStart + (acIndex >> 1)] >> ((acIndex & 1) << 2);
    pAc[i] = ((data & 15) * inv7_5 - 1.0) * pScale;
    acIndex++;
  }

  // Q channel AC (always 5 coefficients for 3x3)
  final qAc = Float64List(5);
  for (var i = 0; i < 5; i++) {
    final data = hash[acStart + (acIndex >> 1)] >> ((acIndex & 1) << 2);
    qAc[i] = ((data & 15) * inv7_5 - 1.0) * qScale;
    acIndex++;
  }

  // A channel AC (14 coefficients for 5x5 if hasAlpha)
  Float64List? aAc;
  if (hasAlpha) {
    aAc = Float64List(14);
    for (var i = 0; i < 14; i++) {
      final data = hash[acStart + (acIndex >> 1)] >> ((acIndex & 1) << 2);
      aAc[i] = ((data & 15) * inv7_5 - 1.0) * aScale;
      acIndex++;
    }
  }

  // Pre-compute all cosine values for X positions only (for separable DCT)
  final wScale = math.pi / w;
  final hScale = math.pi / h;
  final cxStop = lxFinal > (hasAlpha ? 5 : 3) ? lxFinal : (hasAlpha ? 5 : 3);

  final fxAll = Float64List(w * cxStop);
  for (var x = 0; x < w; x++) {
    final xPos = (x + 0.5) * wScale;
    for (var cx = 0; cx < cxStop; cx++) {
      fxAll[x * cxStop + cx] = math.cos(xPos * cx);
    }
  }

  // =========================================================================
  // SEPARABLE IDCT - Pass 1: Pre-compute row sums for each y position
  // This reduces O(W*H*Lx*Ly) to O(H*Lx*Ly + W*H*Lx)
  // =========================================================================

  // L channel: compute intermediate sums for each (y, cx) pair
  // lRowSums[y * lxFinal + cx] = sum over cy of (lAc[j(cx,cy)] * cos(cy*y) * 2)
  final lRowSums = Float64List(h * lxFinal);
  for (var y = 0; y < h; y++) {
    final yPos = (y + 0.5) * hScale;
    final rowBase = y * lxFinal;

    // Build coefficient contributions for this y position
    var j = 0;
    for (var cy = 0; cy < lyFinal; cy++) {
      final fy2 = math.cos(yPos * cy) * 2.0;
      final cxStart = cy > 0 ? 0 : 1;
      for (var cx = cxStart; cx * lyFinal < lxFinal * (lyFinal - cy); cx++) {
        lRowSums[rowBase + cx] += lAc[j++] * fy2;
      }
    }
  }

  // P and Q channels: pre-compute for each y (fixed 3x3 = 5 coefficients)
  // Layout: [y][cx] where cx can be 0, 1, or 2
  final pRowSums = Float64List(h * 3);
  final qRowSums = Float64List(h * 3);
  for (var y = 0; y < h; y++) {
    final yPos = (y + 0.5) * hScale;
    final fy0_2 = math.cos(yPos * 0) * 2.0;
    final fy1_2 = math.cos(yPos * 1) * 2.0;
    final fy2_2 = math.cos(yPos * 2) * 2.0;
    final base = y * 3;

    // cy=0: cx=1,2
    pRowSums[base + 1] += pAc[0] * fy0_2;
    qRowSums[base + 1] += qAc[0] * fy0_2;
    pRowSums[base + 2] += pAc[1] * fy0_2;
    qRowSums[base + 2] += qAc[1] * fy0_2;
    // cy=1: cx=0,1
    pRowSums[base + 0] += pAc[2] * fy1_2;
    qRowSums[base + 0] += qAc[2] * fy1_2;
    pRowSums[base + 1] += pAc[3] * fy1_2;
    qRowSums[base + 1] += qAc[3] * fy1_2;
    // cy=2: cx=0
    pRowSums[base + 0] += pAc[4] * fy2_2;
    qRowSums[base + 0] += qAc[4] * fy2_2;
  }

  // A channel: pre-compute for each y if has alpha (fixed 5x5 = 14 coefficients)
  Float64List? aRowSums;
  if (aAc != null) {
    aRowSums = Float64List(h * 5);
    for (var y = 0; y < h; y++) {
      final yPos = (y + 0.5) * hScale;
      final fy0_2 = math.cos(yPos * 0) * 2.0;
      final fy1_2 = math.cos(yPos * 1) * 2.0;
      final fy2_2 = math.cos(yPos * 2) * 2.0;
      final fy3_2 = math.cos(yPos * 3) * 2.0;
      final fy4_2 = math.cos(yPos * 4) * 2.0;
      final base = y * 5;

      // cy=0: cx=1,2,3,4
      aRowSums[base + 1] += aAc[0] * fy0_2;
      aRowSums[base + 2] += aAc[1] * fy0_2;
      aRowSums[base + 3] += aAc[2] * fy0_2;
      aRowSums[base + 4] += aAc[3] * fy0_2;
      // cy=1: cx=0,1,2,3
      aRowSums[base + 0] += aAc[4] * fy1_2;
      aRowSums[base + 1] += aAc[5] * fy1_2;
      aRowSums[base + 2] += aAc[6] * fy1_2;
      aRowSums[base + 3] += aAc[7] * fy1_2;
      // cy=2: cx=0,1,2
      aRowSums[base + 0] += aAc[8] * fy2_2;
      aRowSums[base + 1] += aAc[9] * fy2_2;
      aRowSums[base + 2] += aAc[10] * fy2_2;
      // cy=3: cx=0,1
      aRowSums[base + 0] += aAc[11] * fy3_2;
      aRowSums[base + 1] += aAc[12] * fy3_2;
      // cy=4: cx=0
      aRowSums[base + 0] += aAc[13] * fy4_2;
    }
  }

  // =========================================================================
  // SEPARABLE IDCT - Pass 2: For each pixel, sum over cx only
  // =========================================================================

  // Output buffer
  final rgba = Uint8List(w * h * 4);

  for (var y = 0, i = 0; y < h; y++) {
    final lRowBase = y * lxFinal;
    final pqRowBase = y * 3;
    final aRowBase = y * 5;

    for (var x = 0; x < w; x++, i += 4) {
      final fxBase = x * cxStop;

      // L channel: sum over cx using pre-computed row sums
      var l = lDc;
      for (var cx = 0; cx < lxFinal; cx++) {
        l += lRowSums[lRowBase + cx] * fxAll[fxBase + cx];
      }

      // P and Q channels: sum over cx (0, 1, 2)
      final fx0 = fxAll[fxBase];
      final fx1 = fxAll[fxBase + 1];
      final fx2 = fxAll[fxBase + 2];

      final p = pDc + pRowSums[pqRowBase] * fx0 +
          pRowSums[pqRowBase + 1] * fx1 +
          pRowSums[pqRowBase + 2] * fx2;
      final q = qDc + qRowSums[pqRowBase] * fx0 +
          qRowSums[pqRowBase + 1] * fx1 +
          qRowSums[pqRowBase + 2] * fx2;

      // A channel: sum over cx (0, 1, 2, 3, 4)
      var a = aDc;
      if (aRowSums != null) {
        final fx3 = fxAll[fxBase + 3];
        final fx4 = fxAll[fxBase + 4];
        a += aRowSums[aRowBase] * fx0 +
            aRowSums[aRowBase + 1] * fx1 +
            aRowSums[aRowBase + 2] * fx2 +
            aRowSums[aRowBase + 3] * fx3 +
            aRowSums[aRowBase + 4] * fx4;
      }

      // Convert LPQ to RGB
      final bVal = l - 0.6666666666666666 * p;
      final rVal = (3.0 * l - bVal + q) * 0.5;
      final gVal = rVal - q;

      // Fast clamp to 0-255
      rgba[i] = _clamp255(rVal);
      rgba[i + 1] = _clamp255(gVal);
      rgba[i + 2] = _clamp255(bVal);
      rgba[i + 3] = _clamp255(a);
    }
  }

  return ThumbHashImage(width: w, height: h, rgba: rgba);
}

/// Extracts the average color from a ThumbHash.
///
/// RGB is not premultiplied by A (straight alpha).
///
/// [hash] is the ThumbHash bytes.
///
/// Returns a [ThumbHashColor] with RGBA values in range 0.0 to 1.0.
///
/// Example:
/// ```dart
/// final color = thumbHashToAverageRGBA(hash);
/// print('Average: R=${color.r}, G=${color.g}, B=${color.b}');
/// ```
ThumbHashColor thumbHashToAverageRGBA(Uint8List hash) {
  if (hash.length < 5) {
    throw ArgumentError('ThumbHash must be at least 5 bytes, got ${hash.length}');
  }

  final header = hash[0] | (hash[1] << 8) | (hash[2] << 16);
  final l = (header & 63) / 63.0;
  final p = ((header >> 6) & 63) / 31.5 - 1.0;
  final q = ((header >> 12) & 63) / 31.5 - 1.0;
  final hasAlpha = (header >> 23) != 0;
  final a = hasAlpha ? (hash[5] & 15) / 15.0 : 1.0;

  final b = l - 2.0 / 3.0 * p;
  final r = (3.0 * l - b + q) / 2.0;
  final g = r - q;

  return ThumbHashColor(
    r: r.clamp(0.0, 1.0),
    g: g.clamp(0.0, 1.0),
    b: b.clamp(0.0, 1.0),
    a: a,
  );
}

/// Extracts the approximate aspect ratio of the original image.
///
/// [hash] is the ThumbHash bytes.
///
/// Returns the aspect ratio (width / height).
/// For example, a 16:9 image returns approximately 1.78.
///
/// Example:
/// ```dart
/// final ratio = thumbHashToApproximateAspectRatio(hash);
/// if (ratio > 1) {
///   print('Landscape image');
/// } else {
///   print('Portrait image');
/// }
/// ```
double thumbHashToApproximateAspectRatio(Uint8List hash) {
  if (hash.length < 5) {
    throw ArgumentError('ThumbHash must be at least 5 bytes, got ${hash.length}');
  }

  final header = hash[3];
  final hasAlpha = (hash[2] & 0x80) != 0;
  final isLandscape = (hash[4] & 0x80) != 0;
  final lx = isLandscape ? (hasAlpha ? 5 : 7) : header & 7;
  final ly = isLandscape ? header & 7 : (hasAlpha ? 5 : 7);
  return lx / ly;
}

// ============================================================================
// ENCODE FUNCTIONS
// ============================================================================

/// Encodes an RGBA image to a ThumbHash.
///
/// RGB should not be premultiplied by A (straight alpha).
///
/// [w] is the width of the input image. Must be <= 100px.
/// [h] is the height of the input image. Must be <= 100px.
/// [rgba] is the pixels in the input image, row-by-row.
/// Must have w*h*4 elements (4 bytes per pixel: R, G, B, A).
///
/// Returns the ThumbHash as a [Uint8List] (typically 25-35 bytes).
///
/// Example:
/// ```dart
/// // Encode a 100x75 image
/// final hash = rgbaToThumbHash(100, 75, pixelData);
/// final base64Hash = base64.encode(hash);
/// ```
///
/// Throws [ArgumentError] if dimensions exceed 100x100 or rgba length is wrong.
Uint8List rgbaToThumbHash(int w, int h, Uint8List rgba) {
  // Validate input
  if (w > 100 || h > 100) {
    throw ArgumentError('Image dimensions ${w}x$h exceed maximum 100x100');
  }
  if (rgba.length != w * h * 4) {
    throw ArgumentError(
        'RGBA buffer length ${rgba.length} does not match ${w}x$h image (expected ${w * h * 4})');
  }

  // Determine the average color
  var avgR = 0.0, avgG = 0.0, avgB = 0.0, avgA = 0.0;
  for (var i = 0, j = 0; i < w * h; i++, j += 4) {
    final alpha = rgba[j + 3] / 255.0;
    avgR += alpha / 255.0 * rgba[j];
    avgG += alpha / 255.0 * rgba[j + 1];
    avgB += alpha / 255.0 * rgba[j + 2];
    avgA += alpha;
  }
  if (avgA > 0) {
    avgR /= avgA;
    avgG /= avgA;
    avgB /= avgA;
  }

  final hasAlpha = avgA < w * h;
  final lLimit = hasAlpha ? 5 : 7;
  final lx = math.max(1, ((lLimit * w) / math.max(w, h)).round());
  final ly = math.max(1, ((lLimit * h) / math.max(w, h)).round());

  // Convert RGBA to LPQA color space
  final l = Float64List(w * h);
  final p = Float64List(w * h);
  final q = Float64List(w * h);
  final a = Float64List(w * h);

  for (var i = 0, j = 0; i < w * h; i++, j += 4) {
    final alpha = rgba[j + 3] / 255.0;
    final r = avgR * (1.0 - alpha) + alpha / 255.0 * rgba[j];
    final g = avgG * (1.0 - alpha) + alpha / 255.0 * rgba[j + 1];
    final b = avgB * (1.0 - alpha) + alpha / 255.0 * rgba[j + 2];
    l[i] = (r + g + b) / 3.0;
    p[i] = (r + g) / 2.0 - b;
    q[i] = r - g;
    a[i] = alpha;
  }

  // Encode channels using DCT
  final lChannel = _encodeChannel(w, h, l, math.max(3, lx), math.max(3, ly));
  final pChannel = _encodeChannel(w, h, p, 3, 3);
  final qChannel = _encodeChannel(w, h, q, 3, 3);
  final aChannel = hasAlpha ? _encodeChannel(w, h, a, 5, 5) : null;

  // Write header
  final isLandscape = w > h;
  final header24 = (63.0 * lChannel.dc).round() |
      ((31.5 + 31.5 * pChannel.dc).round() << 6) |
      ((31.5 + 31.5 * qChannel.dc).round() << 12) |
      ((31.0 * lChannel.scale).round() << 18) |
      (hasAlpha ? 1 << 23 : 0);
  final header16 = (isLandscape ? ly : lx) |
      ((63.0 * pChannel.scale).round() << 3) |
      ((63.0 * qChannel.scale).round() << 9) |
      (isLandscape ? 1 << 15 : 0);

  // Calculate hash size
  final acStart = hasAlpha ? 6 : 5;
  final acCount = lChannel.ac.length +
      pChannel.ac.length +
      qChannel.ac.length +
      (aChannel?.ac.length ?? 0);
  final hash = Uint8List(acStart + (acCount + 1) ~/ 2);

  // Write header bytes
  hash[0] = header24 & 0xFF;
  hash[1] = (header24 >> 8) & 0xFF;
  hash[2] = (header24 >> 16) & 0xFF;
  hash[3] = header16 & 0xFF;
  hash[4] = (header16 >> 8) & 0xFF;
  if (aChannel != null) {
    hash[5] = (15.0 * aChannel.dc).round() |
        ((15.0 * aChannel.scale).round() << 4);
  }

  // Write AC coefficients
  var acIndex = 0;
  acIndex = _writeAc(hash, acStart, acIndex, lChannel.ac);
  acIndex = _writeAc(hash, acStart, acIndex, pChannel.ac);
  acIndex = _writeAc(hash, acStart, acIndex, qChannel.ac);
  if (aChannel != null) {
    _writeAc(hash, acStart, acIndex, aChannel.ac);
  }

  return hash;
}

// ============================================================================
// ASYNC FUNCTIONS
// ============================================================================

/// Decodes a ThumbHash to an RGBA image asynchronously.
///
/// This runs [thumbHashToRGBA] in a separate isolate to avoid blocking
/// the main thread, which is useful for UI applications.
///
/// RGB is not premultiplied by A (straight alpha).
///
/// [hash] is the ThumbHash bytes (typically from base64 decoding).
///
/// Returns a [Future] that completes with a [ThumbHashImage] containing
/// width, height, and RGBA pixel data.
///
/// Example:
/// ```dart
/// final hash = base64.decode('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
/// final image = await thumbHashToRGBAAsync(hash);
/// print('Size: ${image.width}x${image.height}');
/// ```
///
/// Throws [ArgumentError] if the hash is too short or malformed.
Future<ThumbHashImage> thumbHashToRGBAAsync(Uint8List hash) {
  return Isolate.run(() => thumbHashToRGBA(hash));
}

/// Encodes an RGBA image to a ThumbHash asynchronously.
///
/// This runs [rgbaToThumbHash] in a separate isolate to avoid blocking
/// the main thread, which is useful for UI applications.
///
/// RGB should not be premultiplied by A (straight alpha).
///
/// [w] is the width of the input image. Must be <= 100px.
/// [h] is the height of the input image. Must be <= 100px.
/// [rgba] is the pixels in the input image, row-by-row.
/// Must have w*h*4 elements (4 bytes per pixel: R, G, B, A).
///
/// Returns a [Future] that completes with the ThumbHash as a [Uint8List]
/// (typically 25-35 bytes).
///
/// Example:
/// ```dart
/// // Encode a 100x75 image asynchronously
/// final hash = await rgbaToThumbHashAsync(100, 75, pixelData);
/// final base64Hash = base64.encode(hash);
/// ```
///
/// Throws [ArgumentError] if dimensions exceed 100x100 or rgba length is wrong.
Future<Uint8List> rgbaToThumbHashAsync(int w, int h, Uint8List rgba) {
  return Isolate.run(() => rgbaToThumbHash(w, h, rgba));
}

// ============================================================================
// PRIVATE HELPERS
// ============================================================================

/// Fast clamp to 0-255 range.
@pragma('vm:prefer-inline')
int _clamp255(double v) {
  final i = (v * 255.0).toInt();
  return i < 0 ? 0 : (i > 255 ? 255 : i);
}

/// Count AC coefficients for given dimensions.
@pragma('vm:prefer-inline')
int _countAc(int nx, int ny) {
  var n = 0;
  for (var cy = 0; cy < ny; cy++) {
    for (var cx = cy > 0 ? 0 : 1; cx * ny < nx * (ny - cy); cx++) {
      n++;
    }
  }
  return n;
}

/// Encoded channel result.
class _EncodedChannel {
  final double dc;
  final List<double> ac;
  final double scale;

  _EncodedChannel(this.dc, this.ac, this.scale);
}

/// Encode a channel using separable 2D DCT.
/// Reduces complexity from O(W*H*nx*ny) to O(W*H*nx + H*nx*ny).
_EncodedChannel _encodeChannel(
    int w, int h, Float64List channel, int nx, int ny) {
  // Pre-compute ALL cosine values once
  final fxAll = Float64List(w * nx);
  final fyAll = Float64List(h * ny);

  final wScale = math.pi / w;
  for (var x = 0; x < w; x++) {
    final xPos = (x + 0.5) * wScale;
    for (var cx = 0; cx < nx; cx++) {
      fxAll[x * nx + cx] = math.cos(xPos * cx);
    }
  }

  final hScale = math.pi / h;
  for (var y = 0; y < h; y++) {
    final yPos = (y + 0.5) * hScale;
    for (var cy = 0; cy < ny; cy++) {
      fyAll[y * ny + cy] = math.cos(yPos * cy);
    }
  }

  // =========================================================================
  // SEPARABLE DCT - Pass 1: 1D DCT along X for each row
  // intermediate[y][cx] = sum over x of (channel[x,y] * cos(cx*x))
  // Complexity: O(W * H * nx)
  // =========================================================================
  final intermediate = Float64List(h * nx);

  for (var y = 0; y < h; y++) {
    final rowOffset = y * w;
    final intBase = y * nx;
    for (var cx = 0; cx < nx; cx++) {
      var sum = 0.0;
      for (var x = 0; x < w; x++) {
        sum += channel[rowOffset + x] * fxAll[x * nx + cx];
      }
      intermediate[intBase + cx] = sum;
    }
  }

  // =========================================================================
  // SEPARABLE DCT - Pass 2: 1D DCT along Y using intermediate results
  // coeff[cx,cy] = (1/WH) * sum over y of (intermediate[y][cx] * cos(cy*y))
  // Complexity: O(H * nx * ny) - but only for triangular coefficients
  // =========================================================================
  var dc = 0.0;
  final ac = <double>[];
  var scale = 0.0;
  final invWH = 1.0 / (w * h);

  for (var cy = 0; cy < ny; cy++) {
    for (var cx = 0; cx * ny < nx * (ny - cy); cx++) {
      var f = 0.0;
      for (var y = 0; y < h; y++) {
        f += intermediate[y * nx + cx] * fyAll[y * ny + cy];
      }
      f *= invWH;
      if (cx > 0 || cy > 0) {
        ac.add(f);
        scale = math.max(scale, f.abs());
      } else {
        dc = f;
      }
    }
  }

  if (scale > 0) {
    final invScale = 0.5 / scale;
    for (var i = 0; i < ac.length; i++) {
      ac[i] = 0.5 + invScale * ac[i];
    }
  }

  return _EncodedChannel(dc, ac, scale);
}

/// Write AC coefficients to hash.
int _writeAc(Uint8List hash, int start, int index, List<double> ac) {
  for (final v in ac) {
    hash[start + (index >> 1)] |= (15.0 * v).round() << ((index & 1) << 2);
    index++;
  }
  return index;
}
