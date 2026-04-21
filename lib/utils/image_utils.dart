import 'package:insurecrm/utils/app_logger.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 图片压缩与缩略图工具
class ImageUtils {
  /// 最大原图宽度（超过则压缩）
  static const int maxImageWidth = 1920;

  /// 最大原图高度（超过则压缩）
  static const int maxImageHeight = 1920;

  /// 缩略图尺寸（正方形）
  static const int thumbnailSize = 200;

  /// JPEG 压缩质量 (0-100)
  static const int jpegQuality = 85;

  /// 缩略图 JPEG 质量
  static const int thumbQuality = 70;

  // Web 平台不使用此工具
  static bool get isSupported => !kIsWeb;

  /// 压缩图片并保存到应用目录，返回保存后的路径
  /// 如果不需要压缩，直接复制原文件
  static Future<String> compressAndSave(File originalFile, {
    String? subDir,
    String? fileName,
    int? maxWidth,
    int? maxHeight,
  }) async {
    if (!isSupported) return originalFile.path;

    final directory = await getApplicationDocumentsDirectory();
    final targetDir = subDir != null
        ? Directory('${directory.path}/$subDir')
        : directory;

    if (!targetDir.existsSync()) targetDir.createSync(recursive: true);

    final outputName = fileName ??
        '${DateTime.now().millisecondsSinceEpoch}${path.extension(originalFile.path)}';

    final outputPath = '${targetDir.path}/$outputName';

    try {
      final bytes = await originalFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) {
        // 无法解码（非图片），直接复制
        await originalFile.copy(outputPath);
        return outputPath;
      }

      final w = maxWidth ?? maxImageWidth;
      final h = maxHeight ?? maxImageHeight;

      // 只有当宽或高超过限制时才压缩
      if (decodedImage.width <= w && decodedImage.height <= h) {
        await originalFile.copy(outputPath);
        return outputPath;
      }

      // 计算等比缩放后的尺寸
      final resized = img.copyResize(
        decodedImage,
        width: w > decodedImage.width ? decodedImage.width : w,
        height: h > decodedImage.height ? decodedImage.height : h,
        interpolation: img.Interpolation.linear,
      );

      final outFile = File(outputPath);
      final encoder = img.JpegEncoder(quality: jpegQuality);
      await outFile.writeAsBytes(encoder.encode(resized));
      return outputPath;
    } catch (e) {
      AppLogger.error('compress error: $e');
      // 压缩失败时回退到直接复制
      await originalFile.copy(outputPath);
      return outputPath;
    }
  }

  /// 从原始文件生成缩略图，返回缩略图路径
  static Future<String?> generateThumbnail(File originalFile) async {
    if (!isSupported) return null;

    try {
      final bytes = await originalFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return null;

      final directory = await getApplicationDocumentsDirectory();
      final thumbDir = Directory('${directory.path}/thumbnails');
      if (!thumbDir.existsSync()) thumbDir.createSync(recursive: true);

      // 正方形裁切+缩放
      final cropped = _centerCropSquare(decodedImage);
      final resized = img.copyResize(
        cropped,
        width: thumbnailSize,
        height: thumbnailSize,
        interpolation: img.Interpolation.linear,
      );

      final outputPath =
          '${thumbDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final thumbEncoder = img.JpegEncoder(quality: thumbQuality);
      await File(outputPath)
          .writeAsBytes(thumbEncoder.encode(resized));
      return outputPath;
    } catch (e) {
      AppLogger.error('generateThumbnail error: $e');
      return null;
    }
  }

  /// 获取文件大小（格式化显示）
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 获取文件大小（字节）
  static int getFileSize(String filePath) {
    try {
      return File(filePath).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  /// 删除物理文件
  static void deleteFiles(List<String> paths) {
    for (var p in paths) {
      try { File(p).deleteSync(); } catch (_) {}
    }
  }

  /// 中心裁切为正方形
  static img.Image _centerCropSquare(img.Image image) {
    final size = image.width < image.height ? image.width : image.height;
    final x = ((image.width - size) / 2).round();
    final y = ((image.height - size) / 2).round();
    return img.copyCrop(image, x: x, y: y, width: size, height: size);
  }
}
