import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_cache_plus/image_cache_plus.dart';

// Mock Http if needed or just test structure since we don't have good mocks yet.
// We will focus on the Widget logic (Stack, Params) not the network.
void main() {
  testWidgets('ImageCachePlus shows placeholder initially', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ImageCachePlus(
          imageUrl: 'https://example.com/image.jpg',
          width: 100,
          height: 100,
        ),
      ),
    );

    // Initial state: Placeholder (CircularProgressIndicator by default)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Stack), findsOneWidget);
  });

  testWidgets('ImageCachePlus accepts memCache params', (
    WidgetTester tester,
  ) async {
    const widget = ImageCachePlus(
      imageUrl: 'https://example.com/image.jpg',
      memCacheWidth: 200,
      memCacheHeight: 300,
    );

    expect(widget.memCacheWidth, 200);
    expect(widget.memCacheHeight, 300);
  });
}
