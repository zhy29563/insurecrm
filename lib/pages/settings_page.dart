import 'package:insurance_manager/widgets/app_components.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/pages/colleague_management_page.dart';
import 'package:insurance_manager/database/database_helper.dart';
import 'package:insurance_manager/pages/login_page.dart';
import 'package:insurance_manager/pages/backup_restore_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _amapApiKeyController = TextEditingController();
  final _amapApiKeyIOSController = TextEditingController();
  final _newRelLabelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = Provider.of<AppState>(context, listen: false);
      _amapApiKeyController.text = appState.amapApiKey;
      _amapApiKeyIOSController.text = appState.amapApiKeyIOS;
    });
  }

  @override
  void dispose() {
    _amapApiKeyController.dispose();
    _amapApiKeyIOSController.dispose();
    _newRelLabelController.dispose();
    super.dispose();
  }

  Color _relLabelColor(String label) => AppDesign.cnRelColor(label);

  Future<bool> _addRelationshipLabel(String value, AppState appState) async {
    final label = value.trim();
    if (label.isEmpty) return false;
    if (appState.relationshipLabels.contains(label)) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('标签「$label」已存在')),
      );
      return false;
    }
    await appState.addRelationshipLabel(label);
    if (!mounted) return false;
    // No setState needed - Provider.of<AppState>(context) in build() will auto-rebuild
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加标签「$label」')),
    );
    return true;
  }

  void _showAddRelationshipLabelDialog(AppState appState) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('添加关系标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '标签名称',
            hintText: '例如: 师生、合作伙伴、亲属',
            prefixIcon: Icon(Icons.label),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await _addRelationshipLabel(controller.text, appState);
              if (success && ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFE53935)),
            child: Text('添加'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showAddAIDialog({String? editKey, String category = 'chat'}) {
    final appState = Provider.of<AppState>(context, listen: false);
    final pageContext = context;  // Capture page-level context before dialog
    final nameController = TextEditingController();
    final apiKeyController = TextEditingController();
    final baseUrlController = TextEditingController();
    final modelController = TextEditingController();

    final isASR = category == 'asr';
    final categoryLabel = isASR ? '语音识别(ASR)' : '对话分析';

    // 编辑模式填充已有数据
    bool wasEnabled = true;
    if (editKey != null && appState.aiProviderConfigs.containsKey(editKey)) {
      final rawConfig = appState.aiProviderConfigs[editKey];
      if (rawConfig is Map<String, dynamic>) {
        nameController.text = rawConfig['name']?.toString() ?? editKey;
        apiKeyController.text = rawConfig['apiKey']?.toString() ?? '';
        baseUrlController.text = rawConfig['baseUrl']?.toString() ?? '';
        modelController.text = rawConfig['model']?.toString() ?? '';
        wasEnabled = rawConfig['enabled'] == true || rawConfig['enabled'] == 1;
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(editKey != null ? '编辑AI引擎' : '添加$categoryLabel引擎'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '引擎名称 *',
                      hintText: isASR ? '例如: 豆包ASR、讯飞ASR' : '例如: 豆包、千问、GPT、Claude',
                      prefixIcon: Icon(Icons.label),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: apiKeyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'API Key *',
                      hintText: '输入 API Key',
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: baseUrlController,
                    decoration: InputDecoration(
                      labelText: 'Base URL（可选）',
                      hintText: isASR ? '例如: https://openspeech.bytedance.com/v1' : '例如: https://api.openai.com/v1',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: modelController,
                    decoration: InputDecoration(
                      labelText: '模型名称（可选）',
                      hintText: isASR ? '例如: asr-pro' : '例如: gpt-4o, qwen-max',
                      prefixIcon: Icon(Icons.psychology),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    apiKeyController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(content: Text('请填写引擎名称和API Key')),
                  );
                  return;
                }
                // 生成唯一 key
                final key = editKey ??
                    nameController.text.trim().toLowerCase().replaceAll(' ', '_');
                // 检查 key 是否已存在（仅新增模式）
                if (editKey == null && appState.aiProviderConfigs.containsKey(key)) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(content: Text('名为「${nameController.text.trim()}」的引擎已存在，请使用不同名称')),
                  );
                  return;
                }
                await appState.updateAIConfig(key, {
                  'name': nameController.text.trim(),
                  'apiKey': apiKeyController.text.trim(),
                  'baseUrl': baseUrlController.text.trim(),
                  'model': modelController.text.trim(),
                  'category': category,
                  'enabled': editKey != null ? wasEnabled : true,
                });
                if (!context.mounted) return;
                Navigator.pop(context);
                // No setState needed - Provider will auto-rebuild
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(content: Text(editKey != null ? 'AI引擎配置已更新' : '$categoryLabel引擎已添加')),
                );
              },
              child: Text(editKey != null ? '更新' : '添加'),
            ),
          ],
        ),
      ),
    ).then((_) {
      nameController.dispose();
      apiKeyController.dispose();
      baseUrlController.dispose();
      modelController.dispose();
    });
  }

  void _confirmDeleteAI(String key, String name) {
    final pageContext = context;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除AI引擎「$name」的配置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final appState = Provider.of<AppState>(pageContext, listen: false);
              await appState.deleteAIConfig(key);
              if (!context.mounted) return;
              Navigator.pop(context);
              // No setState needed - Provider will auto-rebuild
              ScaffoldMessenger.of(pageContext).showSnackBar(
                SnackBar(content: Text('已删除AI引擎「$name」')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('删除'),
          ),
        ],
      ),
    );
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
                activeThumbColor: primaryColor,
                onChanged: (value) => appState.toggleDarkMode(value),
              ),
            ],
          ),
          SizedBox(height: 16),

          // 高德地图配置
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.map_rounded,
            iconColor: Color(0xFF43A047),
            title: '高德地图配置',
            children: [
              Text(
                '地图功能使用高德地图 SDK。请前往高德开放平台 (lbs.amap.com) '
                '注册账号，创建应用并获取 Android/iOS 平台的 API Key。',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (appState.hasAmapApiKey
                          ? Color(0xFF43A047)
                          : Color(0xFFFF9800))
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      appState.hasAmapApiKey
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      size: 20,
                      color: appState.hasAmapApiKey
                          ? Color(0xFF43A047)
                          : Color(0xFFFF9800),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appState.hasAmapApiKey
                            ? 'API Key 已配置，地图功能可用'
                            : 'API Key 未配置，地图功能将不可用',
                        style: TextStyle(
                          fontSize: 13,
                          color: appState.hasAmapApiKey
                              ? Color(0xFF43A047)
                              : Color(0xFFFF9800),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14),
              TextField(
                controller: _amapApiKeyController,
                decoration: InputDecoration(
                  labelText: 'Android API Key',
                  hintText: '输入高德地图 Android 平台 Key',
                  prefixIcon: Icon(Icons.android_rounded, color: primaryColor),
                  suffixIcon: _amapApiKeyController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _amapApiKeyController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _amapApiKeyIOSController,
                decoration: InputDecoration(
                  labelText: 'iOS API Key（可选）',
                  hintText: '输入高德地图 iOS 平台 Key',
                  prefixIcon: Icon(Icons.phone_iphone_rounded, color: primaryColor),
                  suffixIcon: _amapApiKeyIOSController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _amapApiKeyIOSController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await appState.setAmapApiKey(
                        _amapApiKeyController.text.trim());
                    await appState.setAmapApiKeyIOS(
                        _amapApiKeyIOSController.text.trim());
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(appState.hasAmapApiKey
                            ? 'API Key 已保存'
                            : 'API Key 已清除'),
                      ),
                    );
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF43A047),
                  ),
                  icon: Icon(Icons.save_rounded),
                  label: Text('保存 API Key'),
                ),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.shade900.withValues(alpha: 0.3)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isDark
                          ? Colors.blue.shade800.withValues(alpha: 0.5)
                          : Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                        SizedBox(width: 6),
                        Text('配置说明',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• 前往 lbs.amap.com 注册并创建应用\n'
                      '• 分别获取 Android 和 iOS 平台的 Key\n'
                      '• 保存后地图功能即可使用',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // AI语音ASR配置
          _buildAICategorySection(
            isDark: isDark,
            appState: appState,
            category: 'asr',
            icon: Icons.mic_rounded,
            iconColor: Color(0xFFFF6D00),
            title: 'AI语音识别(ASR)配置',
            description: '配置语音识别引擎，用于产品推荐中的语音输入识别。支持兼容 OpenAI Whisper API 格式的ASR服务。',
            emptyHint: '暂未配置ASR引擎',
            emptySubHint: '添加ASR引擎后，可在产品推荐中使用语音输入',
            addLabel: '添加ASR引擎',
            presetChips: [
              _buildPresetChip('豆包ASR', 'doubao_asr', Icons.local_fire_department, Color(0xFFFF6D00), category: 'asr', appState: appState, isDark: isDark),
              _buildPresetChip('讯飞ASR', 'xfyun_asr', Icons.record_voice_over, Color(0xFF0066CC), category: 'asr', appState: appState, isDark: isDark),
            ],
          ),
          SizedBox(height: 16),

          // AI对话配置
          _buildAICategorySection(
            isDark: isDark,
            appState: appState,
            category: 'chat',
            icon: Icons.smart_toy_rounded,
            iconColor: Color(0xFF1E88E5),
            title: 'AI对话分析配置',
            description: '配置对话分析引擎，用于产品推荐中的智能分析和推荐。支持兼容 OpenAI Chat API 格式的AI服务。',
            emptyHint: '暂未配置对话引擎',
            emptySubHint: '添加对话引擎后，可在产品推荐中使用AI分析',
            addLabel: '添加对话引擎',
            presetChips: [
              _buildPresetChip('豆包', 'doubao', Icons.local_fire_department, Color(0xFFFF6D00), appState: appState, isDark: isDark),
              _buildPresetChip('千问', 'qianwen', Icons.auto_awesome, Color(0xFF6A1B9A), appState: appState, isDark: isDark),
              _buildPresetChip('GPT', 'gpt', Icons.psychology, Color(0xFF10A37F), appState: appState, isDark: isDark),
              _buildPresetChip('Claude', 'claude', Icons.smart_toy, Color(0xFFD97757), appState: appState, isDark: isDark),
              _buildPresetChip('Gemini', 'gemini', Icons.diamond, Color(0xFF4285F4), appState: appState, isDark: isDark),
            ],
          ),
          SizedBox(height: 16),

          // 关系标签管理
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.label_important_rounded,
            iconColor: Color(0xFFE53935),
            title: '关系标签管理',
            children: [
              Text(
                '管理客户关系标签，添加关系时可从中选择。自定义标签会保存到本地。',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              SizedBox(height: 14),
              // 当前标签列表
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: appState.relationshipLabels.map<Widget>((label) {
                  return Chip(
                    label: Text(label, style: TextStyle(fontSize: 13)),
                    backgroundColor: _relLabelColor(label).withValues(alpha: 0.1),
                    side: BorderSide(color: _relLabelColor(label).withValues(alpha: 0.3)),
                    deleteIconColor: Colors.grey.shade500,
                    onDeleted: () async {
                      if (appState.relationshipLabels.length <= 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('至少保留一个关系标签')),
                        );
                        return;
                      }
                      await appState.removeRelationshipLabel(label);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已删除标签「$label」')),
                      );
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 14),
              // 添加新标签
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newRelLabelController,
                      decoration: InputDecoration(
                        labelText: '新标签名称',
                        hintText: '输入关系标签',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (value) async {
                        final success = await _addRelationshipLabel(value, appState);
                        if (success) _newRelLabelController.clear();
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final text = _newRelLabelController.text.trim();
                      if (text.isNotEmpty) {
                        final success = await _addRelationshipLabel(text, appState);
                        if (success) _newRelLabelController.clear();
                      }
                    },
                    icon: Icon(Icons.add_rounded, size: 18),
                    label: Text('添加'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFE53935),
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              // 重置按钮
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('重置关系标签'),
                        content: Text('确定要恢复默认关系标签吗？自定义添加的标签将被移除。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('取消'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFE53935)),
                            child: Text('重置'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await appState.resetRelationshipLabels();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('关系标签已重置为默认')),
                      );
                    }
                  },
                  icon: Icon(Icons.restore_rounded, size: 16),
                  label: Text('恢复默认标签', style: TextStyle(fontSize: 13)),
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
                      onPressed: kIsWeb ? null : () async {
                        try {
                          final dbHelper = DatabaseHelper.instance;
                          final exportFile = await dbHelper.exportDatabase();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('数据库已导出到: ${exportFile.path}'),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
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
                      onPressed: kIsWeb ? null : () => _importDatabase(context),
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
                      onPressed: kIsWeb ? null : () =>
                          _exportCSV(context, appState, 'customers'),
                      icon: Icon(Icons.table_chart_rounded, size: 18),
                      label: Text('导出客户CSV'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: kIsWeb ? null : () =>
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
              _buildAboutRow('应用', '保险经纪人 v1.0'),
              Divider(height: 20),
              _buildAboutRow('版权', '© 2026 保险经纪人'),
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
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (route) => false,
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

  Widget _buildPresetChip(String label, String key, IconData icon, Color color, {String category = 'chat', required AppState appState, required bool isDark}) {
    final alreadyAdded = appState.aiProviderConfigs.containsKey(key);

    return InkWell(
      onTap: alreadyAdded
          ? null
          : () {
              _showAddAIDialogWithPreset(key, label, category: category);
            },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: alreadyAdded
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: alreadyAdded
                ? (isDark ? Colors.grey.shade700 : Colors.grey.shade300)
                : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: alreadyAdded ? Colors.grey : color),
            SizedBox(width: 6),
            Text(
              alreadyAdded ? '$label (已添加)' : label,
              style: TextStyle(
                fontSize: 13,
                color: alreadyAdded ? Colors.grey : color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAIDialogWithPreset(String key, String name, {String category = 'chat'}) {
    final pageContext = context;
    final apiKeyController = TextEditingController();
    final baseUrlController = TextEditingController();
    final modelController = TextEditingController();

    // 预设 Base URL
    final presetUrls = {
      'doubao': 'https://ark.cn-beijing.volces.com/api/v3',
      'doubao_asr': 'https://openspeech.bytedance.com/api/v1',
      'xfyun_asr': 'https://iat-api.xfyun.cn/v2',
      'qianwen': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      'gpt': 'https://api.openai.com/v1',
      'claude': 'https://api.anthropic.com/v1',
      'gemini': 'https://generativelanguage.googleapis.com/v1beta',
    };
    final presetModels = {
      'doubao': 'doubao-pro-4k',
      'doubao_asr': 'asr-pro',
      'xfyun_asr': 'iat-16k',
      'qianwen': 'qwen-max',
      'gpt': 'gpt-4o',
      'claude': 'claude-3-5-sonnet-20241022',
      'gemini': 'gemini-1.5-pro',
    };

    baseUrlController.text = presetUrls[key] ?? '';
    modelController.text = presetModels[key] ?? '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.smart_toy_rounded, color: Color(0xFF1E88E5)),
              SizedBox(width: 8),
              Text('配置 $name'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: apiKeyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'API Key *',
                      hintText: '输入 $name 的 API Key',
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: baseUrlController,
                    decoration: InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'API 服务地址',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: modelController,
                    decoration: InputDecoration(
                      labelText: '模型名称',
                      hintText: '使用的模型',
                      prefixIcon: Icon(Icons.psychology),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (apiKeyController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(content: Text('请填写API Key')),
                  );
                  return;
                }
                final appState = Provider.of<AppState>(context, listen: false);
                // Check if key already exists
                if (appState.aiProviderConfigs.containsKey(key)) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(content: Text('$name 引擎已存在')),
                  );
                  return;
                }
                await appState.updateAIConfig(key, {
                  'name': name,
                  'apiKey': apiKeyController.text.trim(),
                  'baseUrl': baseUrlController.text.trim(),
                  'model': modelController.text.trim(),
                  'category': category,
                  'enabled': true,
                });
                if (!context.mounted) return;
                Navigator.pop(context);
                // No setState needed - Provider will auto-rebuild
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(content: Text('$name 引擎已配置')),
                );
              },
              child: Text('保存'),
            ),
          ],
        ),
      ),
    ).then((_) {
      apiKeyController.dispose();
      baseUrlController.dispose();
      modelController.dispose();
    });
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
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                  color: iconColor.withValues(alpha: 0.12),
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

  Widget _buildAICategorySection({
    required bool isDark,
    required AppState appState,
    required String category,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String emptyHint,
    required String emptySubHint,
    required String addLabel,
    required List<Widget> presetChips,
  }) {
    // 筛选当前分类的配置
    final categoryConfigs = appState.aiProviderConfigs.entries
        .where((e) => e.value is Map<String, dynamic>)
        .map((e) => MapEntry(e.key, e.value as Map<String, dynamic>))
        .where((e) => (e.value['category'] ?? 'chat') == category)
        .toList();

    return _buildSectionCard(
      isDark: isDark,
      icon: icon,
      iconColor: iconColor,
      title: title,
      children: [
        Text(
          description,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
        SizedBox(height: 14),
        // 已配置的引擎列表
        if (categoryConfigs.isNotEmpty) ...[
          ...categoryConfigs.map<Widget>((entry) {
            final key = entry.key;
            final config = entry.value;
            final name = config['name']?.toString() ?? key;
            final enabled = config['enabled'] == true;
            final hasApiKey = (config['apiKey']?.toString() ?? '').isNotEmpty;
            final baseUrl = config['baseUrl']?.toString() ?? '';
            final model = config['model']?.toString() ?? '';

            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (enabled ? iconColor : Colors.grey)
                    .withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (enabled ? iconColor : Colors.grey)
                      .withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: enabled
                              ? iconColor.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: enabled
                              ? iconColor
                              : Colors.grey.shade500,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: enabled
                                        ? Color(0xFF43A047).withValues(alpha: 0.12)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    enabled ? '已启用' : '已禁用',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: enabled
                                          ? Color(0xFF43A047)
                                          : Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              hasApiKey
                                  ? 'API Key: ****'
                                  : '未配置 API Key',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500),
                            ),
                            if (baseUrl.isNotEmpty)
                              Text(
                                'Base URL: $baseUrl',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade400),
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (model.isNotEmpty)
                              Text(
                                '模型: $model',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade400),
                              ),
                          ],
                        ),
                      ),
                      // 操作按钮
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: enabled,
                            onChanged: (val) async {
                              final updatedConfig = Map<String, dynamic>.from(config);
                              updatedConfig['enabled'] = val;
                              await appState.updateAIConfig(key, updatedConfig);
                              // No setState needed - Provider will auto-rebuild
                            },
                            activeThumbColor: Color(0xFF43A047),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          IconButton(
                            icon: Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showAddAIDialog(editKey: key, category: category),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            tooltip: '编辑',
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 18,
                                color: Colors.red.shade400),
                            onPressed: () => _confirmDeleteAI(key, name),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            tooltip: '删除',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey.shade200),
          SizedBox(height: 12),
        ],
        // 无配置提示
        if (categoryConfigs.isEmpty)
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.grey.shade200,
                  style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 40, color: Colors.grey.shade300),
                SizedBox(height: 10),
                Text(
                  emptyHint,
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  emptySubHint,
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
        // 添加按钮
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showAddAIDialog(category: category),
            icon: Icon(Icons.add_rounded, size: 20),
            label: Text(addLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: iconColor,
              side: BorderSide(color: iconColor.withValues(alpha: 0.5)),
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (presetChips.isNotEmpty) ...[
          SizedBox(height: 10),
          Text(
            '快捷添加：',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presetChips,
          ),
        ],
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

  Future<void> _importDatabase(BuildContext ctx) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        dialogTitle: '选择数据库文件',
      );

      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.first;
      if (platformFile.path == null) {
        if (!ctx.mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('无法获取文件路径')),
        );
        return;
      }

      final importFile = File(platformFile.path!);

      // Confirm dialog
      if (!ctx.mounted) return;
      final confirmed = await showDialog<bool>(context: ctx, builder: (dialogCtx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('导入数据库'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('即将从以下文件导入数据库：'),
          SizedBox(height: 4),
          Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text(platformFile.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('注意：', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800, fontSize: 13)),
              SizedBox(height: 4),
              Text('当前所有数据将被覆盖替换！建议先导出当前数据库备份后再导入。', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('确认导入', style: TextStyle(color: Colors.white)),
          ),
        ],
      ));

      if (confirmed != true) return;

      // Show loading
      if (!ctx.mounted) return;
      showDialog(barrierDismissible: false, context: ctx, builder: (loadingCtx) => PopScope(
        canPop: false,
        child: AlertDialog(content: Row(children: [
          CircularProgressIndicator(strokeWidth: 3),
          SizedBox(width: 16),
          Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('正在导入数据...', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('请勿关闭应用', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
        ])),
      ));

      final dbHelper = DatabaseHelper.instance;
      final success = await dbHelper.importDatabase(importFile);

      if (!ctx.mounted) return;
      if (success) {
        // Reload app state data while loading dialog is still showing
        final appState = Provider.of<AppState>(ctx, listen: false);
        await appState.initializeApp();

        // Close loading after full initialization
        if (ctx.mounted) Navigator.pop(ctx);
        if (!ctx.mounted) return;

        showDialog(context: ctx, builder: (successCtx) => AlertDialog(
          icon: Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: Text('导入成功！'),
          content: Text('数据库已成功导入。建议重启应用以确保所有数据正确加载。'),
          actions: [TextButton(onPressed: () => Navigator.pop(successCtx), child: Text('好的'))],
        ));
      } else {
        // Close loading dialog for failed import
        if (ctx.mounted) Navigator.pop(ctx);
        if (!ctx.mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('导入失败，请确认文件格式正确')),
        );
      }
    } catch (e) {
      if (!ctx.mounted) return;
      // Close loading dialog if still showing
      try { Navigator.pop(ctx); } catch (_) {}
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  Future<void> _exportCSV(
    BuildContext context,
    AppState appState,
    String type,
  ) async {
    if (kIsWeb) return;
    try {
      // CSV escape: double quotes inside fields must be doubled
      String esc(String? v) => (v ?? '').replaceAll('"', '""');

      String csvContent;

      if (type == 'customers') {
        final header = '姓名,别名,年龄,性别,评级,电话,地址,标签,创建时间';
        final rows = appState.customers
            .map((c) {
              final phones = esc(c.phones.join('; '));
              final addresses = esc(c.addresses.join('; '));
              final tags = esc(c.tagList.join('; '));
              return '"${esc(c.name)}","${esc(c.alias)}","${esc(c.age?.toString())}","${esc(c.gender)}","${esc(c.rating?.toString())}","$phones","$addresses","$tags","${esc(c.createdAt)}"';
            })
            .join('\n');
        csvContent = '$header\n$rows';
      } else {
        final header = '公司,名称,描述,优势,分类,开始日期,结束日期,创建时间';
        final rows = appState.products
            .map((p) {
              return '"${esc(p.company)}","${esc(p.name)}","${esc(p.description)}","${esc(p.sellingPoints)}","${esc(p.category)}","${esc(p.salesStartDate)}","${esc(p.salesEndDate)}","${esc(p.createdAt)}"';
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
      await file.writeAsString('\ufeff$csvContent'); // Add UTF-8 BOM for Excel compatibility

      try {
        await Share.shareXFiles([XFile(file.path)], subject: '$type 导出');
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('分享失败，CSV已保存到: ${file.path}')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出CSV失败: $e')));
    }
  }
}
