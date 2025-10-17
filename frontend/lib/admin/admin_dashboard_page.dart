import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'admin_profile_order_count_page.dart';
import 'admin_api.dart';
import 'admin_food_list_page.dart';
import 'admin_add_food_page.dart';
import 'admin_food_detail_page.dart';
import 'admin_notifications_page.dart';
import 'admin_revenue_detail_page.dart';
import 'admin_profile_page.dart';
import 'admin_reviews_detail_page.dart';

String formatCurrencyVND(double v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idxFromEnd = s.length - i;
    buf.write(s[i]);
    if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
      buf.write(',');
    }
  }
  return '₫${buf.toString()}';
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  String _selectedLocation = '';
  String? _selectedRestaurantId;
  String _filter = 'Hàng ngày';
  late final AdminApi _api;
  Timer? _refreshTimer;

  int runningOrders = 0;
  int orderRequests = 0;
  double avgRestaurantRating = 0.0;
  int totalRestaurantReviews = 0;

  final Map<String, List<double>> _mockRevenueByFilter = {
    'Hàng ngày': [],
    'Hàng tuần': [],
    'Hàng tháng': [],
  };
  final Map<String, List<RevenuePoint>> _pointsByFilter = {
    'Hàng ngày': [],
    'Hàng tuần': [],
    'Hàng tháng': [],
  };
  int _tabIndex = 0; 

  @override
  Widget build(BuildContext context) {
    final points = _pointsByFilter[_filter] ?? const [];
    final seriesForChart = points.isNotEmpty
        ? points.map((e) => e.total).toList()
        : (_mockRevenueByFilter[_filter] ?? const []);
    final labelsDyn = points.isNotEmpty ? points.map((e) => e.period).toList() : labelsForFilter(_filter);
    final tooltipsDyn = points.isNotEmpty
        ? points.map((e) => e.tooltip).toList()
        : List<String>.filled(labelsDyn.length, '');
    final double totalRevenue = seriesForChart.isNotEmpty
        ? seriesForChart.fold(0.0, (prev, v) => prev + v)
        : 0.0;

    final dashboardPage = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              selectedLocation: _selectedLocation.isEmpty ? 'Đang tải địa điểm...' : _selectedLocation,
              onTapChoose: _openRestaurantPicker,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdminOrderCountPage()),
                      );
                    },
                    child: _StatCard(
                      value: runningOrders.toString().padLeft(2, '0'),
                      label: 'Đơn đang chờ',
                      icon: Icons.local_shipping_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdminOrderCountPage()),
                      );
                    },
                    child: _StatCard(
                      value: orderRequests.toString().padLeft(2, '0'),
                      label: 'Yêu cầu đơn hàng',
                      icon: Icons.pending_actions_outlined,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _RevenueCard(
              total: totalRevenue,
              filter: _filter,
              onFilterChanged: (value) {
                setState(() => _filter = value);
                _loadRevenue();
              },
              series: seriesForChart,
              labels: labelsDyn,
              tooltips: tooltipsDyn,
            ),
            const SizedBox(height: 16),
            _ReviewsPreview(
              rating: avgRestaurantRating,
              totalReviews: totalRestaurantReviews,
              onViewAll: () {
                if (_selectedRestaurantId == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminReviewsDetailPage(
                      restaurantId: _selectedRestaurantId!,
                      restaurantName: _selectedLocation,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _PopularItemsSection(restaurantId: _selectedRestaurantId),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );

    final pages = <Widget>[
      dashboardPage,
      const AdminFoodListPage(),
      const AdminNotificationsPage(),
      const AdminProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      body: IndexedStack(index: _tabIndex, children: pages),
      bottomNavigationBar: _BottomBar(
        selectedIndex: _tabIndex,
        onSelect: (i) => setState(() => _tabIndex = i),
        onCenterTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminAddFoodPage()),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _api = AdminApi.fromDefaults();
    _initDefaultRestaurant();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_selectedRestaurantId != null && mounted) {
        await Future.wait([
          _loadCounters(),
          _loadRevenue(),
          _loadRestaurantRatings(),
        ]);
      }
    });
  }

  Future<void> _initDefaultRestaurant() async {
    try {
      final restaurants = await _api.fetchRestaurants();
      if (restaurants.isNotEmpty) {
        final r = restaurants.first;
        setState(() {
          _selectedRestaurantId = (r['_id'] ?? r['id']).toString();
          _selectedLocation = (r['name'] ?? r['address'] ?? '').toString();
        });
        await Future.wait([
          _loadCounters(),
          _loadRevenue(),
          _loadRestaurantRatings(),
        ]);
      }
    } catch (_) {}
  }

  Future<void> _loadCounters() async {
    try {
      final c = await _api.fetchCounters(restaurantId: _selectedRestaurantId);
      setState(() {
        runningOrders = c.running;
        orderRequests = c.requests;
      });
    } catch (_) {
      // fallback giữ mock
    }
  }

  Future<void> _loadRestaurantRatings() async {
    try {
      if (_selectedRestaurantId == null) return;
      
      final restaurants = await _api.fetchRestaurants();
      final selectedRestaurant = restaurants.firstWhere(
        (r) => (r['_id'] ?? r['id']).toString() == _selectedRestaurantId,
        orElse: () => restaurants.isNotEmpty ? restaurants.first : {},
      );
      
      if (selectedRestaurant.isEmpty) return;
      
      final rating = (selectedRestaurant['rating'] is num) ? (selectedRestaurant['rating'] as num).toDouble() : 0.0;
      final reviews = selectedRestaurant['reviews'] as List? ?? [];
      
      setState(() {
        avgRestaurantRating = rating;
        totalRestaurantReviews = reviews.length;
      });
    } catch (_) {
      // keep defaults if failed
    }
  }

  Future<void> _loadRevenue() async {
    try {
      final g = _filter == 'Hàng ngày'
          ? 'daily'
          : _filter == 'Hàng tuần'
              ? 'weekly'
              : 'monthly';
      final series = await _api.fetchRevenue(granularity: g, restaurantId: _selectedRestaurantId);
      setState(() {
        // Doanh thu chỉ tính đơn đã thanh toán (paid) theo API backend
        _pointsByFilter[_filter] = series;
        _mockRevenueByFilter[_filter] = series.map((e) => e.total).toList();
      });
    } catch (_) {
      // fallback giữ mock
    }
  }

  List<double> _padSeries(List<double> input, int target) {
    if (input.isEmpty) return List<double>.filled(target, 0);
    if (input.length >= target) return input;
    final padding = List<double>.filled(target - input.length, 0);
    return [...padding, ...input];
  }

  List<String> _padStringList(List<String> input, int target) {
    if (input.isEmpty) return List<String>.filled(target, '');
    if (input.length >= target) return input;
    final padding = List<String>.filled(target - input.length, '');
    return [...padding, ...input];
  }

  List<String> labelsForFilter(String filter) {
    if (filter == 'Hàng ngày') {
      return ['T2','T3','T4','T5','T6'];
    }
    if (filter == 'Hàng tuần') {
      return ['Tuần 1','Tuần 2','Tuần 3','Tuần 4'];
    }
    return List<String>.generate(5, (i) => '');
  }

  Future<void> _openRestaurantPicker() async {
    try {
      final restaurants = await _api.fetchRestaurants();
      if (!mounted) return;
      final chosen = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, i) {
                final r = restaurants[i];
                return ListTile(
                  title: Text(
                    r['name'] ?? 'Nhà hàng',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    (r['address'] ?? '').toString(),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () => Navigator.of(ctx).pop(r),
                );
              },
              separatorBuilder: (_, __) => const Divider(),
              itemCount: restaurants.length,
            ),
          );
        },
      );
      if (chosen != null) {
        setState(() {
          _selectedRestaurantId = (chosen['_id'] ?? chosen['id'])?.toString();
          _selectedLocation = (chosen['name'] ?? chosen['address'] ?? 'Nhà hàng').toString();
        });
        await Future.wait([
          _loadCounters(),
          _loadRevenue(),
          _loadRestaurantRatings(),
        ]);
      }
    } catch (_) {}
  }
}

class _Header extends StatelessWidget {
  final String selectedLocation;
  final VoidCallback onTapChoose;

  const _Header({
    required this.selectedLocation,
    required this.onTapChoose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const _Avatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ĐỊA ĐIỂM',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: onTapChoose,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedLocation,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.black87),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 18,
      backgroundImage: AssetImage('assets/homepageUser/restaurant_img2.jpg'),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.deepOrange),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
          ),
        ],
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final double total;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final List<double> series;
  final List<String> labels;
  final List<String> tooltips;

  const _RevenueCard({
    required this.total,
    required this.filter,
    required this.onFilterChanged,
    required this.series,
    required this.labels,
    required this.tooltips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng doanh thu',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatCurrencyVND(total),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: filter,
                  items: const [
                    DropdownMenuItem(value: 'Hàng ngày', child: Text('Hàng ngày')),
                    DropdownMenuItem(value: 'Hàng tuần', child: Text('Hàng tuần')),
                    DropdownMenuItem(value: 'Hàng tháng', child: Text('Hàng tháng')),
                  ],
                  onChanged: (v) {
                    if (v != null) onFilterChanged(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminRevenueDetailPage()),
                  );
                },
                child: const Text('Xem chi tiết'),
              )
            ],
          ),
          const SizedBox(height: 12),
          _LineChart(
            series: series,
            labels: labels,
            tooltips: tooltips,
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final ticks = labels.isNotEmpty ? labels : const <String>['', '', '', '', '', '', '', ''];
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ticks
                    .map((t) => Flexible(
                          child: Text(
                            t,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ))
                    .toList(),
              );
            },
          )
        ],
      ),
    );
  }

  // removed per top-level formatCurrencyVND
}

class _LineChart extends StatefulWidget {
  final List<double> series;
  final List<String> labels;
  final List<String> tooltips;
  const _LineChart({required this.series, this.labels = const [], this.tooltips = const []});

  @override
  State<_LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<_LineChart> {
  int _selectedIndex = -1; // -1 => default to last point

  @override
  void didUpdateWidget(covariant _LineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series.length != widget.series.length) {
      _selectedIndex = -1;
    }
  }

  void _updateSelection(Offset localPos, Size size) {
    final s = widget.series;
    if (s.isEmpty) return;
    final clampedX = localPos.dx.clamp(0.0, size.width);
    final ratio = s.length <= 1 ? 0.0 : clampedX / size.width;
    final idx = (ratio * (s.length - 1)).round().clamp(0, s.length - 1);
    if (idx != _selectedIndex) {
      setState(() => _selectedIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 7,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return MouseRegion(
            onHover: (event) => _updateSelection(event.localPosition, size),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (d) => _updateSelection(d.localPosition, size),
              onPanUpdate: (d) => _updateSelection(d.localPosition, size),
              onTapDown: (d) => _updateSelection(d.localPosition, size),
              child: CustomPaint(
                painter: _LineChartPainter(
                  series: widget.series,
                  labels: widget.labels,
                  tooltips: widget.tooltips,
                  selectedIndex: _selectedIndex >= 0
                      ? _selectedIndex
                      : (widget.series.isEmpty ? 0 : widget.series.length - 1),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> series;
  final List<String> labels;
  final List<String> tooltips;
  final int selectedIndex;
  _LineChartPainter({required this.series, required this.labels, required this.tooltips, required this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFFF8F9FB)
      ..style = PaintingStyle.fill;
    final borderRadius = 12.0;

    final rrect = RRect.fromRectAndRadius(  
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(rrect, bgPaint);

    if (series.isEmpty) return;

    final maxV = series.reduce((a, b) => a > b ? a : b);
    final minV = series.reduce((a, b) => a < b ? a : b);
    final dy = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    final path = Path();
    for (int i = 0; i < series.length; i++) {
      final x = size.width * (i / (series.length - 1));
      final y = size.height - ((series[i] - minV) / dy) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = Colors.deepOrange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    final sel = selectedIndex.clamp(0, series.length - 1);
    final x = size.width * (sel / (series.length - 1));
    final y = size.height - ((series[sel] - minV) / dy) * size.height;

    final dotPaint = Paint()..color = Colors.deepOrange;
    canvas.drawCircle(Offset(x, y), 5, dotPaint);

    final valueLabel = formatCurrencyVND(series[sel]);
    String period = (tooltips.isNotEmpty && sel < tooltips.length && tooltips[sel].isNotEmpty)
        ? tooltips[sel]
        : ((labels.isNotEmpty && sel < labels.length) ? labels[sel] : '');
    final textPainter = TextPainter(
      text: TextSpan(children: [
        if (period.isNotEmpty)
          const TextSpan(text: '\n'),
        TextSpan(text: valueLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final labelPadding = 10.0;
    final minLabelWidth = 90.0;
    final labelWidth = (textPainter.width + 22).clamp(minLabelWidth, size.width) as double;
    final labelHeight = textPainter.height + 14;

    final isNearBottom = y > size.height * 0.8;
    final double tooltipTop = (isNearBottom
            ? (y - labelHeight - 12).clamp(6.0, size.height - labelHeight - 6.0)
            : (y + 12).clamp(6.0, size.height - labelHeight - 6.0))
        as double;
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        ((x - labelWidth / 2).clamp(6.0, size.width - labelWidth - 6.0)).toDouble(),
        tooltipTop,
        labelWidth,
        labelHeight,
      ),
      const Radius.circular(8),
    );

    final labelPaint = Paint()..color = Colors.black87;
    canvas.drawRRect(labelRect, labelPaint);

    textPainter.paint(canvas, Offset(
      labelRect.left + labelPadding / 2,
      labelRect.top + (labelHeight - textPainter.height) / 2,
    ));

    if (period.isNotEmpty) {
      final periodPainter = TextPainter(
        text: TextSpan(text: period, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      periodPainter.layout(maxWidth: labelWidth);
      final periodOffset = Offset(
        labelRect.left + (labelWidth - periodPainter.width) / 2,
        labelRect.top + 3,
      );
      periodPainter.paint(canvas, periodOffset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ReviewsPreview extends StatelessWidget {
  final double rating;
  final int totalReviews;
  final VoidCallback? onViewAll;
  const _ReviewsPreview({required this.rating, required this.totalReviews, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.deepOrange, size: 28),
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 8),
          Text('Tổng ${totalReviews} đánh giá'),
          const Spacer(),
          TextButton(onPressed: onViewAll, child: const Text('Xem tất cả đánh giá')),
        ],
      ),
    );
  }
}

class _PopularItemsSection extends StatelessWidget {
  final String? restaurantId;
  const _PopularItemsSection({this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Món phổ biến trong tuần',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TopFoodsList(restaurantId: restaurantId),
        ],
      ),
    );
  }
}

class _TopFoodsList extends StatefulWidget {
  final String? restaurantId;
  const _TopFoodsList({this.restaurantId});

  @override
  State<_TopFoodsList> createState() => _TopFoodsListState();
}

class _TopFoodsListState extends State<_TopFoodsList> {
  late final AdminApi _api;
  bool loading = true;
  List<Map<String, dynamic>> foods = [];

  @override
  void initState() {
    super.initState();
    _api = AdminApi.fromDefaults();
    _load();
  }

  @override
  void didUpdateWidget(_TopFoodsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurantId != widget.restaurantId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await _api.fetchTopFoods(limit: 3, restaurantId: widget.restaurantId);
      setState(() => foods = data);
    } catch (_) {
      setState(() => foods = []);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (foods.isEmpty) {
      return const SizedBox(
        height: 50,
        child: Center(child: Text('Chưa có dữ liệu đơn hàng')), 
      );
    }
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: foods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final f = foods[index];
          final title = (f['name'] ?? '').toString();
          String _normalizeImage(dynamic v) {
            final s = (v ?? '').toString();
            if (s.isEmpty) return 'assets/homepageUser/restaurant_img1.jpg';
            String path = s.replaceFirst('homepageuser/', 'homepageUser/');
            if (path.startsWith('http') || path.startsWith('data:')) return path;
              // Use asset path as stored in DB (already includes assets/...)
              return path;
          }
          final image = _normalizeImage(f['image']);
          final qty = (f['totalQuantity'] ?? 0) as int;
          return GestureDetector(
            onTap: () async {
              final changed = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AdminFoodDetailPage(food: f)),
              );
              if (changed == true) {
                _load();
              }
            },
            child: _PopularItemCard(image: image, title: '$title (x$qty)'),
          );
        },
      ),
    );
  }
}

class _PopularItemCard extends StatelessWidget {
  final String image;
  final String title;
  const _PopularItemCard({required this.image, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: image.startsWith('http')
                ? Image.network(
                    image,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => _imgFallback(),
                  )
                : image.startsWith('data:')
                    ? _base64Image(image)
                    : Image.asset(
                        image,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => _imgFallback(),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgFallback() => Container(
        color: const Color(0xFFF5F6FA),
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
      );

  Widget _base64Image(String dataUrl) {
    try {
      final b64 = dataUrl.split(',').last;
      return Image.memory(base64Decode(b64), width: double.infinity, fit: BoxFit.cover);
    } catch (_) {
      return _imgFallback();
    }
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onCenterTap;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _BottomBar({required this.onCenterTap, this.selectedIndex = 0, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavIcon(icon: Icons.grid_view_rounded, selected: selectedIndex == 0, onTap: () => onSelect(0)),
          _NavIcon(icon: Icons.menu_rounded, selected: selectedIndex == 1, onTap: () => onSelect(1)),
          _CenterButton(onTap: onCenterTap),
          _NavIcon(icon: Icons.notifications_none_rounded, selected: selectedIndex == 2, onTap: () => onSelect(2)),
          _NavIcon(icon: Icons.person_outline_rounded, selected: selectedIndex == 3, onTap: () => onSelect(3)),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _NavIcon({required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.deepOrange : Colors.black54;
    return InkWell(
      onTap: onTap,
      child: Icon(icon, color: color),
    );
  }
}

class _CenterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.deepOrange,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

