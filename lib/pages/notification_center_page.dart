import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';

class NotificationCenterPage extends StatefulWidget {
  @override
  _NotificationCenterPageState createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).loadSystemNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    final overdue = appState.overdueReminders;
    final today = appState.todayReminders;
    final upcoming = appState.reminders.where((r) {
      final date = r['reminder_date'] as String?;
      if (date == null) return false;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      return date.compareTo(todayStr) > 0 && r['status'] == 'pending';
    }).toList()
      ..sort(
        (a, b) => (a['reminder_date'] as String).compareTo(b['reminder_date'] as String),
      );

    final sysNotifs = appState.systemNotifications;

    // Group system notifications by type
    final followUpNotifs = sysNotifs.where((n) => n['type'] == 'follow_up').toList();
    final policyExpiryNotifs = sysNotifs.where((n) => n['type'] == 'policy_expiry').toList();
    final birthdayNotifs = sysNotifs.where((n) => n['type'] == 'birthday').toList();

    // Total unread count for badge
    final totalUnread = overdue.length + sysNotifs.where((n) => n['isUrgent'] == true).length;

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
                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.loadReminders();
          await appState.loadSystemNotifications();
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
              ...followUpNotifs.map((n) => _buildSystemNotificationCard(n, isDark)),
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
              ...policyExpiryNotifs.map((n) => _buildSystemNotificationCard(n, isDark)),
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
              ...birthdayNotifs.map((n) => _buildSystemNotificationCard(n, isDark)),
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
              ...overdue.map((r) => _buildReminderCard(r, isDark, primaryColor, isOverdue: true)),
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
              ...today.map((r) => _buildReminderCard(r, isDark, primaryColor)),
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
              ...upcoming.take(10).map((r) => _buildReminderCard(r, isDark, primaryColor)),
            ],

            // ====== 空状态 ======
            if (overdue.isEmpty && today.isEmpty && upcoming.isEmpty &&
                followUpNotifs.isEmpty && policyExpiryNotifs.isEmpty && birthdayNotifs.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade300),
                      SizedBox(height: 16),
                      Text('暂无通知', style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
                      SizedBox(height: 8),
                      Text('所有待办和系统通知将在这里显示',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade300)),
                    ],
                  ),
                ),
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
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: color),
        ),
        SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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
        color: isDark ? Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isUrgent ? Border.all(color: (color as Color).withOpacity(0.3)) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
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
                        notif['title'] ?? '',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        margin: EdgeInsets.only(left: 8),
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Color(0xFFE53935).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('紧急', style: TextStyle(fontSize: 10, color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  notif['subtitle'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
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
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: color),
        ),
        SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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
    final typeIcon = {
      'follow_up': Icons.phone_rounded,
      'visit': Icons.directions_walk_rounded,
      'renewal': Icons.autorenew_rounded,
      'birthday': Icons.cake_rounded,
      'other': Icons.event_rounded,
    };
    final typeColor = {
      'follow_up': Color(0xFF1E88E5),
      'visit': Color(0xFF43A047),
      'renewal': Color(0xFFFF9800),
      'birthday': Color(0xFFAB47BC),
      'other': Color(0xFF78909C),
    };
    final typeLabel = {
      'follow_up': '跟进',
      'visit': '拜访',
      'renewal': '续期',
      'birthday': '生日',
      'other': '其他',
    };

    final rType = reminder['type'] as String? ?? 'follow_up';
    final color = typeColor[rType] ?? Color(0xFF78909C);

    return Dismissible(
      key: ValueKey(reminder['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Color(0xFFE53935), borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (direction) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.deleteReminder(reminder['id'] as int);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isOverdue && !isCompleted ? Border.all(color: Color(0xFFE53935).withOpacity(0.3)) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: Offset(0, 1))],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                final appState = Provider.of<AppState>(context, listen: false);
                appState.updateReminderStatus(reminder['id'] as int, isCompleted ? 'pending' : 'completed');
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isCompleted ? Color(0xFF43A047) : Colors.transparent,
                  border: Border.all(color: isCompleted ? Color(0xFF43A047) : Colors.grey.shade400, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isCompleted ? Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
              ),
            ),
            SizedBox(width: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(typeIcon[rType] ?? Icons.event_rounded, size: 18, color: color),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder['title'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? Colors.grey : null,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                        child: Text(typeLabel[rType] ?? '其他', style: TextStyle(fontSize: 10, color: color)),
                      ),
                      SizedBox(width: 8),
                      if (reminder['customer_name'] != null)
                        Text(reminder['customer_name'], style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                      SizedBox(width: 4),
                      Text(
                        '${reminder['reminder_date'] ?? ''}${reminder['reminder_time'] != null ? " ${reminder['reminder_time']}" : ""}',
                        style: TextStyle(fontSize: 12, color: isOverdue && !isCompleted ? Color(0xFFE53935) : Colors.grey.shade400),
                      ),
                      if (isOverdue && !isCompleted) ...[
                        SizedBox(width: 8),
                        Text('超期', style: TextStyle(fontSize: 11, color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
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
