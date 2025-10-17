import 'package:flutter/material.dart';
import 'admin_api.dart';

class AdminReviewsDetailPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  const AdminReviewsDetailPage({Key? key, required this.restaurantId, required this.restaurantName}) : super(key: key);

  @override
  State<AdminReviewsDetailPage> createState() => _AdminReviewsDetailPageState();
}

class _AdminReviewsDetailPageState extends State<AdminReviewsDetailPage> {
  late final AdminApi _api;
  bool _loading = true;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _api = AdminApi.fromDefaults();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Fetch restaurants and extract reviews of selected one
      final restaurants = await _api.fetchRestaurants();
      final r = restaurants.firstWhere(
        (e) => ((e['_id'] ?? e['id']).toString()) == widget.restaurantId,
        orElse: () => {},
      );
      final List<dynamic> rev = (r['reviews'] as List?) ?? [];
      setState(() {
        _reviews = rev.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (_) {
      setState(() => _reviews = []);
    } finally {
      setState(() => _loading = false);
    }
  }

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
        title: Text('Đánh giá - ${widget.restaurantName}', style: const TextStyle(color: Colors.black)),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _reviews.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(child: Text('Chưa có đánh giá')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviews.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final r = _reviews[index];
                        final user = (r['user'] ?? r['username'] ?? 'Người dùng').toString();
                        final rating = ((r['rating'] ?? r['stars'] ?? 0) as num).toDouble();
                        final comment = (r['comment'] ?? r['content'] ?? '').toString();
                        final createdAt = (r['createdAt'] ?? r['date'] ?? '').toString();
                        return Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.person_outline, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(user, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        ),
                                        _Stars(rating: rating),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (comment.isNotEmpty) Text(comment),
                                    if (createdAt.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(createdAt, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    final int full = rating.floor();
    final bool half = (rating - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) return const Icon(Icons.star, size: 16, color: Colors.deepOrange);
        if (i == full && half) return const Icon(Icons.star_half, size: 16, color: Colors.deepOrange);
        return const Icon(Icons.star_border, size: 16, color: Colors.deepOrange);
      }),
    );
  }
}


