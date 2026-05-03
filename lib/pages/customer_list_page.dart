import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/models/customer.dart';
import 'package:insurance_manager/pages/customer_detail_page.dart';
import 'package:insurance_manager/pages/customer_map_page.dart';
import 'package:insurance_manager/widgets/app_components.dart';

class CustomerListPage extends StatefulWidget {
  final bool addMode;
  final bool visitMode;

  const CustomerListPage({super.key, this.addMode = false, this.visitMode = false});

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
  late Animation<double> animation;

  // Search debounce timer
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    if (widget.addMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navigateToCustomerDetail();
      });
    } else if (widget.visitMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请选择要拜访的客户'), duration: Duration(seconds: 2)),
        );
      });
    }

    // 启动动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  void _navigateToCustomerDetail([Customer? customer]) {
    if (!mounted) return;
    if (widget.visitMode && customer != null) {
      Navigator.pop(context, customer);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailPage(customer: customer),
      ),
    );
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

    // Compute filtered customers without side effects in build
    List<Customer> filtered;
    if (_searchQuery.isEmpty) {
      filtered = appState.customers;
    } else {
      filtered = appState.searchCustomers(_searchQuery);
    }

    // Apply tag filter
    if (_selectedTag != null) {
      filtered = filtered
          .where((c) => c.tagList.contains(_selectedTag))
          .toList();
    }

    // Only regroup if filtered results actually changed
    if (!_listEquals(filtered, _filteredCustomers)) {
      _filteredCustomers = filtered;
      _groupCustomersSafe();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('客户管理'),
        actions: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.map_rounded, size: 20),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CustomerMapPage()),
              );
            },
          ),
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_add_rounded, size: 20),
            ),
            onPressed: () => _navigateToCustomerDetail(),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, 0.05),
            end: Offset(0, 0),
          ).animate(animation),
          child: Column(
            children: [
              // 搜索框
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: AppSearchBar(
                  controller: _searchController,
                  hintText: '搜索客户（姓名、电话、地址）',
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
              // 标签筛选
              if (appState.allTags.isNotEmpty)
                FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, 0.05),
                      end: Offset(0, 0),
                    ).animate(animation),
                    child: Container(
                      height: 40,
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text('全部'),
                              selected: _selectedTag == null,
                              onSelected: (_) {
                                setState(() => _selectedTag = null);
                              },
                              selectedColor: primaryColor.withValues(alpha: 0.2),
                              checkmarkColor: primaryColor,
                            ),
                          ),
                          ...appState.allTags.map<Widget>(
                            (tag) => Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(tag),
                                selected: _selectedTag == tag,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedTag = _selectedTag == tag
                                        ? null
                                        : tag;
                                  });
                                },
                                selectedColor: primaryColor.withValues(alpha: 0.2),
                                checkmarkColor: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: appState.isDataLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredCustomers.isEmpty
                    ? FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0, 0.05),
                            end: Offset(0, 0),
                          ).animate(animation),
                          child: const EmptyStatePlaceholder(
                            icon: Icons.people_outline_rounded,
                            message: '暂无客户数据',
                            actionHint: '点击右上角添加客户',
                          ),
                        ),
                      )
                    : FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0, 0.05),
                            end: Offset(0, 0),
                          ).animate(animation),
                          child: Stack(
                            children: [
                              ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.only(bottom: 20),
                                itemCount: _alphabet.length,
                                itemBuilder: (context, index) {
                                  final letter = _alphabet[index];
                                  final customers =
                                      _groupedCustomers[letter] ?? [];

                                  return Column(
                                    key: _sectionKeys[letter],
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          20,
                                          16,
                                          20,
                                          6,
                                        ),
                                        child: FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: Offset(0, 0.05),
                                              end: Offset(0, 0),
                                            ).animate(animation),
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
                                      ),
                                      ...customers
                                          .map<Widget>(
                                            (customer) => FadeTransition(
                                              opacity: animation,
                                              child: SlideTransition(
                                                position: Tween<Offset>(
                                                  begin: Offset(0, 0.05),
                                                  end: Offset(0, 0),
                                                ).animate(animation),
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 4,
                                                  ),
                                                  child: _buildCustomerCard(
                                                    context,
                                                    customer,
                                                    isDark,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                    ],
                                  );
                                },
                              ),
                              // 侧边字母索引
                              Positioned(
                                right: 2,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: _alphabet.map<Widget>((letter) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: Offset(0, 0.05),
                                              end: Offset(0, 0),
                                            ).animate(animation),
                                            child: InkWell(
                                              onTap: () =>
                                                  _scrollToSection(letter),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Container(
                                                width: 24,
                                                height: 20,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  letter,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: primaryColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(
    BuildContext context,
    Customer customer,
    bool isDark,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _navigateToCustomerDetail(customer),
      child: Row(
        children: [
          CustomerAvatar(name: customer.name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  customer.phones.isNotEmpty ? customer.phones[0] : '暂无电话',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                if (customer.tagList.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  TagList(tags: customer.tagList),
                ],
              ],
            ),
          ),
          RatingBadge(rating: customer.rating),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  void _groupCustomersSafe() {
    _groupedCustomers.clear();
    _alphabet.clear();
    // 保留已有的 sectionKeys，只为新出现的字母创建 GlobalKey
    final oldSectionKeys = Map<String, GlobalKey>.from(_sectionKeys);
    _sectionKeys.clear();

    for (var customer in _filteredCustomers) {
      String firstLetter = customer.name.isNotEmpty
          ? customer.name.substring(0, 1).toUpperCase()
          : '#';

      if (!_groupedCustomers.containsKey(firstLetter)) {
        _groupedCustomers[firstLetter] = [];
        _alphabet.add(firstLetter);
        // 复用已有的 key，避免 GlobalKey 冲突
        _sectionKeys[firstLetter] = oldSectionKeys[firstLetter] ?? GlobalKey();
      }

      _groupedCustomers[firstLetter]!.add(customer);
    }

    _alphabet.sort();
    _groupedCustomers.forEach((key, value) {
      value.sort((a, b) => a.name.compareTo(b.name));
    });
  }

  /// Quick equality check for customer lists by comparing IDs
  bool _listEquals(List<Customer> a, List<Customer> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _scrollToSection(String letter) {
    final key = _sectionKeys[letter];
    if (key != null) {
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

}
