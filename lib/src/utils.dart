import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class Utils {
  /// Generates a SHA-256 hash of the [url] to use as a filename.
  static String keyFromUrl(String url) {
    var bytes = utf8.encode(url);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Gets the directory where images should be stored.
  static Future<Directory> getCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/image_cache_plus');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return cacheDir;
  }
}
