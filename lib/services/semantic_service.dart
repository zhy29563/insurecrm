import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:insurance_manager/utils/app_logger.dart';

/// 中文语义嵌入模型配置
const _kModelDir = 'embedding_model';
const _kModelFile = 'model.onnx';
const _kVocabFile = 'vocab.txt';

/// BERT 特殊 token
const _clsToken = '[CLS]';
const _sepToken = '[SEP]';
const _unkToken = '[UNK]';
const _padToken = '[PAD]';

/// BGE-small-zh-v1.5 模型参数
const _maxSeqLength = 128;
const _padTokenId = 0;
const _clsTokenId = 101;
const _sepTokenId = 102;

/// 本地语义分析服务
///
/// 使用 BAAI/bge-small-zh-v1.5 ONNX 模型进行文本语义嵌入，
/// 无需网络，数据不离开设备。通过余弦相似度计算文本间语义相关性，
/// 用于产品推荐等场景的智能匹配。
class SemanticService {
  static SemanticService? _instance;
  static SemanticService get instance => _instance ??= SemanticService._();

  SemanticService._();

  OrtSession? _session;
  List<String> _vocab = [];
  Map<String, int> _vocabMap = {};
  bool _isInitialized = false;
  bool _isInitializing = false;

  bool get isInitialized => _isInitialized;
  String get modelName => 'BGE-small-zh 语义分析模型';

  /// 获取模型存储根目录
  Future<String> _getModelDir() async {
    final appDir = await getApplicationSupportDirectory();
    return '${appDir.path}/$_kModelDir';
  }

  /// 从 assets 拷贝模型文件到本地目录
  Future<bool> _copyModelFromAssets() async {
    try {
      final modelDir = await _getModelDir();
      final dir = Directory(modelDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // 拷贝 ONNX 模型
      final modelPath = '$modelDir/$_kModelFile';
      final modelFile = File(modelPath);
      if (!modelFile.existsSync() || modelFile.lengthSync() == 0) {
        AppLogger.info('拷贝嵌入模型: $_kModelDir/$_kModelFile');
        final data = await rootBundle.load('assets/$_kModelDir/$_kModelFile');
        final bytes = data.buffer.asUint8List();

        const chunkSize = 4 * 1024 * 1024;
        final sink = modelFile.openWrite();
        for (int offset = 0; offset < bytes.length; offset += chunkSize) {
          final end =
              offset + chunkSize > bytes.length ? bytes.length : offset + chunkSize;
          sink.add(bytes.sublist(offset, end));
          await sink.flush();
        }
        await sink.close();
        AppLogger.info('嵌入模型拷贝完成: ${bytes.length} bytes');
      }

      // 加载 vocab（直接从 assets 读取文本）
      try {
        final vocabStr =
            await rootBundle.loadString('assets/$_kModelDir/$_kVocabFile');
        _vocab = vocabStr.split('\n').where((s) => s.isNotEmpty).toList();
        _buildVocabMap();
        AppLogger.info('Vocab 加载完成: ${_vocab.length} tokens');
      } catch (e) {
        // 尝试从本地目录读取
        final vocabPath = '$modelDir/$_kVocabFile';
        final vocabFile = File(vocabPath);
        if (vocabFile.existsSync()) {
          final vocabStr = await vocabFile.readAsString();
          _vocab = vocabStr.split('\n').where((s) => s.isNotEmpty).toList();
          _buildVocabMap();
          AppLogger.info('Vocab 从本地加载: ${_vocab.length} tokens');
        } else {
          // 使用内置基础 vocab
          _useFallbackVocab();
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('拷贝嵌入模型失败: $e');
      return false;
    }
  }

  void _buildVocabMap() {
    _vocabMap = {};
    for (int i = 0; i < _vocab.length; i++) {
      _vocabMap[_vocab[i]] = i;
    }
  }

  /// 使用内置基础 vocab（当 vocab.txt 不存在时的降级方案）
  void _useFallbackVocab() {
    AppLogger.warning('使用内置基础 vocab（降级模式）');
    _vocab = [];
    _vocabMap = {};
    // 基础 token ID 映射
    _vocabMap[_padToken] = _padTokenId;
    _vocabMap[_clsToken] = _clsTokenId;
    _vocabMap[_sepToken] = _sepTokenId;
    _vocabMap[_unkToken] = 100;
  }

  /// 简化版中文 BERT tokenizer
  ///
  /// 对中文文本进行字符级分词，对英文/数字进行子词处理。
  /// 输出 input_ids 和 attention_mask。
  _TokenResult _tokenize(String text) {
    final inputIds = <int>[_clsTokenId];
    final attentionMask = <int>[1];

    // 截断过长文本（预留 CLS + SEP）
    const maxContentLen = _maxSeqLength - 2;

    int charCount = 0;
    for (int i = 0; i < text.length && charCount < maxContentLen; i++) {
      final char = text[i];
      if (char.trim().isEmpty) continue;

      // 优先查完整字符
      if (_vocabMap.containsKey(char)) {
        inputIds.add(_vocabMap[char]!);
        attentionMask.add(1);
        charCount++;
      } else {
        // 尝试 UTF-8 字节级处理（针对 BERT WordPiece）
        final bytes = char.codeUnits;
        bool allFound = true;
        final byteIds = <int>[];

        for (final byte in bytes) {
          final byteStr = '[${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}]';
          if (_vocabMap.containsKey(byteStr)) {
            byteIds.add(_vocabMap[byteStr]!);
          } else if (_vocabMap.containsKey('##$byteStr')) {
            byteIds.add(_vocabMap['##$byteStr']!);
          } else {
            allFound = false;
            break;
          }
        }

        if (allFound && byteIds.isNotEmpty) {
          for (final id in byteIds) {
            if (charCount >= maxContentLen) break;
            inputIds.add(id);
            attentionMask.add(1);
            charCount++;
          }
        } else {
          // UNK
          if (charCount < maxContentLen) {
            inputIds.add(_vocabMap[_unkToken] ?? 100);
            attentionMask.add(1);
            charCount++;
          }
        }
      }
    }

    inputIds.add(_sepTokenId);
    attentionMask.add(1);

    return _TokenResult(inputIds, attentionMask);
  }

  /// 初始化语义分析模型
  ///
  /// 模型文件拷贝完成后会先让出 UI 线程，确保启动页面能渲染加载状态，
  /// 然后才加载模型（C++ 同步调用，会短暂阻塞 UI）。
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isInitializing) return false;
    _isInitializing = true;

    try {
      // 拷贝模型到本地
      if (!await _copyModelFromAssets()) {
        AppLogger.error('嵌入模型文件不可用');
        _isInitializing = false;
        return false;
      }

      // 让出 UI 线程
      await Future.delayed(const Duration(milliseconds: 100));

      final modelDir = await _getModelDir();
      final modelPath = '$modelDir/$_kModelFile';
      final modelFile = File(modelPath);

      if (!modelFile.existsSync()) {
        AppLogger.error('嵌入模型文件不存在: $modelPath');
        _isInitializing = false;
        return false;
      }

      // 创建 ONNX Runtime session
      final sessionOptions = OrtSessionOptions();
      sessionOptions.setIntraOpNumThreads(2);
      sessionOptions.setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableAll,
      );
      sessionOptions.appendCPUProvider(CPUFlags.useArena);

      _session = OrtSession.fromFile(modelFile, sessionOptions);
      sessionOptions.release();

      _isInitialized = true;
      AppLogger.info('SemanticService 初始化成功 (BGE-small-zh ONNX)');
      return true;
    } catch (e) {
      AppLogger.error('SemanticService 初始化失败: $e');
      _isInitialized = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// 计算文本的语义嵌入向量
  ///
  /// 返回 Float32List（维度 512），失败返回 null
  Float32List? _computeEmbedding(String text) {
    if (!_isInitialized || _session == null) {
      AppLogger.error('SemanticService 未初始化');
      return null;
    }

    try {
      final tokenResult = _tokenize(text);
      final seqLen = tokenResult.inputIds.length;

      // 创建 input_ids tensor: [1, seqLen]
      final inputIdsData = Int64List.fromList(tokenResult.inputIds);
      final inputIdsTensor =
          OrtValueTensor.createTensorWithDataList(inputIdsData, [1, seqLen]);

      // 创建 attention_mask tensor: [1, seqLen]
      final attentionMaskData = Int64List.fromList(tokenResult.attentionMask);
      final attentionMaskTensor =
          OrtValueTensor.createTensorWithDataList(attentionMaskData, [1, seqLen]);

      // 创建 token_type_ids tensor: [1, seqLen] (全 0)
      final tokenTypeIdsData = Int64List(seqLen);
      final tokenTypeIdsTensor =
          OrtValueTensor.createTensorWithDataList(tokenTypeIdsData, [1, seqLen]);

      final runOptions = OrtRunOptions();

      final inputs = <String, OrtValue>{
        'input_ids': inputIdsTensor,
        'attention_mask': attentionMaskTensor,
        'token_type_ids': tokenTypeIdsTensor,
      };

      final outputs = _session!.run(runOptions, inputs);

      // 释放输入
      inputIdsTensor.release();
      attentionMaskTensor.release();
      tokenTypeIdsTensor.release();
      runOptions.release();

      if (outputs.isEmpty || outputs[0] == null) {
        AppLogger.error('嵌入模型推理输出为空');
        return null;
      }

      // 获取 last_hidden_state 输出: [1, seqLen, 512]
      final outputTensor = outputs[0] as OrtValueTensor;
      final outputValue = outputTensor.value;

      outputTensor.release();

      if (outputValue is! List) {
        AppLogger.error('嵌入模型输出类型异常: ${outputValue.runtimeType}');
        return null;
      }

      // 提取 CLS token 的嵌入向量（第一个 token）
      // outputValue shape: [1, seqLen, embeddingDim]
      final batch = outputValue[0] as List;
      final clsEmbedding = batch[0] as List;

      // BGE 模型需要对嵌入向量做 L2 归一化
      final embedding = Float32List(clsEmbedding.length);
      double norm = 0.0;
      for (int i = 0; i < clsEmbedding.length; i++) {
        final v = (clsEmbedding[i] as num).toDouble();
        embedding[i] = v;
        norm += v * v;
      }
      norm = math.sqrt(norm);
      if (norm > 0) {
        for (int i = 0; i < embedding.length; i++) {
          embedding[i] /= norm;
        }
      }

      return embedding;
    } catch (e) {
      AppLogger.error('计算嵌入向量失败: $e');
      return null;
    }
  }

  /// 计算两个文本的语义相似度
  ///
  /// 返回 0.0~1.0 之间的相似度分数，失败返回 0.0
  double computeSimilarity(String text1, String text2) {
    final emb1 = _computeEmbedding(text1);
    final emb2 = _computeEmbedding(text2);

    if (emb1 == null || emb2 == null) return 0.0;
    if (emb1.length != emb2.length) return 0.0;

    // 余弦相似度（向量已归一化，直接点积即可）
    double dotProduct = 0.0;
    for (int i = 0; i < emb1.length; i++) {
      dotProduct += emb1[i] * emb2[i];
    }

    // 将 [-1, 1] 映射到 [0, 1]
    return (dotProduct + 1.0) / 2.0;
  }

  /// 计算文本的嵌入向量（缓存友好，可批量处理）
  Float32List? getEmbedding(String text) => _computeEmbedding(text);

  /// 批量计算文本嵌入向量
  Map<String, Float32List> getEmbeddings(List<String> texts) {
    final result = <String, Float32List>{};
    for (final text in texts) {
      final emb = _computeEmbedding(text);
      if (emb != null) {
        result[text] = emb;
      }
    }
    return result;
  }

  /// 计算查询文本与候选文本列表的语义相似度排序
  ///
  /// 返回按相似度从高到低排序的 (索引, 相似度) 列表
  List<(int, double)> rankByText(String query, List<String> candidates) {
    final queryEmb = _computeEmbedding(query);
    if (queryEmb == null) return [];

    final scores = <(int, double)>[];
    for (int i = 0; i < candidates.length; i++) {
      final candEmb = _computeEmbedding(candidates[i]);
      if (candEmb == null) continue;

      double dotProduct = 0.0;
      for (int j = 0; j < queryEmb.length && j < candEmb.length; j++) {
        dotProduct += queryEmb[j] * candEmb[j];
      }
      scores.add((i, (dotProduct + 1.0) / 2.0));
    }

    scores.sort((a, b) => b.$2.compareTo(a.$2));
    return scores;
  }

  /// 停用（释放 session，可再次 initialize）
  void deactivate() {
    _session?.release();
    _session = null;
    _isInitialized = false;
    AppLogger.info('SemanticService 已停用');
  }

  /// 销毁实例
  void dispose() {
    _session?.release();
    _session = null;
    _isInitialized = false;
    _instance = null;
  }
}

/// Tokenizer 输出结果
class _TokenResult {
  final List<int> inputIds;
  final List<int> attentionMask;

  _TokenResult(this.inputIds, this.attentionMask);
}
