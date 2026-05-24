import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/models/customer.dart';
import 'package:insurance_manager/widgets/app_components.dart';
import 'package:insurance_manager/pages/customer_detail_page.dart';

class NearbyCustomersPage extends StatefulWidget {
  const NearbyCustomersPage({super.key});

  @override
  _NearbyCustomersPageState createState() => _NearbyCustomersPageState();
}

class _NearbyCustomersPageState extends State<NearbyCustomersPage> {
  Position? _currentPosition;
  List<Map<String, dynamic>> _nearbyCustomers = [];
  bool _isLoading = false;
  bool _isLocating = false;
  String? _errorMessage;
  double _radius = 5.0; // 默认5公里

  final List<double> _radiusOptions = [1, 3, 5, 10, 20];

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _errorMessage = null;
      _nearbyCustomers = [];
    });

    try {
      // 检查并请求定位权限
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        var status = await Permission.location.status;
        if (!status.isGranted) {
          status = await Permission.location.request();
          if (!status.isGranted) {
            if (mounted) {
              setState(() {
                _isLocating = false;
                _errorMessage = '需要位置权限才能使用附近客户功能';
              });
            }
            return;
          }
        }
      }

      // 检查是否开启位置服务
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _errorMessage = '请先开启设备的位置服务（GPS）';
          });
        }
        return;
      }

      // 获取当前位置
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLocating = false;
        });
        _loadNearbyCustomers(position.latitude, position.longitude);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _errorMessage = '获取位置失败：$e';
        });
      }
    }
  }

  void _loadNearbyCustomers(double lat, double lon) {
    setState(() => _isLoading = true);

    final appState = Provider.of<AppState>(context, listen: false);
    final nearby = appState.getCustomersSortedByDistance(lat, lon);

    // 按半径过滤
    final filtered = nearby.where((item) {
      final dist = item['distance'] as double? ?? 0;
      return dist <= _radius * 1000; // 转换为米
    }).toList();

    if (mounted) {
      setState(() {
        _nearbyCustomers = filtered;
        _isLoading = false;
      });
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  Color _distanceColor(double meters) {
    if (meters < 1000) return const Color(0xFF43A047); // 绿色 - 近
    if (meters < 3000) return const Color(0xFFFB8C00); // 橙色 - 中
    return const Color(0xFFE53935); // 红色 - 远
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('附近客户'),
        actions: [
          if (_currentPosition != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '刷新位置',
              onPressed: () => _getCurrentLocation(),
            ),
        ],
      ),
      body: Column(
        children: [
          // 定位状态栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      size: 20,
                      color: _currentPosition != null
                          ? primaryColor
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentPosition != null
                            ? '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                            : '尚未获取位置',
                        style: TextStyle(
                          fontSize: 14,
                          color: _currentPosition != null
                              ? _textPrimary(context)
                              : Colors.grey,
                        ),
                      ),
                    ),
                    if (!_isLocating)
                      FilledButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.gps_fixed_rounded, size: 16),
                        label: const Text('获取位置'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      )
                    else
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),

                // 半径选择器
                if (_currentPosition != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '搜索范围：',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SegmentedButton<double>(
                          segments: _radiusOptions
                              .map((r) => ButtonSegment(
                                    value: r.toDouble(),
                                    label: Text('${r.toInt()}km'),
                                  ))
                              .toList(),
                          selected: {_radius},
                          onSelectionChanged: (values) {
                            setState(() => _radius = values.first);
                            if (_currentPosition != null) {
                              _loadNearbyCustomers(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              );
                            }
                          },
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(fontSize: 12),
                            selectedBackgroundColor:
                                primaryColor.withValues(alpha: 0.15),
                            selectedForegroundColor: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 错误提示
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE53935).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: Colors.red[400]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 13, color: Colors.red[400]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 未定位提示
          if (_currentPosition == null && _errorMessage == null && !_isLocating)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_searching_rounded,
                        size: 64,
                        color: primaryColor.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '点击上方按钮\n获取您的当前位置',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 加载中
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),

          // 结果列表
          if (_currentPosition != null && !_isLoading) ...[
            if (_nearbyCustomers.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_off_rounded,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_radius.toInt()}公里范围内暂无客户',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '客户需要设置经纬度坐标才能显示在这里',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _nearbyCustomers.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 48),
                  itemBuilder: (context, index) {
                    final item = _nearbyCustomers[index];
                    final customer = item['customer'] as Customer;
                    final distance = item['distance'] as double? ?? 0;
                    return _buildCustomerItem(customer, distance);
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white70
          : Colors.black87;

  Widget _buildCustomerItem(Customer customer, double distance) {
    final distColor = _distanceColor(distance);
    final distText = _formatDistance(distance);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerDetailPage(customer: customer),
        ),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CustomerAvatar(name: customer.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    customer.phones.isNotEmpty ? customer.phones[0] : '暂无电话',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  if (customer.address?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      customer.address!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // 距离标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: distColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_walk_rounded,
                    size: 14,
                    color: distColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    distText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: distColor,
                    ),
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
