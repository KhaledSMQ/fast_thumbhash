import 'package:flutter/widgets.dart';

/// Transition types for image loading animations.
///
/// These define how the placeholder transitions to the loaded image.
enum ThumbHashTransition {
  /// Simple crossfade - placeholder fades out as real image fades in.
  ///
  /// This is the default and most common transition effect.
  fade,

  /// Blur-to-sharp effect - placeholder appears blurred and sharpens
  /// as the real image loads.
  ///
  /// Creates a smooth "focus" effect that feels natural.
  blurToSharp,

  /// Scale-up effect - placeholder is slightly enlarged and scales
  /// down to normal size as the real image appears.
  ///
  /// Creates a subtle zoom effect.
  scaleUp,

  /// No animation - instant switch when image loads.
  ///
  /// Use this when you want the fastest possible image display
  /// without any transition animation.
  none,
}

/// Configuration for transition animations.
///
/// Controls the duration, curve, and type of transition used when
/// switching from the ThumbHash placeholder to the loaded image.
///
/// Example:
/// ```dart
/// ThumbHashImage(
///   thumbHash: hash,
///   image: NetworkImage(url),
///   transition: TransitionConfig(
///     type: ThumbHashTransition.blurToSharp,
///     duration: Duration(milliseconds: 500),
///     curve: Curves.easeInOut,
///   ),
/// )
/// ```
class TransitionConfig {
  /// The duration of the transition animation.
  ///
  /// Defaults to 300 milliseconds.
  final Duration duration;

  /// The animation curve to use.
  ///
  /// Defaults to [Curves.easeOut] for a natural deceleration effect.
  final Curve curve;

  /// The type of transition effect.
  ///
  /// Defaults to [ThumbHashTransition.fade].
  final ThumbHashTransition type;

  /// Creates a transition configuration.
  ///
  /// All parameters are optional with sensible defaults.
  const TransitionConfig({
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOut,
    this.type = ThumbHashTransition.fade,
  });

  /// Fast transition preset (200ms).
  ///
  /// Good for small images or when responsiveness is important.
  static const fast = TransitionConfig(
    duration: Duration(milliseconds: 200),
  );

  /// Smooth transition preset (400ms).
  ///
  /// Good for hero images or when a more noticeable effect is desired.
  static const smooth = TransitionConfig(
    duration: Duration(milliseconds: 400),
    curve: Curves.easeInOut,
  );

  /// Blur-to-sharp preset with smooth timing.
  ///
  /// Creates a natural "focus" effect as the image loads.
  static const blur = TransitionConfig(
    type: ThumbHashTransition.blurToSharp,
    duration: Duration(milliseconds: 400),
    curve: Curves.easeOut,
  );

  /// Scale-up preset with subtle zoom.
  ///
  /// Creates a gentle zoom-out effect as the image loads.
  static const scale = TransitionConfig(
    type: ThumbHashTransition.scaleUp,
    duration: Duration(milliseconds: 350),
    curve: Curves.easeOut,
  );

  /// No animation preset.
  ///
  /// Instantly switches to the loaded image.
  static const instant = TransitionConfig(
    type: ThumbHashTransition.none,
    duration: Duration.zero,
  );

  /// Creates a copy with the given fields replaced.
  TransitionConfig copyWith({
    Duration? duration,
    Curve? curve,
    ThumbHashTransition? type,
  }) {
    return TransitionConfig(
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransitionConfig &&
          duration == other.duration &&
          curve == other.curve &&
          type == other.type;

  @override
  int get hashCode => Object.hash(duration, curve, type);

  @override
  String toString() => 'TransitionConfig('
      'type: $type, '
      'duration: ${duration.inMilliseconds}ms, '
      'curve: $curve)';
}
