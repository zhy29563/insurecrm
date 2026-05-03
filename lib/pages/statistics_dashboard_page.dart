import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/widgets/app_components.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsDashboardPage extends StatefulWidget {
  const StatisticsDashboardPage({super.key});

  @override
  _StatisticsDashboardPageState createState() =>
      _StatisticsDashboardPageState();
}

class _StatisticsDashboardPageState extends State<StatisticsDashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _kpiAnimationController;
  late AnimationController _chartController;
  late Animation<double> _kpiCardAnimation;
  late Animation<double> _chartAnimation;

  // Static Tween to avoid recreating on every build call
  static final _slideUpTween = Tween<Offset>(
    begin: Offset(0, 0.1),
    end: Offset(0, 0),
  );

  @override
  void initState() {
    super.initState();

    // KPI卡片动画
    _kpiAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _kpiCardAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _kpiAnimationController, curve: Curves.easeOut));

    // 图表动画
    _chartController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _chartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _chartController,
        curve: Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = Provider.of<AppState>(context, listen: false);
      appState.loadStatistics();
      _kpiAnimationController.forward();
      _chartController.forward();
    });
  }

  @override
  void dispose() {
    _kpiAnimationController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('数据看板')),
      body: RefreshIndicator(
        onRefresh: () => appState.loadStatistics(),
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 核心指标卡片
              FadeTransition(
                opacity: _kpiCardAnimation,
                child: SlideTransition(
                  position: _slideUpTween.animate(_kpiCardAnimation),
                  child: _buildKPIRow(appState),
                ),
              ),
              SizedBox(height: 20),

              // 月度保费趋势
              FadeTransition(
                opacity: _chartAnimation,
                child: SlideTransition(
                  position: _slideUpTween.animate(_chartAnimation),
                  child: _buildSectionCard(
                    isDark: isDark,
                    icon: Icons.show_chart_rounded,
                    iconColor: Color(0xFF1E88E5),
                    title: '月度保费趋势',
                    child: SizedBox(
                      height: 220,
                      child: _buildSalesChart(appState, isDark),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // 月度拜访统计
              FadeTransition(
                opacity: _chartAnimation,
                child: SlideTransition(
                  position: _slideUpTween.animate(_chartAnimation),
                  child: _buildSectionCard(
                    isDark: isDark,
                    icon: Icons.event_note_rounded,
                    iconColor: Color(0xFF43A047),
                    title: '月度拜访统计',
                    child: SizedBox(
                      height: 220,
                      child: _buildVisitChart(appState, isDark),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // 客户意向分布
              FadeTransition(
                opacity: _chartAnimation,
                child: SlideTransition(
                  position: _slideUpTween.animate(_chartAnimation),
                  child: _buildSectionCard(
                    isDark: isDark,
                    icon: Icons.pie_chart_rounded,
                    iconColor: Color(0xFFAB47BC),
                    title: '客户意向分布',
                    child: SizedBox(
                      height: 220,
                      child: _buildRatingChart(appState, isDark),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // 产品销量排行
              FadeTransition(
                opacity: _chartAnimation,
                child: SlideTransition(
                  position: _slideUpTween.animate(_chartAnimation),
                  child: _buildSectionCard(
                    isDark: isDark,
                    icon: Icons.emoji_events_rounded,
                    iconColor: Color(0xFFFF9800),
                    title: '产品销量排行',
                    child: _buildProductRankingList(appState, isDark),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // 季度保费统计
              FadeTransition(
                opacity: _chartAnimation,
                child: SlideTransition(
                  position: _slideUpTween.animate(_chartAnimation),
                  child: _buildSectionCard(
                    isDark: isDark,
                    icon: Icons.calendar_view_month_rounded,
                    iconColor: Color(0xFF5C6BC0),
                    title: '季度保费统计',
                    child: _buildQuarterlySalesChart(appState, isDark),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // 佣金统计
              FadeTransition(
                opacity: _chartAnimation,
                child: SlideTransition(
                  position: _slideUpTween.animate(_chartAnimation),
                  child: _buildSectionCard(
                    isDark: isDark,
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: Color(0xFF66BB6A),
                    title: '佣金统计',
                    child: _buildCommissionChart(appState, isDark),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // 客户转化漏斗
              FadeTransition(
                opacity: _chartAnimation,
                child: SlideTransition(
                  position: _slideUpTween.animate(_chartAnimation),
                  child: _buildSectionCard(
                    isDark: isDark,
                    icon: Icons.linear_scale_rounded,
                    iconColor: Color(0xFFFFA726),
                    title: '客户转化漏斗',
                    child: _buildConversionFunnelChart(appState, isDark),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // 拜访效率分析
              FadeTransition(
                opacity: _chartAnimation,
                child: SlideTransition(
                  position: _slideUpTween.animate(_chartAnimation),
                  child: _buildSectionCard(
                    isDark: isDark,
                    icon: Icons.analytics_rounded,
                    iconColor: Color(0xFF26A69A),
                    title: '拜访效率分析',
                    child: _buildVisitEfficiencyList(appState, isDark),
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPIRow(AppState appState) {
    return Row(
      children: [
        Expanded(
          child: _buildKPICard(
            title: '本月保费',
            value: _formatAmount(appState.currentMonthSalesAmount),
            unit: '元',
            icon: Icons.payments_rounded,
            color: Color(0xFF1E88E5),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _buildKPICard(
            title: '本月拜访',
            value: '${appState.currentMonthVisitsCount}',
            unit: '次',
            icon: Icons.directions_walk_rounded,
            color: Color(0xFF43A047),
          ),
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(width: 4),
              Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSalesChart(AppState appState, bool isDark) {
    final months = List.generate(12, (i) => i + 1);
    final dataMap = <int, double>{};
    for (var item in appState.monthlySales) {
      final month = (item['month'] as num?)?.toInt();
      if (month != null) {
        dataMap[month] = (item['total_amount'] as num?)?.toDouble() ?? 0;
      }
    }

    final spots = months
        .map((m) => FlSpot(m.toDouble(), dataMap[m] ?? 0))
        .toList();
    final hasData = spots.any((s) => s.y > 0);

    if (!hasData) {
      return const EmptyStatePlaceholder(
        icon: Icons.bar_chart_rounded,
        message: '暂无销售数据',
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatAmount(value.toInt()),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}月',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Color(0xFF1E88E5),
            barWidth: 2.5,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Color(0xFF1E88E5).withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.x.toInt()}月: ${_formatAmount(spot.y.toInt())}元',
                  TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVisitChart(AppState appState, bool isDark) {
    final months = List.generate(12, (i) => i + 1);
    final dataMap = <int, double>{};
    for (var item in appState.monthlyVisits) {
      final month = (item['month'] as num?)?.toInt();
      if (month != null) {
        dataMap[month] = (item['count'] as num?)?.toDouble() ?? 0;
      }
    }

    final barGroups = months.map((m) {
      final value = dataMap[m] ?? 0;
      return BarChartGroupData(
        x: m,
        barRods: [
          BarChartRodData(
            toY: value,
            color: value > 0 ? Color(0xFF43A047) : Colors.grey.shade200,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    final hasData = dataMap.values.any((v) => v > 0);

    if (!hasData) {
      return const EmptyStatePlaceholder(
        icon: Icons.event_note_rounded,
        message: '暂无拜访数据',
      );
    }

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}月',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${group.x}月: ${rod.toY.toInt()}次',
                TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRatingChart(AppState appState, bool isDark) {
    final ratingData = appState.ratingDistribution;
    if (ratingData.isEmpty) {
      return const EmptyStatePlaceholder(
        icon: Icons.pie_chart_rounded,
        message: '暂无客户数据',
      );
    }

    final ratingColors = {
      5: Color(0xFFE53935),
      4: Color(0xFFFF9800),
      3: Color(0xFFFDD835),
      2: Color(0xFF43A047),
      1: Color(0xFF42A5F5),
      0: Color(0xFF9E9E9E),
    };

    final total = ratingData.fold(
      0,
      (sum, item) => sum + ((item['count'] as num?)?.toInt() ?? 0),
    );

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sections: ratingData.map((item) {
                final rating = (item['rating'] as num?)?.toInt() ?? -1;
                final count = (item['count'] as num?)?.toInt() ?? 0;
                final percentage = total > 0 ? (count / total * 100) : 0.0;
                return PieChartSectionData(
                  value: count.toDouble(),
                  color: ratingColors[rating] ?? Colors.grey,
                  title: percentage >= 5
                      ? '${percentage.toStringAsFixed(0)}%'
                      : '',
                  titleStyle: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  radius: 40,
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: ratingData.map<Widget>((item) {
              final rating = (item['rating'] as num?)?.toInt() ?? -1;
              final count = (item['count'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ratingColors[rating] ?? Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppDesign.ratingLabel(rating),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProductRankingList(AppState appState, bool isDark) {
    final ranking = appState.productRanking;

    if (ranking.isEmpty) {
      return const EmptyStatePlaceholder(
        icon: Icons.emoji_events_rounded,
        message: '暂无销售数据',
      );
    }

    final top5 = ranking.take(5).toList();
    final maxCount = top5.isEmpty
        ? 1
        : ((top5[0]['sale_count'] as num?)?.toInt() ?? 0).clamp(1, 999999);

    return Column(
      children: top5.asMap().entries.map<Widget>((entry) {
        final index = entry.key;
        final item = entry.value;
        final saleCount = (item['sale_count'] as num?)?.toInt() ?? 0;
        final totalAmount = (item['total_amount'] as num?)?.toDouble() ?? 0;
        final productName = (item['product_name'] as String?) ?? '未知产品';
        final progress = saleCount / maxCount;

        final medalColors = [
          Color(0xFFFFD700), // Gold
          Color(0xFFC0C0C0), // Silver
          Color(0xFFCD7F32), // Bronze
        ];

        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              // 排名
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: index < 3
                      ? medalColors[index].withValues(alpha: 0.15)
                      : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: index < 3
                      ? Icon(
                          Icons.emoji_events_rounded,
                          size: 16,
                          color: medalColors[index],
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
              SizedBox(width: 12),
              // 产品信息和进度条
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            productName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$saleCount笔',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFFF9800),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.05, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (totalAmount > 0)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          '保费: ${_formatAmount(totalAmount.toInt())}元',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatAmount(num amount) {
    if (amount.abs() >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return amount == amount.toInt() ? amount.toInt().toString() : amount.toStringAsFixed(1);
  }

  Widget _buildQuarterlySalesChart(AppState appState, bool isDark) {
    final data = appState.quarterlySales;
    if (data.isEmpty) {
      return const EmptyStatePlaceholder(
        icon: Icons.calendar_view_month_rounded,
        message: '暂无季度数据',
      );
    }
    return Column(
      children: () {
        final maxAmount = data.map((q) => (q['total_amount'] as num?)?.toDouble() ?? 0).fold(0.0, (a, b) => a > b ? a : b);
        return data.map((q) {
          final quarter = q['quarter'] ?? '?';
          final amount = (q['total_amount'] as num?)?.toDouble() ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(width: 60, child: Text('Q$quarter', style: const TextStyle(fontWeight: FontWeight.w600))),
              Expanded(child: LinearProgressIndicator(value: maxAmount > 0 ? amount / maxAmount : 0, minHeight: 20, borderRadius: BorderRadius.circular(4), backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5C6BC0)))),
              const SizedBox(width: 8),
              SizedBox(width: 80, child: Text(_formatAmount(amount), style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
            ]),
          );
        }).toList();
      }(),
    );
  }

  Widget _buildCommissionChart(AppState appState, bool isDark) {
    final monthly = appState.monthlyCommissions;
    final quarterly = appState.quarterlyCommissions;
    if (monthly.isEmpty && quarterly.isEmpty) {
      return const EmptyStatePlaceholder(
        icon: Icons.account_balance_wallet_rounded,
        message: '暂无佣金数据',
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (monthly.isNotEmpty) ...[
        const Text('月度佣金', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        ...monthly.map<Widget>((m) {
          final month = m['month'] ?? '?';
          final commission = (m['total_commission'] as num?)?.toDouble() ?? 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 60, child: Text('$month月', style: const TextStyle(fontWeight: FontWeight.w500))),
              Expanded(child: Text('¥${commission.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF66BB6A)))),
            ]),
          );
        }),
        const SizedBox(height: 12),
      ],
      if (quarterly.isNotEmpty) ...[
        const Text('季度佣金', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        ...quarterly.map<Widget>((q) {
          final quarter = q['quarter'] ?? '?';
          final commission = (q['total_commission'] as num?)?.toDouble() ?? 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 60, child: Text('Q$quarter', style: const TextStyle(fontWeight: FontWeight.w500))),
              Expanded(child: Text('¥${commission.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF66BB6A)))),
            ]),
          );
        }),
        const SizedBox(height: 12),
      ],
    ]);
  }

  Widget _buildConversionFunnelChart(AppState appState, bool isDark) {
    final data = appState.conversionFunnel;
    if (data.isEmpty) {
      return const EmptyStatePlaceholder(
        icon: Icons.linear_scale_rounded,
        message: '暂无转化数据',
      );
    }
    return Column(
      children: data.map<Widget>((stage) {
        final rating = (stage['rating'] as num?)?.toInt();
        final name = AppDesign.ratingLabel(rating);
        final count = (stage['count'] as num?)?.toInt() ?? 0;
        final rate = (stage['conversion_rate'] as num?)?.toDouble()
            ?? 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(flex: 2, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),
            Expanded(flex: 1, child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
            Expanded(flex: 1, child: Text('${rate.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.w600, color: rate > 50 ? Colors.green : Colors.orange), textAlign: TextAlign.right)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildVisitEfficiencyList(AppState appState, bool isDark) {
    final data = appState.visitEfficiency;
    if (data.isEmpty) {
      return const EmptyStatePlaceholder(
        icon: Icons.analytics_rounded,
        message: '暂无拜访效率数据',
      );
    }
    return Column(
      children: data.map<Widget>((item) {
        // 兼容 Web（汇总数据）和数据库（每客户数据）两种格式
        final customerName = (item['customer_name'] as String?) ?? '汇总统计';
        final visitCount = (item['visit_count'] as num?)?.toInt()
            ?? (item['total_visits'] as num?)?.toInt()
            ?? 0;
        final conversionRate = (item['conversion_per_visit'] as num?)?.toDouble() ?? 0.0;
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200)),
          child: ListTile(
            dense: true,
            title: Text(customerName, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('拜访 $visitCount 次 · 转化率 ${conversionRate.toStringAsFixed(0)}%'),
            trailing: Icon(Icons.trending_up, color: conversionRate > 30 ? Colors.green : Colors.orange, size: 20),
          ),
        );
      }).toList(),
    );
  }
}
