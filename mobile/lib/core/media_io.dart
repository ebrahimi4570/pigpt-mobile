import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Save to device gallery + system share sheet for image/audio/file outputs.
class MediaIo {
  static final Dio _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 15)),
  );

  static Future<void> saveImage({
    String? filePath,
    String? url,
    Map<String, String>? headers,
    Uint8List? bytes,
  }) async {
    if (filePath != null && filePath.isNotEmpty && File(filePath).existsSync()) {
      await Gal.putImage(filePath);
      return;
    }
    final data = bytes ?? await _bytes(url, headers);
    if (data == null || data.isEmpty) {
      throw Exception('تصویر برای ذخیره موجود نیست');
    }
    await Gal.putImageBytes(
      data,
      name: 'pigpt-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  static Future<void> shareImage({
    String? filePath,
    String? url,
    Map<String, String>? headers,
    String? text,
  }) async {
    if (filePath != null && filePath.isNotEmpty && File(filePath).existsSync()) {
      await Share.shareXFiles([XFile(filePath)], text: text);
      return;
    }
    final data = await _bytes(url, headers);
    if (data == null) {
      if (url != null && url.isNotEmpty) {
        await Share.share(url);
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'pigpt-share.png'));
    await file.writeAsBytes(data);
    await Share.shareXFiles([XFile(file.path)], text: text);
  }

  static Future<void> shareFile(String path, {String? text}) async {
    await Share.shareXFiles([XFile(path)], text: text);
  }

  static Future<Uint8List?> _bytes(
    String? url,
    Map<String, String>? headers,
  ) async {
    if (url == null || url.isEmpty) return null;
    final res = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers,
      ),
    );
    final data = res.data;
    if (data == null) return null;
    return Uint8List.fromList(data);
  }

  static Future<File> writeTempBytes(List<int> bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes);
    return file;
  }

  static void toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class ImageActionBar extends StatelessWidget {
  const ImageActionBar({
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
    return Row(
      children: [
        TextButton.icon(
          onPressed: () async {
            try {
              await MediaIo.saveImage(
                filePath: filePath,
                url: url,
                headers: headers,
              );
              if (context.mounted) MediaIo.toast(context, 'در گالری ذخیره شد');
            } catch (e) {
              if (context.mounted) MediaIo.toast(context, '$e');
            }
          },
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('ذخیره'),
        ),
        TextButton.icon(
          onPressed: () async {
            try {
              await MediaIo.shareImage(
                filePath: filePath,
                url: url,
                headers: headers,
              );
            } catch (e) {
              if (context.mounted) MediaIo.toast(context, '$e');
            }
          },
          icon: const Icon(Icons.share_rounded, size: 16),
          label: const Text('اشتراک'),
        ),
      ],
    );
  }
}
