import 'package:insurecrm/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';
import 'package:insurecrm/database/database_helper.dart';
import 'package:insurecrm/models/product.dart';
import 'package:insurecrm/models/customer.dart';
import 'package:insurecrm/pages/customer_detail_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:insurecrm/utils/image_utils.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class ProductDetailPage extends StatefulWidget {
  final Product? product;

  ProductDetailPage({this.product});

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _advantagesController = TextEditingController();
  final _categoryController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _newCompanyController = TextEditingController();
  final _newCategoryController = TextEditingController();

  // 内存中的附件（新增的、尚未保存到DB的）
  List<File> _mediaFiles = [];
  List<String> _mediaTypes = []; // 'image', 'video'
  // 从DB加载的已持久化附件
  List<Map<String, dynamic>> _savedAttachments = [];
  bool _isEditing = false;

  bool get isEditMode => widget.product != null;

  // 获取所有公司列表
  List<String> get _companyList {
    final appState = Provider.of<AppState>(context, listen: false);
    return appState.products.map((p) => p.company).toSet().toList()..sort();
  }

  // 获取所有分类列表
  List<String> get _categoryList {
    final appState = Provider.of<AppState>(context, listen: false);
    final categories = appState.products
        .where((p) => p.category != null && p.category!.isNotEmpty)
        .map((p) => p.category!)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _companyController.text = widget.product!.company;
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description ?? '';
      _advantagesController.text = widget.product!.advantages ?? '';
      _categoryController.text = widget.product!.category ?? '';
      _startDateController.text = widget.product!.startDate ?? '';
      _endDateController.text = widget.product!.endDate ?? '';
      _loadAttachments();
    }
  }

  /// 加载已有附件（从数据库）
  Future<void> _loadAttachments() async {
    if (!isEditMode || kIsWeb || widget.product?.id == null) return;
    try {
      final db = DatabaseHelper.instance;
      final attachments = await db.getProductAttachments(widget.product!.id!);
      setState(() => _savedAttachments = attachments);
    } catch (e) { AppLogger.error('loading attachments: $e'); }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _advantagesController.dispose();
    _categoryController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _newCompanyController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  // 选择图片（压缩后保存）
  Future<void> _pickImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('当前平台暂不支持添加图片')));
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final originalFile = File(pickedFile.path);
      // 压缩并复制到应用目录
      final compressedPath = await ImageUtils.compressAndSave(originalFile, subDir: 'product_attachments');
      setState(() {
        _mediaFiles.add(File(compressedPath));
        _mediaTypes.add('image');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图片已添加 (${ImageUtils.formatFileSize(ImageUtils.getFileSize(compressedPath))})')),
      );
    }
  }

  // 选择视频（直接复制）
  Future<void> _pickVideo() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('当前平台暂不支持添加视频')));
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      final savedPath = await ImageUtils.compressAndSave(File(pickedFile.path), subDir: 'product_attachments');
      setState(() {
        _mediaFiles.add(File(savedPath));
        _mediaTypes.add('video');
      });
    }
  }

  // 选择日期
  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        controller.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _showCompanyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('选择公司'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ..._companyList.map((c) => ListTile(
            title: Text(c),
            onTap: () { setState(() => _companyController.text = c); Navigator.pop(context); },
          )),
          Divider(),
          TextField(controller: _newCompanyController, decoration: InputDecoration(labelText: '输入新公司名称')),
          SizedBox(height: 10),
          ElevatedButton(onPressed: () {
            if (_newCompanyController.text.isNotEmpty) { setState(() => _companyController.text = _newCompanyController.text); Navigator.pop(context); }
          }, child: Text('添加新公司')),
        ]),
      ),
    );
  }

  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('选择分类'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ..._categoryList.map((cat) => ListTile(
            title: Text(cat),
            onTap: () { setState(() => _categoryController.text = cat); Navigator.pop(context); },
          )),
          Divider(),
          TextField(controller: _newCategoryController, decoration: InputDecoration(labelText: '输入新分类名称')),
          SizedBox(height: 10),
          ElevatedButton(onPressed: () {
            if (_newCategoryController.text.isNotEmpty) { setState(() => _categoryController.text = _newCategoryController.text); Navigator.pop(context); }
          }, child: Text('添加新分类')),
        ]),
      ),
    );
  }

  // 保存产品 + 附件
  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      final appState = Provider.of<AppState>(context, listen: false);

      final product = Product(
        id: widget.product?.id,
        company: _companyController.text,
        name: _nameController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        advantages: _advantagesController.text.isEmpty ? null : _advantagesController.text,
        category: _categoryController.text.isEmpty ? null : _categoryController.text,
        startDate: _startDateController.text.isEmpty ? null : _startDateController.text,
        endDate: _endDateController.text.isEmpty ? null : _endDateController.text,
        createdAt: widget.product?.createdAt ?? DateTime.now().toIso8601String(),
      );

      int? productId;

      if (widget.product == null) {
        await appState.addProduct(product);
        productId = appState.products.last.id;
      } else {
        productId = widget.product!.id;
        await appState.updateProduct(product);
      }

      // 保存新附件到数据库
      if (!_isSupported()) {
        Navigator.pop(context);
        return;
      }

      if (productId != null && _mediaFiles.isNotEmpty) {
        final db = DatabaseHelper.instance;
        for (int i = 0; i < _mediaFiles.length; i++) {
          final file = _mediaFiles[i];
          final mediaType = _mediaTypes[i];
          String? thumbnailPath;

          // 为图片生成缩略图
          if (mediaType == 'image') {
            thumbnailPath = await ImageUtils.generateThumbnail(file);
          }

          try {
            await db.insertProductAttachment({
              'product_id': productId,
              'file_path': file.path,
              'thumbnail_path': thumbnailPath,
              'media_type': mediaType,
              'file_name': path.basename(file.path),
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (e) { AppLogger.error('saving attachment $i: $e'); }
        }
      }

      Navigator.pop(context);
    }
  }

  bool _isSupported() => !kIsWeb;

  // 删除新选的附件（内存中）
  void _removeNewAttachment(int index) {
    final file = _mediaFiles[index];
    try { file.delete(); } catch (_) {}
    setState(() {
      _mediaFiles.removeAt(index);
      _mediaTypes.removeAt(index);
    });
  }

  // 删除已持久化的附件（DB中）
  void _removeSavedAttachment(int index) async {
    final attachment = _savedAttachments[index];
    final db = DatabaseHelper.instance;
    await db.deleteProductAttachment(attachment['id'] as int);
    setState(() => _savedAttachments.removeAt(index));
  }

  // 获取已购买该产品的客户列表
  Future<List<Customer>> _getProductCustomers(AppState appState) async {
    if (widget.product?.id == null) return [];
    if (kIsWeb) {
      return appState.customers.where((c) => c.products.any((p) => p['id'] == widget.product!.id)).toList();
    } else {
      final db = DatabaseHelper.instance;
      final dbInstance = await db.database;
      final customerProductMaps = await dbInstance.rawQuery(
        'SELECT DISTINCT customer_id FROM customer_products WHERE product_id = ?', [widget.product!.id],
      );
      final customerIds = customerProductMaps.map((m) => m['customer_id'] as int).toSet();
      return appState.customers.where((c) => customerIds.contains(c.id)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? (_isEditing ? '编辑产品' : '产品详情') : '添加产品'),
        backgroundColor: Colors.blue.shade800,
        actions: [
          if (isEditMode)
            Row(children: [
              IconButton(
                icon: Icon(_isEditing ? Icons.save : Icons.edit),
                onPressed: () {
                  if (_isEditing) { _saveProduct(); } else { setState(() => _isEditing = true); }
                },
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  showDialog(context: context, builder: (context) => AlertDialog(
                    title: Text('确认删除'),
                    content: Text('确定要删除这个产品吗？所有附件也将被删除。'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text('取消')),
                      TextButton(onPressed: () {
                        appState.deleteProduct(widget.product!.id!); Navigator.pop(context); Navigator.pop(context);
                      }, child: Text('删除', style: TextStyle(color: Colors.red))),
                    ],
                  ));
                },
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(padding: EdgeInsets.all(20), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 公司选择
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('所属公司', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextFormField(controller: _companyController, enabled: _isEditing || !isEditMode, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50), validator: (v) => v == null || v.isEmpty ? '请选择公司' : null)),
            SizedBox(width: 10),
            ElevatedButton(onPressed: (_isEditing || !isEditMode) ? _showCompanyDialog : null, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700), child: Text('选择')),
          ]),
        ]))),
        SizedBox(height: 20),

        // 产品名称
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('产品名称', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          TextFormField(controller: _nameController, enabled: _isEditing || !isEditMode, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50), validator: (v) => v == null || v.isEmpty ? '请输入产品名称' : null),
        ]))),
        SizedBox(height: 20),

        // 产品分类
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('产品分类', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextFormField(controller: _categoryController, enabled: _isEditing || !isEditMode, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50))),
            SizedBox(width: 10),
            ElevatedButton(onPressed: (_isEditing || !isEditMode) ? _showCategoryDialog : null, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700), child: Text('选择')),
          ]),
        ]))),
        SizedBox(height: 20),

        // 产品介绍 + 多媒体
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('产品介绍', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          TextFormField(controller: _descriptionController, enabled: _isEditing || !isEditMode, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50, alignLabelWithHint: true), maxLines: 5),
          SizedBox(height: 15),
          Text('多媒体附件', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Row(children: [
            ElevatedButton.icon(
              onPressed: (_isEditing || !isEditMode) && !kIsWeb ? _pickImage : null,
              icon: Icon(Icons.image), label: Text('添加图片'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
            ),
            SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: (_isEditing || !isEditMode) && !kIsWeb ? _pickVideo : null,
              icon: Icon(Icons.video_library), label: Text('添加视频'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600),
            ),
          ]),
          SizedBox(height: 15),

          // 已保存的附件（从DB加载）
          if (_savedAttachments.isNotEmpty) ...[
            Text('已保存附件', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: _savedAttachments.asMap().entries.map((entry) {
              int index = entry.key;
              var att = entry.value;
              String type = att['media_type'] as String? ?? 'image';
              String filePath = att['file_path'] as String? ?? '';
              String thumbPath = att['thumbnail_path'] as String? ?? '';
              String fileName = att['file_name'] as String? ?? '文件';

              return Container(width: 100, height: 100, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 2, blurRadius: 4)]), child: Stack(children: [
                if (type == 'image')
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: thumbPath.isNotEmpty
                    ? Image.file(File(thumbPath), fit: BoxFit.cover, width: 100, height: 100, errorBuilder: (_, __, ___) => _buildImageFallback(filePath))
                    : _buildImageFallback(filePath))
                else
                  Container(decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.play_circle, color: Colors.white, size: 40)),
                Positioned(top: -6, right: -6, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3))]), child: IconButton(icon: Icon(Icons.close, color: Colors.red, size: 16), onPressed: (_isEditing || !isEditMode) ? () => _removeSavedAttachment(index) : null, padding: EdgeInsets.all(4)))),
                Positioned(bottom: 2, left: 2, right: 2, child: Container(padding: EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)), child: Text(fileName.length > 12 ? '${fileName.substring(0, 9)}...' : fileName, style: TextStyle(fontSize: 8, color: Colors.white), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
              ]));
            }).toList()),
            SizedBox(height: 10),
          ],

          // 新增的附件（未保存到DB）
          if (_mediaFiles.isNotEmpty) ...[
            if (_savedAttachments.isNotEmpty) Text('待保存附件', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500)),
            SizedBox(height: _savedAttachments.isNotEmpty ? 8 : 0),
            Wrap(spacing: 10, runSpacing: 10, children: _mediaFiles.asMap().entries.map((entry) {
              int index = entry.key;
              File file = entry.value;
              String type = _mediaTypes[index];
              String fileSize = ImageUtils.formatFileSize(file.lengthSync());

              return Container(width: 100, height: 100, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), spreadRadius: 2, blurRadius: 4)]), child: Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: type == 'image'
                  ? Image.file(file, fit: BoxFit.cover, width: 100, height: 100)
                  : Container(decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.play_circle, color: Colors.white, size: 40))),
                Positioned(top: -6, right: -6, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: IconButton(icon: Icon(Icons.close, color: Colors.red, size: 16), onPressed: () => _removeNewAttachment(index), padding: EdgeInsets.all(4)))),
                Positioned(bottom: 2, left: 2, child: Container(padding: EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.85), borderRadius: BorderRadius.circular(4)), child: Text(fileSize, style: TextStyle(fontSize: 8, color: Colors.white)))),
              ]));
            }).toList()),
          ],
        ]))),
        SizedBox(height: 20),

        // 产品优势
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('产品优势', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          TextFormField(controller: _advantagesController, enabled: _isEditing || !isEditMode, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50, alignLabelWithHint: true), maxLines: 3),
        ]))),
        SizedBox(height: 20),

        // 日期设置
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('日期设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Row(children: [
            Expanded(child: GestureDetector(onTap: (_isEditing || !isEditMode) ? () => _selectDate(_startDateController) : null, child: AbsorbPointer(child: TextFormField(controller: _startDateController, enabled: _isEditing || !isEditMode, decoration: InputDecoration(labelText: '生效日期', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50, suffixIcon: Icon(Icons.calendar_today)))))),
            SizedBox(width: 20),
            Expanded(child: GestureDetector(onTap: (_isEditing || !isEditMode) ? () => _selectDate(_endDateController) : null, child: AbsorbPointer(child: TextFormField(controller: _endDateController, enabled: _isEditing || !isEditMode, decoration: InputDecoration(labelText: '结束日期', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade50, suffixIcon: Icon(Icons.calendar_today)))))),
          ]),
        ]))),
        SizedBox(height: 30),

        // 已购买客户
        if (isEditMode)
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('已购买客户', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 12),
            FutureBuilder<List<Customer>>(future: _getProductCustomers(appState), builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Text('获取客户信息失败');
              if (!snapshot.hasData || snapshot.data!.isEmpty) return Text('暂无客户购买此产品', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
              return ListView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics(), itemCount: snapshot.data!.length, itemBuilder: (_, idx) {
                final customer = snapshot.data![idx];
                return Card(margin: EdgeInsets.symmetric(vertical: 5), child: ListTile(title: Text(customer.name), subtitle: Text(customer.phones.isNotEmpty ? customer.phones[0] : '无联系方式'), trailing: Icon(Icons.arrow_forward), onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => CustomerDetailPage(customer: customer)))));
              });
            }),
          ]))),
        SizedBox(height: 30),

        Center(child: ElevatedButton(
          onPressed: _saveProduct,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: EdgeInsets.symmetric(horizontal: 80, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), elevation: 5),
          child: Text(isEditMode ? '保存修改' : '添加产品', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        )),
        SizedBox(height: 30),
      ]))),
    );
  }

  Widget _buildImageFallback(String filePath) {
    final file = File(filePath);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover, width: 100, height: 100);
    }
    return Container(color: Colors.grey.shade200, child: Icon(Icons.broken_image, color: Colors.grey, size: 32));
  }
}
