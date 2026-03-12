import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A full-screen dialog for viewing an image with pan & zoom.
class FullScreenImageViewer extends StatelessWidget {
  final ImageProvider image;
  final String? alt;

  const FullScreenImageViewer({
    super.key,
    required this.image,
    this.alt,
  });

  /// Open from a network URL.
  static void showNetwork(BuildContext context, String url, {String? alt}) {
    _show(context, FullScreenImageViewer(image: NetworkImage(url), alt: alt));
  }

  /// Open from a local file.
  static void showFile(BuildContext context, File file, {String? alt}) {
    _show(context, FullScreenImageViewer(image: FileImage(file), alt: alt));
  }

  static void _show(BuildContext context, FullScreenImageViewer viewer) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => viewer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Zoomable image
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Center(
                    child: Image(
                      image: image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, _) => const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image,
                                color: Colors.white54, size: 48),
                            SizedBox(height: 12),
                            Text('Failed to load image',
                                style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Close button
              Positioned(
                top: 12,
                right: 12,
                child: _CloseButton(onPressed: () => Navigator.of(context).pop()),
              ),

              // Alt text
              if (alt != null && alt!.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: Colors.black54,
                    child: Text(
                      alt!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.close, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
