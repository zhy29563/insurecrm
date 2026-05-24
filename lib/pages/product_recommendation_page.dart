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

class _ProductRecommendationPageState extends State<ProductRecommendationPage>
    with TickerProviderStateMixin {
  final TextEditingController _requirementController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isListening = false;
  bool _isRecordingForASR = false;
  bool _isRecognizingImage = false;
  String? _recordingPath;

  // 语音/OCR 识别的片段列表（可单独删除）
  final List<_InputSegment> _segments = [];
  String _manualText = '';

  static Color _categoryColor(String? category) =>
      AppDesign.categoryColor(category);

  List<Product> _recommendedProducts = [];
  bool _isAnalyzing = false;
  bool _hasAnalyzed = false;
  String? _analysisMode;
  double _semanticThreshold = 0.58;

  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _requirementController.addListener(_onManualTextChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
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

  int get _inputLength => _fullRequirement.length;

  // ── 语音输入 ──────────────────────────────────────

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
        initFn()
            .then((success) {
              result = success;
              if (ctx.mounted) Navigator.pop(ctx, success);
            })
            .catchError((e) {
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

  // ── 图片 OCR ──────────────────────────────────────

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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '选择图片来源',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: _circleIcon(
                    Icons.camera_alt_rounded,
                    const Color(0xFF43A047),
                  ),
                  title: const Text(
                    '拍照',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text('拍摄沟通记录或保单照片'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: _circleIcon(
                    Icons.photo_library_rounded,
                    const Color(0xFF1E88E5),
                  ),
                  title: const Text(
                    '从相册选择',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
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

      setState(() => _isRecognizingImage = true);

      final ocr = OcrService.instance;
      String? ocrTextResult;

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF43A047).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                color: Color(0xFF43A047),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text('识别结果', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已识别到 ${ocrText.length} 个字符，可编辑修正后填入需求框：',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: editController,
                maxLines: 6,
                minLines: 4,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF43A047),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('确认填入'),
          ),
        ],
      ),
    ).whenComplete(() {
      editController.dispose();
    });
  }

  // ── AI 分析 ───────────────────────────────────────

  Future<void> _analyzeProducts() async {
    final requirement = _fullRequirement;
    if (requirement.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入客户要求')));
      return;
    }
    final cleaned = requirement.replaceAll(RegExp(r'[，。、；：！？\s,.;:!?]'), '');
    if (cleaned.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的客户需求（至少2个字）')));
      return;
    }
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

    if (!semantic.isInitialized) {
      await _ensureModelLoaded(
        '语义分析模型',
        '正在初始化 BGE-small-zh 语义分析模型...',
        () => semantic.initialize(),
      );
    }

    if (semantic.isInitialized) {
      AppLogger.info('使用语义分析模式 (BGE-small-zh)');
      _analysisMode = 'semantic';
      final scored = <Product, double>{};

      for (final product in appState.products) {
        final productText = [
          product.name,
          product.category ?? '',
          product.description ?? '',
          product.sellingPoints ?? '',
        ].where((s) => s.isNotEmpty).join('，');

        if (productText.isEmpty) continue;

        final similarity = semantic.computeSimilarity(requirement, productText);
        if (similarity > _semanticThreshold) {
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
      _fadeController.forward(from: 0);
    } else {
      AppLogger.info('语义模型未就绪，降级为关键词匹配模式');
      _analysisMode = 'keyword';
      _fallbackKeywordMatch(appState, requirement);
    }
  }

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
      setState(() => _isAnalyzing = false);
      return;
    }

    setState(() {
      _recommendedProducts = recommended;
      _isAnalyzing = false;
    });
    _fadeController.forward(from: 0);
  }

  Widget _circleIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  @override
  void dispose() {
    _reanalysisTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    _speech.cancel();
    _audioRecorder.dispose();
    _requirementController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final hasAnyInput = _segments.isNotEmpty || _manualText.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('智能产品推荐'),
        toolbarHeight: 56,
        actions: [
          if (hasAnyInput)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '清空重填',
              onPressed: _clearAllInputs,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          children: [
            // 输入卡片
            _buildInputCard(isDark, primaryColor),
            const SizedBox(height: 24),

            // 结果区
            _buildResultsSection(isDark, primaryColor),
          ],
        ),
      ),
    );
  }

  // ── 输入区域卡片 ──────────────────────────────────

  Widget _buildInputCard(bool isDark, Color primaryColor) {
    final isActive = _isListening || _isRecordingForASR;

    return Container(
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                    size: 18,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '客户要求',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const Spacer(),
                if (_segments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_segments.length} 条识别',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFF9800),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // 输入框 + 按钮
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFE53935).withValues(alpha: 0.3)
                      : Colors.grey.shade200.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _requirementController,
                    maxLines: 4,
                    minLines: 2,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                    decoration: InputDecoration(
                      hintText:
                          '描述客户的保险需求，如：\n'
                          '· 有一个3岁的孩子，想给孩子买教育金\n'
                          '· 年收入30万，想配置重疾+医疗\n'
                          '· 刚买了房，需要房贷寿险保障...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                        height: 1.4,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  // 底部工具栏
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.shade200.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // 语音按钮
                        _buildVoiceButton(isActive),

                        // 字数统计
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$_inputLength 字',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: _inputLength > 500
                                    ? const Color(0xFFE53935)
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ),

                        // 拍照按钮
                        _buildOcrButton(),

                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 分析按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeProducts,
                icon: _isAnalyzing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 20),
                label: Text(
                  _isAnalyzing ? 'AI 正在分析...' : '开始智能推荐',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceButton(bool isActive) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.15);
        return Transform.scale(scale: isActive ? scale : 1.0, child: child);
      },
      child: GestureDetector(
        onTap: isActive ? _stopListening : _startListening,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? const Color(0xFFE53935).withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Icon(
            isActive ? Icons.stop_rounded : Icons.mic_none_rounded,
            size: 22,
            color: isActive ? const Color(0xFFE53935) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildOcrButton() {
    return GestureDetector(
      onTap: _isRecognizingImage ? null : _pickImage,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: _isRecognizingImage
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange,
                ),
              )
            : const Icon(
                Icons.document_scanner_outlined,
                size: 22,
                color: Color(0xFF43A047),
              ),
      ),
    );
  }

  // ── 推荐结果区域 ──────────────────────────────────

  Widget _buildResultsSection(bool isDark, Color primaryColor) {
    if (_recommendedProducts.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildThresholdSlider(isDark, primaryColor),
          const SizedBox(height: 14),
          _buildResultsHeader(primaryColor),
          const SizedBox(height: 14),
          FadeTransition(
            opacity: _fadeController,
            child: Column(
              children: List.generate(_recommendedProducts.length, (index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 350 + index * 80),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: _buildProductCard(
                    _recommendedProducts[index],
                    index,
                    isDark,
                  ),
                );
              }),
            ),
          ),
        ],
      );
    }

    // 空状态 / 分析中 / 无结果
    if (_isAnalyzing) {
      return _buildAnalyzingPlaceholder(isDark);
    }

    return _buildEmptyState(isDark);
  }

  Widget _buildThresholdSlider(bool isDark, Color primaryColor) {
    if (_analysisMode != 'semantic') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '匹配灵敏度',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary(context),
                      ),
                    ),
                    Text(
                      '${(_semanticThreshold * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: primaryColor,
                    inactiveTrackColor: primaryColor.withValues(alpha: 0.15),
                    thumbColor: primaryColor,
                    overlayColor: primaryColor.withValues(alpha: 0.1),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                  ),
                  child: Slider(
                    value: _semanticThreshold,
                    min: 0.30,
                    max: 0.85,
                    divisions: 55,
                    onChanged: (val) async {
                      setState(() => _semanticThreshold = val);
                      // 滑动后自动重新分析（防抖）
                      _reanalyzeDebounced();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _semanticThreshold < 0.45
                        ? '宽松 — 更多候选，可能包含低相关结果'
                        : _semanticThreshold > 0.70
                        ? '严格 — 仅高匹配度结果'
                        : '适中 — 推荐平衡精度与召回率',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Timer? _reanalysisTimer;
  void _reanalyzeDebounced() {
    _reanalysisTimer?.cancel();
    _reanalysisTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _fullRequirement.isNotEmpty && _hasAnalyzed) {
        _analyzeProducts();
      }
    });
  }

  Color _textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1A1A2E);

  Widget _buildResultsHeader(Color primaryColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.recommend_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '为您推荐 ${_recommendedProducts.length} 款产品',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const Spacer(),
        if (_analysisMode != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _analysisMode == 'semantic'
                  ? const Color(0xFF1E88E5).withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
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
                const SizedBox(width: 4),
                Text(
                  _analysisMode == 'semantic' ? 'AI 语义分析' : '关键词匹配',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _analysisMode == 'semantic'
                        ? const Color(0xFF1E88E5)
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAnalyzingPlaceholder(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'AI 正在分析您的需求...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '匹配产品特征、计算推荐指数',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasAnalyzed
                  ? Icons.search_off_rounded
                  : Icons.lightbulb_outline_rounded,
              size: 34,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _hasAnalyzed ? '未找到匹配的产品' : '开始您的智能推荐',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _hasAnalyzed
                ? '尝试更具体地描述客户需求，例如年龄、收入、家庭状况等'
                : '在上方输入框描述客户需求，点击「开始智能推荐」',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── 产品卡片 ──────────────────────────────────────

  Widget _buildProductCard(Product product, int rank, bool isDark) {
    final advantages =
        product.sellingPoints
            ?.split(';')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final color = _categoryColor(product.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppDesign.cardShadow(context)],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // 左侧排名色条
            Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: rank == 0
                      ? [const Color(0xFFFFB74D), const Color(0xFFFF9800)]
                      : rank == 1
                      ? [const Color(0xFF90CAF9), const Color(0xFF42A5F5)]
                      : [const Color(0xFFB0BEC5), const Color(0xFF90A4AE)],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 头部：排名 + 名称 + 分类
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 排名徽章
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: rank == 0
                                  ? const [Color(0xFFFFB74D), Color(0xFFFF9800)]
                                  : rank == 1
                                  ? const [Color(0xFF90CAF9), Color(0xFF42A5F5)]
                                  : [color.withValues(alpha: 0.6), color],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (rank == 0
                                            ? const Color(0xFFFF9800)
                                            : rank == 1
                                            ? const Color(0xFF42A5F5)
                                            : color)
                                        .withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${rank + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 产品信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    product.company,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  if (product.category != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        product.category!,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: color,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // 描述
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        product.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.45,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // 卖点标签
                    if (advantages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        children: advantages.take(4).map<Widget>((adv) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: color.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              adv.trim(),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // 底部分割线
                    const SizedBox(height: 14),
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.grey.shade200.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    // 操作提示
                    Center(
                      child: Text(
                        '查看详情了解完整产品信息',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
/// 动画构建辅助器（替代已废弃的 AnimatedBuilder）
/// Flutter 3.x 中 AnimatedBuilder 即 StatefulWidget 的 builder
/// 这里用 AnimatedBuilder 实现脉冲效果
// ═══════════════════════════════════════════════════════════

class AnimatedBuilder extends StatelessWidget {
  final Animation<dynamic> animation;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilderWidget(
      animation: animation,
      builder: builder,
      child: child,
    );
  }
}

class AnimatedBuilderWidget extends StatefulWidget {
  final Animation<dynamic> animation;
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilderWidget({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  State<AnimatedBuilderWidget> createState() => _AnimatedBuilderWidgetState();
}

class _AnimatedBuilderWidgetState extends State<AnimatedBuilderWidget> {
  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_onChange);
  }

  @override
  void didUpdateWidget(AnimatedBuilderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_onChange);
      widget.animation.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.child);
}

/// 识别片段来源
enum _InputSource { offlineASR, systemASR, ocr }

/// 识别片段
class _InputSegment {
  final String text;
  final _InputSource source;

  _InputSegment({required this.text, required this.source});
}
