import 'package:flutter/material.dart';
import '../models/tag.dart';

// 标签选择器组件
class TagSelector extends StatelessWidget {
  final List<Tag> allTags;
  final List<int> selectedTagIds;
  final Function(List<int>) onSelectionChanged;
  final String title;

  const TagSelector({
    super.key,
    required this.allTags,
    required this.selectedTagIds,
    required this.onSelectionChanged,
    this.title = '选择标签',
  });

  /// Safely parse a hex color string (supports #RGB, #RRGGBB, RRGGBB)
  static Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return const Color(0xFF1565C0);
    final hex = colorStr.startsWith('#') ? colorStr.substring(1) : colorStr;
    if (hex.length == 3) {
      // Expand #RGB to #RRGGBB
      final expanded = 'FF${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
      final value = int.tryParse(expanded, radix: 16);
      return value != null ? Color(value) : const Color(0xFF1565C0);
    }
    if (hex.length == 6) {
      final value = int.tryParse('FF$hex', radix: 16);
      return value != null ? Color(value) : const Color(0xFF1565C0);
    }
    return const Color(0xFF1565C0);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: Wrap(
          spacing: 8,
          children: allTags.map<Widget>((tag) {
            final tagId = tag.id;
            final isSelected = tagId != null && selectedTagIds.contains(tagId);
            final tagColor = _parseColor(tag.color);
            return FilterChip(
              label: Text(tag.name),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : tagColor,
              ),
              selected: isSelected,
              selectedColor: tagColor,
              onSelected: (selected) {
                if (tagId == null) return;
                final newSelection = List<int>.from(selectedTagIds);
                if (selected) {
                  newSelection.add(tagId);
                } else {
                  newSelection.remove(tagId);
                }
                onSelectionChanged(newSelection);
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('关闭')),
      ],
    );
  }
}
