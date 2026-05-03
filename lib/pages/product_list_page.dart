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

  void _navigateToProductDetail([Product? product]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
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

    if (_searchQuery.isEmpty) {
      _filteredProducts = List.from(appState.products);
    } else {
      _filteredProducts = appState.searchProducts(_searchQuery);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('产品管理'),
        actions: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_rounded, size: 20),
            ),
            onPressed: () => _navigateToProductDetail(),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: AppSearchBar(
              controller: _searchController,
              hintText: '搜索产品（名称、公司、分类）',
              onChanged: (value) {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(Duration(milliseconds: 300), () {
                  if (mounted) {
                    setState(() {
                      _searchQuery = value;
                    });
                  }
                });
              },
              onClear: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              searchQuery: _searchQuery,
            ),
          ),
          Expanded(
            child: appState.isDataLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                ? const EmptyStatePlaceholder(
                    icon: Icons.auto_stories_outlined,
                    message: '暂无产品数据',
                    actionHint: '点击右上角添加产品',
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(bottom: 20),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        child: _buildProductCard(context, product, isDark),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product, bool isDark) {
    final color = AppDesign.categoryColor(product.category);

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _navigateToProductDetail(product),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(Icons.shield_outlined, color: color, size: 26),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.business_rounded,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      product.company,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                if (product.category != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
}
