/// Ultra-fast ThumbHash encoder/decoder for Dart and Flutter.
///
/// ThumbHash is a very compact representation of an image placeholder.
/// It encodes the image's average color and a low-resolution version
/// into a small byte array (typically 25-35 bytes).
///
/// ## Features
///
/// - **Ultra-fast decoding** - 7x faster than naive implementation
/// - **Fast PNG encoding** - 1.6x faster with pre-allocated buffers
/// - **Full alpha support** - Images with transparency work correctly
/// - **Natural loading transitions** - Smooth fade, blur, and scale effects
/// - **Zero dependencies** - Pure Dart implementation
///
/// ## Quick Start
///
/// ```dart
/// import 'package:fast_thumbhash/fast_thumbhash.dart';
///
/// // Create from base64 string
/// final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
///
/// // Use in Flutter Image widget
/// Image(image: hash.toImage())
///
/// // Get average color for background
/// final color = hash.toAverageColor();
/// ```
///
/// ## Natural Image Loading
///
/// Use [ThumbHashPlaceholder] for automatic placeholder-to-image transitions:
///
/// ```dart
/// ThumbHashPlaceholder(
///   thumbHash: ThumbHash.fromBase64('3OcRJYB...'),
///   image: NetworkImage('https://example.com/photo.jpg'),
///   transition: TransitionConfig.blur,
/// )
/// ```
///
/// ## Core Functions
///
/// For lower-level access, use these functions directly:
///
/// - [thumbHashToRGBA] - Decode ThumbHash to RGBA image
/// - [rgbaToThumbHash] - Encode RGBA image to ThumbHash
/// - [thumbHashToAverageRGBA] - Extract average color
/// - [thumbHashToApproximateAspectRatio] - Get aspect ratio
///
/// ## Performance
///
/// Benchmarked on typical hardware:
/// - Decode: ~45μs per image
/// - PNG encode: ~40μs per image
/// - Total pipeline: ~85μs per image
///
/// Based on the original ThumbHash algorithm by Evan Wallace.
/// See: https://github.com/evanw/thumbhash
library fast_thumbhash;

// Core algorithm
export 'src/thumbhash_base.dart'
    show
        thumbHashToRGBA,
        rgbaToThumbHash,
        thumbHashToAverageRGBA,
        thumbHashToApproximateAspectRatio;

// Data models
export 'src/models.dart' show ThumbHashImage, ThumbHashColor;

// PNG encoder
export 'src/png_encoder.dart' show thumbHashImageToPng;

// Flutter integration - ThumbHash class
export 'src/flutter/thumbhash_image.dart' show ThumbHash;

// Flutter integration - Transitions
export 'src/flutter/transitions.dart'
    show ThumbHashTransition, TransitionConfig;

// Flutter integration - Image loading widgets
export 'src/flutter/thumbhash_image_widget.dart'
    show ThumbHashPlaceholder;

export 'src/flutter/thumbhash_image_builder.dart'
    show ThumbHashImageBuilder, ThumbHashLoadingState, ThumbHashWidgetBuilder;
