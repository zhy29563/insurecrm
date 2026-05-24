import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/models/customer.dart';
import 'package:insurance_manager/pages/customer_detail_page.dart';

import 'package:insurance_manager/widgets/app_components.dart';

class CustomerListPage extends StatefulWidget {
  final bool addMode;
  final bool visitMode;

  const CustomerListPage({
    super.key,
    this.addMode = false,
    this.visitMode = false,
  });

  @override
  _CustomerListPageState createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Customer> _filteredCustomers = [];
  String? _selectedTag;
  final List<String> _alphabet = [];
  final Map<String, List<Customer>> _groupedCustomers = {};
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};

  late AnimationController _animationController;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    if (widget.addMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navigateToCustomerDetail();
      });
    } else if (widget.visitMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请选择要拜访的客户'),
            duration: Duration(seconds: 2),
          ),
        );
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  void _navigateToCustomerDetail([Customer? customer]) async {
    if (!mounted) return;
    if (widget.visitMode && customer != null) {
      Navigator.pop(context, customer);
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailPage(customer: customer),
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
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    List<Customer> filtered;
    if (_searchQuery.isEmpty) {
      filtered = appState.customers;
    } else {
      filtered = appState.searchCustomers(_searchQuery);
    }

    if (_selectedTag != null) {
      filtered = filtered
          .where((c) => c.tagList.contains(_selectedTag))
          .toList();
    }

    if (!_listEquals(filtered, _filteredCustomers)) {
      _filteredCustomers = filtered;
      _groupCustomersSafe();
    }

    // ── 构建 Sliver 列表 ──
    final List<Widget> slivers = [
      // 渐变 AppBar
      _buildSliverAppBar(appState, primaryColor, isDark),

      // 搜索框
      _buildSearchSliver(),

      // 标签筛选
      ..._buildTagSliver(appState.allTags, primaryColor, isDark),

      // 列表 / 空状态 / 加载中
      _buildContentSliver(primaryColor),
    ];

    return Scaffold(body: CustomScrollView(slivers: slivers));
  }

  // ══════════════════════════════════
  //  Sliver 子组件
  // ══════════════════════════════════

  Widget _buildSliverAppBar(
    AppState appState,
    Color primaryColor,
    bool isDark,
  ) {
    return SliverAppBar(
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
                  ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
                  : [primaryColor.withValues(alpha: 0.85), primaryColor],
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
                          '客户管理',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '共 ${appState.customers.length} 位客户',
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
                      onTap: () => _navigateToCustomerDetail(),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add_rounded,
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
    );
  }

  Widget _buildSearchSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: AppSearchBar(
          controller: _searchController,
          hintText: '搜索客户（姓名、电话、地址）',
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
    );
  }

  List<Widget> _buildTagSliver(
    List<String> allTags,
    Color primaryColor,
    bool isDark,
  ) {
    if (allTags.isEmpty) return [];
    return [
      SliverToBoxAdapter(
        child: SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip(context, '全部', null, primaryColor, isDark),
              ...allTags.map<Widget>(
                (tag) =>
                    _buildFilterChip(context, tag, tag, primaryColor, isDark),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildContentSliver(Color primaryColor) {
    final appState = Provider.of<AppState>(context);

    if (appState.isDataLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_filteredCustomers.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyUI(primaryColor),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final letter = _alphabet[index];
          final customers = _groupedCustomers[letter] ?? [];
          return Column(
            key: _sectionKeys[letter],
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 字母分组标题
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withValues(alpha: 0.12),
                        primaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
              // 客户卡片
              ...customers.map<Widget>(
                (customer) => _AnimatedCard(
                  index: index * 100 + customers.indexOf(customer),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildDismissibleCard(
                      context,
                      customer,
                      Theme.of(context).brightness == Brightness.dark,
                      primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          );
        }, childCount: _alphabet.length),
      ),
    );
  }

  // ══════════════════════════════════
  //  UI 子组件
  // ══════════════════════════════════

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    String? value,
    Color primaryColor,
    bool isDark,
  ) {
    final selected = _selectedTag == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedTag = selected ? null : value),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? primaryColor
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
                        color: primaryColor.withValues(alpha: 0.25),
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

  Widget _buildEmptyUI(Color primaryColor) {
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
                  primaryColor.withValues(alpha: 0.12),
                  primaryColor.withValues(alpha: 0.03),
                ],
              ),
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: primaryColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty || _selectedTag != null
                ? '未找到匹配的客户'
                : '暂无客户数据',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedTag != null
                ? '尝试使用其他关键词或筛选条件'
                : '点击「添加」按钮创建第一位客户',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[450]),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(
    BuildContext context,
    Customer customer,
    bool isDark,
    Color primaryColor,
  ) {
    final ratingColor = AppDesign.ratingColor(customer.rating);
    final ratingLabel = AppDesign.ratingLabel(customer.rating);

    return GestureDetector(
      onTap: () => _navigateToCustomerDetail(customer),
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
            CustomerAvatar(name: customer.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          customer.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: _textPrimary(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ratingColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          ratingLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ratingColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 13,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          customer.phones.isNotEmpty
                              ? customer.phones[0]
                              : '暂无电话',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[550],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (customer.tagList.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: TagList(tags: customer.tagList),
                    ),
                ],
              ),
            ),
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
    Customer customer,
    bool isDark,
    Color primaryColor,
  ) {
    return Dismissible(
      key: ValueKey('customer_${customer.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('确认删除'),
                content: Text('确定要删除客户「${customer.name}」吗？\n此操作不可恢复。'),
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
        appState.deleteCustomer(customer.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除客户：${customer.name}'),
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
      child: _buildCustomerCard(context, customer, isDark, primaryColor),
    );
  }

  Color _textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1A1A2E);

  void _groupCustomersSafe() {
    _groupedCustomers.clear();
    _alphabet.clear();
    final oldSectionKeys = Map<String, GlobalKey>.from(_sectionKeys);
    _sectionKeys.clear();

    for (final customer in _filteredCustomers) {
      final firstLetter = customer.name.isNotEmpty
          ? customer.name.substring(0, 1).toUpperCase()
          : '#';
      if (!_groupedCustomers.containsKey(firstLetter)) {
        _groupedCustomers[firstLetter] = [];
        _alphabet.add(firstLetter);
        _sectionKeys[firstLetter] = oldSectionKeys[firstLetter] ?? GlobalKey();
      }
      _groupedCustomers[firstLetter]!.add(customer);
    }
    _alphabet.sort();
    _groupedCustomers.forEach((key, value) {
      value.sort((a, b) => a.name.compareTo(b.name));
    });
  }

  bool _listEquals(List<Customer> a, List<Customer> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}

// ════════════════════════════════════════════
//  卡片入场动画
// ════════════════════════════════════════════

class _AnimatedCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedCard({required this.index, required this.child});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
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
    Future.delayed(Duration(milliseconds: widget.index % 50 * 8 + 60), () {
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
