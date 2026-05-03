import 'package:flutter/material.dart';
import 'package:insurance_manager/pages/customer_detail_page.dart';
import 'package:insurance_manager/pages/customer_list_page.dart';
import 'package:insurance_manager/pages/product_list_page.dart';
import 'package:insurance_manager/pages/settings_page.dart';
import 'package:insurance_manager/pages/product_recommendation_page.dart';
import 'package:insurance_manager/pages/statistics_dashboard_page.dart';
import 'package:insurance_manager/pages/calendar_page.dart';
import 'package:insurance_manager/pages/customer_map_page.dart';
import 'package:insurance_manager/pages/notification_center_page.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/models/customer.dart';
import 'package:insurance_manager/widgets/app_components.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _HomeContent(),
      CustomerListPage(),
      ProductListPage(),
      SettingsPage(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = Provider.of<AppState>(context, listen: false);
      // loadTags is not called in initializeApp, ensure it's loaded
      appState.loadTags();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, '首页'),
                _buildNavItem(1, Icons.people_rounded, '客户'),
                _buildNavItem(2, Icons.auto_stories_rounded, '产品'),
                _buildNavItem(3, Icons.settings_rounded, '设置'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final primaryColor = Theme.of(context).primaryColor;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(20),
      splashColor: primaryColor.withValues(alpha: 0.1),
      highlightColor: primaryColor.withValues(alpha: 0.05),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? primaryColor : Colors.grey,
            ),
            if (isSelected) ...[
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}



class _HomeData {
  final int customerCount;
  final int productCount;
  final int colleagueCount;
  final int currentMonthNewCustomerCount;
  final List<Map<String, dynamic>> overdueReminders;
  final List<Map<String, dynamic>> systemNotifications;
  final List<Map<String, dynamic>> todayReminders;
  final List<Customer> customers;

  _HomeData({
    required this.customerCount,
    required this.productCount,
    required this.colleagueCount,
    required this.currentMonthNewCustomerCount,
    required this.overdueReminders,
    required this.systemNotifications,
    required this.todayReminders,
    required this.customers,
  });
}

class _HomeContent extends StatefulWidget {
  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  @override
  Widget build(BuildContext context) {
    // Use Selector to only rebuild when specific fields used by this widget change
    // This prevents unnecessary rebuilds when unrelated AppState properties change
    return Selector<AppState, _HomeData>(
      selector: (_, appState) => _HomeData(
        customerCount: appState.customers.length,
        productCount: appState.products.length,
        colleagueCount: appState.colleagues.length,
        currentMonthNewCustomerCount: appState.currentMonthNewCustomerCount,
        overdueReminders: appState.overdueReminders,
        systemNotifications: appState.systemNotifications,
        todayReminders: appState.todayReminders,
        customers: appState.customers,
      ),
      builder: (context, data, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return _buildContent(context, data, isDark);
      },
    );
  }

  Widget _buildContent(BuildContext context, _HomeData data, bool isDark) {
    final appState = Provider.of<AppState>(context, listen: false);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 56,
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: isDark ? Color(0xFF1E1E1E) : Color(0xFF0D47A1),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '保险经纪人',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationCenterPage(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      if (data.overdueReminders.isNotEmpty ||
                          data.systemNotifications.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(
                              minWidth: 8,
                              minHeight: 8,
                            ),
                            child: Text(
                              '${(data.overdueReminders.length + data.systemNotifications.length).clamp(1, 99)}',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [Color(0xFF1E1E1E), Color(0xFF2C2C2C), Color(0xFF37474F)]
                      : [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [Color(0xFF2C2C2C), Color(0xFF1E1E1E), Color(0xFF121212)]
                    : [Color(0xFF1976D2), Color(0xFFE3F2FD), Color(0xFFF8FAFE)],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
            padding: EdgeInsets.only(left: 20, right: 20, bottom: 10, top: 10),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.people_rounded,
                    title: '客户总数',
                    value: '${data.customerCount}',
                    gradient: LinearGradient(
                      colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.auto_stories_rounded,
                    title: '产品总数',
                    value: '${data.productCount}',
                    gradient: LinearGradient(
                      colors: [Color(0xFF26A69A), Color(0xFF00897B)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10), // 增加与上方统计卡片的间距
                // 统计卡片 - 第二行
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.handshake_rounded,
                        title: '同事数量',
                        value: '${data.colleagueCount}',
                        gradient: LinearGradient(
                          colors: [Color(0xFFAB47BC), Color(0xFF8E24AA)],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.trending_up_rounded,
                        title: '本月新增',
                        value: '${data.currentMonthNewCustomerCount}',
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF7043), Color(0xFFE64A19)],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // 快捷操作
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '快捷操作',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: [
                    _buildQuickAction(
                      context,
                      '添加客户',
                      Icons.person_add_rounded,
                      Color(0xFF42A5F5),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerListPage(addMode: true),
                        ),
                      ),
                    ),
                    _buildQuickAction(
                      context,
                      '添加产品',
                      Icons.add_circle_rounded,
                      Color(0xFF26A69A),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductListPage(addMode: true),
                        ),
                      ),
                    ),
                    _buildQuickAction(
                      context,
                      '客户地图',
                      Icons.map_rounded,
                      Color(0xFFFF7043),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CustomerMapPage()),
                      ),
                    ),
                    _buildQuickAction(
                      context,
                      '产品推荐',
                      Icons.recommend_rounded,
                      Color(0xFFAB47BC),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductRecommendationPage(),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32),
                // 数据看板入口
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StatisticsDashboardPage(),
                    ),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF1565C0).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '数据看板',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '销售业绩 · 客户分析 · 拜访统计',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
                SizedBox(height: 28),
                // 今日待办
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '今日待办',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (data.todayReminders.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(left: 8),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${data.todayReminders.where((r) => r['status'] == 'pending').length}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CalendarPage()),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Text(
                            '日历',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Theme.of(context).primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // 超期提醒
                if (data.overdueReminders.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Color(0xFFE53935).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Color(0xFFE53935).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color(0xFFE53935).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Color(0xFFE53935),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${data.overdueReminders.length}个超期未跟进',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE53935),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '请尽快处理超期提醒',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFE53935).withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // 今日待办列表
                if (data.todayReminders.isEmpty)
                  EmptyStatePlaceholder(
                    icon: Icons.check_circle_outline_rounded,
                    message: '今天暂无待办',
                    iconSize: 48,
                  )
                else
                  ...data.todayReminders
                      .take(3)
                      .map<Widget>((r) => _buildReminderItem(context, r, isDark)),
                SizedBox(height: 32),
                // 最近客户
                Text(
                  '最近客户',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                if (data.customers.isEmpty)
                  EmptyStatePlaceholder(
                    icon: Icons.people_outline_rounded,
                    message: '暂无客户数据',
                    actionHint: '点击上方"添加客户"开始',
                    iconSize: 48,
                  )
                else
                  ...data.customers
                      .take(3)
                      .map<Widget>((c) => _buildRecentCustomerItem(context, c)),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppDesign.cardBg(isDark),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildRecentCustomerItem(BuildContext context, Customer customer) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerDetailPage(customer: customer),
        ),
      ),
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

  Widget _buildReminderItem(
    BuildContext context,
    Map<String, dynamic> reminder,
    bool isDark,
  ) {
    final isCompleted = reminder['status'] == 'completed';
    final rType = reminder['type'] as String? ?? 'follow_up';

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              final appState = Provider.of<AppState>(context, listen: false);
              appState.updateReminderStatus(
                (reminder['id'] as num?)?.toInt() ?? -1,
                isCompleted ? 'pending' : 'completed',
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isCompleted ? Color(0xFF43A047) : Colors.transparent,
                border: Border.all(
                  color: isCompleted ? Color(0xFF43A047) : Colors.grey.shade400,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isCompleted
                  ? Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          SizedBox(width: 12),
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (AppDesign.reminderTypeColors[rType] ?? Color(0xFF78909C)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              AppDesign.reminderTypeIcons[rType] ?? Icons.event_rounded,
              size: 16,
              color: AppDesign.reminderTypeColors[rType] ?? Color(0xFF78909C),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder['title'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? Colors.grey : null,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${reminder['customer_name'] ?? ''} · ${reminder['reminder_time'] ?? '全天'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


