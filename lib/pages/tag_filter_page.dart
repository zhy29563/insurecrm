import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';
import 'package:insurecrm/models/customer.dart';

// 标签筛选页面
class TagFilterPage extends StatefulWidget {
  const TagFilterPage({super.key});

  @override
  State<TagFilterPage> createState() => _TagFilterPageState();
}

class _TagFilterPageState extends State<TagFilterPage> {
  List<String> _selectedTags = [];
  List<Customer> _filteredCustomers = [];
  bool _isFiltering = false;

  Future<void> _applyFilter() async {
    if (_selectedTags.isEmpty) {
      setState(() => _filteredCustomers = []);
      return;
    }
    setState(() => _isFiltering = true);
    final appState = Provider.of<AppState>(context, listen: false);
    final customers = appState.searchCustomersWithTags(_selectedTags);
    setState(() {
      _filteredCustomers = customers;
      _isFiltering = false;
    });
  }

  void _clearFilter() {
    setState(() {
      _selectedTags = [];
      _filteredCustomers = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final tags = appState.allTags;

    return Scaffold(
      appBar: AppBar(title: const Text('标签筛选')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('选择标签', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: tags.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          selectedColor: const Color(0xFF1565C0),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _applyFilter,
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                          child: _isFiltering
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('应用筛选'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(onPressed: _clearFilter, child: const Text('清除')),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedTags.isNotEmpty) ...[
              Text('已选择标签 (${_selectedTags.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _selectedTags.map((tag) => Chip(
                  label: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  backgroundColor: const Color(0xFF1565C0),
                  deleteIconColor: Colors.white,
                  onDeleted: () {
                    setState(() => _selectedTags.remove(tag));
                    _applyFilter();
                  },
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            Text('筛选结果 (${_filteredCustomers.length} 位客户)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _filteredCustomers.isEmpty
                  ? Center(child: Text(_selectedTags.isEmpty ? '请选择标签进行筛选' : '没有符合条件的客户', style: TextStyle(color: Colors.grey[600], fontSize: 16)))
                  : ListView.builder(
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Text(customer.name.substring(0, 1))),
                            title: Text(customer.name),
                            subtitle: Text('${customer.age ?? "-"}岁 • ${customer.gender ?? "-"}'),
                            trailing: Wrap(spacing: 4, children: [
                              ...customer.tagList.take(3).map((t) => Chip(label: Text(t, style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact)),
                              if (customer.tagList.length > 3)
                                Padding(padding: const EdgeInsets.only(top: 8), child: Text('+${customer.tagList.length - 3}', style: TextStyle(fontSize: 10, color: Colors.grey[600]))),
                              ...List.generate(5, (i) => Icon(i < (customer.rating ?? 0) ? Icons.star : Icons.star_border, color: Colors.amber, size: 14)),
                            ]),
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
