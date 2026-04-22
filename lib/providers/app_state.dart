import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:insurecrm/database/database_helper.dart';
import 'package:insurecrm/models/customer.dart';
import 'package:insurecrm/models/product.dart';
import 'package:insurecrm/models/visit.dart';
import 'package:insurecrm/models/colleague.dart';
import 'package:insurecrm/models/sale.dart';
import 'package:insurecrm/models/user.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:insurecrm/services/backup_service.dart';
import 'package:insurecrm/utils/app_logger.dart';

class AppState extends ChangeNotifier {
  // ===== Authentication State =====
  User? currentUser;
  bool get isLoggedIn => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;

  List<Customer> customers = [];
  List<Product> products = [];
  List<Colleague> colleagues = [];
  List<Map<String, dynamic>> sales = [];
  List<String> allTags = [];
  bool isLoading = false;
  bool darkMode = false;

  // AI引擎配置
  Map<String, dynamic> aiConfigs = {
    'doubao': {'apiKey': '', 'enabled': false},
    'qianwen': {'apiKey': '', 'enabled': false},
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
  int totalSalesAmount = 0;
  int totalVisitsCount = 0;
  int thisMonthNewCustomers = 0;
  int thisMonthSalesAmount = 0;
  int thisMonthVisitsCount = 0;
  List<Map<String, dynamic>> quarterlySales = [];
  List<Map<String, dynamic>> annualSales = [];
  List<Map<String, dynamic>> monthlyCommissions = [];
  List<Map<String, dynamic>> quarterlyCommissions = [];
  List<Map<String, dynamic>> annualCommissions = [];
  List<Map<String, dynamic>> conversionFunnel = [];
  List<Map<String, dynamic>> visitEfficiency = [];

  // Initialize app data
  Future<void> initializeApp() async {
    try {
      await loadCustomers();
      await loadProducts();
      await loadColleagues();
      await loadSales();
      await loadReminders();
      await loadStatistics();
      await loadSystemNotifications();
      // Auto backup check (non-blocking)
      if (!kIsWeb) {
        try {
          await BackupService.instance.runAutoBackupIfNeeded();
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.error('initializing app: $e');
    }
  }

  // Load statistics
  Future<void> loadStatistics() async {
    try {
      if (kIsWeb) {
        // Web platform: calculate from in-memory data
        _calculateWebStatistics();
      } else {
        final db = DatabaseHelper.instance;
        final now = DateTime.now();
        final year = now.year;
        final thisMonth = now.month;

        // Monthly sales
        monthlySales = await db.getMonthlySalesSummary(year);

        // Monthly visits
        monthlyVisits = await db.getMonthlyVisitSummary(year);

        // Monthly new customers
        monthlyNewCustomers = await db.getMonthlyNewCustomerSummary(year);

        // Product ranking
        productRanking = await db.getProductSalesRanking();

        // Rating distribution
        ratingDistribution = await db.getCustomerRatingDistribution();

        // Quarterly and annual sales
        quarterlySales = await db.getQuarterlySalesSummary(year);
        annualSales = await db.getAnnualSalesSummary(year);

        // Commission summaries
        monthlyCommissions = await db.getMonthlyCommissionSummary(year);
        quarterlyCommissions = await db.getQuarterlyCommissionSummary(year);
        annualCommissions = await db.getAnnualCommissionSummary(year);

        // Conversion funnel analysis
        conversionFunnel = await db.getConversionFunnelAnalysis();

        // Visit efficiency analysis
        visitEfficiency = await db.getVisitEfficiencyAnalysis();

        // Calculate totals
        totalSalesAmount = monthlySales.fold(
          0,
          (sum, s) => sum + ((s['total_amount'] as num?)?.toInt() ?? 0),
        );
        totalVisitsCount = monthlyVisits.fold(
          0,
          (sum, v) => sum + ((v['count'] as num?)?.toInt() ?? 0),
        );

        // This month specific
        final thisMonthSalesData = monthlySales
            .where((s) => s['month'] == thisMonth)
            .toList();
        thisMonthSalesAmount = thisMonthSalesData.isNotEmpty
            ? (thisMonthSalesData.first['total_amount'] as num?)?.toInt() ?? 0
            : 0;

        final thisMonthVisitsData = monthlyVisits
            .where((v) => v['month'] == thisMonth)
            .toList();
        thisMonthVisitsCount = thisMonthVisitsData.isNotEmpty
            ? (thisMonthVisitsData.first['count'] as num?)?.toInt() ?? 0
            : 0;

        final thisMonthCustomersData = monthlyNewCustomers
            .where((c) => c['month'] == thisMonth)
            .toList();
        thisMonthNewCustomers = thisMonthCustomersData.isNotEmpty
            ? (thisMonthCustomersData.first['count'] as num?)?.toInt() ?? 0
            : 0;
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error('loading statistics: $e');
    }
  }

  // Load reminders
  Future<void> loadReminders() async {
    try {
      if (kIsWeb) {
        // Web: reminders not persisted, use empty list
        todayReminders = [];
        overdueReminders = [];
      } else {
        final db = DatabaseHelper.instance;
        reminders = await db.getAllReminders();
        final today = DateTime.now().toIso8601String().substring(0, 10);
        todayReminders = await db.getRemindersByDate(today);
        overdueReminders = await db.getOverdueReminders();
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
      final today = now;
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
        if (p.endDate == null || p.endDate!.isEmpty) continue;
        final endDate = DateTime.tryParse(p.endDate!);
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
            'subtitle': '$statusLabel · 到期日 ${p.endDate!.substring(5)}',
            'icon': Icons.autorenew_rounded,
            'color': Color(0xFFFF9800),
            'time': p.endDate,
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
        var birthdayCheck = DateTime(now.year, int.parse(parts[1]), dayNum);

        if (birthdayCheck.month < now.month ||
            (birthdayCheck.month == now.month && birthdayCheck.day < now.day)) {
          birthdayCheck = DateTime(
            now.year + 1,
            birthdayCheck.month,
            birthdayCheck.day,
          );
        }

        final daysUntilBirthday = birthdayCheck.difference(now).inDays;

        if (daysUntilBirthday >= 0 && daysUntilBirthday <= 30) {
          String label;
          if (daysUntilBirthday == 0) {
            label = '今天生日！';
          } else if (daysUntilBirthday <= 7) {
            label = '${daysUntilBirthday}天后生日';
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
        // Web: fallback to hardcoded for compatibility
        if (username == 'admin' && password == '123456') {
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
        final customer = customers.firstWhere(
          (c) => c.id == customerId,
          orElse: () => Customer(name: 'Unknown'),
        );
        final maxId = reminders.fold(0, (max, r) {
          final id = r['id'] as int?;
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
          todayReminders[todayIndex]['status'] = status;
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

  void _calculateWebStatistics() {
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
      (a, b) => (b['rating'] as int).compareTo(a['rating'] as int),
    );

    // New customers this month
    thisMonthNewCustomers = customers.where((c) {
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
          ..sort((a, b) => (a['month'] as int).compareTo(b['month'] as int));

    // Sales and visits from in-memory data
    totalSalesAmount = sales.fold(
      0,
      (sum, s) => sum + ((s['amount'] as num?)?.toInt() ?? 0),
    );
    totalVisitsCount = customers.fold(0, (sum, c) => sum + c.visits.length);
    thisMonthSalesAmount = sales
        .where((s) {
          final sd = s['sale_date'] as String?;
          if (sd == null) return false;
          final dt = DateTime.tryParse(sd);
          return dt != null && dt.month == thisMonth && dt.year == thisYear;
        })
        .fold(0, (sum, s) => sum + ((s['amount'] as num?)?.toInt() ?? 0));

    thisMonthVisitsCount = customers.fold(0, (sum, c) {
      return sum +
          c.visits.where((v) {
            final vd = v['date'] as String?;
            if (vd == null) return false;
            final dt = DateTime.tryParse(vd);
            return dt != null && dt.month == thisMonth && dt.year == thisYear;
          }).length;
    });

    // Product ranking from sales
    Map<int, int> productSaleCounts = {};
    Map<int, double> productSaleAmounts = {};
    for (var s in sales) {
      final pid = s['product_id'] as int?;
      if (pid == null) continue;
      productSaleCounts[pid] = (productSaleCounts[pid] ?? 0) + 1;
      productSaleAmounts[pid] =
          (productSaleAmounts[pid] ?? 0) +
          ((s['amount'] as num?)?.toDouble() ?? 0);
    }
    productRanking =
        productSaleCounts.entries.map((e) {
          final product = products.firstWhere(
            (p) => p.id == e.key,
            orElse: () => Product(company: '', name: 'Unknown'),
          );
          return {
            'product_name': product.name,
            'product_category': product.category ?? '',
            'sale_count': e.value,
            'total_amount': productSaleAmounts[e.key] ?? 0,
          };
        }).toList()..sort(
          (a, b) => (b['sale_count'] as int).compareTo(a['sale_count'] as int),
        );

    // Monthly sales
    Map<int, double> monthlySalesMap = {};
    for (var s in sales) {
      final sd = s['sale_date'] as String?;
      if (sd == null) continue;
      final dt = DateTime.tryParse(sd);
      if (dt != null && dt.year == thisYear) {
        monthlySalesMap[dt.month] =
            (monthlySalesMap[dt.month] ?? 0) +
            ((s['amount'] as num?)?.toDouble() ?? 0);
      }
    }
    monthlySales =
        monthlySalesMap.entries
            .map((e) => {'month': e.key, 'count': 0, 'total_amount': e.value})
            .toList()
          ..sort((a, b) => (a['month'] as int).compareTo(b['month'] as int));

    // Monthly visits
    Map<int, int> monthlyVisitsMap = {};
    for (var c in customers) {
      for (var v in c.visits) {
        final vd = v['date'] as String?;
        if (vd == null) continue;
        final dt = DateTime.tryParse(vd);
        if (dt != null && dt.year == thisYear) {
          monthlyVisitsMap[dt.month] = (monthlyVisitsMap[dt.month] ?? 0) + 1;
        }
      }
    }
    monthlyVisits =
        monthlyVisitsMap.entries
            .map((e) => {'month': e.key, 'count': e.value})
            .toList()
          ..sort((a, b) => (a['month'] as int).compareTo(b['month'] as int));
  }

  // Load all customers
  Future<void> loadCustomers() async {
    try {
      isLoading = true;
      notifyListeners();

      if (kIsWeb) {
        // For web platform, use in-memory data
        if (customers.isEmpty) {
          await addSampleCustomers();
        }
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        final customerMaps = await db.getAllCustomers();

        customers = [];
        for (var map in customerMaps) {
          final phones = await db.getCustomerPhones(map['id']);
          final addresses = await db.getCustomerAddresses(map['id']);
          final visits = await db.getCustomerVisits(map['id']);
          final products = await db.getCustomerProducts(map['id']);
          final relationships = await db.getCustomerRelationships(map['id']);
          final tags = await db.getCustomerTags(map['id']);

          customers.add(
            Customer.fromMap(
              map,
              phones: phones,
              addresses: addresses,
              visits: visits,
              products: products,
              relationships: relationships,
              tagListFromDb: tags,
            ),
          );
        }

        // 添加示例客户数据（如果没有数据）
        if (customers.isEmpty) {
          await addSampleCustomers();
        }
      }
    } catch (e) {
      AppLogger.error('loading customers: $e');
      // If error occurs, add sample data
      if (customers.isEmpty) {
        await addSampleCustomers();
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 添加示例客户数据
  Future<void> addSampleCustomers() async {
    final sampleCustomers = [
      Customer(
        name: '张三',
        alias: '张总',
        age: 35,
        gender: '男',
        rating: 5,
        phones: ['13800138001'],
        addresses: ['北京市朝阳区建国路88号'],
        createdAt: DateTime.now().toIso8601String(),
      ),
      Customer(
        name: '李四',
        alias: '李经理',
        age: 28,
        gender: '女',
        rating: 4,
        phones: ['13900139002'],
        addresses: ['上海市浦东新区陆家嘴金融中心'],
        createdAt: DateTime.now().toIso8601String(),
      ),
      Customer(
        name: '王五',
        alias: '王老板',
        age: 42,
        gender: '男',
        rating: 5,
        phones: ['13700137003'],
        addresses: ['广州市天河区珠江新城'],
        createdAt: DateTime.now().toIso8601String(),
      ),
      Customer(
        name: '赵六',
        alias: '赵女士',
        age: 31,
        gender: '女',
        rating: 3,
        phones: ['13600136004'],
        addresses: ['深圳市南山区科技园'],
        createdAt: DateTime.now().toIso8601String(),
      ),
      Customer(
        name: '钱七',
        alias: '钱总',
        age: 45,
        gender: '男',
        rating: 4,
        phones: ['13500135005'],
        addresses: ['杭州市西湖区阿里巴巴总部'],
        createdAt: DateTime.now().toIso8601String(),
      ),
    ];

    for (var customer in sampleCustomers) {
      await addCustomer(customer);
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
          phones: customer.phones,
          addresses: customer.addresses,
          createdAt: customer.createdAt,
        );
        customers.add(newCustomer);
        notifyListeners();
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        final id = await db.insertCustomer(customer.toMap());

        // Insert phones
        for (var phone in customer.phones) {
          await db.insertCustomerPhone(id, phone);
        }

        // Insert addresses
        for (var address in customer.addresses) {
          await db.insertCustomerAddress(id, address);
        }

        await loadCustomers();
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
          notifyListeners();
        }
      } else {
        final db = DatabaseHelper.instance;
        await db.updateCustomer(customer.toMap());

        // Sync phones: delete old, insert new
        final dbInstance = await db.database;
        await dbInstance.delete(
          'customer_phones',
          where: 'customer_id = ?',
          whereArgs: [customer.id],
        );
        for (var phone in customer.phones) {
          await db.insertCustomerPhone(customer.id!, phone);
        }

        // Sync addresses: delete old, insert new
        await dbInstance.delete(
          'customer_addresses',
          where: 'customer_id = ?',
          whereArgs: [customer.id],
        );
        for (var address in customer.addresses) {
          await db.insertCustomerAddress(customer.id!, address);
        }

        await loadCustomers();
      }
    } catch (e) {
      AppLogger.error('updating customer: $e');
    }
  }

  // Delete customer
  Future<void> deleteCustomer(int id) async {
    try {
      final db = DatabaseHelper.instance;
      await db.deleteCustomer(id);
      await loadCustomers();
    } catch (e) {
      AppLogger.error('deleting customer: $e');
    }
  }

  // Load all products
  Future<void> loadProducts() async {
    isLoading = true;
    notifyListeners();

    try {
      if (kIsWeb) {
        // For web platform, use in-memory data
        if (products.isEmpty) {
          await addSampleProducts();
        }
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        final productMaps = await db.getAllProducts();
        products = productMaps.map((map) => Product.fromMap(map)).toList();

        // 添加示例产品数据（如果没有数据）
        if (products.isEmpty) {
          await addSampleProducts();
        }
      }
    } catch (e) {
      AppLogger.error('loading products: $e');
      // If error occurs, add sample data
      if (products.isEmpty) {
        await addSampleProducts();
      }
    } finally {
      isLoading = false;
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
        advantages: '保障范围广，理赔速度快，服务好',
        category: '重疾险',
        startDate: '2026-01-01',
        endDate: '2026-12-31',
        createdAt: DateTime.now().toIso8601String(),
      ),
      Product(
        company: '太平洋保险',
        name: '太平洋健康险',
        description: '提供全面的健康保障，包括住院医疗、门诊医疗等',
        advantages: '保障全面，保费合理，理赔便捷',
        category: '健康险',
        startDate: '2026-01-01',
        endDate: '2026-12-31',
        createdAt: DateTime.now().toIso8601String(),
      ),
      Product(
        company: '中国人寿',
        name: '国寿养老险',
        description: '为老年人提供稳定的养老保障',
        advantages: '收益稳定，安全可靠，适合养老规划',
        category: '养老险',
        startDate: '2026-01-01',
        endDate: '2026-12-31',
        createdAt: DateTime.now().toIso8601String(),
      ),
      Product(
        company: '人保财险',
        name: '人保车险',
        description: '为车辆提供全面的保险保障',
        advantages: '理赔速度快，服务好，保费合理',
        category: '财产险',
        startDate: '2026-01-01',
        endDate: '2026-12-31',
        createdAt: DateTime.now().toIso8601String(),
      ),
      Product(
        company: '泰康人寿',
        name: '泰康年金险',
        description: '提供稳定的年金收益，适合长期理财',
        advantages: '收益稳定，安全可靠，适合长期规划',
        category: '年金险',
        startDate: '2026-01-01',
        endDate: '2026-12-31',
        createdAt: DateTime.now().toIso8601String(),
      ),
    ];

    for (var product in sampleProducts) {
      await addProduct(product);
    }
  }

  // Add product
  Future<void> addProduct(Product product) async {
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
          advantages: product.advantages,
          category: product.category,
          startDate: product.startDate,
          endDate: product.endDate,
          createdAt: product.createdAt,
        );
        products.add(newProduct);
        notifyListeners();
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        await db.insertProduct(product.toMap());
        await loadProducts();
      }
    } catch (e) {
      AppLogger.error('adding product: $e');
    }
  }

  // Update product
  Future<void> updateProduct(Product product) async {
    try {
      final db = DatabaseHelper.instance;
      await db.updateProduct(product.toMap());
      await loadProducts();
    } catch (e) {
      AppLogger.error('updating product: $e');
    }
  }

  // Delete product
  Future<void> deleteProduct(int id) async {
    try {
      final db = DatabaseHelper.instance;
      await db.deleteProduct(id);
      await loadProducts();
    } catch (e) {
      AppLogger.error('deleting product: $e');
    }
  }

  // Load all colleagues
  Future<void> loadColleagues() async {
    isLoading = true;
    notifyListeners();

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
      isLoading = false;
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
            specialty: colleague.specialty,
          ),
        );
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
        final customer = customers.firstWhere((c) => c.id == visit.customerId);
        final newVisit = {
          'id': customer.visits.length + 1,
          'customer_id': visit.customerId,
          'date': visit.date,
          'location': visit.location,
          'accompanying_persons': visit.accompanyingPersons,
          'introduced_products': visit.introducedProducts,
          'interested_products': visit.interestedProducts,
          'competitors': visit.competitors,
          'notes': visit.notes,
        };
        customer.visits.add(newVisit);
        notifyListeners();
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        await db.insertVisit(visit.toMap());
        await loadCustomers();
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
      final db = DatabaseHelper.instance;
      await db.insertCustomerProduct({
        'customer_id': customerId,
        'product_id': productId,
        'purchase_date': purchaseDate,
      });
      await loadCustomers();
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
        final customer = customers.firstWhere((c) => c.id == customerId);
        final relatedCustomer = customers.firstWhere(
          (c) => c.id == relatedCustomerId,
        );
        final newRelationship = {
          'id': customer.relationships.length + 1,
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
          createdAt: customer.createdAt,
        );
        // Replace the old customer with the new one
        final customerIndex = customers.indexWhere((c) => c.id == customerId);
        if (customerIndex != -1) {
          customers[customerIndex] = updatedCustomer;
          notifyListeners();
        }
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        await db.insertCustomerRelationship({
          'customer_id': customerId,
          'related_customer_id': relatedCustomerId,
          'relationship': relationship,
        });
        await loadCustomers();
      }
    } catch (e) {
      AppLogger.error('adding customer relationship: $e');
    }
  }

  // Load all sales
  Future<void> loadSales() async {
    isLoading = true;
    notifyListeners();

    try {
      if (kIsWeb) {
        // For web platform, use in-memory data
        // No sample sales for now
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        final saleMaps = await db.getAllSales();
        sales = saleMaps;
      }
    } catch (e) {
      AppLogger.error('loading sales: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Add sale
  Future<void> addSale(Sale sale) async {
    try {
      if (kIsWeb) {
        // For web platform, add to in-memory list
        final maxId = sales.fold(0, (max, s) {
          final id = s['id'] as int?;
          return id != null && id > max ? id : max;
        });
        final newSale = {
          'id': maxId + 1,
          'customer_id': sale.customerId,
          'product_id': sale.productId,
          'notes': sale.notes,
          'sale_date': sale.saleDate,
          'colleague_id': sale.colleagueId,
          'commission_rate': sale.commissionRate,
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
        sales.add(newSale);
        notifyListeners();
      } else {
        // For mobile platforms, use database
        final db = DatabaseHelper.instance;
        await db.insertSale(sale.toMap());
        await loadSales();
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
        return sales
            .where((sale) => sale['customer_id'] == customerId)
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
    return customers.where((customer) {
      final nameMatch = customer.name.toLowerCase().contains(
        query.toLowerCase(),
      );
      final phoneMatch = customer.phones.any((phone) => phone.contains(query));
      final addressMatch = customer.addresses.any(
        (address) => address.toLowerCase().contains(query.toLowerCase()),
      );
      return nameMatch || phoneMatch || addressMatch;
    }).toList();
  }

  // Search products
  List<Product> searchProducts(String query) {
    if (query.isEmpty) return products;
    return products.where((product) {
      final nameMatch = product.name.toLowerCase().contains(
        query.toLowerCase(),
      );
      final companyMatch = product.company.toLowerCase().contains(
        query.toLowerCase(),
      );
      final categoryMatch =
          product.category?.toLowerCase().contains(query.toLowerCase()) ??
          false;
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
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
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
    const R = 6371; // Radius of the earth in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final d = R * c;
    return d;
  }

  double _deg2rad(double deg) {
    return deg * (3.14159265359 / 180);
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

    // Remove duplicates and limit to 5 recommendations
    return recommended.toSet().take(5).toList();
  }

  // 切换主题模式
  void toggleDarkMode(bool value) {
    darkMode = value;
    notifyListeners();
  }

  // 更新AI引擎配置
  void updateAIConfig(String provider, Map<String, dynamic> config) {
    aiConfigs[provider] = config;
    notifyListeners();
  }

  // 更新同事信息
  Future<void> updateColleague(Colleague colleague) async {
    try {
      final db = DatabaseHelper.instance;
      await db.updateColleague(colleague.toMap());
      await loadColleagues();
    } catch (e) {
      AppLogger.error('updating colleague: $e');
    }
  }

  // 删除同事
  Future<void> deleteColleague(int id) async {
    try {
      final db = DatabaseHelper.instance;
      await db.deleteColleague(id);
      await loadColleagues();
    } catch (e) {
      AppLogger.error('deleting colleague: $e');
    }
  }

  // ===== Visit Edit/Delete =====

  Future<void> updateVisit(Visit visit) async {
    try {
      final db = DatabaseHelper.instance;
      await db.updateVisit(visit.toMap()..['id'] = visit.id);
      await loadCustomers();
    } catch (e) {
      AppLogger.error('updating visit: $e');
    }
  }

  Future<void> deleteVisit(int id) async {
    try {
      final db = DatabaseHelper.instance;
      await db.deleteVisit(id);
      await loadCustomers();
    } catch (e) {
      AppLogger.error('deleting visit: $e');
    }
  }

  // ===== Sale Edit/Delete =====

  Future<void> updateSale(Sale sale) async {
    try {
      if (kIsWeb) {
        final index = sales.indexWhere((s) => s['id'] == sale.id);
        if (index != -1) {
          sales[index] = {
            ...sales[index],
            'product_id': sale.productId,
            'notes': sale.notes,
            'sale_date': sale.saleDate,
            'colleague_id': sale.colleagueId,
            'commission_rate': sale.commissionRate,
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
          notifyListeners();
        }
      } else {
        final db = DatabaseHelper.instance;
        await db.updateSale(sale.toMap()..['id'] = sale.id);
        await loadSales();
      }
    } catch (e) {
      AppLogger.error('updating sale: $e');
    }
  }

  Future<void> deleteSale(int id) async {
    try {
      if (kIsWeb) {
        sales.removeWhere((s) => s['id'] == id);
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.deleteSale(id);
        await loadSales();
      }
    } catch (e) {
      AppLogger.error('deleting sale: $e');
    }
  }

  // ===== Customer Relationship Delete =====

  Future<void> deleteCustomerRelationship(int id) async {
    try {
      if (kIsWeb) {
        for (var customer in customers) {
          customer.relationships.removeWhere((r) => r['id'] == id);
        }
        notifyListeners();
      } else {
        final db = DatabaseHelper.instance;
        await db.deleteCustomerRelationship(id);
        await loadCustomers();
      }
    } catch (e) {
      AppLogger.error('deleting customer relationship: $e');
    }
  }

  // ===== Customer Product Dissociation =====

  Future<void> deleteCustomerProduct(int id) async {
    try {
      final db = DatabaseHelper.instance;
      await db.deleteCustomerProduct(id);
      await loadCustomers();
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

  Future<void> addCustomerTag(int customerId, String tag) async {
    try {
      if (kIsWeb) {
        final customer = customers.firstWhere((c) => c.id == customerId);
        if (!customer.tagList.contains(tag)) {
          // Update the tags string for web
          final currentTags = customer.tagList;
          currentTags.add(tag);
          customer.tags = currentTags.join(',');
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
        final customer = customers.firstWhere((c) => c.id == customerId);
        final currentTags = customer.tagList;
        currentTags.remove(tag);
        customer.tags = currentTags.join(',');
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

  // Search customers by tag
  List<Customer> searchCustomersWithTags(List<String> tags) {
    if (tags.isEmpty) return customers;
    return customers.where((c) {
      return tags.every((tag) => c.tagList.contains(tag));
    }).toList();
  }
}
