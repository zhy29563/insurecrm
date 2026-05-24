import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/models/colleague.dart';
import 'package:insurance_manager/widgets/app_components.dart';

class ColleagueManagementPage extends StatefulWidget {
  const ColleagueManagementPage({super.key});

  @override
  _ColleagueManagementPageState createState() =>
      _ColleagueManagementPageState();
}

class _ColleagueManagementPageState extends State<ColleagueManagementPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<Colleague> get _filteredColleagues {
    final appState = Provider.of<AppState>(context, listen: true);
    if (_searchQuery.isEmpty) return appState.colleagues;
    final q = _searchQuery.toLowerCase();
    return appState.colleagues.where((c) {
      return c.name.toLowerCase().contains(q) ||
          (c.phone?.toLowerCase().contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false) ||
          (c.departmentAndRole?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void _showAddSheet() {
    _showEditorSheet(colleague: null);
  }

  void _showEditorSheet({required Colleague? colleague}) {
    final isEdit = colleague != null;
    final nameController = TextEditingController(text: colleague?.name ?? '');
    final phoneController = TextEditingController(text: colleague?.phone ?? '');
    final emailController = TextEditingController(text: colleague?.email ?? '');
    final specialtyController = TextEditingController(
      text: colleague?.departmentAndRole ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: Theme.of(sheetCtx).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        isEdit ? '编辑同事' : '添加同事',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        // Avatar placeholder
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF43A047,
                              ).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: ListenableBuilder(
                                listenable: nameController,
                                builder: (context, _) => Text(
                                  nameController.text.isEmpty
                                      ? '?'
                                      : nameController.text[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF43A047),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Form fields in grouped card style
                        _buildFieldGroup(
                          isDark:
                              Theme.of(context).brightness == Brightness.dark,
                          children: [
                            _buildFieldRow(
                              icon: Icons.person_outline,
                              label: '姓名',
                              controller: nameController,
                              required: true,
                            ),
                            _fieldDivider(),
                            _buildFieldRow(
                              icon: Icons.phone_outlined,
                              label: '电话',
                              controller: phoneController,
                              keyboard: TextInputType.phone,
                            ),
                            _fieldDivider(),
                            _buildFieldRow(
                              icon: Icons.email_outlined,
                              label: '邮箱',
                              controller: emailController,
                              keyboard: TextInputType.emailAddress,
                            ),
                            _fieldDivider(),
                            _buildFieldRow(
                              icon: Icons.star_outline,
                              label: '专长',
                              controller: specialtyController,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Save button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              if (nameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('请输入同事姓名')),
                                );
                                return;
                              }
                              final appState = Provider.of<AppState>(
                                context,
                                listen: false,
                              );
                              if (isEdit) {
                                if (colleague.id == null) return;
                                final updated = Colleague(
                                  id: colleague.id,
                                  name: nameController.text.trim(),
                                  phone: phoneController.text.trim().isEmpty
                                      ? null
                                      : phoneController.text.trim(),
                                  email: emailController.text.trim().isEmpty
                                      ? null
                                      : emailController.text.trim(),
                                  departmentAndRole:
                                      specialtyController.text.trim().isEmpty
                                      ? null
                                      : specialtyController.text.trim(),
                                );
                                appState.updateColleague(updated);
                              } else {
                                final newColleague = Colleague(
                                  name: nameController.text.trim(),
                                  phone: phoneController.text.trim().isEmpty
                                      ? null
                                      : phoneController.text.trim(),
                                  email: emailController.text.trim().isEmpty
                                      ? null
                                      : emailController.text.trim(),
                                  departmentAndRole:
                                      specialtyController.text.trim().isEmpty
                                      ? null
                                      : specialtyController.text.trim(),
                                );
                                appState.addColleague(newColleague);
                              }
                              Navigator.pop(sheetCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEdit ? '同事信息已更新' : '同事已添加'),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF43A047),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isEdit ? '保存修改' : '添加同事',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (isEdit) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                if (colleague.id != null) {
                                  _confirmDelete(colleague.id!);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '删除此同事',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      phoneController.dispose();
      emailController.dispose();
      specialtyController.dispose();
    });
  }

  Widget _buildFieldGroup({
    required List<Widget> children,
    bool isDark = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _fieldDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(height: 1, color: Colors.grey.shade200),
    );
  }

  Widget _buildFieldRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    bool required = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            child: RichText(
              text: TextSpan(
                text: label,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                children: required
                    ? [
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: Colors.red),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '输入$label',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个同事吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final appState = Provider.of<AppState>(context, listen: false);
              appState.deleteColleague(id);
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('同事已删除')));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colleagues = _filteredColleagues;

    return Scaffold(
      appBar: AppBar(
        title: const Text('同事管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: _showAddSheet,
            tooltip: '添加同事',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: AppSearchBar(
              controller: _searchController,
              hintText: '搜索同事姓名、电话、邮箱...',
              onChanged: (v) {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _searchQuery = v);
                });
              },
              onClear: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              searchQuery: _searchQuery,
            ),
          ),
          // Colleague list
          Expanded(
            child: colleagues.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: colleagues.length,
                    itemBuilder: (context, index) {
                      final c = colleagues[index];
                      return _buildDismissibleColleagueTile(c, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStatePlaceholder(
      icon: Icons.group_off_rounded,
      message: _searchQuery.isEmpty ? '暂无同事信息' : '未找到匹配的同事',
      actionHint: _searchQuery.isEmpty ? '点击右上角按钮添加第一位同事' : '尝试使用其他关键词搜索',
    );
  }

  /// 左滑删除的同事条目
  Widget _buildDismissibleColleagueTile(Colleague c, bool isDark) {
    return Dismissible(
      key: ValueKey(c.id ?? c.name),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.delete_rounded, size: 24, color: Colors.red),
            ),
            title: const Text('确认删除'),
            content: Text('确定要删除同事「${c.name}」吗？此操作无法撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        if (c.id == null) return;
        final appState = Provider.of<AppState>(context, listen: false);
        appState.deleteColleague(c.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${c.name}」已删除')),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Padding(
          padding: EdgeInsets.only(right: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_rounded, color: Colors.white, size: 22),
              SizedBox(width: 6),
              Text('删除',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  )),
            ],
          ),
        ),
      ),
      child: _buildColleagueTile(c, isDark),
    );
  }

  Widget _buildColleagueTile(Colleague c, bool isDark) {
    final hasPhone = c.phone != null && c.phone!.isNotEmpty;
    final hasEmail = c.email != null && c.email!.isNotEmpty;
    final hasSpecialty =
        c.departmentAndRole != null && c.departmentAndRole!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDetailDialog(c),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF43A047).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF43A047),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasSpecialty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.orange.shade900.withValues(
                                        alpha: 0.3,
                                      )
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                c.departmentAndRole!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.orange.shade300
                                      : Colors.orange.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (hasPhone || hasEmail) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (hasPhone) ...[
                              Icon(Icons.phone, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Text(c.phone!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                            ],
                            if (hasPhone && hasEmail)
                              const SizedBox(width: 12),
                            if (hasEmail) ...[
                              Icon(Icons.email, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Flexible(child: Text(c.email!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Action arrow
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 查看同事详情弹窗（含编辑/删除入口）
  void _showDetailDialog(Colleague c) {
    final hasPhone = c.phone != null && c.phone!.isNotEmpty;
    final hasEmail = c.email != null && c.email!.isNotEmpty;
    final hasSpecialty = c.departmentAndRole != null && c.departmentAndRole!.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 头像 + 姓名
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF43A047).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF43A047)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(c.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (hasSpecialty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12)),
                    child: Text(c.departmentAndRole!, style: TextStyle(fontSize: 12, color: Colors.orange[800], fontWeight: FontWeight.w500)),
                  ),
                ],
                const SizedBox(height: 18),
                // 联系信息
                if (hasPhone || hasEmail)
                  Column(
                    children: [
                      Divider(color: Colors.grey.shade200),
                      const SizedBox(height: 10),
                      if (hasPhone)
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri.parse('tel:${c.phone}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF43A047).withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFF43A047).withValues(alpha: 0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.call_rounded, size: 18, color: Color(0xFF43A047)),
                                ),
                                const SizedBox(width: 12),
                                Text(c.phone!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.green[800])),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.green[400]),
                              ],
                            ),
                          ),
                        ),
                      if (hasPhone && hasEmail) const SizedBox(height: 8),
                      if (hasEmail)
                        _detailInfoRow(Icons.email_rounded, c.email!),
                      const SizedBox(height: 14),
                    ],
                  ),

                // 操作按钮行
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () { Navigator.pop(ctx); _confirmDelete(c.id!); },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.delete_outline, size: 16), SizedBox(width: 4), Text('删除'),
                      ]),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: () { Navigator.pop(ctx); _showEditorSheet(colleague: c); },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('编辑'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(ctx).primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 详情弹窗中的信息行
  Widget _detailInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }
}
