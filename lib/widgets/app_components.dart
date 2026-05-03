import 'package:flutter/material.dart';

/// Shared app design constants and reusable UI components for consistent styling.
class AppDesign {
  AppDesign._();

  // ── Spacing ──
  static const double paddingPage = 16;
  static const double paddingCard = 16;
  static const double spacingSection = 24;
  static const double spacingItem = 8;

  // ── Border Radius ──
  static const double radiusCard = 14;
  static const double radiusSearch = 14;
  static const double radiusChip = 8;
  static const double radiusButton = 12;
  static const double radiusAvatar = 12;

  // ── Card Background Color ──
  static Color cardBg(bool isDark) => isDark ? const Color(0xFF2C2C2C) : Colors.white;

  // ── Subtitle Text Color ──
  static Color subtitleColor(bool isDark) => isDark ? Colors.grey.shade400 : Colors.grey.shade600;

  // ── Card Shadow ──
  static BoxShadow cardShadow(BuildContext context) => BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: Offset(0, 2),
      );

  // ── Rating Colors & Labels ──
  static const Map<int, Color> ratingColors = {
    5: Color(0xFFE53935),
    4: Color(0xFFFF9800),
    3: Color(0xFFFDD835),
    2: Color(0xFF43A047),
    1: Color(0xFF42A5F5),
  };

  static const Map<int, String> ratingLabels = {
    5: '高意向',
    4: '中高意向',
    3: '中等意向',
    2: '低意向',
    1: '无意向',
  };

  static Color ratingColor(int? rating) =>
      ratingColors[rating] ?? Colors.grey;

  static String ratingLabel(int? rating) =>
      ratingLabels[rating] ?? '未评级';

  // ── Relationship Colors & Labels ──
  static const Map<String, Color> relationshipColors = {
    'family': Color(0xFFE53935),
    'friend': Color(0xFF1E88E5),
    'colleague': Color(0xFF43A047),
    'client_referral': Color(0xFFFF9800),
    'other': Color(0xFF78909C),
  };

  static const Map<String, String> relationshipLabels = {
    'family': '家人',
    'friend': '朋友',
    'colleague': '同事',
    'client_referral': '客户转介',
    'other': '其他',
  };

  static Color relColor(String? type) =>
      relationshipColors[type] ?? relationshipColors['other']!;

  static String relLabel(String? type) =>
      relationshipLabels[type] ?? relationshipLabels['other']!;

  // ── Reminder Type Icons & Colors ──
  static const Map<String, IconData> reminderTypeIcons = {
    'follow_up': Icons.phone_rounded,
    'visit': Icons.directions_walk_rounded,
    'renewal': Icons.autorenew_rounded,
    'birthday': Icons.cake_rounded,
    'other': Icons.event_rounded,
  };

  static const Map<String, Color> reminderTypeColors = {
    'follow_up': Color(0xFF1E88E5),
    'visit': Color(0xFF43A047),
    'renewal': Color(0xFFFF9800),
    'birthday': Color(0xFFAB47BC),
    'other': Color(0xFF78909C),
  };

  // ── Category Colors ──
  static const Map<String, Color> categoryColors = {
    '寿险': Color(0xFFE53935),
    '健康险': Color(0xFF43A047),
    '意外险': Color(0xFFFF9800),
    '年金险': Color(0xFFAB47BC),
    '重疾险': Color(0xFF1E88E5),
  };

  static Color categoryColor(String? category) =>
      categoryColors[category] ?? const Color(0xFF1565C0);

  // ── Chinese Relationship Colors (used in settings/network/detail) ──
  static const Map<String, Color> cnRelColors = {
    '家人': Color(0xFFE53935),
    '朋友': Color(0xFF43A047),
    '同事': Color(0xFF1565C0),
    '同学': Color(0xFFFF9800),
    '客户': Color(0xFF8E24AA),
    '邻居': Color(0xFF00897B),
  };

  static Color cnRelColor(String? label) =>
      cnRelColors[label] ?? const Color(0xFF78909C);

  // ── Reminder Type Labels ──
  static const Map<String, String> reminderTypeLabels = {
    'follow_up': '跟进',
    'visit': '拜访',
    'renewal': '续期',
    'birthday': '生日',
    'other': '其他',
  };

  static String reminderTypeLabel(String? type) =>
      reminderTypeLabels[type] ?? '其他';

  // ── Grouped Section Background ──
  static Color groupedBg(bool isDark) => isDark ? const Color(0xFF1E1E1E) : Colors.white;

  // ── iOS-style background (0xFFF2F2F7 light, dark mode equivalent) ──
  static Color iosBg(bool isDark) => isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
}

/// Unified card container with consistent styling, optional InkWell for tap.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double borderRadius;
  final double elevation;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.borderRadius = AppDesign.radiusCard,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = color ?? (isDark ? const Color(0xFF2C2C2C) : Colors.white);

    final container = Container(
      margin: margin ?? const EdgeInsets.only(bottom: 8),
      padding: padding ?? const EdgeInsets.all(AppDesign.paddingCard),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06 * elevation),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : [
                AppDesign.cardShadow(context),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: container,
        ),
      );
    }
    return container;
  }
}

/// Unified search bar with consistent styling.
class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String? searchQuery;
  final IconData prefixIcon;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = '搜索...',
    this.onChanged,
    this.onClear,
    this.searchQuery,
    this.prefixIcon = Icons.search_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(AppDesign.radiusSearch),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          prefixIcon: Icon(prefixIcon, color: primaryColor, size: 22),
          suffixIcon: (searchQuery != null && searchQuery!.isNotEmpty)
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, size: 20),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

/// Unified empty state placeholder with icon, text, and optional action hint.
class EmptyStatePlaceholder extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionHint;
  final double iconSize;

  const EmptyStatePlaceholder({
    super.key,
    required this.icon,
    required this.message,
    this.actionHint,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Theme.of(context).primaryColor.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize * 0.6,
                color: isDark
                    ? Colors.grey.shade500
                    : Theme.of(context).primaryColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (actionHint != null) ...[
              const SizedBox(height: 8),
              Text(
                actionHint!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade300,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rating badge widget used in customer cards.
class RatingBadge extends StatelessWidget {
  final int? rating;
  const RatingBadge({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    final color = AppDesign.ratingColor(rating);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        AppDesign.ratingLabel(rating),
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Customer avatar with initial letter.
class CustomerAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const CustomerAvatar({
    super.key,
    required this.name,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return CircleAvatar(
      radius: radius,
      backgroundColor: primaryColor.withValues(alpha: 0.1),
      child: Text(
        name.isNotEmpty ? name.substring(0, 1) : '',
        style: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.67,
        ),
      ),
    );
  }
}

/// Tag chip used in customer cards.
class TagChip extends StatelessWidget {
  final String tag;
  const TagChip({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: TextStyle(fontSize: 10, color: primaryColor),
      ),
    );
  }
}

/// Tag list widget (up to maxVisible tags with overflow indicator).
class TagList extends StatelessWidget {
  final List<String> tags;
  final int maxVisible;
  const TagList({super.key, required this.tags, this.maxVisible = 3});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        ...tags.take(maxVisible).map<Widget>((t) => TagChip(tag: t)),
        if (tags.length > maxVisible)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              '+${tags.length - maxVisible}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ),
      ],
    );
  }
}

/// Section header with title and optional trailing widget.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Reusable "Add" trailing button for grouped sections.
class AddSectionButton extends StatelessWidget {
  final VoidCallback onTap;
  const AddSectionButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: primaryColor),
            SizedBox(width: 4),
            Text('添加', style: TextStyle(color: primaryColor, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Unified SnackBar helper for consistent styling.
class AppSnackBar {
  AppSnackBar._();

  static void success(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  static void error(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  static void info(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}
