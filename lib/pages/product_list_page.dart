import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/models/product.dart';
import 'package:insurance_manager/pages/product_detail_page.dart';
import 'package:insurance_manager/widgets/app_components.dart';

class ProductListPage extends StatefulWidget {
  final bool addMode;

  const ProductListPage({super.key, this.addMode = false});

  @override
  _ProductListPageState createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Product> _filteredProducts = [];
  Timer? _debounceTimer;

  String? _selectedCategory;
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    if (widget.addMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _navigateToProductDetail();
      });
    }
  }

  void _navigateToProductDetail([Product? product]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
    if (widget.addMode && mounted && Navigator.of(context).canPop()) {
      Navigator.pop(context, result);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // 计算分类列表
    _categories =
        appState.products
            .map((p) => p.category)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();

    if (_searchQuery.isEmpty) {
      _filteredProducts = List.from(appState.products);
    } else {
      _filteredProducts = appState.searchProducts(_searchQuery);
    }
    // 分类过滤
    if (_selectedCategory != null) {
      _filteredProducts = _filteredProducts
          .where((p) => p.category == _selectedCategory)
          .toList();
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── 渐变 AppBar ──
          SliverAppBar(
            expandedHeight: 72,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
                        : [const Color(0xFF43A047), const Color(0xFF388E3C)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '产品管理',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '共 ${appState.products.length} 款产品',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: GestureDetector(
                            onTap: () => _navigateToProductDetail(),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '添加',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            titleTextStyle: const TextStyle(color: Colors.white, fontSize: 17),
            iconTheme: const IconThemeData(color: Colors.white, size: 24),
          ),

          // ── 搜索框 ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: AppSearchBar(
                controller: _searchController,
                hintText: '搜索产品（名称、公司、分类）',
                onChanged: (value) {
                  _debounceTimer?.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) setState(() => _searchQuery = value);
                  });
                },
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                searchQuery: _searchQuery,
              ),
            ),
          ),

          // ── 分类筛选 ──
          if (_categories.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildCategoryChip(
                      context,
                      '全部',
                      null,
                      const Color(0xFF43A047),
                      isDark,
                    ),
                    ..._categories.map<Widget>((cat) {
                      final catColor = AppDesign.categoryColor(cat);
                      return _buildCategoryChip(
                        context,
                        cat,
                        cat,
                        catColor,
                        isDark,
                      );
                    }),
                  ],
                ),
              ),
            ),

          // ── 列表 / 空状态 / 加载中 ──
          appState.isDataLoading
              ? const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _filteredProducts.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyUI(isDark),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = _filteredProducts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AnimatedProductCard(
                          index: index,
                          child: _buildDismissibleCard(
                            context,
                            product,
                            isDark,
                            primaryColor,
                          ),
                        ),
                      );
                    }, childCount: _filteredProducts.length),
                  ),
                ),
        ],
      ),
    );
  }

  /// 分类 Chip
  Widget _buildCategoryChip(
    BuildContext context,
    String label,
    String? value,
    Color chipColor,
    bool isDark,
  ) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              setState(() => _selectedCategory = selected ? null : value),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? chipColor
                  : (isDark ? Colors.grey[800]! : Colors.grey[100]!),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: chipColor.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : Colors.grey[500],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 空状态 UI
  Widget _buildEmptyUI(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF43A047).withValues(alpha: 0.12),
                  const Color(0xFF43A047).withValues(alpha: 0.03),
                ],
              ),
            ),
            child: Icon(
              Icons.auto_stories_outlined,
              size: 40,
              color: const Color(0xFF43A047).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != null
                ? '未找到匹配的产品'
                : '暂无产品数据',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != null
                ? '尝试使用其他关键词或切换分类'
                : '点击「添加」按钮创建第一款产品',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[450]),
          ),
        ],
      ),
    );
  }

  /// 产品卡片
  Widget _buildProductCard(
    BuildContext context,
    Product product,
    bool isDark,
    Color primaryColor,
  ) {
    final color = AppDesign.categoryColor(product.category);

    return GestureDetector(
      onTap: () => _navigateToProductDetail(product),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppDesign.cardBg(isDark),
          borderRadius: BorderRadius.circular(AppDesign.radiusCard),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200,
          ),
          boxShadow: [AppDesign.cardShadow(context)],
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.shield_outlined, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            // 信息列
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: _textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product.category != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              product.category!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.business_rounded,
                        size: 13,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          product.company,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[550],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 箭头
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.grey[350],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDismissibleCard(
    BuildContext context,
    Product product,
    bool isDark,
    Color primaryColor,
  ) {
    return Dismissible(
      key: ValueKey('product_${product.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('确认删除'),
                content: Text('确定要删除产品「${product.name}」吗？\n此操作不可恢复。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      '删除',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (direction) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.deleteProduct(product.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除产品：${product.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade600, Colors.red.shade400],
          ),
          borderRadius: BorderRadius.circular(AppDesign.radiusCard),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 22),
            SizedBox(width: 6),
            Text(
              '删除',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: _buildProductCard(context, product, isDark, primaryColor),
    );
  }

  Color _textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1A1A2E);
}

// ════════════════════════════════════════════
//  卡片入场动画
// ════════════════════════════════════════════

class _AnimatedProductCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedProductCard({required this.index, required this.child});

  @override
  State<_AnimatedProductCard> createState() => _AnimatedProductCardState();
}

class _AnimatedProductCardState extends State<_AnimatedProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.04, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 60 + 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(opacity: _fadeAnim, child: widget.child),
    );
  }
}
