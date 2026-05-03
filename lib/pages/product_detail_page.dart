import 'package:insurance_manager/widgets/app_components.dart';
import 'package:insurance_manager/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/database/database_helper.dart';
import 'package:insurance_manager/models/product.dart';
import 'package:insurance_manager/models/customer.dart';
import 'package:insurance_manager/pages/customer_detail_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:insurance_manager/utils/image_utils.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class ProductDetailPage extends StatefulWidget {
  final Product? product;

  const ProductDetailPage({super.key, this.product});

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sellingPointsController = TextEditingController();
  final _categoryController = TextEditingController();
  final _salesStartDateController = TextEditingController();
  final _salesEndDateController = TextEditingController();
  final _newCompanyController = TextEditingController();
  final _newCategoryController = TextEditingController();

  // 内存中的附件（新增的、尚未保存到DB的）
  final List<File> _mediaFiles = [];
  final List<String> _mediaTypes = []; // 'image', 'video'
  // 从DB加载的已持久化附件
  List<Map<String, dynamic>> _savedAttachments = [];
  bool _isEditing = false;

  // Cache for FutureBuilder to avoid recreating Future on every rebuild
  Future<List<Customer>>? _productCustomersFuture;

  bool get isEditMode => widget.product != null;

  // Cache for company/category lists to avoid recomputing on every build
  List<String>? _cachedCompanyList;
  List<String>? _cachedCategoryList;

  // 获取所有公司列表
  List<String> get _companyList {
    if (_cachedCompanyList != null) return _cachedCompanyList!;
    final appState = Provider.of<AppState>(context, listen: false);
    _cachedCompanyList = appState.products.map((p) => p.company).toSet().toList()..sort();
    return _cachedCompanyList!;
  }

  // 获取所有分类列表
  List<String> get _categoryList {
    if (_cachedCategoryList != null) return _cachedCategoryList!;
    final appState = Provider.of<AppState>(context, listen: false);
    final categories = appState.products
        .where((p) => p.category != null && p.category!.isNotEmpty)
        .map((p) => p.category!)
        .toSet()
        .toList();
    categories.sort();
    _cachedCategoryList = categories;
    return _cachedCategoryList!;
  }

  void _invalidateProductCaches() {
    _cachedCompanyList = null;
    _cachedCategoryList = null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _companyController.text = widget.product!.company;
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description ?? '';
      _sellingPointsController.text = widget.product!.sellingPoints ?? '';
      _categoryController.text = widget.product!.category ?? '';
      _salesStartDateController.text = widget.product!.salesStartDate ?? '';
      _salesEndDateController.text = widget.product!.salesEndDate ?? '';
      _loadAttachments();
    } else {
      _isEditing = true;
    }
  }

  /// 加载已有附件（从数据库）
  Future<void> _loadAttachments() async {
    if (!isEditMode || kIsWeb || widget.product?.id == null) return;
    try {
      final db = DatabaseHelper.instance;
      final attachments = await db.getProductAttachments(widget.product!.id!);
      if (!mounted) return;
      setState(() => _savedAttachments = attachments);
    } catch (e) { AppLogger.error('loading attachments: $e'); }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _sellingPointsController.dispose();
    _categoryController.dispose();
    _salesStartDateController.dispose();
    _salesEndDateController.dispose();
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
      if (!context.mounted) return;
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
      if (!context.mounted) return;
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
      if (!context.mounted) return;
      setState(() {
        controller.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _showCompanyDialog() {
    _newCompanyController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('选择公司'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ..._companyList.map<Widget>((c) => ListTile(
            title: Text(c),
            onTap: () { setState(() => _companyController.text = c); Navigator.pop(context); },
          )),
          if (_companyList.isNotEmpty) Divider(),
          TextField(controller: _newCompanyController, decoration: InputDecoration(
            labelText: '新公司名称',
            prefixIcon: Icon(Icons.business),
          )),
          SizedBox(height: 10),
          ElevatedButton(onPressed: () {
            if (_newCompanyController.text.isNotEmpty) { setState(() => _companyController.text = _newCompanyController.text); Navigator.pop(context); }
          }, child: Text('添加新公司')),
        ]),
      ),
    );
  }

  void _showCategoryDialog() {
    _newCategoryController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('选择分类'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ..._categoryList.map<Widget>((cat) => ListTile(
            title: Text(cat),
            onTap: () { setState(() => _categoryController.text = cat); Navigator.pop(context); },
          )),
          if (_categoryList.isNotEmpty) Divider(),
          TextField(controller: _newCategoryController, decoration: InputDecoration(
            labelText: '新分类名称',
            prefixIcon: Icon(Icons.category),
          )),
          SizedBox(height: 10),
          ElevatedButton(onPressed: () {
            if (_newCategoryController.text.isNotEmpty) { setState(() => _categoryController.text = _newCategoryController.text); Navigator.pop(context); }
          }, child: Text('添加新分类')),
        ]),
      ),
    );
  }

  bool _isSaving = false;

  // 保存产品 + 附件
  void _saveProduct() async {
    if (_isSaving) return;
    if (_formKey.currentState?.validate() ?? false) {
      final appState = Provider.of<AppState>(context, listen: false);

      final product = Product(
        id: widget.product?.id,
        company: _companyController.text,
        name: _nameController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        sellingPoints: _sellingPointsController.text.isEmpty ? null : _sellingPointsController.text,
        category: _categoryController.text.isEmpty ? null : _categoryController.text,
        salesStartDate: _salesStartDateController.text.isEmpty ? null : _salesStartDateController.text,
        salesEndDate: _salesEndDateController.text.isEmpty ? null : _salesEndDateController.text,
        createdAt: widget.product?.createdAt ?? DateTime.now().toIso8601String(),
      );

      _isSaving = true;
      setState(() {});
      int? productId;

      if (widget.product == null) {
        productId = await appState.addProduct(product);
      } else {
        productId = widget.product!.id;
        await appState.updateProduct(product);
      }

      if (productId == null) {
        if (mounted) setState(() { _isSaving = false; });
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存产品失败，请重试')),
        );
        return;
      }

      // 保存新附件到数据库
      if (!_isSupported()) {
        if (!context.mounted) return;
        Navigator.pop(context);
        return;
      }

      if (_mediaFiles.isNotEmpty) {
        final db = DatabaseHelper.instance;
        try {
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
        } catch (e) {
          AppLogger.error('saving attachments: $e');
        }
      }

      if (!context.mounted) return;
      _isSaving = false;
      _invalidateProductCaches(); // Invalidate cached lists since product data changed
      setState(() {});
      Navigator.pop(context);
    }
  }

  bool _isSupported() => !kIsWeb;

  // 删除新选的附件（内存中）
  void _removeNewAttachment(int index) {
    final file = _mediaFiles[index];
    try { file.deleteSync(); } catch (_) {}
    setState(() {
      _mediaFiles.removeAt(index);
      _mediaTypes.removeAt(index);
    });
  }

  // 删除已持久化的附件（DB中）
  void _removeSavedAttachment(int index) async {
    final attachment = _savedAttachments[index];
    final id = (attachment['id'] as num?)?.toInt();
    if (id == null || id <= 0) return;
    final db = DatabaseHelper.instance;
    try {
      await db.deleteProductAttachment(id);
      if (!mounted) return;
      setState(() => _savedAttachments.removeAt(index));
    } catch (e) {
      AppLogger.error('deleting attachment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除附件失败')),
        );
      }
    }
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
      final customerIds = customerProductMaps.map((m) => (m['customer_id'] as num?)?.toInt() ?? -1).toSet();
      return appState.customers.where((c) => customerIds.contains(c.id)).toList();
    }
  }

  // ============ iOS 风格 UI 组件 ============

  /// 顶部产品封面区域
  Widget _buildProductHeader() {
    // Use first attachment as cover if available
    String? coverPath;
    if (_savedAttachments.isNotEmpty) {
      final imageAtt = _savedAttachments.firstWhere(
        (att) => att['media_type'] == 'image',
        orElse: () => <String, dynamic>{},
      );
      if (imageAtt.isNotEmpty) {
        coverPath = (imageAtt['thumbnail_path'] as String?)?.isNotEmpty == true
            ? imageAtt['thumbnail_path']
            : imageAtt['file_path'] as String?;
      }
    } else if (_mediaFiles.isNotEmpty && _mediaTypes.isNotEmpty && _mediaTypes[0] == 'image') {
      coverPath = _mediaFiles[0].path;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      color: AppDesign.cardBg(isDark),
      child: Column(
        children: [
          // 产品封面图
          GestureDetector(
            onTap: _isEditing ? _pickImage : null,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Color(0xFF00897B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: coverPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: kIsWeb
                              ? _buildProductIcon()
                              : Image.file(
                                  File(coverPath),
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                  errorBuilder: (_, _, _) => _buildProductIcon(),
                                ),
                        )
                      : _buildProductIcon(),
                ),
                if (_isEditing)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Color(0xFF00897B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(Icons.camera_alt, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 10),
          // 产品名称
          _isEditing
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: TextFormField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF00897B)),
                      ),
                      hintText: '产品名称',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18),
                    ),
                    validator: (v) => v == null || v.isEmpty ? '请输入产品名称' : null,
                  ),
                )
              : Text(
                  _nameController.text.isEmpty ? '未命名产品' : _nameController.text,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
          // 公司名
          if (_companyController.text.isNotEmpty || _isEditing)
            _isEditing
                ? Padding(
                    padding: EdgeInsets.only(left: 40, right: 40, top: 4),
                    child: TextFormField(
                      controller: _companyController,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 2),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF00897B)),
                        ),
                        hintText: '所属公司',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                      validator: (v) => v == null || v.isEmpty ? '请输入公司' : null,
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      _companyController.text,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                    ),
                  ),
          // 分类标签
          if (_categoryController.text.isNotEmpty && !_isEditing)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFF00897B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _categoryController.text,
                  style: TextStyle(color: Color(0xFF00897B), fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductIcon() {
    return Center(
      child: Icon(Icons.inventory_2_rounded, size: 36, color: Color(0xFF00897B)),
    );
  }

  /// iOS 风格的分组卡片
  Widget _buildGroupedSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 20, top: 24, bottom: 6),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  /// iOS 风格的表单行
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
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(left: icon != null ? 48 : 84),
            child: Divider(height: 1, thickness: 0.5),
          ),
      ],
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

  /// 带选择按钮的行（公司/分类）
  Widget _buildSelectableFieldRow({
    required String label,
    required TextEditingController controller,
    required VoidCallback onSelect,
    bool enabled = true,
    bool showDivider = true,
    IconData? icon,
  }) {
    return _buildFieldRow(
      label: label,
      icon: icon,
      showDivider: showDivider,
      child: Row(
        children: [
          Expanded(
            child: Text(
              controller.text.isEmpty ? '选择$label' : controller.text,
              style: TextStyle(
                fontSize: 15,
                color: controller.text.isEmpty ? Colors.grey.shade400 : (enabled ? _textPrimary : Colors.grey.shade500),
              ),
            ),
          ),
          if (enabled)
            InkWell(
              onTap: onSelect,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Color(0xFF00897B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('选择', style: TextStyle(color: Color(0xFF00897B), fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ),
        ],
      ),
    );
  }

  /// 日期选择行
  Widget _buildDateFieldRow({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
    bool showDivider = true,
    IconData? icon,
  }) {
    return _buildFieldRow(
      label: label,
      icon: icon,
      showDivider: showDivider,
      child: enabled
          ? InkWell(
              onTap: () => _selectDate(controller),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.text.isEmpty ? '选择日期' : controller.text,
                      style: TextStyle(
                        fontSize: 15,
                        color: controller.text.isEmpty ? Colors.grey.shade400 : _textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade400),
                ],
              ),
            )
          : Text(
              controller.text.isEmpty ? '-' : controller.text,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
            ),
    );
  }

  /// 基本信息区块
  Widget _buildBasicInfoSection() {
    return _buildGroupedSection(
      title: '基本信息',
      children: [
        // 公司
        _buildSelectableFieldRow(
          label: '公司',
          controller: _companyController,
          onSelect: _showCompanyDialog,
          enabled: _isEditing || !isEditMode,
          icon: Icons.business,
          showDivider: true,
        ),
        // 产品名称（非头部编辑时）
        // 分类
        _buildSelectableFieldRow(
          label: '分类',
          controller: _categoryController,
          onSelect: _showCategoryDialog,
          enabled: _isEditing || !isEditMode,
          icon: Icons.category,
          showDivider: false,
        ),
      ],
    );
  }

  /// 产品详情区块
  Widget _buildDetailsSection() {
    return _buildGroupedSection(
      title: '产品详情',
      children: [
        _buildTextFieldRow(
          label: '介绍',
          controller: _descriptionController,
          enabled: _isEditing || !isEditMode,
          hintText: '产品介绍',
          icon: Icons.description,
          maxLines: 5,
          showDivider: true,
        ),
        _buildTextFieldRow(
          label: '优势',
          controller: _sellingPointsController,
          enabled: _isEditing || !isEditMode,
          hintText: '产品优势',
          icon: Icons.emoji_events,
          maxLines: 3,
          showDivider: false,
        ),
      ],
    );
  }

  /// 日期区块
  Widget _buildDateSection() {
    return _buildGroupedSection(
      title: '日期设置',
      children: [
        _buildDateFieldRow(
          label: '生效',
          controller: _salesStartDateController,
          enabled: _isEditing || !isEditMode,
          icon: Icons.play_circle_outline,
          showDivider: true,
        ),
        _buildDateFieldRow(
          label: '结束',
          controller: _salesEndDateController,
          enabled: _isEditing || !isEditMode,
          icon: Icons.stop_circle_outlined,
          showDivider: false,
        ),
      ],
    );
  }

  /// 多媒体附件区块
  Widget _buildMediaSection() {
    final bool canEdit = _isEditing || !isEditMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildGroupedSection(
      title: '多媒体',
      children: [
        // 添加按钮
        if (canEdit)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.attach_file, size: 20, color: Colors.grey.shade400),
                ),
                SizedBox(width: 56),
                Expanded(
                  child: Row(
                    children: [
                      InkWell(
                        onTap: !kIsWeb ? _pickImage : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.green.shade900.withValues(alpha: 0.2) : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image, size: 16, color: Colors.green.shade600),
                              SizedBox(width: 4),
                              Text('图片', style: TextStyle(color: Colors.green.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      InkWell(
                        onTap: !kIsWeb ? _pickVideo : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.purple.shade900.withValues(alpha: 0.2) : Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? Colors.purple.shade700 : Colors.purple.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam, size: 16, color: Colors.purple.shade600),
                              SizedBox(width: 4),
                              Text('视频', style: TextStyle(color: Colors.purple.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // 已保存的附件（从DB加载）
        if (_savedAttachments.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(spacing: 8, runSpacing: 8, children: _savedAttachments.asMap().entries.map<Widget>((entry) {
              int index = entry.key;
              var att = entry.value;
              String type = att['media_type'] as String? ?? 'image';
              String filePath = att['file_path'] as String? ?? '';
              String thumbPath = att['thumbnail_path'] as String? ?? '';
              String fileName = att['file_name'] as String? ?? '文件';

              return Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade100,
                    ),
                    child: type == 'image'
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: thumbPath.isNotEmpty
                              ? (kIsWeb ? _buildImageFallback(filePath) : Image.file(File(thumbPath), fit: BoxFit.cover, width: 80, height: 80, errorBuilder: (_, _, _) => _buildImageFallback(filePath)))
                              : _buildImageFallback(filePath))
                        : Container(
                            decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Icon(Icons.play_circle, color: Colors.white, size: 32))),
                  ),
                  if (canEdit)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: GestureDetector(
                        onTap: () => _removeSavedAttachment(index),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                      ),
                      child: Text(
                        fileName.length > 10 ? '${fileName.substring(0, 7)}...' : fileName,
                        style: TextStyle(fontSize: 9, color: Colors.white),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              );
            }).toList()),
          ),
        // 新增的附件（未保存到DB）
        if (_mediaFiles.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_savedAttachments.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('待保存', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500)),
                  ),
                Wrap(spacing: 8, runSpacing: 8, children: _mediaFiles.asMap().entries.map<Widget>((entry) {
                  int index = entry.key;
                  File file = entry.value;
                  String type = _mediaTypes[index];
                  String fileSize = ImageUtils.formatFileSize(file.lengthSync());

                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200, width: 1.5),
                        ),
                        child: type == 'image'
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Container(color: Colors.grey.shade200, child: Icon(Icons.image, color: Colors.grey, size: 24))
                                  : Image.file(file, fit: BoxFit.cover, width: 80, height: 80))
                          : Container(
                              decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Icon(Icons.play_circle, color: Colors.white, size: 32))),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: GestureDetector(
                          onTap: () => _removeNewAttachment(index),
                          child: Container(
                            decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                          ),
                          child: Text(fileSize, style: TextStyle(fontSize: 9, color: Colors.white)),
                        ),
                      ),
                    ],
                  );
                }).toList()),
              ],
            ),
          ),
        if (_savedAttachments.isEmpty && _mediaFiles.isEmpty && !canEdit)
          Padding(
            padding: EdgeInsets.all(16),
            child: EmptyStatePlaceholder(icon: Icons.attach_file_rounded, message: '暂无附件', iconSize: 48),
          ),
      ],
    );
  }

  /// 已购买客户区块
  Widget _buildCustomersSection(AppState appState) {
    // Cache the Future to avoid recreating it on every rebuild (which would trigger new DB queries)
    _productCustomersFuture ??= _getProductCustomers(appState);
    return _buildGroupedSection(
      title: '已购买客户',
      children: [
        FutureBuilder<List<Customer>>(
          future: _productCustomersFuture,
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: Text('获取客户信息失败', style: TextStyle(color: Colors.grey)),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: EmptyStatePlaceholder(icon: Icons.people_outline_rounded, message: '暂无客户购买此产品', iconSize: 48),
              );
            }
            return Column(
              children: snapshot.data!.asMap().entries.map<Widget>((entry) {
                final index = entry.key;
                final customer = entry.value;
                final isLast = index == snapshot.data!.length - 1;
                return InkWell(
                  onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => CustomerDetailPage(customer: customer))),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Color(0xFF1565C0).withValues(alpha: 0.1),
                                child: Text(
                                  customer.name.isNotEmpty ? customer.name.substring(0, 1) : '?',
                                  style: TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                  Text(
                                    customer.phones.isNotEmpty ? customer.phones[0] : '无联系方式',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Padding(
                          padding: EdgeInsets.only(left: 44),
                          child: Divider(height: 1, thickness: 0.5),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildImageFallback(String filePath) {
    if (kIsWeb) {
      return Container(
        color: Colors.grey.shade200,
        child: Icon(Icons.broken_image, color: Colors.grey, size: 24),
      );
    }
    final file = File(filePath);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover, width: 80, height: 80);
    }
    return Container(
      color: Colors.grey.shade200,
      child: Icon(Icons.broken_image, color: Colors.grey, size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(isEditMode ? (_isEditing ? '编辑产品' : '产品详情') : '添加产品'),
        backgroundColor: Color(0xFF00897B),
        elevation: 0,
        actions: [
          if (isEditMode && !_isEditing)
            Row(children: [
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () => setState(() => _isEditing = true),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline),
                onPressed: () {
                  showDialog(context: context, builder: (dialogCtx) => AlertDialog(
                    title: Text('确认删除'),
                    content: Text('确定要删除这个产品吗？所有附件也将被删除。'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('取消')),
                      TextButton(onPressed: () async {
                        final navigator = Navigator.of(this.context);
                        await appState.deleteProduct(widget.product!.id!);
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        if (this.mounted) {
                          navigator.pop();
                        }
                      }, child: Text('删除', style: TextStyle(color: Colors.red))),
                    ],
                  ));
                },
              ),
            ],
          ),
          if (!isEditMode && _isEditing)
            TextButton(
              onPressed: _saveProduct,
              child: Text('保存', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          if (isEditMode && _isEditing)
            TextButton(
              onPressed: _saveProduct,
              child: Text('保存', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildProductHeader(),
              SizedBox(height: 4),
              _buildBasicInfoSection(),
              _buildDetailsSection(),
              _buildDateSection(),
              _buildMediaSection(),
              if (isEditMode) ...[
                _buildCustomersSection(appState),
              ],
              // 底部保存按钮
              if (_isEditing)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00897B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isEditMode ? '保存修改' : '添加产品',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
