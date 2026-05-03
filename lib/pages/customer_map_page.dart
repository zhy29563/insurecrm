import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:amap_flutter_map_plus/amap_flutter_map_plus.dart';
import 'package:amap_flutter_base_plus/amap_flutter_base_plus.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/models/customer.dart';
import 'package:insurance_manager/widgets/app_components.dart';
import 'package:insurance_manager/pages/customer_detail_page.dart';
import 'package:insurance_manager/pages/settings_page.dart';
import 'package:geolocator/geolocator.dart';

/// State machine for the Nearby tab to avoid FutureBuilder issues
enum _NearbyState { loading, error, success }

/// Wrapper to navigate to settings page from map page
class _SettingsPageWrapper extends StatelessWidget {
  const _SettingsPageWrapper();
  @override
  Widget build(BuildContext context) {
    return SettingsPage();
  }
}

class CustomerMapPage extends StatefulWidget {
  const CustomerMapPage({super.key});

  @override
  State<CustomerMapPage> createState() => _CustomerMapPageState();
}

class _CustomerMapPageState extends State<CustomerMapPage>
    with TickerProviderStateMixin {
  Color get _primary => Theme.of(context).primaryColor;
  AMapController? _mapController;
  bool _isLoading = true;
  List<Customer> _routeCustomers = [];
  double _nearbyRadiusKm = 5.0;
  bool _showingRoute = false;
  Position? _currentPosition;
  double? _routeStartLat, _routeStartLng;
  bool _locationFetching = false; // Prevent concurrent Geolocator calls

  late TabController _tabController;

  // Markers & polylines for the map
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final Map<String, int?> _markerCustomerMap = {};

  // Cached filtered customer list to avoid recomputing on every build
  List<Customer> _customersWithLocationCache = [];
  int _prevCustomerCountForLocationCache = 0;

  // Nearby tab state: use explicit loading/error/data pattern instead of FutureBuilder
  _NearbyState _nearbyState = _NearbyState.loading;
  Position? _nearbyPosition;
  Object? _nearbyError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update markers and cache when customer data changes (instead of doing it in build())
    final appState = Provider.of<AppState>(context);
    if (!_showingRoute) {
      final cs = appState.customers.where((c) => c.latitude != null && c.longitude != null).toList();
      _customersWithLocationCache = cs;
      if (cs.isNotEmpty && (cs.length != _prevCustomerCountForLocationCache || _markers.isEmpty || _markerCustomerMap.isEmpty)) {
        _prevCustomerCountForLocationCache = cs.length;
        // Update markers directly without setState (didChangeDependencies already triggers rebuild)
        _markers = _buildMarkers(cs);
      }
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return; // Only react to final index
    // Trigger location fetch when user switches to the Nearby tab
    if (_tabController.index == 2 && _nearbyState != _NearbyState.success) {
      _fetchNearbyLocation();
    }
    setState(() {});
  }

  Future<void> _initLocation() async {
    if (kIsWeb) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final pos = await _getSafeCurrentLocation();
      if (pos != null) {
        _currentPosition = pos;
        // Only move camera if we're on the map tab
        if (mounted && _mapController != null && _tabController.index == 0) {
          _mapController!.moveCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(pos.latitude, pos.longitude), 14),
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  /// Thread-safe location getter that prevents concurrent Geolocator calls
  Future<Position?> _getSafeCurrentLocation() async {
    if (_locationFetching) {
      // Already fetching — wait and return cached position
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_locationFetching) break;
      }
      return _currentPosition;
    }
    _locationFetching = true;
    try {
      return await _getCurrentLocation();
    } finally {
      _locationFetching = false;
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('Geolocator error: $e');
      return null;
    }
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1), dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final sqrtA = math.sqrt(a.clamp(0.0, 1.0)); // Prevent floating point overflow/underflow
    return R * 2 * math.asin(sqrtA);
  }

  double _toRad(double deg) => deg * math.pi / 180;

  List<Customer> get _customersWithLocation => _customersWithLocationCache;

  List<Customer> _getNearbyCustomers(double lat, double lng, double radiusKm) {
    final entries = _customersWithLocation
        .map((c) => MapEntry(
            c, _distanceKm(lat, lng, c.latitude!, c.longitude!)))
        .where((e) => e.value <= radiusKm)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries.map((e) => e.key).toList();
  }

  String _ratingLabel(int? r) => AppDesign.ratingLabel(r);

  String _formatDist(double km) =>
      km < 1 ? '${(km * 1000).round()}m' : '${km.toStringAsFixed(1)}km';

  void _onMarkerTap(String markerKey) {
    final id = _markerCustomerMap[markerKey];
    if (id == null) return;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickSheet(customerId: id),
    );
  }

  void _clearRoute() {
    final allWithLoc = _customersWithLocation;
    setState(() {
      _routeCustomers = [];
      _showingRoute = false;
      _polylines = {};
      _markers = _buildMarkers(allWithLoc);
    });
  }

  /// Build markers from customer list
  Set<Marker> _buildMarkers(List<Customer> customers) {
    _markerCustomerMap.clear();
    return customers.map<Marker>((c) {
      final key = 'customer_${c.id}';
      _markerCustomerMap[key] = c.id;
      return Marker(
        position: LatLng(c.latitude!, c.longitude!),
        infoWindow: InfoWindow(
          title: c.name,
          snippet: c.phones.isNotEmpty ? c.phones[0] : _ratingLabel(c.rating),
        ),
        onTap: (_) => _onMarkerTap(key),
      );
    }).toSet();
  }

  /// Update markers on map
  void _updateMarkers(List<Customer> customers) {
    setState(() {
      _markers = _buildMarkers(customers);
    });
  }

  /// Draw route polyline on map
  void _drawRoutePolyline(List<Customer> customers, double startLat, double startLng) {
    final points = <LatLng>[
      LatLng(startLat, startLng),
      ...customers.map((c) => LatLng(c.latitude!, c.longitude!)),
      LatLng(startLat, startLng),
    ];
    setState(() {
      _polylines = {
        Polyline(
          points: points,
          width: 5,
          color: const Color(0xFFE53935),
          dashLineType: DashLineType.square,
        ),
      };
      // Add numbered markers for route
      _markerCustomerMap.clear();
      final routeMarkers = <Marker>{};
      for (int i = 0; i < customers.length; i++) {
        final c = customers[i];
        _markerCustomerMap['customer_${c.id}'] = c.id;
        routeMarkers.add(Marker(
          position: LatLng(c.latitude!, c.longitude!),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${c.name}',
            snippet: c.phones.isNotEmpty ? c.phones[0] : '',
          ),
          onTap: (_) => _onMarkerTap('customer_${c.id}'),
        ));
      }
      _markers = routeMarkers;
    });
  }

  /// Build AMapApiKey from app state
  AMapApiKey _buildApiKey(AppState appState) {
    return AMapApiKey(
      androidKey: appState.amapApiKey,
      iosKey: appState.amapApiKeyIOS.isNotEmpty ? appState.amapApiKeyIOS : appState.amapApiKey,
    );
  }

  // ===== Build =====

  @override
  Widget build(BuildContext context) {
    final ac = Provider.of<AppState>(context);
    // Use cached filtered list instead of re-filtering on every build
    final allCust = _customersWithLocationCache;

    return Scaffold(
      appBar: AppBar(
        title: const Text('客户地图'),
        bottom: kIsWeb
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: '全部视图'),
                    Tab(text: '拜访路线'),
                    Tab(text: '附近推荐'),
                  ],
                ),
              ),
        actions: [
          if (!kIsWeb && allCust.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.my_location),
              tooltip: '定位到我',
              onPressed: () async {
                final p = await _getSafeCurrentLocation();
                if (!mounted) return;
                if (p != null) {
                  _currentPosition = p;
                  if (_tabController.index == 0) {
                    _mapController?.moveCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(p.latitude, p.longitude), 14),
                    );
                  }
                }
              },
            ),
          if (_showingRoute)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: '清除路线',
              onPressed: _clearRoute,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('${allCust.length}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70)),
            ),
          ),
        ],
      ),
      body: kIsWeb
          ? _buildWebPlaceholder(allCust)
          // CRITICAL: Do NOT use TabBarView with AMapWidget (AndroidView).
          // TabBarView uses PageView which scrolls children off-screen, causing
          // the native map view's rendering surface to become invalid, leading to
          // SIGSEGV when Flutter tries to repaint/relayout the off-screen map.
          // Use Stack + Offstage instead: map is always rendered at its original
          // position, other tab content is overlaid on top with opaque background.
          : Stack(
              children: [
                // Map view always at the bottom — never scrolled, never destroyed
                _buildMapView(allCust),
                // Route planning: overlaid with opaque background when active
                Offstage(
                  offstage: _tabController.index != 1,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _buildRoutePlanView(allCust, ac.customers.length),
                  ),
                ),
                // Nearby: overlaid with opaque background when active
                Offstage(
                  offstage: _tabController.index != 2,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _buildNearbyView(allCust),
                  ),
                ),
              ],
            ),
    );
  }

  // ===== TAB 1: Map View =====
  Widget _buildMapView(List<Customer> cs) {
    final appState = Provider.of<AppState>(context);
    if (!appState.hasAmapApiKey) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_rounded, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                '高德地图 API Key 未配置',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '请在 设置 > 高德地图配置 中输入 API Key',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _SettingsPageWrapper()),
                  );
                },
                icon: const Icon(Icons.settings),
                label: const Text('前往设置'),
              ),
            ],
          ),
        ),
      );
    }

    // Markers are now updated in didChangeDependencies instead of build()
    // CRITICAL: Always create AMapWidget — never conditionally replace it with another widget.
    // Replacing AMapWidget triggers native map destroy/create cycle, which can crash
    // when the map tab is off-screen (e.g., user is on the Nearby tab).
    return Stack(children: [
      AMapWidget(
        apiKey: _buildApiKey(appState),
        privacyStatement: const AMapPrivacyStatement(
          hasContains: true,
          hasShow: true,
          hasAgree: true,
        ),
        initialCameraPosition: CameraPosition(
          target: _currentPosition != null
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : const LatLng(39.9042, 116.4074),
          zoom: 12,
        ),
        markers: _markers,
        polylines: _polylines,
        scaleEnabled: true,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        myLocationStyleOptions: MyLocationStyleOptions(_tabController.index == 0),
        onMapCreated: (controller) {
          if (mounted) _mapController = controller;
        },
        onTap: (latLng) {
          // Dismiss any open bottom sheet on map tap
        },
      ),
      if (_isLoading)
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: const Center(child: CircularProgressIndicator()),
        ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 160),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Text('客户列表 (${cs.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                ...[
                  const Color(0xFFE53935),
                  const Color(0xFFFF9800),
                  const Color(0xFF43A047)
                ].map<Widget>((c) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: c),
                    )),
                const SizedBox(width: 4),
                Text('意向级别',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ]),
            ),
            Flexible(
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: cs.length,
                  itemBuilder: (_, i) => _buildChip(cs[i]),
                ),
              ),
            ),
          ]),
        ),
      ),
      if (cs.isEmpty)
        Center(
          child: EmptyStatePlaceholder(
            icon: Icons.location_off_rounded,
            message: '暂无客户位置信息',
            actionHint: '在客户详情中设置位置后显示',
          ),
        ),
    ]);
  }

  Widget _buildChip(Customer c) {
    final primaryColor = Theme.of(context).primaryColor;
    return InkWell(
      onTap: () {
        if (c.latitude != null && c.longitude != null) {
          _mapController?.moveCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(c.latitude!, c.longitude!), 15),
          );
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.1),
                child: Text(c.name.isNotEmpty ? c.name.characters.first : '',
                    style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(c.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            if (c.phones.isNotEmpty)
              Text(c.phones[0],
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ===== TAB 2: Route Plan =====
  Widget _buildRoutePlanView(List<Customer> customers, int totalCustomerCount) {
    if (customers.isEmpty) {
      return const EmptyStatePlaceholder(
        icon: Icons.directions_walk_rounded,
        message: '暂无可拜访客户',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.route_rounded,
                  size: 26, color: Color(0xFF1565C0)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('智能拜访路线',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('根据距离自动规划最优拜访顺序',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            const Text('起点选择',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final p = await _getSafeCurrentLocation();
                    if (p == null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('无法获取位置')));
                      return;
                    }
                    _currentPosition = p;
                    final nb = _getNearbyCustomers(p.latitude, p.longitude, 50);
                    _buildOptimizedRoute(p.latitude, p.longitude, nb);
                    _tabController.animateTo(0);
                  },
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('我的位置'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final p = await _getSafeCurrentLocation();
                    if (p == null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('无法获取位置')));
                      return;
                    }
                    _currentPosition = p;
                    _buildOptimizedRoute(p.latitude, p.longitude, customers);
                    _tabController.animateTo(0);
                  },
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('全部客户'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            const Text('搜索半径',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Slider(
              value: _nearbyRadiusKm,
              min: 1,
              max: 30,
              divisions: 29,
              label: '${_nearbyRadiusKm.round()}km',
              activeColor: const Color(0xFF1565C0),
              onChanged: (v) => setState(() => _nearbyRadiusKm = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () async {
                  final p = await _getSafeCurrentLocation();
                  if (p == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('无法获取位置')));
                    return;
                  }
                  _currentPosition = p;
                  final nb = _getNearbyCustomers(p.latitude, p.longitude, _nearbyRadiusKm);
                  if (nb.isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${_nearbyRadiusKm.round()}公里内无客户')));
                    return;
                  }
                  _buildOptimizedRoute(p.latitude, p.longitude, nb);
                  _tabController.animateTo(0);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.alt_route,
                          size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('生成${_nearbyRadiusKm.round()}公里内拜访路线',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, color: Colors.white)),
                    ]),
              ),
            ),
          ]),
        ),
        if (_showingRoute && _routeCustomers.isNotEmpty) ...[
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            color: const Color(0xFFFFF3E0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.timeline,
                          size: 20, color: Color(0xFFE65100)),
                      const SizedBox(height: 8),
                      Text('拜访路线 (${_routeCustomers.length}个客户)',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100))),
                    ]),
                    const SizedBox(height: 12),
                    ...List.generate(_routeCustomers.length, (i) {
                      final c = _routeCustomers[i];
                      final dist = i == 0
                          ? null
                          : _distanceKm(
                              _routeCustomers[i - 1].latitude!,
                              _routeCustomers[i - 1].longitude!,
                              c.latitude!,
                              c.longitude!);
                      return InkWell(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    CustomerDetailPage(customer: c))),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 4),
                          child: Row(children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF1565C0),
                                  shape: BoxShape.circle),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    Text(
                                        c.phones.isNotEmpty
                                            ? c.phones[0]
                                            : '无电话',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey)),
                                  ]),
                            ),
                            if (dist != null)
                              Text(_formatDist(dist),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFE65100),
                                      fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios,
                                size: 12, color: Colors.grey),
                          ]),
                        ),
                      );
                    }),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('预计总路程',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            Text(_estimateTotalDistance(),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE65100))),
                          ]),
                    ),
                  ]),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _clearRoute,
              icon: const Icon(Icons.clear,
                  size: 18, color: Color(0xFFE53935)),
              label: const Text('清除路线',
                  style: TextStyle(color: Color(0xFFE53935))),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              _buildStatItem(Icons.people, '总计', '$totalCustomerCount'),
              const Spacer(),
              _buildStatItem(
                  Icons.location_on, '有位置', '${customers.length}'),
              const Spacer(),
              _buildStatItem(Icons.star_outline_rounded, '高意向',
                  '${customers.where((c) => c.rating != null && c.rating! >= 4).length}'),
            ]),
          ),
        ),
      ]),
    );
  }

  void _buildOptimizedRoute(double startLat, double startLng, List<Customer> custs) {
    if (custs.isEmpty) {
      setState(() {
        _routeCustomers = [];
        _showingRoute = false;
      });
      return;
    }
    final unvisited = List<Customer>.from(custs);
    final route = <Customer>[];
    double curLat = startLat, curLng = startLng;
    while (unvisited.isNotEmpty) {
      Customer? best;
      double md = double.infinity;
      for (var c in unvisited) {
        final d = _distanceKm(curLat, curLng, c.latitude!, c.longitude!);
        if (d < md) {
          md = d;
          best = c;
        }
      }
      if (best != null) {
        route.add(best);
        curLat = best.latitude!;
        curLng = best.longitude!;
        unvisited.remove(best);
      }
    }
    setState(() {
      _routeStartLat = startLat;
      _routeStartLng = startLng;
      _routeCustomers = route;
      _showingRoute = true;
    });
    _drawRoutePolyline(route, startLat, startLng);

    // Move camera to show all route markers (defer slightly to allow tab animation)
    if (_mapController != null && route.isNotEmpty) {
      final allPoints = <LatLng>[
        LatLng(startLat, startLng),
        ...route.map((c) => LatLng(c.latitude!, c.longitude!)),
      ];
      double minLat = allPoints.first.latitude, maxLat = minLat;
      double minLng = allPoints.first.longitude, maxLng = minLng;
      for (final p in allPoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      // Prevent degenerate bounds (single point or very close points)
      if ((maxLat - minLat) < 0.001) {
        minLat -= 0.005;
        maxLat += 0.005;
      }
      if ((maxLng - minLng) < 0.001) {
        minLng -= 0.005;
        maxLng += 0.005;
      }
      // Defer camera move to allow tab switch animation to complete
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _mapController != null) {
          _mapController!.moveCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng),
              ),
              60,
            ),
          );
        }
      });
    }
  }

  String _estimateTotalDistance() {
    if (_routeCustomers.isEmpty || _routeStartLat == null) return '0 km';
    double t = 0;
    double pLat = _routeStartLat!, pLng = _routeStartLng!;
    for (final c in _routeCustomers) {
      t += _distanceKm(pLat, pLng, c.latitude!, c.longitude!);
      pLat = c.latitude!;
      pLng = c.longitude!;
    }
    t += _distanceKm(pLat, pLng, _routeStartLat!, _routeStartLng!);
    return _formatDist(t);
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0))),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  // ===== TAB 3: Nearby =====

  /// Fetch location for nearby tab using explicit state machine (no FutureBuilder)
  Future<void> _fetchNearbyLocation() async {
    if (!mounted) return;
    setState(() {
      _nearbyState = _NearbyState.loading;
      _nearbyError = null;
    });
    try {
      // Use cached position if available, otherwise fetch fresh (thread-safe)
      Position? pos = _currentPosition ?? await _getSafeCurrentLocation();
      if (!mounted) return;
      if (pos != null) {
        _currentPosition = pos;
        setState(() {
          _nearbyPosition = pos;
          _nearbyState = _NearbyState.success;
        });
      } else {
        setState(() {
          _nearbyState = _NearbyState.error;
          _nearbyError = null; // No position, not an exception
        });
      }
    } catch (e) {
      debugPrint('Nearby location fetch error: $e');
      if (!mounted) return;
      setState(() {
        _nearbyState = _NearbyState.error;
        _nearbyError = e;
      });
    }
  }

  Widget _buildNearbyView(List<Customer> customers) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    switch (_nearbyState) {
      case _NearbyState.loading:
        return const Center(child: CircularProgressIndicator());
      case _NearbyState.error:
        return _buildLocationUnavailable(_nearbyError);
      case _NearbyState.success:
        break;
    }

    // _nearbyState == success
    final pos = _nearbyPosition;
    if (pos == null) {
      return _buildLocationUnavailable(null);
    }
    final myLat = pos.latitude, myLng = pos.longitude;
    final nb = _getNearbyCustomers(myLat, myLng, _nearbyRadiusKm);

    return RefreshIndicator(
      onRefresh: _fetchNearbyLocation,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                      color: Color(0xFFE3F2FD), shape: BoxShape.circle),
                  child: const Icon(Icons.my_location_rounded,
                      size: 24, color: Color(0xFF1565C0)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('我的位置',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                        '${myLat.toStringAsFixed(4)}, ${myLng.toStringAsFixed(4)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${_nearbyRadiusKm.round()}km',
                      style: const TextStyle(
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('搜索半径:',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700)),
              const SizedBox(width: 8),
              ...[1, 3, 5, 10, 20, 30].map<Widget>((km) => InkWell(
                    onTap: () =>
                        setState(() => _nearbyRadiusKm = km.toDouble()),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (_nearbyRadiusKm - km).abs() < 0.01
                            ? primaryColor
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('$km km',
                          style: TextStyle(
                            fontSize: 12,
                            color: (_nearbyRadiusKm - km).abs() < 0.01
                                ? Colors.white
                                : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF1565C0).withValues(alpha: 0.08),
                const Color(0xFF1E88E5).withValues(alpha: 0.03),
              ]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNearbyStat(
                      '附近客户', '${nb.length}', Icons.people, const Color(0xFF1565C0)),
                  Container(
                      width: 1, height: 24, color: Colors.grey.shade300),
                  _buildNearbyStat(
                      '高意向',
                      '${nb.where((c) => c.rating != null && c.rating! >= 4).length}',
                      Icons.star,
                      const Color(0xFFFFB300)),
                  Container(
                      width: 1, height: 24, color: Colors.grey.shade300),
                  _buildNearbyStat(
                      '最近',
                      nb.isNotEmpty
                          ? _formatDist(_distanceKm(
                              myLat,
                              myLng,
                              nb.first.latitude!,
                              nb.first.longitude!))
                          : '-',
                      Icons.near_me,
                      const Color(0xFF43A047)),
                ]),
          ),
          const SizedBox(height: 16),
          if (nb.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                    mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search_off,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('${_nearbyRadiusKm.round()}km 内无客户',
                      style: TextStyle(
                          fontSize: 15, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text('尝试扩大搜索半径',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400)),
                ]),
              ),
            )
          else
            ...nb.asMap().entries.map<Widget>((e) {
              final i = e.key;
              final c = e.value;
              final d = _distanceKm(myLat, myLng, c.latitude!, c.longitude!);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  leading: Stack(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          const Color(0xFF43A047).withValues(alpha: 0.1),
                      child: Text(
                          c.name.isNotEmpty ? c.name.characters.first.toUpperCase() : '',
                          style: const TextStyle(
                              color: Color(0xFF43A047),
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ),
                    if (i < 3)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: i == 0
                                ? const Color(0xFFFFD700)
                                : i == 1
                                    ? const Color(0xFFC0C0C0)
                                    : const Color(0xFFCD7F32),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 1.5),
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                  ]),
                  title: Row(children: [
                    Text(c.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBC02D).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_ratingLabel(c.rating),
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFF57F17),
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 3),
                        if (c.phones.isNotEmpty)
                          Text(c.phones[0],
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600)),
                        const SizedBox(height: 3),
                        Row(children: [
                          Icon(Icons.directions_walk_rounded,
                              size: 14,
                              color: d < 1
                                  ? const Color(0xFF43A047)
                                  : const Color(0xFFFF9800)),
                          const SizedBox(width: 3),
                          Text(_formatDist(d),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: d < 1
                                      ? const Color(0xFF43A047)
                                      : const Color(0xFFFF9800))),
                        ]),
                      ]),
                  trailing: IconButton(
                    icon: const Icon(Icons.near_me,
                        size: 18, color: Color(0xFF1565C0)),
                    onPressed: () =>
                        _navigateToCustomer(myLat, myLng, c),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CustomerDetailPage(customer: c))),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNearbyStat(
      String label, String value, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 3),
      Text(value,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ]);
  }

  void _navigateToCustomer(double fromLat, double fromLng, Customer c) {
    _buildOptimizedRoute(fromLat, fromLng, [c]);
    _tabController.animateTo(0);
  }

  Widget _buildLocationUnavailable(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.gps_off, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('无法获取位置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            error != null ? '定位服务异常，请检查GPS和权限设置' : '请检查GPS权限设置',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchNearbyLocation,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ]),
      ),
    );
  }

  // ===== Web Placeholder =====
  Widget _buildWebPlaceholder(List<Customer> locCust) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppDesign.cardBg(isDark),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('地图功能 Web 端暂不可用',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          Text('请使用移动端查看',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
          if (locCust.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(),
            Text('有位置信息的客户: ${locCust.length}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            ...locCust.take(8).map<Widget>((c) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        const Color(0xFF1565C0).withValues(alpha: 0.1),
                    child: Text(c.name.isNotEmpty ? c.name.substring(0, 1) : '',
                        style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  title: Text(c.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                      '${c.latitude?.toStringAsFixed(4) ?? "?"}, ${c.longitude?.toStringAsFixed(4) ?? "?"}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward,
                      size: 16, color: Colors.grey),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CustomerDetailPage(customer: c))),
                )),
          ],
        ]),
      ),
    );
  }
}

class _QuickSheet extends StatelessWidget {
  final int customerId;
  const _QuickSheet({required this.customerId});

  @override
  Widget build(BuildContext context) {
    final ac = Provider.of<AppState>(context);
    final cust =
        ac.customers.where((c) => c.id == customerId).firstOrNull;
    if (cust == null) return const SizedBox.shrink();
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.25,
      maxChildSize: 0.55,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.1),
                child: Text(cust.name.isNotEmpty ? cust.name.characters.first.toUpperCase() : '',
                    style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cust.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFBC02D).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_staticRL(cust.rating),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFF57F17),
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        if (cust.alias != null && cust.alias!.isNotEmpty)
                          Text(cust.alias!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600)),
                      ]),
                    ]),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _infoChip(Icons.phone_rounded, '联系方式',
                      cust.phones.isNotEmpty ? cust.phones[0] : '-')),
              const SizedBox(width: 10),
              Expanded(
                  child: _infoChip(
                      Icons.cake_rounded, '年龄', cust.age?.toString() ?? '-')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _infoChip(Icons.calendar_today, '下次跟进',
                      cust.nextFollowUpDate ?? '-')),
              const SizedBox(width: 10),
              Expanded(
                  child: _infoChip(
                      Icons.person_outline, '性别', cust.gender ?? '-')),
            ]),
            if (cust.addresses.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('地址',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              ...cust.addresses.take(2).map<Widget>((a) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(a, style: const TextStyle(fontSize: 13)),
                  )),
            ],
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CustomerDetailPage(customer: cust)));
                  },
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('查看详情'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('关闭'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  static String _staticRL(int? r) {
    switch (r) {
      case 5: return '高意向';
      case 4: return '中高意向';
      case 3: return '中等意向';
      case 2: return '低意向';
      case 1: return '低意向';
      default: return '未评';
    }
  }

  static Widget _infoChip(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: const Color(0xFF1565C0)),
              const SizedBox(width: 4),
              Text(title,
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade600)),
            ]),
            const SizedBox(height: 4),
            Flexible(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
    );
  }
}
