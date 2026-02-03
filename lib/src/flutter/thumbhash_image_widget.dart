import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'thumbhash_image.dart';
import 'transitions.dart';

/// Signature for a function that builds a widget when an image fails to load.
///
/// Used by [ThumbHashPlaceholder.errorBuilder] to allow custom error handling.
///
/// The [context] is the build context where the error widget will be displayed.
/// The [error] is the exception that caused the image to fail loading.
/// The [stackTrace] is the stack trace associated with the error, if available.
typedef ImageErrorWidgetBuilder = Widget Function(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
);

/// A widget that displays a ThumbHash placeholder and transitions to
/// the loaded image with a natural animation effect.
///
/// This is the simplest way to use ThumbHash with automatic image loading.
/// It shows the ThumbHash placeholder immediately, loads the real image
/// in the background, and applies a smooth transition when ready.
///
/// Example:
/// ```dart
/// ThumbHashPlaceholder(
///   thumbHash: ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A'),
///   image: NetworkImage('https://example.com/photo.jpg'),
/// )
/// ```
///
/// With custom transition:
/// ```dart
/// ThumbHashPlaceholder(
///   thumbHash: hash,
///   image: NetworkImage(url),
///   transition: TransitionConfig.blur,
///   fit: BoxFit.contain,
/// )
/// ```
class ThumbHashPlaceholder extends StatefulWidget {
  /// The ThumbHash placeholder to show while loading.
  final ThumbHash thumbHash;

  /// The actual image to load and display.
  final ImageProvider image;

  /// How the image should be inscribed into the space.
  ///
  /// Defaults to [BoxFit.cover].
  final BoxFit fit;

  /// The transition configuration for the loading animation.
  ///
  /// Defaults to a 300ms fade transition.
  final TransitionConfig transition;

  /// Builder for the widget to show when image loading fails.
  ///
  /// Provides access to the [BuildContext], the [error] that occurred,
  /// and the [stackTrace] for custom error handling and display.
  ///
  /// If null, the ThumbHash placeholder remains visible on error.
  ///
  /// Example:
  /// ```dart
  /// ThumbHashPlaceholder(
  ///   thumbHash: hash,
  ///   image: NetworkImage(url),
  ///   errorBuilder: (context, error, stackTrace) {
  ///     return Center(
  ///       child: Column(
  ///         mainAxisSize: MainAxisSize.min,
  ///         children: [
  ///           Icon(Icons.error, color: Colors.red),
  ///           Text('Failed to load image'),
  ///         ],
  ///       ),
  ///     );
  ///   },
  /// )
  /// ```
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Optional widget to overlay while loading.
  ///
  /// For example, a loading spinner or progress indicator.
  final Widget? loadingWidget;

  /// Alignment of the image within its bounds.
  ///
  /// Defaults to [Alignment.center].
  final Alignment alignment;

  /// How to paint any portions not covered by the image.
  final ImageRepeat repeat;

  /// Whether to apply anti-aliasing.
  final FilterQuality filterQuality;

  /// Creates a ThumbHash placeholder widget with automatic loading.
  const ThumbHashPlaceholder({
    super.key,
    required this.thumbHash,
    required this.image,
    this.fit = BoxFit.cover,
    this.transition = const TransitionConfig(),
    this.errorBuilder,
    this.loadingWidget,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.filterQuality = FilterQuality.low,
  });

  @override
  State<ThumbHashPlaceholder> createState() => _ThumbHashPlaceholderState();
}

class _ThumbHashPlaceholderState extends State<ThumbHashPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  ImageInfo? _imageInfo;
  bool _isLoaded = false;
  bool _hasError = false;
  Object? _error;
  StackTrace? _stackTrace;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(ThumbHashPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) {
      _disposeImageStream();
      _isLoaded = false;
      _hasError = false;
      _error = null;
      _stackTrace = null;
      _imageInfo = null;
      _controller.reset();
      _resolveImage();
    }
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
      _imageInfo = info;
      _isLoaded = true;
      _hasError = false;
    });
    if (widget.transition.type != ThumbHashTransition.none) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  void _handleImageError(Object error, StackTrace? stackTrace) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _error = error;
      _stackTrace = stackTrace;
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
    _disposeImageStream();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build the placeholder image with error handling
    final placeholder = Image(
      image: widget.thumbHash.toImage(),
      fit: widget.fit,
      alignment: widget.alignment,
      repeat: widget.repeat,
      filterQuality: widget.filterQuality,
      errorBuilder: (context, error, stackTrace) {
        // If the thumbhash placeholder fails to decode, show empty widget
        return const SizedBox.shrink();
      },
    );

    // If error occurred, show error widget or placeholder
    if (_hasError) {
      return widget.errorBuilder?.call(context, _error!, _stackTrace) ??
          placeholder;
    }

    // Build based on transition type
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;

        return Stack(
          fit: StackFit.passthrough,
          children: [
            // Placeholder with transition effect
            _buildPlaceholder(placeholder, progress),

            // Loaded image fading in
            if (_isLoaded && _imageInfo != null)
              _buildLoadedImage(progress),

            // Optional loading widget
            if (!_isLoaded && !_hasError && widget.loadingWidget != null)
              widget.loadingWidget!,
          ],
        );
      },
    );
  }

  Widget _buildPlaceholder(Widget placeholder, double progress) {
    switch (widget.transition.type) {
      case ThumbHashTransition.fade:
        return Opacity(
          opacity: 1.0 - progress,
          child: placeholder,
        );

      case ThumbHashTransition.blurToSharp:
        // Blur decreases as progress increases
        final sigma = 8.0 * (1.0 - progress);
        if (sigma < 0.1) return placeholder;
        return ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.decal,
          ),
          child: Opacity(
            opacity: 1.0 - progress * 0.5,
            child: placeholder,
          ),
        );

      case ThumbHashTransition.scaleUp:
        // Scale from 1.05 to 1.0
        final scale = 1.05 - (0.05 * progress);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: 1.0 - progress,
            child: placeholder,
          ),
        );

      case ThumbHashTransition.none:
        return progress < 1.0 ? placeholder : const SizedBox.shrink();
    }
  }

  Widget _buildLoadedImage(double progress) {
    final loadedImage = RawImage(
      image: _imageInfo!.image,
      fit: widget.fit,
      alignment: widget.alignment,
      repeat: widget.repeat,
      filterQuality: widget.filterQuality,
    );

    switch (widget.transition.type) {
      case ThumbHashTransition.fade:
      case ThumbHashTransition.blurToSharp:
        return Opacity(
          opacity: progress,
          child: loadedImage,
        );

      case ThumbHashTransition.scaleUp:
        // Scale from 0.95 to 1.0
        final scale = 0.95 + (0.05 * progress);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: progress,
            child: loadedImage,
          ),
        );

      case ThumbHashTransition.none:
        return loadedImage;
    }
  }
}
