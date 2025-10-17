import 'package:flutter/material.dart';
import 'dart:async';
import 'admin_api.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({Key? key}) : super(key: key);

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  late final AdminApi _api;
  bool loading = true;
  List<Map<String, dynamic>> items = [];
  // Removed auto-refresh timer per request

  @override
  void initState() {
    super.initState();
    _api = AdminApi.fromDefaults();
    _load();
  }

  @override
  void dispose() {
    // No periodic refresh to cancel
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await _api.fetchNotifications();
      setState(() => items = data);
    } catch (_) {
      setState(() => items = []);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Thông báo', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: Colors.orange)),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'clear_all') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Xóa tất cả thông báo?'),
                    content: const Text('Hành động này sẽ xóa toàn bộ thông báo.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
                    ],
                  ),
                );
                if (ok == true) {
                  try {
                    await _api.clearNotifications();
                    _load();
                  } catch (_) {}
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'clear_all', child: Text('Xóa tất cả')),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final n = items[index];
              final id = (n['_id'] ?? n['id'] ?? '').toString();
                final status = (n['status'] ?? '').toString();
                final orderId = (n['orderId'] ?? '').toString();
                final msg = (n['message'] ?? '').toString();
                final created = (n['createdAt'] ?? '').toString();
              return Dismissible(
                key: ValueKey(id.isEmpty ? '$index-$created' : id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Xóa thông báo?'),
                      content: const Text('Bạn có chắc muốn xóa thông báo này?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
                      ],
                    ),
                  );
                  return ok == true;
                },
                onDismissed: (_) async {
                  try {
                    if (id.isNotEmpty) {
                      await _api.deleteNotification(id);
                    }
                  } catch (_) {}
                  items.removeAt(index);
                  setState(() {});
                },
                child: _NotificationTile(
                  title: 'Đơn $orderId',
                  subtitle: msg,
                  time: created,
                  status: status,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        try {
                          if (id.isNotEmpty) await _api.deleteNotification(id);
                          items.removeAt(index);
                          setState(() {});
                        } catch (_) {}
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'delete', child: Text('Xóa')),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                ),
              );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: items.length,
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final String status;
  final Widget? trailing;

  const _NotificationTile({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.status,
    this.trailing,
  }) : super(key: key);

  Color _statusColor() {
    // Admin chỉ quan tâm 2 trạng thái chính:
    // - PENDING: yêu cầu mới chờ chấp nhận
    // - Khác (ASSIGNED/DELIVERING/DELIVERED/CANCELLED...): đang/đã xử lý
    final s = status.toUpperCase();
    if (s == 'PENDING') return Colors.orange; // Yêu cầu mới
    return Colors.blue; // Nhóm còn lại hiển thị chung
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: _statusColor().withOpacity(0.15), child: Icon(Icons.notifications, color: _statusColor())),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700])),
            ]),
          ),
          const SizedBox(width: 8),
          Text(time.split('T').first, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ]
        ],
      ),
    );
  }
}


