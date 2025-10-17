import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';

class ShipperOrderDetailPage extends StatefulWidget {
  final String orderId;
  const ShipperOrderDetailPage({Key? key, required this.orderId}) : super(key: key);

  @override
  State<ShipperOrderDetailPage> createState() => _ShipperOrderDetailPageState();
}

class _ShipperOrderDetailPageState extends State<ShipperOrderDetailPage> {
  Map<String, dynamic>? order;
  List<Map<String, dynamic>> messages = [];
  final TextEditingController _msgCtrl = TextEditingController();
  Timer? _pollTimer;
  DateTime? _lastMessageAt;

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    return defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
  }

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadOrder();
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final url = Uri.parse('$baseUrl/api/orders/${widget.orderId}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        setState(() {
          order = json.decode(res.body) as Map<String, dynamic>;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final since = _lastMessageAt?.toUtc().toIso8601String();
      final url = Uri.parse('$baseUrl/api/orders/${widget.orderId}/messages${since != null ? '?since=$since' : ''}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (data.isNotEmpty) {
          final list = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          setState(() {
            messages.addAll(list);
            _lastMessageAt = DateTime.tryParse(list.last['createdAt']?.toString() ?? '') ?? _lastMessageAt;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final content = _msgCtrl.text.trim();
    if (content.isEmpty) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final url = Uri.parse('$baseUrl/api/orders/${widget.orderId}/messages');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderId': auth.userId ?? 'shipper',
          'senderRole': 'SHIPPER',
          'content': content,
        }),
      );
      if (res.statusCode == 201) {
        _msgCtrl.clear();
        _loadMessages();
      }
    } catch (_) {}
  }

  Future<void> _updateStatus(String status) async {
    try {
      final url = Uri.parse('$baseUrl/api/orders/${widget.orderId}/status');
      final res = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );
      if (res.statusCode == 200) {
        _loadOrder();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = order?['status']?.toString() ?? 'ASSIGNED';
    final name = order?['userName']?.toString() ?? '';
    final phone = order?['userPhone']?.toString() ?? '';
    final addr = order?['deliveryAddress']?.toString() ?? '';
    final items = (order?['items'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Chi tiết đơn', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (s != 'DELIVERED' && s != 'CANCELLED')
            TextButton(
              onPressed: _cancelOrder,
              child: const Text('Hủy đơn', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(name),
            subtitle: Text(phone),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(addr),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(color: Color(0xFFF8F9FA)),
            child: Wrap(
              spacing: 8,
              children: [
                _statusBtn('ASSIGNED', s == 'ASSIGNED'),
                _statusBtn('PICKED_UP', s == 'PICKED_UP'),
                _statusBtn('DELIVERING', s == 'DELIVERING'),
                _statusBtn('DELIVERED', s == 'DELIVERED'),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('Món:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...items.map((e) => Text('- ${e['name']} x ${e['quantity']}')).toList(),
                const Divider(),
                const Text('Chat với khách', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
          Container(
            height: 280,
            decoration: const BoxDecoration(color: Colors.white),
            child: Column(
              children: [
                Expanded(child: _buildChat()),
                _buildInput(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _cancelOrder() async {
    try {
      final url = Uri.parse('$baseUrl/api/orders/${widget.orderId}/cancel');
      final res = await http.put(url);
      if (res.statusCode == 200) {
        _loadOrder();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy đơn'), backgroundColor: Colors.red),
        );
      }
    } catch (_) {}
  }

  Widget _statusBtn(String status, bool active) {
    return OutlinedButton(
      onPressed: () => _updateStatus(status),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? Colors.orange[50] : null,
      ),
      child: Text(status),
    );
  }

  Widget _buildChat() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final role = m['senderRole']?.toString() ?? 'USER';
        final isMe = role == 'SHIPPER';
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe ? Colors.orange[100] : Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(m['content']?.toString() ?? ''),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _msgCtrl,
                decoration: const InputDecoration(
                  hintText: 'Nhắn tin với khách...',
                  filled: true,
                  fillColor: Color(0xFFF3F7FB),
                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _sendMessage,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}












