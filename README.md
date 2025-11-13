# FV - Advanced Image Viewer

A high-performance Flutter image viewer designed to handle large local image libraries (20,000+ images) with smooth scrolling, efficient caching, and responsive layouts.

## Features

- **Waterfall Grid Layout**: Responsive grid using `waterfall_flow` package with adaptive column sizing
- **High Performance**: Handles 20,000+ images including files over 10MB
- **Multi-tier Caching**: 
  - Memory cache (100 images, 200MB max)
  - Disk cache (2-5GB with LRU eviction)
  - Three-size thumbnail system (150px, 300px, 600px)
- **SQLite Indexing**: Fast database queries with FTS5 full-text search
- **Background Processing**: Isolate-based thumbnail generation and file scanning
- **Lazy Loading**: Loads 50 images initially, triggers next batch 10 items from end
- **Real-time Updates**: File system watcher for directory changes

## Architecture

### Data Layer
- **DatabaseService**: SQLite with indexed queries for pagination and FTS5 for search
- **ImageModel**: Data model with file metadata (path, dimensions, size, dates)

### Services
- **FileScannerService**: Recursive directory scanning with batch processing (50-100 files)
- **ThumbnailService**: Isolate-based thumbnail generation with priority queue
- **CacheManagerService**: Multi-tier caching with configurable retention policies

### UI Components
- **GalleryScreen**: Main waterfall grid view with lazy loading
- **ImageDetailScreen**: Full-screen viewer with PhotoView (zoom, pan)
- **ImageCard**: Memory-aware image widget with visibility detection

## Memory Management

- Image cache: 100 images max, 200MB limit
- Disk cache: 2-5GB with LRU eviction
- Off-screen image clearing via VisibilityDetector
- Platform-aware cache sizing (200MB mobile, 1GB desktop)

## Usage

1. Grant storage permissions
2. Tap scan button to index images
3. Browse gallery with smooth scrolling
4. Tap image for full-screen view with zoom

## Implementation Details

- **Initial Scan**: Progress dialog with "Scanning X of ~20000" and cancel option
- **Thumbnail Strategy**: Hybrid approach - visible batch immediately, rest in background
- **Grid Columns**: Adaptive with maxCrossAxisExtent (150px mobile, 200px tablet/desktop)
- **Large Image Handling**: Progressive loading with zoom limits for 10MB+ files

