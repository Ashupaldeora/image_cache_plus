import 'package:flutter/material.dart';
import '../image_provider.dart';

/// A widget that displays a cached network image.
class ImageCachePlus extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? errorWidget;
  final Duration fadeDuration;
  final Alignment alignment;
  final Map<String, String>? httpHeaders;
  final bool useOldImageOnUrlChange;

  const ImageCachePlus({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.fadeDuration = const Duration(milliseconds: 300),
    this.alignment = Alignment.center,
    this.httpHeaders,
    this.useOldImageOnUrlChange = false,
  });

  @override
  State<ImageCachePlus> createState() => _ImageCachePlusState();
}

class _ImageCachePlusState extends State<ImageCachePlus>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  ImageInfo? _imageInfo;
  bool _loading = true;
  Object? _error;
  ImageChunkEvent? _loadingProgress;

 @override
void initState() {
  super.initState();

  _controller = AnimationController(
    vsync: this,
    duration: widget.fadeDuration,
    lowerBound: 0.7,   // 👈 NEVER go fully transparent
    upperBound: 1.0,
  );

  _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeIn,
  );

  // Start in loading state
  _loading = true;
}


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(ImageCachePlus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    final CachedNetworkImageProvider provider = CachedNetworkImageProvider(
      widget.imageUrl,
      headers: widget.httpHeaders,
    );

    final ImageStream newStream = provider.resolve(
      createLocalImageConfiguration(
        context,
        size: widget.width != null && widget.height != null
            ? Size(widget.width!, widget.height!)
            : null,
      ),
    );

    if (newStream.key == _imageStream?.key) {
      return;
    }

    _stopListening();
    _imageStream = newStream;
    _imageStreamListener = ImageStreamListener(
      _handleImageFrame,
      onChunk: _handleChunk,
      onError: _handleError,
    );

    // Reset state only if we don't want to keep old image
    if (!widget.useOldImageOnUrlChange) {
      setState(() {
        _loading = true;
        _error = null;
        _imageInfo = null;
        _loadingProgress = null;
      });
      _controller.reset();
    } else {
      // Kepp showing old image while loading new one
      // But we can show a progress indicator on top if needed?
      // For now, let's just tracking loading state but keep _imageInfo
    }

    newStream.addListener(_imageStreamListener!);
  }

  void _handleImageFrame(ImageInfo imageInfo, bool synchronousCall) {
    if (mounted) {
      setState(() {
        _imageInfo = imageInfo;
        _loading = false;
        _error = null;
      });
      if (synchronousCall) {
        _controller.value = 1.0; // No fade if synchronous (e.g. memory cache)
      } else {
        _controller.forward();
      }
    }
  }

  void _handleChunk(ImageChunkEvent event) {
    if (mounted) {
      setState(() {
        _loadingProgress = event;
      });
    }
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    if (mounted) {
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _stopListening() {
    _imageStream?.removeListener(_imageStreamListener!);
    _imageStream = null;
    _imageStreamListener = null;
  }

  @override
  void dispose() {
    _stopListening();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Error Case
    if (_error != null) {
      if (widget.errorWidget != null) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.errorWidget!(context),
        );
      }
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: const Icon(Icons.error, color: Colors.red),
      );
    }

    // 2. Loading Case (but no image yet)
    if (_loading && _imageInfo == null) {
      if (widget.placeholder != null) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.placeholder!(context),
        );
      }
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: CircularProgressIndicator(
            value:
                _loadingProgress != null &&
                    _loadingProgress!.expectedTotalBytes != null
                ? _loadingProgress!.cumulativeBytesLoaded /
                      _loadingProgress!.expectedTotalBytes!
                : null,
          ),
        ),
      );
    }

    // 3. Image Loaded (or keeping old image while loading new one)
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FadeTransition(
        opacity: _animation,
        child: RawImage(
          image: _imageInfo?.image,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
        ),
      ),
    );
  }
}
