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

class _NearbyCustomersPageState extends State<NearbyCustomersPage>
    with TickerProviderStateMixin {
  Position? _currentPosition;
  String _address = '';
  List<Map<String, dynamic>> _nearbyCustomers = [];
  bool _isLoading = false;
  bool _isLocating = false;
  String? _errorMessage;
  double _radius = 5.0;

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_off_rounded,
              size: 28, color: Colors.orange),
        ),
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
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        var status = await Permission.locationWhenInUse.status;
        if (!status.isGranted) {
          status = await Permission.locationWhenInUse.request();
          if (!status.isGranted) {
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
              if (isPermanentlyDenied && mounted) {
                _showPermissionDialog();
              }
            }
            return;
          }
        }
      }

      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _errorMessage = '请先开启设备的位置服务（GPS）';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String address = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
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
        _fadeController.forward(from: 0);
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

    final filtered = nearby.where((item) {
      final dist = item['distance'] as double? ?? 0;
      return dist <= _radius;
    }).toList();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _nearbyCustomers = filtered;
          _isLoading = false;
        });
      }
    });
  }

  String _formatRadiusLabel(double km) {
    if (km >= 1)
      return '${km.toStringAsFixed(km == km.roundToDouble() ? 0 : 1)}km';
    return '${(km * 1000).round()}m';
  }

  String _formatDistance(double km) {
    if (km >= 1) {
      return '${km.toStringAsFixed(1)} km';
    } else {
      return '${(km * 1000).round()} m';
    }
  }

  Color _distanceColor(double km) {
    if (km < 1) return const Color(0xFF43A047);
    if (km < 3) return const Color(0xFFFB8C00);
    return const Color(0xFFE53935);
  }

  String _distanceLabel(double km) {
    if (km < 0.5) return '很近';
    if (km < 1) return '步行可达';
    if (km < 3) return '附近';
    return '较远';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── 渐变头部 ──
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
                        : [const Color(0xFF42A5F5), primaryColor],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) => Transform.scale(
                                scale: _isLocating ? _pulseAnimation.value : 1.0,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                        alpha: _currentPosition != null
                                            ? 0.25
                                            : 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    _currentPosition != null
                                        ? Icons.my_location_rounded
                                        : Icons.location_searching_rounded,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '附近客户',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Text(
                                      _currentPosition != null
                                          ? (_address.length > 30
                                              ? '${_address.substring(0, 28)}...'
                                              : _address)
                                          : '点击定位查找附近客户',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_currentPosition != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people_outline_rounded,
                                        size: 14, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_nearbyCustomers.length} 位',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (_currentPosition != null &&
                            _nearbyCustomers.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '搜索范围: ${_formatRadiusLabel(_radius)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              if (_currentPosition != null)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        size: 18, color: Colors.white),
                  ),
                  tooltip: '刷新位置',
                  onPressed: () => _getCurrentLocation(),
                ),
            ],
            titleTextStyle: const TextStyle(color: Colors.white),
            iconTheme: const IconThemeData(color: Colors.white),
          ),

          // ── 主体内容 ──
          SliverToBoxAdapter(
            child: Column(
              children: [
                // 定位操作卡片
                _buildLocationCard(isDark, primaryColor),

                // 错误提示
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _buildErrorCard(),
                  ),

                // 半径调节器（定位后显示）
                if (_currentPosition != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _buildRadiusSlider(isDark, primaryColor),
                  ),

                // 未定位空状态
                if (_currentPosition == null &&
                    _errorMessage == null &&
                    !_isLocating)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    child: Center(child: _buildEmptyLocateUI(primaryColor)),
                  )

                // 加载中
                else if (_isLoading)
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '正在搜索附近客户...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )

                // 结果列表
                else if (_currentPosition != null && !_isLoading) ...[
                  if (_nearbyCustomers.isEmpty)
                    _buildNoResultsUI(primaryColor)
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Column(
                        children: List.generate(_nearbyCustomers.length, (index) {
                          final item = _nearbyCustomers[index];
                          final customer = item['customer'] as Customer;
                          final distance = item['distance'] as double? ?? 0;
                          return _AnimatedCustomerCard(
                            index: index,
                            child: _buildCustomerCard(customer, distance,
                                isDark, primaryColor, colorScheme),
                          );
                        }),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════
  //  UI 组件
  // ════════════════════════════════

  /// 定位状态卡片
  Widget _buildLocationCard(bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF252525), const Color(0xFF1E1E1E)]
              : [Colors.white, const Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(AppDesign.radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // 左侧图标区
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _currentPosition != null
                  ? primaryColor.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _currentPosition != null
                  ? Icons.check_circle_rounded
                  : Icons.gps_not_fixed_rounded,
              size: 24,
              color: _currentPosition != null
                  ? primaryColor
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 14),
          // 中间信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentPosition != null ? '已定位' : '尚未获取位置',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _currentPosition != null ? _address : '点击按钮开始定位',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppDesign.subtitleColor(isDark),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 右侧按钮
          _isLocating
              ? SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: primaryColor),
                )
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _getCurrentLocation,
                    borderRadius: BorderRadius.circular(AppDesign.radiusButton),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          primaryColor,
                          primaryColor.withValues(alpha: 0.85)
                        ]),
                        borderRadius:
                            BorderRadius.circular(AppDesign.radiusButton),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.gps_fixed_rounded,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          const Text('获取位置',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// 错误提示卡片
  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          colors: [
            const Color(0xFFFFEBEE),
            const Color(0xFFFFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDesign.radiusCard),
        border: Border.all(
          color: Colors.red[200]!.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 20, color: Colors.red[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: TextStyle(fontSize: 13, color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  /// 半径滑动条
  Widget _buildRadiusSlider(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppDesign.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppDesign.radiusCard),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: 18, color: primaryColor),
                  const SizedBox(width: 8),
                  const Text('搜索半径',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatRadiusLabel(_radius),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              inactiveTrackColor: primaryColor.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayColor: primaryColor.withValues(alpha: 0.12),
              trackHeight: 6,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 18),
              trackShape: const RoundedRectSliderTrackShape(),
              valueIndicatorShape:
                  const PaddleSliderValueIndicatorShape(),
              valueIndicatorColor: primaryColor,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Slider(
              value: _radius,
              min: 0.5,
              max: kDebugMode ? 200.0 : 20.0,
              divisions: (kDebugMode ? 199 : 19) * 2,
              label: _formatRadiusLabel(_radius),
              onChanged: (value) => setState(() => _radius = value),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('500m',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ...[1, 5, 10, 20]
                    .map((v) => Expanded(
                          child: Center(
                            child: Text(
                              v >= 10 ? '${v}km' : '${v}km',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400]),
                            ),
                          ),
                        ))
                    .toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 未定位空状态
  Widget _buildEmptyLocateUI(Color primaryColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                primaryColor.withValues(alpha: 0.15),
                primaryColor.withValues(alpha: 0.04),
              ],
            ),
          ),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Icon(
                Icons.explore_outlined,
                size: 44,
                color: primaryColor.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '发现附近客户',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '使用 GPS 定位后，将按距离\n显示您附近的客户列表',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _getCurrentLocation,
          icon: const Icon(Icons.my_location_rounded, size: 18),
          label: const Text('立即定位', style: TextStyle(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            elevation: 3,
          ),
        ),
      ],
    );
  }

  /// 无结果空状态
  Widget _buildNoResultsUI(Color primaryColor) {
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[100],
              ),
              child: Icon(Icons.location_off_rounded,
                  size: 42, color: Colors.grey[350]),
            ),
            const SizedBox(height: 20),
            Text(
              '${_radius.toInt()}公里范围内暂无客户',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '客户需要设置经纬度坐标才能显示在这里',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[450]),
            ),
          ],
        ),
      ),
    );
  }

  /// 客户卡片
  Widget _buildCustomerCard(Customer customer, double distance,
      bool isDark, Color primaryColor, ColorScheme colorScheme) {
    final distColor = _distanceColor(distance);
    final distText = _formatDistance(distance);
    final distTag = _distanceLabel(distance);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerDetailPage(customer: customer),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppDesign.cardBg(isDark),
          borderRadius: BorderRadius.circular(AppDesign.radiusCard),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 头像
            CustomerAvatar(name: customer.name),
            const SizedBox(width: 14),
            // 信息列
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          customer.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 距离标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: distColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          distTag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: distColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 13, color: Colors.grey[450]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          customer.phones.isNotEmpty
                              ? customer.phones[0]
                              : '暂无电话',
                          style: TextStyle(fontSize: 13, color: Colors.grey[550]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.grey[450]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          customer.address?.isNotEmpty == true
                              ? customer.address!
                              : (customer.addresses.isNotEmpty
                                  ? customer.addresses[0]
                                  : '暂无地址'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppDesign.subtitleColor(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 距离数值
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      distColor,
                      distColor.withValues(alpha: 0.85),
                    ]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: distColor.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_walk_rounded,
                          size: 16, color: Colors.white70),
                      const SizedBox(height: 3),
                      Text(distText,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : const Color(0xFF1A1A2E);
}

// ═════════════════════════════════════════════════════
//  卡片入场动画组件
// ═════════════════════════════════════════════════════

class _AnimatedCustomerCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedCustomerCard({required this.index, required this.child});

  @override
  State<_AnimatedCustomerCard> createState() =>
      _AnimatedCustomerCardState();
}

class _AnimatedCustomerCardState extends State<_AnimatedCustomerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.06, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(opacity: _fadeAnim, child: widget.child),
    );
  }
}
