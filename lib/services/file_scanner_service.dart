import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import '../models/image_model.dart';
import 'database_service.dart';
import 'thumbnail_service.dart';

class FileScannerService {
  static final FileScannerService instance = FileScannerService._init();
  
  FileScannerService._init();

  final List<String> _supportedExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
  ];

  Stream<ScanProgress> scanDirectory(String directoryPath) async* {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw Exception('Directory does not exist: $directoryPath');
    }

    final files = <String>[];
    int totalFiles = 0;
    int scannedFiles = 0;

    // First pass: count all image files
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && _isImageFile(entity.path)) {
        files.add(entity.path);
        totalFiles++;
      }
    }

    yield ScanProgress(
      totalFiles: totalFiles,
      scannedFiles: 0,
      phase: ScanPhase.counting,
    );

    // Second pass: process files in batches
    const batchSize = 50;
    for (var i = 0; i < files.length; i += batchSize) {
      final end = (i + batchSize < files.length) ? i + batchSize : files.length;
      final batch = files.sublist(i, end);

      // Process batch in isolate
      final imageModels = await compute(_processBatchIsolate, batch);
      
      // Insert into database
      if (imageModels.isNotEmpty) {
        await DatabaseService.instance.insertImageBatch(imageModels);
      }

      scannedFiles += batch.length;

      yield ScanProgress(
        totalFiles: totalFiles,
        scannedFiles: scannedFiles,
        phase: ScanPhase.indexing,
      );
    }

    yield ScanProgress(
      totalFiles: totalFiles,
      scannedFiles: totalFiles,
      phase: ScanPhase.thumbnails,
    );

    // Third pass: generate thumbnails in background
    _generateThumbnailsInBackground(files);
  }

  Future<void> _generateThumbnailsInBackground(List<String> files) async {
    // Generate thumbnails in background without blocking
    for (final filePath in files) {
      try {
        final image = await DatabaseService.instance.getImageByPath(filePath);
        if (image != null && image.thumbnailPath == null) {
          final thumbnailPath = await ThumbnailService.instance.generateThumbnail(
            filePath,
            size: ThumbnailService.mediumSize,
          );
          
          if (thumbnailPath != null && image.id != null) {
            await DatabaseService.instance.updateThumbnailPath(image.id!, thumbnailPath);
          }
        }
      } catch (e) {
        debugPrint('Error generating thumbnail for $filePath: $e');
      }
    }
  }

  static List<ImageModel> _processBatchIsolate(List<String> filePaths) {
    final results = <ImageModel>[];

    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (!file.existsSync()) continue;

        final bytes = file.readAsBytesSync();
        final image = img.decodeImage(bytes);
        
        if (image == null) continue;

        final stat = file.statSync();

        results.add(ImageModel(
          filePath: filePath,
          width: image.width,
          height: image.height,
          fileSize: stat.size,
          dateAdded: DateTime.now(),
          dateModified: stat.modified,
        ));
      } catch (e) {
        debugPrint('Error processing file $filePath: $e');
      }
    }

    return results;
  }

  bool _isImageFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return _supportedExtensions.contains(ext);
  }

  Future<void> watchDirectory(String directoryPath, Function(FileSystemEvent) onEvent) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw Exception('Directory does not exist: $directoryPath');
    }

    directory.watch(recursive: true).listen((event) {
      if (event is FileSystemCreateEvent || event is FileSystemModifyEvent) {
        if (_isImageFile(event.path)) {
          onEvent(event);
        }
      }
    });
  }

  Future<void> rescanDirectory(String directoryPath) async {
    // Clear existing entries for this directory
    // Then rescan
    await for (final progress in scanDirectory(directoryPath)) {
      debugPrint('Rescan progress: ${progress.scannedFiles}/${progress.totalFiles}');
    }
  }
}

class ScanProgress {
  final int totalFiles;
  final int scannedFiles;
  final ScanPhase phase;

  ScanProgress({
    required this.totalFiles,
    required this.scannedFiles,
    required this.phase,
  });

  double get progress => totalFiles > 0 ? scannedFiles / totalFiles : 0;
}

enum ScanPhase {
  counting,
  indexing,
  thumbnails,
  complete,
}
