import 'package:insurecrm/utils/app_logger.dart';
import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
// ignore: unnecessary_import
import 'dart:io';
// ignore: unnecessary_import
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final _databaseName = "insurance_app.db";
  static final _databaseVersion = 8;
  static int get databaseVersion => _databaseVersion;

  static final tableCustomers = 'customers';
  static final tableProducts = 'products';
  static final tableVisits = 'visits';
  static final tableColleagues = 'colleagues';
  static final tableCustomerProducts = 'customer_products';
  static final tableCustomerRelations = 'customer_relations';
  static final tableSales = 'sales';
  static final tableReminders = 'reminders';
  static final tableCustomerTags = 'customer_tags';

  // make this a singleton class
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Initialize database for all platforms
  static void initializeDatabase() {
    // Web platform: no initialization needed
    if (kIsWeb) return;
    // For Linux, Windows, and macOS platforms
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Initialize FFI for desktop platforms
      sqfliteFfiInit();
      // Set database factory to FFI
      databaseFactory = databaseFactoryFfi;
    }
    // For mobile platforms, database will be initialized automatically
  }

  // only have a single app-wide reference to the database
  static Database? _database;
  static Completer<Database>? _initCompleter;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<Database>();
    try {
      _database = await _initDatabase();
      _initCompleter!.complete(_database!);
      return _database!;
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  // this opens the database (and creates it if it doesn't exist)
  _initDatabase() async {
    // For web platform, use in-memory database
    if (kIsWeb) {
      return await openDatabase(
        ':memory:',
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } else {
      // For mobile platforms
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, _databaseName);
      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    // Create customers table
    await db.execute('''
          CREATE TABLE $tableCustomers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            alias TEXT,
            age INTEGER,
            gender TEXT,
            rating INTEGER,
            latitude REAL,
            longitude REAL,
            address TEXT,
            birthday TEXT,
            tags TEXT,
            photos TEXT,
            next_follow_up_date TEXT,
            created_at TEXT
          )''');

    // Create phones table
    await db.execute('''
          CREATE TABLE customer_phones (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            phone TEXT NOT NULL,
            FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id)
          )''');

    // Create addresses table
    await db.execute('''
          CREATE TABLE customer_addresses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            address TEXT NOT NULL,
            FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id)
          )''');

    // Create products table
    await db.execute('''
          CREATE TABLE $tableProducts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company TEXT NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            advantages TEXT,
            category TEXT,
            start_date TEXT,
            end_date TEXT,
            created_at TEXT
          )''');

    // Create visits table
    await db.execute('''
          CREATE TABLE $tableVisits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            location TEXT,
            accompanying_persons TEXT,
            introduced_products TEXT,
            interested_products TEXT,
            competitors TEXT,
            notes TEXT,
            FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id)
          )''');

    // Create sales table
    await db.execute('''
          CREATE TABLE $tableSales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            amount REAL,
            notes TEXT,
            sale_date TEXT NOT NULL,
            colleague_id INTEGER,
            commission_rate REAL,
            policy_number TEXT,
            policy_status TEXT DEFAULT '有效',
            payment_method TEXT,
            payment_term INTEGER,
            guarantee_period INTEGER,
            renewal_date TEXT,
            FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id),
            FOREIGN KEY (product_id) REFERENCES $tableProducts (id),
            FOREIGN KEY (colleague_id) REFERENCES $tableColleagues (id)
          )''');

    // Create colleagues table
    await db.execute('''
          CREATE TABLE $tableColleagues (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            specialty TEXT
          )''');

    // Create customer-products relationship table
    await db.execute('''
          CREATE TABLE $tableCustomerProducts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            purchase_date TEXT,
            FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id),
            FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
          )''');

    // Create customer-customer relationship table
    await db.execute('''
          CREATE TABLE $tableCustomerRelations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            related_customer_id INTEGER NOT NULL,
            relationship TEXT,
            FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id),
            FOREIGN KEY (related_customer_id) REFERENCES $tableCustomers (id)
          )''');

    // Create reminders table
    await db.execute('''
          CREATE TABLE $tableReminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            reminder_date TEXT NOT NULL,
            reminder_time TEXT,
            type TEXT NOT NULL DEFAULT 'follow_up',
            status TEXT NOT NULL DEFAULT 'pending',
            created_at TEXT,
            FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id)
          )''');

    // Create customer tags table
    await db.execute('''
          CREATE TABLE $tableCustomerTags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            tag TEXT NOT NULL,
            FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id)
          )''');

    // Create product_attachments table (v4)
    await db.execute('''
          CREATE TABLE IF NOT EXISTS product_attachments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            thumbnail_path TEXT,
            media_type TEXT NOT NULL DEFAULT 'image',
            file_name TEXT,
            created_at TEXT,
            FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
          )''');

    // Create users table (v5)
    await db.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            display_name TEXT,
            role TEXT NOT NULL DEFAULT 'user',
            security_question TEXT,
            security_answer_hash TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT,
            last_login TEXT
          )''');

    // Insert default admin account: admin / 123456
    final defaultAdminPasswordHash = hashPassword('123456');
    final defaultAdminSecurityAnswer = hashPassword('保险');
    await db.insert('users', {
      'username': 'admin',
      'password_hash': defaultAdminPasswordHash,
      'display_name': '系统管理员',
      'role': 'admin',
      'security_question': '您从事的行业是什么？',
      'security_answer_hash': defaultAdminSecurityAnswer,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Database upgrade
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add reminders table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableReminders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          reminder_date TEXT NOT NULL,
          reminder_time TEXT,
          type TEXT NOT NULL DEFAULT 'follow_up',
          status TEXT NOT NULL DEFAULT 'pending',
          created_at TEXT,
          FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id)
        )''');
    }
    if (oldVersion < 3) {
      // Add customer tags table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableCustomerTags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          tag TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id)
        )''');
    }
    if (oldVersion < 4) {
      // Add missing columns to customers table
      await db.execute('ALTER TABLE $tableCustomers ADD COLUMN photos TEXT');
      await db.execute('ALTER TABLE $tableCustomers ADD COLUMN birthday TEXT');
      await db.execute('ALTER TABLE $tableCustomers ADD COLUMN tags TEXT');
      await db.execute('ALTER TABLE $tableCustomers ADD COLUMN next_follow_up_date TEXT');

      // Create product_attachments table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_attachments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          file_path TEXT NOT NULL,
          thumbnail_path TEXT,
          media_type TEXT NOT NULL DEFAULT 'image',
          file_name TEXT,
          created_at TEXT,
          FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
        )''');
    }
    if (oldVersion < 5) {
      // Create users table for authentication system
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          display_name TEXT,
          role TEXT NOT NULL DEFAULT 'user',
          security_question TEXT,
          security_answer_hash TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT,
          last_login TEXT
        )''');

      // Insert default admin account: admin / 123456
      final defaultAdminPasswordHash = hashPassword('123456');
      final defaultAdminSecurityAnswer = hashPassword('保险');
      await db.insert('users', {
        'username': 'admin',
        'password_hash': defaultAdminPasswordHash,
        'display_name': '系统管理员',
        'role': 'admin',
        'security_question': '您从事的行业是什么？',
        'security_answer_hash': defaultAdminSecurityAnswer,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    if (oldVersion < 6) {
      // Fix: Ensure missing columns in customers table
      // v4 upgrade only added 'photos', but 'birthday', 'tags', 'next_follow_up_date' were missing
      try { await db.execute('ALTER TABLE $tableCustomers ADD COLUMN photos TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableCustomers ADD COLUMN birthday TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableCustomers ADD COLUMN tags TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableCustomers ADD COLUMN next_follow_up_date TEXT'); } catch (_) {}

      // Fix: Ensure users table exists (old _onCreate missed it for fresh installs)
      // and re-hash default admin password with consistent hashPassword() method
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          display_name TEXT,
          role TEXT NOT NULL DEFAULT 'user',
          security_question TEXT,
          security_answer_hash TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT,
          last_login TEXT
        )''');

      // Also ensure product_attachments table exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_attachments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          file_path TEXT NOT NULL,
          thumbnail_path TEXT,
          media_type TEXT NOT NULL DEFAULT 'image',
          file_name TEXT,
          created_at TEXT,
          FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
        )''');

      // Check if admin account exists
      final adminRows = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: ['admin'],
      );
      if (adminRows.isEmpty) {
        // No admin account — insert default one
        await db.insert('users', {
          'username': 'admin',
          'password_hash': hashPassword('123456'),
          'display_name': '系统管理员',
          'role': 'admin',
          'security_question': '您从事的行业是什么？',
          'security_answer_hash': hashPassword('保险'),
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Admin exists — fix password hash (old v5 used wrong hash method)
        await db.update(
          'users',
          {
            'password_hash': hashPassword('123456'),
            'security_answer_hash': hashPassword('保险'),
          },
          where: 'username = ?',
          whereArgs: ['admin'],
        );
      }
    }
    if (oldVersion < 7) {
      // Add missing columns to sales table (referenced by Sale model and statistics queries)
      try { await db.execute('ALTER TABLE $tableSales ADD COLUMN amount REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableSales ADD COLUMN policy_number TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableSales ADD COLUMN policy_status TEXT DEFAULT \'有效\''); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableSales ADD COLUMN payment_method TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableSales ADD COLUMN payment_term INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableSales ADD COLUMN guarantee_period INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE $tableSales ADD COLUMN renewal_date TEXT'); } catch (_) {}
    }
    if (oldVersion < 8) {
      // v8: Clean up stale/duplicate data from previous bugs
      // Delete all sample data so it can be cleanly re-inserted by addSampleCustomers()
      await db.delete(tableCustomerTags);
      await db.delete(tableCustomerRelations);
      await db.delete(tableCustomerProducts);
      await db.delete(tableSales);
      await db.delete(tableReminders);
      await db.delete(tableVisits);
      await db.delete(tableColleagues);
      await db.delete('customer_phones');
      await db.delete('customer_addresses');
      await db.delete(tableCustomers);
      // Also delete stale products so they can be re-created with proper IDs
      await db.delete(tableProducts);
    }
  }

  // Helper methods

  // Insert a customer into the database
  Future<int> insertCustomer(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableCustomers, row);
  }

  // Insert a phone for a customer
  Future<int> insertCustomerPhone(int customerId, String phone) async {
    Database db = await instance.database;
    return await db.insert('customer_phones', {
      'customer_id': customerId,
      'phone': phone,
    });
  }

  // Insert an address for a customer
  Future<int> insertCustomerAddress(int customerId, String address) async {
    Database db = await instance.database;
    return await db.insert('customer_addresses', {
      'customer_id': customerId,
      'address': address,
    });
  }

  // Get all customers
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    Database db = await instance.database;
    return await db.query(tableCustomers);
  }

  // Get customer by id
  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> results = await db.query(
      tableCustomers,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Get customer phones
  Future<List<String>> getCustomerPhones(int customerId) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> results = await db.query(
      'customer_phones',
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );
    return results.map((e) => e['phone'] as String).toList();
  }

  // Get customer addresses
  Future<List<String>> getCustomerAddresses(int customerId) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> results = await db.query(
      'customer_addresses',
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );
    return results.map((e) => e['address'] as String).toList();
  }

  // Update a customer
  Future<int> updateCustomer(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row['id'];
    return await db.update(
      tableCustomers,
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete a customer and all related records
  Future<int> deleteCustomer(int id) async {
    Database db = await instance.database;
    // Delete child records first to maintain referential integrity
    await db.delete(
      'customer_phones',
      where: 'customer_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      'customer_addresses',
      where: 'customer_id = ?',
      whereArgs: [id],
    );
    await db.delete(tableVisits, where: 'customer_id = ?', whereArgs: [id]);
    await db.delete(tableSales, where: 'customer_id = ?', whereArgs: [id]);
    await db.delete(
      tableCustomerProducts,
      where: 'customer_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      tableCustomerRelations,
      where: 'customer_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      tableCustomerRelations,
      where: 'related_customer_id = ?',
      whereArgs: [id],
    );
    return await db.delete(tableCustomers, where: 'id = ?', whereArgs: [id]);
  }

  // Insert a product
  Future<int> insertProduct(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableProducts, row);
  }

  // Get all products
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    Database db = await instance.database;
    return await db.query(tableProducts);
  }

  // Get product by id
  Future<Map<String, dynamic>?> getProductById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> results = await db.query(
      tableProducts,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Update a product
  Future<int> updateProduct(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row['id'];
    return await db.update(
      tableProducts,
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete a product
  Future<int> deleteProduct(int id) async {
    Database db = await instance.database;
    return await db.delete(tableProducts, where: 'id = ?', whereArgs: [id]);
  }

  // Insert a visit
  Future<int> insertVisit(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableVisits, row);
  }

  // Get visits for a customer
  Future<List<Map<String, dynamic>>> getCustomerVisits(int customerId) async {
    Database db = await instance.database;
    return await db.query(
      tableVisits,
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );
  }

  // Insert a colleague
  Future<int> insertColleague(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableColleagues, row);
  }

  // Get all colleagues
  Future<List<Map<String, dynamic>>> getAllColleagues() async {
    Database db = await instance.database;
    return await db.query(tableColleagues);
  }

  // Update a colleague
  Future<int> updateColleague(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row['id'];
    return await db.update(
      tableColleagues,
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete a colleague
  Future<int> deleteColleague(int id) async {
    Database db = await instance.database;
    return await db.delete(tableColleagues, where: 'id = ?', whereArgs: [id]);
  }

  // Insert customer-product relationship
  Future<int> insertCustomerProduct(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableCustomerProducts, row);
  }

  // Get customer products
  Future<List<Map<String, dynamic>>> getCustomerProducts(int customerId) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT p.*, cp.purchase_date
      FROM $tableProducts p
      JOIN $tableCustomerProducts cp ON p.id = cp.product_id
      WHERE cp.customer_id = ?
    ''',
      [customerId],
    );
  }

  // Insert customer relationship
  Future<int> insertCustomerRelationship(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableCustomerRelations, row);
  }

  // Get customer relationships
  Future<List<Map<String, dynamic>>> getCustomerRelationships(
    int customerId,
  ) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT c.*, cr.relationship
      FROM $tableCustomers c
      JOIN $tableCustomerRelations cr ON c.id = cr.related_customer_id
      WHERE cr.customer_id = ?
    ''',
      [customerId],
    );
  }

  // Insert a sale
  Future<int> insertSale(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableSales, row);
  }

  // Get sales for a customer
  Future<List<Map<String, dynamic>>> getCustomerSales(int customerId) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT s.*, p.name as product_name, c.name as colleague_name
      FROM $tableSales s
      JOIN $tableProducts p ON s.product_id = p.id
      LEFT JOIN $tableColleagues c ON s.colleague_id = c.id
      WHERE s.customer_id = ?
      ORDER BY s.sale_date DESC
    ''',
      [customerId],
    );
  }

  // Get visit efficiency analysis
  Future<List<Map<String, dynamic>>> getVisitEfficiencyAnalysis() async {
    Database db = await instance.database;
    return await db.rawQuery('''
      SELECT
        c.id as customer_id,
        c.name as customer_name,
        COUNT(v.id) as visit_count,
        COUNT(s.id) as sale_count,
        CASE COUNT(v.id)
          WHEN 0 THEN 0
          ELSE CAST(COUNT(s.id) AS REAL) * 100 / COUNT(v.id)
        END as conversion_per_visit
      FROM $tableCustomers c
      LEFT JOIN $tableVisits v ON c.id = v.customer_id
      LEFT JOIN $tableSales s ON c.id = s.customer_id
      GROUP BY c.id, c.name
      HAVING COUNT(v.id) > 0
      ORDER BY conversion_per_visit DESC
      ''');
  }

  // Get all sales
  Future<List<Map<String, dynamic>>> getAllSales() async {
    Database db = await instance.database;
    return await db.rawQuery('''
      SELECT s.*, c.name as customer_name, p.name as product_name, col.name as colleague_name
      FROM $tableSales s
      JOIN $tableCustomers c ON s.customer_id = c.id
      JOIN $tableProducts p ON s.product_id = p.id
      LEFT JOIN $tableColleagues col ON s.colleague_id = col.id
      ORDER BY s.sale_date DESC
    ''');
  }

  // Get all visits
  Future<List<Map<String, dynamic>>> getAllVisits() async {
    Database db = await instance.database;
    return await db.query(tableVisits, orderBy: 'date DESC');
  }

  // Insert a reminder
  Future<int> insertReminder(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tableReminders, row);
  }

  // Get all reminders
  Future<List<Map<String, dynamic>>> getAllReminders() async {
    Database db = await instance.database;
    return await db.rawQuery('''
      SELECT r.*, c.name as customer_name
      FROM $tableReminders r
      JOIN $tableCustomers c ON r.customer_id = c.id
      ORDER BY r.reminder_date ASC, r.reminder_time ASC
    ''');
  }

  // Get reminders by date
  Future<List<Map<String, dynamic>>> getRemindersByDate(String date) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT r.*, c.name as customer_name
      FROM $tableReminders r
      JOIN $tableCustomers c ON r.customer_id = c.id
      WHERE r.reminder_date = ?
      ORDER BY r.reminder_time ASC
    ''',
      [date],
    );
  }

  // Get pending reminders (not completed)
  Future<List<Map<String, dynamic>>> getPendingReminders() async {
    Database db = await instance.database;
    return await db.rawQuery('''
      SELECT r.*, c.name as customer_name
      FROM $tableReminders r
      JOIN $tableCustomers c ON r.customer_id = c.id
      WHERE r.status = 'pending'
      ORDER BY r.reminder_date ASC, r.reminder_time ASC
    ''');
  }

  // Get overdue reminders
  Future<List<Map<String, dynamic>>> getOverdueReminders() async {
    Database db = await instance.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return await db.rawQuery(
      '''
      SELECT r.*, c.name as customer_name
      FROM $tableReminders r
      JOIN $tableCustomers c ON r.customer_id = c.id
      WHERE r.status = 'pending' AND r.reminder_date < ?
      ORDER BY r.reminder_date ASC
    ''',
      [today],
    );
  }

  // Update a reminder
  Future<int> updateReminder(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row['id'];
    return await db.update(
      tableReminders,
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete a reminder
  Future<int> deleteReminder(int id) async {
    Database db = await instance.database;
    return await db.delete(tableReminders, where: 'id = ?', whereArgs: [id]);
  }

  // Get monthly sales summary
  Future<List<Map<String, dynamic>>> getMonthlySalesSummary(int year) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT
        CAST(strftime('%m', sale_date) AS INTEGER) as month,
        COUNT(*) as count,
        SUM(amount) as total_amount
      FROM $tableSales
      WHERE strftime('%Y', sale_date) = ?
      GROUP BY strftime('%m', sale_date)
      ORDER BY month
    ''',
      [year.toString()],
    );
  }

  // Get quarterly sales summary
  Future<List<Map<String, dynamic>>> getQuarterlySalesSummary(int year) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT
        CASE
          WHEN CAST(strftime('%m', sale_date) AS INTEGER) BETWEEN 1 AND 3 THEN 1
          WHEN CAST(strftime('%m', sale_date) AS INTEGER) BETWEEN 4 AND 6 THEN 2
          WHEN CAST(strftime('%m', sale_date) AS INTEGER) BETWEEN 7 AND 9 THEN 3
          ELSE 4
        END as quarter,
        COUNT(*) as count,
        SUM(amount) as total_amount
      FROM $tableSales
      WHERE strftime('%Y', sale_date) = ?
      GROUP BY quarter
      ORDER BY quarter
    ''',
      [year.toString()],
    );
  }

  // Get annual sales summary
  Future<List<Map<String, dynamic>>> getAnnualSalesSummary(int year) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT
        CAST(strftime('%Y', sale_date) AS INTEGER) as year,
        COUNT(*) as count,
        SUM(amount) as total_amount
      FROM $tableSales
      WHERE strftime('%Y', sale_date) = ?
      GROUP BY year
    ''',
      [year.toString()],
    );
  }

  // Get monthly visit summary
  Future<List<Map<String, dynamic>>> getMonthlyVisitSummary(int year) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT
        CAST(strftime('%m', date) AS INTEGER) as month,
        COUNT(*) as count
      FROM $tableVisits
      WHERE strftime('%Y', date) = ?
      GROUP BY strftime('%m', date)
      ORDER BY month
    ''',
      [year.toString()],
    );
  }

  // Get monthly commission summary
  Future<List<Map<String, dynamic>>> getMonthlyCommissionSummary(
    int year,
  ) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT
        CAST(strftime('%m', sale_date) AS INTEGER) as month,
        SUM(amount * commission_rate / 100) as total_commission
      FROM $tableSales
      WHERE strftime('%Y', sale_date) = ? AND commission_rate IS NOT NULL
      GROUP BY month
      ORDER BY month
    ''',
      [year.toString()],
    );
  }

  // Get quarterly commission summary
  Future<List<Map<String, dynamic>>> getQuarterlyCommissionSummary(
    int year,
  ) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT
        CASE
          WHEN CAST(strftime('%m', sale_date) AS INTEGER) BETWEEN 1 AND 3 THEN 1
          WHEN CAST(strftime('%m', sale_date) AS INTEGER) BETWEEN 4 AND 6 THEN 2
          WHEN CAST(strftime('%m', sale_date) AS INTEGER) BETWEEN 7 AND 9 THEN 3
          ELSE 4
        END as quarter,
        SUM(amount * commission_rate / 100) as total_commission
      FROM $tableSales
      WHERE strftime('%Y', sale_date) = ? AND commission_rate IS NOT NULL
      GROUP BY quarter
      ORDER BY quarter
    ''',
      [year.toString()],
    );
  }

  // Get annual commission summary
  Future<List<Map<String, dynamic>>> getAnnualCommissionSummary(
    int year,
  ) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT
        CAST(strftime('%Y', sale_date) AS INTEGER) as year,
        SUM(amount * commission_rate / 100) as total_commission
      FROM $tableSales
      WHERE strftime('%Y', sale_date) = ? AND commission_rate IS NOT NULL
      GROUP BY year
    ''',
      [year.toString()],
    );
  }

  // Get monthly new customer summary
  Future<List<Map<String, dynamic>>> getMonthlyNewCustomerSummary(
    int year,
  ) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT
        CAST(strftime('%m', created_at) AS INTEGER) as month,
        COUNT(*) as count
      FROM $tableCustomers
      WHERE strftime('%Y', created_at) = ?
      GROUP BY strftime('%m', created_at)
      ORDER BY month
    ''',
      [year.toString()],
    );
  }

  // Get product sales ranking
  Future<List<Map<String, dynamic>>> getProductSalesRanking() async {
    Database db = await instance.database;
    return await db.rawQuery('''
      SELECT
        p.name as product_name,
        p.category as product_category,
        COUNT(s.id) as sale_count,
        SUM(s.amount) as total_amount
      FROM $tableProducts p
      LEFT JOIN $tableSales s ON p.id = s.product_id
      GROUP BY p.id
      ORDER BY sale_count DESC, total_amount DESC
    ''');
  }

  // Get conversion funnel analysis
  Future<List<Map<String, dynamic>>> getConversionFunnelAnalysis() async {
    Database db = await instance.database;
    return await db.rawQuery('''
      SELECT
        rating,
        COUNT(*) as count,
        SUM(CASE WHEN EXISTS(
          SELECT 1 FROM $tableSales s WHERE s.customer_id = c.id
        ) THEN 1 ELSE 0 END) as converted_count,
        CASE COUNT(*)
          WHEN 0 THEN 0
          ELSE CAST(SUM(CASE WHEN EXISTS(
            SELECT 1 FROM $tableSales s WHERE s.customer_id = c.id
          ) THEN 1 ELSE 0 END) AS REAL) * 100 / COUNT(*)
        END as conversion_rate
      FROM $tableCustomers c
      GROUP BY rating
      ORDER BY rating DESC
      ''');
  }

  // Get customer rating distribution
  Future<List<Map<String, dynamic>>> getCustomerRatingDistribution() async {
    Database db = await instance.database;
    return await db.rawQuery('''
      SELECT
        COALESCE(rating, 0) as rating,
        COUNT(*) as count
      FROM $tableCustomers
      GROUP BY rating
      ORDER BY rating DESC
    ''');
  }

  // ===== Visit CRUD =====

  // Update a visit
  Future<int> updateVisit(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row['id'];
    return await db.update(tableVisits, row, where: 'id = ?', whereArgs: [id]);
  }

  // Delete a visit
  Future<int> deleteVisit(int id) async {
    Database db = await instance.database;
    return await db.delete(tableVisits, where: 'id = ?', whereArgs: [id]);
  }

  // ===== Sale CRUD =====

  // Update a sale
  Future<int> updateSale(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row['id'];
    return await db.update(tableSales, row, where: 'id = ?', whereArgs: [id]);
  }

  // Delete a sale
  Future<int> deleteSale(int id) async {
    Database db = await instance.database;
    return await db.delete(tableSales, where: 'id = ?', whereArgs: [id]);
  }

  // ===== Customer Relationship =====

  // Delete a customer relationship
  Future<int> deleteCustomerRelationship(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableCustomerRelations,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete customer product association
  Future<int> deleteCustomerProduct(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableCustomerProducts,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ===== Customer Tags =====

  // Insert a tag for a customer
  Future<int> insertCustomerTag(int customerId, String tag) async {
    Database db = await instance.database;
    return await db.insert(tableCustomerTags, {
      'customer_id': customerId,
      'tag': tag,
    });
  }

  // Get tags for a customer
  Future<List<String>> getCustomerTags(int customerId) async {
    Database db = await instance.database;
    final results = await db.query(
      tableCustomerTags,
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );
    return results.map((e) => e['tag'] as String).toList();
  }

  // Delete a customer tag
  Future<int> deleteCustomerTag(int customerId, String tag) async {
    Database db = await instance.database;
    return await db.delete(
      tableCustomerTags,
      where: 'customer_id = ? AND tag = ?',
      whereArgs: [customerId, tag],
    );
  }

  // Delete all tags for a customer
  Future<int> deleteAllCustomerTags(int customerId) async {
    Database db = await instance.database;
    return await db.delete(
      tableCustomerTags,
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );
  }

  // Get all unique tags
  Future<List<String>> getAllUniqueTags() async {
    Database db = await instance.database;
    final results = await db.rawQuery(
      'SELECT DISTINCT tag FROM $tableCustomerTags ORDER BY tag',
    );
    return results.map((e) => e['tag'] as String).toList();
  }

  // Get customers by tag
  Future<List<Map<String, dynamic>>> getCustomersByTag(String tag) async {
    Database db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT c.* FROM $tableCustomers c
      JOIN $tableCustomerTags ct ON c.id = ct.customer_id
      WHERE ct.tag = ?
      ORDER BY c.name
    ''',
      [tag],
    );
  }

  // Close database connection
  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
    _initCompleter = null;
  }

  // Get database file path
  Future<String> getDatabasePath() async {
    if (kIsWeb) {
      return ':memory:';
    } else {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      return join(documentsDirectory.path, _databaseName);
    }
  }

  // Export database
  Future<File> exportDatabase() async {
    if (kIsWeb) {
      // For web platform, throw an exception
      throw Exception('Export functionality not supported on web');
    } else {
      String dbPath = await getDatabasePath();
      File dbFile = File(dbPath);

      // Create export directory if it doesn't exist
      Directory exportDir = Directory(
        join(
          await getApplicationDocumentsDirectory().then((dir) => dir.path),
          'exports',
        ),
      );
      if (!exportDir.existsSync()) {
        exportDir.createSync(recursive: true);
      }

      // Create export file with timestamp
      String timestamp = DateTime.now().toString().replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      String exportPath = join(exportDir.path, 'insurance_app_$timestamp.db');
      File exportFile = File(exportPath);

      // Copy database file to export location
      await dbFile.copy(exportPath);
      return exportFile;
    }
  }

  // Import database
  Future<bool> importDatabase(File importFile) async {
    if (kIsWeb) {
      // For web platform, return false
      return false;
    } else {
      try {
        String dbPath = await getDatabasePath();

        // Close database if it's open
        if (_database != null && _database!.isOpen) {
          await _database!.close();
          _database = null;
        }

        // Copy import file to database location
        await importFile.copy(dbPath);

        // Reopen database
        await instance.database;
        return true;
      } catch (e) {
        AppLogger.error('importing database: $e');
        return false;
      }
    }
  }

  // ===== Product Attachments =====

  Future<int> insertProductAttachment(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('product_attachments', row);
  }

  Future<List<Map<String, dynamic>>> getProductAttachments(
    int productId,
  ) async {
    Database db = await instance.database;
    return await db.query(
      'product_attachments',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'id ASC',
    );
  }

  Future<void> deleteProductAttachment(int id) async {
    Database db = await instance.database;
    // Get file paths to delete physical files
    final results = await db.query(
      'product_attachments',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isNotEmpty) {
      final path = results.first['file_path'] as String?;
      final thumbPath = results.first['thumbnail_path'] as String?;
      try {
        if (path != null) File(path).delete();
      } catch (_) {}
      try {
        if (thumbPath != null) File(thumbPath).delete();
      } catch (_) {}
    }
    await db.delete('product_attachments', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteProductAttachmentsByProductId(int productId) async {
    Database db = await instance.database;
    final results = await db.query(
      'product_attachments',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    for (var r in results) {
      final path = r['file_path'] as String?;
      final thumbPath = r['thumbnail_path'] as String?;
      try {
        if (path != null) File(path).delete();
      } catch (_) {}
      try {
        if (thumbPath != null) File(thumbPath).delete();
      } catch (_) {}
    }
    await db.delete(
      'product_attachments',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  // ===== Password Hashing =====

  /// Public method for password hashing
  static String hashPassword(String password) {
    // Use a more robust approach with multiple rounds
    String result = password + 'insurecrm_salt_v2';
    for (int i = 0; i < 100; i++) {
      result = result.split('').reversed.join() + i.toString();
      int h = 0;
      for (int j = 0; j < result.length; j++) {
        h = ((h << 5) - h) + result.codeUnitAt(j);
        h = h & 0xffffffff;
      }
      result = '${h.toRadixString(16).padLeft(8, '0')}_$result';
    }
    // Final SHA-like digest simulation
    final bytes = result.codeUnits;
    int hash1 = 0xcbf29ce4;
    for (final byte in bytes) {
      hash1 ^= byte;
      hash1 = (hash1 * 0x010001b3) & 0x7fffffff;
    }
    return hash1.toRadixString(16).padLeft(8, '0');
  }

  // ===== User Authentication CRUD =====

  /// Register a new user. Returns (success, errorMessage).
  Future<(bool success, String message)> registerUser({
    required String username,
    required String displayName,
    required String password,
    required String securityQuestion,
    required String securityAnswer,
    String role = 'user',
  }) async {
    Database db = await instance.database;

    // Check if username already exists
    final existing = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (existing.isNotEmpty) {
      return (false, '用户名已存在');
    }

    await db.insert('users', {
      'username': username,
      'password_hash': hashPassword(password),
      'display_name': displayName,
      'role': role,
      'security_question': securityQuestion,
      'security_answer_hash': hashPassword(securityAnswer),
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    return (true, '');
  }

  /// Validate login credentials. Returns User map on success, null on failure.
  Future<Map<String, dynamic>?> validateLogin(
    String username,
    String password,
  ) async {
    Database db = await instance.database;

    final results = await db.query(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username],
    );

    if (results.isEmpty) {
      return null;
    }

    final storedHash = results.first['password_hash'] as String?;
    if (storedHash == null) {
      return null;
    }

    final inputHash = hashPassword(password);
    if (inputHash != storedHash) {
      return null;
    }

    // Update last_login
    await db.update(
      'users',
      {'last_login': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [results.first['id']],
    );

    return results.first;
  }

  /// Get user by ID
  Future<Map<String, dynamic>?> getUserById(int id) async {
    Database db = await instance.database;
    final results = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  /// Get all users (for admin management)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    Database db = await instance.database;
    return await db.query(
      'users',
      orderBy: 'id ASC',
      columns: [
        'id',
        'username',
        'display_name',
        'role',
        'is_active',
        'created_at',
        'last_login',
      ],
    );
  }

  /// Update user role
  Future<void> updateUserRole(int userId, String newRole) async {
    Database db = await instance.database;
    await db.update(
      'users',
      {'role': newRole},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Reset password via security question verification
  Future<(bool success, String message)> resetPassword({
    required String username,
    required String securityAnswer,
    required String newPassword,
  }) async {
    Database db = await instance.database;

    final results = await db.query(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username],
    );

    if (results.isEmpty) {
      return (false, '用户不存在或已禁用');
    }

    final storedAnswerHash = results.first['security_answer_hash'] as String?;
    if (storedAnswerHash == null || storedAnswerHash.isEmpty) {
      return (false, '该账号未设置安全问题，请联系管理员重置密码');
    }

    final inputAnswerHash = hashPassword(securityAnswer);
    if (inputAnswerHash != storedAnswerHash) {
      return (false, '安全问题的答案不正确');
    }

    await db.update(
      'users',
      {'password_hash': hashPassword(newPassword)},
      where: 'id = ?',
      whereArgs: [results.first['id']],
    );

    return (true, '密码重置成功');
  }

  /// Change current user's password
  Future<(bool success, String message)> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    Database db = await instance.database;

    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
    if (results.isEmpty) {
      return (false, '用户不存在');
    }

    final storedHash = results.first['password_hash'] as String?;
    if (hashPassword(oldPassword) != storedHash) {
      return (false, '原密码不正确');
    }

    await db.update(
      'users',
      {'password_hash': hashPassword(newPassword)},
      where: 'id = ?',
      whereArgs: [userId],
    );

    return (true, '密码修改成功');
  }

  /// Delete a user
  Future<void> deleteUser(int id) async {
    Database db = await instance.database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
