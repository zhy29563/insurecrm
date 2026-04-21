import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final appState = Provider.of<AppState>(context, listen: false);
    final dateStr = day.toIso8601String().substring(0, 10);
    return appState.reminders
        .where((r) => r['reminder_date'] == dateStr)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: Text('日历')),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: primaryColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              formatButtonDecoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              formatButtonTextStyle: TextStyle(color: primaryColor),
            ),
          ),
          SizedBox(height: 8),
          Divider(height: 1),
          Expanded(child: _buildDayEvents(appState, isDark, primaryColor)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReminderDialog(context),
        child: Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildDayEvents(AppState appState, bool isDark, Color primaryColor) {
    if (_selectedDay == null) {
      return Center(
        child: Text('请选择日期', style: TextStyle(color: Colors.grey)),
      );
    }

    final events = _getEventsForDay(_selectedDay!);
    final dateStr =
        '${_selectedDay!.year}年${_selectedDay!.month}月${_selectedDay!.day}日';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (events.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${events.length}项',
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      SizedBox(height: 12),
                      Text(
                        '当日暂无待办',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return _buildEventCard(events[index], isDark, primaryColor);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventCard(
    Map<String, dynamic> reminder,
    bool isDark,
    Color primaryColor,
  ) {
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
        color: Color(0xFFE53935),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                final appState = Provider.of<AppState>(context, listen: false);
                appState.updateReminderStatus(
                  reminder['id'] as int,
                  isCompleted ? 'pending' : 'completed',
                );
              },
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
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                typeIcon[rType] ?? Icons.event_rounded,
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
                    reminder['title'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: isCompleted ? Colors.grey : null,
                    ),
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel[rType] ?? '其他',
                          style: TextStyle(fontSize: 10, color: color),
                        ),
                      ),
                      SizedBox(width: 8),
                      if (reminder['customer_name'] != null)
                        Text(
                          reminder['customer_name'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      if (reminder['reminder_time'] != null) ...[
                        SizedBox(width: 8),
                        Text(
                          reminder['reminder_time'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
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

  void _showAddReminderDialog(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final dateController = TextEditingController(
      text: _selectedDay != null
          ? '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}'
          : DateTime.now().toIso8601String().substring(0, 10),
    );
    final timeController = TextEditingController();
    String selectedType = 'follow_up';
    int? selectedCustomerId;

    final types = ['follow_up', 'visit', 'renewal', 'birthday', 'other'];
    final typeLabels = {
      'follow_up': '跟进',
      'visit': '拜访',
      'renewal': '续期',
      'birthday': '生日',
      'other': '其他',
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('添加待办'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: '标题',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: '描述',
                    prefixIcon: Icon(Icons.description_rounded),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: '日期',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDay ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      dateController.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }
                  },
                ),
                SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  decoration: InputDecoration(
                    labelText: '时间（可选）',
                    prefixIcon: Icon(Icons.access_time_rounded),
                    hintText: '如 09:00',
                  ),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: '类型',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: types
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(typeLabels[t] ?? t),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedCustomerId,
                  decoration: InputDecoration(
                    labelText: '关联客户',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  items: appState.customers
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedCustomerId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('请输入标题')));
                  return;
                }
                if (selectedCustomerId == null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('请选择关联客户')));
                  return;
                }
                await appState.addReminder(
                  customerId: selectedCustomerId!,
                  title: titleController.text,
                  description: descController.text.isNotEmpty
                      ? descController.text
                      : null,
                  reminderDate: dateController.text,
                  reminderTime: timeController.text.isNotEmpty
                      ? timeController.text
                      : null,
                  type: selectedType,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('待办已添加')));
              },
              child: Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}
