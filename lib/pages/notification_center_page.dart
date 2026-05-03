import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/widgets/app_components.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  _NotificationCenterPageState createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  // Reminder type labels - using AppDesign.reminderTypeLabel()

  // Cached filtered results to avoid recomputing on every build
  List<Map<String, dynamic>> _cachedOverdue = [];
  List<Map<String, dynamic>> _cachedToday = [];
  List<Map<String, dynamic>> _cachedUpcoming = [];
  List<Map<String, dynamic>> _cachedFollowUp = [];
  List<Map<String, dynamic>> _cachedPolicyExpiry = [];
  List<Map<String, dynamic>> _cachedBirthday = [];
  int _cachedTotalUnread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).loadSystemNotifications();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCachedNotifications();
  }

  void _updateCachedNotifications() {
    final appState = Provider.of<AppState>(context);
    _cachedOverdue = appState.overdueReminders;
    _cachedToday = appState.todayReminders.where((r) => r['status'] == 'pending').toList();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    _cachedUpcoming = appState.reminders.where((r) {
      final date = r['reminder_date'] as String?;
      if (date == null) return false;
      return date.compareTo(todayStr) > 0 && r['status'] == 'pending';
    }).toList()..sort((a, b) {
      final aDate = a['reminder_date'] as String? ?? '';
      final bDate = b['reminder_date'] as String? ?? '';
      return aDate.compareTo(bDate);
    });

    final sysNotifs = appState.systemNotifications;
    _cachedFollowUp = sysNotifs.where((n) => n['type'] == 'follow_up').toList();
    _cachedPolicyExpiry = sysNotifs.where((n) => n['type'] == 'policy_expiry').toList();
    _cachedBirthday = sysNotifs.where((n) => n['type'] == 'birthday').toList();
    _cachedTotalUnread = _cachedOverdue.length + sysNotifs.where((n) => n['isRead'] != true).length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // Use cached values instead of recomputing on every build
    final overdue = _cachedOverdue;
    final today = _cachedToday;
    final upcoming = _cachedUpcoming;
    final followUpNotifs = _cachedFollowUp;
    final policyExpiryNotifs = _cachedPolicyExpiry;
    final birthdayNotifs = _cachedBirthday;
    final totalUnread = _cachedTotalUnread;

    return Scaffold(
      appBar: AppBar(
        title: Text('通知中心'),
        actions: [
          if (totalUnread > 0)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalUnread',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final appState = Provider.of<AppState>(context, listen: false);
          await Future.wait([
            appState.loadReminders(),
            appState.loadSystemNotifications(),
          ]);
          _updateCachedNotifications();
          if (mounted) setState(() {});
        },
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // ====== 系统通知 ======
            if (followUpNotifs.isNotEmpty) ...[
              _buildSystemSectionHeader(
                icon: Icons.phone_rounded,
                color: Color(0xFFE53935),
                title: '跟进到期提醒',
                count: followUpNotifs.length,
              ),
              SizedBox(height: 12),
              ...followUpNotifs.map<Widget>(
                (n) => _buildSystemNotificationCard(n, isDark),
              ),
              SizedBox(height: 24),
            ],

            if (policyExpiryNotifs.isNotEmpty) ...[
              _buildSystemSectionHeader(
                icon: Icons.autorenew_rounded,
                color: Color(0xFFFF9800),
                title: '保单到期提醒',
                count: policyExpiryNotifs.length,
              ),
              SizedBox(height: 12),
              ...policyExpiryNotifs.map<Widget>(
                (n) => _buildSystemNotificationCard(n, isDark),
              ),
              SizedBox(height: 24),
            ],

            if (birthdayNotifs.isNotEmpty) ...[
              _buildSystemSectionHeader(
                icon: Icons.cake_rounded,
                color: Color(0xFFAB47BC),
                title: '客户生日提醒',
                count: birthdayNotifs.length,
              ),
              SizedBox(height: 12),
              ...birthdayNotifs.map<Widget>(
                (n) => _buildSystemNotificationCard(n, isDark),
              ),
              SizedBox(height: 24),
            ],

            // ====== 超期提醒 ======
            if (overdue.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.warning_amber_rounded,
                color: Color(0xFFE53935),
                title: '超期未处理',
                count: overdue.length,
              ),
              SizedBox(height: 12),
              ...overdue.map<Widget>(
                (r) => _buildReminderCard(
                  r,
                  isDark,
                  primaryColor,
                  isOverdue: true,
                ),
              ),
              SizedBox(height: 24),
            ],

            // ====== 今日待办 ======
            if (today.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.today_rounded,
                color: Color(0xFF1E88E5),
                title: '今日待办',
                count: today.length,
              ),
              SizedBox(height: 12),
              ...today.map<Widget>((r) => _buildReminderCard(r, isDark, primaryColor)),
              SizedBox(height: 24),
            ],

            // ====== 即将到来 ======
            if (upcoming.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.upcoming_rounded,
                color: Color(0xFF43A047),
                title: '即将到来',
                count: upcoming.length,
              ),
              SizedBox(height: 12),
              ...upcoming
                  .take(10)
                  .map<Widget>((r) => _buildReminderCard(r, isDark, primaryColor)),
            ],

            // ====== 空状态 ======
            if (overdue.isEmpty &&
                today.isEmpty &&
                upcoming.isEmpty &&
                followUpNotifs.isEmpty &&
                policyExpiryNotifs.isEmpty &&
                birthdayNotifs.isEmpty)
              const EmptyStatePlaceholder(
                  icon: Icons.notifications_none_rounded,
                  message: '暂无通知',
                  actionHint: '所有待办和系统通知将在这里显示',
                ),
          ],
        ),
      ),
    );
  }

  // ========== System Notification Widgets ==========

  Widget _buildSystemSectionHeader({
    required IconData icon,
    required Color color,
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemNotificationCard(Map<String, dynamic> notif, bool isDark) {
    final isUrgent = notif['isUrgent'] as bool? ?? false;
    final icon = notif['icon'] as IconData? ?? Icons.info_outline;
    final color = notif['color'] as Color? ?? Color(0xFF78909C);

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(12),
        border: isUrgent
            ? Border.all(color: color.withValues(alpha: 0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (notif['title'] as String?) ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        margin: EdgeInsets.only(left: 8),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFFE53935).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '紧急',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFE53935),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  (notif['subtitle'] as String?) ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  // ========== Reminder Widgets ==========

  Widget _buildSectionHeader({
    required IconData icon,
    required Color color,
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderCard(
    Map<String, dynamic> reminder,
    bool isDark,
    Color primaryColor, {
    bool isOverdue = false,
  }) {
    final isCompleted = reminder['status'] == 'completed';
    final rType = reminder['type'] as String? ?? 'follow_up';
    final color = AppDesign.reminderTypeColors[rType] ?? Color(0xFF78909C);

    return Dismissible(
      key: ValueKey('notif_reminder_${reminder['id'] ?? reminder.hashCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Color(0xFFE53935),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (direction) {
        if (!mounted) return;
        final appState = Provider.of<AppState>(context, listen: false);
        appState.deleteReminder((reminder['id'] as num?)?.toInt() ?? -1);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppDesign.cardBg(isDark),
          borderRadius: BorderRadius.circular(12),
          border: isOverdue && !isCompleted
              ? Border.all(color: Color(0xFFE53935).withValues(alpha: 0.3))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () {
                final appState = Provider.of<AppState>(context, listen: false);
                appState.updateReminderStatus(
                  (reminder['id'] as num?)?.toInt() ?? -1,
                  isCompleted ? 'pending' : 'completed',
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isCompleted ? Color(0xFF43A047) : Colors.transparent,
                  border: Border.all(
                    color: isCompleted
                        ? Color(0xFF43A047)
                        : Colors.grey.shade400,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isCompleted
                    ? Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            SizedBox(width: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                AppDesign.reminderTypeIcons[rType] ?? Icons.event_rounded,
                size: 18,
                color: color,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (reminder['title'] as String?) ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: isCompleted ? Colors.grey : null,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppDesign.reminderTypeLabel(rType),
                          style: TextStyle(fontSize: 10, color: color),
                        ),
                      ),
                      SizedBox(width: 8),
                      if (reminder['customer_name'] != null)
                        Text(
                          reminder['customer_name'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${(reminder['reminder_date'] as String?) ?? ''}${reminder['reminder_time'] != null ? " ${reminder['reminder_time']}" : ""}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue && !isCompleted
                              ? Color(0xFFE53935)
                              : Colors.grey.shade400,
                        ),
                      ),
                      if (isOverdue && !isCompleted) ...[
                        SizedBox(width: 8),
                        Text(
                          '超期',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFE53935),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
