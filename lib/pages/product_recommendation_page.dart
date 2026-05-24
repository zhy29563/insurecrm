import 'package:insurance_manager/utils/app_logger.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/models/product.dart';
import 'package:insurance_manager/widgets/app_components.dart';
import 'package:insurance_manager/services/sherpa_asr_service.dart';
import 'package:insurance_manager/services/semantic_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:insurance_manager/services/ocr_service.dart';

class ProductRecommendationPage extends StatefulWidget {
  const ProductRecommendationPage({super.key});

  @override
  _ProductRecommendationPageState createState() =>
      _ProductRecommendationPageState();
}

class _ProductRecommendationPageState extends State<ProductRecommendationPage> {
  final TextEditingController _requirementController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isListening = false;
  bool _isRecordingForASR = false;
  bool _isRecognizingImage = false;
  String? _recordingPath;

  // 语音/OCR 识别的片段列表（可单独删除）
  final List<_InputSegment> _segments = [];
  // 手动输入的文本
  String _manualText = '';

  static Color _categoryColor(String? category) =>
      AppDesign.categoryColor(category);
  List<Product> _recommendedProducts = [];
  bool _isAnalyzing = false;
  bool _hasAnalyzed = false; // 是否已执行过分析
  String? _analysisMode; // 当前使用的分析模式：'semantic' / 'keyword' / null

  @override
  void initState() {
    super.initState();
    _requirementController.addListener(_onManualTextChanged);
  }

  void _onManualTextChanged() {
    _manualText = _requirementController.text;
  }

  /// 获取完整的需求文本（手动 + 片段）
  String get _fullRequirement {
    final parts = <String>[];
    if (_manualText.trim().isNotEmpty) parts.add(_manualText.trim());
    for (final seg in _segments) {
      if (seg.text.trim().isNotEmpty) parts.add(seg.text.trim());
    }
    return parts.join('，');
  }

  void _startListening() async {
    if (_isListening || _isRecordingForASR) return;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('需要麦克风权限才能使用语音输入'),
              action: SnackBarAction(
                label: '设置',
                onPressed: () => openAppSettings(),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      }
    }

    final sherpaASR = SherpaASRService.instance;
    if (sherpaASR.isInitialized) {
      await _startRecordingForOfflineASR();
    } else if (!kIsWeb) {
      // 按需加载 ASR 模型
      final ok = await _ensureModelLoaded(
        '语音识别模型',
        '正在初始化 Paraformer 语音识别模型...',
        () => sherpaASR.initialize(),
      );
      if (ok && sherpaASR.isInitialized) {
        await _startRecordingForOfflineASR();
      } else {
        await _startSystemASR();
      }
    } else {
      await _startSystemASR();
    }
  }

  /// 统一模型按需加载方法：显示进度弹窗，完成后返回是否成功
  Future<bool> _ensureModelLoaded(
    String modelName,
    String message,
    Future<bool> Function() initFn,
  ) async {
    bool? result;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // 异步执行初始化，完成后关闭弹窗
        initFn().then((success) {
          result = success;
          if (ctx.mounted) Navigator.pop(ctx, success);
        }).catchError((e) {
          AppLogger.error('加载$modelName 失败: $e');
          result = false;
          if (ctx.mounted) Navigator.pop(ctx, false);
        });
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _startSystemASR() async {
    if (!kIsWeb && Platform.isIOS) {
      var speechStatus = await Permission.speech.status;
      if (!speechStatus.isGranted) {
        speechStatus = await Permission.speech.request();
        if (!speechStatus.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('需要语音识别权限才能使用语音输入'),
              action: SnackBarAction(
                label: '设置',
                onPressed: () => openAppSettings(),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      }
    }

    final bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          String msg = '语音识别出错';
          if (error.errorMsg.contains('no-speech')) {
            msg = '未检测到语音，请重试';
          } else if (error.errorMsg.contains('audio')) {
            msg = '音频录制失败，请检查麦克风权限';
          } else if (error.permanent) {
            msg = '语音识别不可用，请检查设备设置';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
          );
        }
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (mounted && result.finalResult) {
            final text = result.recognizedWords;
            if (text.isNotEmpty) {
              final current = _requirementController.text.trim();
              final newText = current.isEmpty ? text : '$current，$text';
              _requirementController.text = newText;
            }
          }
        },
        localeId: 'zh_CN',
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: false,
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('语音识别不可用，请检查设备是否支持'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _startRecordingForOfflineASR() async {
    try {
      if (kIsWeb) {
        await _startSystemASR();
        return;
      }

      final tempDir = await getTemporaryDirectory();
      _recordingPath =
          '${tempDir.path}/asr_offline_${DateTime.now().millisecondsSinceEpoch}.wav';

      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: _recordingPath!,
        );
        if (!mounted) return;
        setState(() => _isRecordingForASR = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('麦克风权限未授权'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('starting recording for offline ASR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('录音启动失败'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _stopRecordingAndOfflineASR() async {
    if (!_isRecordingForASR || _recordingPath == null) return;

    try {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() => _isRecordingForASR = false);

      if (path == null || (kIsWeb ? false : !File(path).existsSync())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('录音文件不存在'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('正在离线识别语音...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final sherpaASR = SherpaASRService.instance;
      final transcript = await sherpaASR.recognizeFile(path);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (transcript != null && transcript.isNotEmpty) {
        if (mounted) {
          final current = _requirementController.text.trim();
          final newText = current.isEmpty ? transcript : '$current，$transcript';
          setState(() => _requirementController.text = newText);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('语音识别结果为空，请重试'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      try {
        if (!kIsWeb) {
          final file = File(path);
          if (file.existsSync()) file.deleteSync();
        }
      } catch (_) {}
    } catch (e) {
      AppLogger.error('offline ASR error: $e');
      if (mounted) {
        setState(() => _isRecordingForASR = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('离线语音识别失败：$e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _stopListening() {
    if (_isRecordingForASR) {
      _stopRecordingAndOfflineASR();
      return;
    }
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _clearAllInputs() {
    setState(() {
      _segments.clear();
      _requirementController.clear();
      _manualText = '';
      _recommendedProducts = [];
      _hasAnalyzed = false;
      _analysisMode = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('拍照识别功能在当前平台暂不可用')));
        return;
      }

      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '选择图片来源',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF43A047),
                  ),
                  title: const Text('拍照'),
                  subtitle: const Text('拍摄沟通记录'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF1E88E5),
                  ),
                  title: const Text('从相册选择'),
                  subtitle: const Text('选择已有的记录照片'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );

      if (source == null || !mounted) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (!context.mounted || image == null) return;

      setState(() {
        _isRecognizingImage = true;
      });

      final ocr = OcrService.instance;
      String? ocrTextResult;

      // 按需加载 OCR 模型
      if (!ocr.isInitialized) {
        await _ensureModelLoaded(
          '文字识别模型',
          '正在初始化 PP-OCRv5 文字识别模型...',
          () => ocr.initialize(),
        );
      }
      if (ocr.isInitialized) {
        ocrTextResult = await ocr.recognizeText(image.path);
      }
      final String ocrText = ocrTextResult?.trim() ?? '';

      if (ocrText.isEmpty) {
        if (mounted) {
          setState(() => _isRecognizingImage = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('未识别到文字，请确保照片清晰且包含文字内容'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      final result = await _showOCRResultDialog(ocrText);
      if (mounted) {
        setState(() => _isRecognizingImage = false);
        if (result != null && result.isNotEmpty) {
          final current = _requirementController.text.trim();
          final newText = current.isEmpty ? result : '$current，$result';
          setState(() => _requirementController.text = newText);
        }
      }
    } catch (e) {
      AppLogger.error('picking/recognizing image: $e');
      if (mounted) {
        setState(() => _isRecognizingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片识别失败，请重试'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<String?> _showOCRResultDialog(String ocrText) {
    final editController = TextEditingController(text: ocrText);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.document_scanner_rounded, color: Color(0xFF43A047)),
            SizedBox(width: 8),
            Text('识别结果'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已识别到文字内容，可编辑修正后填入需求框：',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: editController,
                  maxLines: 8,
                  autofocus: false,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final edited = editController.text.trim();
              Navigator.pop(context, edited.isNotEmpty ? edited : null);
            },
            child: const Text('确认填入'),
          ),
        ],
      ),
    ).whenComplete(() {
      editController.dispose();
    });
  }

  Future<void> _analyzeProducts() async {
    final requirement = _fullRequirement;
    if (requirement.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入客户要求')));
      return;
    }
    // 去除标点和空格后，有效内容至少需要2个字符
    final cleaned = requirement.replaceAll(RegExp(r'[，。、；：！？\s,.;:!?]'), '');
    if (cleaned.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的客户需求（至少2个字）')));
      return;
    }
    // 检测是否包含至少一个中文或有意义的英文单词
    final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(cleaned);
    final hasWord = RegExp(r'[a-zA-Z]{3,}').hasMatch(cleaned);
    if (!hasChinese && !hasWord) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有意义的客户需求描述')));
      return;
    }

    setState(() => _isAnalyzing = true);
    _hasAnalyzed = true;
    _analysisMode = null;

    final appState = Provider.of<AppState>(context, listen: false);
    final semantic = SemanticService.instance;

    // 按需加载语义分析模型
    if (!semantic.isInitialized) {
      await _ensureModelLoaded(
        '语义分析模型',
        '正在初始化 BGE-small-zh 语义分析模型...',
        () => semantic.initialize(),
      );
    }

    // 语义分析模式：使用嵌入模型计算相似度
    if (semantic.isInitialized) {
      AppLogger.info('使用语义分析模式 (BGE-small-zh)');
      _analysisMode = 'semantic';
      final scored = <Product, double>{};

      for (final product in appState.products) {
        // 组合产品文本信息用于语义匹配
        final productText = [
          product.name,
          product.category ?? '',
          product.description ?? '',
          product.sellingPoints ?? '',
        ].where((s) => s.isNotEmpty).join('，');

        if (productText.isEmpty) continue;

        final similarity = semantic.computeSimilarity(requirement, productText);
        if (similarity > 0.58) {
          // 阈值：相似度 > 0.58 才计入（提高门槛减少无关匹配）
          scored[product] = similarity;
        }
      }

      if (scored.isEmpty) {
        AppLogger.info('语义匹配无结果，降级为关键词匹配');
        _analysisMode = 'keyword';
        _fallbackKeywordMatch(appState, requirement);
        return;
      }

      final sorted = scored.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 区分校验：最高分必须比平均分高 15% 以上，否则认为输入无区分度
      if (scored.length >= 3) {
        final avgScore = scored.values.reduce((a, b) => a + b) / scored.length;
        final topScore = sorted.first.value;
        if ((topScore - avgScore) / avgScore < 0.15) {
          AppLogger.info(
            '语义区分度不足 (top=$topScore, avg=${avgScore.toStringAsFixed(3)})',
          );
          setState(() => _isAnalyzing = false);
          return;
        }
      }

      final recommended = sorted.take(5).map((e) => e.key).toList();

      if (recommended.isEmpty) {
        AppLogger.info('语义匹配无结果，降级为关键词匹配');
        _analysisMode = 'keyword';
        _fallbackKeywordMatch(appState, requirement);
        return;
      }

      setState(() {
        _recommendedProducts = recommended;
        _isAnalyzing = false;
      });
    } else {
      // 模型未初始化，降级为关键词匹配
      AppLogger.info('语义模型未就绪，降级为关键词匹配模式');
      _analysisMode = 'keyword';
      _fallbackKeywordMatch(appState, requirement);
    }
  }

  /// 降级方案：关键词匹配
  void _fallbackKeywordMatch(AppState appState, String requirement) {
    final reqLower = requirement.toLowerCase();
    final keywords = reqLower
        .split(RegExp(r'[,，、\s]+'))
        .where((s) => s.length >= 2)
        .toSet();

    final recommended = <Product>[];
    final scored = <Product, int>{};

    for (final product in appState.products) {
      int score = 0;
      final nameLower = product.name.toLowerCase();
      final categoryLower = product.category?.toLowerCase() ?? '';
      final descLower = product.description?.toLowerCase() ?? '';
      final pointsLower = product.sellingPoints?.toLowerCase() ?? '';

      for (final kw in keywords) {
        if (nameLower.contains(kw)) score += 10;
        if (categoryLower.contains(kw)) score += 8;
        if (descLower.contains(kw)) score += 5;
        if (pointsLower.contains(kw)) score += 5;
      }

      if (score == 0) {
        if (nameLower.contains(reqLower) || reqLower.contains(nameLower)) {
          score += 3;
        }
        if (categoryLower.contains(reqLower) ||
            reqLower.contains(categoryLower)) {
          score += 2;
        }
      }

      if (score > 0) {
        scored[product] = score;
      }
    }

    final sorted = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    recommended.addAll(sorted.take(5).map((e) => e.key));

    if (recommended.isEmpty) {
      // 无匹配结果，不兜底推荐
      setState(() => _isAnalyzing = false);
      return;
    }

    setState(() {
      _recommendedProducts = recommended;
      _isAnalyzing = false;
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _audioRecorder.dispose();
    _requirementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final hasAnyInput = _segments.isNotEmpty || _manualText.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('产品推荐'),
        actions: [
          if (hasAnyInput)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              tooltip: '清空所有',
              onPressed: _clearAllInputs,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 需求输入区 ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesign.cardBg(isDark),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [AppDesign.cardShadow(context)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.edit_note_rounded,
                          size: 20,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '客户要求',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      if (_segments.isNotEmpty)
                        Text(
                          '${_segments.length} 条识别',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 微信风格输入栏：[语音] [输入框] [拍照]
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 左侧语音按钮
                      GestureDetector(
                        onTap: _isListening || _isRecordingForASR
                            ? _stopListening
                            : _startListening,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isListening || _isRecordingForASR)
                                ? const Color(0xFFE53935).withValues(alpha: 0.1)
                                : Colors.grey.shade100,
                          ),
                          child: Icon(
                            _isListening || _isRecordingForASR
                                ? Icons.stop_rounded
                                : Icons.mic_none_rounded,
                            color: (_isListening || _isRecordingForASR)
                                ? const Color(0xFFE53935)
                                : Colors.grey.shade600,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 中间输入框（弹性填充）
                      Expanded(
                        child: TextField(
                          controller: _requirementController,
                          maxLines: 3,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: '输入客户的保险需求...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade400,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: primaryColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 右侧拍照按钮
                      IconButton(
                        onPressed: _isRecognizingImage ? () {} : _pickImage,
                        icon: Icon(
                          _isRecognizingImage
                              ? Icons.hourglass_top_rounded
                              : Icons.document_scanner_rounded,
                          size: 22,
                          color: _isRecognizingImage
                              ? Colors.orange
                              : const Color(0xFF43A047),
                        ),
                        tooltip: _isRecognizingImage ? '识别中' : '拍照识别',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 推荐按钮（全宽，独占一行）
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isAnalyzing ? null : _analyzeProducts,
                      icon: _isAnalyzing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(_isAnalyzing ? '分析' : 'AI分析与推荐'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 推荐结果区 ──
            if (_recommendedProducts.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.recommend_rounded,
                      size: 20,
                      color: Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '推荐产品 (${_recommendedProducts.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (_analysisMode != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _analysisMode == 'semantic'
                            ? const Color(0xFF1E88E5).withValues(alpha: 0.1)
                            : const Color(0xFF9E9E9E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _analysisMode == 'semantic'
                                ? Icons.psychology_rounded
                                : Icons.search_rounded,
                            size: 13,
                            color: _analysisMode == 'semantic'
                                ? const Color(0xFF1E88E5)
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _analysisMode == 'semantic' ? 'AI语义' : '关键词',
                            style: TextStyle(
                              fontSize: 11,
                              color: _analysisMode == 'semantic'
                                  ? const Color(0xFF1E88E5)
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              ..._recommendedProducts.map<Widget>(
                (product) => _buildProductCard(product, isDark),
              ),
            ] else if (!_isAnalyzing) ...[
              EmptyStatePlaceholder(
                icon: _hasAnalyzed
                    ? Icons.search_off_rounded
                    : Icons.lightbulb_outline_rounded,
                message: _hasAnalyzed
                    ? '未找到匹配的产品，请尝试更具体的需求描述'
                    : '输入客户需求，将为您推荐合适的产品',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product, bool isDark) {
    final List<String> advantages =
        product.sellingPoints
            ?.split(';')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    final color = _categoryColor(product.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppDesign.cardShadow(context)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 产品头部
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.shield_outlined, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      product.company,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (product.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product.category!,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          if (product.description != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                product.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ),
          if (advantages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: advantages.map<Widget>((adv) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    adv.trim(),
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// 识别片段来源
// ignore: unused_field
enum _InputSource { offlineASR, systemASR, ocr }

/// 识别片段
class _InputSegment {
  final String text;
  final _InputSource source;

  _InputSegment({required this.text, required this.source});
}
