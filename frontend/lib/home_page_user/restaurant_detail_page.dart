import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'cart_provider.dart';
import 'cart_item.dart';
import 'product_detail_page.dart';

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

class _RestaurantReviewForm extends StatefulWidget {
  final Future<void> Function(int, String) onSubmit;
  const _RestaurantReviewForm({Key? key, required this.onSubmit})
    : super(key: key);

  @override
  State<_RestaurantReviewForm> createState() => _RestaurantReviewFormState();
}

class _RestaurantReviewFormState extends State<_RestaurantReviewForm> {
  double _rating = 5;
  final TextEditingController _controller = TextEditingController();
  bool sending = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
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
              decoration: const InputDecoration(hintText: "Nhận xét..."),
            ),
            const SizedBox(height: 6),
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
                  child: const Text('Gửi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantDetailPage extends StatefulWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantDetailPage({Key? key, required this.restaurant})
    : super(key: key);

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  String selectedCategory = 'All';
  List<Map<String, dynamic>> foods = [];
  bool isLoading = true;
  // Reviews state
  List<Review> reviews = [];
  bool reviewsLoading = false;
  int selectedReviewFilter = 0;

  final List<String> categories = [
    'All',
    'Burger',
    'Pizza',
    'Sandwich',
    'Salad',
    'Drinks',
  ];

  @override
  void initState() {
    super.initState();
    _loadFoods();
    fetchReviews();
  }

  Future<void> fetchReviews() async {
    setState(() => reviewsLoading = true);
    final rawId = widget.restaurant['_id'] ?? widget.restaurant['id'];
    final String restId = rawId is Map
        ? (rawId['_id'] ?? rawId['\$oid'] ?? rawId.toString())
        : (rawId?.toString() ?? '');
    final String baseUrl = kIsWeb
        ? 'http://localhost:3000'
        : (defaultTargetPlatform == TargetPlatform.android
              ? 'http://10.0.2.2:3000'
              : 'http://localhost:3000');
    final url = Uri.parse('$baseUrl/api/restaurants/$restId/reviews');
    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final List data = json.decode(resp.body);
        setState(() {
          reviews = data.map((e) => Review.fromJson(e)).toList();
        });
      }
    } catch (_) {}
    setState(() => reviewsLoading = false);
  }

  Future<void> postReview(int rating, String comment) async {
    final rawId = widget.restaurant['_id'] ?? widget.restaurant['id'];
    final String restId = rawId is Map
        ? (rawId['_id'] ?? rawId['\$oid'] ?? rawId.toString())
        : (rawId?.toString() ?? '');
    final String baseUrl = kIsWeb
        ? 'http://localhost:3000'
        : (defaultTargetPlatform == TargetPlatform.android
              ? 'http://10.0.2.2:3000'
              : 'http://localhost:3000');
    final url = Uri.parse('$baseUrl/api/restaurants/$restId/reviews');
    final review = Review(user: 'Bạn', rating: rating, comment: comment);
    try {
      final resp = await http.post(
        url,
        body: json.encode(review.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        setState(() => reviews.insert(0, review));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đánh giá đã được ghi nhận!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gửi đánh giá thất bại (${resp.statusCode})')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể kết nối để gửi đánh giá.')),
      );
    }
  }

  Future<void> _loadFoods() async {
    setState(() {
      isLoading = true;
    });

    try {
      final baseUrl = 'http://localhost:3000';
      final url = Uri.parse('$baseUrl/api/foods');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          foods = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        setState(() {
          foods = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        foods = [];
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredFoods {
    if (selectedCategory == 'All') {
      return foods;
    }
    return foods.where((food) => food['category'] == selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.white,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.black,
                  size: 18,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Restaurant Image
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xff2E7D32), Color(0xff4CAF50)],
                      ),
                    ),
                    child: widget.restaurant['image'] != null
                        ? Image.asset(
                            '${widget.restaurant['image']}',
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.restaurant,
                            size: 100,
                            color: Colors.white,
                          ),
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                  // Page indicators
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Restaurant Info
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating, Delivery, Time
                  Row(
                    children: [
                      const Icon(Icons.star, size: 18, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text('${widget.restaurant['rating'] ?? 4.7}'),
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
                      Text('${widget.restaurant['deliveryTime'] ?? 20} min'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Restaurant Name
                  Text(
                    widget.restaurant['name'] ?? 'Restaurant',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    widget.restaurant['description'] ??
                        'Maecenas sed diam eget risus varius blandit sit amet non magna. Integer posuere erat a ante venenatis dapibus posuere velit aliquet.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Category Filters
          SliverToBoxAdapter(
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = selectedCategory == category;

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedCategory = category;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.orange : Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isSelected
                                ? Colors.orange
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Food Items
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$selectedCategory (${filteredFoods.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (filteredFoods.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không có món ăn nào',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: filteredFoods.length,
                      itemBuilder: (context, index) {
                        final food = filteredFoods[index];
                        return _FoodCard(
                          food: food,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProductDetailPage(product: food),
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          // Reviews Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'ĐÁNH GIÁ NGƯỜI DÙNG',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _RestaurantReviewForm(onSubmit: postReview),

                  // Filter chips
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
                            padding: const EdgeInsets.only(right: 6, bottom: 8),
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

                  const SizedBox(height: 8),
                  if (reviewsLoading)
                    const Center(child: CircularProgressIndicator())
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
                            'Chưa có đánh giá.',
                            style: TextStyle(color: Colors.grey),
                          );
                        return Column(
                          children: filtered
                              .map(
                                (rv) => ListTile(
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: AssetImage('homepageUser/user_icon.jpg'),
                                  ),
                                  title: Row(
                                    children: [
                                      ...List.generate(
                                        rv.rating,
                                        (i) => const Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.orange,
                                        ),
                                      ),
                                      ...List.generate(
                                        5 - rv.rating,
                                        (i) => const Icon(
                                          Icons.star_border,
                                          size: 16,
                                          color: Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        rv.user,
                                        style: const TextStyle(
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  final Map<String, dynamic> food;
  final VoidCallback onTap;

  const _FoodCard({Key? key, required this.food, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  color: Color(0xffffe1c2),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: food['image'] != null
                      ? Image.asset(
                          '${food['image']}',
                          fit: BoxFit.cover,
                        )
                      : const Icon(
                          Icons.fastfood,
                          size: 40,
                          color: Colors.orange,
                        ),
                ),
              ),
            ),

            // Food Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      food['restaurant'] ?? 'Restaurant',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₫${food['price'] ?? 0}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.orange,
                          ),
                        ),
                        Consumer<CartProvider>(
                          builder: (context, cartProvider, child) {
                            final isInCart = cartProvider.isItemInCart(
                              food['_id'] ??
                                  food['id'] ??
                                  DateTime.now().millisecondsSinceEpoch
                                      .toString(),
                              'M',
                            );
                            return GestureDetector(
                              onTap: () {
                                if (!isInCart) {
                                  final cartItem = CartItem(
                                    id:
                                        food['_id'] ??
                                        food['id'] ??
                                        DateTime.now().millisecondsSinceEpoch
                                            .toString(),
                                    name: food['name'] ?? '',
                                    image: food['image'],
                                    basePrice: (food['price'] ?? 0) as int,
                                    size: 'M',
                                    quantity: 1,
                                    restaurant:
                                        food['restaurant'] ?? 'Restaurant',
                                    category: food['category'] ?? '',
                                    description: food['description'],
                                  );
                                  cartProvider.addItem(cartItem);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Đã thêm ${food['name']} vào giỏ hàng',
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isInCart
                                      ? Colors.green
                                      : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isInCart ? Icons.check : Icons.add,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
