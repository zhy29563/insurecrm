import 'package:insurance_manager/utils/app_logger.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/models/product.dart';
import 'package:insurance_manager/widgets/app_components.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:insurance_manager/pages/settings_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
  File? _selectedImage;

  // Use AppDesign.categoryColor instead of local map
  static Color _categoryColor(String? category) => AppDesign.categoryColor(category);
  List<Product> _recommendedProducts = [];
  bool _isAnalyzing = false;
  String _selectedAIProviderKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      // 默认选择第一个已启用的Chat AI（产品推荐只需chat类型引擎）
      final enabled = appState.enabledChatEngines;
      if (enabled.isNotEmpty) {
        setState(() {
          _selectedAIProviderKey = enabled.first['key']?.toString() ?? '';
        });
      }
    });
  }

  void _startListening() async {
    if (_isListening || _isRecordingForASR) return;

    // 先请求麦克风权限
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('需要麦克风权限才能使用语音输入'),
              action: SnackBarAction(
                label: '设置',
                onPressed: () => openAppSettings(),
              ),
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      }
    }

    // 检查是否有启用的自定义ASR引擎
    final appState = Provider.of<AppState>(context, listen: false);
    final asrEngines = appState.enabledASREngines;

    if (asrEngines.isNotEmpty) {
      // 使用自定义ASR引擎
      await _startRecordingForCustomASR(asrEngines);
    } else {
      // 使用系统级ASR
      await _startSystemASR();
    }
  }

  Future<void> _startSystemASR() async {
    // iOS 还需要语音识别权限
    if (!kIsWeb && Platform.isIOS) {
      var speechStatus = await Permission.speech.status;
      if (!speechStatus.isGranted) {
        speechStatus = await Permission.speech.request();
        if (!speechStatus.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('需要语音识别权限才能使用语音输入'),
              action: SnackBarAction(
                label: '设置',
                onPressed: () => openAppSettings(),
              ),
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      }
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        AppLogger.debug('speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (error) {
        AppLogger.error('speech error: ${error.errorMsg} (permanent: ${error.permanent})');
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
            SnackBar(content: Text(msg), duration: Duration(seconds: 3)),
          );
        }
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _requirementController.text = result.recognizedWords;
              _requirementController.selection = TextSelection.fromPosition(
                TextPosition(offset: _requirementController.text.length),
              );
            });
          }
        },
        localeId: 'zh_CN',
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('语音识别不可用，请检查设备是否支持'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _startRecordingForCustomASR(List<Map<String, dynamic>> asrEngines) async {
    try {
      if (kIsWeb) {
        // Web 平台不支持录音文件方式
        await _startSystemASR();
        return;
      }

      // 获取临时目录用于保存录音文件
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/asr_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _recordingPath!,
        );
        if (!mounted) return;
        setState(() => _isRecordingForASR = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('麦克风权限未授权'), duration: Duration(seconds: 3)),
          );
        }
      }
    } catch (e) {
      AppLogger.error('starting recording for ASR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音启动失败'), duration: Duration(seconds: 3)),
        );
      }
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
    if (!_isRecordingForASR || _recordingPath == null) return;

    try {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() => _isRecordingForASR = false);

      if (path == null || (kIsWeb ? false : !File(path).existsSync())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('录音文件不存在'), duration: Duration(seconds: 3)),
          );
        }
        return;
      }

      // 获取ASR引擎配置
      final appState = Provider.of<AppState>(context, listen: false);
      final asrEngines = appState.enabledASREngines;
      if (asrEngines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ASR引擎未配置'), duration: Duration(seconds: 3)),
          );
        }
        return;
      }

      final asrConfig = asrEngines.first;
      final apiKey = asrConfig['apiKey'] as String? ?? '';
      final baseUrl = asrConfig['baseUrl'] as String? ?? '';
      final model = asrConfig['model'] as String? ?? '';
      final asrName = asrConfig['name'] as String? ?? 'ASR';

      if (apiKey.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$asrName 的 API Key 未配置'), duration: Duration(seconds: 3)),
          );
        }
        return;
      }

      // 显示处理中提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('正在使用 $asrName 识别语音...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // 调用 ASR API（兼容 OpenAI Whisper API 格式）
      final transcript = await _callWhisperAPI(
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model,
        audioPath: path,
      );

      // 关闭处理中提示
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (transcript != null && transcript.isNotEmpty) {
        if (mounted) {
          setState(() {
            _requirementController.text = transcript;
            _requirementController.selection = TextSelection.fromPosition(
              TextPosition(offset: _requirementController.text.length),
            );
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('语音识别结果为空，请重试'), duration: Duration(seconds: 3)),
          );
        }
      }

      // 清理录音文件
      try {
        if (!kIsWeb) {
          final file = File(path);
          if (file.existsSync()) file.deleteSync();
        }
      } catch (_) {}
    } catch (e) {
      AppLogger.error('transcribing audio: $e');
      if (mounted) {
        setState(() => _isRecordingForASR = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音识别失败：$e'), duration: Duration(seconds: 3)),
        );
      }
    }
  }

  Future<String?> _callWhisperAPI({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String audioPath,
  }) async {
    try {
      // 构建 API URL：baseUrl/v1/audio/transcriptions
      String apiUrl = baseUrl;
      if (!apiUrl.endsWith('/')) apiUrl += '/';
      apiUrl += 'v1/audio/transcriptions';

      final file = File(audioPath);
      final fileBytes = await file.readAsBytes();
      final fileName = audioPath.split('/').last;

      // 构建 multipart request
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.fields['model'] = model.isNotEmpty ? model : 'whisper-1';
      request.fields['language'] = 'zh';
      request.fields['response_format'] = 'json';
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      final streamedResponse = await request.send().timeout(Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['text'] as String?;
      } else {
        AppLogger.error('ASR API error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      AppLogger.error('calling Whisper API: $e');
      return null;
    }
  }

  void _stopListening() {
    if (_isRecordingForASR) {
      _stopRecordingAndTranscribe();
      return;
    }
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('拍照识别功能在当前平台暂不可用')));
        return;
      }

      // 选择图片来源：拍照或相册
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '选择图片来源',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt_rounded, color: Color(0xFF43A047)),
                  title: Text('拍照'),
                  subtitle: Text('拍摄沟通记录'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_rounded, color: Color(0xFF1E88E5)),
                  title: Text('从相册选择'),
                  subtitle: Text('选择已有的记录照片'),
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

      final imageFile = File(image.path);
      setState(() {
        _selectedImage = imageFile;
        _isRecognizingImage = true;
      });

      // 使用 ML Kit OCR 识别文字
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
      final inputImage = InputImage.fromFilePath(image.path);

      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      String ocrText = recognizedText.text.trim();

      if (ocrText.isEmpty) {
        if (mounted) {
          setState(() => _isRecognizingImage = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('未识别到文字，请确保照片清晰且包含文字内容'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 弹窗确认识别结果，获取用户可能编辑后的文本
      if (!mounted) return;
      final result = await _showOCRResultDialog(ocrText);
      if (mounted) {
        setState(() => _isRecognizingImage = false);
        if (result != null && result.isNotEmpty) {
          setState(() {
            if (_requirementController.text.isNotEmpty) {
              _requirementController.text += '\n$result';
            } else {
              _requirementController.text = result;
            }
            _requirementController.selection = TextSelection.fromPosition(
              TextPosition(offset: _requirementController.text.length),
            );
          });
        }
      }
    } catch (e) {
      AppLogger.error('picking/recognizing image: $e');
      if (mounted) {
        setState(() => _isRecognizingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片识别失败，请重试'), duration: Duration(seconds: 3)),
        );
      }
    }
  }

  Future<String?> _showOCRResultDialog(String ocrText) {
    final editController = TextEditingController(text: ocrText);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.document_scanner_rounded, color: Color(0xFF43A047)),
            SizedBox(width: 8),
            Text('识别结果'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已识别到文字内容，可编辑修正后填入需求框：',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              SizedBox(height: 12),
              TextField(
                controller: editController,
                maxLines: 8,
                autofocus: false,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final edited = editController.text.trim();
              Navigator.pop(context, edited.isNotEmpty ? edited : null);
            },
            child: Text('确认填入'),
          ),
        ],
      ),
    ).whenComplete(() {
      editController.dispose();
    });
  }

  void _analyzeProducts() async {
    if (_requirementController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('请输入客户要求')));
      return;
    }

    if (_selectedAIProviderKey.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('请先选择AI引擎，或在设置中配置对话分析引擎')));
      return;
    }

    // Validate that the selected AI provider key still exists in enabled chat engines
    final appStateCheck = Provider.of<AppState>(context, listen: false);
    final enabledKeys = appStateCheck.enabledChatEngines.map((e) => e['key']?.toString() ?? '').where((k) => k.isNotEmpty).toList();
    if (!enabledKeys.contains(_selectedAIProviderKey)) {
      if (enabledKeys.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请先在设置中配置对话分析引擎')),
        );
        return;
      }
      setState(() => _selectedAIProviderKey = enabledKeys.first);
    }

    setState(() {
      _isAnalyzing = true;
    });

    await Future.delayed(Duration(seconds: 2));
    if (!context.mounted) return;

    final appState = Provider.of<AppState>(context, listen: false);
    List<Product> allProducts = appState.products;

    // Split requirement into keywords for better matching
    var keywords = _requirementController.text
        .toLowerCase()
        .split(RegExp(r'[,，、\s]+'))
        .where((k) => k.length >= 2) // Filter out single-char keywords to avoid overly broad matches
        .toList();
    // If no keywords >= 2 chars, fall back to all non-empty tokens
    if (keywords.isEmpty) {
      keywords = _requirementController.text
          .toLowerCase()
          .split(RegExp(r'[,，、\s]+'))
          .where((k) => k.isNotEmpty)
          .toList();
    }
    List<Product> recommended = [];

    for (var product in allProducts) {
      bool matches = false;

      final searchFields = [
        product.name.toLowerCase(),
        if (product.description != null) product.description!.toLowerCase(),
        if (product.category != null) product.category!.toLowerCase(),
        if (product.sellingPoints != null) ...product.sellingPoints!.split(';').map((a) => a.toLowerCase()),
      ];

      // Match if any keyword is found in any search field
      for (var keyword in keywords) {
        for (var field in searchFields) {
          if (field.contains(keyword)) {
            matches = true;
            break;
          }
        }
        if (matches) break;
      }

      if (matches) {
        recommended.add(product);
      }
    }

    if (recommended.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('未找到匹配的产品，请尝试其他关键词')));
      }
    }

    if (!context.mounted) return;
    setState(() {
      _recommendedProducts = recommended;
      _isAnalyzing = false;
    });
  }

  @override
  void dispose() {
    _speech.cancel(); // cancel() releases platform resources, stop() only stops listening
    _audioRecorder.dispose();
    _requirementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final enabledEngines = appState.enabledChatEngines;

    return Scaffold(
      appBar: AppBar(title: Text('产品推荐')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI引擎选择
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesign.cardBg(isDark),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.smart_toy_rounded,
                          size: 20,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'AI引擎',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      Spacer(),
                      if (enabledEngines.isEmpty)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => _SettingsAIRedirect(),
                              ),
                            );
                          },
                          icon: Icon(Icons.settings, size: 16),
                          label: Text('去配置'),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12),
                  if (enabledEngines.isEmpty)
                    EmptyStatePlaceholder(
                      icon: Icons.smart_toy_rounded,
                      message: '暂无已启用的对话引擎',
                      actionHint: '请先在设置中配置AI引擎',
                      iconSize: 48,
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButtonFormField<String>(
                        value: enabledEngines.any((e) => e['key'] == _selectedAIProviderKey)
                            ? _selectedAIProviderKey
                            : enabledEngines.first['key']?.toString(),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: Icon(Icons.memory_rounded,
                              color: primaryColor),
                        ),
                        items: enabledEngines.map<DropdownMenuItem<String>>((engine) {
                          final key = engine['key']?.toString() ?? '';
                          final name = engine['name']?.toString() ?? key;
                          final model = engine['model']?.toString() ?? '';
                          return DropdownMenuItem<String>(
                            value: key,
                            child: Row(
                              children: [
                                Icon(Icons.smart_toy_rounded,
                                    size: 18, color: primaryColor),
                                SizedBox(width: 8),
                                Text(name),
                                if (model.isNotEmpty) ...[
                                  SizedBox(width: 6),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      model,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedAIProviderKey = value;
                            });
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // 客户要求输入卡片
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppDesign.cardBg(isDark),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
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
                      SizedBox(width: 12),
                      Text(
                        '客户要求',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _requirementController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '请输入客户的保险需求，例如：健康保险、重疾保险、养老保险等',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  SizedBox(height: 14),
                  // 语音和拍照按钮
                  Row(
                    children: [
                      _buildToolButton(
                        icon: _isListening || _isRecordingForASR
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        label: _isRecordingForASR
                            ? '录音中(点击结束)...'
                            : _isListening
                                ? '识别中...'
                                : _getAsrLabel(appState),
                        color: _isListening || _isRecordingForASR
                            ? Color(0xFFE53935)
                            : Color(0xFF1E88E5),
                        onTap: _isListening || _isRecordingForASR ? _stopListening : _startListening,
                      ),
                      SizedBox(width: 12),
                      _buildToolButton(
                        icon: _isRecognizingImage
                            ? Icons.hourglass_top_rounded
                            : Icons.document_scanner_rounded,
                        label: _isRecognizingImage ? '识别中...' : '拍照识别',
                        color: Color(0xFF43A047),
                        onTap: _isRecognizingImage ? () {} : _pickImage,
                      ),
                    ],
                  ),
                  if (_selectedImage != null && _isRecognizingImage)
                    Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? SizedBox.shrink()
                                : Image.file(
                                    _selectedImage!,
                                    height: 60,
                                    width: 60,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '正在识别文字...',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isAnalyzing ? null : _analyzeProducts,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isAnalyzing
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('AI 分析中...'),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(_selectedAIProviderKey.isEmpty
                                    ? '分析并推荐产品'
                                    : '使用 ${_getSelectedAIName(appState)} 分析'),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 28),

            // 推荐产品
            if (_recommendedProducts.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFFFF9800).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.recommend_rounded,
                      size: 20,
                      color: Color(0xFFFF9800),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    '推荐产品 (${_recommendedProducts.length})',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                  ),
                  Spacer(),
                  if (_selectedAIProviderKey.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_toy_rounded,
                              size: 14, color: primaryColor),
                          SizedBox(width: 4),
                          Text(
                            _getSelectedAIName(appState),
                            style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16),
              ..._recommendedProducts.map<Widget>(
                (product) => _buildProductCard(product, isDark),
              ),
            ] else if (!_isAnalyzing) ...[
              const EmptyStatePlaceholder(
                icon: Icons.lightbulb_outline_rounded,
                message: '输入客户需求，AI 将为您推荐合适的产品',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getSelectedAIName(AppState appState) {
    if (_selectedAIProviderKey.isEmpty) return 'AI';
    final config = appState.aiProviderConfigs[_selectedAIProviderKey];
    if (config == null) return 'AI';
    return (config as Map<String, dynamic>)['name']?.toString() ?? _selectedAIProviderKey;
  }

  String _getAsrLabel(AppState appState) {
    final asrEngines = appState.enabledASREngines;
    if (asrEngines.isNotEmpty) {
      final name = asrEngines.first['name'] as String? ?? 'ASR';
      return '语音输入($name)';
    }
    return '语音输入(系统)';
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildProductCard(Product product, bool isDark) {
    List<String> advantages = product.sellingPoints?.split(';') ?? [];

    final color = _categoryColor(product.category);

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.shield_outlined, color: color, size: 22),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      product.company,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (product.category != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product.category!,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          if (product.description != null)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                product.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ),
          if (advantages.isNotEmpty) ...[
            SizedBox(height: 14),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '产品优势',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: advantages.map<Widget>((adv) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
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
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 一个中间页面，跳转到设置页面的AI配置区域
class _SettingsAIRedirect extends StatelessWidget {
  const _SettingsAIRedirect();

  @override
  Widget build(BuildContext context) {
    return SettingsPage();
  }
}
