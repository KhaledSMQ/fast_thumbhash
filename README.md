# fast_thumbhash

[![pub package](https://img.shields.io/pub/v/fast_thumbhash.svg)](https://pub.dev/packages/fast_thumbhash)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ultra-fast [ThumbHash](https://evanw.github.io/thumbhash/) encoder/decoder for Dart and Flutter.

ThumbHash is a very compact representation of an image placeholder. It encodes the image's average color and a low-resolution version into a small byte array (typically 25-35 bytes), perfect for storing inline with your data and showing while the real image loads.

## Features

- **Ultra-fast decoding** - 7x faster than naive implementation using separable 2D IDCT
- **Fast PNG encoding** - 1.6x faster with batched Adler-32 and 256-entry CRC table
- **Full alpha support** - Images with transparency work correctly
- **Natural loading transitions** - Smooth fade, blur-to-sharp, and scale effects
- **Complete API** - All ThumbHash operations supported
- **Zero dependencies** - Pure Dart implementation
- **Well documented** - Comprehensive dartdoc comments

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  fast_thumbhash: ^1.0.0
```

## Quick Start

### Flutter Usage

```dart
import 'package:fast_thumbhash/fast_thumbhash.dart';
import 'package:flutter/material.dart';

// Create from base64 string (most common)
final thumbHash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');

// Use in a Flutter Image widget
Image(
  image: thumbHash.toImage(),
  fit: BoxFit.cover,
)

// Get the average color for a background
Container(
  color: thumbHash.toAverageColor(),
  child: Image(image: thumbHash.toImage()),
)

// Maintain aspect ratio
AspectRatio(
  aspectRatio: thumbHash.toAspectRatio(),
  child: Image(image: thumbHash.toImage(), fit: BoxFit.cover),
)
```

### Natural Image Loading

Use `ThumbHashPlaceholder` for automatic smooth transitions from placeholder to loaded image:

```dart
// Simple fade transition (default)
ThumbHashPlaceholder(
  thumbHash: ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A'),
  image: NetworkImage('https://example.com/photo.jpg'),
)

// Blur-to-sharp transition
ThumbHashPlaceholder(
  thumbHash: thumbHash,
  image: NetworkImage(url),
  transition: TransitionConfig.blur,
)

// Scale-up transition
ThumbHashPlaceholder(
  thumbHash: thumbHash,
  image: NetworkImage(url),
  transition: TransitionConfig.scale,
)

// Custom transition
ThumbHashPlaceholder(
  thumbHash: thumbHash,
  image: NetworkImage(url),
  transition: TransitionConfig(
    type: ThumbHashTransition.fade,
    duration: Duration(milliseconds: 500),
    curve: Curves.easeInOut,
  ),
)
```

### Custom Image Loading with Builder

For full control over the loading experience, use `ThumbHashImageBuilder`:

```dart
ThumbHashImageBuilder(
  thumbHash: thumbHash,
  image: NetworkImage(url),
  transition: TransitionConfig.smooth,
  builder: (context, state) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Placeholder with fade based on progress
        Opacity(
          opacity: 1.0 - state.progress,
          child: Image(image: state.placeholderImage, fit: BoxFit.cover),
        ),
        // Loaded image fades in
        if (state.isLoaded)
          Opacity(
            opacity: state.progress,
            child: RawImage(image: state.loadedImageInfo!.image, fit: BoxFit.cover),
          ),
        // Loading indicator
        if (!state.isLoaded && !state.hasError)
          Center(child: CircularProgressIndicator()),
      ],
    );
  },
)
```

### Transition Presets

| Preset | Effect | Duration |
|--------|--------|----------|
| `TransitionConfig.fast` | Fade | 200ms |
| `TransitionConfig.smooth` | Fade | 400ms |
| `TransitionConfig.blur` | Blur-to-sharp | 400ms |
| `TransitionConfig.scale` | Scale-up | 350ms |
| `TransitionConfig.instant` | No animation | 0ms |

## API Reference

### ThumbHash Class (Flutter)

The main class for Flutter applications:

```dart
// Create from different sources
ThumbHash.fromBase64(String encoded);
ThumbHash.fromBytes(Uint8List bytes);
ThumbHash.fromIntList(List<int> list);

// Methods
ImageProvider toImage();         // For Flutter Image widget
Color toAverageColor();          // Get average color as Flutter Color
ThumbHashColor toAverageRGBA();  // Get average color (0.0-1.0)
double toAspectRatio();          // Get width/height ratio
ThumbHashImage toRGBA();         // Get raw RGBA pixel data
Uint8List toPngBytes();          // Get PNG file bytes

// Properties
bool hasAlpha;                   // Whether image has transparency
bool isLandscape;                // Whether width > height
int byteLength;                  // Size of ThumbHash data
```

### Core Functions

For lower-level access or pure Dart usage:

```dart
// Decode ThumbHash to RGBA image
ThumbHashImage thumbHashToRGBA(Uint8List hash);

// Encode RGBA image to ThumbHash (max 100x100 pixels)
Uint8List rgbaToThumbHash(int width, int height, Uint8List rgba);

// Extract average color
ThumbHashColor thumbHashToAverageRGBA(Uint8List hash);

// Get approximate aspect ratio
double thumbHashToApproximateAspectRatio(Uint8List hash);

// Encode image to PNG
Uint8List thumbHashImageToPng(ThumbHashImage image);
```

### Data Models

```dart
// Decoded image data
class ThumbHashImage {
  final int width;
  final int height;
  final Uint8List rgba;  // 4 bytes per pixel: R, G, B, A
}

// Color with 0.0-1.0 range
class ThumbHashColor {
  final double r, g, b, a;
  
  List<int> toRGBA8();   // Convert to 0-255 range
  int toARGB32();        // Convert to 0xAARRGGBB format
}
```

## Encoding Images

To generate ThumbHash from an image, you need to:

1. Resize the image to max 100x100 pixels
2. Extract RGBA pixel data
3. Call `rgbaToThumbHash()`

```dart
// Example with dart:ui (Flutter)
import 'dart:ui' as ui;

Future<Uint8List> generateThumbHash(ui.Image image) async {
  // Resize to max 100x100 while preserving aspect ratio
  final maxSize = 100;
  final scale = maxSize / max(image.width, image.height);
  final w = (image.width * scale).round();
  final h = (image.height * scale).round();
  
  // Get RGBA bytes
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgba = byteData!.buffer.asUint8List();
  
  return rgbaToThumbHash(w, h, rgba);
}
```

## Performance

Benchmarked on Apple M1:

| Operation | Time | Throughput |
|-----------|------|------------|
| Decode (thumbHashToRGBA) | ~12-17 μs | 60,000-80,000/sec |
| PNG encode (thumbHashImageToPng) | ~13-20 μs | 50,000-75,000/sec |
| Average color (thumbHashToAverageRGBA) | ~0.2 μs | 5,000,000/sec |
| Aspect ratio | ~0.05 μs | 20,000,000/sec |
| **Full pipeline (decode + PNG)** | **~26-38 μs** | **26,000-39,000/sec** |

### Optimizations

This implementation uses several algorithmic optimizations:

- **Separable 2D DCT/IDCT** - Reduces complexity from O(W×H×Lx×Ly) to O(H×Lx×Ly + W×H×Lx), yielding ~5-7x fewer operations
- **Pre-computed cosine tables** - Eliminates redundant `cos()` calls
- **Batched Adler-32** - Modulo every 5552 bytes instead of every byte
- **256-entry CRC-32 table** - Single lookup per byte instead of two

Run the benchmark yourself:

```bash
cd fast_thumbhash
dart run benchmark/benchmark.dart
```

## Comparison with BlurHash

ThumbHash has several advantages over BlurHash:

| Feature | ThumbHash | BlurHash |
|---------|-----------|----------|
| Encodes aspect ratio | ✅ | ❌ |
| Alpha channel support | ✅ | ❌ |
| More accurate colors | ✅ | ❌ |
| More detail per byte | ✅ | ❌ |
| Configurable parameters | ❌ | ✅ |

## Credits

- **ThumbHash algorithm** by [Evan Wallace](https://github.com/evanw/thumbhash)
- **Dart implementation** by [Khaled Sameer](https://khaled.ee) - optimized for maximum performance

## License

MIT License - see [LICENSE](LICENSE) file.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

**Khaled Sameer** - [khaled.ee](https://khaled.ee) - [GitHub](https://github.com/KhaledSMQ)
