import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/customer.dart';

// 客户分组页面
class CustomerGroupingPage extends StatefulWidget {
  @override
  _CustomerGroupingPageState createState() => _CustomerGroupingPageState();
}

class _CustomerGroupingPageState extends State<CustomerGroupingPage> {
  String _selectedGroupBy = 'age'; // 默认按年龄段分组
  Map<String, List<Customer>> _groupedCustomers = {};

  @override
  void initState() {
    super.initState();
    _groupByCustomers();
  }

  Future<void> _groupByCustomers() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final customers = appState.customers;

    Map<String, List<Customer>> grouped;

    switch (_selectedGroupBy) {
      case 'age':
        grouped = _groupByAge(customers);
        break;
      case 'location':
        grouped = _groupByLocation(customers);
        break;
      case 'industry':
        grouped = {'默认分组': customers};
        break;
      default:
        grouped = {'全部客户': customers};
    }

    setState(() {
      _groupedCustomers = grouped;
    });
  }

  Map<String, List<Customer>> _groupByAge(List<Customer> customers) {
    final groups = <String, List<Customer>>{};
    for (var c in customers) {
      final age = c.age ?? 0;
      String key;
      if (age < 25)
        key = '25岁以下';
      else if (age < 35)
        key = '25-34岁';
      else if (age < 45)
        key = '35-44岁';
      else if (age < 55)
        key = '45-54岁';
      else
        key = '55岁以上';
      groups.putIfAbsent(key, () => []).add(c);
    }
    return groups;
  }

  Map<String, List<Customer>> _groupByLocation(List<Customer> customers) {
    final groups = <String, List<Customer>>{};
    for (var c in customers) {
      final addr = c.addresses.isNotEmpty ? c.addresses.first : '未知地区';
      final key = addr.length > 4 ? addr.substring(0, 4) : addr;
      groups.putIfAbsent(key, () => []).add(c);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('客户分组')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('分组方式', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment<String>(value: 'age', label: Text('年龄段')),
                        ButtonSegment<String>(
                          value: 'location',
                          label: Text('地区'),
                        ),
                        ButtonSegment<String>(
                          value: 'industry',
                          label: Text('行业'),
                        ),
                      ],
                      selected: {_selectedGroupBy},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _selectedGroupBy = newSelection.first;
                          _groupByCustomers();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: _groupedCustomers.isEmpty
                  ? Center(child: Text('没有客户数据'))
                  : ListView.builder(
                      itemCount: _groupedCustomers.keys.length,
                      itemBuilder: (context, groupIndex) {
                        final groupName = _groupedCustomers.keys.elementAt(
                          groupIndex,
                        );
                        final groupCustomers = _groupedCustomers[groupName]!;

                        if (groupCustomers.isEmpty) return SizedBox.shrink();

                        return Card(
                          child: ExpansionTile(
                            title: Row(
                              children: [
                                Icon(
                                  Icons.people,
                                  color: Theme.of(context).primaryColor,
                                ),
                                SizedBox(width: 8),
                                Text(groupName),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${groupCustomers.length}人',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: groupCustomers.length,
                                itemBuilder: (context, customerIndex) {
                                  final customer =
                                      groupCustomers[customerIndex];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text(
                                        customer.name.substring(0, 1),
                                      ),
                                    ),
                                    title: Text(customer.name),
                                    subtitle: Text(
                                      '${customer.age}岁 • ${customer.gender}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (
                                          int i = 0;
                                          i < (customer.rating ?? 0);
                                          i++
                                        )
                                          Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                        for (
                                          int i = (customer.rating ?? 0);
                                          i < 5;
                                          i++
                                        )
                                          Icon(
                                            Icons.star_border,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
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
