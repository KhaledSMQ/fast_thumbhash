import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_thumbhash/fast_thumbhash.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThumbHash Decoding', () {
    test('decodes known hash without alpha', () {
      // Known working hash (no alpha)
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      final hash = base64.decode(base64Hash);
      final image = thumbHashToRGBA(Uint8List.fromList(hash));

      expect(image.width, equals(32));
      expect(image.height, equals(23));
      expect(image.rgba.length, equals(32 * 23 * 4));
    });

    test('decodes known hash with alpha', () {
      // Hash with alpha channel
      const base64Hash = '3OiFBQAziIWCjHn3aGpwZ/moB8iHeHR6Zw==';
      final hash = base64.decode(base64Hash);
      final image = thumbHashToRGBA(Uint8List.fromList(hash));

      expect(image.width, equals(32));
      expect(image.height, equals(32));
      expect(image.rgba.length, equals(32 * 32 * 4));
    });

    test('throws on too short hash', () {
      final shortHash = Uint8List.fromList([0x00, 0x01, 0x02]);
      expect(
        () => thumbHashToRGBA(shortHash),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('pixel values are in valid range 0-255', () {
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      final hash = base64.decode(base64Hash);
      final image = thumbHashToRGBA(Uint8List.fromList(hash));

      for (var i = 0; i < image.rgba.length; i++) {
        expect(image.rgba[i], inInclusiveRange(0, 255));
      }
    });

    test('getPixel returns correct values', () {
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      final hash = base64.decode(base64Hash);
      final image = thumbHashToRGBA(Uint8List.fromList(hash));

      // Get first pixel
      final pixel = image.getPixel(0, 0);
      expect(pixel.length, equals(4));
      expect(pixel[0], equals(image.rgba[0])); // R
      expect(pixel[1], equals(image.rgba[1])); // G
      expect(pixel[2], equals(image.rgba[2])); // B
      expect(pixel[3], equals(image.rgba[3])); // A
    });
  });

  group('ThumbHash Average Color', () {
    test('extracts average color from hash without alpha', () {
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      final hash = base64.decode(base64Hash);
      final color = thumbHashToAverageRGBA(Uint8List.fromList(hash));

      expect(color.r, inInclusiveRange(0.0, 1.0));
      expect(color.g, inInclusiveRange(0.0, 1.0));
      expect(color.b, inInclusiveRange(0.0, 1.0));
      expect(color.a, equals(1.0)); // No alpha = fully opaque
    });

    test('extracts average color from hash with alpha', () {
      const base64Hash = '3OiFBQAziIWCjHn3aGpwZ/moB8iHeHR6Zw==';
      final hash = base64.decode(base64Hash);
      final color = thumbHashToAverageRGBA(Uint8List.fromList(hash));

      expect(color.r, inInclusiveRange(0.0, 1.0));
      expect(color.g, inInclusiveRange(0.0, 1.0));
      expect(color.b, inInclusiveRange(0.0, 1.0));
      expect(color.a, inInclusiveRange(0.0, 1.0));
      expect(color.a, lessThan(1.0)); // Has alpha, so < 1
    });

    test('toRGBA8 returns 8-bit values', () {
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      final hash = base64.decode(base64Hash);
      final color = thumbHashToAverageRGBA(Uint8List.fromList(hash));
      final rgba8 = color.toRGBA8();

      expect(rgba8.length, equals(4));
      for (final v in rgba8) {
        expect(v, inInclusiveRange(0, 255));
      }
    });

    test('toARGB32 returns valid 32-bit color', () {
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      final hash = base64.decode(base64Hash);
      final color = thumbHashToAverageRGBA(Uint8List.fromList(hash));
      final argb = color.toARGB32();

      // Extract components
      final a = (argb >> 24) & 0xFF;
      final r = (argb >> 16) & 0xFF;
      final g = (argb >> 8) & 0xFF;
      final b = argb & 0xFF;

      expect(a, equals(255)); // Fully opaque
      expect(r, inInclusiveRange(0, 255));
      expect(g, inInclusiveRange(0, 255));
      expect(b, inInclusiveRange(0, 255));
    });
  });

  group('ThumbHash Aspect Ratio', () {
    test('landscape image has ratio > 1', () {
      // Known landscape hash
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      final hash = base64.decode(base64Hash);
      final ratio = thumbHashToApproximateAspectRatio(Uint8List.fromList(hash));

      expect(ratio, greaterThan(1.0));
    });

    test('square image has ratio = 1', () {
      // Hash with 5x5 dimensions (hasAlpha, not landscape)
      const base64Hash = '3OiFBQAziIWCjHn3aGpwZ/moB8iHeHR6Zw==';
      final hash = base64.decode(base64Hash);
      final ratio = thumbHashToApproximateAspectRatio(Uint8List.fromList(hash));

      expect(ratio, equals(1.0));
    });

    test('isLandscape flag is correct', () {
      final landscapeHash = base64.decode('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
      final squareHash = base64.decode('3OiFBQAziIWCjHn3aGpwZ/moB8iHeHR6Zw==');

      expect((landscapeHash[4] & 0x80) != 0, isTrue);
      expect((squareHash[4] & 0x80) != 0, isFalse);
    });
  });

  group('ThumbHash Encoding', () {
    test('encodes and decodes round-trip', () {
      // Create a simple 8x8 solid color image
      const w = 8, h = 8;
      final rgba = Uint8List(w * h * 4);
      for (var i = 0; i < w * h; i++) {
        rgba[i * 4] = 128; // R
        rgba[i * 4 + 1] = 64; // G
        rgba[i * 4 + 2] = 192; // B
        rgba[i * 4 + 3] = 255; // A (opaque)
      }

      // Encode
      final hash = rgbaToThumbHash(w, h, rgba);
      expect(hash.length, greaterThan(5));

      // Decode
      final decoded = thumbHashToRGBA(hash);
      expect(decoded.width, greaterThan(0));
      expect(decoded.height, greaterThan(0));
    });

    test('encoded hash has correct alpha flag', () {
      const w = 8, h = 8;

      // Image without alpha
      final opaqueRgba = Uint8List(w * h * 4);
      for (var i = 0; i < w * h * 4; i += 4) {
        opaqueRgba[i] = 128;
        opaqueRgba[i + 1] = 64;
        opaqueRgba[i + 2] = 192;
        opaqueRgba[i + 3] = 255; // Fully opaque
      }
      final opaqueHash = rgbaToThumbHash(w, h, opaqueRgba);
      expect((opaqueHash[2] & 0x80) != 0, isFalse); // No alpha

      // Image with alpha
      final alphaRgba = Uint8List(w * h * 4);
      for (var i = 0; i < w * h * 4; i += 4) {
        alphaRgba[i] = 128;
        alphaRgba[i + 1] = 64;
        alphaRgba[i + 2] = 192;
        alphaRgba[i + 3] = 128; // Semi-transparent
      }
      final alphaHash = rgbaToThumbHash(w, h, alphaRgba);
      expect((alphaHash[2] & 0x80) != 0, isTrue); // Has alpha
    });

    test('throws on oversized image', () {
      final bigRgba = Uint8List(101 * 101 * 4);
      expect(
        () => rgbaToThumbHash(101, 101, bigRgba),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on wrong buffer size', () {
      final wrongSize = Uint8List(100);
      expect(
        () => rgbaToThumbHash(10, 10, wrongSize),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('PNG Encoding', () {
    test('produces valid PNG signature', () {
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      final hash = base64.decode(base64Hash);
      final image = thumbHashToRGBA(Uint8List.fromList(hash));
      final png = thumbHashImageToPng(image);

      // PNG signature: 89 50 4E 47 0D 0A 1A 0A
      expect(png[0], equals(0x89));
      expect(png[1], equals(0x50)); // P
      expect(png[2], equals(0x4E)); // N
      expect(png[3], equals(0x47)); // G
      expect(png[4], equals(0x0D));
      expect(png[5], equals(0x0A));
      expect(png[6], equals(0x1A));
      expect(png[7], equals(0x0A));
    });

    test('PNG size is reasonable', () {
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      final hash = base64.decode(base64Hash);
      final image = thumbHashToRGBA(Uint8List.fromList(hash));
      final png = thumbHashImageToPng(image);

      // PNG should be larger than raw RGBA due to headers,
      // but not excessively so (uncompressed)
      expect(png.length, greaterThan(image.rgba.length));
      expect(png.length, lessThan(image.rgba.length * 2));
    });

    test('contains IHDR, IDAT, IEND chunks', () {
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      final hash = base64.decode(base64Hash);
      final image = thumbHashToRGBA(Uint8List.fromList(hash));
      final png = thumbHashImageToPng(image);

      // IHDR chunk type at offset 12
      expect(png[12], equals(0x49)); // I
      expect(png[13], equals(0x48)); // H
      expect(png[14], equals(0x44)); // D
      expect(png[15], equals(0x52)); // R

      // Find IEND chunk (last 12 bytes)
      final iendStart = png.length - 12;
      expect(png[iendStart + 4], equals(0x49)); // I
      expect(png[iendStart + 5], equals(0x45)); // E
      expect(png[iendStart + 6], equals(0x4E)); // N
      expect(png[iendStart + 7], equals(0x44)); // D
    });
  });

  group('ThumbHash Flutter Class', () {
    test('fromBase64 creates valid instance', () {
      final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
      expect(hash.byteLength, greaterThan(0));
    });

    test('fromBytes creates valid instance', () {
      final bytes =
          Uint8List.fromList(base64.decode('3OcRJYB4d3h/iIeHeEh3eIhw+j3A'));
      final hash = ThumbHash.fromBytes(bytes);
      expect(hash.byteLength, equals(bytes.length));
    });

    test('toRGBA returns cached result', () {
      final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
      final image1 = hash.toRGBA();
      final image2 = hash.toRGBA();
      expect(identical(image1, image2), isTrue);
    });

    test('toAspectRatio returns correct value', () {
      final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
      expect(hash.toAspectRatio(), greaterThan(1.0));
      expect(hash.isLandscape, isTrue);
    });

    test('hasAlpha is correct', () {
      final noAlpha = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
      final withAlpha =
          ThumbHash.fromBase64('3OiFBQAziIWCjHn3aGpwZ/moB8iHeHR6Zw==');

      expect(noAlpha.hasAlpha, isFalse);
      expect(withAlpha.hasAlpha, isTrue);
    });

    test('equality works correctly', () {
      final hash1 = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
      final hash2 = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
      final hash3 =
          ThumbHash.fromBase64('3OiFBQAziIWCjHn3aGpwZ/moB8iHeHR6Zw==');

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hash3)));
      expect(hash1.hashCode, equals(hash2.hashCode));
    });

    test('toString provides useful info', () {
      final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
      final str = hash.toString();

      expect(str, contains('ThumbHash'));
      expect(str, contains('bytes'));
      expect(str, contains('aspect'));
    });
  });

  group('ThumbHashColor', () {
    test('equality works', () {
      const color1 = ThumbHashColor(r: 0.5, g: 0.5, b: 0.5, a: 1.0);
      const color2 = ThumbHashColor(r: 0.5, g: 0.5, b: 0.5, a: 1.0);
      const color3 = ThumbHashColor(r: 0.6, g: 0.5, b: 0.5, a: 1.0);

      expect(color1, equals(color2));
      expect(color1, isNot(equals(color3)));
    });

    test('opaque constructor sets alpha to 1.0', () {
      const color = ThumbHashColor.opaque(r: 0.5, g: 0.5, b: 0.5);
      expect(color.a, equals(1.0));
    });
  });

  group('ThumbHashImage', () {
    test('pixelCount is correct', () {
      final image = ThumbHashImage(
        width: 32,
        height: 24,
        rgba: Uint8List(32 * 24 * 4),
      );
      expect(image.pixelCount, equals(32 * 24));
    });

    test('toString provides dimensions', () {
      final image = ThumbHashImage(
        width: 32,
        height: 24,
        rgba: Uint8List(32 * 24 * 4),
      );
      final str = image.toString();
      expect(str, contains('32x24'));
    });
  });

  group('Async Functions', () {
    test('thumbHashToRGBAAsync produces same result as sync', () async {
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      final hash = Uint8List.fromList(base64.decode(base64Hash));

      final syncResult = thumbHashToRGBA(hash);
      final asyncResult = await thumbHashToRGBAAsync(hash);

      expect(asyncResult.width, equals(syncResult.width));
      expect(asyncResult.height, equals(syncResult.height));
      expect(asyncResult.rgba, equals(syncResult.rgba));
    });

    test('rgbaToThumbHashAsync produces same result as sync', () async {
      const w = 8, h = 8;
      final rgba = Uint8List(w * h * 4);
      for (var i = 0; i < w * h; i++) {
        rgba[i * 4] = 128; // R
        rgba[i * 4 + 1] = 64; // G
        rgba[i * 4 + 2] = 192; // B
        rgba[i * 4 + 3] = 255; // A
      }

      final syncResult = rgbaToThumbHash(w, h, rgba);
      final asyncResult = await rgbaToThumbHashAsync(w, h, rgba);

      expect(asyncResult, equals(syncResult));
    });

    test('thumbHashImageToPngAsync produces same result as sync', () async {
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      final hash = Uint8List.fromList(base64.decode(base64Hash));
      final image = thumbHashToRGBA(hash);

      final syncResult = thumbHashImageToPng(image);
      final asyncResult = await thumbHashImageToPngAsync(image);

      expect(asyncResult, equals(syncResult));
    });

    test('ThumbHash.toRGBAAsync produces same result as sync', () async {
      final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');

      final syncResult = hash.toRGBA();
      final asyncResult = await hash.toRGBAAsync();

      expect(asyncResult.width, equals(syncResult.width));
      expect(asyncResult.height, equals(syncResult.height));
      expect(asyncResult.rgba, equals(syncResult.rgba));
    });

    test('ThumbHash.toRGBAAsync caches result', () async {
      final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');

      final result1 = await hash.toRGBAAsync();
      final result2 = await hash.toRGBAAsync();

      expect(identical(result1, result2), isTrue);
    });

    test('ThumbHash.toPngBytesAsync produces same result as sync', () async {
      final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');

      // Use a fresh instance for sync to avoid cache interference
      final hashSync = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
      final syncResult = hashSync.toPngBytes();
      final asyncResult = await hash.toPngBytesAsync();

      expect(asyncResult, equals(syncResult));
    });

    test('ThumbHash.toPngBytesAsync caches result', () async {
      final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');

      final result1 = await hash.toPngBytesAsync();
      final result2 = await hash.toPngBytesAsync();

      expect(identical(result1, result2), isTrue);
    });

    test('ThumbHash.toImageAsync returns MemoryImage', () async {
      final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');

      final imageProvider = await hash.toImageAsync();

      expect(imageProvider, isA<MemoryImage>());
    });

    test('async methods work with alpha channel', () async {
      const base64Hash = '3OiFBQAziIWCjHn3aGpwZ/moB8iHeHR6Zw==';
      final hash = Uint8List.fromList(base64.decode(base64Hash));

      final syncResult = thumbHashToRGBA(hash);
      final asyncResult = await thumbHashToRGBAAsync(hash);

      expect(asyncResult.width, equals(syncResult.width));
      expect(asyncResult.height, equals(syncResult.height));
      expect(asyncResult.rgba, equals(syncResult.rgba));
    });

    test('multiple concurrent async calls work correctly', () async {
      const base64Hash1 = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
      const base64Hash2 = '3OiFBQAziIWCjHn3aGpwZ/moB8iHeHR6Zw==';

      final hash1 = Uint8List.fromList(base64.decode(base64Hash1));
      final hash2 = Uint8List.fromList(base64.decode(base64Hash2));

      // Run multiple async operations concurrently
      final results = await Future.wait([
        thumbHashToRGBAAsync(hash1),
        thumbHashToRGBAAsync(hash2),
        thumbHashToRGBAAsync(hash1),
      ]);

      // Verify results match sync versions
      final sync1 = thumbHashToRGBA(hash1);
      final sync2 = thumbHashToRGBA(hash2);

      expect(results[0].rgba, equals(sync1.rgba));
      expect(results[1].rgba, equals(sync2.rgba));
      expect(results[2].rgba, equals(sync1.rgba));
    });

    test('ThumbHash.fromBase64Async creates valid instance with pre-decoded RGBA', () async {
      const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';

      final hash = await ThumbHash.fromBase64Async(base64Hash);

      // Verify it's equivalent to sync version
      final syncHash = ThumbHash.fromBase64(base64Hash);
      expect(hash.bytes, equals(syncHash.bytes));
      expect(hash.toAspectRatio(), equals(syncHash.toAspectRatio()));
      expect(hash.hasAlpha, equals(syncHash.hasAlpha));

      // RGBA should already be cached (pre-decoded)
      final rgba1 = hash.toRGBA();
      final rgba2 = hash.toRGBA();
      expect(identical(rgba1, rgba2), isTrue);
    });
  });
}
