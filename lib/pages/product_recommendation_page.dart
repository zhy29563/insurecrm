import 'package:insurecrm/utils/app_logger.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';
import 'package:insurecrm/models/product.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';

class ProductRecommendationPage extends StatefulWidget {
  const ProductRecommendationPage({Key? key}) : super(key: key);

  @override
  _ProductRecommendationPageState createState() =>
      _ProductRecommendationPageState();
}

class _ProductRecommendationPageState extends State<ProductRecommendationPage> {
  final TextEditingController _requirementController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  List<CameraDescription>? _cameras;
  CameraController? _cameraController;
  File? _image;
  List<Product> _recommendedProducts = [];
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      if (!kIsWeb &&
          (Platform.isLinux || Platform.isWindows || Platform.isMacOS))
        return;
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
        );
        await _cameraController?.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      AppLogger.error('initializing camera: $e');
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => AppLogger.debug('onStatus: $status'),
        onError: (error) => AppLogger.error('onError: $error'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) => setState(() {
            _requirementController.text = result.recognizedWords;
          }),
        );
      }
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('拍照功能在当前平台暂不可用')));
        return;
      }
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _image = File(image.path);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('照片已添加')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法获取照片')));
    }
  }

  void _analyzeProducts() async {
    if (_requirementController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('请输入客户要求')));
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    await Future.delayed(Duration(seconds: 2));

    final appState = Provider.of<AppState>(context, listen: false);
    List<Product> allProducts = appState.products;

    String requirement = _requirementController.text.toLowerCase();
    List<Product> recommended = [];

    for (var product in allProducts) {
      bool matches = false;

      if (product.name.toLowerCase().contains(requirement) ||
          (product.description != null &&
              product.description!.toLowerCase().contains(requirement)) ||
          (product.category != null &&
              product.category!.toLowerCase().contains(requirement))) {
        matches = true;
      }

      if (!matches && product.advantages != null) {
        List<String> advantages = product.advantages!.split(';');
        for (var advantage in advantages) {
          if (advantage.toLowerCase().contains(requirement)) {
            matches = true;
            break;
          }
        }
      }

      if (matches) {
        recommended.add(product);
      }
    }

    if (recommended.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('未找到匹配的产品，请尝试其他关键词')));
    }

    setState(() {
      _recommendedProducts = recommended;
      _isAnalyzing = false;
    });
  }

  @override
  void dispose() {
    _requirementController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: Text('产品推荐')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 客户要求输入卡片
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Color(0xFF2C2C2C) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
                          color: primaryColor.withOpacity(0.1),
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
                        icon: _isListening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        label: _isListening ? '录音中...' : '语音输入',
                        color: _isListening
                            ? Color(0xFFE53935)
                            : Color(0xFF1E88E5),
                        onTap: _isListening ? _stopListening : _startListening,
                      ),
                      SizedBox(width: 12),
                      _buildToolButton(
                        icon: Icons.camera_alt_rounded,
                        label: '拍照记录',
                        color: Color(0xFF43A047),
                        onTap: _pickImage,
                      ),
                    ],
                  ),
                  if (_image != null)
                    Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _image!,
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
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
                                Text('分析并推荐产品'),
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
                      color: Color(0xFFFF9800).withOpacity(0.1),
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
                ],
              ),
              SizedBox(height: 16),
              ..._recommendedProducts.map(
                (product) => _buildProductCard(product, isDark),
              ),
            ] else if (!_isAnalyzing) ...[
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '输入客户需求，AI 将为您推荐合适的产品',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
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
    );
  }

  Widget _buildProductCard(Product product, bool isDark) {
    List<String> advantages = product.advantages?.split(';') ?? [];

    final categoryColors = {
      '寿险': Color(0xFFE53935),
      '健康险': Color(0xFF43A047),
      '意外险': Color(0xFFFF9800),
      '年金险': Color(0xFFAB47BC),
      '重疾险': Color(0xFF1E88E5),
    };

    final color = categoryColors[product.category] ?? Color(0xFF1565C0);

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                  color: color.withOpacity(0.1),
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
                    color: color.withOpacity(0.1),
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
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
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
                    children: advantages.map((adv) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
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
