import 'package:flutter/widgets.dart';

import 'thumbhash_image.dart';
import 'transitions.dart';

/// The current state of image loading, exposed to [ThumbHashImageBuilder].
///
/// This class provides all the information needed to build a custom
/// loading UI with transition effects.
///
/// Example:
/// ```dart
/// ThumbHashImageBuilder(
///   thumbHash: hash,
///   image: NetworkImage(url),
///   builder: (context, state) {
///     if (state.hasError) {
///       return Icon(Icons.error);
///     }
///     return Opacity(
///       opacity: state.isLoaded ? 1.0 : 0.5,
///       child: Image(image: state.placeholderImage),
///     );
///   },
/// )
/// ```
class ThumbHashLoadingState {
  /// The ThumbHash data.
  final ThumbHash thumbHash;

  /// The ThumbHash placeholder as an [ImageProvider].
  ///
  /// This is ready to use immediately without any loading.
  final ImageProvider placeholderImage;

  /// The loaded image provider, or null if still loading.
  ///
  /// Check [isLoaded] before using this.
  final ImageInfo? loadedImageInfo;

  /// The transition animation progress (0.0 to 1.0).
  ///
  /// - 0.0: Loading or just started transitioning
  /// - 1.0: Transition complete
  ///
  /// Use this to create custom transition effects.
  final double progress;

  /// Whether the image has finished loading successfully.
  bool get isLoaded => loadedImageInfo != null;

  /// Whether an error occurred during loading.
  final bool hasError;

  /// The error that occurred, if any.
  final Object? error;

  /// The stack trace for the error, if any.
  final StackTrace? stackTrace;

  /// Creates a loading state.
  const ThumbHashLoadingState({
    required this.thumbHash,
    required this.placeholderImage,
    this.loadedImageInfo,
    this.progress = 0.0,
    this.hasError = false,
    this.error,
    this.stackTrace,
  });

  /// Creates a copy with the given fields replaced.
  ThumbHashLoadingState copyWith({
    ThumbHash? thumbHash,
    ImageProvider? placeholderImage,
    ImageInfo? loadedImageInfo,
    double? progress,
    bool? hasError,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return ThumbHashLoadingState(
      thumbHash: thumbHash ?? this.thumbHash,
      placeholderImage: placeholderImage ?? this.placeholderImage,
      loadedImageInfo: loadedImageInfo ?? this.loadedImageInfo,
      progress: progress ?? this.progress,
      hasError: hasError ?? this.hasError,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  @override
  String toString() => 'ThumbHashLoadingState('
      'isLoaded: $isLoaded, '
      'progress: ${progress.toStringAsFixed(2)}, '
      'hasError: $hasError)';
}

/// Signature for the builder function used by [ThumbHashImageBuilder].
typedef ThumbHashWidgetBuilder = Widget Function(
  BuildContext context,
  ThumbHashLoadingState state,
);

/// A builder widget for creating custom ThumbHash loading experiences.
///
/// Unlike [ThumbHashImage] which provides built-in transitions, this widget
/// gives you full control over how the placeholder and loaded image are
/// displayed and animated.
///
/// The [builder] is called whenever the loading state changes, providing
/// a [ThumbHashLoadingState] with all the information needed to build
/// your custom UI.
///
/// Example with custom transition:
/// ```dart
/// ThumbHashImageBuilder(
///   thumbHash: hash,
///   image: NetworkImage(url),
///   transition: TransitionConfig.smooth,
///   builder: (context, state) {
///     return Stack(
///       fit: StackFit.expand,
///       children: [
///         // Blurred placeholder
///         ImageFiltered(
///           imageFilter: ImageFilter.blur(
///             sigmaX: 10 * (1 - state.progress),
///             sigmaY: 10 * (1 - state.progress),
///           ),
///           child: Image(image: state.placeholderImage, fit: BoxFit.cover),
///         ),
///         // Loaded image fades in
///         if (state.isLoaded)
///           Opacity(
///             opacity: state.progress,
///             child: RawImage(
///               image: state.loadedImageInfo!.image,
///               fit: BoxFit.cover,
///             ),
///           ),
///       ],
///     );
///   },
/// )
/// ```
class ThumbHashImageBuilder extends StatefulWidget {
  /// The ThumbHash placeholder data.
  final ThumbHash thumbHash;

  /// The actual image to load.
  final ImageProvider image;

  /// The transition configuration.
  ///
  /// This controls the animation duration and curve. The [progress]
  /// value in [ThumbHashLoadingState] is animated according to this
  /// configuration.
  final TransitionConfig transition;

  /// The builder function called to build the widget.
  ///
  /// This is called:
  /// - Initially with progress = 0.0 and isLoaded = false
  /// - During the transition animation with progress 0.0 → 1.0
  /// - On error with hasError = true
  final ThumbHashWidgetBuilder builder;

  /// Called when the image fails to load.
  ///
  /// Use this for logging or analytics. The error is also available
  /// in the [ThumbHashLoadingState] passed to the builder.
  final void Function(Object error, StackTrace? stackTrace)? onError;

  /// Called when the image finishes loading successfully.
  final VoidCallback? onLoaded;

  /// Creates a ThumbHash image builder.
  const ThumbHashImageBuilder({
    super.key,
    required this.thumbHash,
    required this.image,
    required this.builder,
    this.transition = const TransitionConfig(),
    this.onError,
    this.onLoaded,
  });

  @override
  State<ThumbHashImageBuilder> createState() => _ThumbHashImageBuilderState();
}

class _ThumbHashImageBuilderState extends State<ThumbHashImageBuilder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late ThumbHashLoadingState _state;

  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.transition.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.transition.curve,
    );
    _controller.addListener(_onAnimationUpdate);

    _state = ThumbHashLoadingState(
      thumbHash: widget.thumbHash,
      placeholderImage: widget.thumbHash.toImage(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(ThumbHashImageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update thumbHash if changed
    if (widget.thumbHash != oldWidget.thumbHash) {
      _state = _state.copyWith(
        thumbHash: widget.thumbHash,
        placeholderImage: widget.thumbHash.toImage(),
      );
    }

    // Reload image if changed
    if (widget.image != oldWidget.image) {
      _disposeImageStream();
      _controller.reset();
      _state = ThumbHashLoadingState(
        thumbHash: widget.thumbHash,
        placeholderImage: widget.thumbHash.toImage(),
      );
      _resolveImage();
    }

    // Update animation configuration
    if (widget.transition.duration != oldWidget.transition.duration) {
      _controller.duration = widget.transition.duration;
    }
    if (widget.transition.curve != oldWidget.transition.curve) {
      _animation = CurvedAnimation(
        parent: _controller,
        curve: widget.transition.curve,
      );
    }
  }

  void _resolveImage() {
    final ImageStream newStream =
        widget.image.resolve(createLocalImageConfiguration(context));

    if (_imageStream?.key == newStream.key) {
      return;
    }

    _disposeImageStream();
    _imageStream = newStream;

    _imageListener = ImageStreamListener(
      _handleImageLoad,
      onError: _handleImageError,
    );
    _imageStream!.addListener(_imageListener!);
  }

  void _handleImageLoad(ImageInfo info, bool synchronousCall) {
    if (!mounted) return;

    setState(() {
      _state = _state.copyWith(
        loadedImageInfo: info,
        hasError: false,
        error: null,
        stackTrace: null,
      );
    });

    widget.onLoaded?.call();

    if (widget.transition.type != ThumbHashTransition.none) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
      _onAnimationUpdate();
    }
  }

  void _handleImageError(Object error, StackTrace? stackTrace) {
    if (!mounted) return;

    setState(() {
      _state = _state.copyWith(
        hasError: true,
        error: error,
        stackTrace: stackTrace,
      );
    });

    widget.onError?.call(error, stackTrace);
  }

  void _onAnimationUpdate() {
    if (!mounted) return;
    setState(() {
      _state = _state.copyWith(progress: _animation.value);
    });
  }

  void _disposeImageStream() {
    if (_imageListener != null && _imageStream != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageStream = null;
    _imageListener = null;
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationUpdate);
    _disposeImageStream();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _state);
  }
}
