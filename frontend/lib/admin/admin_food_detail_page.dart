import 'package:flutter/material.dart';
import 'admin_api.dart';
import 'dart:convert';
import 'admin_add_food_page.dart';

class AdminFoodDetailPage extends StatefulWidget {
  final Map<String, dynamic> food;
  const AdminFoodDetailPage({Key? key, required this.food}) : super(key: key);

  @override
  State<AdminFoodDetailPage> createState() => _AdminFoodDetailPageState();
}

class _AdminFoodDetailPageState extends State<AdminFoodDetailPage> {
  late Map<String, dynamic> food;

  @override
  void initState() {
    super.initState();
    food = Map<String, dynamic>.from(widget.food);
    _ensureFullFood();
  }

  Future<void> _ensureFullFood() async {
    try {
      final id = (food['_id'] ?? food['id']).toString();
      final missing = !(food['ingredients'] is List) || (food['description'] == null);
      if (id.isNotEmpty && missing) {
        final list = await AdminApi.fromDefaults().fetchFoods();
        final fresh = list.firstWhere(
          (e) => ((e['_id'] ?? e['id']).toString()) == id,
          orElse: () => food,
        );
        setState(() => food = fresh);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    String _normalizeImage(dynamic v) {
      final s = (v ?? '').toString();
      if (s.isEmpty) return 'assets/homepageUser/restaurant_img1.jpg';
      String path = s.replaceFirst('homepageuser/', 'homepageUser/');
      if (path.startsWith('http') || path.startsWith('data:')) return path;
      // Use DB path as-is for assets (already includes 'assets/...')
      return path;
    }
    final image = _normalizeImage(food['image']);
    final name = (food['name'] ?? '').toString();
    final price = (food['price'] ?? 0) as num;
    final ingredients = (food['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final rating = (food['rating'] ?? 0).toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Food Details', style: TextStyle(color: Colors.black)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                final updated = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AdminAddFoodPage(initial: food)),
                );
                // nếu quay lại có cập nhật, giữ lại trang và refresh dữ liệu hiển thị
                if (updated == true) {
                  // Re-fetch single food to get latest
                  try {
                    final id = (food['_id'] ?? food['id']).toString();
                    final list = await AdminApi.fromDefaults().fetchFoods();
                    final fresh = list.firstWhere((e) => ((e['_id'] ?? e['id']).toString()) == id, orElse: () => food);
                    setState(() => food = fresh);
                  } catch (_) {}
                }
              }
              if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Xóa món?'),
                    content: Text('Bạn có chắc muốn xóa "$name"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
                    ],
                  ),
                );
                if (ok == true) {
                  try {
                    await AdminApi.fromDefaults().deleteFood((food['_id'] ?? food['id']).toString());
                    Navigator.of(context).pop(true);
                  } catch (_) {}
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Sửa')),
              PopupMenuItem(value: 'delete', child: Text('Xóa')),
            ],
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: image.startsWith('http')
                ? Image.network(
                    image,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackBox(),
                  )
                : image.startsWith('data:')
                    ? _base64Image(image)
                    : Image.asset(
                        image,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackBox(),
                      ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              ),
              Text('₫$price', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.star, color: Colors.orange, size: 18),
            const SizedBox(width: 4),
            Text(rating),
          ]),
          const SizedBox(height: 16),
          const Text('INGREDIENTS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (ingredients.isEmpty)
            const Text('Chưa có nguyên liệu', style: TextStyle(color: Colors.grey))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ingredients.map((ing) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFFFF2E6), borderRadius: BorderRadius.circular(20)),
                child: Text(ing, style: const TextStyle(color: Colors.deepOrange)),
              )).toList(),
            ),
          const SizedBox(height: 16),
          const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text((food['description'] ?? 'Không có mô tả').toString(), style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }
  Widget _fallbackBox() => Container(
        height: 220,
        color: Colors.grey[300],
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
  Widget _base64Image(String dataUrl) {
    try {
      final b64 = dataUrl.split(',').last;
      return Image.memory(base64Decode(b64), height: 220, fit: BoxFit.cover);
    } catch (_) {
      return _fallbackBox();
    }
  }
}


