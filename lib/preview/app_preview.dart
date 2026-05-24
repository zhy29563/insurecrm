import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/main.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/pages/customer_list_page.dart';
import 'package:insurance_manager/pages/product_list_page.dart';
import 'package:insurance_manager/pages/product_recommendation_page.dart';
import 'package:insurance_manager/pages/settings_page.dart';
import 'package:insurance_manager/pages/statistics_dashboard_page.dart';
import 'package:insurance_manager/pages/calendar_page.dart';
import 'package:insurance_manager/pages/customer_detail_page.dart';
import 'package:insurance_manager/pages/product_detail_page.dart';
import 'package:insurance_manager/pages/backup_restore_page.dart';
import 'package:insurance_manager/pages/notification_center_page.dart';
import 'package:insurance_manager/pages/colleague_management_page.dart';
import 'package:insurance_manager/pages/customer_grouping_page.dart';
import 'package:insurance_manager/pages/tag_filter_page.dart';
import 'package:insurance_manager/pages/tag_management_page.dart';
import 'package:insurance_manager/pages/splash_page.dart';

// ============================================================
// 预览辅助工具
// ============================================================

/// 完整应用预览（HomePage 用）
Widget _previewFullApp() => ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MyApp(),
    );

/// 单页预览包装器
Widget _previewPage(Widget page) => ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, _) => MaterialApp(
          title: '保险经纪人',
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: appState.darkMode ? ThemeMode.dark : ThemeMode.light,
          home: page,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

ThemeData get _lightTheme => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF1565C0),
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFE),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Color(0xFF1565C0),
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

ThemeData get _darkTheme => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF1565C0),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Color(0xFF1E1E1E),
      ),
    );

// ============================================================
// 主页面预览
// ============================================================

@Preview()
Widget homePagePreview() => _previewFullApp();

// ============================================================
// 客户相关页面预览
// ============================================================

@Preview()
Widget customerListPagePreview() =>
    _previewPage(const CustomerListPage());

@Preview()
Widget customerDetailPagePreview() =>
    _previewPage(const CustomerDetailPage());

@Preview()
Widget customerGroupingPagePreview() =>
    _previewPage(const CustomerGroupingPage());

// ============================================================
// 产品相关页面预览
// ============================================================

@Preview()
Widget productListPagePreview() => _previewPage(const ProductListPage());

@Preview()
Widget productDetailPagePreview() => _previewPage(const ProductDetailPage());

@Preview()
Widget productRecommendationPagePreview() =>
    _previewPage(const ProductRecommendationPage());

// ============================================================
// 功能页面预览
// ============================================================

@Preview()
Widget settingsPagePreview() => _previewPage(const SettingsPage());

@Preview()
Widget statisticsDashboardPagePreview() =>
    _previewPage(const StatisticsDashboardPage());

@Preview()
Widget calendarPagePreview() => _previewPage(const CalendarPage());

@Preview()
Widget backupRestorePagePreview() => _previewPage(const BackupRestorePage());

@Preview()
Widget notificationCenterPagePreview() =>
    _previewPage(const NotificationCenterPage());

@Preview()
Widget colleagueManagementPagePreview() =>
    _previewPage(const ColleagueManagementPage());

@Preview()
Widget tagFilterPagePreview() => _previewPage(const TagFilterPage());

@Preview()
Widget tagManagementPagePreview() => _previewPage(const TagManagementPage());

@Preview()
Widget splashPagePreview() => _previewPage(const SplashPage());
