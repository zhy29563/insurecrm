import 'package:flutter/material.dart';
import 'package:insurecrm/pages/customer_list_page.dart';
import 'package:insurecrm/pages/product_list_page.dart';
import 'package:insurecrm/pages/settings_page.dart';
import 'package:insurecrm/pages/product_recommendation_page.dart';
import 'package:insurecrm/pages/statistics_dashboard_page.dart';
import 'package:insurecrm/pages/calendar_page.dart';
import 'package:insurecrm/pages/customer_map_page.dart';
import 'package:insurecrm/pages/notification_center_page.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';

class HomePage extends StatefulWidget {
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
      final appState = Provider.of<AppState>(context, listen: false);
      appState.loadCustomers();
      appState.loadProducts();
      appState.loadColleagues();
      appState.loadSales();
      appState.loadStatistics();
      appState.loadReminders();
      appState.loadTags();
      appState.loadSystemNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
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

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.1)
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

class _HomeContent extends StatefulWidget {
  @override
  __HomeContentState createState() => __HomeContentState();
}

class __HomeContentState extends State<_HomeContent>
    with TickerProviderStateMixin {
  late AnimationController _greetingController;
  late AnimationController _statsController;
  late AnimationController _quickActionsController;
  late Animation<double> _greetingAnimation;
  late Animation<double> _statsAnimation;
  late Animation<double> _quickActionsAnimation;

  @override
  void initState() {
    super.initState();

    // 问候语动画
    _greetingController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _greetingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _greetingController, curve: Curves.easeOut),
    );

    // 统计卡片动画
    _statsController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _statsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _statsController,
        curve: Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    // 快捷操作动画
    _quickActionsController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _quickActionsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _quickActionsController,
        curve: Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // 延迟启动动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _greetingController.forward();
      _statsController.forward();
      _quickActionsController.forward();
    });
  }

  @override
  void dispose() {
    _greetingController.dispose();
    _statsController.dispose();
    _quickActionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: Color(0xFF0D47A1),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D47A1),
                    Color(0xFF1565C0),
                    Color(0xFF1E88E5),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '保险管理系统',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        NotificationCenterPage(),
                                  ),
                                );
                              },
                                child: Stack(
                                  children: [
                                    Icon(
                                      Icons.notifications_none_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    if (appState.overdueReminders.isNotEmpty ||
                                        appState.systemNotifications.isNotEmpty)
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
                                            '${(appState.overdueReminders.length + appState.systemNotifications.length).clamp(1, 99)}',
                                            style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
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
                      SizedBox(height: 16),
                      FadeTransition(
                        opacity: _greetingAnimation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(-0.1, 0),
                            end: Offset(0, 0),
                          ).animate(_greetingAnimation),
                          child: Text(
                            _getGreeting(),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      FadeTransition(
                        opacity: _greetingAnimation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(-0.1, 0),
                            end: Offset(0, 0),
                          ).animate(_greetingAnimation),
                          child: Text(
                            '今天也是充满机遇的一天',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(130),
            child: FadeTransition(
              opacity: _statsAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, 0.1),
                  end: Offset(0, 0),
                ).animate(_statsAnimation),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1976D2),
                        Color(0xFFE3F2FD),
                        Color(0xFFF8FAFE),
                      ],
                      stops: [0.0, 0.6, 1.0],
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 10,
                    top: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          icon: Icons.people_rounded,
                          title: '客户总数',
                          value: '${appState.customers.length}',
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
                          value: '${appState.products.length}',
                          gradient: LinearGradient(
                            colors: [Color(0xFF26A69A), Color(0xFF00897B)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                        value: '${appState.colleagues.length}',
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
                        value: '${appState.thisMonthNewCustomers}',
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF7043), Color(0xFFE64A19)],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32),
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
                FadeTransition(
                  opacity: _quickActionsAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, 0.1),
                      end: Offset(0, 0),
                    ).animate(_quickActionsAnimation),
                    child: GridView.count(
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
                            MaterialPageRoute(
                              builder: (_) => CustomerMapPage(),
                            ),
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
                  ),
                ),
                SizedBox(height: 32),
                // 数据看板入口
                FadeTransition(
                  opacity: _quickActionsAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, 0.1),
                      end: Offset(0, 0),
                    ).animate(_quickActionsAnimation),
                    child: GestureDetector(
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
                              color: Color(0xFF1565C0).withOpacity(0.3),
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
                                color: Colors.white.withOpacity(0.2),
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
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white.withOpacity(0.7),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 28),
                // 今日待办
                FadeTransition(
                  opacity: _quickActionsAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, 0.1),
                      end: Offset(0, 0),
                    ).animate(_quickActionsAnimation),
                    child: Row(
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
                            if (appState.todayReminders.isNotEmpty)
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
                                  '${appState.todayReminders.where((r) => r['status'] == 'pending').length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CalendarPage()),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '日历',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Color(0xFF1565C0),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),
                // 超期提醒
                if (appState.overdueReminders.isNotEmpty)
                  FadeTransition(
                    opacity: _quickActionsAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, 0.1),
                        end: Offset(0, 0),
                      ).animate(_quickActionsAnimation),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Color(0xFFE53935).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Color(0xFFE53935).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Color(0xFFE53935).withOpacity(0.15),
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
                                    '${appState.overdueReminders.length}个超期未跟进',
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
                                      color: Color(0xFFE53935).withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // 今日待办列表
                if (appState.todayReminders.isEmpty)
                  FadeTransition(
                    opacity: _quickActionsAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, 0.1),
                        end: Offset(0, 0),
                      ).animate(_quickActionsAnimation),
                      child: Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Color(0xFF2C2C2C)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 20,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '今天暂无待办',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...appState.todayReminders
                      .take(3)
                      .map(
                        (r) => FadeTransition(
                          opacity: _quickActionsAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, 0.1),
                              end: Offset(0, 0),
                            ).animate(_quickActionsAnimation),
                            child: _buildReminderItem(context, r, isDark),
                          ),
                        ),
                      ),
                SizedBox(height: 32),
                // 最近客户
                FadeTransition(
                  opacity: _quickActionsAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, 0.1),
                      end: Offset(0, 0),
                    ).animate(_quickActionsAnimation),
                    child: Text(
                      '最近客户',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                if (appState.customers.isEmpty)
                  FadeTransition(
                    opacity: _quickActionsAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, 0.1),
                        end: Offset(0, 0),
                      ).animate(_quickActionsAnimation),
                      child: Container(
                        padding: EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Color(0xFF2C2C2C)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '暂无客户数据',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '点击上方"添加客户"开始',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...appState.customers
                      .take(3)
                      .map(
                        (c) => FadeTransition(
                          opacity: _quickActionsAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, 0.1),
                              end: Offset(0, 0),
                            ).animate(_quickActionsAnimation),
                            child: _buildRecentCustomerItem(context, c),
                          ),
                        ),
                      ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
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
            color: gradient.colors.first.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.2),
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
              color: Colors.white.withOpacity(0.85),
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                color: color.withOpacity(0.12),
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
    );
  }

  Widget _buildRecentCustomerItem(BuildContext context, customer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 10),
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
            radius: 22,
            backgroundColor: Color(0xFF1565C0).withOpacity(0.1),
            child: Text(
              customer.name.substring(0, 1),
              style: TextStyle(
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.bold,
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
                SizedBox(height: 2),
                Text(
                  customer.phones.isNotEmpty ? customer.phones[0] : '暂无电话',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
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
        ],
      ),
    );
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

  Widget _buildReminderItem(
    BuildContext context,
    Map<String, dynamic> reminder,
    bool isDark,
  ) {
    final isCompleted = reminder['status'] == 'completed';
    final typeIcon = {
      'follow_up': Icons.phone_rounded,
      'visit': Icons.directions_walk_rounded,
      'renewal': Icons.autorenew_rounded,
      'birthday': Icons.cake_rounded,
      'other': Icons.event_rounded,
    };
    final typeColor = {
      'follow_up': Color(0xFF1E88E5),
      'visit': Color(0xFF43A047),
      'renewal': Color(0xFFFF9800),
      'birthday': Color(0xFFAB47BC),
      'other': Color(0xFF78909C),
    };

    final rType = reminder['type'] as String? ?? 'follow_up';

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final appState = Provider.of<AppState>(context, listen: false);
              appState.updateReminderStatus(
                reminder['id'] as int,
                isCompleted ? 'pending' : 'completed',
              );
            },
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
              color: (typeColor[rType] ?? Color(0xFF78909C)).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              typeIcon[rType] ?? Icons.event_rounded,
              size: 16,
              color: typeColor[rType] ?? Color(0xFF78909C),
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
