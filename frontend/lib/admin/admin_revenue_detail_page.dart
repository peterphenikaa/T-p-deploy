import 'package:flutter/material.dart';
import 'admin_api.dart';

class AdminRevenueDetailPage extends StatefulWidget {
  const AdminRevenueDetailPage({Key? key}) : super(key: key);

  @override
  State<AdminRevenueDetailPage> createState() => _AdminRevenueDetailPageState();
}

class _AdminRevenueDetailPageState extends State<AdminRevenueDetailPage> {
  late final AdminApi _api;
  bool _loading = true;
  String _timeFilter = 'Tất cả thời gian';
  List<Map<String, dynamic>> _restaurants = [];
  Map<String, double> _revenueByRestaurant = {};
  Map<String, int> _reviewsByRestaurant = {};
  Map<String, int> _itemsByRestaurant = {};

  @override
  void initState() {
    super.initState();
    _api = AdminApi.fromDefaults();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final restaurants = await _api.fetchRestaurants();
      // Placeholder: aggregate using available endpoints. Here we only have revenue series without range.
      // We will fetch monthly revenue per restaurant as approximation for filters.
      final Map<String, double> revenueMap = {};
      final Map<String, int> reviewsMap = {};
      int windowCount(String filter, int length) {
        if (filter == 'Tất cả thời gian') return length;
        if (filter == 'Tháng hiện tại') return length > 0 ? 1 : 0;
        if (filter == 'Tháng trước') return -1; // special: pick previous month only
        if (filter == '6 tháng trước') return length < 6 ? length : 6;
        if (filter == 'Năm hiện tại') return length < 12 ? length : 12;
        return length;
      }

      // Load all foods to compute counts per restaurant
      List<Map<String, dynamic>> foods = const [];
      try {
        foods = await _api.fetchFoods();
      } catch (_) {}

      for (final r in restaurants) {
        final id = (r['_id'] ?? r['id']).toString();
        final name = (r['name'] ?? 'Nhà hàng').toString();
        // Revenue: sum of latest monthly series
        try {
          final series = await _api.fetchRevenue(granularity: 'monthly', restaurantId: id);
          double total;
          if (_timeFilter == 'Tháng trước') {
            if (series.length >= 2) {
              total = series[series.length - 2].total;
            } else {
              total = 0.0;
            }
          } else {
            final w = windowCount(_timeFilter, series.length);
            if (w <= 0) {
              total = 0.0;
            } else {
              final start = (series.length - w).clamp(0, series.length);
              total = series.sublist(start).fold<double>(0.0, (p, e) => p + e.total);
            }
          }
          revenueMap[name] = total;
        } catch (_) {
          revenueMap[name] = 0.0;
        }
        // Reviews count and items count from restaurant object if available
        final reviews = (r['reviews'] is List) ? (r['reviews'] as List).length : (r['reviewCount'] ?? 0) as int;
        reviewsMap[name] = reviews;

        // Items count by restaurantId from foods
        final itemCount = foods.where((f) {
          final rid = (f['restaurantId'] ?? f['restaurantID'] ?? f['restaurant'] ?? '').toString();
          return rid.isNotEmpty && rid == id;
        }).length;
        _itemsByRestaurant[name] = itemCount;
      }

      setState(() {
        _restaurants = restaurants;
        _revenueByRestaurant = revenueMap;
        _reviewsByRestaurant = reviewsMap;
        // _itemsByRestaurant already filled above where possible
      });
    } catch (_) {
      setState(() {
        _restaurants = [];
        _revenueByRestaurant = {};
        _reviewsByRestaurant = {};
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  double get totalRevenue => _revenueByRestaurant.values.fold(0.0, (p, v) => p + v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Chi tiết thống kê', style: TextStyle(color: Colors.black)),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TotalRevenueCard(total: totalRevenue, filter: _timeFilter, onFilterChanged: (v) {
                      setState(() => _timeFilter = v);
                      _load();
                    }),
                    const SizedBox(height: 16),
                    _PieSection(
                      title: 'Doanh thu theo nhà hàng',
                      data: _revenueByRestaurant.map((k, v) => MapEntry(k, v.toDouble())),
                      valueFormatter: (v) => _formatCurrencyVND(v),
                    ),
                    const SizedBox(height: 16),
                    _PieSection(
                      title: 'Số lượng đánh giá',
                      data: _reviewsByRestaurant.map((k, v) => MapEntry(k, v.toDouble())),
                      valueFormatter: (v) => v.toStringAsFixed(0),
                    ),
                    const SizedBox(height: 16),
                    _PieSection(
                      title: 'Số mặt hàng hiện có',
                      data: _itemsByRestaurant.map((k, v) => MapEntry(k, v.toDouble())),
                      valueFormatter: (v) => v.toStringAsFixed(0),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatCurrencyVND(double v) {
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
}

class _TotalRevenueCard extends StatelessWidget {
  final double total;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  const _TotalRevenueCard({required this.total, required this.filter, required this.onFilterChanged});

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tổng doanh thu', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(_formatCurrencyVND(total), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: filter,
              items: const [
                DropdownMenuItem(value: 'Tất cả thời gian', child: Text('Tất cả thời gian')),
                DropdownMenuItem(value: 'Tháng hiện tại', child: Text('Tháng hiện tại')),
                DropdownMenuItem(value: 'Tháng trước', child: Text('Tháng trước')),
                DropdownMenuItem(value: '6 tháng trước', child: Text('6 tháng trước')),
                DropdownMenuItem(value: 'Năm hiện tại', child: Text('Năm hiện tại')),
              ],
              onChanged: (v) {
                if (v != null) onFilterChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrencyVND(double v) {
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
}

class _PieSection extends StatelessWidget {
  final String title;
  final Map<String, double> data;
  final String Function(double) valueFormatter;
  const _PieSection({required this.title, required this.data, required this.valueFormatter});

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
                child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.4,
            child: _PieChart(data: data),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: data.entries.map((e) {
              final color = _colorForIndex(e.key.hashCode);
              final total = data.values.fold<double>(0.0, (p, v) => p + v);
              final percent = total == 0 ? 0.0 : (e.value / total * 100);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${e.key}: ${percent.toStringAsFixed(1)}% (${valueFormatter(e.value)})'),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  final Map<String, double> data;
  const _PieChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _PiePainter(data),
        );
      },
    );
  }
}

class _PiePainter extends CustomPainter {
  final Map<String, double> data;
  _PiePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final double total = data.values.fold<double>(0.0, (p, v) => p + v);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) * 0.85;

    // Background circle
    final bgPaint = Paint()
      ..color = const Color(0xFFF8F9FB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    if (total <= 0) {
      // Draw empty ring
      final emptyPaint = Paint()
        ..color = const Color(0xFFE0E0E0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.3;
      canvas.drawCircle(center, radius * 0.75, emptyPaint);
      return;
    }

    double startRadian = -1.5708; // -90deg
    for (final entry in data.entries) {
      final sweep = (entry.value / total) * 6.28318530718; // 2*pi
      final paint = Paint()
        ..color = _colorForIndex(entry.key.hashCode)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.3
        ..strokeCap = StrokeCap.butt;

      final rect = Rect.fromCircle(center: center, radius: radius * 0.75);
      canvas.drawArc(rect, startRadian, sweep, false, paint);
      startRadian += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Color _colorForIndex(int i) {
  final colors = <Color>[
    const Color(0xFFEF5350),
    const Color(0xFFAB47BC),
    const Color(0xFF5C6BC0),
    const Color(0xFF29B6F6),
    const Color(0xFF26A69A),
    const Color(0xFF9CCC65),
    const Color(0xFFFFCA28),
    const Color(0xFFFFA726),
    const Color(0xFF8D6E63),
    const Color(0xFF78909C),
  ];
  final idx = (i.abs()) % colors.length;
  return colors[idx];
}


