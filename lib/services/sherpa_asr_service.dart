import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:insurance_manager/utils/app_logger.dart';

/// 离线 ASR 模型配置
enum OfflineASRModel {
  paraformerZh(
    'paraformer-zh',
    'Paraformer 中文离线',
    'model.int8.onnx',
    'tokens.txt',
    ~120,
  );

  const OfflineASRModel(
    this.key,
    this.displayName,
    this.modelFile,
    this.tokensFile,
    this.sizeMB,
  );

  final String key;
  final String displayName;
  final String modelFile;
  final String tokensFile;
  final int sizeMB;
}

/// Sherpa-ONNX 离线语音识别服务
class SherpaASRService {
  static SherpaASRService? _instance;
  static SherpaASRService get instance => _instance ??= SherpaASRService._();

  SherpaASRService._();

  sherpa.OfflineRecognizer? _recognizer;
  OfflineASRModel? _currentModel;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _bindingsInitialized = false;

  bool get isInitialized => _isInitialized;
  OfflineASRModel? get currentModel => _currentModel;

  /// 初始化 sherpa-onnx 原生绑定（只需调用一次）
  void _ensureBindingsInitialized() {
    if (_bindingsInitialized) return;
    sherpa.initBindings();
    _bindingsInitialized = true;
    AppLogger.info('SherpaASR: 原生绑定已初始化');
  }

  /// 获取模型存储根目录
  Future<String> _getModelDir() async {
    final appDir = await getApplicationSupportDirectory();
    return '${appDir.path}/sherpa_models';
  }

  /// 获取指定模型的本地目录
  Future<String> getModelPath(OfflineASRModel model) async {
    final baseDir = await _getModelDir();
    return '$baseDir/${model.key}';
  }

  /// 检查模型是否已拷贝到本地
  Future<bool> isModelReady(OfflineASRModel model) async {
    final modelDir = await getModelPath(model);
    final modelFile = File('$modelDir/${model.modelFile}');
    final tokensFile = File('$modelDir/${model.tokensFile}');
    return modelFile.existsSync() && tokensFile.existsSync();
  }

  /// 检查模型文件是否在本地可用
  Future<bool> ensureModelAvailable(OfflineASRModel model) async {
    if (await isModelReady(model)) {
      return true;
    }
    AppLogger.error(
      '语音识别模型文件不存在: ${model.displayName}\n'
      '请手动执行下载脚本:\n'
      '  bash scripts/download_sherpa_models.sh',
    );
    return false;
  }

  /// 从网络下载模型文件
  /// 获取已就绪的模型列表
  Future<List<OfflineASRModel>> getReadyModels() async {
    final result = <OfflineASRModel>[];
    for (final model in OfflineASRModel.values) {
      if (await isModelReady(model)) {
        result.add(model);
      }
    }
    return result;
  }

  /// 初始化识别器（使用指定模型）
  Future<bool> initialize({OfflineASRModel? model}) async {
    if (_isInitializing) return false;
    _isInitializing = true;

    try {
      _ensureBindingsInitialized();

      final targetModel = model ?? OfflineASRModel.paraformerZh;

      // 确保模型可用（优先从 assets 拷贝，否则检查已下载）
      if (!await ensureModelAvailable(targetModel)) {
        AppLogger.error('模型不可用: ${targetModel.key}');
        _isInitializing = false;
        return false;
      }

      // 如果已经用同一模型初始化，跳过
      if (_isInitialized && _currentModel == targetModel) {
        _isInitializing = false;
        return true;
      }

      // 释放旧识别器
      _recognizer?.free();
      _recognizer = null;
      _isInitialized = false;

      final modelDir = await getModelPath(targetModel);

      // 创建离线模型配置
      final offlineModelConfig = sherpa.OfflineModelConfig(
        paraformer: sherpa.OfflineParaformerModelConfig(
          model: '$modelDir/${targetModel.modelFile}',
        ),
        tokens: '$modelDir/${targetModel.tokensFile}',
        numThreads: 2,
        debug: false,
        provider: 'cpu',
      );

      // 创建离线识别器配置
      final recognizerConfig = sherpa.OfflineRecognizerConfig(
        model: offlineModelConfig,
      );

      _recognizer = sherpa.OfflineRecognizer(recognizerConfig);
      _currentModel = targetModel;
      _isInitialized = true;
      AppLogger.info('SherpaASR 初始化成功: ${targetModel.displayName}');
      return true;
    } catch (e) {
      AppLogger.error('SherpaASR 初始化失败: $e');
      _isInitialized = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// 识别音频文件（WAV 16kHz mono）
  ///
  /// 返回识别文本，失败返回 null
  Future<String?> recognizeFile(String audioPath) async {
    if (!_isInitialized || _recognizer == null) {
      AppLogger.error('SherpaASR 未初始化');
      return null;
    }

    try {
      final wave = sherpa.readWave(audioPath);
      if (wave.samples.isEmpty) {
        AppLogger.error('读取音频文件失败: $audioPath');
        return null;
      }

      final stream = _recognizer!.createStream();
      stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);

      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      stream.free();

      final text = result.text.trim();
      AppLogger.info('SherpaASR 识别结果: $text');
      return text.isNotEmpty ? text : null;
    } catch (e) {
      AppLogger.error('SherpaASR 识别失败: $e');
      return null;
    }
  }

  /// 识别 PCM 音频数据（16kHz, 16bit, mono, Float32 normalized [-1,1]）
  ///
  /// 用于从录音流中直接识别
  Future<String?> recognizePCM(
    Float32List samples, {
    int sampleRate = 16000,
  }) async {
    if (!_isInitialized || _recognizer == null) {
      AppLogger.error('SherpaASR 未初始化');
      return null;
    }

    try {
      final stream = _recognizer!.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);

      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      stream.free();

      final text = result.text.trim();
      return text.isNotEmpty ? text : null;
    } catch (e) {
      AppLogger.error('SherpaASR PCM识别失败: $e');
      return null;
    }
  }

  /// 停用识别器（释放资源但保留实例，可再次 initialize）
  void deactivate() {
    _recognizer?.free();
    _recognizer = null;
    _isInitialized = false;
    _currentModel = null;
  }

  /// 释放资源并销毁实例
  void dispose() {
    _recognizer?.free();
    _recognizer = null;
    _isInitialized = false;
    _currentModel = null;
    _instance = null;
  }
}
