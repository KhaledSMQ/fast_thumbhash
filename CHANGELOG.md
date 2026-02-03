# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-03

### Changed

- **BREAKING**: `ThumbHashPlaceholder.errorWidget` is now `errorBuilder` with signature `Widget Function(BuildContext context, Object error, StackTrace? stackTrace)`. This provides access to the error details and build context for better error handling.

### Added

- `ImageErrorWidgetBuilder` typedef for the error builder function

## [1.0.0] - 2026-02-03

### Added

- Initial release of fast_thumbhash
- Ultra-fast ThumbHash decoder (7x faster than naive implementation)
- Fast PNG encoder with pre-allocated buffers (1.6x faster)
- Full ThumbHash API support:
  - `thumbHashToRGBA()` - Decode ThumbHash to RGBA image
  - `rgbaToThumbHash()` - Encode RGBA image to ThumbHash
  - `thumbHashToAverageRGBA()` - Extract average color
  - `thumbHashToApproximateAspectRatio()` - Get aspect ratio
- Flutter `ThumbHash` convenience class with:
  - `ThumbHash.fromBase64()` - Create from base64 string
  - `ThumbHash.fromBytes()` - Create from raw bytes
  - `toImage()` - Get Flutter `ImageProvider`
  - `toAverageColor()` - Get average color as Flutter `Color`
  - `toAspectRatio()` - Get aspect ratio
- Natural image loading widgets:
  - `ThumbHashPlaceholder` - Simple widget with automatic transitions
  - `ThumbHashImageBuilder` - Customizable builder for full control
  - `TransitionConfig` - Configure transition animations
- Transition effects:
  - Fade - Simple crossfade
  - Blur-to-sharp - Focus effect as image loads
  - Scale-up - Subtle zoom effect
  - None - Instant switch
- Full alpha channel support
- Comprehensive test suite (50+ tests)
- Performance benchmarks

### Performance

- Decode: ~12-17μs per image (7x faster than naive)
- PNG encode: ~13-20μs per image (1.6x faster than naive)
- Total pipeline: ~26-38μs per image

### Optimizations

- Separable 2D DCT/IDCT - ~5-7x fewer operations
- Pre-computed cosine tables
- Batched Adler-32 checksum (modulo every 5552 bytes)
- 256-entry CRC-32 table (single lookup per byte)
