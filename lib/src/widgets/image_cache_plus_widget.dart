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
  final int? memCacheWidth;
  final int? memCacheHeight;
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
    this.memCacheWidth,
    this.memCacheHeight,
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

    _controller =
        AnimationController(
          vsync: this,
          duration: widget.fadeDuration,
          lowerBound: 0.0,
          upperBound: 1.0,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            // Trigger rebuild to possibly remove placeholder from Stack
            setState(() {});
          }
        });

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

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
    if (widget.imageUrl != oldWidget.imageUrl ||
        widget.memCacheWidth != oldWidget.memCacheWidth ||
        widget.memCacheHeight != oldWidget.memCacheHeight) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    final ImageProvider baseProvider = CachedNetworkImageProvider(
      widget.imageUrl,
      headers: widget.httpHeaders,
    );

    final ImageProvider provider =
        (widget.memCacheWidth != null || widget.memCacheHeight != null)
        ? ResizeImage(
            baseProvider,
            width: widget.memCacheWidth,
            height: widget.memCacheHeight,
          )
        : baseProvider;

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
        _controller.value = 1.0;
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
    // 1. Error Case (Highest priority, replaces everything)
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

    // We use a Stack to handle the transition:
    // Bottom: Placeholder/Loading Indicator (only if needed)
    // Top: The Image (fading in)

    final List<Widget> children = [];

    // --- Bottom Layer: Placeholder ---
    // Show placeholder if:
    // 1. We are loading (_loading == true)
    // 2. OR the animation is running (opacity < 1.0) -> PREVENTS BACK VIEW
    // 3. BUT NOT if we have an "old image" from useOldImageOnUrlChange (handled by image itself being persistent)

    // Simplification: We always show the placeholder behind the image UNLESS the image is fully loaded and opaque.
    // If we have no image info yet, we definitely need the placeholder.
    // If we have image info but opacity < 1.0, we still need placeholder behind.

    final bool showPlaceholder = _loading || _controller.value != 1.0;

    if (showPlaceholder) {
      if (widget.placeholder != null) {
        children.add(Positioned.fill(child: widget.placeholder!(context)));
      } else {
        children.add(
          Positioned.fill(
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
          ),
        );
      }
    }

    // --- Top Layer: Image ---
    if (_imageInfo != null) {
      children.add(
        FadeTransition(
          opacity: _animation,
          child: RawImage(
            image: _imageInfo!.image,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(fit: StackFit.expand, children: children),
    );
  }
}
