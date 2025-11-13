import 'package:flutter/material.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/image_model.dart';
import '../services/database_service.dart';
import '../services/file_scanner_service.dart';
import '../widgets/image_card.dart';
import 'image_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final List<ImageModel> _images = [];
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 50;

  bool _isScanning = false;
  ScanProgress? _scanProgress;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialImages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMoreImages();
    }
  }

  Future<void> _loadInitialImages() async {
    final count = await DatabaseService.instance.getImageCount();
    
    if (count == 0) {
      // No images in database, prompt to scan
      _showScanDialog();
    } else {
      _loadMoreImages();
    }
  }

  Future<void> _loadMoreImages() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    final newImages = await DatabaseService.instance.getImages(
      limit: _pageSize,
      offset: _currentPage * _pageSize,
    );

    setState(() {
      _images.addAll(newImages);
      _currentPage++;
      _hasMore = newImages.length == _pageSize;
      _isLoading = false;
    });
  }

  Future<void> _showScanDialog() async {
    final shouldScan = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan for Images'),
        content: const Text(
          'No images found in the database. Would you like to scan a directory for images?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Scan'),
          ),
        ],
      ),
    );

    if (shouldScan == true) {
      _startScan();
    }
  }

  Future<void> _startScan() async {
    // Request storage permission
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to scan images'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      // For demo purposes, using a default directory
      // In production, use a directory picker
      final directory = '/storage/emulated/0/DCIM';
      
      await for (final progress in FileScannerService.instance.scanDirectory(directory)) {
        if (mounted) {
          setState(() {
            _scanProgress = progress;
          });
        }
      }

      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanProgress = null;
          _currentPage = 0;
          _images.clear();
          _hasMore = true;
        });

        _loadMoreImages();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan completed successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanProgress = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning directory: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startScan,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isScanning) {
      return _buildScanningProgress();
    }

    if (_images.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No images found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.scanner),
              label: const Text('Scan for Images'),
            ),
          ],
        ),
      );
    }

    return WaterfallFlow.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _images.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _images.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final image = _images[index];
        return ImageCard(
          image: image,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageDetailScreen(image: image),
              ),
            );
          },
          onVisibilityChanged: (isVisible) {
            if (!isVisible) {
              // Clear from memory when not visible
              // This is handled by Flutter's image cache automatically
            }
          },
        );
      },
    );
  }

  Widget _buildScanningProgress() {
    final progress = _scanProgress;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            progress != null
                ? 'Scanning ${progress.scannedFiles} of ${progress.totalFiles}'
                : 'Initializing scan...',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            progress?.phase.name ?? '',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          if (progress != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: LinearProgressIndicator(
                value: progress.progress,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
