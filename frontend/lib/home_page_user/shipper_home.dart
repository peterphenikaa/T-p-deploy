import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import 'shipper_order_detail_page.dart';

class ShipperHomePage extends StatefulWidget {
  const ShipperHomePage({Key? key}) : super(key: key);

  @override
  State<ShipperHomePage> createState() => _ShipperHomePageState();
}

class _ShipperHomePageState extends State<ShipperHomePage> {
  List<Map<String, dynamic>> pendingOrders = [];
  List<Map<String, dynamic>> myOrders = [];
  bool isLoading = true;
  Timer? _pollTimer;
  int _lastPendingCount = 0;
  String? _shipperId;
  String? _shipperName;

  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';
  }

  @override
  void initState() {
    super.initState();
    // Delay to safely access Provider after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndLoad();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _initializeAndLoad() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _shipperId = auth.userId;
      _shipperName = auth.userName;
    });

    _loadOrders();
    _loadMyOrders();

    // Poll for updates every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadOrders(showNotification: true);
      _loadMyOrders();
    });
  }

  Future<void> _loadOrders({bool showNotification = false}) async {
    try {
      // Lấy các đơn nhà hàng đã hoàn thành món và sẵn sàng cho shipper: ASSIGNED
      final url = Uri.parse('$baseUrl/api/orders?status=ASSIGNED');
      print('🔍 Shipper fetching orders: $url');
      final response = await http.get(url);

      print('📥 Shipper response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final newPending = List<Map<String, dynamic>>.from(data);
        
        print('📦 Found ${newPending.length} pending orders');
        
        // Check if new order arrived
        if (showNotification && newPending.length > _lastPendingCount) {
          print('🔔 New order detected!');
          _showNewOrderNotification();
        }
        
        setState(() {
          pendingOrders = newPending;
          _lastPendingCount = newPending.length;
          isLoading = false;
        });
      }
    } catch (e) {
      print('💥 Error loading orders: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadMyOrders() async {
    try {
      final sid = _shipperId;
      // Require a valid Mongo ObjectId (24 hex chars) to avoid cast errors on backend
      final isValidObjectId = sid != null && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(sid);
      if (!isValidObjectId) {
        setState(() {
          myOrders = [];
        });
        return;
      }

      final url = Uri.parse('$baseUrl/api/orders?shipperId=$sid');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        // Exclude completed/cancelled from "Đang giao"
        final filtered = data.where((o) {
          final s = (o as Map<String, dynamic>)['status']?.toString() ?? '';
          return s != 'DELIVERED' && s != 'CANCELLED';
        }).toList();
        setState(() {
          myOrders = List<Map<String, dynamic>>.from(filtered);
        });
      }
    } catch (e) {
      print('💥 Error loading my orders: $e');
    }
  }

  void _showNewOrderNotification() {
    // Show snackbar + play sound effect
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.notifications_active, color: Colors.white),
            SizedBox(width: 12),
            Text('🔔 Đơn hàng mới!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      // Use logged-in shipper profile
      final sid = _shipperId;
      final sname = _shipperName ?? 'Shipper';

      final isValidObjectId = sid != null && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(sid);
      if (!isValidObjectId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không xác định được Shipper. Hãy đăng nhập tài khoản shipper.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final url = Uri.parse('$baseUrl/api/orders/$orderId/assign');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'shipperId': sid,
          'shipperName': sname,
        }),
      );

      if (response.statusCode == 200) {
        // Move order to My Orders immediately for better UX
        Map<String, dynamic>? assigned;
        try {
          final body = json.decode(response.body);
          if (body is Map && body['order'] is Map) {
            assigned = Map<String, dynamic>.from(body['order']);
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã nhận đơn thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          pendingOrders.removeWhere((o) => (o['orderId'] ?? '') == orderId);
          if (assigned != null) {
            myOrders.insert(0, assigned!);
          }
        });
        // Refresh from server to be consistent
        _loadOrders();
        _loadMyOrders();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      final url = Uri.parse('$baseUrl/api/orders/$orderId/cancel');
      final response = await http.put(url);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Đã hủy đơn'),
            backgroundColor: Colors.red,
          ),
        );
        _loadOrders();
        _loadMyOrders();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f7fb),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Shipper Dashboard',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: () {
              _loadOrders();
              _loadMyOrders();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await _loadOrders();
              await _loadMyOrders();
            },
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Thêm padding bottom để tránh che khuất FAB
                    children: [
                      _buildStatsCards(),
                      const SizedBox(height: 24),
                      _buildSectionHeader('🔔 Đơn hàng chờ nhận', pendingOrders.length),
                      const SizedBox(height: 12),
                      if (pendingOrders.isEmpty)
                        _buildEmptyState('Chưa có đơn hàng mới')
                      else
                        ...pendingOrders.map((order) => _buildPendingOrderCard(order)),
                      const SizedBox(height: 24),
                      _buildSectionHeader('📦 Đơn hàng của tôi', myOrders.length),
                      const SizedBox(height: 12),
                      if (myOrders.isEmpty)
                        _buildEmptyState('Chưa có đơn hàng nào')
                      else
                        ...myOrders.map((order) => _buildMyOrderCard(order)),
                    ],
                  ),
          ),
          
          // Icon đăng xuất tròn ở góc dưới bên phải cho shipper
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: () => _showLogoutDialog(context),
                backgroundColor: Colors.blue[600],
                child: const Icon(
                  Icons.logout,
                  color: Colors.white,
                  size: 24,
                ),
                elevation: 0,
                mini: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Đơn chờ',
            pendingOrders.length.toString(),
            Colors.orange,
            Icons.pending_actions,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Đang giao',
            myOrders.length.toString(),
            Colors.blue,
            Icons.local_shipping,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingOrderCard(Map<String, dynamic> order) {
    final orderId = order['orderId'] ?? '';
    final total = order['total'] ?? 0;
    final address = order['deliveryAddress'] ?? '';
    final items = (order['items'] as List?) ?? [];
    final itemCount = items.length;
    final restaurant = order['restaurantName'] ?? 'Restaurant';
    final eta = order['estimatedDeliveryTime'] ?? '20-30 phút';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        orderId,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        eta,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.red[400], size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.fastfood, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$itemCount món',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.attach_money, color: Colors.green[600], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '₫${total.toString()}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _cancelOrder(orderId),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'HỦY ĐƠN',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptOrder(orderId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'NHẬN ĐƠN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyOrderCard(Map<String, dynamic> order) {
    final orderId = order['orderId'] ?? '';
    final address = order['deliveryAddress'] ?? '';
    final status = order['status'] ?? 'ASSIGNED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShipperOrderDetailPage(orderId: orderId),
            ),
          );
        },
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.navigation, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orderId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản shipper không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout(context);
              },
              child: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  void _logout(BuildContext context) {
    // Xóa thông tin user khỏi AuthProvider
    Provider.of<AuthProvider>(context, listen: false).clear();
    
    // Hủy timer polling
    _pollTimer?.cancel();
    
    // Chuyển về trang login
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
    
    // Hiển thị thông báo
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đăng xuất khỏi tài khoản shipper'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
