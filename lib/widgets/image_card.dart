import 'dart:io';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/image_model.dart';
import '../services/thumbnail_service.dart';

class ImageCard extends StatefulWidget {
  final ImageModel image;
  final VoidCallback onTap;
  final Function(bool)? onVisibilityChanged;

  const ImageCard({
    super.key,
    required this.image,
    required this.onTap,
    this.onVisibilityChanged,
  });

  @override
  State<ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<ImageCard> {
  String? _thumbnailPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _thumbnailPath = widget.image.thumbnailPath;
  }

  Future<void> _loadThumbnail() async {
    if (_thumbnailPath != null) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final thumbnailPath = await ThumbnailService.instance.generateThumbnail(
      widget.image.filePath,
      size: ThumbnailService.mediumSize,
      highPriority: true,
    );

    if (mounted) {
      setState(() {
        _thumbnailPath = thumbnailPath;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('image_${widget.image.id}'),
      onVisibilityChanged: (info) {
        final isVisible = info.visibleFraction > 0;
        widget.onVisibilityChanged?.call(isVisible);
        
        if (isVisible && _thumbnailPath == null && !_isLoading) {
          _loadThumbnail();
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.all(4),
          child: _buildImageContent(),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_thumbnailPath != null && File(_thumbnailPath!).existsSync()) {
      return Image.file(
        File(_thumbnailPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.image,
          size: 48,
          color: Colors.grey,
        ),
      ),
    );
  }
}
