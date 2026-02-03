// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_thumbhash/fast_thumbhash.dart';
import 'package:flutter/material.dart';

/// Example usage of the fast_thumbhash package.
///
/// This file demonstrates the main features and use cases.

void main() {
  runApp(const ThumbHashExampleApp());
}

/// Example Flutter app demonstrating ThumbHash usage.
class ThumbHashExampleApp extends StatelessWidget {
  const ThumbHashExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fast_thumbhash Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ThumbHashExamplePage(),
    );
  }
}

class ThumbHashExamplePage extends StatelessWidget {
  const ThumbHashExamplePage({super.key});

  // Sample ThumbHash strings (base64 encoded)
  static const sampleHashes = [
    '3OcRJYB4d3h/iIeHeEh3eIhw+j3A', // Landscape, no alpha
    '3OiFBQAziIWCjHn3aGpwZ/moB8iHeHR6Zw==', // Square, with alpha
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('fast_thumbhash Example'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basic usage examples
          _buildSection(
            context,
            'Basic Usage',
            Column(
              children: sampleHashes.map((hash) {
                return _buildBasicExample(context, hash);
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // Natural loading with transitions
          _buildSection(
            context,
            'Natural Loading (ThumbHashPlaceholder)',
            _buildNaturalLoadingExample(context),
          ),

          const SizedBox(height: 24),

          // Custom builder example
          _buildSection(
            context,
            'Custom Builder (ThumbHashImageBuilder)',
            _buildBuilderExample(context),
          ),

          const SizedBox(height: 24),

          // Image loading pattern (manual)
          _buildSection(
            context,
            'Manual Image Loading Pattern',
            _buildImageLoadingExample(context),
          ),

          const SizedBox(height: 24),

          // API demonstration
          _buildSection(
            context,
            'API Features',
            _buildApiExample(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildBasicExample(BuildContext context, String base64Hash) {
    final thumbHash = ThumbHash.fromBase64(base64Hash);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ThumbHash image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 100,
              height: 100 / thumbHash.toAspectRatio(),
              child: Image(
                image: thumbHash.toImage(),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hash: ${base64Hash.substring(0, 20)}...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text('Aspect ratio: ${thumbHash.toAspectRatio().toStringAsFixed(2)}'),
                Text('Has alpha: ${thumbHash.hasAlpha}'),
                Text('Is landscape: ${thumbHash.isLandscape}'),
                const SizedBox(height: 8),
                // Average color swatch
                Row(
                  children: [
                    const Text('Average color: '),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: thumbHash.toAverageColor(),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNaturalLoadingExample(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Automatic smooth transitions from placeholder to loaded image:',
        ),
        const SizedBox(height: 16),

        // Fade transition
        _buildTransitionDemo(
          context,
          'Fade (Default)',
          ThumbHash.fromBase64(sampleHashes[0]),
          TransitionConfig.fast,
        ),
        const SizedBox(height: 12),

        // Blur to sharp
        _buildTransitionDemo(
          context,
          'Blur to Sharp',
          ThumbHash.fromBase64(sampleHashes[0]),
          TransitionConfig.blur,
        ),
        const SizedBox(height: 12),

        // Scale up
        _buildTransitionDemo(
          context,
          'Scale Up',
          ThumbHash.fromBase64(sampleHashes[1]),
          TransitionConfig.scale,
        ),
        const SizedBox(height: 12),

        // Smooth
        _buildTransitionDemo(
          context,
          'Smooth (400ms)',
          ThumbHash.fromBase64(sampleHashes[1]),
          TransitionConfig.smooth,
        ),
      ],
    );
  }

  Widget _buildTransitionDemo(
    BuildContext context,
    String label,
    ThumbHash thumbHash,
    TransitionConfig config,
  ) {
    // Use a random image URL with cache-busting to simulate loading
    final imageUrl =
        'https://picsum.photos/seed/${label.hashCode}/300/200';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${config.type.name}, ${config.duration.inMilliseconds}ms',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 120,
            height: 80,
            child: ThumbHashPlaceholder(
              thumbHash: thumbHash,
              image: NetworkImage(imageUrl),
              transition: config,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBuilderExample(BuildContext context) {
    final thumbHash = ThumbHash.fromBase64(sampleHashes[0]);
    const imageUrl = 'https://picsum.photos/seed/builder/400/300';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Full control with ThumbHashImageBuilder:',
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: ThumbHashImageBuilder(
              thumbHash: thumbHash,
              image: const NetworkImage(imageUrl),
              transition: TransitionConfig.smooth,
              onLoaded: () {
                // Called when image loads
              },
              onError: (error, stackTrace) {
                // Handle error
              },
              builder: (context, state) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background with average color
                    Container(color: thumbHash.toAverageColor()),

                    // Placeholder image
                    Opacity(
                      opacity: 1.0 - state.progress * 0.5,
                      child: Image(
                        image: state.placeholderImage,
                        fit: BoxFit.cover,
                      ),
                    ),

                    // Loaded image fades in
                    if (state.isLoaded && state.loadedImageInfo != null)
                      Opacity(
                        opacity: state.progress,
                        child: RawImage(
                          image: state.loadedImageInfo!.image,
                          fit: BoxFit.cover,
                        ),
                      ),

                    // Loading indicator
                    if (!state.isLoaded && !state.hasError)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),

                    // Error state
                    if (state.hasError)
                      const Center(
                        child: Icon(Icons.error, color: Colors.red, size: 48),
                      ),

                    // Progress indicator
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          state.isLoaded
                              ? 'Loaded (${(state.progress * 100).toInt()}%)'
                              : 'Loading...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageLoadingExample(BuildContext context) {
    final thumbHash = ThumbHash.fromBase64(sampleHashes[0]);
    const imageUrl = 'https://picsum.photos/seed/manual/400/300';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manual implementation with Stack (for reference):',
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: thumbHash.toAspectRatio(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ThumbHash placeholder
                Image(image: thumbHash.toImage(), fit: BoxFit.cover),
                // Network image
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      // Loading complete
                      return child;
                    }
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) {
                    return const Center(child: Icon(Icons.error));
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApiExample(BuildContext context) {
    final hash = ThumbHash.fromBase64(sampleHashes[0]);
    final image = hash.toRGBA();
    final color = hash.toAverageRGBA();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCodeExample(
          'ThumbHash.fromBase64()',
          "final hash = ThumbHash.fromBase64('3OcRJYB4...');",
        ),
        _buildCodeExample(
          'toRGBA()',
          'final image = hash.toRGBA();\n'
              '// width: ${image.width}, height: ${image.height}\n'
              '// pixels: ${image.pixelCount}',
        ),
        _buildCodeExample(
          'toAverageRGBA()',
          'final color = hash.toAverageRGBA();\n'
              '// r: ${color.r.toStringAsFixed(3)}, g: ${color.g.toStringAsFixed(3)}\n'
              '// b: ${color.b.toStringAsFixed(3)}, a: ${color.a.toStringAsFixed(3)}',
        ),
        _buildCodeExample(
          'toAspectRatio()',
          'final ratio = hash.toAspectRatio();\n'
              '// ratio: ${hash.toAspectRatio().toStringAsFixed(2)}',
        ),
      ],
    );
  }

  Widget _buildCodeExample(String title, String code) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Pure Dart Examples (no Flutter required)
// =============================================================================

/// Demonstrates pure Dart usage without Flutter.
void pureDartExample() {
  print('=== Pure Dart ThumbHash Example ===\n');

  // Decode a ThumbHash
  const base64Hash = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
  final hashBytes = Uint8List.fromList(base64.decode(base64Hash));

  // Get image dimensions and pixels
  final image = thumbHashToRGBA(hashBytes);
  print('Decoded image: ${image.width}x${image.height}');
  print('Total pixels: ${image.pixelCount}');
  print('Buffer size: ${image.rgba.length} bytes\n');

  // Get average color
  final color = thumbHashToAverageRGBA(hashBytes);
  print('Average color:');
  print('  R: ${(color.r * 255).round()}');
  print('  G: ${(color.g * 255).round()}');
  print('  B: ${(color.b * 255).round()}');
  print('  A: ${(color.a * 255).round()}\n');

  // Get aspect ratio
  final ratio = thumbHashToApproximateAspectRatio(hashBytes);
  print('Aspect ratio: ${ratio.toStringAsFixed(2)}');
  print('Orientation: ${ratio > 1 ? "landscape" : "portrait"}\n');

  // Encode to PNG
  final png = thumbHashImageToPng(image);
  print('PNG size: ${png.length} bytes');
  print('PNG signature valid: ${png[0] == 0x89 && png[1] == 0x50}');
}

/// Demonstrates encoding an image to ThumbHash.
void encodingExample() {
  print('\n=== ThumbHash Encoding Example ===\n');

  // Create a simple 32x32 gradient image
  const w = 32, h = 32;
  final rgba = Uint8List(w * h * 4);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      rgba[i] = (x * 255 ~/ w); // R: horizontal gradient
      rgba[i + 1] = (y * 255 ~/ h); // G: vertical gradient
      rgba[i + 2] = 128; // B: constant
      rgba[i + 3] = 255; // A: fully opaque
    }
  }

  // Encode to ThumbHash
  final hash = rgbaToThumbHash(w, h, rgba);
  final base64Hash = base64.encode(hash);

  print('Input image: ${w}x$h');
  print('ThumbHash size: ${hash.length} bytes');
  print('Base64: $base64Hash');

  // Verify by decoding
  final decoded = thumbHashToRGBA(hash);
  print('Decoded size: ${decoded.width}x${decoded.height}');
}
