import 'package:insurance_manager/widgets/app_components.dart';
import 'package:insurance_manager/utils/app_logger.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/models/customer.dart';
import 'package:insurance_manager/database/database_helper.dart';
import 'package:insurance_manager/models/product.dart';
import 'package:insurance_manager/models/visit.dart';
import 'package:insurance_manager/models/colleague.dart';
import 'package:insurance_manager/models/sale.dart';
import 'package:amap_flutter_map_plus/amap_flutter_map_plus.dart';
import 'package:amap_flutter_base_plus/amap_flutter_base_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:insurance_manager/pages/product_detail_page.dart';
import 'package:insurance_manager/pages/settings_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:insurance_manager/utils/image_utils.dart';

class RelationshipGraphPainter extends CustomPainter {
  final Customer centerCustomer;
  final List<Map<String, dynamic>> relationships;
  final Color scaffoldBgColor;

  RelationshipGraphPainter({
    required this.centerCustomer,
    required this.relationships,
    required this.scaffoldBgColor,
  });

  Color _relColor(String? type) => AppDesign.cnRelColor(type);

  Color _ratingColor(int? r) => AppDesign.ratingColor(r);

  @override
  void paint(Canvas canvas, Size size) {
    if (relationships.isEmpty) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final centerRadius = 36.0;
    final nodeRadius = 24.0;

    // 绘制背景装饰 - 中心光晕
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1565C0).withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: 120));
    canvas.drawCircle(Offset(centerX, centerY), 120, bgPaint);

    // 绘制连线（先画线，后画节点覆盖）
    for (int i = 0; i < relationships.length; i++) {
      final relationship = relationships[i];
      final angleStep = 2 * math.pi / relationships.length;
      final angle = i * angleStep - math.pi / 2;
      final radius = math.min(centerX, centerY) - nodeRadius - 16;
      final nodeX = centerX + radius * math.cos(angle);
      final nodeY = centerY + radius * math.sin(angle);

      final relColor = _relColor(relationship['relationship'] as String?);

      // 连线 - 渐变虚线
      final linePaint = Paint()
        ..color = relColor.withValues(alpha: 0.35)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(centerX, centerY), Offset(nodeX, nodeY), linePaint);

      // 关系标签 - 在连线中点
      final midX = (centerX + nodeX) / 2;
      final midY = (centerY + nodeY) / 2;
      final relLabel = relationship['relationship'] as String? ?? '';
      if (relLabel.isNotEmpty) {
        final labelTp = TextPainter(
          text: TextSpan(
            text: relLabel,
            style: TextStyle(
              color: relColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        // 标签背景
        final bgRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(midX, midY),
            width: labelTp.width + 8,
            height: labelTp.height + 4,
          ),
          const Radius.circular(4),
        );
        canvas.drawRRect(bgRect, Paint()..color = Colors.white);
        canvas.drawRRect(bgRect, Paint()
          ..color = relColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
        labelTp.paint(canvas, Offset(midX - labelTp.width / 2, midY - labelTp.height / 2));
      }
    }

    // 绘制中心节点
    // 外圈光晕
    final centerGlow = Paint()
      ..color = const Color(0xFF1565C0).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY), centerRadius + 6, centerGlow);

    // 中心圆
    final centerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
      ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: centerRadius));
    canvas.drawCircle(Offset(centerX, centerY), centerRadius, centerPaint);

    // 中心白色描边
    canvas.drawCircle(Offset(centerX, centerY), centerRadius, Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke);

    // 中心文字
    final centerName = centerCustomer.name;
    final centerDisplay = centerName.length > 3 ? '${centerName.substring(0, 2)}…' : centerName;
    final centerTp = TextPainter(
      text: TextSpan(
        text: centerDisplay,
        style: TextStyle(
          color: scaffoldBgColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: centerRadius * 2 - 8);
    centerTp.paint(canvas, Offset(
      centerX - centerTp.width / 2,
      centerY - centerTp.height / 2,
    ));

    // 绘制周围关系节点
    for (int i = 0; i < relationships.length; i++) {
      final relationship = relationships[i];
      final angleStep = 2 * math.pi / relationships.length;
      final angle = i * angleStep - math.pi / 2;
      final radius = math.min(centerX, centerY) - nodeRadius - 16;
      final nodeX = centerX + radius * math.cos(angle);
      final nodeY = centerY + radius * math.sin(angle);

      final relColor = _relColor(relationship['relationship'] as String?);
      final rating = (relationship['rating'] as num?)?.toInt();
      final nodeColor = rating != null && rating > 0 ? _ratingColor(rating) : relColor;

      // 节点阴影
      canvas.drawCircle(Offset(nodeX, nodeY + 2), nodeRadius, Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill);

      // 节点圆 - 渐变
      final nodePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [nodeColor, nodeColor.withValues(alpha: 0.8)],
        ).createShader(Rect.fromCircle(center: Offset(nodeX, nodeY), radius: nodeRadius));
      canvas.drawCircle(Offset(nodeX, nodeY), nodeRadius, nodePaint);

      // 节点白色描边
      canvas.drawCircle(Offset(nodeX, nodeY), nodeRadius, Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke);

      // 节点名称
      final name = relationship['name'] as String? ?? '';
      final displayName = name.length > 3 ? '${name.substring(0, 2)}…' : name;
      final tp = TextPainter(
        text: TextSpan(
          text: displayName,
          style: TextStyle(
            color: scaffoldBgColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: nodeRadius * 2 - 6);
      tp.paint(canvas, Offset(
        nodeX - tp.width / 2,
        nodeY - tp.height / 2,
      ));
    }
  }

  @override
  bool shouldRepaint(covariant RelationshipGraphPainter oldDelegate) {
    return oldDelegate.centerCustomer != centerCustomer ||
        oldDelegate.relationships != relationships;
  }
}

class CustomerDetailPage extends StatefulWidget {
  final Customer? customer;

  const CustomerDetailPage({super.key, this.customer});

  @override
  _CustomerDetailPageState createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  // Adaptive text color for dark mode
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get primaryColor => Theme.of(context).primaryColor;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aliasController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _wechatIdController = TextEditingController();
  final _idCardNumberController = TextEditingController();
  final _occupationController = TextEditingController();
  final _notesController = TextEditingController();
  String _gender = '男';
  int _rating = 3;
  String? _source;
  List<String> _phones = [];
  List<String> _addresses = [];
  List<String> _photos = [];
  AMapController? _mapViewController;
  double? _currentLat;
  double? _currentLng;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _nameController.text = widget.customer!.name;
      _aliasController.text = widget.customer!.alias ?? '';
      _ageController.text = widget.customer!.age?.toString() ?? '';
      _gender = widget.customer!.gender ?? '男';
      _rating = widget.customer!.rating ?? 3;
      _phones = List<String>.from(widget.customer!.phones);
      _addresses = List<String>.from(widget.customer!.addresses);
      _photos = List<String>.from(widget.customer!.photoList);
      _birthdayController.text = widget.customer!.birthday ?? '';
      _wechatIdController.text = widget.customer!.wechatId ?? '';
      _idCardNumberController.text = widget.customer!.idCardNumber ?? '';
      _occupationController.text = widget.customer!.occupation ?? '';
      _source = widget.customer!.source;
      _notesController.text = widget.customer!.notes ?? '';
      if (widget.customer!.latitude != null &&
          widget.customer!.longitude != null) {
        _currentLat = widget.customer!.latitude!;
        _currentLng = widget.customer!.longitude!;
      }
    } else {
      _isEditing = true;
    }
    // Only get current location for new customers (not when editing existing ones)
    if (widget.customer == null) {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    _wechatIdController.dispose();
    _idCardNumberController.dispose();
    _occupationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final result = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentLat = result.latitude;
        _currentLng = result.longitude;
      });
      _moveMapTo(result.latitude, result.longitude);
    } catch (e) {
      AppLogger.error('getting location: $e');
    }
  }

  void _moveMapTo(double lat, double lng) {
    _mapViewController?.moveCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
    );
  }

  // Current marker for detail map - cached to avoid creating new Set on every build
  Set<Marker>? _cachedDetailMapMarkers;
  bool? _cachedDetailMapIsEditing;
  double? _cachedDetailMapLat;
  double? _cachedDetailMapLng;

  Set<Marker> get _detailMapMarkers {
    if (_cachedDetailMapIsEditing == _isEditing &&
        _cachedDetailMapLat == _currentLat &&
        _cachedDetailMapLng == _currentLng &&
        _cachedDetailMapMarkers != null) {
      return _cachedDetailMapMarkers!;
    }
    if (_currentLat == null || _currentLng == null) {
      _cachedDetailMapMarkers = {};
      _cachedDetailMapIsEditing = _isEditing;
      _cachedDetailMapLat = _currentLat;
      _cachedDetailMapLng = _currentLng;
      return _cachedDetailMapMarkers!;
    }
    _cachedDetailMapIsEditing = _isEditing;
    _cachedDetailMapLat = _currentLat;
    _cachedDetailMapLng = _currentLng;
    _cachedDetailMapMarkers = {
      Marker(
        position: LatLng(_currentLat!, _currentLng!),
        draggable: _isEditing,
        infoWindow: const InfoWindow(title: '客户位置'),
        onDragEnd: (id, position) {
          if (_isEditing) {
            setState(() {
              _currentLat = position.latitude;
              _currentLng = position.longitude;
              _cachedDetailMapMarkers = null; // invalidate cache
            });
          }
        },
      ),
    };
    return _cachedDetailMapMarkers!;
  }

  void _saveCustomer() async {
    if (_formKey.currentState?.validate() ?? false) {
      final appState = Provider.of<AppState>(context, listen: false);

      final customer = Customer(
        id: widget.customer?.id,
        name: _nameController.text,
        alias: _aliasController.text.isEmpty ? null : _aliasController.text,
        age: int.tryParse(_ageController.text),
        gender: _gender,
        rating: _rating,
        latitude: _currentLat,
        longitude: _currentLng,
        phones: _phones,
        addresses: _addresses,
        photos: _photos.isNotEmpty ? _photos.join('|') : null,
        persistentPhotoList: _photos,
        birthday: _birthdayController.text.isEmpty ? null : _birthdayController.text,
        createdAt:
            widget.customer?.createdAt ?? DateTime.now().toIso8601String(),
        wechatId: _wechatIdController.text.isEmpty ? null : _wechatIdController.text,
        idCardNumber: _idCardNumberController.text.isEmpty ? null : _idCardNumberController.text,
        occupation: _occupationController.text.isEmpty ? null : _occupationController.text,
        source: _source,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        purchaseIntentionLevel: _rating,
        tags: widget.customer?.tags,
        persistentTagList: widget.customer?.persistentTagList ?? [],
        visits: widget.customer?.visits ?? [],
        products: widget.customer?.products ?? [],
        relationships: widget.customer?.relationships ?? [],
      );

      try {
        if (widget.customer == null) {
          await appState.addCustomer(customer);
        } else {
          await appState.updateCustomer(customer);
        }
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  void _addPhone() {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && !_phones.contains(phone)) {
      setState(() {
        _phones.add(phone);
        _phoneController.clear();
      });
    }
  }

  void _removePhone(int index) {
    setState(() {
      _phones.removeAt(index);
    });
  }

  void _addAddress() {
    final address = _addressController.text.trim();
    if (address.isNotEmpty && !_addresses.contains(address)) {
      setState(() {
        _addresses.add(address);
        _addressController.clear();
      });
    }
  }

  void _removeAddress(int index) {
    setState(() {
      _addresses.removeAt(index);
    });
  }

  Future<void> _scanIdCard() async {
    try {
      if (kIsWeb ||
          (!kIsWeb &&
              (Platform.isLinux || Platform.isWindows || Platform.isMacOS))) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('身份证扫描功能在当前平台暂不可用')));
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('身份证扫描功能在当前平台暂不可用')));
      return;
    }

    try {
      // 选择图片来源
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('扫描身份证', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: primaryColor),
                  title: Text('拍照识别'),
                  subtitle: Text('使用相机拍摄身份证'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: Color(0xFF43A047)),
                  title: Text('从相册选择'),
                  subtitle: Text('选择已有的身份证照片'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );

      if (source == null) return;
      if (!mounted) return;

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );
      if (picked == null) return;
      if (!mounted) return;

      // 显示识别中提示
      if (!context.mounted) return;
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 3),
                SizedBox(width: 16),
                Expanded(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('正在识别...', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('请稍候', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                )),
              ],
            ),
          ),
        ),
      );

      // 使用 ML Kit 识别文字
      final inputImage = InputImage.fromFilePath(picked.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
      final recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      // 关闭加载对话框
      if (context.mounted) Navigator.pop(context);

      // 解析识别结果
      final fullText = recognizedText.text;
      if (fullText.trim().isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未识别到文字，请重新拍摄清晰的身份证照片')),
        );
        return;
      }

      // 提取身份证信息
      String? name;
      String? idNumber;
      String? gender;
      String? address;

      // 提取姓名 - 身份证上"姓名"关键字后面
      final nameMatch = RegExp(r'姓\s*名\s*([^\x00-\xff]{1,4})').firstMatch(fullText);
      if (nameMatch != null) {
        name = nameMatch.group(1)?.trim();
      }

      // 提取身份证号 - 18位数字（最后一位可能是X）
      final idMatch = RegExp(r'\d{17}[\dXx]').firstMatch(fullText);
      if (idMatch != null) {
        idNumber = idMatch.group(0)?.toUpperCase();
      }

      // 提取性别
      final genderMatch = RegExp(r'性\s*别\s*([男女])').firstMatch(fullText);
      if (genderMatch != null) {
        gender = genderMatch.group(1);
      }

      // 提取地址 - "住址"后面的内容
      final addrMatch = RegExp(r'住\s*址\s*([\s\S]*?)(?:\d{17}[\dXx]|公民身份号码|$)').firstMatch(fullText);
      if (addrMatch != null) {
        address = addrMatch.group(1)?.trim();
        // 去除换行
        address = address?.replaceAll(RegExp(r'\s+'), '');
      }

      // 从身份证号提取出生日期和性别（备用方案）
      if (idNumber != null && idNumber.length == 18) {
        // 出生日期
        final birthYear = idNumber.substring(6, 10);
        final birthMonth = idNumber.substring(10, 12);
        final birthDay = idNumber.substring(12, 14);
        final birthDate = '$birthYear-$birthMonth-$birthDay';

        // 性别（第17位奇数=男，偶数=女）
        if (gender == null) {
          final genderDigit = int.tryParse(idNumber[16]) ?? 0;
          gender = genderDigit % 2 == 1 ? '男' : '女';
        }

        // 计算年龄
        final birthDateTime = DateTime.tryParse(birthDate);
        if (birthDateTime != null) {
          final now = DateTime.now();
          int age = now.year - birthDateTime.year;
          if (now.month < birthDateTime.month ||
              (now.month == birthDateTime.month && now.day < birthDateTime.day)) {
            age--;
          }
          if (_ageController.text.isEmpty) {
            _ageController.text = age.toString();
          }
        }

        if (_birthdayController.text.isEmpty) {
          _birthdayController.text = birthDate;
        }
      }

      // 弹出确认对话框
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('识别结果'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name != null) _buildScanResultRow('姓名', name),
              if (gender != null) _buildScanResultRow('性别', gender),
              if (idNumber != null) _buildScanResultRow('证件号', idNumber),
              if (address != null) _buildScanResultRow('地址', address),
              if (_birthdayController.text.isNotEmpty) _buildScanResultRow('生日', _birthdayController.text),
              SizedBox(height: 12),
              Text('确认将以上信息填入客户资料？', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: Text('确认填入'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        if (!mounted) return;
        setState(() {
          if (name != null && _nameController.text.isEmpty) {
            _nameController.text = name;
          }
          if (gender != null) {
            _gender = gender;
          }
          if (idNumber != null) {
            _idCardNumberController.text = idNumber;
          }
          if (address != null && address.isNotEmpty && !_addresses.any((a) => a == address)) {
            _addresses.add(address);
          }
        });
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('身份证信息已填入')),
        );
      }
    } catch (e) {
      AppLogger.error('scanning ID card: $e');
      if (!context.mounted) return;
      // 关闭可能残留的加载对话框（仅当对话框仍然显示时）
      try {
        if (ModalRoute.of(context)?.isCurrent == false) {
          Navigator.pop(context);
        }
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('身份证扫描失败: $e')));
    }
  }

  Widget _buildScanResultRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb ||
          (!kIsWeb &&
              (Platform.isLinux || Platform.isWindows || Platform.isMacOS))) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('照片选择功能在当前平台暂不可用')));
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('照片选择功能在当前平台暂不可用')));
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (!context.mounted) return;

      if (image != null) {
        final String savedPath = await _saveImage(File(image.path));
        if (!context.mounted) return;
        setState(() {
          _photos.add(savedPath);
        });

        await _extractInfoFromImage(savedPath);
        if (!context.mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('照片添加成功')));
      }
    } catch (e) {
      AppLogger.error('picking image: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('照片添加失败，请重试')));
    }
  }

  Future<String> _saveImage(File image) async {
    try {
      final String savedPath = await ImageUtils.compressAndSave(
        image,
        subDir: 'customer_photos',
      );
      return savedPath;
    } catch (e) {
      AppLogger.error('saving image: $e');
      rethrow;
    }
  }

  Future<void> _extractInfoFromImage(String imagePath) async {
    try {
      AppLogger.debug('info from image: $imagePath');
    } catch (e) {
      AppLogger.error('extracting info from image: $e');
    }
  }

  void _removePhoto(int index) {
    if (index < 0 || index >= _photos.length) return;
    final photoToDelete = _photos[index];
    setState(() {
      _photos.removeAt(index);
    });
    ImageUtils.deleteFiles([photoToDelete]);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('无法拨打电话')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('拨打电话失败: $e')));
    }
  }

  Future<void> _sendSms(String phoneNumber) async {
    try {
      // 使用 sms:phoneNumber 格式，避免 Uri 构造器生成不标准的 sms://phoneNumber
      final Uri smsUri = Uri.parse('sms:$phoneNumber');
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('无法发送短信')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('发送短信失败: $e')));
    }
  }

  Future<void> _openWechat() async {
    try {
      // 直接打开微信
      final Uri wechatUri = Uri.parse('weixin://');
      if (await canLaunchUrl(wechatUri)) {
        await launchUrl(wechatUri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('未安装微信或无法打开')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('打开微信失败: $e')));
    }
  }

  Widget _buildMapWidget() {
    try {
      if (kIsWeb ||
          (!kIsWeb &&
              (Platform.isLinux || Platform.isWindows || Platform.isMacOS))) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, color: Colors.grey[400], size: 40),
                SizedBox(height: 8),
                Text('地图功能在当前平台暂不可用',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        );
      }
      final appState = Provider.of<AppState>(context, listen: false);
      if (!appState.hasAmapApiKey) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.vpn_key_rounded, color: Colors.orange[400], size: 40),
                SizedBox(height: 8),
                Text('高德地图 API Key 未配置',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                SizedBox(height: 4),
                Text('请在设置中配置 API Key',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      }

      // Use AMapWidget (native map)
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 200,
          child: AMapWidget(
            apiKey: AMapApiKey(
              androidKey: appState.amapApiKey,
              iosKey: appState.amapApiKeyIOS.isNotEmpty ? appState.amapApiKeyIOS : appState.amapApiKey,
            ),
            privacyStatement: const AMapPrivacyStatement(
              hasContains: true,
              hasShow: true,
              hasAgree: true,
            ),
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentLat ?? 39.9042, _currentLng ?? 116.4074),
              zoom: 15,
            ),
            markers: _detailMapMarkers,
            myLocationStyleOptions: MyLocationStyleOptions(false),
            scaleEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            onTap: (latLng) {
              if (_isEditing) {
                setState(() {
                  _currentLat = latLng.latitude;
                  _currentLng = latLng.longitude;
                });
              }
            },
            onMapCreated: (controller) {
              if (mounted) _mapViewController = controller;
            },
          ),
        ),
      );
    } catch (e) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, color: Colors.grey[400], size: 40),
              SizedBox(height: 8),
              Text('地图功能在当前平台暂不可用',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }
  }

  void _addVisit() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final dateController = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0],
    );
    final locationController = TextEditingController();
    final accompanyingPersonsController = TextEditingController();
    final introducedProductsController = TextEditingController();
    final interestedProductsController = TextEditingController();
    final competitorsController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加拜访记录'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateController,
                decoration: InputDecoration(
                  labelText: '日期',
                  prefixIcon: Icon(Icons.calendar_today, size: 20),
                ),
                readOnly: true,
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null && mounted) {
                    dateController.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  }
                },
              ),
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: '地点',
                  prefixIcon: Icon(Icons.location_on, size: 20),
                ),
              ),
              TextField(
                controller: accompanyingPersonsController,
                decoration: InputDecoration(
                  labelText: '随行人员',
                  prefixIcon: Icon(Icons.people, size: 20),
                ),
              ),
              TextField(
                controller: introducedProductsController,
                decoration: InputDecoration(
                  labelText: '介绍的产品',
                  prefixIcon: Icon(Icons.inventory, size: 20),
                ),
              ),
              TextField(
                controller: interestedProductsController,
                decoration: InputDecoration(
                  labelText: '客户意向产品',
                  prefixIcon: Icon(Icons.favorite, size: 20),
                ),
              ),
              TextField(
                controller: competitorsController,
                decoration: InputDecoration(
                  labelText: '同行竞争产品',
                  prefixIcon: Icon(Icons.compare, size: 20),
                ),
              ),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: '备注',
                  prefixIcon: Icon(Icons.note, size: 20),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (widget.customer?.id == null) return;
              final visit = Visit(
                customerId: widget.customer!.id!,
                visitDate: dateController.text,
                location: locationController.text,
                accompanyingPersons: accompanyingPersonsController.text,
                productsPresented: introducedProductsController.text,
                interestedProducts: interestedProductsController.text,
                competitors: competitorsController.text,
                notes: notesController.text,
              );
              await appState.addVisit(visit);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (!mounted) return;
              // No setState needed - Provider will auto-rebuild when data changes
              ScaffoldMessenger.of(this.context)
                  .showSnackBar(SnackBar(content: Text('拜访记录已添加')));
            },
            child: Text('添加'),
          ),
        ],
      ),
    ).whenComplete(() {
      dateController.dispose();
      locationController.dispose();
      accompanyingPersonsController.dispose();
      introducedProductsController.dispose();
      interestedProductsController.dispose();
      competitorsController.dispose();
      notesController.dispose();
    });
  }

  void _addSale() async {
    if (widget.customer?.id == null) return;
    final appState = Provider.of<AppState>(context, listen: false);
    final dateController = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0],
    );
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    Product? selectedProduct;
    Colleague? selectedColleague;
    final commissionController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('添加销售记录'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: '日期',
                    prefixIcon: Icon(Icons.calendar_today, size: 20),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null && mounted) {
                      dateController.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }
                  },
                ),
                SizedBox(height: 10),
                Text('选择产品:', style: TextStyle(fontSize: 14)),
                SizedBox(height: 5),
                DropdownButton<Product>(
                  hint: Text('请选择产品'),
                  value: selectedProduct,
                  isExpanded: true,
                  onChanged: (Product? value) {
                    setDialogState(() {
                      selectedProduct = value;
                    });
                  },
                  items: appState.products.map<DropdownMenuItem<Product>>((Product product) {
                    return DropdownMenuItem<Product>(
                      value: product,
                      child: Text(product.name),
                    );
                  }).toList(),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: '金额',
                    hintText: '请输入销售金额',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: '备注',
                    hintText: '请输入备注信息（可多行）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  minLines: 3,
                ),
                SizedBox(height: 10),
                Text('选择合作同事:', style: TextStyle(fontSize: 14)),
                SizedBox(height: 5),
                DropdownButton<Colleague>(
                  hint: Text('请选择同事（可选）'),
                  value: selectedColleague,
                  isExpanded: true,
                  onChanged: (Colleague? value) {
                    setDialogState(() {
                      selectedColleague = value;
                    });
                  },
                  items: appState.colleagues.map<DropdownMenuItem<Colleague>>((Colleague colleague) {
                    return DropdownMenuItem<Colleague>(
                      value: colleague,
                      child: Text(colleague.name),
                    );
                  }).toList(),
                ),
                if (selectedColleague != null)
                  TextField(
                    controller: commissionController,
                    decoration: InputDecoration(labelText: '分成比例 (%)'),
                    keyboardType: TextInputType.number,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedProduct == null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('请选择产品')));
                  return;
                }

                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('请输入有效的销售金额')));
                  return;
                }
                if (selectedColleague != null) {
                  final commissionRate = double.tryParse(commissionController.text);
                  if (commissionController.text.isNotEmpty && commissionRate == null) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('请输入有效的分成比例')));
                    return;
                  }
                  if (commissionRate != null && (commissionRate < 0 || commissionRate > 100)) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('分成比例应在0-100之间')));
                    return;
                  }
                }
                final sale = Sale(
                  customerId: widget.customer!.id!,
                  productId: selectedProduct!.id!,
                  amount: amount,
                  notes: notesController.text,
                  saleDate: dateController.text,
                  colleagueId: selectedColleague?.id,
                  commissionRate: selectedColleague != null
                      ? double.tryParse(commissionController.text)
                      : null,
                );
                await appState.addSale(sale);
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!mounted) return;
                // No setState needed - Provider will auto-rebuild when data changes
                ScaffoldMessenger.of(this.context)
                    .showSnackBar(SnackBar(content: Text('销售记录已添加')));
              },
              child: Text('添加'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      dateController.dispose();
      amountController.dispose();
      notesController.dispose();
      commissionController.dispose();
    });
  }

  void _addCustomerRelationship() async {
    if (widget.customer?.id == null) return;
    final appState = Provider.of<AppState>(context, listen: false);
    Customer? selectedCustomer;
    String relationshipType = appState.relationshipLabels.isNotEmpty ? appState.relationshipLabels.first : '其他';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('添加客户关系'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('选择客户:', style: TextStyle(fontSize: 14)),
                SizedBox(height: 5),
                DropdownButton<Customer>(
                  hint: Text('请选择客户'),
                  value: selectedCustomer,
                  isExpanded: true,
                  onChanged: (Customer? value) {
                    setDialogState(() {
                      selectedCustomer = value;
                    });
                  },
                  items: appState.customers
                      .where((customer) => customer.id != widget.customer!.id)
                      .map<DropdownMenuItem<Customer>>((Customer customer) {
                    return DropdownMenuItem<Customer>(
                      value: customer,
                      child: Text(customer.name),
                    );
                  }).toList(),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Text('关系类型:', style: TextStyle(fontSize: 14)),
                    Spacer(),
                    InkWell(
                      onTap: () async {
                        Navigator.pop(context); // 先关闭当前对话框
                        await Navigator.push(
                          this.context,
                          MaterialPageRoute(
                            builder: (_) => SettingsPage(),
                          ),
                        );
                        // 返回后重新打开添加关系对话框（此时标签已更新）
                        if (mounted) {
                          _addCustomerRelationship();
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.settings_outlined, size: 14, color: primaryColor),                          SizedBox(width: 2),
                          Text('管理标签', style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 5),
                DropdownButton<String>(
                  value: appState.relationshipLabels.contains(relationshipType) ? relationshipType : null,
                  hint: Text('选择关系类型'),
                  isExpanded: true,
                  onChanged: (String? value) {
                    setDialogState(() {
                      relationshipType = value ?? relationshipType;
                    });
                  },
                  items: appState.relationshipLabels.map<DropdownMenuItem<String>>((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedCustomer == null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('请选择客户')));
                  return;
                }

                await appState.addCustomerRelationship(
                  widget.customer!.id!,
                  selectedCustomer!.id!,
                  relationshipType,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!mounted) return;
                // No setState needed - Provider will auto-rebuild when data changes
                ScaffoldMessenger.of(this.context)
                    .showSnackBar(SnackBar(content: Text('客户关系已添加')));
              },
              child: Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Product>> _getCustomerProducts(AppState appState) async {
    if (widget.customer?.id == null) return [];
    if (kIsWeb) {
      final updatedCustomer = appState.customers.firstWhere(
        (c) => c.id == widget.customer!.id,
        orElse: () => widget.customer!,
      );
      final customerProductMaps = updatedCustomer.products;
      final productIds = customerProductMaps
          .map<int?>((p) => (p['id'] as num?)?.toInt())
          .where((id) => id != null)
          .toSet();
      // Build index for O(1) lookup instead of O(N) linear scan per product
      final productById = <int, Product>{};
      for (final p in appState.products) {
        if (p.id != null) productById[p.id!] = p;
      }
      return productIds.map<Product?>((id) => productById[id]).whereType<Product>().toList();
    } else {
      final db = DatabaseHelper.instance;
      final customerProductMaps = await db.getCustomerProducts(
        widget.customer!.id!,
      );
      return customerProductMaps.map<Product>((map) => Product.fromMap(map)).toList();
    }
  }

  // ============ iOS Contacts 风格 UI 组件 ============

  /// 顶部头像区域 - iOS Contacts 风格
  Widget _buildHeader() {
    final String initial = _nameController.text.isNotEmpty
        ? _nameController.text.substring(0, 1)
        : '?';
    final bool hasPhoto = _photos.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: 24, bottom: 20),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // 头像
          GestureDetector(
            onTap: _isEditing ? _pickImage : null,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.1),
                  ),
                  child: hasPhoto
                      ? ClipOval(
                          child: kIsWeb
                              ? _buildAvatarInitial(initial)
                              : Image.file(
                                  File(_photos[0]),
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                  errorBuilder: (_, _, _) => _buildAvatarInitial(initial),
                                ),
                        )
                      : _buildAvatarInitial(initial),
                ),
                if (_isEditing)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 10),
          // 姓名
          _isEditing
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: 60),
                  child: TextFormField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                      hintText: '输入姓名',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入姓名';
                      }
                      return null;
                    },
                  ),
                )
              : Text(
                  _nameController.text.isEmpty ? '未命名' : _nameController.text,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
          // 别名
          if (_aliasController.text.isNotEmpty || _isEditing)
            _isEditing
                ? Padding(
                    padding: EdgeInsets.only(left: 60, right: 60, top: 4),
                    child: TextFormField(
                      controller: _aliasController,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 2),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: primaryColor),
                        ),
                        hintText: '别名/公司',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      _aliasController.text,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                    ),
                  ),
          // 评级
          if (!_isEditing && widget.customer != null)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('意向: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ...List.generate(5, (index) {
                    return Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: index < _rating ? Colors.amber : Colors.grey.shade300,
                      size: 16,
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarInitial(String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: primaryColor,
          fontSize: 32,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// iOS Contacts 风格的分组卡片
  Widget _buildGroupedSection({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 20, top: 24, bottom: 6),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
              Spacer(),
              if (trailing != null) ...[
                trailing,
                SizedBox(width: 16),
              ],
            ],
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  /// iOS Contacts 风格的表单行 - 左侧标签 + 右侧输入
  Widget _buildFieldRow({
    required String label,
    required Widget child,
    bool showDivider = true,
    IconData? icon,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null)
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(icon, size: 20, color: Colors.grey.shade400),
                ),
              SizedBox(
                width: 56,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(left: icon != null ? 48 : 84),
            child: Divider(height: 1, color: Colors.grey.shade200, thickness: 0.5),
          ),
      ],
    );
  }

  /// iOS 风格的只读文本显示行（避免创建未 dispose 的 TextEditingController）
  Widget _buildDisplayRow({
    required String label,
    required String displayText,
    bool showDivider = true,
    IconData? icon,
  }) {
    return _buildFieldRow(
      label: label,
      icon: icon,
      showDivider: showDivider,
      child: Text(
        displayText,
        style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
      ),
    );
  }

  /// iOS 风格的文本输入行
  Widget _buildTextFieldRow({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool showDivider = true,
    IconData? icon,
    String? Function(String?)? validator,
  }) {
    return _buildFieldRow(
      label: label,
      icon: icon,
      showDivider: showDivider,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 15,
          color: enabled ? _textPrimary : Colors.grey.shade500,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: hintText ?? '',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        ),
        validator: validator,
      ),
    );
  }

  /// iOS 风格的选择行（性别等）
  Widget _buildPickerRow({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    bool showDivider = true,
    IconData? icon,
  }) {
    return _buildFieldRow(
      label: label,
      icon: icon,
      showDivider: showDivider,
      child: DropdownButton<String>(
        value: options.contains(value) ? value : options.first,
        underline: SizedBox(),
        isDense: true,
        isExpanded: true,
        icon: Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
        style: TextStyle(fontSize: 15, color: _textPrimary),
        onChanged: onChanged,
        items: options.map<DropdownMenuItem<String>>((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }).toList(),
      ),
    );
  }

  /// 手机号列表行 - iOS Contacts 风格
  Widget _buildPhoneRow(int index, String phone, {bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.phone_android, size: 20, color: Colors.green.shade600),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  _phones.length > 1 ? '手机 ${index + 1}' : '手机',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
              ),
              Expanded(
                child: _isEditing
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(phone, style: TextStyle(fontSize: 15, color: _textPrimary)),
                          ),
                          GestureDetector(
                            onTap: () => _removePhone(index),
                            child: Icon(Icons.remove_circle_outline, size: 20, color: Colors.red.shade300),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(phone, style: TextStyle(fontSize: 15, color: primaryColor)),
                          ),
                          GestureDetector(
                            onTap: () => _makePhoneCall(phone),
                            child: Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.phone, size: 18, color: Colors.green.shade600),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _sendSms(phone),
                            child: Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Icon(Icons.message, size: 18, color: Colors.blue.shade600),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(left: 48),
            child: Divider(height: 1, color: Colors.grey.shade200, thickness: 0.5),
          ),
      ],
    );
  }

  /// 地址列表行
  Widget _buildAddressRow(int index, String address, {bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(right: 12, top: 2),
                child: Icon(Icons.location_on, size: 20, color: Colors.red.shade400),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  _addresses.length > 1 ? '地址 ${index + 1}' : '地址',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
              ),
              Expanded(
                child: _isEditing
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(address, style: TextStyle(fontSize: 15, color: _textPrimary)),
                          ),
                          GestureDetector(
                            onTap: () => _removeAddress(index),
                            child: Icon(Icons.remove_circle_outline, size: 20, color: Colors.red.shade300),
                          ),
                        ],
                      )
                    : Text(address, style: TextStyle(fontSize: 15, color: _textPrimary)),
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(left: 48),
            child: Divider(height: 1, color: Colors.grey.shade200, thickness: 0.5),
          ),
      ],
    );
  }

  /// 添加新手机号行 - iOS Contacts 风格
  Widget _buildAddPhoneRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.add_circle_outline, size: 20, color: primaryColor),
          ),
          SizedBox(
            width: 56,
            child: Text('手机', style: TextStyle(fontSize: 15, color: primaryColor)),
          ),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '输入手机号',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
              ),
              onFieldSubmitted: (_) => _addPhone(),
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
            onTap: _addPhone,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('添加', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            ),
          ),
        ],
      ),
    );
  }

  /// 添加新地址行
  Widget _buildAddAddressRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.add_circle_outline, size: 20, color: primaryColor),
          ),
          SizedBox(
            width: 56,
            child: Text('地址', style: TextStyle(fontSize: 15, color: primaryColor)),
          ),
          Expanded(
            child: TextFormField(
              controller: _addressController,
              style: TextStyle(fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '输入地址',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
              ),
              onFieldSubmitted: (_) => _addAddress(),
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
            onTap: _addAddress,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('添加', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            ),
          ),
        ],
      ),
    );
  }

  /// 快速操作按钮行 - 拨号/短信/微信
  Widget _buildQuickActions() {
    final primaryPhone = _phones.isNotEmpty ? _phones[0] : null;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionButton(
            icon: Icons.phone,
            label: '电话',
            color: Colors.green,
            onPressed: primaryPhone != null ? () => _makePhoneCall(primaryPhone) : null,
          ),
          _buildQuickActionButton(
            icon: Icons.message,
            label: '短信',
            color: Colors.blue,
            onPressed: primaryPhone != null ? () => _sendSms(primaryPhone) : null,
          ),
          _buildQuickActionButton(
            icon: Icons.chat,
            label: '微信',
            color: Color(0xFF07C160),
            onPressed: () => _openWechat(),
          ),
          _buildQuickActionButton(
            icon: _isEditing ? Icons.check : Icons.edit,
            label: _isEditing ? '保存' : '编辑',
            color: primaryColor,
            onPressed: () {
              if (_isEditing) {
                _saveCustomer();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final bool enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: enabled ? color : Colors.grey.shade400, size: 22),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: enabled ? color : Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 联系信息区块
  Widget _buildContactSection() {
    final List<Widget> rows = [];

    // 手机号列表
    for (int i = 0; i < _phones.length; i++) {
      rows.add(_buildPhoneRow(i, _phones[i], showDivider: i < _phones.length - 1 || _addresses.isNotEmpty || _isEditing));
    }
    // 地址列表
    for (int i = 0; i < _addresses.length; i++) {
      rows.add(_buildAddressRow(i, _addresses[i], showDivider: i < _addresses.length - 1 || _isEditing));
    }
    // 添加手机号/地址（编辑模式）
    if (_isEditing) {
      if (rows.isNotEmpty) {
        // Add divider before add rows if there are existing entries
      }
      rows.add(_buildAddPhoneRow());
      rows.add(Padding(
        padding: EdgeInsets.only(left: 48),
        child: Divider(height: 1, color: Colors.grey.shade200, thickness: 0.5),
      ));
      rows.add(_buildAddAddressRow());
    }

    if (rows.isEmpty && !_isEditing) {
      rows.add(Padding(
        padding: EdgeInsets.all(16),
        child: EmptyStatePlaceholder(icon: Icons.contact_phone_rounded, message: '暂无联系信息', iconSize: 48),
      ));
    }

    return _buildGroupedSection(title: '联系信息', children: rows);
  }

  /// 基本信息区块
  Widget _buildBasicInfoSection() {
    final List<Widget> rows = [];

    // 别名/公司
    if (_isEditing || _aliasController.text.isNotEmpty) {
      rows.add(_buildTextFieldRow(
        label: '别名',
        controller: _aliasController,
        enabled: _isEditing,
        hintText: '别名/公司',
        icon: Icons.badge,
        showDivider: true,
      ));
    }

    // 性别
    rows.add(_buildPickerRow(
      label: '性别',
      value: _gender,
      options: ['男', '女'],
      onChanged: _isEditing ? (v) { if (v != null) setState(() => _gender = v); } : (_) {},
      icon: _gender == '男' ? Icons.male : Icons.female,
      showDivider: true,
    ));

    // 年龄
    if (_isEditing) {
      rows.add(_buildFieldRow(
        label: '年龄',
        icon: Icons.cake,
        showDivider: true,
        child: DropdownButtonFormField<String>(
          value: (_ageController.text.isNotEmpty &&
                  int.tryParse(_ageController.text) != null &&
                  int.parse(_ageController.text) >= 1 &&
                  int.parse(_ageController.text) <= 80)
              ? _ageController.text
              : null,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: '选择',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),
          isDense: true,
          items: List.generate(80, (index) {
            final age = index + 1;
            return DropdownMenuItem(value: age.toString(), child: Text(age.toString()));
          }),
          onChanged: (value) {
            setState(() => _ageController.text = value ?? '');
          },
        ),
      ));
    } else if (_ageController.text.isNotEmpty) {
      rows.add(_buildDisplayRow(
        label: '年龄',
        displayText: '${_ageController.text} 岁',
        icon: Icons.cake,
        showDivider: _birthdayController.text.isNotEmpty,
      ));
    }

    // 生日
    if (_isEditing) {
      rows.add(_buildFieldRow(
        label: '生日',
        icon: Icons.card_giftcard,
        showDivider: false,
        child: InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1930),
              lastDate: DateTime.now(),
            );
            if (picked != null && mounted) {
              setState(() {
                _birthdayController.text =
                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              });
            }
          },
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _birthdayController.text.isEmpty ? '选择生日' : _birthdayController.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: _birthdayController.text.isEmpty ? Colors.grey.shade400 : _textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ));
    } else if (_birthdayController.text.isNotEmpty) {
      rows.add(_buildDisplayRow(
        label: '生日',
        displayText: _birthdayController.text,
        icon: Icons.card_giftcard,
        showDivider: false,
      ));
    }

    return _buildGroupedSection(title: '基本信息', children: rows);
  }

  /// 更多信息区块（微信/身份证/职业/来源）
  Widget _buildMoreInfoSection() {
    final List<Widget> rows = [];

    // 微信
    rows.add(_buildTextFieldRow(
      label: '微信',
      controller: _wechatIdController,
      enabled: _isEditing,
      hintText: '微信号',
      icon: Icons.chat_bubble,
      showDivider: true,
    ));

    // 职业
    rows.add(_buildTextFieldRow(
      label: '职业',
      controller: _occupationController,
      enabled: _isEditing,
      hintText: '职业',
      icon: Icons.work,
      showDivider: true,
    ));

    // 客户来源
    if (_isEditing) {
      rows.add(_buildFieldRow(
        label: '来源',
        icon: Icons.source,
        showDivider: true,
        child: DropdownButton<String>(
          value: _source != null && ['线上推广', '线下活动', '转介绍', '主动咨询', '其他'].contains(_source) ? _source : null,
          underline: SizedBox(),
          isDense: true,
          isExpanded: true,
          icon: Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
          hint: Text('选择来源', style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          style: TextStyle(fontSize: 15, color: _textPrimary),
          onChanged: (v) { if (v != null) setState(() => _source = v); },
          items: ['线上推广', '线下活动', '转介绍', '主动咨询', '其他'].map<DropdownMenuItem<String>>((s) {
            return DropdownMenuItem(value: s, child: Text(s));
          }).toList(),
        ),
      ));
    } else if (_source != null) {
      rows.add(_buildDisplayRow(
        label: '来源',
        displayText: _source!,
        icon: Icons.source,
        showDivider: true,
      ));
    }

    // 身份证
    rows.add(_buildTextFieldRow(
      label: '证件',
      controller: _idCardNumberController,
      enabled: _isEditing,
      hintText: '身份证号',
      icon: Icons.credit_card,
      showDivider: false,
    ));

    return _buildGroupedSection(title: '更多信息', children: rows);
  }

  /// 购买意向评级区块（编辑模式）
  Widget _buildRatingSection() {
    if (!_isEditing && widget.customer == null) return SizedBox.shrink();

    return _buildGroupedSection(
      title: '购买意向',
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.star, size: 20, color: Colors.amber),
              ),
              SizedBox(
                width: 56,
                child: Text('意向', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
              ),
              Expanded(
                child: _isEditing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: List.generate(5, (index) {
                          final ratingVal = index + 1;
                          return GestureDetector(
                            onTap: () => setState(() => _rating = ratingVal),
                            child: Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                ratingVal <= _rating ? Icons.star : Icons.star_border,
                                color: ratingVal <= _rating ? Colors.amber : Colors.grey.shade300,
                                size: 28,
                              ),
                            ),
                          );
                        }),
                      )
                    : Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: index < _rating ? Colors.amber : Colors.grey.shade300,
                              size: 20,
                            );
                          }),
                          SizedBox(width: 8),
                          Text(
                            _rating >= 1 && _rating <= 5
                                ? ['低意向', '中低意向', '中等意向', '中高意向', '高意向'][_rating - 1]
                                : (_rating == 0 ? '无意向' : ''),
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 备注区块
  Widget _buildRemarkSection() {
    return _buildGroupedSection(
      title: '备注',
      children: [
        _buildTextFieldRow(
          label: '备注',
          controller: _notesController,
          enabled: _isEditing,
          hintText: '添加备注...',
          icon: Icons.note,
          maxLines: 3,
          showDivider: false,
        ),
      ],
    );
  }

  /// 位置信息区块
  Widget _buildLocationSection() {
    return _buildGroupedSection(
      title: '位置信息',
      children: [
        Padding(
          padding: EdgeInsets.all(12),
          child: _buildMapWidget(),
        ),
        if (_isEditing)
          Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _getCurrentLocation,
                icon: Icon(Icons.my_location, size: 18),
                label: Text('获取当前位置'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                  padding: EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 照片区块
  Widget _buildPhotosSection() {
    return _buildGroupedSection(
      title: '照片',
      children: [
        _photos.isEmpty
            ? Padding(
                padding: EdgeInsets.all(16),
                child: _isEditing
                    ? GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, color: Colors.grey.shade400, size: 24),
                              SizedBox(height: 2),
                              Text('添加', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                            ],
                          ),
                        ),
                      )
                    : Text('暂无照片', style: TextStyle(color: AppDesign.subtitleColor(Theme.of(context).brightness == Brightness.dark), fontSize: 14)),
              )
            : Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length + (_isEditing ? 1 : 0),
                    separatorBuilder: (context, index) => SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (_isEditing && index == _photos.length) {
                        return GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: Colors.grey.shade400, size: 24),
                                SizedBox(height: 2),
                                Text('添加', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                              ],
                            ),
                          ),
                        );
                      }
                      final photo = _photos[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: kIsWeb
                                ? Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey.shade200,
                                    child: Icon(Icons.image_not_supported, color: Colors.grey),
                                  )
                                : Image.file(
                                    File(photo),
                                    fit: BoxFit.cover,
                                    width: 80,
                                    height: 80,
                                    errorBuilder: (_, _, _) => Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.broken_image, color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                          if (_isEditing)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () => _removePhoto(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
      ],
    );
  }

  /// 身份证扫描区块（编辑模式）
  Widget _buildScanSection() {
    if (!_isEditing) return SizedBox.shrink();

    return _buildGroupedSection(
      title: '快捷操作',
      children: [
        InkWell(
          onTap: _scanIdCard,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.document_scanner, size: 20, color: Colors.teal),
                ),
                SizedBox(
                  width: 56,
                  child: Text('证件', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                ),
                Expanded(
                  child: Text('扫描身份证', style: TextStyle(fontSize: 15, color: primaryColor)),
                ),
                Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 已购产品区块
  Widget _buildProductsSection(AppState appState) {
    return _buildGroupedSection(
      title: '已购产品',
      children: [
        FutureBuilder<List<Product>>(
          future: _customerProductsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )),
              );
            } else if (snapshot.hasError) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: Text('获取产品信息失败', style: TextStyle(color: Colors.grey)),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: EmptyStatePlaceholder(icon: Icons.inventory_2_rounded, message: '暂无已购产品', iconSize: 48),
              );
            } else {
              return Column(
                children: snapshot.data!.asMap().entries.map<Widget>((entry) {
                  final index = entry.key;
                  final product = entry.value;
                  final isLast = index == snapshot.data!.length - 1;
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailPage(product: product),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(Icons.inventory_2, size: 20, color: Colors.teal),
                              ),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  product.category ?? '产品',
                                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                                ),
                              ),
                              Expanded(
                                child: Text(product.name, style: TextStyle(fontSize: 15, color: _textPrimary)),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Padding(
                            padding: EdgeInsets.only(left: 48),
                            child: Divider(height: 1, color: Colors.grey.shade200, thickness: 0.5),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            }
          },
        ),
      ],
    );
  }

  /// 客户关系区块
  Widget _buildRelationshipsSection() {
    return _buildGroupedSection(
      title: '客户关系',
      trailing: AddSectionButton(onTap: _addCustomerRelationship),
      children: [
        Builder(
          builder: (context) {
            final appState = Provider.of<AppState>(context);
            final updatedCustomer = appState.customers.firstWhere(
              (c) => c.id == widget.customer!.id,
              orElse: () => widget.customer!,
            );
            final relationships = updatedCustomer.relationships;
            // Build index for O(1) customer lookup
            final customerById = <int, Customer>{};
            for (final c in appState.customers) {
              if (c.id != null) customerById[c.id!] = c;
            }
            if (relationships.isEmpty) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: EmptyStatePlaceholder(icon: Icons.diversity_3_rounded, message: '暂无客户关系', iconSize: 48),
              );
            }
            return Column(
              children: [
                // 关系思维导图
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: SizedBox(
                    height: relationships.length <= 3 ? 180 : 240,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) {
                            final pos = details.localPosition;
                            final centerX = constraints.maxWidth / 2;
                            final centerY = constraints.maxHeight / 2;
                            final nodeRadius = 24.0;
                            final r = math.min(centerX, centerY) - nodeRadius - 16;
                            for (int i = 0; i < relationships.length; i++) {
                              final angleStep = 2 * math.pi / relationships.length;
                              final angle = i * angleStep - math.pi / 2;
                              final nodeX = centerX + r * math.cos(angle);
                              final nodeY = centerY + r * math.sin(angle);
                              final dx = pos.dx - nodeX;
                              final dy = pos.dy - nodeY;
                              if (dx * dx + dy * dy <= (nodeRadius + 4) * (nodeRadius + 4)) {
                                final relatedId = (relationships[i]['related_customer_id'] as num?)?.toInt() ?? (relationships[i]['id'] as num?)?.toInt();
                                if (relatedId != null) {
                                  final relatedCustomer = customerById[relatedId];
                                  if (relatedCustomer != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CustomerDetailPage(customer: relatedCustomer),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('该客户已被删除')),
                                    );
                                  }
                                }
                                return;
                              }
                            }
                          },
                          child: CustomPaint(
                            painter: RelationshipGraphPainter(
                              centerCustomer: updatedCustomer,
                              relationships: relationships,
                              scaffoldBgColor: Theme.of(context).scaffoldBackgroundColor,
                            ),
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // 关系列表
                ...relationships.asMap().entries.map<Widget>((entry) {
                  final index = entry.key;
                  final rel = entry.value;
                  final isLast = index == relationships.length - 1;
                  return Dismissible(
                    key: ValueKey('rel_${rel['id'] ?? rel.hashCode}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20),
                      margin: EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('确认删除'),
                          content: Text('确定要删除这条客户关系吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('删除', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) async {
                      final appState = Provider.of<AppState>(context, listen: false);
                      if (rel['id'] != null) {
                        await appState.deleteCustomerRelationship((rel['id'] as num?)?.toInt() ?? -1);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('客户关系已删除')));
                      }
                    },
                    child: InkWell(
                      onTap: () {
                        // Use related_customer_id if available (DB mode returns customer fields via JOIN),
                        // otherwise fall back to 'id' which in Web in-memory mode stores the related customer id too
                        // because DB mode: SELECT c.* gives customer id; Web mode: we now store related_customer_id
                        final relatedCustomerId = (rel['related_customer_id'] as num?)?.toInt() ?? (rel['id'] as num?)?.toInt();
                        if (relatedCustomerId != null) {
                          final relatedCustomer = customerById[relatedCustomerId];
                          if (relatedCustomer != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CustomerDetailPage(customer: relatedCustomer),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('该客户已被删除')),
                            );
                          }
                        }
                      },
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: Icon(Icons.person_outline, size: 20, color: Colors.blue),
                                ),
                                SizedBox(
                                  width: 56,
                                  child: Text(
                                    rel['relationship'] ?? '',
                                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                                  ),
                                ),
                                Expanded(
                                  child: Text(rel['name'] ?? '', style: TextStyle(fontSize: 15, color: _textPrimary)),
                                ),
                                Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Padding(
                              padding: EdgeInsets.only(left: 48),
                              child: Divider(height: 1, color: Colors.grey.shade200, thickness: 0.5),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  /// 拜访记录区块
  Widget _buildVisitsSection() {
    final appState = Provider.of<AppState>(context);
    final updatedCustomer = appState.customers.firstWhere(
      (c) => c.id == widget.customer!.id,
      orElse: () => widget.customer!,
    );
    final visits = updatedCustomer.visits;
    return _buildGroupedSection(
      title: '拜访记录',
      trailing: AddSectionButton(onTap: _addVisit),
      children: [
        visits.isEmpty
            ? Padding(
                padding: EdgeInsets.all(16),
                child: EmptyStatePlaceholder(icon: Icons.directions_walk_rounded, message: '暂无拜访记录', iconSize: 48),
              )
            : Column(
                children: visits.asMap().entries.map<Widget>((entry) {
                  final index = entry.key;
                  final visit = entry.value;
                  return Dismissible(
                    key: ValueKey('visit_${visit['id']}_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20),
                      margin: EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('确认删除'),
                          content: Text('确定要删除这条拜访记录吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('删除', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) async {
                      final appState = Provider.of<AppState>(context, listen: false);
                      if (visit['id'] != null) {
                        await appState.deleteVisit((visit['id'] as num?)?.toInt() ?? -1);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('拜访记录已删除')));
                      }
                    },
                    child: _buildVisitItem(visit, index),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildVisitItem(Map<String, dynamic> visit, int index) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event, size: 16, color: primaryColor),
              SizedBox(width: 6),
              Text(
                visit['date'] ?? '',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: primaryColor),
              ),
              if (visit['location'] != null && visit['location'].toString().isNotEmpty) ...[
                SizedBox(width: 12),
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    visit['location'],
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (visit['introduced_products'] != null && visit['introduced_products'].toString().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4, left: 22),
              child: Text('介绍: ${visit['introduced_products']}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            ),
          if (visit['interested_products'] != null && visit['interested_products'].toString().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2, left: 22),
              child: Text('意向: ${visit['interested_products']}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            ),
          if (visit['notes'] != null && visit['notes'].toString().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2, left: 22),
              child: Text('备注: ${visit['notes']}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ),
        ],
      ),
    );
  }

  /// 销售记录区块
  Widget _buildSalesSection() {
    return _buildGroupedSection(
      title: '销售记录',
      trailing: AddSectionButton(onTap: _addSale),
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _customerSalesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )),
              );
            } else if (snapshot.hasError) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: Text('加载销售记录失败', style: TextStyle(color: Colors.grey)),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: EmptyStatePlaceholder(icon: Icons.receipt_long_rounded, message: '暂无销售记录', iconSize: 48),
              );
            } else {
              return Column(
                children: snapshot.data!.asMap().entries.map<Widget>((entry) {
                  final index = entry.key;
                  final sale = entry.value;
                  return Dismissible(
                    key: ValueKey('sale_${sale['id']}_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20),
                      margin: EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('确认删除'),
                          content: Text('确定要删除这条销售记录吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('删除', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) async {
                      final appState = Provider.of<AppState>(context, listen: false);
                      if (sale['id'] != null) {
                        await appState.deleteSale((sale['id'] as num?)?.toInt() ?? -1);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('销售记录已删除')));
                      }
                    },
                    child: _buildSaleItem(sale, index, snapshot.data!.length),
                  );
                }).toList(),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildSaleItem(Map<String, dynamic> sale, int index, int total) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sell, size: 16, color: Colors.green.shade700),
              SizedBox(width: 6),
              Text(
                sale['sale_date'] ?? '',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.green.shade700),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 4, left: 22),
            child: Text('产品: ${sale['product_name'] ?? ''}',
                style: TextStyle(fontSize: 14, color: Colors.black87)),
          ),
          if (sale['notes'] != null && sale['notes'].toString().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2, left: 22),
              child: Text('备注: ${sale['notes']}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ),
          if (sale['colleague_name'] != null)
            Padding(
              padding: EdgeInsets.only(top: 2, left: 22),
              child: Text('合作: ${sale['colleague_name']}${sale['commission_rate'] != null ? ' (${sale['commission_rate']}%)' : ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ),
        ],
      ),
    );
  }

  late AppState appState;
  Future<List<Product>>? _customerProductsFuture;
  Future<List<Map<String, dynamic>>>? _customerSalesFuture;
  int? _lastCustomerId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appState = Provider.of<AppState>(context);
    // Only recreate futures when the customer ID changes, not on every rebuild
    final currentId = widget.customer?.id;
    if (currentId != _lastCustomerId) {
      _lastCustomerId = currentId;
      _customerProductsFuture = _getCustomerProducts(appState);
      if (currentId != null) {
        _customerSalesFuture = appState.getCustomerSales(currentId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.customer != null;

    return Scaffold(
      backgroundColor: Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(isEditMode ? (_isEditing ? '编辑客户' : '客户详情') : '添加客户'),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          if (isEditMode && !_isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('确认删除'),
                    content: Text('确定要删除这个客户吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('取消'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await appState.deleteCustomer(widget.customer!.id!);
                          } catch (e) {
                            AppLogger.error('删除客户失败: $e');
                          }
                          if (!context.mounted) return;
                          Navigator.pop(context); // close dialog
                          if (!mounted) return;
                          Navigator.of(this.context).pop(); // pop page
                        },
                        child: Text('删除', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (!isEditMode && _isEditing)
            TextButton(
              onPressed: _saveCustomer,
              child: Text('保存', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 顶部头像+姓名区域
              _buildHeader(),
              SizedBox(height: 4),
              // 快速操作按钮
              _buildQuickActions(),
              // 联系信息
              _buildContactSection(),
              // 基本信息
              _buildBasicInfoSection(),
              // 更多信息
              _buildMoreInfoSection(),
              // 购买意向
              _buildRatingSection(),
              // 身份证扫描
              _buildScanSection(),
              // 备注
              _buildRemarkSection(),
              // 位置信息
              _buildLocationSection(),
              // 照片
              _buildPhotosSection(),
              // 以下仅编辑模式/已有客户时显示
              if (isEditMode) ...[
                // 已购产品
                _buildProductsSection(appState),
                // 客户关系
                _buildRelationshipsSection(),
                // 拜访记录
                _buildVisitsSection(),
                // 销售记录
                _buildSalesSection(),
              ],
              // 底部保存按钮（编辑模式）
              if (_isEditing)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saveCustomer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isEditMode ? '保存修改' : '添加客户',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_isEditing) SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
