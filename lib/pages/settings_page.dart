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
import 'package:insurance_manager/services/ocr_service.dart';
import 'package:insurance_manager/services/semantic_service.dart';
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

          // 语音识别模型
          _buildModelSection(
            isDark: isDark,
            icon: Icons.mic_rounded,
            iconColor: const Color(0xFF00897B),
            title: '语音识别模型',
            description: 'Sherpa-ONNX Paraformer 中文语音识别，无需网络，数据不离开设备。',
            modelName: 'Paraformer 中文离线',
            modelSize: '~120 MB',
            isActive: SherpaASRService.instance.isInitialized,
            activeColor: const Color(0xFF00897B),
            onToggle: (enable) async {
              if (enable) {
                return await SherpaASRService.instance.initialize();
              } else {
                SherpaASRService.instance.deactivate();
                return true;
              }
            },
            successMsg: '已启用语音识别模型',
            failMsg: '启用语音识别模型失败',
          ),
          const SizedBox(height: 16),

          // 文字识别模型
          _buildModelSection(
            isDark: isDark,
            icon: Icons.document_scanner_rounded,
            iconColor: const Color(0xFF43A047),
            title: '文字识别模型',
            description: 'PaddleOCR PP-OCRv5 文字识别，无需网络，数据不离开设备。支持中英文。',
            modelName: 'PP-OCRv5 中英离线',
            modelSize: '~21 MB',
            isActive: OcrService.instance.isInitialized,
            activeColor: const Color(0xFF43A047),
            onToggle: (enable) async {
              if (enable) {
                return await OcrService.instance.initialize();
              } else {
                await OcrService.instance.deactivate();
                return true;
              }
            },
            successMsg: '已启用文字识别模型',
            failMsg: '启用文字识别模型失败',
          ),
          const SizedBox(height: 16),

          // 语义分析模型
          _buildModelSection(
            isDark: isDark,
            icon: Icons.psychology_rounded,
            iconColor: const Color(0xFF5C6BC0),
            title: '语义分析模型',
            description: 'BGE-small-zh 语义嵌入模型，无需网络，数据不离开设备。用于产品推荐智能匹配。',
            modelName: 'BGE-small-zh 语义嵌入',
            modelSize: '~91 MB',
            isActive: SemanticService.instance.isInitialized,
            activeColor: const Color(0xFF5C6BC0),
            onToggle: (enable) async {
              if (enable) {
                return await SemanticService.instance.initialize();
              } else {
                SemanticService.instance.deactivate();
                return true;
              }
            },
            successMsg: '已启用语义分析模型',
            failMsg: '启用语义分析模型失败',
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

  /// 通用模型配置区
  Widget _buildModelSection({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String modelName,
    required String modelSize,
    required bool isActive,
    required Color activeColor,
    required Future<bool> Function(bool enable) onToggle,
    required String successMsg,
    required String failMsg,
  }) {
    return _buildSectionCard(
      isDark: isDark,
      icon: icon,
      iconColor: iconColor,
      title: title,
      children: [
        Text(
          description,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(
            isActive ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isActive
                ? activeColor
                : (isDark ? Colors.grey[600] : Colors.grey[400]),
          ),
          title: Text(modelName),
          subtitle: Text(
            '$modelSize · ${isActive ? "使用中" : "已内置"}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: isActive
              ? TextButton(
                  onPressed: () async {
                    await onToggle(false);
                    setState(() {});
                  },
                  child: const Text('停用'),
                )
              : TextButton(
                  onPressed: () async {
                    final ok = await onToggle(true);
                    if (ok && mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(successMsg)));
                    } else if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(failMsg)));
                    }
                  },
                  child: const Text('启用'),
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
