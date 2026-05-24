import 'package:paddle_ocr_flutter/paddle_ocr_flutter.dart';
import 'package:insurance_manager/utils/app_logger.dart';

/// 本地 OCR 服务
///
/// 使用 PaddleOCR PP-OCRv5 离线模型，无需网络，数据不离开设备。
/// 模型内置于 paddle_ocr_flutter 插件 assets 中（~21MB），首次 init 时自动加载。
class OcrService {
  static OcrService? _instance;
  static OcrService get instance => _instance ??= OcrService._();

  OcrService._();

  final PaddleOcrFlutter _ocr = PaddleOcrFlutter();
  bool _isInitialized = false;
  bool _isInitializing = false;

  bool get isInitialized => _isInitialized;

  /// 初始化 OCR 引擎
  ///
  /// 初始化前会先让出 UI 线程，确保启动页面能渲染模型名称，
  /// 然后才加载模型（C++ 同步调用，会短暂阻塞 UI）。
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isInitializing) return false;
    _isInitializing = true;

    try {
      // 让出 UI 线程，确保启动页面能渲染模型名称
      await Future.delayed(const Duration(milliseconds: 100));
      await _ocr.init(threadNum: 4);
      _isInitialized = true;
      AppLogger.info('OcrService 初始化成功 (PP-OCRv5 离线)');
      return true;
    } catch (e) {
      AppLogger.error('OcrService 初始化失败: $e');
      _isInitialized = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// 识别图片中的文字
  ///
  /// [imagePath] 图片绝对路径
  /// 返回完整识别文本，失败返回 null
  Future<String?> recognizeText(String imagePath) async {
    if (!_isInitialized) {
      AppLogger.error('OcrService 未初始化');
      return null;
    }

    try {
      final results = await _ocr.recognize(imagePath);
      if (results.isEmpty) return null;

      // 按 reading order 拼接（插件已排序 top-to-bottom, left-to-right）
      final text = results.map((r) => r.text).join('\n').trim();
      AppLogger.info('OCR 识别结果: ${text.length} 字符, ${results.length} 区域');
      return text.isNotEmpty ? text : null;
    } catch (e) {
      AppLogger.error('OCR 识别失败: $e');
      return null;
    }
  }

  /// 识别图片，返回结构化结果（含坐标和置信度）
  Future<List<OcrResult>> recognize(String imagePath) async {
    if (!_isInitialized) {
      AppLogger.error('OcrService 未初始化');
      return [];
    }

    try {
      return await _ocr.recognize(imagePath);
    } catch (e) {
      AppLogger.error('OCR 识别失败: $e');
      return [];
    }
  }

  /// 停用（释放引擎，可再次 initialize）
  Future<void> deactivate() async {
    if (_isInitialized) {
      await _ocr.dispose();
      _isInitialized = false;
      AppLogger.info('OcrService 已停用');
    }
  }

  /// 销毁实例
  void dispose() {
    if (_isInitialized) {
      _ocr.dispose();
      _isInitialized = false;
    }
    _instance = null;
  }
}
