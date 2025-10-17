import 'package:flutter/material.dart';
import 'admin_api.dart';
import 'dart:convert'; // Added for jsonDecode
import 'package:http/http.dart' as http; // Added for http

class AdminOrderCountPage extends StatefulWidget {
  const AdminOrderCountPage({super.key});

  @override
  State<AdminOrderCountPage> createState() => _AdminOrderCountPageState();
}

class _AdminOrderCountPageState extends State<AdminOrderCountPage> {
  late final AdminApi _api;
  bool loading = true;
  int total = 0;

  // Filters
  String? _selectedRestaurantId; // null => all restaurants
  String _selectedStatus = 'all'; // all | PENDING | ASSIGNED

  // Restaurant options
  List<Map<String, dynamic>> _restaurants = [];

  // Orders list
  List<Map<String, dynamic>> _orders = [];

  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      final uri = Uri.parse('${_api.baseUrl}/api/orders/$orderId/status');
      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      );
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cập nhật trạng thái thành $newStatus')),
          );
        }
        await _reloadAll();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi cập nhật trạng thái: ${res.statusCode}')),
          );
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _api = AdminApi.fromDefaults();
    _init();
  }

  Future<void> _init() async {
    setState(() => loading = true);
    try {
      final restaurants = await _api.fetchRestaurants();
      setState(() => _restaurants = restaurants);
      await _reloadAll();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _reloadAll() async {
    await Future.wait([_loadCount(), _loadOrders()]);
  }

  Future<void> _loadCount() async {
    try {
      final counters = await _api.fetchCounters(restaurantId: _selectedRestaurantId);
      int value;
      if (_selectedStatus == 'all') {
        value = counters.requests + counters.running;
      } else if (_selectedStatus == 'PENDING') {
        value = counters.requests;
      } else {
        value = counters.running;
      }
      setState(() => total = value);
    } catch (_) {
      setState(() => total = 0);
    }
  }

  Future<void> _loadOrders() async {
    try {
      // Luôn lấy đầy đủ đơn (theo nhà hàng nếu có), sau đó lọc theo _selectedStatus ở client
      final params = <String, String>{};
      if (_selectedRestaurantId != null) params['restaurantId'] = _selectedRestaurantId!;
      final uri = Uri.parse('${_api.baseUrl}/api/orders').replace(queryParameters: params.isEmpty ? null : params);
      final res = await AdminHttp.get(uri);
      if (res.statusCode == 200) {
        final data = AdminHttp.decodeList(res.body);

        // Xác định tập trạng thái cần hiển thị theo bộ lọc
        final Set<String> allowed = _selectedStatus == 'all'
            ? {'PENDING', 'ASSIGNED'}
            : {_selectedStatus};

        // Chỉ hiển thị tới khi nhà hàng bàn giao cho shipper (ẩn DELIVERING/PICKED_UP/DELIVERED/CANCELLED)
        final filtered = data.where((o) {
          final s = (o['status'] ?? '').toString();
          return allowed.contains(s);
        }).toList();
        setState(() => _orders = filtered);
      } else {
        setState(() => _orders = []);
      }
    } catch (_) {
      setState(() => _orders = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Số lượng đơn hàng', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Total count
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.deepOrange),
                      const SizedBox(width: 12),
                      Text(
                        'Tổng: $total đơn',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Filters
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bộ lọc', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Restaurant filter
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: _selectedRestaurantId,
                              decoration: const InputDecoration(
                                labelText: 'Nhà hàng',
                                border: OutlineInputBorder(),
                              ),
                              items: <DropdownMenuItem<String?>>[
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Tất cả nhà hàng'),
                                ),
                                ..._restaurants.map((r) => DropdownMenuItem<String?>(
                                      value: (r['_id'] ?? r['id']).toString(),
                                      child: Text((r['name'] ?? 'Nhà hàng').toString()),
                                    )),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedRestaurantId = v);
                                _reloadAll();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Status filter
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Trạng thái',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                                DropdownMenuItem(value: 'PENDING', child: Text('Đang chờ')),
                                DropdownMenuItem(value: 'ASSIGNED', child: Text('Đang chuẩn bị')),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _selectedStatus = v);
                                _reloadAll();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Orders list
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: _orders.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Không có đơn hàng nào'),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _orders.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final o = _orders[index];
                            final id = (o['orderId'] ?? '').toString();
                            final createdAt = DateTime.tryParse(o['createdAt']?.toString() ?? '');
                            final timeText = createdAt != null
                                ? '${createdAt.toLocal()}'.split('.')[0]
                                : '';
                            final status = (o['status'] ?? '').toString();
                            return ListTile(
                              title: Text('Đơn $id'),
                              subtitle: Text(timeText),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (status == 'PENDING')
                                    TextButton(
                                      onPressed: () async {
                                        // Khi nhà hàng hoàn thành món -> chuyển PENDING -> ASSIGNED
                                        await _updateStatus(id, 'ASSIGNED');
                                      },
                                      child: const Text('Hoàn thành'),
                                    ),
                                  // Trạng thái ASSIGNED: chờ shipper nhận, không cập nhật tiếp ở đây
                                  const SizedBox(width: 8),
                                  _StatusChip(status: status),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _colorFor(String s) {
    switch (s.toLowerCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'ASSIGNED':
        return Colors.blue;
      case 'DELIVERING':
        return Colors.blue;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

// Lightweight helper to use AdminApi baseUrl with raw http
class AdminHttp {
  static Future<dynamic> get(Uri uri) => http.get(uri);
  static List<Map<String, dynamic>> decodeList(String body) {
    final data = jsonDecode(body) as List<dynamic>;
    return List<Map<String, dynamic>>.from(data);
  }
}


