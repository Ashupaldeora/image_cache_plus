import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:clock/clock.dart';
import 'utils.dart';

/// Manages image caching using Hive for metadata and file system for storage.
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();

  factory CacheManager() {
    return _instance;
  }

  CacheManager._internal();

  Box? _box;
  // In-memory cache for small images (optional, but good for list performance)
  // Key: URL, Value: Uint8List
  final Map<String, Uint8List> _memoryCache = {};

  // Configuration
  static const String _boxName = 'image_cache_plus_box';
  Duration defaultCacheDuration = const Duration(days: 7);
  int maxMemoryCacheSize = 50 * 1024 * 1024; // 50MB
  int _currentMemoryCacheSize = 0;
  Directory? _cacheDir;

  /// Initializes Hive and opens the box.
  /// Should be called before using any other methods.
  Future<void> init() async {
    if (_box != null && _box!.isOpen && _cacheDir != null) return;

    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      Hive.init(appDir.path);
    }

    _box = await Hive.openBox(_boxName);
    _cacheDir = await Utils.getCacheDirectory();
  }

  /// Returns the file if it exists and is not expired.
  /// Returns null otherwise.
  Future<File?> getFile(String url) async {
    await init();

    final key = Utils.keyFromUrl(url);
    final metadata = _box!.get(key);

    if (metadata == null) return null;

    // Expiry check
    final int expiryTime = metadata['expiry'] ?? 0;
    if (clock.now().millisecondsSinceEpoch > expiryTime) {
      // Expired
      await _box!.delete(key);
      if (_cacheDir != null) {
        final file = File('${_cacheDir!.path}/$key');
        if (await file.exists()) {
          await file.delete();
        }
      }
      return null;
    }

    if (_cacheDir == null) await init(); // Safety fallback
    final file = File('${_cacheDir!.path}/$key');
    if (await file.exists()) {
      return file;
    } else {
      // Metadata exists but file missing
      await _box!.delete(key);
      return null;
    }
  }

  /// Saves the image bytes to file and metadata to Hive.
  Future<File> putFile(
    String url,
    Uint8List bytes, {
    Duration? cacheDuration,
    String? eTag,
  }) async {
    await init();

    final key = Utils.keyFromUrl(url);
    if (_cacheDir == null) await init();
    final file = File('${_cacheDir!.path}/$key');

    await file.writeAsBytes(bytes);

    final duration = cacheDuration ?? defaultCacheDuration;
    final expiry = clock.now().add(duration).millisecondsSinceEpoch;

    await _box!.put(key, {
      'url': url,
      'expiry': expiry,
      'eTag': eTag,
      'savedAt': clock.now().millisecondsSinceEpoch,
    });

    _addToMemoryCache(url, bytes);

    return file;
  }

  /// Gets image from memory cache if available.
  Uint8List? getFromMemory(String url) {
    return _memoryCache[url];
  }

  void _addToMemoryCache(String url, Uint8List bytes) {
    if (bytes.length > 5 * 1024 * 1024) {
      return; // Don't cache images > 5MB in memory
    }

    if (_currentMemoryCacheSize + bytes.length > maxMemoryCacheSize) {
      _memoryCache
          .clear(); // Simple strategy: clear all if full. Can be LRU later.
      _currentMemoryCacheSize = 0;
    }

    _memoryCache[url] = bytes;
    _currentMemoryCacheSize += bytes.length;
  }

  /// Clears the entire cache.
  Future<void> clearCache() async {
    await init();
    await _box!.clear();
    if (_cacheDir != null && _cacheDir!.existsSync()) {
      await _cacheDir!.delete(recursive: true);
      // Re-create it
      _cacheDir!.createSync(recursive: true);
    }
    _memoryCache.clear();
    _currentMemoryCacheSize = 0;
  }
}
