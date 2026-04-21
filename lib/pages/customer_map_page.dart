import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:insurecrm/providers/app_state.dart';
import 'package:insurecrm/models/customer.dart';
import 'package:insurecrm/pages/customer_detail_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class CustomerMapPage extends StatefulWidget {
  const CustomerMapPage({super.key});

  @override
  State<CustomerMapPage> createState() => _CustomerMapPageState();
}

class _CustomerMapPageState extends State<CustomerMapPage>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng _initialPosition = const LatLng(39.9042, 116.4074);
  bool _isLoading = true;
  List<Customer> _routeCustomers = [];
  double _nearbyRadiusKm = 5.0;
  bool _showingRoute = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
    });
    _initMap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initMap() async {
    try {
      final position = await _getCurrentLocation();
      if (position != null) {
        _initialPosition = LatLng(position.latitude, position.longitude);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      if (!(await Geolocator.isLocationServiceEnabled())) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
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
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * math.pi / 180;

  List<Customer> get _customersWithLocation =>
      Provider.of<AppState>(context, listen: false)
          .customers
          .where((c) => c.latitude != null && c.longitude != null)
          .toList();

  List<Customer> _getNearbyCustomers(LatLng center, double radiusKm) {
    final entries = _customersWithLocation
        .map((c) => MapEntry(
            c, _distanceKm(center.latitude, center.longitude, c.latitude!, c.longitude!)))
        .where((e) => e.value <= radiusKm)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries.map((e) => e.key).toList();
  }

  void _buildAllMarkers(List<Customer> customers) {
    final ms = <Marker>{};
    for (var c in customers) {
      if (c.latitude == null || c.longitude == null) continue;
      ms.add(Marker(
        markerId: MarkerId('c_${c.id}'),
        position: LatLng(c.latitude!, c.longitude!),
        infoWindow: InfoWindow(
          title: c.name,
          snippet: '${_ratingLabel(c.rating)} | ${c.phones.isNotEmpty ? c.phones[0] : "-"}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(_ratingHue(c.rating)),
        onTap: () => _onTap(c.id!),
      ));
    }
    setState(() => _markers = ms);
  }

  void _buildOptimizedRoute(LatLng start, List<Customer> custs) {
    if (custs.isEmpty) {
      setState(() {
        _polylines = {};
        _routeCustomers = [];
        _showingRoute = false;
      });
      return;
    }
    final unvisited = List<Customer>.from(custs);
    final route = <Customer>[];
    LatLng cur = start;
    while (unvisited.isNotEmpty) {
      Customer? best;
      double md = double.infinity;
      for (var c in unvisited) {
        final d = _distanceKm(
            cur.latitude, cur.longitude, c.latitude!, c.longitude!);
        if (d < md) {
          md = d;
          best = c;
        }
      }
      if (best != null) {
        route.add(best);
        cur = LatLng(best.latitude!, best.longitude!);
        unvisited.remove(best);
      }
    }
    final pts = <LatLng>[start];
    for (var c in route) {
      pts.add(LatLng(c.latitude!, c.longitude!));
    }
    pts.add(start);
    setState(() {
      _routeCustomers = route;
      _showingRoute = true;
      _polylines = {
        Polyline(
          polylineId: const PolylineId('r'),
          points: pts,
          color: const Color(0xFFE53935),
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        )
      };
    });
    if (_mapController != null && pts.length > 1) {
      final ml = pts.map((p) => p.latitude).reduce(math.min);
      final xl = pts.map((p) => p.latitude).reduce(math.max);
      final mg = pts.map((p) => p.longitude).reduce(math.min);
      final xg = pts.map((p) => p.longitude).reduce(math.max);
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(ml, mg), northeast: LatLng(xl, xg)),
        50,
      ));
    }
  }

  double _ratingHue(int? r) {
    switch (r) {
      case 5: return BitmapDescriptor.hueRed;
      case 4: return BitmapDescriptor.hueOrange;
      case 3: return BitmapDescriptor.hueYellow;
      case 2: return BitmapDescriptor.hueGreen;
      case 1: return BitmapDescriptor.hueAzure;
      default: return BitmapDescriptor.hueViolet;
    }
  }

  String _ratingLabel(int? r) {
    switch (r) {
      case 5: return '高意向';
      case 4: return '中高意向';
      case 3: return '中等意向';
      case 2: return '低意向';
      case 1: return '低意向';
      default: return '未评';
    }
  }

  String _formatDist(double km) =>
      km < 1 ? '${(km * 1000).round()}m' : '${km.toStringAsFixed(1)}km';

  void _onTap(int id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickSheet(customerId: id),
    );
  }

  void _clearRoute() {
    setState(() {
      _polylines = {};
      _routeCustomers = [];
      _showingRoute = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ac = Provider.of<AppState>(context);
    final allCust =
        ac.customers.where((c) => c.latitude != null && c.longitude != null).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_markers.isEmpty && !kIsWeb && allCust.isNotEmpty) {
        _buildAllMarkers(allCust);
      }
    });
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
                final p = await _getCurrentLocation();
                if (p != null && _mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(
                        LatLng(p.latitude, p.longitude), 14),
                  );
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMapView(allCust),
                _buildRoutePlanView(allCust),
                _buildNearbyView(allCust),
              ],
            ),
    );
  }

  // ===== TAB 1: Map View =====
  Widget _buildMapView(List<Customer> cs) {
    return Stack(children: [
      if (_isLoading)
        const Center(child: CircularProgressIndicator())
      else
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: _initialPosition, zoom: 12),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          compassEnabled: true,
          mapToolbarEnabled: true,
          onMapCreated: (c) => _mapController = c,
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
                ].map((c) => Container(
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
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_off_rounded,
                  size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text('暂无客户位置信息'),
              const SizedBox(height: 4),
              Text('在客户详情中设置位置后显示',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ]),
          ),
        ),
    ]);
  }

  Widget _buildChip(Customer c) {
    return GestureDetector(
      onTap: () {
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
                LatLng(c.latitude!, c.longitude!), 15),
          );
        }
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
                child: Text(c.name.characters.first,
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
  Widget _buildRoutePlanView(List<Customer> customers) {
    if (customers.isEmpty) {
      return const Center(child: Text('暂无可拜访客户'));
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
                    final p = await _getCurrentLocation();
                    if (p == null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('无法获取位置')));
                      return;
                    }
                    final nb = _getNearbyCustomers(
                        LatLng(p.latitude, p.longitude), 50);
                    _buildOptimizedRoute(
                        LatLng(p.latitude, p.longitude), nb);
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
                    final p = await _getCurrentLocation();
                    if (p == null) return;
                    _buildOptimizedRoute(
                        LatLng(p.latitude, p.longitude), customers);
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
                  final p = await _getCurrentLocation();
                  if (p == null) return;
                  final nb = _getNearbyCustomers(
                      LatLng(p.latitude, p.longitude), _nearbyRadiusKm);
                  if (nb.isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${_nearbyRadiusKm.round()}公里内无客户')));
                    return;
                  }
                  _buildOptimizedRoute(
                      LatLng(p.latitude, p.longitude), nb);
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
                      const SizedBox(width: 8),
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
              onPressed: () {
                setState(() {
                  _polylines = {};
                  _routeCustomers = [];
                  _showingRoute = false;
                });
              },
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
              _buildStatItem(Icons.people, '总计', '${customers.length}'),
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

  String _estimateTotalDistance() {
    if (_routeCustomers.isEmpty) return '0 km';
    double t = 0;
    LatLng p = _initialPosition;
    for (final c in _routeCustomers) {
      t += _distanceKm(p.latitude, p.longitude, c.latitude!, c.longitude!);
      p = LatLng(c.latitude!, c.longitude!);
    }
    t += _distanceKm(p.latitude, p.longitude, _initialPosition.latitude,
        _initialPosition.longitude);
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
  Widget _buildNearbyView(List<Customer> customers) {
    return FutureBuilder<Position?>(
      future: _getCurrentLocation(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data == null) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.gps_off, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text('无法获取位置'),
              const SizedBox(height: 4),
              Text('请检查GPS权限设置',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ]),
          );
        }
        final pos = snap.data!;
        final myLoc = LatLng(pos.latitude, pos.longitude);
        final nb = _getNearbyCustomers(myLoc, _nearbyRadiusKm);
        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
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
                                '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600)),
                          ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.1),
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
                  ...[1, 3, 5, 10, 20, 30].map((km) => GestureDetector(
                        onTap: () =>
                            setState(() => _nearbyRadiusKm = km.toDouble()),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _nearbyRadiusKm == km
                                ? const Color(0xFF1565C0)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text('$km km',
                              style: TextStyle(
                                fontSize: 12,
                                color: _nearbyRadiusKm == km
                                    ? Colors.white
                                    : Colors.grey.shade700,
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
                    const Color(0xFF1565C0).withOpacity(0.08),
                    const Color(0xFF1E88E5).withOpacity(0.03),
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
                                  myLoc.latitude,
                                  myLoc.longitude,
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
                ...nb.asMap().entries.map((e) {
                  final i = e.key;
                  final c = e.value;
                  final d = _distanceKm(myLoc.latitude, myLoc.longitude,
                      c.latitude!, c.longitude!);
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
                              const Color(0xFF43A047).withOpacity(0.1),
                          child: Text(
                              c.name.characters.first.toUpperCase(),
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
                            color: const Color(0xFFFBC02D).withOpacity(0.12),
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
                            _navigateToCustomer(myLoc, c),
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
      },
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

  void _navigateToCustomer(LatLng from, Customer c) {
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('nav'),
          points: [from, LatLng(c.latitude!, c.longitude!)],
          color: const Color(0xFF1565C0),
          width: 4,
          patterns: [PatternItem.dash(15), PatternItem.gap(8)],
        )
      };
      _showingRoute = true;
    });
    _tabController.animateTo(0);
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
              math.min(from.latitude, c.latitude!),
              math.min(from.longitude, c.longitude!)),
          northeast: LatLng(
              math.max(from.latitude, c.latitude!),
              math.max(from.longitude, c.longitude!)),
        ),
        50,
      ));
    }
  }

  // ===== Web Placeholder =====
  Widget _buildWebPlaceholder(List<Customer> locCust) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
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
            ...locCust.take(8).map((c) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        const Color(0xFF1565C0).withOpacity(0.1),
                    child: Text(c.name.substring(0, 1),
                        style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  title: Text(c.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                      '${c.latitude!.toStringAsFixed(4)}, ${c.longitude!.toStringAsFixed(4)}',
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
                backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
                child: Text(cust.name.characters.first.toUpperCase(),
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
                                const Color(0xFFFBC02D).withOpacity(0.12),
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
              ...cust.addresses.take(2).map((a) => Padding(
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
      case 4: return '较好';
      case 3: return '一般';
      case 2: return '较差';
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
