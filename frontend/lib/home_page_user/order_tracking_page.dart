import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';

class OrderTrackingPage extends StatefulWidget {
  final String orderId;
  const OrderTrackingPage({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
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
          'senderId': auth.userId ?? 'guest',
          'senderRole': 'USER',
          'content': content,
        }),
      );
      if (res.statusCode == 201) {
        _msgCtrl.clear();
        _loadMessages();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final status = order?['status']?.toString() ?? 'PENDING';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Theo dõi đơn hàng', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          if (status != 'DELIVERED' && status != 'CANCELLED')
            TextButton(
              onPressed: _cancelOrder,
              child: const Text('Hủy đơn', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusTimeline(status),
          const Divider(height: 1),
          Expanded(child: _buildChat()),
          Container(
            decoration: const BoxDecoration(color: Colors.white),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInput(),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _finishAndBackToShopping,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('ĐÃ NHẬN HÀNG THÀNH CÔNG'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder() async {
    try {
      final url = Uri.parse('$baseUrl/api/orders/${widget.orderId}/cancel');
      final res = await http.put(url);
      if (res.statusCode == 200) {
        await _loadOrder();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy đơn hàng'), backgroundColor: Colors.red),
        );
      }
    } catch (_) {}
  }

  void _finishAndBackToShopping() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildStatusTimeline(String status) {
    final steps = ['PENDING', 'ASSIGNED', 'PICKED_UP', 'DELIVERING', 'DELIVERED'];
    final currentIndex = steps.indexOf(status);
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: steps.map((s) {
          final idx = steps.indexOf(s);
          final done = currentIndex >= idx;
          return Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: done ? Colors.green : Colors.grey[300],
                ),
                const SizedBox(height: 6),
                Text(
                  s,
                  style: TextStyle(fontSize: 11, color: done ? Colors.green[700] : Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChat() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final role = m['senderRole']?.toString() ?? 'USER';
        final isMe = role == 'USER';
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
                  hintText: 'Nhắn tin với shipper...',
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


