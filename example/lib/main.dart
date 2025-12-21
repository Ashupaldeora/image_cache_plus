import 'package:flutter/material.dart';
import 'package:image_cache_plus/image_cache_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheManager().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Cache Plus Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Image Cache Plus Demo'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  final List<String> imageUrls = const [
    'https://images.unsplash.com/photo-1682687220742-aba13b6e50ba',
    'https://images.unsplash.com/photo-1682687220063-4742bd7fd538',
    'https://images.unsplash.com/photo-1682687220199-d0124f48f95b',
    'https://images.unsplash.com/photo-1682687220067-dced9a881b56',
    'https://plus.unsplash.com/premium_photo-1675827055694-010aef2cf08f',
    'https://images.unsplash.com/photo-1682685797208-c741d58c2be8',
    'https://images.unsplash.com/photo-1682685797229-090c88560126',
    'https://images.unsplash.com/photo-1682685797828-d3b2559774ba',
    'https://thisisbrokenurl.com/image.jpg', // Error case
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await CacheManager().clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Cache Cleared')));
              }
            },
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 100, // Show many items to test scrolling
        itemBuilder: (context, index) {
          final url = imageUrls[index % imageUrls.length];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ImageCachePlus(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context) => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    Text('Error', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
