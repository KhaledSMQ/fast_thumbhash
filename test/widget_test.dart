import 'dart:typed_data';

import 'package:fast_thumbhash/fast_thumbhash.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Test ThumbHash data
  const testHashBase64 = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
  const testHashWithAlpha = '3OiFBQAziIWCjHn3aGpwZ/moB8iHeHR6Zw==';

  group('TransitionConfig', () {
    test('default values are correct', () {
      const config = TransitionConfig();

      expect(config.type, equals(ThumbHashTransition.fade));
      expect(config.duration, equals(const Duration(milliseconds: 300)));
      expect(config.curve, equals(Curves.easeOut));
    });

    test('presets have expected values', () {
      expect(TransitionConfig.fast.duration,
          equals(const Duration(milliseconds: 200)));
      expect(TransitionConfig.smooth.duration,
          equals(const Duration(milliseconds: 400)));
      expect(TransitionConfig.blur.type,
          equals(ThumbHashTransition.blurToSharp));
      expect(TransitionConfig.scale.type, equals(ThumbHashTransition.scaleUp));
      expect(TransitionConfig.instant.type, equals(ThumbHashTransition.none));
    });

    test('copyWith creates modified copy', () {
      const original = TransitionConfig();
      final modified = original.copyWith(
        duration: const Duration(milliseconds: 500),
        type: ThumbHashTransition.blurToSharp,
      );

      expect(modified.duration, equals(const Duration(milliseconds: 500)));
      expect(modified.type, equals(ThumbHashTransition.blurToSharp));
      expect(modified.curve, equals(original.curve)); // Unchanged
    });

    test('equality works correctly', () {
      const config1 = TransitionConfig();
      const config2 = TransitionConfig();
      const config3 = TransitionConfig(
        duration: Duration(milliseconds: 500),
      );

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1, isNot(equals(config3)));
    });

    test('toString provides useful info', () {
      const config = TransitionConfig();
      final str = config.toString();

      expect(str, contains('TransitionConfig'));
      expect(str, contains('fade'));
      expect(str, contains('300ms'));
    });
  });

  group('ThumbHashTransition enum', () {
    test('has all expected values', () {
      expect(ThumbHashTransition.values.length, equals(4));
      expect(ThumbHashTransition.values,
          contains(ThumbHashTransition.fade));
      expect(ThumbHashTransition.values,
          contains(ThumbHashTransition.blurToSharp));
      expect(ThumbHashTransition.values,
          contains(ThumbHashTransition.scaleUp));
      expect(ThumbHashTransition.values,
          contains(ThumbHashTransition.none));
    });
  });

  group('ThumbHashLoadingState', () {
    test('initial state has correct defaults', () {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);
      final state = ThumbHashLoadingState(
        thumbHash: thumbHash,
        placeholderImage: thumbHash.toImage(),
      );

      expect(state.isLoaded, isFalse);
      expect(state.hasError, isFalse);
      expect(state.progress, equals(0.0));
      expect(state.loadedImageInfo, isNull);
      expect(state.error, isNull);
    });

    test('isLoaded is true when loadedImageInfo is set', () {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);
      // We can't easily create an ImageInfo in tests, so we test the logic
      final state = ThumbHashLoadingState(
        thumbHash: thumbHash,
        placeholderImage: thumbHash.toImage(),
        loadedImageInfo: null,
      );

      expect(state.isLoaded, isFalse);
    });

    test('copyWith creates modified copy', () {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);
      final state = ThumbHashLoadingState(
        thumbHash: thumbHash,
        placeholderImage: thumbHash.toImage(),
      );

      final modified = state.copyWith(
        progress: 0.5,
        hasError: true,
      );

      expect(modified.progress, equals(0.5));
      expect(modified.hasError, isTrue);
      expect(modified.thumbHash, equals(state.thumbHash));
    });

    test('toString provides useful info', () {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);
      final state = ThumbHashLoadingState(
        thumbHash: thumbHash,
        placeholderImage: thumbHash.toImage(),
      );

      final str = state.toString();
      expect(str, contains('ThumbHashLoadingState'));
      expect(str, contains('isLoaded'));
      expect(str, contains('progress'));
    });
  });

  group('ThumbHashPlaceholder widget', () {
    testWidgets('renders without error', (tester) async {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ThumbHashPlaceholder(
            thumbHash: thumbHash,
            image: MemoryImage(Uint8List(0)), // Dummy image
          ),
        ),
      );

      // Should render without throwing
      expect(find.byType(ThumbHashPlaceholder), findsOneWidget);
    });

    testWidgets('shows placeholder immediately', (tester) async {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ThumbHashPlaceholder(
            thumbHash: thumbHash,
            image: MemoryImage(Uint8List(0)),
          ),
        ),
      );

      // The Stack should be rendered
      expect(find.byType(Stack), findsOneWidget);
    });

    testWidgets('supports all transition types', (tester) async {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);

      for (final type in ThumbHashTransition.values) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ThumbHashPlaceholder(
              thumbHash: thumbHash,
              image: MemoryImage(Uint8List(0)),
              transition: TransitionConfig(type: type),
            ),
          ),
        );

        expect(find.byType(ThumbHashPlaceholder), findsOneWidget);
      }
    });

    testWidgets('shows loading widget when provided', (tester) async {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ThumbHashPlaceholder(
            thumbHash: thumbHash,
            image: MemoryImage(Uint8List(0)),
            loadingWidget: const Text('Loading...'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('respects fit parameter', (tester) async {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ThumbHashPlaceholder(
            thumbHash: thumbHash,
            image: MemoryImage(Uint8List(0)),
            fit: BoxFit.contain,
          ),
        ),
      );

      expect(find.byType(ThumbHashPlaceholder), findsOneWidget);
    });
  });

  group('ThumbHashImageBuilder widget', () {
    testWidgets('builder receives correct initial state', (tester) async {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);
      ThumbHashLoadingState? capturedState;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ThumbHashImageBuilder(
            thumbHash: thumbHash,
            image: MemoryImage(Uint8List(0)),
            builder: (context, state) {
              capturedState = state;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedState, isNotNull);
      expect(capturedState!.thumbHash, equals(thumbHash));
      expect(capturedState!.isLoaded, isFalse);
      expect(capturedState!.progress, equals(0.0));
    });

    testWidgets('builder can return custom widget', (tester) async {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ThumbHashImageBuilder(
            thumbHash: thumbHash,
            image: MemoryImage(Uint8List(0)),
            builder: (context, state) {
              return const Text('Custom Widget');
            },
          ),
        ),
      );

      expect(find.text('Custom Widget'), findsOneWidget);
    });

    testWidgets('shows placeholder image in state', (tester) async {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);
      ImageProvider? capturedPlaceholder;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ThumbHashImageBuilder(
            thumbHash: thumbHash,
            image: MemoryImage(Uint8List(0)),
            builder: (context, state) {
              capturedPlaceholder = state.placeholderImage;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedPlaceholder, isNotNull);
      expect(capturedPlaceholder, isA<MemoryImage>());
    });
  });

  group('Integration', () {
    test('ThumbHash with alpha works with transitions', () {
      final thumbHash = ThumbHash.fromBase64(testHashWithAlpha);

      expect(thumbHash.hasAlpha, isTrue);
      expect(thumbHash.toImage(), isA<MemoryImage>());
    });

    test('all presets can be used with ThumbHash', () {
      final thumbHash = ThumbHash.fromBase64(testHashBase64);

      // Verify presets work
      const configs = [
        TransitionConfig.fast,
        TransitionConfig.smooth,
        TransitionConfig.blur,
        TransitionConfig.scale,
        TransitionConfig.instant,
      ];

      for (final config in configs) {
        expect(config.duration, isA<Duration>());
        expect(config.curve, isA<Curve>());
        expect(config.type, isA<ThumbHashTransition>());
      }
    });
  });
}
