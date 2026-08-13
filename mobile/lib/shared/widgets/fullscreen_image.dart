import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/media_io.dart';

Future<void> showFullscreenImage(
  BuildContext context, {
  String? filePath,
  String? url,
  Map<String, String>? headers,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => FullscreenImagePage(
        filePath: filePath,
        url: url,
        headers: headers,
      ),
    ),
  );
}

class FullscreenImagePage extends StatelessWidget {
  const FullscreenImagePage({
    super.key,
    this.filePath,
    this.url,
    this.headers,
  });

  final String? filePath;
  final String? url;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    Widget image;
    final file = filePath != null && filePath!.isNotEmpty ? File(filePath!) : null;
    if (file != null && file.existsSync()) {
      image = Image.file(file, fit: BoxFit.contain);
    } else if (url != null && url!.isNotEmpty) {
      image = Image.network(
        url!,
        fit: BoxFit.contain,
        headers: headers ?? const {},
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 48),
      );
    } else {
      image = const Icon(Icons.image_outlined, size: 48);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('تصویر'),
        actions: [
          IconButton(
            tooltip: 'ذخیره',
            onPressed: () async {
              try {
                await MediaIo.saveImage(
                  filePath: filePath,
                  url: url,
                  headers: headers,
                );
                if (context.mounted) {
                  MediaIo.toast(context, 'در گالری ذخیره شد');
                }
              } catch (e) {
                if (context.mounted) MediaIo.toast(context, '$e');
              }
            },
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'اشتراک',
            onPressed: () => MediaIo.shareImage(
              filePath: filePath,
              url: url,
              headers: headers,
            ),
            icon: const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.6,
          maxScale: 5,
          child: SizedBox(width: double.infinity, child: image),
        ),
      ),
    );
  }
}

class TappableImage extends StatelessWidget {
  const TappableImage({
    super.key,
    required this.child,
    this.filePath,
    this.url,
    this.headers,
  });

  final Widget child;
  final String? filePath;
  final String? url;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showFullscreenImage(
        context,
        filePath: filePath,
        url: url,
        headers: headers,
      ),
      child: child,
    );
  }
}

