import 'package:flutter/material.dart';
import '../models/tag.dart';

// 标签选择器组件
class TagSelector extends StatelessWidget {
  final List<Tag> allTags;
  final List<int> selectedTagIds;
  final Function(List<int>) onSelectionChanged;
  final String title;

  const TagSelector({
    Key? key,
    required this.allTags,
    required this.selectedTagIds,
    required this.onSelectionChanged,
    this.title = '选择标签',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Container(
        width: double.maxFinite,
        child: Wrap(
          spacing: 8,
          children: allTags.map((tag) {
            final isSelected = selectedTagIds.contains(tag.id!);
            return FilterChip(
              label: Text(tag.name),
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Color(
                        int.parse('FF\${tag.color.substring(1)}', radix: 16),
                      ),
              ),
              selected: isSelected,
              selectedColor: Color(
                int.parse('FF\${tag.color.substring(1)}', radix: 16),
              ),
              onSelected: (selected) {
                final newSelection = List<int>.from(selectedTagIds);
                if (selected) {
                  newSelection.add(tag.id!);
                } else {
                  newSelection.remove(tag.id!);
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
