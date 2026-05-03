import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/models/customer.dart';
import 'package:insurance_manager/widgets/app_components.dart';

// 标签筛选页面
class TagFilterPage extends StatefulWidget {
  const TagFilterPage({super.key});

  @override
  State<TagFilterPage> createState() => _TagFilterPageState();
}

class _TagFilterPageState extends State<TagFilterPage>
    with SingleTickerProviderStateMixin {
  List<String> _selectedTags = [];
  List<Customer> _filteredCustomers = [];
  bool _isFiltering = false;
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _applyFilter() async {
    if (_selectedTags.isEmpty) {
      setState(() => _filteredCustomers = []);
      return;
    }
    setState(() => _isFiltering = true);
    final appState = Provider.of<AppState>(context, listen: false);
    final customers = appState.searchCustomersWithTags(_selectedTags);
    if (!mounted) return;
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
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('标签筛选')),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(_fadeAnimation),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag selection card
                AppCard(
                  padding: const EdgeInsets.all(16),
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.filter_list_rounded,
                                size: 18, color: primaryColor),
                          ),
                          const SizedBox(width: 10),
                          Text('选择标签',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (tags.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: EmptyStatePlaceholder(
                            icon: Icons.label_off_rounded,
                            message: '暂无标签，请先在标签管理中添加',
                            iconSize: 48,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: tags.map<Widget>((tag) {
                            final isSelected = _selectedTags.contains(tag);
                            return FilterChip(
                              label: Text(tag),
                              selected: isSelected,
                              selectedColor: primaryColor,
                              labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black87)),
                              checkmarkColor: Colors.white,
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
                            onPressed: _selectedTags.isEmpty
                                ? null
                                : _applyFilter,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: _isFiltering
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Text('应用筛选'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                            onPressed: _clearFilter,
                            child: const Text('清除')),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Selected tags summary
                if (_selectedTags.isNotEmpty) ...[
                  Row(
                    children: [
                      Text('已选择标签 (${_selectedTags.length})',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Wrap(
                        spacing: 6,
                        children: _selectedTags
                            .map<Widget>((tag) => Chip(
                                  label: Text(tag,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                  backgroundColor: primaryColor,
                                  deleteIconColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  onDeleted: () {
                                    setState(() {
                                      _selectedTags.remove(tag);
                                    });
                                    _applyFilter();
                                  },
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                // Results section
                SectionHeader(
                  title: '筛选结果 (${_filteredCustomers.length} 位客户)',
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _filteredCustomers.isEmpty
                      ? EmptyStatePlaceholder(
                          icon: Icons.filter_alt_off_rounded,
                          message: _selectedTags.isEmpty
                              ? '请选择标签进行筛选'
                              : '没有符合条件的客户',
                          actionHint: _selectedTags.isEmpty
                              ? '选择上方标签后点击应用筛选'
                              : '尝试减少标签或更换组合',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: AppCard(
                                padding: const EdgeInsets.all(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => Scaffold(
                                        appBar: AppBar(
                                            title:
                                                Text(customer.name)),
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    CustomerAvatar(name: customer.name),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(customer.name,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 15)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${customer.age ?? "-"}岁 • ${customer.gender ?? "-"}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  Colors.grey.shade500,
                                            ),
                                          ),
                                          if (customer.tagList
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            TagList(
                                                tags: customer.tagList),
                                          ],
                                        ],
                                      ),
                                    ),
                                    RatingBadge(rating: customer.rating),
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
      ),
    );
  }
}
