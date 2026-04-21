import 'package:insurecrm/utils/app_logger.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/services/backup_service.dart';
import 'package:insurecrm/providers/app_state.dart';
import 'package:insurecrm/database/database_helper.dart';
import 'package:share_plus/share_plus.dart';

class BackupRestorePage extends StatefulWidget {
  @override
  _BackupRestorePageState createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  final BackupService _backup = BackupService.instance;
  List<BackupInfo> _backups = [];
  bool _isLoading = false;
  bool _autoBackupEnabled = false;
  int _intervalHours = 24;
  int _maxBackups = 5;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshBackups();
  }

  Future<void> _loadSettings() async {
    _autoBackupEnabled = await _backup.isAutoBackupEnabled();
    _intervalHours = await _backup.getBackupIntervalHours();
    _maxBackups = await _backup.getMaxBackupsCount();
    setState(() {});
  }

  Future<void> _refreshBackups() async {
    setState(() => _isLoading = true);
    try {
      _backups = await _backup.getBackupList();
    } catch (e) { AppLogger.error('loading backups: $e'); }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('数据备份与恢复'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshBackups,
            tooltip: '刷新列表',
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // ===== Auto Backup Settings =====
          _buildCard(
            isDark: isDark,
            icon: Icons.schedule_rounded,
            iconColor: Color(0xFF7B1FA2),
            title: '自动备份设置',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('启用自动备份', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(_autoBackupEnabled ? '已开启' : '已关闭'),
                secondary: Icon(Icons.timer_outlined, color: Color(0xFF7B1FA2)),
                value: _autoBackupEnabled,
                activeColor: primaryColor,
                onChanged: kIsWeb ? null : (v) async {
                  await _backup.setAutoBackupEnabled(v);
                  setState(() => _autoBackupEnabled = v);
                  if (v) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('自动备份已启用，将在应用启动时检查并执行')));
                },
              ),
              if (_autoBackupEnabled) ...[
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.access_time, color: Colors.grey),
                  title: Text('备份间隔（小时）'),
                  trailing: SizedBox(
                    width: 80,
                    child: DropdownButton<int>(
                      value: _intervalHours,
                      items: [1, 6, 12, 24, 48, 72].map((h) =>
                        DropdownMenuItem(value: h, child: Text('$h小时'))
                      ).toList(),
                      onChanged: (v) async {
                        await _backup.setBackupIntervalHours(v!);
                        setState(() => _intervalHours = v);
                      },
                    ),
                  ),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.archive_outlined, color: Colors.grey),
                  title: Text('保留备份数量'),
                  trailing: SizedBox(
                    width: 60,
                    child: DropdownButton<int>(
                      value: _maxBackups,
                      items: [3, 5, 10, 20].map((n) =>
                        DropdownMenuItem(value: n, child: Text('$n个'))
                      ).toList(),
                      onChanged: (v) async {
                        await _backup.setMaxBackupsCount(v!);
                        setState(() => _maxBackups = v);
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 16),

          // ===== Manual Actions =====
          _buildCard(
            isDark: isDark,
            icon: Icons.backup_rounded,
            iconColor: Color(0xFF1565C0),
            title: '手动操作',
            children: [
              Text('创建完整备份或从已有备份恢复数据',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              SizedBox(height: 12),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: _isCreating || kIsWeb ? null : () => _createManualBackup(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1565C0)),
                  icon: _isCreating ? SizedBox(width:18,height:18,child: CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : Icon(Icons.add_box_rounded, size: 18),
                  label: Text(_isCreating ? '备份中...' : '立即备份'),
                )),
                SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  onPressed: kIsWeb ? null : () => _showRestoreDialog(context),
                  icon: Icon(Icons.restore_rounded, size: 18),
                  label: Text('选择恢复'),
                  style: OutlinedButton.styleFrom(foregroundColor: Color(0xFF00897B)),
                )),
              ]),
            ],
          ),
          SizedBox(height: 16),

          // ===== Cloud Sync Info =====
          _buildCard(
            isDark: isDark,
            icon: Icons.cloud_upload_rounded,
            iconColor: Color(0xFF0288D1),
            title: '云端同步（可选）',
            children: [
              Text('将备份文件上传至云端存储，支持跨设备同步',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                    SizedBox(width: 8),
                    Text('使用方式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.blue.shade900)),
                  ]),
                  SizedBox(height: 8),
                  Text('• 点击备份文件右侧的「分享」按钮，可将备份上传到网盘、微信等云端位置\n'
                       '• 在新设备上下载后通过「导入备份」功能导入即可完成跨设备迁移\n'
                       '• 建议定期手动备份到云端以防数据丢失',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade800)),
                ]),
              ),
            ],
          ),
          SizedBox(height: 20),

          // ===== Backup List =====
          Row(children: [
            Icon(Icons.folder_zip_rounded, color: Colors.orange.shade700),
            SizedBox(width: 8),
            Text('本地备份记录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10)),
              child: Text('${_backups.length} 个', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
            ),
          ]),
          SizedBox(height: 10),
          if (_isLoading)
            Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
          else if (_backups.isEmpty)
            _EmptyBackupsPlaceholder()
          else ..._backups.map((b) => _buildBackupTile(b, context, isDark)).toList(),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCard({
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: iconColor)),
          SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ]),
        SizedBox(height: 16),
        ...children,
      ]),
    );
  }

  Widget _buildBackupTile(BackupInfo info, BuildContext context, bool isDark) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: info.isAuto ? Color(0xFFE3F2FD) : Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(10)),
            child: Icon(info.isAuto ? Icons.auto_awesome : Icons.backup, color: info.isAuto ? Color(0xFF1565C0) : Color(0xFF7B1FA2)),
          ),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(info.fileName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
              SizedBox(width: 6),
              if (info.isAuto) Container(padding: EdgeInsets.symmetric(horizontal:6,vertical:1), decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                child: Text('自动', style: TextStyle(fontSize: 10, color: Colors.blue.shade800))),
            ]),
            SizedBox(height: 4),
            Row(children: [
              Icon(Icons.access_time_filled, size: 13, color: Colors.grey),
              SizedBox(width: 3),
              Text(_formatDateTime(info.created), style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(width: 12),
              Icon(Icons.sd_storage, size: 13, color: Colors.grey),
              SizedBox(width: 3),
              Text(info.sizeFormatted, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ])),
          PopupMenuButton<String>(
            onSelected: (v) => _handleBackupAction(v, info, context),
            itemBuilder: (c) => [
              PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share, size:18), SizedBox(width:8), Text('分享/上传云端')])),
              PopupMenuItem(value: 'restore', child: Row(children: [Icon(Icons.restore, size:18, color: Colors.teal), SizedBox(width:8), Text('从此备份恢复', style: TextStyle(color: Colors.teal))])),
              PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size:18, color: Colors.red), SizedBox(width:8), Text('删除', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ]),
      ),
    );
  }

  void _handleBackupAction(String action, BackupInfo info, BuildContext ctx) async {
    switch (action) {
      case 'share':
        try {
          final shareFile = await _backup.exportBackupForSharing(info.path);
          await Share.shareXFiles([XFile(shareFile.path)], subject: '保险管理系统备份');
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('已准备分享')));
        } catch (e) { ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('分享失败：$e'))); }
        break;
      case 'restore':
        _confirmRestore(ctx, info.path, info.fileName);
        break;
      case 'delete':
        _confirmDelete(ctx, info);
        break;
    }
  }

  void _confirmDelete(BuildContext ctx, BackupInfo info) {
    showDialog(context: ctx, builder: (dialogCtx) => AlertDialog(
      title: Text('确认删除'), content: Text('确定要删除备份「${info.fileName}」吗？此操作无法撤销。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('取消')),
        TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () async { Navigator.pop(dialogCtx); await _backup.deleteBackup(info.path); _refreshBackups(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已删除'))); }, child: Text('删除')),
      ],
    ));
  }

  void _confirmRestore(BuildContext ctx, String backupPath, String fileName) {
    showDialog(context: ctx, builder: (dialogCtx) => AlertDialog(
      title: Row(children: [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 8), Text('数据恢复')]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('即将从以下备份恢复所有数据：'),
        SizedBox(height: 4),
        Container(margin: EdgeInsets.all(8), padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
          child: Text(fileName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        SizedBox(height: 10),
        Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text('注意：', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800, fontSize: 13))]),
          SizedBox(height: 4),
          Text('当前所有数据将被覆盖替换！建议先创建一个当前数据的备份再进行恢复。', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
        ])),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('取消')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(dialogCtx);
            final dialog = showDialog(barrierDismissible: false, context: context, builder: (loadingCtx) => WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(content: Row(children: [
                CircularProgressIndicator(strokeWidth:3),
                SizedBox(width:16),
                Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('正在恢复数据...', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('请勿关闭应用', style: TextStyle(fontSize:12, color: Colors.grey))
                ]))
              ]))));
            final result = await _backup.restoreFromBackup(backupPath);
            Navigator.pop(context);
            if (result.$1) {
              showDialog(context: context, builder: (successCtx) => AlertDialog(
                icon: Icon(Icons.check_circle, color: Colors.green, size: 48),
                title: Text('恢复成功！'),
                content: Text(result.$2 + '\n\n建议重启应用以完整加载恢复的数据。'),
                actions: [TextButton(onPressed: (){ Navigator.pop(successCtx); _refreshBackups(); }, child: Text('好的'))]));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.$2)));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text('确认恢复', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Future<void> _createManualBackup(BuildContext ctx) async {
    setState(() => _isCreating = true);
    try {
      final backupPath = await _backup.createFullBackup(isAutoBackup: false);
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('✅ 备份成功！\n$backupPath')));
      _refreshBackups();
    } catch (e) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('❌ 备份失败：$e')));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showRestoreDialog(BuildContext ctx) {
    showDialog(context: ctx, builder: (dialogCtx) => SimpleDialog(title: Text('导入外部备份'), children: [
      Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 16), child: Column(children: [
        Text('请将 .zip 备份文件放到以下目录中：', style: TextStyle(fontSize: 13)),
        SizedBox(height: 8),
        Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
          child: Text('文档目录 / backups /', style: TextStyle(fontSize: 11, fontFamily: 'monospace'))),
        SizedBox(height: 12),
        Text('或者点击下方按钮选择文件（需要系统文件选择器支持）', style: TextStyle(fontSize: 13, color: Colors.grey)),
      ])),
      Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(children: [
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () { Navigator.pop(dialogCtx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请在设备上找到备份文件放入备份目录后刷新列表'))); },
          icon: Icon(Icons.folder_open), label: Text('打开备份文件夹'))),
        SizedBox(height: 8),
        Text('提示：可通过「分享」功能将其他设备的备份传到此设备', style: TextStyle(fontSize: 12, color: Colors.grey.shade500), textAlign: TextAlign.center),
      ])),
    ]));
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}

class _EmptyBackupsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey.shade300),
          SizedBox(height: 16),
          Text('暂无备份', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey)),
          SizedBox(height: 8),
          Text('点击上方「立即备份」按钮创建第一个备份', style: TextStyle(color: Colors.grey.shade500)),
          SizedBox(height: 16),
          Text('建议：开启自动备份以防止数据丢失', style: TextStyle(fontSize: 13, color: Colors.orange.shade700)),
        ]),
      ),
    );
  }
}
