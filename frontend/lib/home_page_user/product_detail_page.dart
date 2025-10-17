import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'cart_item.dart';
import 'cart_provider.dart';
import 'cart_page.dart';
import 'recently_viewed_widget.dart';
import 'recent_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:food_delivery_app/config/env.dart';

class Review {
  final String user;
  final int rating;
  final String comment;

  Review({required this.user, required this.rating, required this.comment});

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      user: json['user'],
      rating: json['rating'],
      comment: json['comment'],
    );
  }

  Map<String, dynamic> toJson() => {
    "user": user,
    "rating": rating,
    "comment": comment,
  };
}

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailPage({Key? key, required this.product}) : super(key: key);

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int quantity = 1;
  String selectedSize = 'M';
  final List<String> availableSizes = ['S', 'M', 'L'];
  final Map<String, String> sizeLabels = {'S': '10"', 'M': '14"', 'L': '16"'};

  List<Review> reviews = [];
  bool reviewsLoading = false;
  int selectedReviewFilter = 0; // 0 = all, 1-5 = stars

  String userNote = '';
  final TextEditingController noteController = TextEditingController();

  // Restaurant info
  Map<String, dynamic>? restaurantInfo;
  bool restaurantLoading = false;

  int get currentPrice {
    int base = (widget.product['price'] ?? 0) as int;
    switch (selectedSize) {
      case 'S':
        return base;
      case 'M':
        return (base * 1.3).round();
      case 'L':
        return (base * 1.6).round();
      default:
        return base;
    }
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final recentProvider = Provider.of<RecentProvider>(
          context,
          listen: false,
        );
        recentProvider.addRecent(widget.product);
        print('[ProductDetail] Added to recent: ${widget.product['name']}');
      } catch (e) {
        print('[ProductDetail] Error adding to recent: $e');
      }
    });
    fetchReviews();
    fetchRestaurantInfo();
  }

  Future<void> fetchReviews() async {
    setState(() => reviewsLoading = true);
    final rawId = widget.product['_id'] ?? widget.product['id'];
    final String productId = rawId is Map
        ? (rawId['_id'] ?? rawId['\$oid'] ?? rawId.toString())
        : (rawId?.toString() ?? '');
    final url = Uri.parse('$API_BASE_URL/api/foods/$productId/reviews');
    try {
      print('[fetchReviews] GET $url');
      final resp = await http.get(url);
      print('[fetchReviews] status=${resp.statusCode} body=${resp.body}');
      if (resp.statusCode == 200) {
        final List data = json.decode(resp.body);
        setState(() {
          reviews = data.map((e) => Review.fromJson(e)).toList();
        });
      }
    } catch (_) {}
    setState(() => reviewsLoading = false);
  }

  Future<void> fetchRestaurantInfo() async {
    setState(() => restaurantLoading = true);

    try {
      // First get the food details to get restaurantId
      final rawId = widget.product['_id'] ?? widget.product['id'];
      final String productId = rawId is Map
          ? (rawId['_id'] ?? rawId['\$oid'] ?? rawId.toString())
          : (rawId?.toString() ?? '');

      print('[fetchRestaurantInfo] Product ID: $productId');
      print('[fetchRestaurantInfo] Raw product data: ${widget.product}');

      final foodUrl = Uri.parse('$API_BASE_URL/api/foods/$productId');
      print('[fetchRestaurantInfo] Food URL: $foodUrl');
      final foodResp = await http
          .get(foodUrl)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Food API timeout');
            },
          );

      print(
        '[fetchRestaurantInfo] Food response status: ${foodResp.statusCode}',
      );
      print('[fetchRestaurantInfo] Food response body: ${foodResp.body}');

      if (foodResp.statusCode == 200) {
        final foodData = json.decode(foodResp.body);
        final restaurantId = foodData['restaurantId'];
        print('[fetchRestaurantInfo] Restaurant ID: $restaurantId');

        if (restaurantId != null) {
          // Get restaurant details
          final restaurantUrl = Uri.parse(
            '$API_BASE_URL/api/restaurants/$restaurantId',
          );
          print('[fetchRestaurantInfo] Restaurant URL: $restaurantUrl');
          final restaurantResp = await http
              .get(restaurantUrl)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw Exception('Restaurant API timeout');
                },
              );

          print(
            '[fetchRestaurantInfo] Restaurant response status: ${restaurantResp.statusCode}',
          );
          print(
            '[fetchRestaurantInfo] Restaurant response body: ${restaurantResp.body}',
          );

          if (restaurantResp.statusCode == 200) {
            final restaurantData = json.decode(restaurantResp.body);
            print('[fetchRestaurantInfo] Restaurant data: $restaurantData');
            setState(() {
              restaurantInfo = restaurantData;
            });
          } else {
            print(
              '[fetchRestaurantInfo] Failed to get restaurant: ${restaurantResp.statusCode}',
            );
          }
        } else {
          print('[fetchRestaurantInfo] No restaurantId found in food data');
        }
      } else {
        print(
          '[fetchRestaurantInfo] Failed to get food: ${foodResp.statusCode}',
        );
      }
    } catch (e) {
      print('[fetchRestaurantInfo] Error: $e');
    }

    setState(() => restaurantLoading = false);
  }

  Future<void> postReview(int rating, String comment) async {
    final rawId = widget.product['_id'] ?? widget.product['id'];
    final String productId = rawId is Map
        ? (rawId['_id'] ?? rawId['\$oid'] ?? rawId.toString())
        : (rawId?.toString() ?? '');
    final url = Uri.parse('$API_BASE_URL/api/foods/$productId/reviews');
    final review = Review(user: "Bạn", rating: rating, comment: comment);
    try {
      print('[postReview] POST $url body=${json.encode(review.toJson())}');
      final resp = await http.post(
        url,
        body: json.encode(review.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
      print('[postReview] status=${resp.statusCode} body=${resp.body}');
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        setState(() {
          reviews.insert(0, review);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đánh giá đã được ghi nhận!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gửi đánh giá thất bại (${resp.statusCode})')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể kết nối để gửi đánh giá. Vui lòng thử lại.'),
        ),
      );
    }
  }

  void _addToCart() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final item = widget.product;

    final cartItem = CartItem(
      id: item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      foodId: item['_id'] ?? item['id'], // Use MongoDB _id as foodId
      name: item['name'] ?? '',
      image: item['image'],
      basePrice: (item['price'] ?? 0) as int,
      size: selectedSize,
      quantity: quantity,
      restaurant: restaurantInfo?['name'] ?? 'Unknown Restaurant',
      category: item['category'] ?? '',
      description: item['description'],
      userNote: userNote,
    );

    cartProvider.addItem(cartItem);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã thêm $quantity ${item['name']} (${sizeLabels[selectedSize]}) vào giỏ hàng',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Xem giỏ hàng',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartPage()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.product;
    final String name = item['name'] ?? '';
    final String description =
        item['description'] ?? 'Món ăn ngon được chế biến tươi mỗi ngày.';
    final int deliveryTime = (item['deliveryTime'] ?? 20) as int;
    final double rating = (item['rating'] ?? 4.7).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xfff6f7fb),
      body: SafeArea(
        child: Column(
          children: [
            // Header with image
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Chi tiết sản phẩm',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  const Spacer(),
                  Consumer<CartProvider>(
                    builder: (context, cartProvider, child) {
                      return Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            child: IconButton(
                              icon: const Icon(Icons.shopping_cart),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CartPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (cartProvider.itemCount > 0)
                            Positioned(
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  cartProvider.itemCount.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 190,
                  color: const Color(0xffffe1c2),
                  alignment: Alignment.center,
                  child: item['image'] != null
                      ? Image.asset(
                          '${item['image']}',
                          fit: BoxFit.contain,
                          height: 150,
                        )
                      : const Icon(
                          Icons.local_pizza,
                          size: 96,
                          color: Colors.orange,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.redAccent,
                          ),
                          SizedBox(width: 8),
                          if (restaurantLoading)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Text(
                              restaurantInfo?['name'] ?? 'Restaurant',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 18, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1)),
                        const SizedBox(width: 18),
                        const Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        const Text('Free'),
                        const SizedBox(width: 18),
                        const Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 4),
                        Text('$deliveryTime min'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Text(
                          'SIZE',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₫${currentPrice.toString()}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: availableSizes.map((size) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _SizeChip(
                            label: sizeLabels[size]!,
                            selected: selectedSize == size,
                            onTap: () => setState(() => selectedSize = size),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'INGREDIENTS',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final List<dynamic> raw =
                            (item['ingredients'] as List?) ?? const [];
                        final List<String> ingredients = raw
                            .map((e) => e.toString())
                            .toList();
                        if (ingredients.isEmpty) {
                          return const Text(
                            'Chưa có nguyên liệu',
                            style: TextStyle(color: Colors.grey),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ingredients
                              .map(
                                (ing) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF2E6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    ing,
                                    style: const TextStyle(
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ghi chú cho nhà hàng',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: noteController,
                            onChanged: (value) =>
                                setState(() => userNote = value),
                            minLines: 1,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText:
                                  'Nhập ghi chú (ví dụ: không hành, ít cay...)',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.orange,
                                  width: 1,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Recently viewed (moved above reviews)
                    const RecentlyViewedWidget(),

                    // REVIEW SECTION
                    Text(
                      'ĐÁNH GIÁ NGƯỜI DÙNG',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    _ReviewForm(onSubmit: postReview),

                    // Review filter chips
                    if (!reviewsLoading)
                      Builder(
                        builder: (context) {
                          final counts = <int, int>{};
                          for (var r in reviews) {
                            counts[r.rating] = (counts[r.rating] ?? 0) + 1;
                          }
                          int total = reviews.length;
                          List<Widget> chips = [];
                          chips.add(
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 6,
                                bottom: 8,
                              ),
                              child: ChoiceChip(
                                label: Text('Tất cả ($total)'),
                                selected: selectedReviewFilter == 0,
                                onSelected: (_) =>
                                    setState(() => selectedReviewFilter = 0),
                              ),
                            ),
                          );
                          for (int s = 5; s >= 1; s--) {
                            chips.add(
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 6,
                                  bottom: 8,
                                ),
                                child: ChoiceChip(
                                  label: Text('$s ⭐ (${counts[s] ?? 0})'),
                                  selected: selectedReviewFilter == s,
                                  onSelected: (_) =>
                                      setState(() => selectedReviewFilter = s),
                                ),
                              ),
                            );
                          }
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: chips),
                          );
                        },
                      ),

                    if (reviewsLoading)
                      Center(child: CircularProgressIndicator())
                    else
                      Builder(
                        builder: (context) {
                          final filtered = selectedReviewFilter == 0
                              ? reviews
                              : reviews
                                    .where(
                                      (r) => r.rating == selectedReviewFilter,
                                    )
                                    .toList();
                          if (filtered.isEmpty)
                            return Text(
                              "Chưa có đánh giá.",
                              style: TextStyle(color: Colors.grey),
                            );
                          return Column(
                            children: filtered
                                .map(
                                  (rv) => ListTile(
                                    leading: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: AssetImage(
                                        'homepageUser/user_icon.jpg',
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        ...List.generate(
                                          rv.rating,
                                          (i) => Icon(
                                            Icons.star,
                                            size: 16,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        ...List.generate(
                                          5 - rv.rating,
                                          (i) => Icon(
                                            Icons.star_border,
                                            size: 16,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          rv.user,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(rv.comment),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              '₫${currentPrice.toString()}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(26),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: () => setState(
                      () => quantity = quantity > 1 ? quantity - 1 : 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    quantity.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _QtyButton(
                    icon: Icons.add,
                    onTap: () => setState(() => quantity = quantity + 1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                final isInCart = cartProvider.isItemInCart(
                  item['id'] ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  selectedSize,
                );
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isInCart ? Colors.green : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  onPressed: _addToCart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isInCart) ...[
                        const Icon(Icons.check, size: 18, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(isInCart ? 'Đã thêm' : 'Thêm vào giỏ'),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewForm extends StatefulWidget {
  final Future<void> Function(int, String) onSubmit;
  const _ReviewForm({Key? key, required this.onSubmit}) : super(key: key);

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  double _rating = 5;
  final TextEditingController _controller = TextEditingController();
  bool sending = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 14),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Thêm đánh giá của bạn:",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Row(
              children: List.generate(
                5,
                (i) => IconButton(
                  icon: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: Colors.orange,
                  ),
                  onPressed: () => setState(() => _rating = i + 1.0),
                ),
              ),
            ),
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(hintText: "Nhận xét..."),
            ),
            SizedBox(height: 6),
            Row(
              children: [
                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          setState(() => sending = true);
                          try {
                            await widget.onSubmit(
                              _rating.toInt(),
                              _controller.text,
                            );
                            setState(() {
                              _controller.clear();
                              _rating = 5;
                            });
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Gửi đánh giá gặp lỗi. Vui lòng thử lại.',
                                ),
                              ),
                            );
                          } finally {
                            setState(() => sending = false);
                          }
                        },
                  child: Text("Gửi"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SizeChip({
    Key? key,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? Colors.orange : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _IngredientIcon extends StatelessWidget {
  final IconData icon;
  const _IngredientIcon({Key? key, required this.icon}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xfffff2ea),
      child: Icon(icon, color: Colors.orange),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({Key? key, required this.icon, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
