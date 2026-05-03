import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/widgets/app_components.dart';

// 标签管理页面 - 管理客户标签字符串
class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage>
    with SingleTickerProviderStateMixin {
  List<String> _allTags = [];
  String _searchQuery = '';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTags();
    });
  }

  void _loadTags() {
    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() {
      _allTags = List.from(appState.allTags);
    });
  }

  List<String> get _filteredTags {
    if (_searchQuery.isEmpty) return _allTags;
    return _allTags
        .where((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _showAddTagDialog() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(ctx).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.label_rounded,
                  color: Theme.of(ctx).primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('添加标签'),
          ],
        ),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '标签名称 *',
            hintText: '输入标签名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isEmpty) {
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('标签名称不能为空')),
                );
                return;
              }
              if (_allTags.contains(name)) {
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('该标签已存在')),
                );
                return;
              }
              final appState =
                  Provider.of<AppState>(context, listen: false);
              await appState.addTag(name);
              if (!mounted) return;
              _loadTags();
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _deleteTag(String tag) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('确认删除'),
          ],
        ),
        content: Text('确定要删除标签「$tag」吗？\n所有客户的该标签关联也会被删除，此操作无法撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final appState =
                  Provider.of<AppState>(context, listen: false);
              await appState.removeTag(tag);
              if (!mounted) return;
              _loadTags();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_rounded, size: 20),
            ),
            onPressed: _showAddTagDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(_fadeAnimation),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: AppSearchBar(
                  controller: _searchController,
                  hintText: '搜索标签',
                  searchQuery: _searchQuery,
                  onClear: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  onChanged: (value) {
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(
                        const Duration(milliseconds: 300), () {
                      if (mounted) setState(() => _searchQuery = value);
                    });
                  },
                ),
              ),
              // Stats bar
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '共 ${_allTags.length} 个标签',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    if (_searchQuery.isNotEmpty)
                      Text(
                        '找到 ${_filteredTags.length} 个结果',
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: _filteredTags.isEmpty
                    ? EmptyStatePlaceholder(
                        icon: Icons.label_off_rounded,
                        message: _searchQuery.isEmpty
                            ? '暂无标签'
                            : '没有找到标签',
                        actionHint: _searchQuery.isEmpty
                            ? '点击右上角添加标签'
                            : '尝试其他关键词',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: _filteredTags.length,
                        itemBuilder: (context, index) {
                          final tag = _filteredTags[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              onTap: () => _showTagOptions(tag),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: primaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.label_rounded,
                                      size: 18,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      tag,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded,
                                        size: 20,
                                        color: Colors.red.shade300),
                                    onPressed: () => _deleteTag(tag),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTagOptions(String tag) {
    // Future: navigate to tag detail / customers with this tag
  }
}
