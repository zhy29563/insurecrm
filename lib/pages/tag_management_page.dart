import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';

// 标签管理页面 - 管理客户标签字符串
class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  List<String> _allTags = [];
  String _searchQuery = '';
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  void _loadTags() {
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() {
      _allTags = List.from(appState.allTags);
    });
  }

  List<String> get _filteredTags {
    if (_searchQuery.isEmpty) return _allTags;
    return _allTags.where((t) => t.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  void _showAddTagDialog() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: '标签名称 *', hintText: '输入标签名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isNotEmpty && !_allTags.contains(name)) {
                // Add to allTags and persist
                final appState = Provider.of<AppState>(context, listen: false);
                appState.allTags.add(name);
                appState.allTags.sort();
                appState.notifyListeners();
                _loadTags();
              }
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _deleteTag(String tag) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.allTags.remove(tag);
    appState.notifyListeners();
    _loadTags();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddTagDialog),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '搜索标签',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredTags.isEmpty
                  ? Center(child: Text('没有找到标签'))
                  : ListView.builder(
                      itemCount: _filteredTags.length,
                      itemBuilder: (context, index) {
                        final tag = _filteredTags[index];
                        return Card(
                          child: ListTile(
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(color: Color(0xFF1565C0), shape: BoxShape.circle),
                            ),
                            title: Text(tag),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: () => _deleteTag(tag),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
