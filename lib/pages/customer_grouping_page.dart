import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/customer.dart';
import '../widgets/app_components.dart';

// 客户分组页面
class CustomerGroupingPage extends StatefulWidget {
  const CustomerGroupingPage({super.key});

  @override
  _CustomerGroupingPageState createState() => _CustomerGroupingPageState();
}

class _CustomerGroupingPageState extends State<CustomerGroupingPage>
    with SingleTickerProviderStateMixin {
  String _selectedGroupBy = 'age';
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

  Map<String, List<Customer>> _groupByAge(List<Customer> customers) {
    final groups = <String, List<Customer>>{};
    for (var c in customers) {
      String key;
      if (c.age == null) {
        key = '未知年龄';
      } else if (c.age! < 25) {
        key = '25岁以下';
      } else if (c.age! < 35) {
        key = '25-34岁';
      } else if (c.age! < 45) {
        key = '35-44岁';
      } else if (c.age! < 55) {
        key = '45-54岁';
      } else {
        key = '55岁以上';
      }
      groups.putIfAbsent(key, () => []).add(c);
    }
    return groups;
  }

  Map<String, List<Customer>> _groupByLocation(List<Customer> customers) {
    final groups = <String, List<Customer>>{};
    for (var c in customers) {
      final addr = (c.addresses.isNotEmpty && c.addresses.first.trim().isNotEmpty)
          ? c.addresses.first.trim()
          : '未知地区';
      String key;
      final match = RegExp(r'^(.+?[省市])').firstMatch(addr);
      if (match != null) {
        key = match.group(1)!;
      } else if (addr.length > 6) {
        key = addr.substring(0, 6);
      } else {
        key = addr;
      }
      groups.putIfAbsent(key, () => []).add(c);
    }
    return groups;
  }

  Map<String, List<Customer>> _groupByIndustry(List<Customer> customers) {
    final groups = <String, List<Customer>>{};
    for (var c in customers) {
      final key = c.occupation?.trim().isNotEmpty == true
          ? c.occupation!.trim()
          : '未知行业';
      groups.putIfAbsent(key, () => []).add(c);
    }
    return groups;
  }

  Map<String, List<Customer>> _computeGroups(List<Customer> customers) {
    switch (_selectedGroupBy) {
      case 'age':
        return _groupByAge(customers);
      case 'location':
        return _groupByLocation(customers);
      case 'industry':
        return _groupByIndustry(customers);
      default:
        return {'全部客户': customers};
    }
  }

  // Group icons for visual variety
  static const _groupIcons = <String, IconData>{
    'age': Icons.cake_rounded,
    'location': Icons.location_on_rounded,
    'industry': Icons.work_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final customers = appState.customers;
    final primaryColor = Theme.of(context).primaryColor;
    final groupedCustomers = _computeGroups(customers);

    return Scaffold(
      appBar: AppBar(title: const Text('客户分组')),
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
              children: [
                // Grouping selector card
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
                            child: Icon(Icons.category_rounded,
                                size: 18, color: primaryColor),
                          ),
                          const SizedBox(width: 10),
                          Text('分组方式',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'age',
                            label: Text('年龄段'),
                            icon: Icon(Icons.cake_rounded, size: 18),
                          ),
                          ButtonSegment<String>(
                            value: 'location',
                            label: Text('地区'),
                            icon: Icon(Icons.location_on_rounded, size: 18),
                          ),
                          ButtonSegment<String>(
                            value: 'industry',
                            label: Text('行业'),
                            icon: Icon(Icons.work_rounded, size: 18),
                          ),
                        ],
                        selected: {_selectedGroupBy},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedGroupBy = newSelection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Text(
                        '共 ${groupedCustomers.length} 个分组',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500),
                      ),
                      const Spacer(),
                      Text(
                        '${customers.length} 位客户',
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: groupedCustomers.isEmpty
                      ? const EmptyStatePlaceholder(
                          icon: Icons.people_outline_rounded,
                          message: '没有客户数据',
                          actionHint: '先添加一些客户吧',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: groupedCustomers.keys.length,
                          itemBuilder: (context, groupIndex) {
                            final groupName =
                                groupedCustomers.keys.elementAt(groupIndex);
                            final groupCustomers =
                                groupedCustomers[groupName]!;

                            if (groupCustomers.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                padding: EdgeInsets.zero,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    dividerColor: Colors.transparent,
                                  ),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.fromLTRB(
                                        14, 8, 14, 8),
                                    childrenPadding: const EdgeInsets.only(
                                        bottom: 8),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: primaryColor
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _groupIcons[_selectedGroupBy] ??
                                            Icons.people_rounded,
                                        size: 20,
                                        color: primaryColor,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(groupName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15)),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryColor
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${groupCustomers.length}人',
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    children: [
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: groupCustomers.length,
                                        itemBuilder:
                                            (context, customerIndex) {
                                          final customer =
                                              groupCustomers[customerIndex];
                                          return Padding(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 10,
                                                vertical: 3),
                                            child: Row(
                                              children: [
                                                CustomerAvatar(
                                                    name: customer.name,
                                                    radius: 18),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        customer.name,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500,
                                                            fontSize: 14),
                                                      ),
                                                      const SizedBox(
                                                          height: 2),
                                                      Text(
                                                        '${customer.age != null ? '${customer.age}岁' : '年龄未知'} • ${customer.gender ?? '性别未知'}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey.shade500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                RatingBadge(
                                                    rating: customer.rating),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
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
