import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

class CacheManagerService {
  static final CacheManagerService instance = CacheManagerService._init();
  
  CacheManagerService._init();

  static const int diskCacheSizeGB = 3;
  static const Duration stalePeriod = Duration(days: 30);

  late final CacheManager _cacheManager;

  Future<void> initialize() async {
    _cacheManager = CacheManager(
      Config(
        'image_cache',
        stalePeriod: stalePeriod,
        maxNrOfCacheObjects: 10000,
        repo: JsonCacheInfoRepository(databaseName: 'image_cache'),
        fileSystem: IOFileSystem('image_cache'),
      ),
    );
  }

  CacheManager get cacheManager => _cacheManager;

  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }

  Future<int> getCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      int totalSize = 0;
      
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (e) {
            debugPrint('Error getting file size: $e');
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
      return 0;
    }
  }

  Future<void> cleanupOldCache({int maxSizeBytes = 5 * 1024 * 1024 * 1024}) async {
    try {
      final currentSize = await getCacheSize();
      
      if (currentSize > maxSizeBytes) {
        // Implement LRU cleanup
        await _cacheManager.emptyCache();
      }
    } catch (e) {
      debugPrint('Error cleaning up cache: $e');
    }
  }
}
