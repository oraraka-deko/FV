import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  static final ThumbnailService instance = ThumbnailService._init();
  
  ThumbnailService._init();

  static const int smallSize = 150;
  static const int mediumSize = 300;
  static const int largeSize = 600;
  static const int jpegQuality = 85;

  Future<String?> generateThumbnail(
    String imagePath, {
    int size = mediumSize,
    bool highPriority = false,
  }) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final thumbnailDir = Directory(path.join(cacheDir.path, 'thumbnails', '${size}px'));
      
      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      final fileName = path.basenameWithoutExtension(imagePath);
      final fileHash = fileName.hashCode.abs().toString();
      final thumbnailPath = path.join(thumbnailDir.path, '$fileHash.jpg');

      // Check if thumbnail already exists
      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }

      // Generate thumbnail in isolate
      final result = await compute(
        _generateThumbnailIsolate,
        ThumbnailGenerationParams(
          sourcePath: imagePath,
          targetPath: thumbnailPath,
          size: size,
          quality: jpegQuality,
        ),
      );

      return result;
    } catch (e) {
      debugPrint('Error generating thumbnail for $imagePath: $e');
      return null;
    }
  }

  Future<List<String?>> generateThumbnailBatch(
    List<String> imagePaths, {
    int size = mediumSize,
    int batchSize = 100,
  }) async {
    final results = <String?>[];
    
    for (var i = 0; i < imagePaths.length; i += batchSize) {
      final end = (i + batchSize < imagePaths.length) ? i + batchSize : imagePaths.length;
      final batch = imagePaths.sublist(i, end);
      
      final batchResults = await Future.wait(
        batch.map((path) => generateThumbnail(path, size: size)),
      );
      
      results.addAll(batchResults);
    }
    
    return results;
  }

  static String? _generateThumbnailIsolate(ThumbnailGenerationParams params) {
    try {
      final sourceFile = File(params.sourcePath);
      if (!sourceFile.existsSync()) {
        return null;
      }

      final bytes = sourceFile.readAsBytesSync();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return null;
      }

      // Calculate resize dimensions maintaining aspect ratio
      final thumbnail = img.copyResize(
        image,
        width: image.width > image.height ? params.size : null,
        height: image.height >= image.width ? params.size : null,
        interpolation: img.Interpolation.linear,
      );

      // Encode as JPEG with compression
      final jpegBytes = img.encodeJpg(thumbnail, quality: params.quality);
      
      // Save to file
      final targetFile = File(params.targetPath);
      targetFile.writeAsBytesSync(jpegBytes);

      return params.targetPath;
    } catch (e) {
      debugPrint('Error in thumbnail generation isolate: $e');
      return null;
    }
  }

  Future<void> clearThumbnailCache() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final thumbnailDir = Directory(path.join(cacheDir.path, 'thumbnails'));
      
      if (await thumbnailDir.exists()) {
        await thumbnailDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing thumbnail cache: $e');
    }
  }

  Future<int> getThumbnailCacheSize() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final thumbnailDir = Directory(path.join(cacheDir.path, 'thumbnails'));
      
      if (!await thumbnailDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in thumbnailDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('Error calculating thumbnail cache size: $e');
      return 0;
    }
  }
}

class ThumbnailGenerationParams {
  final String sourcePath;
  final String targetPath;
  final int size;
  final int quality;

  ThumbnailGenerationParams({
    required this.sourcePath,
    required this.targetPath,
    required this.size,
    required this.quality,
  });
}
