import 'dart:io' show File;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:insurance_manager/database/database_helper.dart';
import 'package:insurance_manager/models/customer.dart';
import 'package:insurance_manager/models/product.dart';
import 'package:insurance_manager/models/visit.dart';
import 'package:insurance_manager/models/colleague.dart';
import 'package:insurance_manager/models/sale.dart';
import 'package:insurance_manager/models/user.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:insurance_manager/services/backup_service.dart';
import 'package:insurance_manager/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  // ===== Authentication State =====
  User? currentUser;
  bool get isLoggedIn => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;

  List<Customer> customers = [];
  List<Product> products = [];
  List<Colleague> colleagues = [];
  List<Map<String, dynamic>> salesRecords = [];
  List<String> allTags = [];
  bool isDataLoading = false;
  bool darkMode = false;

  // 客户关系标签（可自定义）
  static const List<String> _defaultRelationshipLabels = ['家人', '朋友', '同事', '同学', '客户', '邻居', '其他'];
  List<String> _relationshipLabels = List.from(_defaultRelationshipLabels);
  List<String> get relationshipLabels => _relationshipLabels;

  // AI引擎配置 (AI = Artificial Intelligence, 人工智能)
  // category: 'asr' = 语音识别, 'chat' = 对话分析
  Map<String, dynamic> aiProviderConfigs = {
    'doubao': {'apiKey': '', 'enabled': false, 'category': 'chat'},
    'qianwen': {'apiKey': '', 'enabled': false, 'category': 'chat'},
  };

  // 统计数据
  List<Map<String, dynamic>> monthlySales = [];
  List<Map<String, dynamic>> monthlyVisits = [];
  List<Map<String, dynamic>> monthlyNewCustomers = [];
  List<Map<String, dynamic>> productRanking = [];
  List<Map<String, dynamic>> ratingDistribution = [];
  List<Map<String, dynamic>> reminders = [];
  List<Map<String, dynamic>> todayReminders = [];
  List<Map<String, dynamic>> overdueReminders = [];
  List<Map<String, dynamic>> systemNotifications = [];
  double totalSalesAmountAllTime = 0;
  int totalVisitsCountAllTime = 0;
  int currentMonthNewCustomerCount = 0;
  double currentMonthSalesAmount = 0;
  int currentMonthVisitsCount = 0;
  List<Map<String, dynamic>> quarterlySales = [];
  List<Map<String, dynamic>> annualSales = [];
  List<Map<String, dynamic>> monthlyCommissions = [];
  List<Map<String, dynamic>> quarterlyCommissions = [];
  List<Map<String, dynamic>> annualCommissions = [];
  List<Map<String, dynamic>> conversionFunnel = [];
  List<Map<String, dynamic>> visitEfficiency = [];

  bool _isSeedingSampleData = false;

  // 高德地图 API Key (AMap API Key)
  String _amapApiKey = '9899118f0feee8101d581461cd896476';
  String _amapApiKeyIOS = '';
  String get amapApiKey => _amapApiKey;
  String get amapApiKeyIOS => _amapApiKeyIOS;
  bool get hasAmapApiKey => _amapApiKey.isNotEmpty || _amapApiKeyIOS.isNotEmpty;

  // Load AMap API Key from SharedPreferences
  Future<void> loadAmapApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 兼容旧版本：先读取高德 key，若为空则读取旧的 Google Maps key
      _amapApiKey = prefs.getString('amap_api_key') ??
          prefs.getString('google_maps_api_key') ?? _amapApiKey;
      _amapApiKeyIOS = prefs.getString('amap_api_key_ios') ?? '';
      notifyListeners();
    } catch (e) {
      AppLogger.error('loading AMap API key: $e');
    }
  }

  // Save AMap Android API Key to SharedPreferences
  Future<void> setAmapApiKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key.isEmpty) {
        await prefs.remove('amap_api_key');
      } else {
        await prefs.setString('amap_api_key', key);
      }
      _amapApiKey = key;
      notifyListeners();
    } catch (e) {
      AppLogger.error('saving AMap API key: $e');
    }
  }

  // Save AMap iOS API Key to SharedPreferences
  Future<void> setAmapApiKeyIOS(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key.isEmpty) {
        await prefs.remove('amap_api_key_ios');
      } else {
        await prefs.setString('amap_api_key_ios', key);
      }
      _amapApiKeyIOS = key;
      notifyListeners();
    } catch (e) {
      AppLogger.error('saving AMap iOS API key: $e');
    }
  }

  // 加载关系标签
  Future<void> _loadRelationshipLabels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('relationship_labels');
      if (saved != null && saved.isNotEmpty) {
        _relationshipLabels = saved;
      }
    } catch (e) {
      AppLogger.error('loading relationship labels: $e');
    }
  }

  // 保存关系标签
  Future<void> _saveRelationshipLabels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('relationship_labels', _relationshipLabels);
    } catch (e) {
      AppLogger.error('saving relationship labels: $e');
    }
  }

  // 添加关系标签
  Future<void> addRelationshipLabel(String label) async {
    if (label.trim().isEmpty || _relationshipLabels.contains(label.trim())) return;
    _relationshipLabels.add(label.trim());
    await _saveRelationshipLabels();
    notifyListeners();
  }

  // 删除关系标签
  Future<void> removeRelationshipLabel(String label) async {
    _relationshipLabels.remove(label);
    await _saveRelationshipLabels();
    notifyListeners();
  }

  // 重置关系标签为默认
  Future<void> resetRelationshipLabels() async {
    _relationshipLabels = List.from(_defaultRelationshipLabels);
    await _saveRelationshipLabels();
    notifyListeners();
  }

  // Initialize app data (parallelized for performance)
  Future<void> initializeApp() async {
    try {
      // Load config data in parallel (lightweight)
      await Future.wait([
        loadAmapApiKey(),
        _loadRelationshipLabels(),
        _loadAIConfigs(),
      ]);

      // Load core data (customers first since others may depend on it)
      await loadCustomers();

      // Products, colleagues, sales can be loaded in parallel
      await Future.wait([
        loadProducts(),
        loadColleagues(),
        loadSales(),
      ]);

      // Load dependent data (reminders + statistics + notifications in parallel)
      await Future.wait([
        loadReminders(),
        loadStatistics(),
        loadSystemNotifications(),
      ]);

      // Auto backup check (non-blocking)
      if (!kIsWeb) {
        try {
          await BackupService.instance.runAutoBackupIfNeeded();
        } catch (e) {
          AppLogger.error('auto backup: $e');
        }
      }
    } catch (e) {
      AppLogger.error('initializing app: $e');
    }
  }

  // Load statistics (parallelized DB queries for performance)
  Future<void> loadStatistics() async {
    try {
      if (kIsWeb) {
        // Web platform: calculate from in-memory data
        _calculateInMemoryStatistics();
      } else {
        final db = DatabaseHelper.instance;
        final now = DateTime.now();
        final year = now.year;
        final thisMonth = now.month;

        // Run all 14+ DB queries in parallel
        final results = await Future.wait([
          db.getMonthlySalesSummary(year),
          db.getMonthlyVisitSummary(year),
          db.getMonthlyNewCustomerSummary(year),
          db.getProductSalesRanking(),
          db.getCustomerRatingDistribution(),
          db.getQuarterlySalesSummary(year),
          db.getAnnualSalesSummary(year),
          db.getMonthlyCommissionSummary(year),
          db.getQuarterlyCommissionSummary(year),
          db.getAnnualCommissionSummary(year),
          db.getConversionFunnelAnalysis(),
          db.getVisitEfficiencyAnalysis(),
          db.getAllTimeTotalSalesAmount(),
          db.getAllTimeTotalVisitsCount(),
        ]);

        monthlySales = results[0] as List<Map<String, dynamic>>;
        monthlyVisits = results[1] as List<Map<String, dynamic>>;
        monthlyNewCustomers = results[2] as List<Map<String, dynamic>>;
        productRanking = results[3] as List<Map<String, dynamic>>;
        ratingDistribution = results[4] as List<Map<String, dynamic>>;
        quarterlySales = results[5] as List<Map<String, dynamic>>;
        annualSales = results[6] as List<Map<String, dynamic>>;
        monthlyCommissions = results[7] as List<Map<String, dynamic>>;
        quarterlyCommissions = results[8] as List<Map<String, dynamic>>;
        annualCommissions = results[9] as List<Map<String, dynamic>>;
        final rawConversionFunnel = results[10] as List<Map<String, dynamic>>;
        visitEfficiency = results[11] as List<Map<String, dynamic>>;
        totalSalesAmountAllTime = (results[12] as num?)?.toDouble() ?? 0.0;
        totalVisitsCountAllTime = (results[13] as num?)?.toInt() ?? 0;

        // Conversion funnel with labels
        final ratingLabelMap = {0: '未评级', 1: '无意向', 2: '低意向', 3: '中意向', 4: '高意向', 5: '已成交'};
        conversionFunnel = rawConversionFunnel.map((item) {
          final count = (item['count'] as num?)?.toInt() ?? 0;
          return {
            ...item,
            'label': ratingLabelMap[item['rating']] ?? '未知',
            'percentage': customers.isNotEmpty ? (count / customers.length * 100) : 0.0,
          };
        }).toList();

        // This month specific (use firstWhere to avoid creating temporary lists)
        final thisMonthSalesEntry = monthlySales.cast<Map<String, dynamic>?>().firstWhere(
          (s) => s?['month'] == thisMonth,
          orElse: () => null,
        );
        currentMonthSalesAmount = thisMonthSalesEntry != null
            ? (thisMonthSalesEntry['total_amount'] as num?)?.toDouble() ?? 0
            : 0;

        final thisMonthVisitsEntry = monthlyVisits.cast<Map<String, dynamic>?>().firstWhere(
          (v) => v?['month'] == thisMonth,
          orElse: () => null,
        );
        currentMonthVisitsCount = thisMonthVisitsEntry != null
            ? (thisMonthVisitsEntry['count'] as num?)?.toInt() ?? 0
            : 0;

        final thisMonthCustomersEntry = monthlyNewCustomers.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['month'] == thisMonth,
          orElse: () => null,
        );
        currentMonthNewCustomerCount = thisMonthCustomersEntry != null
            ? (thisMonthCustomersEntry['count'] as num?)?.toInt() ?? 0
            : 0;
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error('loading statistics: $e');
    }
  }

  // Load reminders (parallelized DB queries for performance)
  Future<void> loadReminders() async {
    try {
      if (kIsWeb) {
        // Web: reminders not persisted, use empty list
        reminders = [];
        todayReminders = [];
        overdueReminders = [];
      } else {
        final db = DatabaseHelper.instance;
        // Run all 3 queries in parallel instead of sequentially
        final results = await Future.wait([
          db.getAllReminders(),
          db.getRemindersByDate(DateTime.now().toIso8601String().substring(0, 10)),
          db.getOverdueReminders(),
        ]);
        reminders = results[0] as List<Map<String, dynamic>>;
        todayReminders = results[1] as List<Map<String, dynamic>>;
        overdueReminders = results[2] as List<Map<String, dynamic>>;
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error('loading reminders: $e');
    }
  }

  // Load & generate system notifications
  Future<void> loadSystemNotifications() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final in30Days = today.add(Duration(days: 30));
      final notifications = <Map<String, dynamic>>[];

      // 1. 跟进到期提醒 (nextFollowUpDate is due or past)
      for (var c in customers) {
        if (c.nextFollowUpDate == null || c.nextFollowUpDate!.isEmpty) continue;
        final followUpDate = DateTime.tryParse(c.nextFollowUpDate!);
        if (followUpDate == null) continue;
        if (!followUpDate.isAfter(in30Days)) {
          String statusLabel;
          if (followUpDate.isBefore(today)) {
            statusLabel = '已超期';
          } else if (followUpDate.isBefore(today.add(Duration(days: 3)))) {
            statusLabel = '即将到期';
          } else {
            statusLabel = '近期到期';
          }
          notifications.add({
            'id': 'followup_${c.id}',
            'type': 'follow_up',
            'title': '跟进客户：${c.name}',
            'subtitle':
                '$statusLabel · 计划跟进日 ${c.nextFollowUpDate!.substring(5)}',
            'icon': Icons.phone_rounded,
            'color': Color(0xFFE53935),
            'time': c.nextFollowUpDate,
            'isUrgent': !followUpDate.isAfter(today.add(Duration(days: 7))),
          });
        }
      }

      // 2. 保单/产品到期提醒 (product endDate)
      for (var p in products) {
        if (p.salesEndDate == null || p.salesEndDate!.isEmpty) continue;
        final endDate = DateTime.tryParse(p.salesEndDate!);
        if (endDate == null) continue;
        if (!endDate.isAfter(in30Days)) {
          String statusLabel;
          if (endDate.isBefore(today)) {
            statusLabel = '已到期';
          } else if (endDate.isBefore(today.add(Duration(days: 14)))) {
            statusLabel = '即将到期';
          } else {
            statusLabel = '近期到期';
          }
          notifications.add({
            'id': 'policy_${p.id}',
            'type': 'policy_expiry',
            'title': '${p.company} - ${p.name} 保单到期',
            'subtitle': '$statusLabel · 到期日 ${p.salesEndDate!.substring(5)}',
            'icon': Icons.autorenew_rounded,
            'color': Color(0xFFFF9800),
            'time': p.salesEndDate,
            'isUrgent': !endDate.isAfter(today.add(Duration(days: 14))),
          });
        }
      }

      // 3. 客户生日提醒
      for (var c in customers) {
        if (c.birthday == null || c.birthday!.isEmpty) continue;
        final parts = c.birthday!.split('-');
        if (parts.length < 2) continue;

        final dayStr = parts.length >= 3
            ? (parts[2].length <= 2 ? parts[2] : parts[2].substring(0, 2))
            : '1';
        final dayNum = int.tryParse(dayStr) ?? 1;
        var birthdayCheck = DateTime(now.year, int.tryParse(parts[1]) ?? 1, dayNum);

        if (birthdayCheck.month < now.month ||
            (birthdayCheck.month == now.month && birthdayCheck.day < now.day)) {
          birthdayCheck = DateTime(
            now.year + 1,
            birthdayCheck.month,
            birthdayCheck.day,
          );
        }

        final daysUntilBirthday = birthdayCheck.difference(today).inDays;

        if (daysUntilBirthday >= 0 && daysUntilBirthday <= 30) {
          String label;
          if (daysUntilBirthday == 0) {
            label = '今天生日！';
          } else if (daysUntilBirthday <= 7) {
            label = '$daysUntilBirthday天后生日';
          } else {
            label = '$daysUntilBirthday天后生日';
          }
          notifications.add({
            'id': 'birthday_${c.id}_${now.year}',
            'type': 'birthday',
            'title': '${c.name} 的生日',
            'subtitle': '$label · ${c.birthday}',
            'icon': Icons.cake_rounded,
            'color': Color(0xFFAB47BC),
            'time': birthdayCheck.toIso8601String().substring(0, 10),
            'isUrgent': daysUntilBirthday <= 3,
            'customerId': c.id,
          });
        }
      }

      // Sort: urgent first, then by time
      notifications.sort((a, b) {
        final aUrgent = a['isUrgent'] as bool? ?? false;
        final bUrgent = b['isUrgent'] as bool? ?? false;
        if (aUrgent != bUrgent) return aUrgent ? -1 : 1;
        final aTime = a['time'] as String? ?? '';
        final bTime = b['time'] as String? ?? '';
        return aTime.compareTo(bTime);
      });

      systemNotifications = notifications;
      notifyListeners();
    } catch (e) {
      AppLogger.error('loading system notifications: $e');
    }
  }

  // ===== Authentication Methods =====

  /// Login with username/password. Returns (success, errorMessage).
  Future<(bool success, String message)> login(
    String username,
    String password,
  ) async {
    try {
      if (kIsWeb) {
        // Web: fallback to hardcoded for debug compatibility only
        if (kDebugMode && username == 'admin' && password == '123456') {
          currentUser = User(
            id: 0,
            username: 'admin',
            passwordHash: '',
            displayName: '系统管理员',
            role: 'admin',
          );
          notifyListeners();
          return (true, '');
        }
        return (false, '用户名或密码错误');
      }

      final db = DatabaseHelper.instance;
      final result = await db.validateLogin(username, password);
      if (result != null) {
        currentUser = User.fromMap(result);
        notifyListeners();
        return (true, '');
      }
      return (false, '用户名或密码错误');
    } catch (e) {
      AppLogger.error('during login: $e');
      return (false, '登录失败：$e');
    }
  }

  /// Register a new user
  Future<(bool success, String message)> register({
    required String username,
    required String displayName,
    required String password,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
    try {
      if (kIsWeb) {
        return (false, 'Web 模式暂不支持注册');
      }
      final db = DatabaseHelper.instance;
      return await db.registerUser(
        username: username,
        displayName: displayName,
        password: password,
        securityQuestion: securityQuestion,
        securityAnswer: securityAnswer,
      );
    } catch (e) {
      return (false, '注册失败：$e');
    }
  }

  /// Logout
  void logout() {
    currentUser = null;
    notifyListeners();
  }

  /// Reset password via security question
  Future<(bool success, String message)> resetPassword({
    required String username,
    required String securityAnswer,
    required String newPassword,
  }) async {
    if (kIsWeb) {
      return (false, 'Web 模式不支持密码重置');
    }
    final db = DatabaseHelper.instance;
    return await db.resetPassword(
      username: username,
      securityAnswer: securityAnswer,
      newPassword: newPassword,
    );
  }

  /// Get security question for a user
  Future<String?> getSecurityQuestion(String username) async {
    if (kIsWeb) return null;
    final db = DatabaseHelper.instance;
    Database database = await db.database;
    final results = await database.query(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username],
      columns: ['security_question'],
    );
    if (results.isNotEmpty) {
      return results.first['security_question'] as String?;
    }
    return null;
  }

  /// Change current user's password
  Future<(bool success, String message)> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (kIsWeb || currentUser == null) {
      return (false, '无法修改密码');
    }
    final db = DatabaseHelper.instance;
    return await db.changePassword(
      userId: currentUser!.id!,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  // Load all users (for admin)
  Future<List<Map<String, dynamic>>> loadAllUsers() async {
    if (kIsWeb) return [];
    final db = DatabaseHelper.instance;
    return await db.getAllUsers();
  }

  // Update user role (admin only)
  Future<void> updateUserRole(int userId, String newRole) async {
    if (kIsWeb) return;
    final db = DatabaseHelper.instance;
    await db.updateUserRole(userId, newRole);
  }

  // Add reminder
  Future<void> addReminder({
    required int customerId,
    required String title,
    String? description,
    required String reminderDate,
    String? reminderTime,
    String type = 'follow_up',
  }) async {
    try {
      if (kIsWeb) {
        final customerIndex = customers.indexWhere((c) => c.id == customerId);
        if (customerIndex == -1) return;
        final customer = customers[customerIndex];
        final maxId = reminders.fold(0, (max, r) {
          final id = (r['id'] as num?)?.toInt();
          return id != null && id > max ? id : max;
        });
        final newReminder = {
          'id': maxId + 1,
          'customer_id': customerId,
          'customer_name': customer.name,
          'title': title,
          'description': description,
          'reminder_date': reminderDate,
          'reminder_time': reminderTime,
          'type': type,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        };
        reminders.add(newReminder);
        final today = DateTime.now().toIso8601String().substring(0, 10);
        if (reminderDate == today) {
          todayReminders.add(newReminder);
        }
        // Also check if the reminder is overdue (past date)
        if (reminderDate.compareTo(today) < 0) {
          overdueReminders.add(newReminder);
        }
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.insertReminder({
          'customer_id': customerId,
          'title': title,
          'description': description,
          'reminder_date': reminderDate,
          'reminder_time': reminderTime,
          'type': type,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
        await loadReminders();
      }
    } catch (e) {
      AppLogger.error('adding reminder: $e');
    }
  }

  // Update reminder status
  Future<void> updateReminderStatus(int id, String status) async {
    try {
      if (kIsWeb) {
        final index = reminders.indexWhere((r) => r['id'] == id);
        if (index != -1) {
          reminders[index]['status'] = status;
        }
        final todayIndex = todayReminders.indexWhere((r) => r['id'] == id);
        if (todayIndex != -1) {
          if (status == 'completed' || status == 'dismissed') {
            todayReminders.removeAt(todayIndex);
          } else {
            todayReminders[todayIndex]['status'] = status;
          }
        }
        final overdueIndex = overdueReminders.indexWhere((r) => r['id'] == id);
        if (overdueIndex != -1) {
          if (status == 'completed' || status == 'dismissed') {
            overdueReminders.removeAt(overdueIndex);
          } else {
            overdueReminders[overdueIndex]['status'] = status;
          }
        }
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.updateReminder({'id': id, 'status': status});
        await loadReminders();
      }
    } catch (e) {
      AppLogger.error('updating reminder: $e');
    }
  }

  // Delete reminder
  Future<void> deleteReminder(int id) async {
    try {
      if (kIsWeb) {
        reminders.removeWhere((r) => r['id'] == id);
        todayReminders.removeWhere((r) => r['id'] == id);
        overdueReminders.removeWhere((r) => r['id'] == id);
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.deleteReminder(id);
        await loadReminders();
      }
    } catch (e) {
      AppLogger.error('deleting reminder: $e');
    }
  }

  void _calculateInMemoryStatistics() {
    final now = DateTime.now();
    final thisMonth = now.month;
    final thisYear = now.year;

    // Rating distribution from customers
    Map<int, int> ratingCounts = {};
    for (var c in customers) {
      final r = c.rating ?? 0;
      ratingCounts[r] = (ratingCounts[r] ?? 0) + 1;
    }
    ratingDistribution = ratingCounts.entries
        .map((e) => {'rating': e.key, 'count': e.value})
        .toList();
    ratingDistribution.sort(
      (a, b) => ((b['rating'] as num?) ?? 0).compareTo((a['rating'] as num?) ?? 0),
    );

    // New customers this month
    currentMonthNewCustomerCount = customers.where((c) {
      if (c.createdAt == null) return false;
      final dt = DateTime.tryParse(c.createdAt!);
      return dt != null && dt.month == thisMonth && dt.year == thisYear;
    }).length;

    // Monthly new customers
    Map<int, int> monthlyCounts = {};
    for (var c in customers) {
      if (c.createdAt == null) continue;
      final dt = DateTime.tryParse(c.createdAt!);
      if (dt != null && dt.year == thisYear) {
        monthlyCounts[dt.month] = (monthlyCounts[dt.month] ?? 0) + 1;
      }
    }
    monthlyNewCustomers =
        monthlyCounts.entries
            .map((e) => {'month': e.key, 'count': e.value})
            .toList()
          ..sort((a, b) => ((a['month'] as num?) ?? 0).compareTo((b['month'] as num?) ?? 0));

    // Sales and visits from in-memory data
    totalSalesAmountAllTime = salesRecords.fold(
      0.0,
      (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0),
    );
    totalVisitsCountAllTime = customers.fold(0, (sum, c) => sum + c.visits.length);
    currentMonthSalesAmount = salesRecords
        .where((saleRecord) {
          final saleDateStr = saleRecord['sale_date'] as String?;
          if (saleDateStr == null) return false;
          final saleDate = DateTime.tryParse(saleDateStr);
          return saleDate != null && saleDate.month == thisMonth && saleDate.year == thisYear;
        })
        .fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0));

    currentMonthVisitsCount = customers.fold(0, (sum, customer) {
      return sum +
          customer.visits.where((visitRecord) {
            final visitDateStr = visitRecord['date'] as String?;
            if (visitDateStr == null) return false;
            final visitDate = DateTime.tryParse(visitDateStr);
            return visitDate != null && visitDate.month == thisMonth && visitDate.year == thisYear;
          }).length;
    });

    // Product ranking from sales
    Map<int, int> productSaleCounts = {};
    Map<int, double> productSaleAmounts = {};
    for (var saleRecord in salesRecords) {
      final productId = (saleRecord['product_id'] as num?)?.toInt();
      if (productId == null) continue;
      productSaleCounts[productId] = (productSaleCounts[productId] ?? 0) + 1;
      productSaleAmounts[productId] =
          (productSaleAmounts[productId] ?? 0) +
          ((saleRecord['amount'] as num?)?.toDouble() ?? 0);
    }
    productRanking =
        productSaleCounts.entries.map((entry) {
          final product = products.firstWhere(
            (p) => p.id == entry.key,
            orElse: () => Product(company: '', name: 'Unknown'),
          );
          return {
            'product_name': product.name,
            'product_category': product.category ?? '',
            'sale_count': entry.value,
            'total_amount': productSaleAmounts[entry.key] ?? 0,
          };
        }).toList()..sort(
          (a, b) => ((b['sale_count'] as num?) ?? 0).compareTo((a['sale_count'] as num?) ?? 0),
        );

    // Monthly sales
    Map<int, double> monthlySalesMap = {};
    Map<int, int> monthlySalesCountMap = {};
    for (var saleRecord in salesRecords) {
      final saleDateStr = saleRecord['sale_date'] as String?;
      if (saleDateStr == null) continue;
      final saleDate = DateTime.tryParse(saleDateStr);
      if (saleDate != null && saleDate.year == thisYear) {
        monthlySalesMap[saleDate.month] =
            (monthlySalesMap[saleDate.month] ?? 0) +
            ((saleRecord['amount'] as num?)?.toDouble() ?? 0);
        monthlySalesCountMap[saleDate.month] =
            (monthlySalesCountMap[saleDate.month] ?? 0) + 1;
      }
    }
    monthlySales =
        monthlySalesMap.entries
            .map((entry) => {'month': entry.key, 'count': monthlySalesCountMap[entry.key] ?? 0, 'total_amount': entry.value})
            .toList()
          ..sort((a, b) => ((a['month'] as num?) ?? 0).compareTo((b['month'] as num?) ?? 0));

    // Monthly visits
    Map<int, int> monthlyVisitsMap = {};
    for (var customer in customers) {
      for (var visitRecord in customer.visits) {
        final visitDateStr = visitRecord['date'] as String?;
        if (visitDateStr == null) continue;
        final visitDate = DateTime.tryParse(visitDateStr);
        if (visitDate != null && visitDate.year == thisYear) {
          monthlyVisitsMap[visitDate.month] = (monthlyVisitsMap[visitDate.month] ?? 0) + 1;
        }
      }
    }
    monthlyVisits =
        monthlyVisitsMap.entries
            .map((e) => {'month': e.key, 'count': e.value})
            .toList()
          ..sort((a, b) => ((a['month'] as num?) ?? 0).compareTo((b['month'] as num?) ?? 0));

    // Quarterly sales
    Map<int, double> quarterlySalesMap = {};
    Map<int, int> quarterlySalesCountMap = {};
    for (var saleRecord in salesRecords) {
      final saleDateStr = saleRecord['sale_date'] as String?;
      if (saleDateStr == null) continue;
      final saleDate = DateTime.tryParse(saleDateStr);
      if (saleDate != null && saleDate.year == thisYear) {
        final q = ((saleDate.month - 1) ~/ 3) + 1;
        quarterlySalesMap[q] = (quarterlySalesMap[q] ?? 0) + ((saleRecord['amount'] as num?)?.toDouble() ?? 0);
        quarterlySalesCountMap[q] = (quarterlySalesCountMap[q] ?? 0) + 1;
      }
    }
    quarterlySales = quarterlySalesMap.entries
        .map((e) => {'quarter': e.key, 'count': quarterlySalesCountMap[e.key] ?? 0, 'total_amount': e.value})
        .toList()..sort((a, b) => ((a['quarter'] as num?) ?? 0).compareTo((b['quarter'] as num?) ?? 0));

    // Annual sales (only current year)
    final thisYearSales = salesRecords.where((s) {
      final d = DateTime.tryParse(s['sale_date'] as String? ?? '');
      return d != null && d.year == thisYear;
    }).toList();
    final thisYearSalesAmount = thisYearSales.fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0));
    annualSales = [{'year': thisYear, 'count': thisYearSales.length, 'total_amount': thisYearSalesAmount}];

    // Monthly commissions
    Map<int, double> monthlyCommMap = {};
    for (var saleRecord in salesRecords) {
      final saleDateStr = saleRecord['sale_date'] as String?;
      if (saleDateStr == null) continue;
      final saleDate = DateTime.tryParse(saleDateStr);
      final amount = (saleRecord['amount'] as num?)?.toDouble() ?? 0;
      final rate = (saleRecord['commission_rate'] as num?)?.toDouble() ?? 0;
      final commission = amount * rate / 100;
      if (saleDate != null && saleDate.year == thisYear) {
        monthlyCommMap[saleDate.month] = (monthlyCommMap[saleDate.month] ?? 0) + commission;
      }
    }
    monthlyCommissions = monthlyCommMap.entries
        .map((e) => {'month': e.key, 'total_commission': e.value})
        .toList()          ..sort((a, b) => ((a['month'] as num?) ?? 0).compareTo((b['month'] as num?) ?? 0));

    // Quarterly commissions
    Map<int, double> quarterlyCommMap = {};
    for (var saleRecord in salesRecords) {
      final saleDateStr = saleRecord['sale_date'] as String?;
      if (saleDateStr == null) continue;
      final saleDate = DateTime.tryParse(saleDateStr);
      final amount = (saleRecord['amount'] as num?)?.toDouble() ?? 0;
      final rate = (saleRecord['commission_rate'] as num?)?.toDouble() ?? 0;
      final commission = amount * rate / 100;
      if (saleDate != null && saleDate.year == thisYear) {
        final q = ((saleDate.month - 1) ~/ 3) + 1;
        quarterlyCommMap[q] = (quarterlyCommMap[q] ?? 0) + commission;
      }
    }
    quarterlyCommissions = quarterlyCommMap.entries
        .map((e) => {'quarter': e.key, 'total_commission': e.value})
        .toList()..sort((a, b) => ((a['quarter'] as num?) ?? 0).compareTo((b['quarter'] as num?) ?? 0));

    // Annual commissions (only current year)
    final thisYearCommission = thisYearSales.fold(0.0, (sum, s) {
      final amount = (s['amount'] as num?)?.toDouble() ?? 0;
      final rate = (s['commission_rate'] as num?)?.toDouble() ?? 0;
      return sum + amount * rate / 100;
    });
    annualCommissions = [{'year': thisYear, 'total_commission': thisYearCommission}];

    // Conversion funnel (based on customer ratings) - optimized with Set for O(N+M) instead of O(N*M)
    final ratingLabels = {0: '未评级', 1: '无意向', 2: '低意向', 3: '中意向', 4: '高意向', 5: '已成交'};
    final totalCustomers = customers.length;
    // Pre-compute Set of customer IDs that have sales for O(1) lookup
    final customerIdsWithSales = salesRecords
        .map((s) => (s['customer_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    conversionFunnel = ratingLabels.entries.map((e) {
      final count = customers.where((c) => (c.rating ?? 0) == e.key).length;
      final convertedInRating = customers.where((c) =>
          (c.rating ?? 0) == e.key &&
          customerIdsWithSales.contains(c.id)
      ).length;
      return {
        'rating': e.key,
        'label': e.value,
        'count': count,
        'percentage': totalCustomers > 0 ? (count / totalCustomers * 100) : 0.0,
        'conversion_rate': count > 0 ? (convertedInRating / count * 100) : 0.0,
      };
    }).toList();

    // Visit efficiency (converted = rating 5 "已成交")
    final totalVisitsAll = customers.fold(0, (sum, c) => sum + c.visits.length);
    final convertedCustomers = customers.where((c) => c.rating == 5).length;
    visitEfficiency = [{
      'total_visits': totalVisitsAll,
      'total_customers': totalCustomers,
      'converted_customers': convertedCustomers,
      'conversion_per_visit': totalVisitsAll > 0 ? convertedCustomers / totalVisitsAll * 100 : 0.0,
    }];
  }

  // Helper: load all customers from database with relations (batch query - eliminates N+1 problem)
  Future<List<Customer>> _loadCustomersFromDb(DatabaseHelper db) async {
    final customerMaps = await db.getAllCustomers();
    if (customerMaps.isEmpty) return [];

    // Batch load all customer-related data in 7 queries instead of 7*N queries
    final batchData = await db.batchLoadCustomerData();
    final phonesByCustomer = batchData['phones'] as Map<int, List<Map<String, dynamic>>>;
    final addressesByCustomer = batchData['addresses'] as Map<int, List<Map<String, dynamic>>>;
    final visitsByCustomer = batchData['visits'] as Map<int, List<Map<String, dynamic>>>;
    final tagsByCustomer = batchData['tags'] as Map<int, List<String>>;
    final photosByCustomer = batchData['photos'] as Map<int, List<String>>;
    final productsByCustomer = batchData['products'] as Map<int, List<Map<String, dynamic>>>;
    final relationsByCustomer = batchData['relations'] as Map<int, List<Map<String, dynamic>>>;

    final List<Customer> result = [];
    for (var map in customerMaps) {
      final customerId = map['id'] as int;
      final phones = (phonesByCustomer[customerId] ?? [])
          .map((e) => e['phone'] as String? ?? '')
          .where((p) => p.isNotEmpty)
          .toList();
      final addresses = (addressesByCustomer[customerId] ?? [])
          .map((e) => e['address'] as String? ?? '')
          .where((a) => a.isNotEmpty)
          .toList();
      final visits = visitsByCustomer[customerId] ?? [];
      final tags = tagsByCustomer[customerId] ?? [];
      final photoList = photosByCustomer[customerId] ?? [];
      final products = productsByCustomer[customerId] ?? [];
      final relationships = relationsByCustomer[customerId] ?? [];

      result.add(
        Customer.fromMap(
          map,
          phones: phones,
          addresses: addresses,
          visits: visits,
          products: products,
          relationships: relationships,
          persistentTagList: tags,
          persistentPhotoList: photoList,
        ),
      );
    }
    return result;
  }

  // Load all customers
  Future<void> loadCustomers() async {
    try {
      isDataLoading = true;

      if (kIsWeb) {
        // For web platform, use in-memory data
        if (customers.isEmpty && !_isSeedingSampleData && kDebugMode) {
          _isSeedingSampleData = true;
          await addSampleCustomers();
          _isSeedingSampleData = false;
        }
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        customers = await _loadCustomersFromDb(db);

        // 仅在 Debug 模式下添加示例客户数据（如果没有数据）
        if (customers.isEmpty && !_isSeedingSampleData && kDebugMode) {
          _isSeedingSampleData = true;
          await addSampleCustomers();
          _isSeedingSampleData = false;

          // 重新从数据库加载客户数据
          customers = await _loadCustomersFromDb(db);
        }
      }
    } catch (e) {
      AppLogger.error('loading customers: $e');
      // If error occurs, try adding sample data (debug only)
      if (customers.isEmpty && !_isSeedingSampleData && kDebugMode) {
        _isSeedingSampleData = true;
        try {
          await addSampleCustomers();
          // Reload from database after adding sample data
          if (!kIsWeb) {
            customers = await _loadCustomersFromDb(DatabaseHelper.instance);
          }
        } catch (_) {}
        _isSeedingSampleData = false;
      }
    } finally {
      isDataLoading = false;
      notifyListeners();
    }
  }

  // 添加示例客户数据（仅 Debug 模式）
  Future<void> addSampleCustomers() async {
    if (kIsWeb) {
      // Web平台：直接操作内存数据
      if (colleagues.isEmpty) {
        // 添加测试同事
        final testColleagues = [
          Colleague(name: '张三', phone: '13800138001', departmentAndRole: '销售经理'),
          Colleague(name: '李四', phone: '13800138002', departmentAndRole: '销售代表'),
          Colleague(name: '王五', phone: '13800138003', departmentAndRole: '市场专员'),
          Colleague(name: '赵六', phone: '13800138004', departmentAndRole: '客服经理'),
        ];

        for (int i = 0; i < testColleagues.length; i++) {
          testColleagues[i].id = i + 1;
          colleagues.add(testColleagues[i]);
        }
      }

      if (customers.isEmpty) {
        final now = DateTime.now();
        // 添加测试客户
        final sampleCustomers = [
          Customer(
            id: 1,
            name: '陈小明',
            alias: '小明',
            age: 35,
            gender: '男',
            rating: 5,
            phones: ['13900139001', '13900139002'],
            addresses: ['北京市朝阳区建国路88号'],
            latitude: 39.9042,
            longitude: 116.4074,
            tags: '高意向,重点客户',
            birthday: '1991-05-15',
            nextFollowUpDate:
                now.add(Duration(days: 2)).toIso8601String().substring(0, 10),
            createdAt:
                now.subtract(Duration(days: 15)).toIso8601String(),
          ),
          Customer(
            id: 2,
            name: '刘小红',
            alias: '小红',
            age: 28,
            gender: '女',
            rating: 4,
            phones: ['13900139003'],
            addresses: ['上海市浦东新区世纪大道100号'],
            latitude: 31.2304,
            longitude: 121.4737,
            tags: '中等意向',
            birthday: '1998-08-22',
            nextFollowUpDate:
                now.add(Duration(days: 7)).toIso8601String().substring(0, 10),
            createdAt:
                now.subtract(Duration(days: 10)).toIso8601String(),
          ),
          Customer(
            id: 3,
            name: '王大力',
            alias: '大力',
            age: 42,
            gender: '男',
            rating: 3,
            phones: ['13900139004'],
            addresses: ['广州市天河区天河路123号'],
            latitude: 23.1291,
            longitude: 113.2644,
            tags: '低意向',
            birthday: '1984-03-10',
            nextFollowUpDate:
                now.subtract(Duration(days: 3)).toIso8601String().substring(
                  0,
                  10,
                ),
            createdAt:
                now.subtract(Duration(days: 30)).toIso8601String(),
          ),
          Customer(
            id: 4,
            name: '张丽',
            alias: '丽丽',
            age: 30,
            gender: '女',
            rating: 5,
            phones: ['13900139005', '13900139006'],
            addresses: ['深圳市南山区科技园路1号'],
            latitude: 22.5431,
            longitude: 114.0579,
            tags: '高意向,VIP客户',
            birthday: '1996-11-08',
            nextFollowUpDate:
                now.add(Duration(days: 1)).toIso8601String().substring(0, 10),
            createdAt:
                now.subtract(Duration(days: 5)).toIso8601String(),
          ),
          Customer(
            id: 5,
            name: '李强',
            alias: '强哥',
            age: 38,
            gender: '男',
            rating: 4,
            phones: ['13900139007'],
            addresses: ['杭州市西湖区文二路100号'],
            latitude: 30.2741,
            longitude: 120.1551,
            tags: '中等意向,重点客户',
            birthday: '1988-07-25',
            nextFollowUpDate:
                now.add(Duration(days: 5)).toIso8601String().substring(0, 10),
            createdAt: now.toIso8601String(),
          ),
        ];

        customers.addAll(sampleCustomers);
      }

      notifyListeners();
    } else {
      // 移动平台：操作数据库
      final db = DatabaseHelper.instance;

      // 检查是否已有客户数据
      final existingCustomers = await db.getAllCustomers();
      if (existingCustomers.isEmpty) {
        try {
        final now = DateTime.now();

        // 添加测试客户（含birthday和next_follow_up_date）
        final sampleCustomers = [
          {
            'name': '陈小明',
            'alias': '小明',
            'age': 35,
            'gender': '男',
            'rating': 5,
            'latitude': 39.9042,
            'longitude': 116.4074,
            'tags': '高意向,重点客户',
            'birthday': '1991-05-15',
            'next_follow_up_date':
                now.add(Duration(days: 2)).toIso8601String().substring(0, 10),
            'created_at':
                now.subtract(Duration(days: 15)).toIso8601String(),
          },
          {
            'name': '刘小红',
            'alias': '小红',
            'age': 28,
            'gender': '女',
            'rating': 4,
            'latitude': 31.2304,
            'longitude': 121.4737,
            'tags': '中等意向',
            'birthday': '1998-08-22',
            'next_follow_up_date':
                now.add(Duration(days: 7)).toIso8601String().substring(0, 10),
            'created_at':
                now.subtract(Duration(days: 10)).toIso8601String(),
          },
          {
            'name': '王大力',
            'alias': '大力',
            'age': 42,
            'gender': '男',
            'rating': 3,
            'latitude': 23.1291,
            'longitude': 113.2644,
            'tags': '低意向',
            'birthday': '1984-03-10',
            'next_follow_up_date':
                now.subtract(Duration(days: 3)).toIso8601String().substring(
                  0,
                  10,
                ),
            'created_at':
                now.subtract(Duration(days: 30)).toIso8601String(),
          },
          {
            'name': '张丽',
            'alias': '丽丽',
            'age': 30,
            'gender': '女',
            'rating': 5,
            'latitude': 22.5431,
            'longitude': 114.0579,
            'tags': '高意向,VIP客户',
            'birthday': '1996-11-08',
            'next_follow_up_date':
                now.add(Duration(days: 1)).toIso8601String().substring(0, 10),
            'created_at':
                now.subtract(Duration(days: 5)).toIso8601String(),
          },
          {
            'name': '李强',
            'alias': '强哥',
            'age': 38,
            'gender': '男',
            'rating': 4,
            'latitude': 30.2741,
            'longitude': 120.1551,
            'tags': '中等意向,重点客户',
            'birthday': '1988-07-25',
            'next_follow_up_date':
                now.add(Duration(days: 5)).toIso8601String().substring(0, 10),
            'created_at': now.toIso8601String(),
          },
        ];

        // 客户联系方式
        final customerPhones = [
          ['13900139001', '13900139002'], // 陈小明
          ['13900139003'], // 刘小红
          ['13900139004'], // 王大力
          ['13900139005', '13900139006'], // 张丽
          ['13900139007'], // 李强
        ];

        // 客户地址
        final customerAddresses = [
          ['北京市朝阳区建国路88号'], // 陈小明
          ['上海市浦东新区世纪大道100号'], // 刘小红
          ['广州市天河区天河路123号'], // 王大力
          ['深圳市南山区科技园路1号'], // 张丽
          ['杭州市西湖区文二路100号'], // 李强
        ];

        // 插入客户数据并收集ID
        final customerIds = <int>[];
        for (int i = 0; i < sampleCustomers.length; i++) {
          final customerId = await db.insertCustomer(sampleCustomers[i]);
          customerIds.add(customerId);

          for (final phone in customerPhones[i]) {
            await db.insertCustomerPhone(customerId, phone);
          }
          for (final address in customerAddresses[i]) {
            await db.insertCustomerAddress(customerId, address);
          }
        }

        // 确保产品数据存在
        final existingProducts = await db.getAllProducts();
        if (existingProducts.isEmpty) {
          final sampleProducts = [
            {
              'company': '平安保险',
              'name': '平安福重疾险',
              'description': '涵盖100种重疾和50种轻症，保障全面',
              'advantages': '保障范围广，理赔速度快',
              'category': '重疾险',
              'start_date': '2026-01-01',
              'end_date': '2026-12-31',
              'created_at': now.toIso8601String(),
            },
            {
              'company': '太平洋保险',
              'name': '太平洋健康险',
              'description': '提供全面的健康保障',
              'advantages': '保障全面，保费合理',
              'category': '健康险',
              'start_date': '2026-01-01',
              'end_date': '2026-12-31',
              'created_at': now.toIso8601String(),
            },
            {
              'company': '中国人寿',
              'name': '国寿养老险',
              'description': '为老年人提供稳定的养老保障',
              'advantages': '收益稳定，安全可靠',
              'category': '养老险',
              'start_date': '2026-01-01',
              'end_date': '2026-12-31',
              'created_at': now.toIso8601String(),
            },
            {
              'company': '人保财险',
              'name': '人保车险',
              'description': '为车辆提供全面的保险保障',
              'advantages': '理赔速度快，服务好',
              'category': '财产险',
              'start_date': '2026-01-01',
              'end_date': '2026-12-31',
              'created_at': now.toIso8601String(),
            },
            {
              'company': '泰康人寿',
              'name': '泰康年金险',
              'description': '提供稳定的年金收益',
              'advantages': '收益稳定，安全可靠',
              'category': '年金险',
              'start_date': '2026-01-01',
              'end_date': '2026-12-31',
              'created_at': now.toIso8601String(),
            },
          ];
          for (final product in sampleProducts) {
            await db.insertProduct(product);
          }
        }

        // 确保同事数据存在
        final existingColleagues = await db.getAllColleagues();
        if (existingColleagues.isEmpty) {
          final testColleagues = [
            {'name': '张三', 'phone': '13800138001', 'specialty': '销售经理'},
            {'name': '李四', 'phone': '13800138002', 'specialty': '销售代表'},
            {'name': '王五', 'phone': '13800138003', 'specialty': '市场专员'},
            {'name': '赵六', 'phone': '13800138004', 'specialty': '客服经理'},
          ];
          for (final colleague in testColleagues) {
            await db.insertColleague(colleague);
          }
        }

        // 获取产品和同事ID用于关联
        final productMaps = await db.getAllProducts();
        final colleagueMaps = await db.getAllColleagues();
        final productIds = productMaps.map((p) => (p['id'] as num?)?.toInt() ?? 0).toList();

        // 添加示例拜访记录
        final sampleVisits = [
          {
            'customer_id': customerIds[0],
            'date':
                now.subtract(Duration(days: 5)).toIso8601String().substring(
                  0,
                  10,
                ),
            'location': '北京办公室',
            'accompanying_persons': '张三',
            'introduced_products': '平安福重疾险',
            'interested_products': '平安福重疾险',
            'notes': '客户对重疾险很感兴趣，希望了解更多细节',
          },
          {
            'customer_id': customerIds[0],
            'date':
                now.subtract(Duration(days: 20)).toIso8601String().substring(
                  0,
                  10,
                ),
            'location': '客户家中',
            'notes': '初次拜访，了解客户需求',
          },
          {
            'customer_id': customerIds[1],
            'date':
                now.subtract(Duration(days: 3)).toIso8601String().substring(
                  0,
                  10,
                ),
            'location': '上海办公室',
            'introduced_products': '太平洋健康险',
            'notes': '客户对健康险有兴趣，需要进一步跟进',
          },
          {
            'customer_id': customerIds[3],
            'date':
                now.subtract(Duration(days: 1)).toIso8601String().substring(
                  0,
                  10,
                ),
            'location': '深圳咖啡厅',
            'accompanying_persons': '李四',
            'introduced_products': '太平洋健康险,国寿养老险',
            'interested_products': '太平洋健康险',
            'notes': 'VIP客户，对健康险和养老险都有兴趣',
          },
          {
            'customer_id': customerIds[4],
            'date':
                now.subtract(Duration(days: 8)).toIso8601String().substring(
                  0,
                  10,
                ),
            'location': '杭州茶馆',
            'notes': '客户正在考虑养老规划',
          },
        ];
        for (final visit in sampleVisits) {
          await db.insertVisit(visit);
        }

        // 添加示例销售记录
        if (productIds.isNotEmpty) {
          final sampleSales = [
            {
              'customer_id': customerIds[0],
              'product_id': productIds[0],
              'amount': 50000.0,
              'notes': '购买平安福重疾险，保额50万',
              'sale_date':
                  now.subtract(Duration(days: 3)).toIso8601String().substring(
                    0,
                    10,
                  ),
              'colleague_id': colleagueMaps.isNotEmpty
                  ? colleagueMaps[0]['id']
                  : null,
              'commission_rate': 8.5,
            },
            {
              'customer_id': customerIds[3],
              'product_id': productIds.length > 1 ? productIds[1] : productIds[0],
              'amount': 8000.0,
              'notes': '购买太平洋健康险，年缴保费8000元',
              'sale_date':
                  now.subtract(Duration(days: 1)).toIso8601String().substring(
                    0,
                    10,
                  ),
              'colleague_id': colleagueMaps.length > 1
                  ? colleagueMaps[1]['id']
                  : null,
              'commission_rate': 5.0,
            },
            {
              'customer_id': customerIds[4],
              'product_id': productIds.length > 2 ? productIds[2] : productIds[0],
              'amount': 120000.0,
              'notes': '购买国寿养老险，年缴保费12万',
              'sale_date': now.toIso8601String().substring(0, 10),
              'colleague_id': colleagueMaps.isNotEmpty
                  ? colleagueMaps[0]['id']
                  : null,
              'commission_rate': 3.0,
            },
          ];
          for (final sale in sampleSales) {
            await db.insertSale(sale);
          }
        }

        // 添加示例提醒
        final sampleReminders = [
          {
            'customer_id': customerIds[0],
            'title': '跟进陈小明 - 重疾险方案',
            'description': '发送详细的重疾险保障方案',
            'reminder_date':
                now.add(Duration(days: 2)).toIso8601String().substring(0, 10),
            'reminder_time': '10:00',
            'type': 'follow_up',
            'status': 'pending',
            'created_at': now.toIso8601String(),
          },
          {
            'customer_id': customerIds[3],
            'title': '张丽 - 健康险方案讲解',
            'description': '上门讲解太平洋健康险方案',
            'reminder_date': now.toIso8601String().substring(0, 10),
            'reminder_time': '14:00',
            'type': 'visit',
            'status': 'pending',
            'created_at': now.toIso8601String(),
          },
          {
            'customer_id': customerIds[2],
            'title': '跟进王大力 - 续保提醒',
            'description': '车险即将到期，提醒续保',
            'reminder_date':
                now.subtract(Duration(days: 3)).toIso8601String().substring(
                  0,
                  10,
                ),
            'type': 'renewal',
            'status': 'pending',
            'created_at': now.toIso8601String(),
          },
          {
            'customer_id': customerIds[1],
            'title': '刘小红 - 健康险跟进',
            'description': '跟进健康险意向，发送产品资料',
            'reminder_date':
                now.add(Duration(days: 7)).toIso8601String().substring(0, 10),
            'reminder_time': '09:00',
            'type': 'follow_up',
            'status': 'pending',
            'created_at': now.toIso8601String(),
          },
          {
            'customer_id': customerIds[4],
            'title': '李强 - 养老规划回访',
            'description': '回访养老规划需求',
            'reminder_date':
                now.add(Duration(days: 5)).toIso8601String().substring(0, 10),
            'type': 'follow_up',
            'status': 'pending',
            'created_at': now.toIso8601String(),
          },
        ];
        for (final reminder in sampleReminders) {
          await db.insertReminder(reminder);
        }

        // 添加示例客户-产品关联
        if (productIds.isNotEmpty) {
          final sampleCustomerProducts = [
            {
              'customer_id': customerIds[0],
              'product_id': productIds[0],
              'purchase_date':
                  now.subtract(Duration(days: 3)).toIso8601String().substring(
                    0,
                    10,
                  ),
            },
            {
              'customer_id': customerIds[3],
              'product_id':
                  productIds.length > 1 ? productIds[1] : productIds[0],
              'purchase_date':
                  now.subtract(Duration(days: 1)).toIso8601String().substring(
                    0,
                    10,
                  ),
            },
            {
              'customer_id': customerIds[4],
              'product_id':
                  productIds.length > 2 ? productIds[2] : productIds[0],
              'purchase_date': now.toIso8601String().substring(0, 10),
            },
          ];
          for (final customerProductEntry in sampleCustomerProducts) {
            await db.insertCustomerProduct(customerProductEntry);
          }
        }

        // 添加示例客户关系
        if (customerIds.length >= 5) {
          final sampleRelationships = [
            {
              'customer_id': customerIds[0],
              'related_customer_id': customerIds[1],
              'relationship': '朋友',
            },
            {
              'customer_id': customerIds[3],
              'related_customer_id': customerIds[4],
              'relationship': '同事',
            },
          ];
          for (final rel in sampleRelationships) {
            await db.insertCustomerRelationship(rel);
          }
        }

        // 添加示例客户标签（到customer_tags表）
        final sampleTags = [
          {'customer_id': customerIds[0], 'tags': ['高意向', '重点客户']},
          {'customer_id': customerIds[1], 'tags': ['中等意向']},
          {'customer_id': customerIds[2], 'tags': ['低意向']},
          {'customer_id': customerIds[3], 'tags': ['高意向', 'VIP客户']},
          {'customer_id': customerIds[4], 'tags': ['中等意向', '重点客户']},
        ];
        for (final tagEntry in sampleTags) {
          for (final tag in (tagEntry['tags'] as List?)?.cast<String>() ?? <String>[]) {
            await db.insertCustomerTag((tagEntry['customer_id'] as num?)?.toInt() ?? 0, tag);
          }
        }
        } catch (e) {
          AppLogger.error('adding sample customers (mobile): $e');
        }
      }
    }
  }

  // Add customer
  Future<void> addCustomer(Customer customer) async {
    try {
      if (kIsWeb) {
        // For web platform, add to in-memory list
        final maxId = customers.fold(
          0,
          (max, c) => c.id != null && c.id! > max ? c.id! : max,
        );
        final newCustomer = Customer(
          id: maxId + 1,
          name: customer.name,
          alias: customer.alias,
          age: customer.age,
          gender: customer.gender,
          rating: customer.rating,
          latitude: customer.latitude,
          longitude: customer.longitude,
          address: customer.address,
          phones: List<String>.from(customer.phones),
          addresses: List<String>.from(customer.addresses),
          visits: List<Map<String, dynamic>>.from(customer.visits),
          products: List<Map<String, dynamic>>.from(customer.products),
          relationships: List<Map<String, dynamic>>.from(customer.relationships),
          birthday: customer.birthday,
          tags: customer.tags,
          photos: customer.photos,
          nextFollowUpDate: customer.nextFollowUpDate,
          createdAt: customer.createdAt ?? DateTime.now().toIso8601String(),
          persistentTagList: List<String>.from(customer.persistentTagList),
          persistentPhotoList: List<String>.from(customer.persistentPhotoList),
          wechatId: customer.wechatId,
          idCardNumber: customer.idCardNumber,
          occupation: customer.occupation,
          source: customer.source,
          notes: customer.notes,
          purchaseIntentionLevel: customer.purchaseIntentionLevel,
        );
        customers.add(newCustomer);
        // Update allTags with any new tags from this customer
        for (var tag in newCustomer.tagList) {
          if (!allTags.contains(tag)) {
            allTags.add(tag);
          }
        }
        allTags.sort();
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        final map = customer.toMap()..remove('id');
        final id = await db.insertCustomer(map);

        // Insert phones
        for (var phone in customer.phones) {
          await db.insertCustomerPhone(id, phone);
        }

        // Insert addresses
        for (var address in customer.addresses) {
          await db.insertCustomerAddress(id, address);
        }

        // Insert photos
        for (var photoPath in customer.persistentPhotoList) {
          await db.insertCustomerPhoto({
            'customer_id': id,
            'file_path': photoPath,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        // Insert tags (use tagList which covers both persistentTagList and tags field)
        for (var tag in customer.tagList) {
          await db.insertCustomerTag(id, tag);
        }

        await loadCustomers();
        await loadTags(); // Tags depend on customer data, run after
      }
    } catch (e) {
      AppLogger.error('adding customer: $e');
    }
  }

  // Update customer
  Future<void> updateCustomer(Customer customer) async {
    try {
      if (kIsWeb) {
        final index = customers.indexWhere((c) => c.id == customer.id);
        if (index != -1) {
          customers[index] = customer;
          // Refresh allTags since customer tags may have changed
          allTags = customers.expand((c) => c.tagList).toSet().toList()..sort();
          _calculateInMemoryStatistics();
          notifyListeners();
        }
      } else {
        final db = DatabaseHelper.instance;
        final dbInstance = await db.database;

        // Query old photos before transaction to clean up orphaned files later
        List<String> oldPhotoPaths = [];
        try {
          final oldPhotos = await dbInstance.query(
            'customer_photos',
            where: 'customer_id = ?',
            whereArgs: [customer.id],
          );
          for (var p in oldPhotos) {
            final fp = p['file_path'] as String?;
            if (fp != null) oldPhotoPaths.add(fp);
          }
        } catch (_) {}

        await dbInstance.transaction((txn) async {
          // Update customer record (exclude 'id' from SET clause)
          final customerMap = customer.toMap()..remove('id');
          await txn.update(
            DatabaseHelper.tableCustomers,
            customerMap,
            where: 'id = ?',
            whereArgs: [customer.id],
          );

          // Sync phones: delete old, insert new
          await txn.delete(
            'customer_phones',
            where: 'customer_id = ?',
            whereArgs: [customer.id],
          );
          for (var phone in customer.phones) {
            await txn.insert('customer_phones', {
              'customer_id': customer.id,
              'phone': phone,
            });
          }

          // Sync addresses: delete old, insert new
          await txn.delete(
            'customer_addresses',
            where: 'customer_id = ?',
            whereArgs: [customer.id],
          );
          for (var address in customer.addresses) {
            await txn.insert('customer_addresses', {
              'customer_id': customer.id,
              'address': address,
            });
          }

          // Sync photos: delete old, insert new
          await txn.delete(
            'customer_photos',
            where: 'customer_id = ?',
            whereArgs: [customer.id],
          );
          for (var photoPath in customer.persistentPhotoList) {
            await txn.insert('customer_photos', {
              'customer_id': customer.id,
              'file_path': photoPath,
              'created_at': DateTime.now().toIso8601String(),
            });
          }

          // Sync tags: delete old, insert new
          await txn.delete(
            'customer_tags',
            where: 'customer_id = ?',
            whereArgs: [customer.id],
          );
          for (var tag in customer.tagList) {
            // Sync tags definition table
            await txn.insert('tags', {
              'name': tag,
              'created_at': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            await txn.insert('customer_tags', {
              'customer_id': customer.id,
              'tag': tag,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        });

        // Delete orphaned photo files that are no longer in the new photo list
        for (final oldPath in oldPhotoPaths) {
          if (!customer.persistentPhotoList.contains(oldPath)) {
            try { await File(oldPath).delete(); } catch (_) {}
          }
        }

        await loadCustomers();
        await Future.wait([
          loadTags(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('updating customer: $e');
    }
  }

  // Delete customer
  Future<void> deleteCustomer(int id) async {
    try {
      if (kIsWeb) {
        // Also clean up orphaned sales records for this customer
        salesRecords.removeWhere((s) => (s['customer_id'] as num?)?.toInt() == id);
        customers.removeWhere((c) => c.id == id);
        // Rebuild allTags from remaining customers
        allTags = customers.expand((c) => c.tagList).toSet().toList()..sort();
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.deleteCustomer(id);
        await loadCustomers();
        await Future.wait([
          loadTags(),
          loadSales(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('deleting customer: $e');
    }
  }

  // Load all products
  Future<void> loadProducts() async {
    isDataLoading = true;

    try {
      if (kIsWeb) {
        // For web platform, use in-memory data
        if (products.isEmpty && kDebugMode) {
          await addSampleProducts();
        }
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        final productMaps = await db.getAllProducts();
        products = productMaps.map((map) => Product.fromMap(map)).toList();

        // 仅在 Debug 模式下添加示例产品数据（如果没有数据）
        if (products.isEmpty && kDebugMode) {
          await addSampleProducts();
        }
      }
    } catch (e) {
      AppLogger.error('loading products: $e');
      // If error occurs, add sample data (debug only)
      if (products.isEmpty && kDebugMode) {
        await addSampleProducts();
      }
    } finally {
      isDataLoading = false;
      notifyListeners();
    }
  }

  // 添加示例产品数据
  Future<void> addSampleProducts() async {
    final sampleProducts = [
      Product(
        company: '平安保险',
        name: '平安福重疾险',
        description: '涵盖100种重疾和50种轻症，保障全面',
        sellingPoints: '保障范围广，理赔速度快，服务好',
        category: '重疾险',
        salesStartDate: '2026-01-01',
        salesEndDate: '2026-12-31',
        createdAt: DateTime.now().toIso8601String(),
      ),
      Product(
        company: '太平洋保险',
        name: '太平洋健康险',
        description: '提供全面的健康保障，包括住院医疗、门诊医疗等',
        sellingPoints: '保障全面，保费合理，理赔便捷',
        category: '健康险',
        salesStartDate: '2026-01-01',
        salesEndDate: '2026-12-31',
        createdAt: DateTime.now().toIso8601String(),
      ),
      Product(
        company: '中国人寿',
        name: '国寿养老险',
        description: '为老年人提供稳定的养老保障',
        sellingPoints: '收益稳定，安全可靠，适合养老规划',
        category: '养老险',
        salesStartDate: '2026-01-01',
        salesEndDate: '2026-12-31',
        createdAt: DateTime.now().toIso8601String(),
      ),
      Product(
        company: '人保财险',
        name: '人保车险',
        description: '为车辆提供全面的保险保障',
        sellingPoints: '理赔速度快，服务好，保费合理',
        category: '财产险',
        salesStartDate: '2026-01-01',
        salesEndDate: '2026-12-31',
        createdAt: DateTime.now().toIso8601String(),
      ),
      Product(
        company: '泰康人寿',
        name: '泰康年金险',
        description: '提供稳定的年金收益，适合长期理财',
        sellingPoints: '收益稳定，安全可靠，适合长期规划',
        category: '年金险',
        salesStartDate: '2026-01-01',
        salesEndDate: '2026-12-31',
        createdAt: DateTime.now().toIso8601String(),
      ),
    ];

    for (var product in sampleProducts) {
      await addProduct(product);
    }
  }

  // Add product, returns the new product's id
  Future<int?> addProduct(Product product) async {
    try {
      if (kIsWeb) {
        // For web platform, add to in-memory list
        final maxId = products.fold(
          0,
          (max, p) => p.id != null && p.id! > max ? p.id! : max,
        );
        final newProduct = Product(
          id: maxId + 1,
          company: product.company,
          name: product.name,
          description: product.description,
          sellingPoints: product.sellingPoints,
          category: product.category,
          salesStartDate: product.salesStartDate,
          salesEndDate: product.salesEndDate,
          createdAt: product.createdAt,
        );
        products.add(newProduct);
        _calculateInMemoryStatistics();
        notifyListeners();
        return newProduct.id;
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        final id = await db.insertProduct(product.toMap());
        await loadProducts();
        return id;
      }
    } catch (e) {
      AppLogger.error('adding product: $e');
      return null;
    }
  }

  // Update product
  Future<void> updateProduct(Product product) async {
    try {
      if (kIsWeb) {
        final index = products.indexWhere((p) => p.id == product.id);
        if (index != -1) {
          products[index] = product;
          _calculateInMemoryStatistics();
          notifyListeners();
        }
      } else {
        final db = DatabaseHelper.instance;
        await db.updateProduct(product.toMap());
        await Future.wait([
          loadProducts(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('updating product: $e');
    }
  }

  // Delete product
  Future<void> deleteProduct(int id) async {
    try {
      if (kIsWeb) {
        products.removeWhere((p) => p.id == id);
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.deleteProduct(id);
        // Only reload what's actually affected by product deletion
        await Future.wait([
          loadProducts(),
          loadSales(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('deleting product: $e');
    }
  }

  // Load all colleagues
  Future<void> loadColleagues() async {
    isDataLoading = true;

    try {
      if (kIsWeb) {
        // For web platform, use in-memory data
        // No sample colleagues for now
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        final colleagueMaps = await db.getAllColleagues();
        colleagues = colleagueMaps
            .map((map) => Colleague.fromMap(map))
            .toList();
      }
    } catch (e) {
      AppLogger.error('loading colleagues: $e');
    } finally {
      isDataLoading = false;
      notifyListeners();
    }
  }

  // Add colleague
  Future<void> addColleague(Colleague colleague) async {
    try {
      if (kIsWeb) {
        final maxId = colleagues.fold(
          0,
          (max, c) => c.id != null && c.id! > max ? c.id! : max,
        );
        colleagues.add(
          Colleague(
            id: maxId + 1,
            name: colleague.name,
            phone: colleague.phone,
            email: colleague.email,
            departmentAndRole: colleague.departmentAndRole,
          ),
        );
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.insertColleague(colleague.toMap());
        await loadColleagues();
      }
    } catch (e) {
      AppLogger.error('adding colleague: $e');
    }
  }

  // Add visit
  Future<void> addVisit(Visit visit) async {
    try {
      if (kIsWeb) {
        // For web platform, add to in-memory list
        final customerIndex = customers.indexWhere((c) => c.id == visit.customerId);
        if (customerIndex == -1) return;
        final customer = customers[customerIndex];
        final newVisit = {
          'id': (customer.visits.fold(0, (max, v) { final id = (v['id'] as num?)?.toInt(); return id != null && id > max ? id : max; })) + 1,
          'customer_id': visit.customerId,
          'date': visit.visitDate,
          'location': visit.location,
          'accompanying_persons': visit.accompanyingPersons,
          'introduced_products': visit.productsPresented,
          'interested_products': visit.interestedProducts,
          'competitors': visit.competitors,
          'notes': visit.notes,
        };
        // Create new list to avoid mutating potentially const list
        final updatedVisits = List<Map<String, dynamic>>.from(customer.visits)
          ..add(newVisit);
        customers[customerIndex] = Customer(
          id: customer.id,
          name: customer.name,
          alias: customer.alias,
          age: customer.age,
          gender: customer.gender,
          rating: customer.rating,
          latitude: customer.latitude,
          longitude: customer.longitude,
          address: customer.address,
          phones: customer.phones,
          addresses: customer.addresses,
          visits: updatedVisits,
          products: customer.products,
          relationships: customer.relationships,
          birthday: customer.birthday,
          tags: customer.tags,
          photos: customer.photos,
          nextFollowUpDate: customer.nextFollowUpDate,
          createdAt: customer.createdAt ?? DateTime.now().toIso8601String(),
          persistentTagList: customer.persistentTagList,
          persistentPhotoList: customer.persistentPhotoList,
          wechatId: customer.wechatId,
          idCardNumber: customer.idCardNumber,
          occupation: customer.occupation,
          source: customer.source,
          notes: customer.notes,
          purchaseIntentionLevel: customer.purchaseIntentionLevel,
        );
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        await db.insertVisit(visit.toMap());
        await Future.wait([
          loadCustomers(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('adding visit: $e');
    }
  }

  // Add customer product
  Future<void> addCustomerProduct(
    int customerId,
    int productId,
    String purchaseDate,
  ) async {
    try {
      if (kIsWeb) {
        final customerIndex = customers.indexWhere((c) => c.id == customerId);
        if (customerIndex == -1) return;
        final customer = customers[customerIndex];
        final product = products.firstWhere(
          (p) => p.id == productId,
          orElse: () => Product(company: '', name: 'Unknown'),
        );
        final updatedProducts = List<Map<String, dynamic>>.from(customer.products)
          ..add({
            'id': (customer.products.fold(0, (max, p) { final id = (p['id'] as num?)?.toInt(); return id != null && id > max ? id : max; })) + 1,
            'product_id': productId,
            'name': product.name,
            'purchase_date': purchaseDate,
          });
        customers[customerIndex] = Customer(
          id: customer.id,
          name: customer.name,
          alias: customer.alias,
          age: customer.age,
          gender: customer.gender,
          rating: customer.rating,
          latitude: customer.latitude,
          longitude: customer.longitude,
          address: customer.address,
          phones: customer.phones,
          addresses: customer.addresses,
          visits: customer.visits,
          products: updatedProducts,
          relationships: customer.relationships,
          birthday: customer.birthday,
          tags: customer.tags,
          photos: customer.photos,
          nextFollowUpDate: customer.nextFollowUpDate,
          createdAt: customer.createdAt ?? DateTime.now().toIso8601String(),
          persistentTagList: customer.persistentTagList,
          persistentPhotoList: customer.persistentPhotoList,
          wechatId: customer.wechatId,
          idCardNumber: customer.idCardNumber,
          occupation: customer.occupation,
          source: customer.source,
          notes: customer.notes,
          purchaseIntentionLevel: customer.purchaseIntentionLevel,
        );
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.insertCustomerProduct({
          'customer_id': customerId,
          'product_id': productId,
          'purchase_date': purchaseDate,
        });
        await Future.wait([
          loadCustomers(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('adding customer product: $e');
    }
  }

  // Add customer relationship
  Future<void> addCustomerRelationship(
    int customerId,
    int relatedCustomerId,
    String relationship,
  ) async {
    try {
      if (kIsWeb) {
        // For web platform, add to in-memory list
        final customerIndex = customers.indexWhere((c) => c.id == customerId);
        if (customerIndex == -1) return;
        final customer = customers[customerIndex];
        final relatedCustomerIndex = customers.indexWhere((c) => c.id == relatedCustomerId);
        if (relatedCustomerIndex == -1) return;
        final relatedCustomer = customers[relatedCustomerIndex];
        final newRelationship = {
          'id': (customer.relationships.fold(0, (max, r) { final id = (r['id'] as num?)?.toInt(); return id != null && id > max ? id : max; })) + 1,
          'related_customer_id': relatedCustomerId,
          'name': relatedCustomer.name,
          'relationship': relationship,
        };
        // Create a new mutable list and add the new relationship
        final updatedRelationships = List<Map<String, dynamic>>.from(
          customer.relationships,
        );
        updatedRelationships.add(newRelationship);
        // Create a new customer with the updated relationships
        final updatedCustomer = Customer(
          id: customer.id,
          name: customer.name,
          alias: customer.alias,
          age: customer.age,
          gender: customer.gender,
          rating: customer.rating,
          latitude: customer.latitude,
          longitude: customer.longitude,
          address: customer.address,
          phones: customer.phones,
          addresses: customer.addresses,
          visits: customer.visits,
          products: customer.products,
          relationships: updatedRelationships,
          birthday: customer.birthday,
          tags: customer.tags,
          photos: customer.photos,
          nextFollowUpDate: customer.nextFollowUpDate,
          createdAt: customer.createdAt ?? DateTime.now().toIso8601String(),
          persistentTagList: customer.persistentTagList,
          persistentPhotoList: customer.persistentPhotoList,
          wechatId: customer.wechatId,
          idCardNumber: customer.idCardNumber,
          occupation: customer.occupation,
          source: customer.source,
          notes: customer.notes,
          purchaseIntentionLevel: customer.purchaseIntentionLevel,
        );
        // Replace the old customer with the new one
        customers[customerIndex] = updatedCustomer;
        notifyListeners();
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        await db.insertCustomerRelationship({
          'customer_id': customerId,
          'related_customer_id': relatedCustomerId,
          'relationship': relationship,
        });
        await Future.wait([
          loadCustomers(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('adding customer relationship: $e');
    }
  }

  // Load all sales
  Future<void> loadSales() async {
    isDataLoading = true;

    try {
      if (kIsWeb) {
        // For web platform, use in-memory data
        // No sample sales for now
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        final saleMaps = await db.getAllSales();
        salesRecords = saleMaps;
      }
    } catch (e) {
      AppLogger.error('loading sales: $e');
    } finally {
      isDataLoading = false;
      notifyListeners();
    }
  }

  // Add sale
  Future<void> addSale(Sale sale) async {
    try {
      if (kIsWeb) {
        // For web platform, add to in-memory list
        final maxId = salesRecords.fold(0, (max, s) {
          final id = (s['id'] as num?)?.toInt();
          return id != null && id > max ? id : max;
        });
        final newSale = {
          'id': maxId + 1,
          'customer_id': sale.customerId,
          'product_id': sale.productId,
          'amount': sale.amount ?? 0.0,
          'notes': sale.notes,
          'sale_date': sale.saleDate,
          'colleague_id': sale.colleagueId,
          'commission_rate': sale.commissionRate ?? 0.0,
          'customer_name': customers
              .firstWhere(
                (c) => c.id == sale.customerId,
                orElse: () {
                  AppLogger.warning('Sale references non-existent customer_id: ${sale.customerId}');
                  return Customer(name: 'Unknown');
                },
              )
              .name,
          'product_name': products
              .firstWhere(
                (p) => p.id == sale.productId,
                orElse: () {
                  AppLogger.warning('Sale references non-existent product_id: ${sale.productId}');
                  return Product(company: '', name: 'Unknown');
                },
              )
              .name,
          'colleague_name': sale.colleagueId != null
              ? colleagues
                    .firstWhere(
                      (c) => c.id == sale.colleagueId,
                      orElse: () {
                        AppLogger.warning('Sale references non-existent colleague_id: ${sale.colleagueId}');
                        return Colleague(name: 'Unknown');
                      },
                    )
                    .name
              : null,
        };
        salesRecords.add(newSale);
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        await db.insertSale(sale.toMap());
        await Future.wait([
          loadSales(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('adding sale: $e');
    }
  }

  // Get customer sales
  Future<List<Map<String, dynamic>>> getCustomerSales(int customerId) async {
    try {
      if (kIsWeb) {
        // For web platform, filter from in-memory list
        return salesRecords
            .where((sale) => (sale['customer_id'] as num?)?.toInt() == customerId)
            .toList();
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        return await db.getCustomerSales(customerId);
      }
    } catch (e) {
      AppLogger.error('getting customer sales: $e');
      return [];
    }
  }

  // Search customers
  List<Customer> searchCustomers(String query) {
    if (query.isEmpty) return customers;
    final q = query.toLowerCase();
    return customers.where((customer) {
      final nameMatch = customer.name.toLowerCase().contains(q);
      final aliasMatch = customer.alias?.toLowerCase().contains(q) ?? false;
      final phoneMatch = customer.phones.any((phone) => phone.contains(q));
      final addressMatch = customer.addresses.any(
        (address) => address.toLowerCase().contains(q),
      );
      final tagMatch = customer.tagList.any((tag) => tag.toLowerCase().contains(q));
      final wechatMatch = customer.wechatId?.toLowerCase().contains(q) ?? false;
      final notesMatch = customer.notes?.toLowerCase().contains(q) ?? false;
      final occupationMatch = customer.occupation?.toLowerCase().contains(q) ?? false;
      return nameMatch || aliasMatch || phoneMatch || addressMatch || tagMatch || wechatMatch || notesMatch || occupationMatch;
    }).toList();
  }

  // Search products
  List<Product> searchProducts(String query) {
    if (query.isEmpty) return products;
    final q = query.toLowerCase();
    return products.where((product) {
      final nameMatch = product.name.toLowerCase().contains(q);
      final companyMatch = product.company.toLowerCase().contains(q);
      final categoryMatch =
          product.category?.toLowerCase().contains(q) ?? false;
      return nameMatch || companyMatch || categoryMatch;
    }).toList();
  }

  // Calculate distance between two points (public)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return _calculateDistance(lat1, lon1, lat2, lon2);
  }

  // Get all customers sorted by distance from a point
  List<Map<String, dynamic>> getCustomersSortedByDistance(
    double latitude,
    double longitude, {
    int? limit,
  }) {
    final customersWithDist = customers
        .where((c) {
          return c.latitude != null && c.longitude != null;
        })
        .map((c) {
          final dist = _calculateDistance(
            latitude,
            longitude,
            c.latitude!,
            c.longitude!,
          );
          return {'customer': c, 'distance': dist};
        })
        .toList();

    customersWithDist.sort(
      (a, b) => ((a['distance'] as num?) ?? 0).compareTo((b['distance'] as num?) ?? 0),
    );

    if (limit != null && limit < customersWithDist.length) {
      return customersWithDist.sublist(0, limit);
    }
    return customersWithDist;
  }

  // Get nearby customers
  List<Customer> getNearbyCustomers(
    double latitude,
    double longitude,
    double radius,
  ) {
    return customers.where((customer) {
      if (customer.latitude == null || customer.longitude == null) return false;
      final distance = _calculateDistance(
        latitude,
        longitude,
        customer.latitude!,
        customer.longitude!,
      );
      return distance <= radius;
    }).toList();
  }

  // Calculate distance between two points
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371; // Radius of the earth in km
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final haversineA =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final haversineAngle = 2 * math.atan2(math.sqrt(haversineA), math.sqrt(1 - haversineA));
    final distanceKm = earthRadiusKm * haversineAngle;
    return distanceKm;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Recommend products for customer
  List<Product> recommendProducts(Customer customer) {
    // Simple recommendation logic based on age and gender
    List<Product> recommended = [];

    for (var product in products) {
      if (customer.age != null) {
        if (customer.age! < 30 && product.category?.contains('健康') == true) {
          recommended.add(product);
        } else if (customer.age! >= 30 &&
            customer.age! < 50 &&
            product.category?.contains('重疾') == true) {
          recommended.add(product);
        } else if (customer.age! >= 50 &&
            product.category?.contains('养老') == true) {
          recommended.add(product);
        }
      }
    }

    // Remove duplicates (by product id) and limit to 5 recommendations
    final seenIds = <int>{};
    return recommended.where((p) {
      final id = p.id;
      if (id == null || seenIds.contains(id)) return false;
      seenIds.add(id);
      return true;
    }).take(5).toList();
  }

  // 切换主题模式
  void toggleDarkMode(bool value) {
    darkMode = value;
    notifyListeners();
  }

  // 更新AI引擎配置
  Future<void> updateAIConfig(String provider, Map<String, dynamic> config) async {
    aiProviderConfigs[provider] = config;
    if (!kIsWeb) {
      await _saveAIConfigToDb(provider, config);
    }
    notifyListeners();
  }

  // 删除AI引擎配置
  Future<void> deleteAIConfig(String provider) async {
    aiProviderConfigs.remove(provider);
    if (!kIsWeb) {
      try {
        final db = DatabaseHelper.instance;
        await db.deleteAIConfigByKey(provider);
      } catch (e) {
        AppLogger.error('deleting AI config from db: $e');
      }
    }
    notifyListeners();
  }

  // 获取已启用的AI引擎列表
  List<Map<String, dynamic>> get enabledAIEngines {
    return aiProviderConfigs.entries
        .where((e) => e.value['enabled'] == true)
        .map((e) => {
              'key': e.key,
              'name': e.value['name'] ?? e.key,
              'apiKey': e.value['apiKey'] ?? '',
              'baseUrl': e.value['baseUrl'] ?? '',
              'model': e.value['model'] ?? '',
              'category': e.value['category'] ?? 'chat',
              'enabled': true,
            })
        .toList();
  }

  // 获取已启用的ASR(语音识别)引擎
  List<Map<String, dynamic>> get enabledASREngines {
    return enabledAIEngines.where((e) => e['category'] == 'asr').toList();
  }

  // 获取已启用的Chat(对话分析)引擎
  List<Map<String, dynamic>> get enabledChatEngines {
    return enabledAIEngines.where((e) => e['category'] == 'chat').toList();
  }

  // 保存单个AI配置到数据库
  Future<void> _saveAIConfigToDb(String provider, Map<String, dynamic> config) async {
    try {
      final db = DatabaseHelper.instance;
      final now = DateTime.now().toIso8601String();
      final existing = await db.getAIConfigByKey(provider);
      if (existing != null) {
        await db.updateAIConfig(provider, {
          'name': config['name'] ?? provider,
          'api_key': config['apiKey'] ?? '',
          'base_url': config['baseUrl'] ?? '',
          'model': config['model'] ?? '',
          'category': config['category'] ?? 'chat',
          'enabled': (config['enabled'] == true) ? 1 : 0,
          'updated_at': now,
        });
      } else {
        await db.insertAIConfig({
          'provider_key': provider,
          'name': config['name'] ?? provider,
          'api_key': config['apiKey'] ?? '',
          'base_url': config['baseUrl'] ?? '',
          'model': config['model'] ?? '',
          'category': config['category'] ?? 'chat',
          'enabled': (config['enabled'] == true) ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        });
      }
    } catch (e) {
      AppLogger.error('saving AI config to db: $e');
    }
  }

  // 加载AI配置（优先从数据库，降级到SharedPreferences）
  Future<void> _loadAIConfigs() async {
    try {
      if (!kIsWeb) {
        final db = DatabaseHelper.instance;
        final dbConfigs = await db.getAllAIConfigs();
        if (dbConfigs.isNotEmpty) {
          final Map<String, dynamic> loaded = {};
          for (final row in dbConfigs) {
            loaded[row['provider_key']?.toString() ?? ''] = {
              'name': row['name'],
              'apiKey': row['api_key'] ?? '',
              'baseUrl': row['base_url'] ?? '',
              'model': row['model'] ?? '',
              'category': row['category'] ?? 'chat',
              'enabled': row['enabled'] == 1,
            };
          }
          aiProviderConfigs = loaded;
          notifyListeners();
          return;
        }
      }
      // Fallback: load from SharedPreferences (legacy)
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('ai_configs');
      if (encoded != null && encoded.isNotEmpty) {
        final Map<String, dynamic> loaded = {};
        for (final entry in encoded.split(';;')) {
          final parts = entry.split('::');
          if (parts.length == 2) {
            final key = parts[0];
            final Map<String, dynamic> config = {};
            for (final kv in parts[1].split('|')) {
              final kvParts = kv.split('=');
              if (kvParts.length == 2) {
                config[kvParts[0]] = kvParts[1] == 'true'
                    ? true
                    : kvParts[1] == 'false'
                        ? false
                        : kvParts[1];
              }
            }
            loaded[key] = config;
          }
        }
        if (loaded.isNotEmpty) {
          aiProviderConfigs = loaded;
          notifyListeners();
          // Migrate to database
          for (final entry in loaded.entries) {
            await _saveAIConfigToDb(entry.key, (entry.value is Map<String, dynamic>) ? entry.value as Map<String, dynamic> : <String, dynamic>{});
          }
          // Clear legacy SharedPreferences
          await prefs.remove('ai_configs');
        }
      }
    } catch (e) {
      AppLogger.error('loading AI configs: $e');
    }
  }

  // 更新同事信息
  Future<void> updateColleague(Colleague colleague) async {
    try {
      if (kIsWeb) {
        final index = colleagues.indexWhere((c) => c.id == colleague.id);
        if (index != -1) {
          colleagues[index] = colleague;
          _calculateInMemoryStatistics();
          notifyListeners();
        }
      } else {
        final db = DatabaseHelper.instance;
        await db.updateColleague(colleague.toMap());
        await Future.wait([
          loadColleagues(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('updating colleague: $e');
    }
  }

  // 删除同事
  Future<void> deleteColleague(int id) async {
    try {
      if (kIsWeb) {
        colleagues.removeWhere((c) => c.id == id);
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.deleteColleague(id);
        await Future.wait([
          loadColleagues(),
          loadSales(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('deleting colleague: $e');
    }
  }

  // ===== Visit Edit/Delete =====

  Future<void> updateVisit(Visit visit) async {
    try {
      if (kIsWeb) {
        for (int i = 0; i < customers.length; i++) {
          final customer = customers[i];
          final vIdx = customer.visits.indexWhere((v) => v['id'] == visit.id);
          if (vIdx != -1) {
            final updatedVisits = List<Map<String, dynamic>>.from(customer.visits);
            updatedVisits[vIdx] = visit.toMap()..['id'] = visit.id;
            customers[i] = Customer(
              id: customer.id,
              name: customer.name,
              alias: customer.alias,
              age: customer.age,
              gender: customer.gender,
              rating: customer.rating,
              latitude: customer.latitude,
              longitude: customer.longitude,
              address: customer.address,
              phones: customer.phones,
              addresses: customer.addresses,
              visits: updatedVisits,
              products: customer.products,
              relationships: customer.relationships,
              birthday: customer.birthday,
              tags: customer.tags,
              photos: customer.photos,
              nextFollowUpDate: customer.nextFollowUpDate,
              createdAt: customer.createdAt,
              persistentTagList: customer.persistentTagList,
              persistentPhotoList: customer.persistentPhotoList,
              wechatId: customer.wechatId,
              idCardNumber: customer.idCardNumber,
              occupation: customer.occupation,
              source: customer.source,
              notes: customer.notes,
              purchaseIntentionLevel: customer.purchaseIntentionLevel,
            );
            break;
          }
        }
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.updateVisit(visit.toMap()..['id'] = visit.id);
        await Future.wait([
          loadCustomers(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('updating visit: $e');
    }
  }

  Future<void> deleteVisit(int id) async {
    try {
      if (kIsWeb) {
        for (int i = 0; i < customers.length; i++) {
          final customer = customers[i];
          final hadVisit = customer.visits.any((v) => v['id'] == id);
          if (hadVisit) {
            final updatedVisits = List<Map<String, dynamic>>.from(customer.visits)
              ..removeWhere((v) => v['id'] == id);
            customers[i] = Customer(
              id: customer.id,
              name: customer.name,
              alias: customer.alias,
              age: customer.age,
              gender: customer.gender,
              rating: customer.rating,
              latitude: customer.latitude,
              longitude: customer.longitude,
              address: customer.address,
              phones: customer.phones,
              addresses: customer.addresses,
              visits: updatedVisits,
              products: customer.products,
              relationships: customer.relationships,
              birthday: customer.birthday,
              tags: customer.tags,
              photos: customer.photos,
              nextFollowUpDate: customer.nextFollowUpDate,
              createdAt: customer.createdAt,
              persistentTagList: customer.persistentTagList,
              persistentPhotoList: customer.persistentPhotoList,
              wechatId: customer.wechatId,
              idCardNumber: customer.idCardNumber,
              occupation: customer.occupation,
              source: customer.source,
              notes: customer.notes,
              purchaseIntentionLevel: customer.purchaseIntentionLevel,
            );
            break;
          }
        }
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.deleteVisit(id);
        await Future.wait([
          loadCustomers(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('deleting visit: $e');
    }
  }

  // ===== Sale Edit/Delete =====

  Future<void> updateSale(Sale sale) async {
    try {
      if (kIsWeb) {
        final index = salesRecords.indexWhere((s) => s['id'] == sale.id);
        if (index != -1) {
          salesRecords[index] = {
            ...salesRecords[index],
            'customer_id': sale.customerId,
            'product_id': sale.productId,
            'amount': sale.amount ?? 0.0,
            'notes': sale.notes,
            'sale_date': sale.saleDate,
            'colleague_id': sale.colleagueId,
            'commission_rate': sale.commissionRate ?? 0.0,
            'customer_name': customers
                .firstWhere(
                  (c) => c.id == sale.customerId,
                  orElse: () => Customer(name: 'Unknown'),
                )
                .name,
            'product_name': products
                .firstWhere(
                  (p) => p.id == sale.productId,
                  orElse: () => Product(company: '', name: 'Unknown'),
                )
                .name,
            'colleague_name': sale.colleagueId != null
                ? colleagues
                      .firstWhere(
                        (c) => c.id == sale.colleagueId,
                        orElse: () => Colleague(name: 'Unknown'),
                      )
                      .name
                : null,
          };
          _calculateInMemoryStatistics();
          notifyListeners();
        }
      } else {
        final db = DatabaseHelper.instance;
        await db.updateSale(sale.toMap()..['id'] = sale.id);
        await Future.wait([
          loadSales(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('updating sale: $e');
    }
  }

  Future<void> deleteSale(int id) async {
    try {
      if (kIsWeb) {
        salesRecords.removeWhere((s) => s['id'] == id);
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.deleteSale(id);
        await Future.wait([
          loadSales(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('deleting sale: $e');
    }
  }

  // ===== Customer Relationship Delete =====

  Future<void> deleteCustomerRelationship(int id) async {
    try {
      if (kIsWeb) {
        for (int i = 0; i < customers.length; i++) {
          final customer = customers[i];
          final hadRelationship = customer.relationships.any((r) => r['id'] == id);
          if (hadRelationship) {
            final updatedRelationships = List<Map<String, dynamic>>.from(customer.relationships)
              ..removeWhere((r) => r['id'] == id);
            customers[i] = Customer(
              id: customer.id,
              name: customer.name,
              alias: customer.alias,
              age: customer.age,
              gender: customer.gender,
              rating: customer.rating,
              latitude: customer.latitude,
              longitude: customer.longitude,
              address: customer.address,
              phones: customer.phones,
              addresses: customer.addresses,
              visits: customer.visits,
              products: customer.products,
              relationships: updatedRelationships,
              birthday: customer.birthday,
              tags: customer.tags,
              photos: customer.photos,
              nextFollowUpDate: customer.nextFollowUpDate,
              createdAt: customer.createdAt,
              persistentTagList: customer.persistentTagList,
              persistentPhotoList: customer.persistentPhotoList,
              wechatId: customer.wechatId,
              idCardNumber: customer.idCardNumber,
              occupation: customer.occupation,
              source: customer.source,
              notes: customer.notes,
              purchaseIntentionLevel: customer.purchaseIntentionLevel,
            );
            break;
          }
        }
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.deleteCustomerRelationship(id);
        await Future.wait([
          loadCustomers(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('deleting customer relationship: $e');
    }
  }

  // ===== Customer Product Dissociation =====

  Future<void> deleteCustomerProduct(int id) async {
    try {
      if (kIsWeb) {
        for (int i = 0; i < customers.length; i++) {
          final customer = customers[i];
          final hadProduct = customer.products.any((p) => p['id'] == id);
          if (hadProduct) {
            final updatedProducts = List<Map<String, dynamic>>.from(customer.products)
              ..removeWhere((p) => p['id'] == id);
            customers[i] = Customer(
              id: customer.id,
              name: customer.name,
              alias: customer.alias,
              age: customer.age,
              gender: customer.gender,
              rating: customer.rating,
              latitude: customer.latitude,
              longitude: customer.longitude,
              address: customer.address,
              phones: customer.phones,
              addresses: customer.addresses,
              visits: customer.visits,
              products: updatedProducts,
              relationships: customer.relationships,
              birthday: customer.birthday,
              tags: customer.tags,
              photos: customer.photos,
              nextFollowUpDate: customer.nextFollowUpDate,
              createdAt: customer.createdAt,
              persistentTagList: customer.persistentTagList,
              persistentPhotoList: customer.persistentPhotoList,
              wechatId: customer.wechatId,
              idCardNumber: customer.idCardNumber,
              occupation: customer.occupation,
              source: customer.source,
              notes: customer.notes,
              purchaseIntentionLevel: customer.purchaseIntentionLevel,
            );
            break;
          }
        }
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.deleteCustomerProduct(id);
        await Future.wait([
          loadCustomers(),
          loadStatistics(),
        ]);
      }
    } catch (e) {
      AppLogger.error('deleting customer product: $e');
    }
  }

  // ===== Customer Tags =====

  Future<void> loadTags() async {
    try {
      if (kIsWeb) {
        // Web: tags stored in customer objects
        final tagSet = <String>{};
        for (var c in customers) {
          for (var t in c.tagList) {
            tagSet.add(t);
          }
        }
        allTags = tagSet.toList()..sort();
      } else {
        final db = DatabaseHelper.instance;
        allTags = await db.getAllUniqueTags();
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error('loading tags: $e');
    }
  }

  Future<void> addTag(String tag) async {
    if (!allTags.contains(tag)) {
      if (!kIsWeb) {
        try {
          await DatabaseHelper.instance.insertTag(tag);
        } catch (e) {
          AppLogger.error('insertTag failed: $e');
          return;
        }
      }
      allTags.add(tag);
      allTags.sort();
      notifyListeners();
    }
  }

  Future<void> removeTag(String tag) async {
    // Clean up customer_tags associations and tag definition in the database
    if (!kIsWeb) {
      try {
        // deleteTag already removes both customer_tags and tags table
        await DatabaseHelper.instance.deleteTag(tag);
        // Refresh customers to update persistentTagList
        await loadCustomers();
        await Future.wait([
          loadTags(),
          loadStatistics(),
        ]);
      } catch (e) {
        AppLogger.error('removeTag failed: $e');
        return;
      }
    } else {
      // Web: update customer objects' persistentTagList in memory
      allTags.remove(tag);
      for (int i = 0; i < customers.length; i++) {
        if (customers[i].persistentTagList.contains(tag)) {
          final updatedTags = List<String>.from(customers[i].persistentTagList)..remove(tag);
          customers[i] = Customer(
            id: customers[i].id,
            name: customers[i].name,
            alias: customers[i].alias,
            age: customers[i].age,
            gender: customers[i].gender,
            rating: customers[i].rating,
            latitude: customers[i].latitude,
            longitude: customers[i].longitude,
            address: customers[i].address,
            phones: customers[i].phones,
            addresses: customers[i].addresses,
            visits: customers[i].visits,
            products: customers[i].products,
            relationships: customers[i].relationships,
            birthday: customers[i].birthday,
            tags: updatedTags.join(','),
            photos: customers[i].photos,
            nextFollowUpDate: customers[i].nextFollowUpDate,
            createdAt: customers[i].createdAt,
            persistentTagList: updatedTags,
            persistentPhotoList: customers[i].persistentPhotoList,
            wechatId: customers[i].wechatId,
            idCardNumber: customers[i].idCardNumber,
            occupation: customers[i].occupation,
            source: customers[i].source,
            notes: customers[i].notes,
            purchaseIntentionLevel: customers[i].purchaseIntentionLevel,
          );
        }
      }
      _calculateInMemoryStatistics();
    }
    notifyListeners();
  }

  Future<void> addCustomerTag(int customerId, String tag) async {
    try {
      if (kIsWeb) {
        final idx = customers.indexWhere((c) => c.id == customerId);
        if (idx == -1) return;
        final customer = customers[idx];
        if (!customer.tagList.contains(tag)) {
          // Create a new Customer object with updated tags (immutable update pattern)
          final currentTags = List<String>.from(customer.tagList)..add(tag);
          customers[idx] = Customer(
            id: customer.id,
            name: customer.name,
            alias: customer.alias,
            age: customer.age,
            gender: customer.gender,
            rating: customer.rating,
            latitude: customer.latitude,
            longitude: customer.longitude,
            address: customer.address,
            phones: customer.phones,
            addresses: customer.addresses,
            visits: customer.visits,
            products: customer.products,
            relationships: customer.relationships,
            birthday: customer.birthday,
            tags: currentTags.join(','),
            photos: customer.photos,
            nextFollowUpDate: customer.nextFollowUpDate,
            createdAt: customer.createdAt,
            persistentTagList: currentTags,
            persistentPhotoList: customer.persistentPhotoList,
            wechatId: customer.wechatId,
            idCardNumber: customer.idCardNumber,
            occupation: customer.occupation,
            source: customer.source,
            notes: customer.notes,
            purchaseIntentionLevel: customer.purchaseIntentionLevel,
          );
        }
        if (!allTags.contains(tag)) {
          allTags.add(tag);
          allTags.sort();
        }
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.insertCustomerTag(customerId, tag);
        await loadCustomers();
        await loadTags();
      }
    } catch (e) {
      AppLogger.error('adding customer tag: $e');
    }
  }

  Future<void> removeCustomerTag(int customerId, String tag) async {
    try {
      if (kIsWeb) {
        final idx = customers.indexWhere((c) => c.id == customerId);
        if (idx == -1) return;
        final customer = customers[idx];
        final currentTags = List<String>.from(customer.tagList)..remove(tag);
        // Create a new Customer object with updated tags (immutable update pattern)
        customers[idx] = Customer(
          id: customer.id,
          name: customer.name,
          alias: customer.alias,
          age: customer.age,
          gender: customer.gender,
          rating: customer.rating,
          latitude: customer.latitude,
          longitude: customer.longitude,
          address: customer.address,
          phones: customer.phones,
          addresses: customer.addresses,
          visits: customer.visits,
          products: customer.products,
          relationships: customer.relationships,
          birthday: customer.birthday,
          tags: currentTags.join(','),
          photos: customer.photos,
          nextFollowUpDate: customer.nextFollowUpDate,
          createdAt: customer.createdAt ?? DateTime.now().toIso8601String(),
          persistentTagList: currentTags,
          persistentPhotoList: customer.persistentPhotoList,
          wechatId: customer.wechatId,
          idCardNumber: customer.idCardNumber,
          occupation: customer.occupation,
          source: customer.source,
          notes: customer.notes,
          purchaseIntentionLevel: customer.purchaseIntentionLevel,
        );
        // Don't auto-remove from allTags just because no customer uses it;
        // the tag should remain available for future use as a definition.
        _calculateInMemoryStatistics();
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.deleteCustomerTag(customerId, tag);
        await loadCustomers();
        await loadTags();
      }
    } catch (e) {
      AppLogger.error('removing customer tag: $e');
    }
  }

  List<Customer> searchCustomersByTag(String tag) {
    return customers.where((c) => c.tagList.contains(tag)).toList();
  }

  // Search customers by tag - O(N*M*K) where N=customers, M=search tags, K=customer tags
  List<Customer> searchCustomersWithTags(List<String> tags) {
    if (tags.isEmpty) return [];
    return customers.where((c) {
      final cTags = c.tagList;
      return tags.every((tag) => cTags.contains(tag));
    }).toList();
  }
}
