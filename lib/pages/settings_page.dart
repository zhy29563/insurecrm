import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';
import 'package:insurecrm/models/colleague.dart';
import 'package:insurecrm/pages/colleague_management_page.dart';
import 'package:insurecrm/database/database_helper.dart';
import 'package:insurecrm/pages/login_page.dart';
import 'package:insurecrm/pages/backup_restore_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _doubaoApiKeyController = TextEditingController();
  final _qianwenApiKeyController = TextEditingController();
  String _selectedAiEngine = '豆包';
  final List<String> _aiEngines = ['豆包', '千问', 'GPT', 'Gemini', 'Claude'];

  @override
  void dispose() {
    _doubaoApiKeyController.dispose();
    _qianwenApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // 外观设置
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.palette_rounded,
            iconColor: Color(0xFFAB47BC),
            title: '外观设置',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('深色模式'),
                subtitle: Text('减少夜间使用对眼睛的刺激'),
                secondary: Icon(
                  appState.darkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: appState.darkMode
                      ? Color(0xFFFFB74D)
                      : Color(0xFFFFA726),
                ),
                value: appState.darkMode,
                activeColor: primaryColor,
                onChanged: (value) => appState.toggleDarkMode(value),
              ),
            ],
          ),
          SizedBox(height: 16),

          // AI引擎配置
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.smart_toy_rounded,
            iconColor: Color(0xFF1E88E5),
            title: 'AI引擎配置',
            children: [
              DropdownButtonFormField<String>(
                value: _selectedAiEngine,
                decoration: InputDecoration(
                  labelText: '选择AI引擎',
                  prefixIcon: Icon(Icons.memory_rounded, color: primaryColor),
                ),
                items: _aiEngines.map((engine) {
                  return DropdownMenuItem(value: engine, child: Text(engine));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAiEngine = value!;
                  });
                },
              ),
              SizedBox(height: 12),
              if (_selectedAiEngine == '豆包')
                _buildApiKeyField(
                  controller: _doubaoApiKeyController,
                  label: '豆包 API Key',
                  onSave: () {
                    appState.updateAIConfig('doubao', {
                      'apiKey': _doubaoApiKeyController.text,
                      'enabled': true,
                    });
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('豆包AI引擎配置已更新')));
                  },
                  primaryColor: primaryColor,
                ),
              if (_selectedAiEngine == '千问')
                _buildApiKeyField(
                  controller: _qianwenApiKeyController,
                  label: '千问 API Key',
                  onSave: () {
                    appState.updateAIConfig('qianwen', {
                      'apiKey': _qianwenApiKeyController.text,
                      'enabled': true,
                    });
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('千问AI引擎配置已更新')));
                  },
                  primaryColor: primaryColor,
                ),
              if (!['豆包', '千问'].contains(_selectedAiEngine))
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.construction_rounded,
                        size: 20,
                        color: Colors.grey,
                      ),
                      SizedBox(width: 10),
                      Text(
                        '该AI引擎配置功能开发中',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),

          // 同事管理
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.group_rounded,
            iconColor: Color(0xFF43A047),
            title: '同事管理',
            children: [
              Text(
                '管理同事信息，包括添加、编辑和删除同事资料',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ColleagueManagementPage(),
                      ),
                    );
                  },
                  icon: Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text('进入同事管理页面'),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // 数据备份与同步
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.cloud_sync_rounded,
            iconColor: Color(0xFF0288D1),
            title: '数据备份与同步',
            children: [
              Text(
                '自动定时本地备份、数据恢复、云端备份分享',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BackupRestorePage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0288D1),
                  ),
                  icon: Icon(Icons.backup_table_rounded, size: 18),
                  label: Text('进入备份管理'),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // 数据库管理
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.storage_rounded,
            iconColor: Color(0xFFFF7043),
            title: '数据库管理',
            children: [
              Text(
                '管理数据库文件，包括导出和导入数据',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final dbHelper = DatabaseHelper.instance;
                          final exportFile = await dbHelper.exportDatabase();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('数据库已导出到: ${exportFile.path}'),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('导出数据库失败: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1565C0),
                      ),
                      icon: Icon(Icons.download_rounded, size: 18),
                      label: Text('导出DB'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('导入功能在当前平台暂不可用')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00897B),
                      ),
                      icon: Icon(Icons.upload_rounded, size: 18),
                      label: Text('导入'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _exportCSV(context, appState, 'customers'),
                      icon: Icon(Icons.table_chart_rounded, size: 18),
                      label: Text('导出客户CSV'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _exportCSV(context, appState, 'products'),
                      icon: Icon(Icons.table_chart_rounded, size: 18),
                      label: Text('导出产品CSV'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),

          // 关于
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.info_rounded,
            iconColor: Color(0xFF78909C),
            title: '关于',
            children: [
              _buildAboutRow('版本', '1.0.0'),
              Divider(height: 20),
              _buildAboutRow('应用', '保险管理系统 v1.0'),
              Divider(height: 20),
              _buildAboutRow('版权', '© 2026 保险管理系统'),
            ],
          ),
          SizedBox(height: 24),

          // 退出登录
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final appState = Provider.of<AppState>(context, listen: false);
                appState.logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE53935),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '退出登录',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildApiKeyField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onSave,
    required Color primaryColor,
  }) {
    return Column(
      children: [
        TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(Icons.key_rounded, color: primaryColor),
          ),
        ),
        SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onSave,
            icon: Icon(Icons.save_rounded),
            label: Text('保存配置'),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _exportCSV(
    BuildContext context,
    AppState appState,
    String type,
  ) async {
    try {
      String csvContent;
      String fileName;

      if (type == 'customers') {
        fileName = 'customers_export.csv';
        final header = '姓名,别名,年龄,性别,评级,电话,地址,标签,创建时间';
        final rows = appState.customers
            .map((c) {
              final phones = c.phones.join('; ');
              final addresses = c.addresses.join('; ');
              final tags = c.tagList.join('; ');
              return '"${c.name}","${c.alias ?? ''}","${c.age ?? ''}","${c.gender ?? ''}","${c.rating ?? ''}","$phones","$addresses","$tags","${c.createdAt ?? ''}"';
            })
            .join('\n');
        csvContent = '$header\n$rows';
      } else {
        fileName = 'products_export.csv';
        final header = '公司,名称,描述,优势,分类,开始日期,结束日期,创建时间';
        final rows = appState.products
            .map((p) {
              return '"${p.company}","${p.name}","${p.description ?? ''}","${p.advantages ?? ''}","${p.category ?? ''}","${p.startDate ?? ''}","${p.endDate ?? ''}","${p.createdAt ?? ''}"';
            })
            .join('\n');
        csvContent = '$header\n$rows';
      }

      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${directory.path}/exports');
      if (!exportDir.existsSync()) {
        exportDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().toString().replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      final file = File('${exportDir.path}/${type}_$timestamp.csv');
      await file.writeAsString(csvContent);

      try {
        await Share.shareXFiles([XFile(file.path)], subject: '$type 导出');
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV已导出到: ${file.path}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出CSV失败: $e')));
    }
  }
}
