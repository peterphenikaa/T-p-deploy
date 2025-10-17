import 'package:flutter/material.dart';
import 'admin_api.dart';
import 'dart:convert';
import 'admin_add_food_page.dart';
import 'admin_food_detail_page.dart';

class AdminFoodListPage extends StatefulWidget {
  const AdminFoodListPage({Key? key}) : super(key: key);

  @override
  State<AdminFoodListPage> createState() => _AdminFoodListPageState();
}

class _AdminFoodListPageState extends State<AdminFoodListPage>
    with SingleTickerProviderStateMixin {
  late final AdminApi _api;
  bool loading = true;
  List<Map<String, dynamic>> foods = [];
  List<String> categories = [];
  List<String> allCategories = [];
  String activeCategory = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _api = AdminApi.fromDefaults();
    _loadFoods(updateCategories: true);
  }

  Widget _fallbackBox() => Container(
        width: 72,
        height: 72,
        color: Colors.grey[300],
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood, color: Colors.orange),
      );

  Widget _base64Image(String dataUrl) {
    try {
      final b64 = dataUrl.split(',').last;
      return Image.memory(base64Decode(b64), width: 72, height: 72, fit: BoxFit.cover);
    } catch (_) {
      return _fallbackBox();
    }
  }

  Future<void> _loadFoods({String? category, bool updateCategories = false}) async {
    setState(() => loading = true);
    try {
      final data = await _api.fetchFoods(category: category);
      foods = data;
      if (updateCategories) {
        final setCats = <String>{};
        for (final f in data) {
          final c = (f['category'] ?? '').toString();
          if (c.isNotEmpty) setCats.add(c);
        }
        final sorted = setCats.toList()..sort();
        allCategories = ['Tất cả', ...sorted];
        categories = allCategories;
      } else {
        // Preserve full list of categories so chips never disappear
        if (allCategories.isNotEmpty) categories = allCategories;
      }
      setState(() {
        activeCategory = category == null || category.isEmpty ? 'Tất cả' : category;
      });
    } catch (_) {
      setState(() {
        foods = [];
        if (allCategories.isEmpty) {
          categories = ['Tất cả'];
          allCategories = categories;
        } else {
          categories = allCategories;
        }
        activeCategory = 'Tất cả';
      });
    } finally {
      setState(() => loading = false);
    }
  }

  String _normalizeImage(dynamic v) {
    final s = (v ?? '').toString();
    if (s.isEmpty) return 'assets/homepageUser/restaurant_img1.jpg';
    // Fix common casing issue from DB
    String path = s.replaceFirst('homepageuser/', 'homepageUser/');
    // If the backend gives http/base64, use it directly
    if (path.startsWith('http') || path.startsWith('data:')) return path;
    // Otherwise, use the path as-is (DB already stores asset paths like assets/homepageUser/..)
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Danh sách món ăn', style: TextStyle(color: Colors.black)),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: activeCategory.toLowerCase() == c.toLowerCase(),
                      onSelected: (_) => _loadFoods(category: c == 'Tất cả' ? null : c, updateCategories: false),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              activeCategory == 'Tất cả'
                  ? 'Tổng ${foods.length.toString().padLeft(2, '0')} món'
                  : 'Tổng ${foods.length.toString().padLeft(2, '0')} món - ${activeCategory}',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : foods.isEmpty
                    ? const Center(child: Text('Không có món ăn'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final f = foods[index];
                          final title = (f['name'] ?? '').toString();
                          final image = _normalizeImage(f['image']);
                          final price = (f['price'] ?? 0) as num;
                          final category = (f['category'] ?? '').toString();
                          final rating = (f['rating'] ?? 0).toString();
                          final reviews = (f['reviews'] is List) ? (f['reviews'] as List).length : 0;
                          return _FoodListTile(
                            image: image,
                            title: title,
                            subtitle: category.isNotEmpty ? category : 'Khác',
                            priceText: '₫$price',
                            ratingText: rating,
                            reviewCount: reviews,
                            trailingText: 'Mang đi',
                            onEdit: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AdminAddFoodPage(initial: f),
                                ),
                              );
                              _loadFoods(category: activeCategory == 'Tất cả' ? null : activeCategory);
                            },
                            onDelete: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Xóa món?'),
                                  content: Text('Bạn có chắc muốn xóa "$title"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                try {
                                  await _api.deleteFood((f['_id'] ?? f['id']).toString());
                                  _loadFoods(category: activeCategory == 'Tất cả' ? null : activeCategory);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa')));
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
                                }
                              }
                            },
                            onTap: () async {
                              final changed = await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => AdminFoodDetailPage(food: f)),
                              );
                              if (changed == true) {
                                _loadFoods(category: activeCategory == 'Tất cả' ? null : activeCategory);
                              }
                            },
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: foods.length,
                      ),
          )
        ],
      ),
      // bottomNavigationBar removed; use persistent one in AdminDashboardPage
    );
  }
}

class _FoodListTile extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;
  final String priceText;
  final String ratingText;
  final int reviewCount;
  final String trailingText;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const _FoodListTile({
    Key? key,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.priceText,
    required this.ratingText,
    required this.reviewCount,
    required this.trailingText,
    this.onEdit,
    this.onDelete,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (image.startsWith('http'))
                ? Image.network(image, width: 72, height: 72, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackBox())
                : (image.startsWith('data:'))
                    ? _base64Image(image)
                    : Image.asset(image, width: 72, height: 72, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackBox()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2E6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(subtitle, style: const TextStyle(color: Colors.deepOrange)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text(ratingText),
                    const SizedBox(width: 6),
                    Text('($reviewCount đánh giá)', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(priceText, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(trailingText, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit?.call();
                      if (v == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                      const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    ),
    );
  }

  Widget _fallbackBox() => Container(
        width: 72,
        height: 72,
        color: Colors.grey[300],
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood, color: Colors.orange),
      );

  Widget _base64Image(String dataUrl) {
    try {
      final b64 = dataUrl.split(',').last;
      return Image.memory(base64Decode(b64), width: 72, height: 72, fit: BoxFit.cover);
    } catch (_) {
      return _fallbackBox();
    }
  }
}


