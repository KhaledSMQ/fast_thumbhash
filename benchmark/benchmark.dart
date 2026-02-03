// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';

// Import only pure Dart parts (not Flutter)
import '../lib/src/thumbhash_base.dart';
import '../lib/src/png_encoder.dart';

/// Performance benchmark for fast_thumbhash.
///
/// Run with: dart run benchmark/benchmark.dart
void main() {
  const iterations = 10000;

  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                  fast_thumbhash Performance Benchmark            ║');
  print('╠══════════════════════════════════════════════════════════════════╣');
  print('║  Iterations per test: $iterations                                    ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
  print('');

  // Test cases
  final testCases = <String, String>{
    'Landscape (no alpha)': '3OcRJYB4d3h/iIeHeEh3eIhw+j3A',
    'Square (with alpha)': '3OiFBQAziIWCjHn3aGpwZ/moB8iHeHR6Zw==',
  };

  for (final entry in testCases.entries) {
    _benchmarkHash(entry.key, entry.value, iterations);
  }

  print('');
  _benchmarkEncoding(iterations ~/ 10); // Encoding is slower, use fewer iterations

  print('');
  print('╔══════════════════════════════════════════════════════════════════╗');
  print('║                         Benchmark Complete                       ║');
  print('╚══════════════════════════════════════════════════════════════════╝');
}

void _benchmarkHash(String name, String base64Hash, int iterations) {
  final hash = Uint8List.fromList(base64.decode(base64Hash));
  final hasAlpha = (hash[2] & 0x80) != 0;

  print('┌──────────────────────────────────────────────────────────────────┐');
  print('│ $name'.padRight(68) + '│');
  final displayHash = base64Hash.length > 25 ? '${base64Hash.substring(0, 25)}...' : base64Hash;
  print('│ Hash: $displayHash'.padRight(68) + '│');
  print('│ Has Alpha: $hasAlpha'.padRight(68) + '│');
  print('├──────────────────────────────────────────────────────────────────┤');

  // Warmup
  for (var i = 0; i < 100; i++) {
    thumbHashToRGBA(hash);
    thumbHashToAverageRGBA(hash);
    thumbHashToApproximateAspectRatio(hash);
  }

  // Benchmark decode
  final decodeStart = DateTime.now();
  for (var i = 0; i < iterations; i++) {
    thumbHashToRGBA(hash);
  }
  final decodeTime = DateTime.now().difference(decodeStart).inMicroseconds;
  final decodePerOp = decodeTime / iterations;

  // Benchmark PNG encoding
  final image = thumbHashToRGBA(hash);
  final pngStart = DateTime.now();
  for (var i = 0; i < iterations; i++) {
    thumbHashImageToPng(image);
  }
  final pngTime = DateTime.now().difference(pngStart).inMicroseconds;
  final pngPerOp = pngTime / iterations;

  // Benchmark average color
  final colorStart = DateTime.now();
  for (var i = 0; i < iterations; i++) {
    thumbHashToAverageRGBA(hash);
  }
  final colorTime = DateTime.now().difference(colorStart).inMicroseconds;
  final colorPerOp = colorTime / iterations;

  // Benchmark aspect ratio
  final ratioStart = DateTime.now();
  for (var i = 0; i < iterations; i++) {
    thumbHashToApproximateAspectRatio(hash);
  }
  final ratioTime = DateTime.now().difference(ratioStart).inMicroseconds;
  final ratioPerOp = ratioTime / iterations;

  // Total pipeline
  final totalStart = DateTime.now();
  for (var i = 0; i < iterations; i++) {
    final img = thumbHashToRGBA(hash);
    thumbHashImageToPng(img);
  }
  final totalTime = DateTime.now().difference(totalStart).inMicroseconds;
  final totalPerOp = totalTime / iterations;

  print('│ thumbHashToRGBA():          ${decodePerOp.toStringAsFixed(1).padLeft(8)} μs/op'.padRight(68) + '│');
  print('│ thumbHashImageToPng():      ${pngPerOp.toStringAsFixed(1).padLeft(8)} μs/op'.padRight(68) + '│');
  print('│ thumbHashToAverageRGBA():   ${colorPerOp.toStringAsFixed(1).padLeft(8)} μs/op'.padRight(68) + '│');
  print('│ thumbHashToAspectRatio():   ${ratioPerOp.toStringAsFixed(1).padLeft(8)} μs/op'.padRight(68) + '│');
  print('├──────────────────────────────────────────────────────────────────┤');
  print('│ Total Pipeline (decode+png): ${totalPerOp.toStringAsFixed(1).padLeft(7)} μs/op'.padRight(68) + '│');
  print('│ Throughput: ${(1000000 / totalPerOp).toStringAsFixed(0).padLeft(7)} images/sec'.padRight(68) + '│');
  print('└──────────────────────────────────────────────────────────────────┘');
  print('');
}

void _benchmarkEncoding(int iterations) {
  print('┌──────────────────────────────────────────────────────────────────┐');
  print('│ Encoding Benchmark (rgbaToThumbHash)'.padRight(68) + '│');
  print('├──────────────────────────────────────────────────────────────────┤');

  // Create test images
  final sizes = [
    [32, 32],
    [64, 48],
    [100, 75],
  ];

  for (final size in sizes) {
    final w = size[0];
    final h = size[1];
    final rgba = _createTestImage(w, h);

    // Warmup
    for (var i = 0; i < 10; i++) {
      rgbaToThumbHash(w, h, rgba);
    }

    // Benchmark
    final start = DateTime.now();
    for (var i = 0; i < iterations; i++) {
      rgbaToThumbHash(w, h, rgba);
    }
    final elapsed = DateTime.now().difference(start).inMicroseconds;
    final perOp = elapsed / iterations;

    print('│ ${w}x$h image: ${perOp.toStringAsFixed(1).padLeft(10)} μs/op'.padRight(68) + '│');
  }

  print('└──────────────────────────────────────────────────────────────────┘');
}

Uint8List _createTestImage(int w, int h) {
  final rgba = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      // Gradient pattern
      rgba[i] = (x * 255 ~/ w); // R
      rgba[i + 1] = (y * 255 ~/ h); // G
      rgba[i + 2] = 128; // B
      rgba[i + 3] = 255; // A
    }
  }
  return rgba;
}
