import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // For BytesBuilder
import 'dart:ui' as ui; // For ui.Codec
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'cache_manager.dart'; // Import your CacheManager

/// A [ImageProvider] that loads images from network and caches them using [CacheManager].
class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  const CachedNetworkImageProvider(
    this.url, {
    this.scale = 1.0,
    this.headers,
    this.cacheManager,
    this.cacheDuration,
  });

  final String url;
  final double scale;
  final Map<String, String>? headers;
  final CacheManager? cacheManager;
  final Duration? cacheDuration;

  CacheManager get _cacheManager => cacheManager ?? CacheManager();

  @override
  Future<CachedNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    // Ownership of this controller is handed off to the ImageStreamCompleter
    // which disposes it.
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CachedNetworkImageProvider>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    try {
      // 1. Check Memory Cache
      final memoryImage = _cacheManager.getFromMemory(key.url);
      if (memoryImage != null) {
        return await decode(
          await ui.ImmutableBuffer.fromUint8List(memoryImage),
        );
      }

      // 2. Check Disk Cache
      final file = await _cacheManager.getFile(key.url);
      if (file != null) {
        final bytes = await file.readAsBytes();
        return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
      }

      // 3. Download
      return await _downloadAndCache(key, chunkEvents, decode);
    } catch (e) {
      chunkEvents.addError(e);
      rethrow;
    } finally {
      // Don't close chunkEvents here; the completer handles it,
      // or we let it live if we want to stream progress.
      // Actually, for single file download, we might want to close it?
      // Standard practice: if download finishes, we are done.
      // But _downloadAndCache will handle the stream.
    }
  }

  Future<ui.Codec> _downloadAndCache(
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    // Retry logic
    int attempts = 0;
    while (attempts < 3) {
      try {
        final uri = Uri.parse(key.url);
        final request = http.Request('GET', uri);
        if (key.headers != null) {
          request.headers.addAll(key.headers!);
        }

        final response = await request.send();

        if (response.statusCode != 200) {
          throw HttpException('Status ${response.statusCode}', uri: uri);
        }

        final contentLength = response.contentLength;
        int received = 0;
        final BytesBuilder bytesBuilder = BytesBuilder(copy: false);

        await response.stream.listen((List<int> newBytes) {
          bytesBuilder.add(newBytes);
          received += newBytes.length;
          if (contentLength != null) {
            chunkEvents.add(
              ImageChunkEvent(
                cumulativeBytesLoaded: received,
                expectedTotalBytes: contentLength,
              ),
            );
          }
        }, cancelOnError: true).asFuture();

        chunkEvents.close();

        final uint8Bytes = bytesBuilder.toBytes();

        // Save to cache
        // We do this asynchronously and don't wait for it to return image faster
        _cacheManager.putFile(
          key.url,
          uint8Bytes,
          cacheDuration: key.cacheDuration,
        );

        return await decode(await ui.ImmutableBuffer.fromUint8List(uint8Bytes));
      } catch (e) {
        attempts++;
        if (attempts >= 3) {
          chunkEvents.addError(e);
          // If we fail all retries, rethrow so the widget knows
          rethrow;
        }
        await Future.delayed(Duration(seconds: attempts)); // Backoff
      }
    }
    throw StateError('Should not reach here');
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is CachedNetworkImageProvider &&
        other.url == url &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, scale);
}
