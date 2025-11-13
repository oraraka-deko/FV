import 'package:flutter/material.dart';
import 'screens/gallery_screen.dart';
import 'services/cache_manager_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure image cache for optimal memory usage
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 * 1024 * 1024; // 200 MB
  
  // Initialize cache manager
  await CacheManagerService.instance.initialize();
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FV - Image Viewer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const GalleryScreen(),
    );
  }
}
