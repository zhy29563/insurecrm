import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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
  String _address = '';
  List<Map<String, dynamic>> _nearbyCustomers = [];
  bool _isLoading = false;
  bool _isLocating = false;
  String? _errorMessage;
  double _radius = 5.0; // 默认5公里

  @override
  void dispose() {
    super.dispose();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_off_rounded, size: 48, color: Colors.orange),
        title: const Text('需要位置权限'),
        content: const Text(
          '位置权限已被拒绝或受限，请在系统设置中允许应用使用位置信息。\n\n点击下方按钮将自动跳转到设置页面。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('去设置'),
          ),
        ],
      ),
    );
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
        // Android 12+ 使用 locationWhenInUse，兼容性更好
        var status = await Permission.locationWhenInUse.status;
        if (!status.isGranted) {
          status = await Permission.locationWhenInUse.request();
          if (!status.isGranted) {
            // 引导用户前往系统设置开启权限
            final isPermanentlyDenied =
                status == PermissionStatus.permanentlyDenied ||
                status == PermissionStatus.denied;
            if (mounted) {
              setState(() {
                _isLocating = false;
                _errorMessage = isPermanentlyDenied
                    ? '位置权限被拒绝，请在设置中手动开启'
                    : '需要位置权限才能使用附近客户功能';
              });
              // 如果是永久拒绝，提示跳转设置
              if (isPermanentlyDenied && mounted) {
                _showPermissionDialog();
              }
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

      // 逆地理编码：将坐标转为可读地址
      String address = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          // 组装可读地址：省市区+街道
          final parts = [
            if (pm.administrativeArea?.isNotEmpty == true)
              pm.administrativeArea!,
            if (pm.locality?.isNotEmpty == true) pm.locality!,
            if (pm.subLocality?.isNotEmpty == true) pm.subLocality!,
            if (pm.thoroughfare?.isNotEmpty == true) pm.thoroughfare!,
            if (pm.name?.isNotEmpty == true && pm.name != pm.thoroughfare)
              pm.name!,
          ];
          address = parts.join('');
          if (address.isEmpty) {
            // 如果中文地址为空，尝试英文组合
            final fallback = [
              if (pm.country != null) pm.country!,
              if (pm.subAdministrativeArea?.isNotEmpty == true)
                pm.subAdministrativeArea!,
              if (pm.street?.isNotEmpty == true) pm.street!,
            ].join(', ');
            address = fallback;
          }
          if (address.isEmpty) {
            address =
                '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          }
        }
      } catch (_) {
        address =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _address = address;
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

    // 按半径过滤（_calculateDistance 返回 km）
    final filtered = nearby.where((item) {
      final dist = item['distance'] as double? ?? 0;
      return dist <= _radius;
    }).toList();

    if (mounted) {
      setState(() {
        _nearbyCustomers = filtered;
        _isLoading = false;
      });
    }
  }

  String _formatRadiusLabel(double km) {
    if (km >= 1) return '${km.toStringAsFixed(km == km.roundToDouble() ? 0 : 1)}km';
    return '${(km * 1000).round()}m';
  }

  String _formatDistance(double km) {
    if (km >= 1) {
      return '${km.toStringAsFixed(1)}km';
    } else {
      return '${(km * 1000).round()}m';
    }
  }

  Color _distanceColor(double km) {
    if (km < 1) return const Color(0xFF43A047); // 绿色 - 1km以内
    if (km < 3) return const Color(0xFFFB8C00); // 橙色 - 3km以内
    return const Color(0xFFE53935); // 红色 - 更远
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
                            ? _address
                            : '尚未获取位置',
                        style: TextStyle(
                          fontSize: 14,
                          color: _currentPosition != null
                              ? _textPrimary(context)
                              : Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

                // 半径滑动条
                if (_currentPosition != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _radius >= 1
                            ? '${_radius.toStringAsFixed(_radius.truncateToDouble() == _radius ? 0 : 1)} km'
                            : '${(_radius * 1000).round()} m',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: primaryColor,
                      inactiveTrackColor: primaryColor.withValues(alpha: 0.15),
                      thumbColor: primaryColor,
                      overlayColor: primaryColor.withValues(alpha: 0.12),
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: _radius,
                      min: 1,
                      max: kDebugMode ? 200.0 : 20.0,
                      divisions: (kDebugMode ? 199 : 19) * 2, // 每0.5km一格
                      label: _formatRadiusLabel(_radius),
                      onChanged: (value) {
                        setState(() => _radius = value);
                      },
                      onChangeEnd: (value) {
                        if (_currentPosition != null) {
                          _loadNearbyCustomers(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          );
                        }
                      },
                    ),
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
                  const SizedBox(height: 2),
                  Text(
                    customer.address?.isNotEmpty == true
                        ? customer.address!
                        : (customer.addresses.isNotEmpty
                            ? customer.addresses[0]
                            : '暂无地址'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
