import 'package:insurecrm/utils/app_logger.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';
import 'package:insurecrm/models/customer.dart';
import 'package:insurecrm/database/database_helper.dart';
import 'package:insurecrm/models/product.dart';
import 'package:insurecrm/models/visit.dart';
import 'package:insurecrm/models/colleague.dart';
import 'package:insurecrm/models/sale.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:insurecrm/pages/product_detail_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:insurecrm/utils/image_utils.dart';

class RelationshipGraphPainter extends CustomPainter {
  final Customer centerCustomer;
  final List<Map<String, dynamic>> relationships;

  RelationshipGraphPainter({
    required this.centerCustomer,
    required this.relationships,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final centerRadius = 40.0;
    final nodeRadius = 30.0;
    final lineWidth = 2.0;

    // 绘制中心节点
    final centerPaint = Paint()
      ..color = Colors.blue.shade700
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY), centerRadius, centerPaint);

    // 绘制中心节点文本
    final centerTextPainter = TextPainter(
      text: TextSpan(
        text: centerCustomer.name,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: size.width);
    centerTextPainter.paint(
      canvas,
      Offset(
        centerX - centerTextPainter.width / 2,
        centerY - centerTextPainter.height / 2,
      ),
    );

    // 绘制关系节点和连线
    final nodePaint = Paint()
      ..color = Colors.green.shade600
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth;

    if (relationships.isNotEmpty) {
      final angleStep = 2 * math.pi / relationships.length;
      for (int i = 0; i < relationships.length; i++) {
        final relationship = relationships[i];
        final angle = i * angleStep;
        final nodeX = centerX + 120 * math.cos(angle);
        final nodeY = centerY + 120 * math.sin(angle);

        // 绘制连线
        canvas.drawLine(
          Offset(centerX, centerY),
          Offset(nodeX, nodeY),
          linePaint,
        );

        // 绘制关系节点
        canvas.drawCircle(Offset(nodeX, nodeY), nodeRadius, nodePaint);

        // 绘制关系节点文本
        final nodeTextPainter = TextPainter(
          text: TextSpan(
            text: relationship['name'],
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(minWidth: 0, maxWidth: size.width);
        nodeTextPainter.paint(
          canvas,
          Offset(
            nodeX - nodeTextPainter.width / 2,
            nodeY - nodeTextPainter.height / 2,
          ),
        );

        // 绘制关系类型
        final relationshipTextPainter = TextPainter(
          text: TextSpan(
            text: relationship['relationship'],
            style: TextStyle(color: Colors.black, fontSize: 10),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(minWidth: 0, maxWidth: size.width);
        relationshipTextPainter.paint(
          canvas,
          Offset(
            (centerX + nodeX) / 2 - relationshipTextPainter.width / 2,
            (centerY + nodeY) / 2 - relationshipTextPainter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class CustomerDetailPage extends StatefulWidget {
  final Customer? customer;

  CustomerDetailPage({this.customer});

  @override
  _CustomerDetailPageState createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aliasController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String _gender = '男';
  int _rating = 3;
  List<String> _phones = [];
  List<String> _addresses = [];
  List<String> _photos = [];
  GoogleMapController? _mapController;
  LatLng _currentPosition = LatLng(39.9042, 116.4074); // Default to Beijing
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
      _phones = widget.customer!.phones;
      _addresses = widget.customer!.addresses;
      _photos = List.from(widget.customer!.photoList); // 加载已保存的照片路径
      if (widget.customer!.latitude != null &&
          widget.customer!.longitude != null) {
        _currentPosition = LatLng(
          widget.customer!.latitude!,
          widget.customer!.longitude!,
        );
      }
    }
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
      });
    } catch (e) {
      AppLogger.error('getting location: $e');
    }
  }

  void _saveCustomer() {
    if (_formKey.currentState!.validate()) {
      final appState = Provider.of<AppState>(context, listen: false);

      final customer = Customer(
        id: widget.customer?.id,
        name: _nameController.text,
        alias: _aliasController.text.isEmpty ? null : _aliasController.text,
        age: int.tryParse(_ageController.text),
        gender: _gender,
        rating: _rating,
        latitude: _currentPosition.latitude,
        longitude: _currentPosition.longitude,
        phones: _phones,
        addresses: _addresses,
        photos: _photos.isNotEmpty ? _photos.join('|') : null, // 持久化照片路径
        createdAt:
            widget.customer?.createdAt ?? DateTime.now().toIso8601String(),
      );

      if (widget.customer == null) {
        appState.addCustomer(customer);
      } else {
        appState.updateCustomer(customer);
      }

      Navigator.pop(context);
    }
  }

  void _addPhone() {
    if (_phoneController.text.isNotEmpty) {
      setState(() {
        _phones.add(_phoneController.text);
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
    if (_addressController.text.isNotEmpty) {
      setState(() {
        _addresses.add(_addressController.text);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('身份证扫描功能在当前平台暂不可用')));
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('身份证扫描功能在当前平台暂不可用')));
      return;
    }

    try {
      // 模拟身份证扫描功能
      // 在实际应用中，这里应该使用 image_picker 和 google_mlkit_text_recognition 插件
      setState(() {
        _nameController.text = '张三';
        _ageController.text = '30';
        _gender = '男';
        _addresses.add('北京市朝阳区某某街道某某小区');
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('身份证扫描成功')));
    } catch (e) {
      AppLogger.error('scanning ID card: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('身份证扫描失败，请重试')));
    }
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb ||
          (!kIsWeb &&
              (Platform.isLinux || Platform.isWindows || Platform.isMacOS))) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('照片选择功能在当前平台暂不可用')));
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('照片选择功能在当前平台暂不可用')));
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image != null) {
        // 保存照片
        final String savedPath = await _saveImage(File(image.path));
        setState(() {
          _photos.add(savedPath);
        });

        // 从照片中提取信息
        await _extractInfoFromImage(savedPath);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('照片添加成功')));
      }
    } catch (e) {
      AppLogger.error('picking image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('照片添加失败，请重试')));
    }
  }

  Future<String> _saveImage(File image) async {
    try {
      // 使用 ImageUtils 压缩并保存
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
      // 模拟从照片中提取信息
      // 在实际应用中，这里应该使用 OCR 技术来提取信息
      // 例如使用 google_mlkit_text_recognition 插件
      AppLogger.debug('info from image: $imagePath');

      // 这里可以添加实际的 OCR 代码
      // 例如：
      // final inputImage = InputImage.fromFile(File(imagePath));
      // final textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
      // final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      // 然后从 recognizedText 中提取信息

      // 模拟提取结果
      // 这里可以根据实际的 OCR 结果来更新表单
    } catch (e) {
      AppLogger.error('extracting info from image: $e');
    }
  }

  void _removePhoto(int index) {
    // 删除物理文件
    ImageUtils.deleteFiles([_photos[index]]);
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法拨打电话')));
    }
  }

  Future<void> _sendSms(String phoneNumber) async {
    final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法发送短信')));
    }
  }

  Future<void> _openMessagingApp(String phoneNumber) async {
    // 尝试打开常见的通讯软件
    final List<String> messagingApps = [
      'whatsapp://send?phone=$phoneNumber',
      'weixin://', // 微信
      'mqq://', // QQ
    ];

    bool launched = false;
    for (final appUrl in messagingApps) {
      final Uri appUri = Uri.parse(appUrl);
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri);
        launched = true;
        break;
      }
    }

    if (!launched) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开通讯软件')));
    }
  }

  Widget _buildMapWidget() {
    try {
      if (kIsWeb ||
          (!kIsWeb &&
              (Platform.isLinux || Platform.isWindows || Platform.isMacOS))) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, color: Colors.grey[400], size: 48),
                SizedBox(height: 12),
                Text('地图功能在当前平台暂不可用'),
              ],
            ),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
          },
          initialCameraPosition: CameraPosition(
            target: _currentPosition,
            zoom: 15,
          ),
          markers: {
            Marker(markerId: MarkerId('current'), position: _currentPosition),
          },
          onTap: (position) {
            setState(() {
              _currentPosition = position;
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(_currentPosition),
              );
            });
          },
        ),
      );
    } catch (e) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, color: Colors.grey[400], size: 48),
              SizedBox(height: 12),
              Text('地图功能在当前平台暂不可用'),
            ],
          ),
        ),
      );
    }
  }

  void _addVisit() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final _dateController = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0],
    );
    final _locationController = TextEditingController();
    final _accompanyingController = TextEditingController();
    final _introducedController = TextEditingController();
    final _interestedController = TextEditingController();
    final _competitorsController = TextEditingController();
    final _notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加拜访记录'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _dateController,
                decoration: InputDecoration(labelText: '日期'),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    _dateController.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  }
                },
              ),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(labelText: '地点'),
              ),
              TextField(
                controller: _accompanyingController,
                decoration: InputDecoration(labelText: '随行人员'),
              ),
              TextField(
                controller: _introducedController,
                decoration: InputDecoration(labelText: '介绍的产品'),
              ),
              TextField(
                controller: _interestedController,
                decoration: InputDecoration(labelText: '客户意向产品'),
              ),
              TextField(
                controller: _competitorsController,
                decoration: InputDecoration(labelText: '同行竞争产品'),
              ),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(labelText: '备注'),
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
              final visit = Visit(
                customerId: widget.customer!.id!,
                date: _dateController.text,
                location: _locationController.text,
                accompanyingPersons: _accompanyingController.text,
                introducedProducts: _introducedController.text,
                interestedProducts: _interestedController.text,
                competitors: _competitorsController.text,
                notes: _notesController.text,
              );
              await appState.addVisit(visit);
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('拜访记录已添加')));
            },
            child: Text('添加'),
          ),
        ],
      ),
    );
  }

  void _addSale() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final _dateController = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0],
    );
    final _amountController = TextEditingController();
    Product? _selectedProduct;
    Colleague? _selectedColleague;
    final _commissionController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('添加销售记录'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _dateController,
                  decoration: InputDecoration(labelText: '日期'),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      _dateController.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }
                  },
                ),
                SizedBox(height: 10),
                Text('选择产品:'),
                SizedBox(height: 5),
                DropdownButton<Product>(
                  hint: Text('请选择产品'),
                  value: _selectedProduct,
                  onChanged: (Product? value) {
                    setDialogState(() {
                      _selectedProduct = value;
                    });
                  },
                  items: appState.products.map((Product product) {
                    return DropdownMenuItem<Product>(
                      value: product,
                      child: Text(product.name),
                    );
                  }).toList(),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: '备注',
                    hintText: '请输入备注信息（可多行）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  minLines: 3,
                ),
                SizedBox(height: 10),
                Text('选择合作同事:'),
                SizedBox(height: 5),
                DropdownButton<Colleague>(
                  hint: Text('请选择同事（可选）'),
                  value: _selectedColleague,
                  onChanged: (Colleague? value) {
                    setDialogState(() {
                      _selectedColleague = value;
                    });
                  },
                  items: appState.colleagues.map((Colleague colleague) {
                    return DropdownMenuItem<Colleague>(
                      value: colleague,
                      child: Text(colleague.name),
                    );
                  }).toList(),
                ),
                if (_selectedColleague != null)
                  TextField(
                    controller: _commissionController,
                    decoration: InputDecoration(labelText: '分成比例 (%)'),
                    keyboardType: TextInputType.number,
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
                if (_selectedProduct == null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('请选择产品')));
                  return;
                }

                final sale = Sale(
                  customerId: widget.customer!.id!,
                  productId: _selectedProduct!.id!,
                  notes: _amountController.text,
                  saleDate: _dateController.text,
                  colleagueId: _selectedColleague?.id,
                  commissionRate: _selectedColleague != null
                      ? double.parse(_commissionController.text)
                      : null,
                );
                await appState.addSale(sale);
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('销售记录已添加')));
              },
              child: Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _addCustomerRelationship() async {
    final appState = Provider.of<AppState>(context, listen: false);
    Customer? _selectedCustomer;
    String _relationshipType = '家人';
    final List<String> _relationshipTypes = ['家人', '朋友', '同事', '同学', '其他'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('添加客户关系'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Text('选择客户:'),
                SizedBox(height: 5),
                DropdownButton<Customer>(
                  hint: Text('请选择客户'),
                  value: _selectedCustomer,
                  onChanged: (Customer? value) {
                    setDialogState(() {
                      _selectedCustomer = value;
                    });
                  },
                  items: appState.customers
                      .where((customer) => customer.id != widget.customer!.id)
                      .map((Customer customer) {
                        return DropdownMenuItem<Customer>(
                          value: customer,
                          child: Text(customer.name),
                        );
                      })
                      .toList(),
                ),
                SizedBox(height: 10),
                Text('选择关系类型:'),
                SizedBox(height: 5),
                DropdownButton<String>(
                  value: _relationshipType,
                  onChanged: (String? value) {
                    setDialogState(() {
                      _relationshipType = value!;
                    });
                  },
                  items: _relationshipTypes.map((String type) {
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
                if (_selectedCustomer == null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('请选择客户')));
                  return;
                }

                await appState.addCustomerRelationship(
                  widget.customer!.id!,
                  _selectedCustomer!.id!,
                  _relationshipType,
                );
                Navigator.pop(context);
                // 触发 UI 更新
                setState(() {});
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('客户关系已添加')));
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
      final productIds = customerProductMaps.map((p) => p['id']).toSet();
      return appState.products.where((p) => productIds.contains(p.id)).toList();
    } else {
      final db = DatabaseHelper.instance;
      final customerProductMaps = await db.getCustomerProducts(
        widget.customer!.id!,
      );
      return customerProductMaps.map((map) => Product.fromMap(map)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isEditMode = widget.customer != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? (_isEditing ? '编辑客户' : '客户详情') : '添加客户'),
        backgroundColor: Colors.blue.shade800,
        actions: [
          if (isEditMode)
            Row(
              children: [
                IconButton(
                  icon: Icon(_isEditing ? Icons.save : Icons.edit),
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
                IconButton(
                  icon: Icon(Icons.delete),
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
                            onPressed: () {
                              appState.deleteCustomer(widget.customer!.id!);
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            child: Text('删除'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 基本信息部分
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '基本信息',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              enabled: _isEditing,
                              decoration: InputDecoration(
                                labelText: '姓名',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入姓名';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: _isEditing ? _scanIdCard : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(Icons.document_scanner),
                            label: Text('扫描身份证'),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: _isEditing ? _pickImage : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(Icons.camera_alt),
                            label: Text('添加照片'),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: _aliasController,
                        enabled: _isEditing,
                        decoration: InputDecoration(
                          labelText: '别名',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _ageController.text.isNotEmpty
                                  ? _ageController.text
                                  : null,
                              decoration: InputDecoration(
                                labelText: '年龄',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              hint: Text('选择年龄'),
                              items: List.generate(80, (index) {
                                final age = index + 1;
                                return DropdownMenuItem(
                                  value: age.toString(),
                                  child: Text(age.toString()),
                                );
                              }),
                              onChanged: _isEditing
                                  ? (value) {
                                      setState(() {
                                        _ageController.text = value ?? '';
                                      });
                                    }
                                  : null,
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: InputDecoration(
                                labelText: '性别',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              items: ['男', '女'].map((gender) {
                                return DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                );
                              }).toList(),
                              onChanged: _isEditing
                                  ? (value) {
                                      setState(() {
                                        _gender = value!;
                                      });
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Text(
                        '购买意向评级',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (index) {
                          final rating = 5 - index;
                          String ratingText = '';
                          switch (rating) {
                            case 1:
                              ratingText = '低';
                              break;
                            case 2:
                              ratingText = '中低';
                              break;
                            case 3:
                              ratingText = '中';
                              break;
                            case 4:
                              ratingText = '中高';
                              break;
                            case 5:
                              ratingText = '高';
                              break;
                          }
                          return GestureDetector(
                            onTap: _isEditing
                                ? () {
                                    setState(() {
                                      _rating = rating;
                                    });
                                  }
                                : null,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _rating == rating
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: _rating == rating
                                    ? [
                                        BoxShadow(
                                          color: Colors.blue.shade300,
                                          spreadRadius: 2,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Text(
                                ratingText,
                                style: TextStyle(
                                  color: _rating == rating
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // 联系方式部分
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '联系方式',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          Icon(
                            Icons.phone_android,
                            color: Colors.blue.shade800,
                            size: 24,
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              enabled: _isEditing,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: '输入手机号',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _isEditing ? _addPhone : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                            ),
                            child: Text('添加'),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      _phones.isEmpty
                          ? Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '暂无联系方式',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _phones.length,
                              itemBuilder: (context, index) {
                                final phone = _phones[index];
                                return Card(
                                  margin: EdgeInsets.symmetric(vertical: 8),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      phone,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.phone,
                                            color: Colors.green,
                                          ),
                                          onPressed: () =>
                                              _makePhoneCall(phone),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.sms,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () => _sendSms(phone),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.chat,
                                            color: Colors.purple,
                                          ),
                                          onPressed: () =>
                                              _openMessagingApp(phone),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.close,
                                            color: Colors.red,
                                          ),
                                          onPressed: _isEditing
                                              ? () => _removePhone(index)
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // 地址信息部分
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '地址信息',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          Icon(
                            Icons.location_on,
                            color: Colors.red.shade600,
                            size: 24,
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _addressController,
                              enabled: _isEditing,
                              decoration: InputDecoration(
                                hintText: '输入地址',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _isEditing ? _addAddress : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                            ),
                            child: Text('添加'),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      _addresses.isEmpty
                          ? Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '暂无地址信息',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _addresses.map((address) {
                                return Chip(
                                  label: Text(
                                    address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  deleteIcon: _isEditing
                                      ? Icon(Icons.close, size: 16)
                                      : null,
                                  onDeleted: _isEditing
                                      ? () {
                                          _removeAddress(
                                            _addresses.indexOf(address),
                                          );
                                        }
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  backgroundColor: Colors.blue.shade50,
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // 照片信息部分
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '相关照片',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          Icon(
                            Icons.photo_library,
                            color: Colors.green.shade600,
                            size: 24,
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      _photos.isEmpty
                          ? Container(
                              padding: EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.image,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    '暂无照片',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: _photos.map((photo) {
                                return Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.3),
                                        spreadRadius: 3,
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          File(photo),
                                          fit: BoxFit.cover,
                                          width: 120,
                                          height: 120,
                                        ),
                                      ),
                                      Positioned(
                                        top: -10,
                                        right: -10,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(
                                                  0.3,
                                                ),
                                                spreadRadius: 2,
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.close,
                                              color: Colors.red,
                                              size: 18,
                                            ),
                                            onPressed: _isEditing
                                                ? () {
                                                    _removePhoto(
                                                      _photos.indexOf(photo),
                                                    );
                                                  }
                                                : null,
                                            padding: EdgeInsets.all(6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // 位置信息部分
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '位置信息',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          Icon(
                            Icons.map,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 3,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _buildMapWidget(),
                      ),
                      SizedBox(height: 15),
                      ElevatedButton.icon(
                        onPressed: _isEditing ? _getCurrentLocation : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        icon: Icon(Icons.my_location),
                        label: Text('获取当前位置'),
                      ),
                    ],
                  ),
                ),
              ),
              if (isEditMode)
                Column(
                  children: [
                    // 产品信息部分
                    SizedBox(height: 30),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '已购买产品',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Icon(
                                  Icons.shopping_cart,
                                  color: Colors.green.shade600,
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            FutureBuilder<List<Product>>(
                              future: _getCustomerProducts(appState),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                } else if (snapshot.hasError) {
                                  return Text('获取产品信息失败');
                                } else if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return Text(
                                    '暂无已购买产品',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  );
                                } else {
                                  return ListView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    itemCount: snapshot.data!.length,
                                    itemBuilder: (context, index) {
                                      final product = snapshot.data![index];
                                      return Card(
                                        margin: EdgeInsets.symmetric(
                                          vertical: 5,
                                        ),
                                        child: ListTile(
                                          title: Text(product.name),
                                          subtitle: Text(
                                            product.category ?? '未分类',
                                          ),
                                          trailing: Icon(Icons.arrow_forward),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ProductDetailPage(
                                                      product: product,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 客户关系部分
                    SizedBox(height: 20),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '客户关系',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.people,
                                      color: Colors.blue.shade600,
                                    ),
                                    SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      onPressed: _addCustomerRelationship,
                                      icon: Icon(Icons.add, size: 16),
                                      label: Text('添加关系'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Builder(
                              builder: (context) {
                                final updatedCustomer = appState.customers
                                    .firstWhere(
                                      (c) => c.id == widget.customer!.id,
                                      orElse: () => widget.customer!,
                                    );
                                final relationships =
                                    updatedCustomer.relationships;
                                if (relationships.isNotEmpty)
                                  return Column(
                                    children: [
                                      Container(
                                        height: 300,
                                        child: CustomPaint(
                                          painter: RelationshipGraphPainter(
                                            centerCustomer: updatedCustomer,
                                            relationships: relationships,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      ...relationships.map(
                                        (rel) => Dismissible(
                                          key: ValueKey(
                                            'rel_${rel['id']}_$rel',
                                          ),
                                          direction:
                                              DismissDirection.endToStart,
                                          background: Container(
                                            alignment: Alignment.centerRight,
                                            padding: EdgeInsets.only(right: 20),
                                            margin: EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Color(0xFFE53935),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.delete_rounded,
                                              color: Colors.white,
                                            ),
                                          ),
                                          confirmDismiss: (direction) async {
                                            return await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Text('确认删除'),
                                                content: Text('确定要删除这条客户关系吗？'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: Text('取消'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          true,
                                                        ),
                                                    child: Text(
                                                      '删除',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          onDismissed: (direction) async {
                                            final appState =
                                                Provider.of<AppState>(
                                                  context,
                                                  listen: false,
                                                );
                                            if (rel['id'] != null) {
                                              await appState
                                                  .deleteCustomerRelationship(
                                                    rel['id'] as int,
                                                  );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('客户关系已删除'),
                                                ),
                                              );
                                            }
                                          },
                                          child: Card(
                                            margin: EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: ListTile(
                                              leading: Icon(
                                                Icons.person,
                                                color: Colors.blue.shade600,
                                              ),
                                              title: Text(rel['name'] ?? ''),
                                              subtitle: Text(
                                                rel['relationship'] ?? '',
                                              ),
                                              trailing: Icon(
                                                Icons.arrow_forward,
                                                size: 16,
                                              ),
                                              onTap: () {
                                                final relatedId = rel['id'];
                                                if (relatedId != null) {
                                                  final relatedCustomer =
                                                      appState.customers
                                                          .firstWhere(
                                                            (c) =>
                                                                c.id ==
                                                                relatedId,
                                                            orElse: () => widget
                                                                .customer!,
                                                          );
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          CustomerDetailPage(
                                                            customer:
                                                                relatedCustomer,
                                                          ),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                else
                                  return Text(
                                    '暂无客户关系',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 拜访记录部分
                    SizedBox(height: 30),
                    Text(
                      '拜访记录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _addVisit,
                      icon: Icon(Icons.add),
                      label: Text('添加拜访记录'),
                    ),
                    SizedBox(height: 10),
                    if (widget.customer!.visits.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: widget.customer!.visits.length,
                        itemBuilder: (context, index) {
                          final visit = widget.customer!.visits[index];
                          return Dismissible(
                            key: ValueKey('visit_${visit['id']}_$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.only(right: 20),
                              margin: EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(
                                color: Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.delete_rounded,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('确认删除'),
                                  content: Text('确定要删除这条拜访记录吗？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(
                                        '删除',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) async {
                              final appState = Provider.of<AppState>(
                                context,
                                listen: false,
                              );
                              if (visit['id'] != null) {
                                await appState.deleteVisit(visit['id'] as int);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('拜访记录已删除')),
                                );
                              }
                            },
                            child: Card(
                              margin: EdgeInsets.symmetric(vertical: 5),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      visit['date'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (visit['location'] != null &&
                                        visit['location'].isNotEmpty)
                                      Text('地点: ${visit['location']}'),
                                    if (visit['accompanying_persons'] != null &&
                                        visit['accompanying_persons']
                                            .isNotEmpty)
                                      Text(
                                        '随行人员: ${visit['accompanying_persons']}',
                                      ),
                                    if (visit['introduced_products'] != null &&
                                        visit['introduced_products'].isNotEmpty)
                                      Text(
                                        '介绍的产品: ${visit['introduced_products']}',
                                      ),
                                    if (visit['interested_products'] != null &&
                                        visit['interested_products'].isNotEmpty)
                                      Text(
                                        '客户意向产品: ${visit['interested_products']}',
                                      ),
                                    if (visit['competitors'] != null &&
                                        visit['competitors'].isNotEmpty)
                                      Text('同行竞争产品: ${visit['competitors']}'),
                                    if (visit['notes'] != null &&
                                        visit['notes'].isNotEmpty)
                                      Text('备注: ${visit['notes']}'),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    // 销售记录部分
                    SizedBox(height: 30),
                    Text(
                      '销售记录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _addSale,
                      icon: Icon(Icons.add),
                      label: Text('添加销售记录'),
                    ),
                    SizedBox(height: 10),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: Provider.of<AppState>(
                        context,
                        listen: false,
                      ).getCustomerSales(widget.customer!.id!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Text('加载销售记录失败');
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return Text('暂无销售记录');
                        } else {
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              final sale = snapshot.data![index];
                              return Dismissible(
                                key: ValueKey('sale_${sale['id']}_$index'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.only(right: 20),
                                  margin: EdgeInsets.symmetric(vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFE53935),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.delete_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                confirmDismiss: (direction) async {
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text('确认删除'),
                                      content: Text('确定要删除这条销售记录吗？'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(
                                            '删除',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (direction) async {
                                  final appState = Provider.of<AppState>(
                                    context,
                                    listen: false,
                                  );
                                  if (sale['id'] != null) {
                                    await appState.deleteSale(
                                      sale['id'] as int,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('销售记录已删除')),
                                    );
                                  }
                                },
                                child: Card(
                                  margin: EdgeInsets.symmetric(vertical: 5),
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sale['sale_date'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text('产品: ${sale['product_name']}'),
                                        if (sale['notes'] != null &&
                                            sale['notes'].toString().isNotEmpty)
                                          Text('备注: ${sale['notes']}'),
                                        if (sale['colleague_name'] != null)
                                          Text(
                                            '合作同事: ${sale['colleague_name']} (分成比例: ${sale['commission_rate']}%)',
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
              SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: _saveCustomer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: EdgeInsets.symmetric(horizontal: 80, vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    shadowColor: Colors.blue.shade300,
                    elevation: 5,
                  ),
                  child: Text(
                    isEditMode ? '保存修改' : '添加客户',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
