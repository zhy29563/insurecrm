import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';
import 'package:insurecrm/models/customer.dart';
import 'package:insurecrm/pages/customer_detail_page.dart';
import 'package:insurecrm/pages/customer_map_page.dart';

class CustomerListPage extends StatefulWidget {
  final bool addMode;
  final bool visitMode;

  CustomerListPage({this.addMode = false, this.visitMode = false});

  @override
  _CustomerListPageState createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Customer> _filteredCustomers = [];
  String? _selectedTag;
  List<String> _alphabet = [];
  Map<String, List<Customer>> _groupedCustomers = {};
  final ScrollController _scrollController = ScrollController();
  Map<String, GlobalKey> _sectionKeys = {};

  late AnimationController _animationController;
  late Animation<double> animation;

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
        _navigateToCustomerDetail();
      });
    } else if (widget.visitMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailPage(customer: customer),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    if (_searchQuery.isEmpty) {
      _filteredCustomers = appState.customers;
      _groupCustomers();
    } else {
      _filteredCustomers = appState.searchCustomers(_searchQuery);
      _groupCustomers();
    }

    // Apply tag filter
    if (_selectedTag != null) {
      _filteredCustomers = _filteredCustomers
          .where((c) => c.tagList.contains(_selectedTag))
          .toList();
      _groupCustomers();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('客户管理'),
        actions: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
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
                color: Colors.white.withOpacity(0.2),
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
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Color(0xFF2C2C2C) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: '搜索客户（姓名、电话、地址）',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: primaryColor,
                        size: 22,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
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
                              selectedColor: primaryColor.withOpacity(0.2),
                              checkmarkColor: primaryColor,
                            ),
                          ),
                          ...appState.allTags.map(
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
                                selectedColor: primaryColor.withOpacity(0.2),
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
                child: appState.isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredCustomers.isEmpty
                    ? FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0, 0.05),
                            end: Offset(0, 0),
                          ).animate(animation),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: 72,
                                  color: Colors.grey.shade300,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '暂无客户数据',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '点击右上角添加客户',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ],
                            ),
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
                                          .map(
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
                                          )
                                          .toList(),
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
                                      children: _alphabet.map((letter) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: Offset(0, 0.05),
                                              end: Offset(0, 0),
                                            ).animate(animation),
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _scrollToSection(letter),
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
    return GestureDetector(
      onTap: () => _navigateToCustomerDetail(customer),
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFF1565C0).withOpacity(0.1),
              child: Text(
                customer.name.substring(0, 1),
                style: TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  SizedBox(height: 3),
                  Text(
                    customer.phones.isNotEmpty ? customer.phones[0] : '暂无电话',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  if (customer.tagList.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: customer.tagList
                          .take(3)
                          .map<Widget>(
                            (tag) => Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFF1565C0).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getRatingColor(customer.rating).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getRatingText(customer.rating),
                style: TextStyle(
                  fontSize: 12,
                  color: _getRatingColor(customer.rating),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }

  void _groupCustomers() {
    _groupedCustomers.clear();
    _alphabet.clear();
    _sectionKeys.clear();

    for (var customer in _filteredCustomers) {
      String firstLetter = customer.name.isNotEmpty
          ? customer.name.substring(0, 1).toUpperCase()
          : '#';

      if (!_groupedCustomers.containsKey(firstLetter)) {
        _groupedCustomers[firstLetter] = [];
        _alphabet.add(firstLetter);
        _sectionKeys[firstLetter] = GlobalKey();
      }

      _groupedCustomers[firstLetter]!.add(customer);
    }

    _alphabet.sort();
    _groupedCustomers.forEach((key, value) {
      value.sort((a, b) => a.name.compareTo(b.name));
    });
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

  Color _getRatingColor(int? rating) {
    switch (rating) {
      case 5:
        return Color(0xFFE53935);
      case 4:
        return Color(0xFFFF9800);
      case 3:
        return Color(0xFFFDD835);
      case 2:
        return Color(0xFF43A047);
      case 1:
        return Color(0xFF42A5F5);
      default:
        return Colors.grey;
    }
  }

  String _getRatingText(int? rating) {
    switch (rating) {
      case 5:
        return '高意向';
      case 4:
        return '中高意向';
      case 3:
        return '中等意向';
      case 2:
        return '低意向';
      case 1:
        return '无意向';
      default:
        return '未评级';
    }
  }
}
