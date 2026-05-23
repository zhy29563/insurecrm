import 'package:insurance_manager/widgets/app_components.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/pages/colleague_management_page.dart';
import 'package:insurance_manager/pages/backup_restore_page.dart';
import 'package:insurance_manager/services/backup_service.dart';
import 'package:insurance_manager/services/sherpa_asr_service.dart';
import 'package:insurance_manager/utils/app_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _newRelLabelController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _newRelLabelController.dispose();
    super.dispose();
  }

  Color _relLabelColor(String label) => AppDesign.cnRelColor(label);

  Future<bool> _addRelationshipLabel(String value, AppState appState) async {
    final label = value.trim();
    if (label.isEmpty) return false;
    if (appState.relationshipLabels.contains(label)) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('标签「$label」已存在')));
      return false;
    }
    await appState.addRelationshipLabel(label);
    if (!mounted) return false;
    // No setState needed - Provider.of<AppState>(context) in build() will auto-rebuild
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已添加标签「$label」')));
    return true;
  }

  void _showAddAIDialog({String? editKey, String category = 'chat'}) {
    final appState = Provider.of<AppState>(context, listen: false);
    final pageContext = context; // Capture page-level context before dialog
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
                      hintText: isASR
                          ? '例如: 豆包ASR、讯飞ASR'
                          : '例如: 豆包、千问、GPT、Claude',
                      prefixIcon: const Icon(Icons.label),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API Key *',
                      hintText: '输入 API Key',
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: baseUrlController,
                    decoration: InputDecoration(
                      labelText: 'Base URL（可选）',
                      hintText: isASR
                          ? '例如: https://openspeech.bytedance.com/v1'
                          : '例如: https://api.openai.com/v1',
                      prefixIcon: const Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: modelController,
                    decoration: InputDecoration(
                      labelText: '模型名称（可选）',
                      hintText: isASR ? '例如: asr-pro' : '例如: gpt-4o, qwen-max',
                      prefixIcon: const Icon(Icons.psychology),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    apiKeyController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    const SnackBar(content: Text('请填写引擎名称和API Key')),
                  );
                  return;
                }
                // 生成唯一 key
                final key =
                    editKey ??
                    nameController.text.trim().toLowerCase().replaceAll(
                      ' ',
                      '_',
                    );
                // 检查 key 是否已存在（仅新增模式）
                if (editKey == null &&
                    appState.aiProviderConfigs.containsKey(key)) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        '名为「${nameController.text.trim()}」的引擎已存在，请使用不同名称',
                      ),
                    ),
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
                  SnackBar(
                    content: Text(
                      editKey != null ? 'AI引擎配置已更新' : '$categoryLabel引擎已添加',
                    ),
                  ),
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
        title: const Text('确认删除'),
        content: Text('确定要删除AI引擎「$name」的配置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final appState = Provider.of<AppState>(
                pageContext,
                listen: false,
              );
              await appState.deleteAIConfig(key);
              if (!context.mounted) return;
              Navigator.pop(context);
              // No setState needed - Provider will auto-rebuild
              ScaffoldMessenger.of(
                pageContext,
              ).showSnackBar(SnackBar(content: Text('已删除AI引擎「$name」')));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
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
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 外观设置
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.palette_rounded,
            iconColor: const Color(0xFFAB47BC),
            title: '外观设置',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('深色模式'),
                subtitle: const Text('减少夜间使用对眼睛的刺激'),
                secondary: Icon(
                  appState.darkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: appState.darkMode
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFFFFA726),
                ),
                value: appState.darkMode,
                activeThumbColor: primaryColor,
                onChanged: (value) => appState.toggleDarkMode(value),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 离线ASR配置
          _buildOfflineASRSection(isDark, appState),
          const SizedBox(height: 16),

          // AI语音ASR配置
          _buildAICategorySection(
            isDark: isDark,
            appState: appState,
            category: 'asr',
            icon: Icons.mic_rounded,
            iconColor: const Color(0xFFFF6D00),
            title: 'AI语音识别(ASR)配置',
            description:
                '配置语音识别引擎，用于产品推荐中的语音输入识别。支持兼容 OpenAI Whisper API 格式的ASR服务。',
            emptyHint: '暂未配置ASR引擎',
            emptySubHint: '添加ASR引擎后，可在产品推荐中使用语音输入',
            addLabel: '添加ASR引擎',
            presetChips: [
              _buildPresetChip(
                '豆包ASR',
                'doubao_asr',
                Icons.local_fire_department,
                const Color(0xFFFF6D00),
                category: 'asr',
                appState: appState,
                isDark: isDark,
              ),
              _buildPresetChip(
                '讯飞ASR',
                'xfyun_asr',
                Icons.record_voice_over,
                const Color(0xFF0066CC),
                category: 'asr',
                appState: appState,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // AI对话配置
          _buildAICategorySection(
            isDark: isDark,
            appState: appState,
            category: 'chat',
            icon: Icons.smart_toy_rounded,
            iconColor: const Color(0xFF1E88E5),
            title: 'AI对话分析配置',
            description:
                '配置对话分析引擎，用于产品推荐中的智能分析和推荐。支持兼容 OpenAI Chat API 格式的AI服务。',
            emptyHint: '暂未配置对话引擎',
            emptySubHint: '添加对话引擎后，可在产品推荐中使用AI分析',
            addLabel: '添加对话引擎',
            presetChips: [
              _buildPresetChip(
                '豆包',
                'doubao',
                Icons.local_fire_department,
                const Color(0xFFFF6D00),
                appState: appState,
                isDark: isDark,
              ),
              _buildPresetChip(
                '千问',
                'qianwen',
                Icons.auto_awesome,
                const Color(0xFF6A1B9A),
                appState: appState,
                isDark: isDark,
              ),
              _buildPresetChip(
                'GPT',
                'gpt',
                Icons.psychology,
                const Color(0xFF10A37F),
                appState: appState,
                isDark: isDark,
              ),
              _buildPresetChip(
                'Claude',
                'claude',
                Icons.smart_toy,
                const Color(0xFFD97757),
                appState: appState,
                isDark: isDark,
              ),
              _buildPresetChip(
                'Gemini',
                'gemini',
                Icons.diamond,
                const Color(0xFF4285F4),
                appState: appState,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 关系标签管理
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.label_important_rounded,
            iconColor: const Color(0xFFE53935),
            title: '关系标签管理',
            children: [
              Text(
                '管理客户关系标签，添加关系时可从中选择。自定义标签会保存到本地。',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 14),
              // 当前标签列表
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: appState.relationshipLabels.map<Widget>((label) {
                  return Chip(
                    label: Text(label, style: const TextStyle(fontSize: 13)),
                    backgroundColor: _relLabelColor(
                      label,
                    ).withValues(alpha: 0.1),
                    side: BorderSide(
                      color: _relLabelColor(label).withValues(alpha: 0.3),
                    ),
                    deleteIconColor: Colors.grey.shade500,
                    onDeleted: () async {
                      if (appState.relationshipLabels.length <= 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('至少保留一个关系标签')),
                        );
                        return;
                      }
                      await appState.removeRelationshipLabel(label);
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('已删除标签「$label」')));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (value) async {
                        final success = await _addRelationshipLabel(
                          value,
                          appState,
                        );
                        if (success) _newRelLabelController.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final text = _newRelLabelController.text.trim();
                      if (text.isNotEmpty) {
                        final success = await _addRelationshipLabel(
                          text,
                          appState,
                        );
                        if (success) _newRelLabelController.clear();
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('添加'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 重置按钮
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('重置关系标签'),
                        content: const Text('确定要恢复默认关系标签吗？自定义添加的标签将被移除。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                            ),
                            child: const Text('重置'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await appState.resetRelationshipLabels();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('关系标签已重置为默认')),
                      );
                    }
                  },
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('恢复默认标签', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 同事管理
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.group_rounded,
            iconColor: const Color(0xFF43A047),
            title: '同事管理',
            children: [
              Text(
                '管理同事信息，包括添加、编辑和删除同事资料',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ColleagueManagementPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('进入同事管理页面'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 数据备份与同步
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.cloud_sync_rounded,
            iconColor: const Color(0xFF0288D1),
            title: '数据备份与同步',
            children: [
              Text(
                '自动定时本地备份、数据恢复、云端备份分享',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BackupRestorePage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0288D1),
                  ),
                  icon: const Icon(Icons.backup_table_rounded, size: 18),
                  label: const Text('进入备份管理'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 数据库管理
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.storage_rounded,
            iconColor: const Color(0xFFFF7043),
            title: '数据库管理',
            children: [
              Text(
                '管理数据备份与恢复，包含数据库和附件的完整导出导入',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: kIsWeb ? null : () => _exportBackup(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('完整备份'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: kIsWeb ? null : () => _importBackup(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                      ),
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: const Text('恢复备份'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: kIsWeb
                          ? null
                          : () => _exportCSV(context, appState, 'customers'),
                      icon: const Icon(Icons.table_chart_rounded, size: 18),
                      label: const Text('导出客户CSV'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: kIsWeb
                          ? null
                          : () => _exportCSV(context, appState, 'products'),
                      icon: const Icon(Icons.table_chart_rounded, size: 18),
                      label: const Text('导出产品CSV'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 关于
          _buildSectionCard(
            isDark: isDark,
            icon: Icons.info_rounded,
            iconColor: const Color(0xFF78909C),
            title: '关于',
            children: [
              _buildAboutRow('版本', '1.0.0'),
              const Divider(height: 20),
              _buildAboutRow('应用', '保险经纪人 v1.0'),
              const Divider(height: 20),
              _buildAboutRow('版权', '© 2026 保险经纪人'),
            ],
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    String key,
    IconData icon,
    Color color, {
    String category = 'chat',
    required AppState appState,
    required bool isDark,
  }) {
    final alreadyAdded = appState.aiProviderConfigs.containsKey(key);

    return InkWell(
      onTap: alreadyAdded
          ? null
          : () {
              _showAddAIDialogWithPreset(key, label, category: category);
            },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: alreadyAdded
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100)
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
            const SizedBox(width: 6),
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

  void _showAddAIDialogWithPreset(
    String key,
    String name, {
    String category = 'chat',
  }) {
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
              const Icon(Icons.smart_toy_rounded, color: Color(0xFF1E88E5)),
              const SizedBox(width: 8),
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
                      prefixIcon: const Icon(Icons.key),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'API 服务地址',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: modelController,
                    decoration: const InputDecoration(
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
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (apiKeyController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(
                    pageContext,
                  ).showSnackBar(const SnackBar(content: Text('请填写API Key')));
                  return;
                }
                final appState = Provider.of<AppState>(context, listen: false);
                // Check if key already exists
                if (appState.aiProviderConfigs.containsKey(key)) {
                  ScaffoldMessenger.of(
                    pageContext,
                  ).showSnackBar(SnackBar(content: Text('$name 引擎已存在')));
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
                ScaffoldMessenger.of(
                  pageContext,
                ).showSnackBar(SnackBar(content: Text('$name 引擎已配置')));
              },
              child: const Text('保存'),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  /// 离线 ASR 配置区
  Widget _buildOfflineASRSection(bool isDark, AppState appState) {
    final sherpaASR = SherpaASRService.instance;
    return _buildSectionCard(
      isDark: isDark,
      icon: Icons.offline_bolt_rounded,
      iconColor: const Color(0xFF00897B),
      title: '离线语音识别',
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Sherpa-ONNX 离线语音识别，无需网络，数据不离开设备。',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 24),
              color: const Color(0xFF00897B),
              onPressed: () => _showOfflineASRModelDialog(isDark),
              tooltip: '下载模型',
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<OfflineASRModel>>(
          future: sherpaASR.getDownloadedModels(),
          builder: (context, snapshot) {
            final downloaded = snapshot.data ?? [];
            if (downloaded.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '未下载离线模型，点击 + 下载模型',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              );
            }
            return Column(
              children: downloaded.map((model) {
                final isActive =
                    sherpaASR.isInitialized && sherpaASR.currentModel == model;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(
                    isActive
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isActive
                        ? const Color(0xFF00897B)
                        : (isDark ? Colors.grey[600] : Colors.grey[400]),
                  ),
                  title: Text(
                    model.displayName,
                    style: TextStyle(
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${model.sizeMB} MB · ${isActive ? "使用中" : "已下载"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: isActive
                      ? TextButton(
                          onPressed: () {
                            sherpaASR.dispose();
                            setState(() {});
                          },
                          child: const Text('停用'),
                        )
                      : TextButton(
                          onPressed: () async {
                            final ok = await sherpaASR.initialize(model: model);
                            if (ok && mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已启用 ${model.displayName}'),
                                ),
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('启用 ${model.displayName} 失败'),
                                ),
                              );
                            }
                          },
                          child: const Text('启用'),
                        ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  /// 离线 ASR 模型下载对话框
  void _showOfflineASRModelDialog(bool isDark) {
    final sherpaASR = SherpaASRService.instance;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.download_rounded, color: Color(0xFF00897B)),
              SizedBox(width: 8),
              Text('下载离线模型'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: OfflineASRModel.values.map((model) {
              return FutureBuilder<bool>(
                future: sherpaASR.isModelDownloaded(model),
                builder: (ctx, snap) {
                  final downloaded = snap.data ?? false;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      downloaded ? Icons.cloud_done : Icons.cloud_download,
                      color: downloaded ? const Color(0xFF00897B) : Colors.grey,
                    ),
                    title: Text(model.displayName),
                    subtitle: Text('${model.sizeMB} MB'),
                    trailing: downloaded
                        ? const Text(
                            '已下载',
                            style: TextStyle(color: Color(0xFF00897B)),
                          )
                        : const Text('下载'),
                    onTap: downloaded
                        ? null
                        : () async {
                            setDialogState(() {});
                            final ok = await _downloadModel(model);
                            if (ok && mounted) {
                              setDialogState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${model.displayName} 下载完成'),
                                ),
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${model.displayName} 下载失败，请检查网络',
                                  ),
                                ),
                              );
                            }
                          },
                  );
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  /// 下载模型文件
  Future<bool> _downloadModel(OfflineASRModel model) async {
    try {
      final modelDir = await SherpaASRService.instance.getModelPath(model);
      final dir = Directory(modelDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // 从 HuggingFace 下载模型文件
      final baseUrl = 'https://huggingface.co/${model.repoId}/resolve/main';
      final filesToDownload = [model.modelFile, model.tokensFile];

      for (final fileName in filesToDownload) {
        final url = '$baseUrl/$fileName';
        final savePath = '$modelDir/$fileName';
        final file = File(savePath);

        if (file.existsSync()) continue;

        final request = await HttpClient().getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode != 200) {
          AppLogger.error('下载模型文件失败: $url (HTTP ${response.statusCode})');
          return false;
        }
        final sink = file.openWrite();
        await response.pipe(sink);
        await sink.close();
      }

      return true;
    } catch (e) {
      AppLogger.error('下载模型失败: $e');
      return false;
    }
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
        const SizedBox(height: 14),
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
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (enabled ? iconColor : Colors.grey).withValues(
                  alpha: 0.06,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (enabled ? iconColor : Colors.grey).withValues(
                    alpha: 0.15,
                  ),
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
                          color: enabled ? iconColor : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: enabled
                                        ? const Color(
                                            0xFF43A047,
                                          ).withValues(alpha: 0.12)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    enabled ? '已启用' : '已禁用',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: enabled
                                          ? const Color(0xFF43A047)
                                          : Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasApiKey ? 'API Key: ****' : '未配置 API Key',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            if (baseUrl.isNotEmpty)
                              Text(
                                'Base URL: $baseUrl',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (model.isNotEmpty)
                              Text(
                                '模型: $model',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
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
                              final updatedConfig = Map<String, dynamic>.from(
                                config,
                              );
                              updatedConfig['enabled'] = val;
                              await appState.updateAIConfig(key, updatedConfig);
                              // No setState needed - Provider will auto-rebuild
                            },
                            activeThumbColor: const Color(0xFF43A047),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showAddAIDialog(
                              editKey: key,
                              category: category,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            tooltip: '编辑',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red.shade400,
                            ),
                            onPressed: () => _confirmDeleteAI(key, name),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
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
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),
        ],
        // 无配置提示
        if (categoryConfigs.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.grey.shade200,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 40,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 10),
                Text(
                  emptyHint,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  emptySubHint,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
        // 添加按钮
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showAddAIDialog(category: category),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(addLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: iconColor,
              side: BorderSide(color: iconColor.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (presetChips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '快捷添加：',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: presetChips),
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
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _exportBackup(BuildContext ctx) async {
    try {
      final backupService = BackupService.instance;
      final backupPath = await backupService.createFullBackup(
        isAutoBackup: false,
      );
      if (!ctx.mounted) return;

      // Offer to share the backup
      try {
        await Share.shareXFiles([
          XFile(backupPath),
        ], subject: '保险经纪人数据备份 ${DateTime.now().year}');
      } catch (_) {
        // Share not available or cancelled — just show path
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text('备份已创建：$backupPath')));
      }
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('创建备份失败：$e')));
    }
  }

  Future<void> _importBackup(BuildContext ctx) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: '选择备份文件',
      );

      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.first;
      if (platformFile.path == null) {
        if (!ctx.mounted) return;
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('无法获取文件路径')));
        return;
      }

      final importFile = File(platformFile.path!);

      // Confirm dialog
      if (!ctx.mounted) return;
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('恢复备份'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('即将从以下备份恢复所有数据（含附件）：'),
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  platformFile.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '注意：',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '当前所有数据将被覆盖替换！建议先创建当前数据的备份再进行恢复。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('确认恢复', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Show loading
      if (!ctx.mounted) return;
      showDialog(
        barrierDismissible: false,
        context: ctx,
        builder: (loadingCtx) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 3),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '正在恢复数据...',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '请勿关闭应用',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final backupService = BackupService.instance;
      final (success, message) = await backupService.restoreFromBackup(
        importFile.path,
      );

      if (!ctx.mounted) return;
      // Close loading dialog
      Navigator.pop(ctx);
      if (!ctx.mounted) return;

      if (success) {
        // Reload app state data
        final appState = Provider.of<AppState>(ctx, listen: false);
        await appState.initializeApp();

        if (!ctx.mounted) return;
        showDialog(
          context: ctx,
          builder: (successCtx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            title: const Text('恢复成功！'),
            content: Text('$message\n\n建议重启应用以完整加载恢复的数据。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(successCtx),
                child: const Text('好的'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!ctx.mounted) return;
      // Close loading dialog if still showing
      try {
        Navigator.pop(ctx);
      } catch (_) {}
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('恢复失败：$e')));
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
        const header = '姓名,别名,年龄,性别,评级,电话,地址,标签,创建时间';
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
        const header = '公司,名称,描述,优势,分类,开始日期,结束日期,创建时间';
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
      await file.writeAsString(
        '\ufeff$csvContent',
      ); // Add UTF-8 BOM for Excel compatibility

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
