import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:food_delivery_app/config/env.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'cart_provider.dart';
import 'cart_item.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'restaurant_detail_page.dart';

class SearchPage extends StatefulWidget {
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  List<String> recentKeywords = [];
  List<Map<String, dynamic>> currentResults = [];

  Future<void> _searchFoods(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        currentResults = [];
      });
      return;
    }

    try {
      final url = Uri.parse(
        '$API_BASE_URL/api/foods?search=${Uri.encodeQueryComponent(query.trim())}',
      );

      print('Searching for: $query');
      print('URL: $url');

      final response = await http.get(url);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentResults = List<Map<String, dynamic>>.from(data);
        });
        print('Found ${currentResults.length} results');
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        setState(() {
          currentResults = [];
        });
      }
    } catch (e) {
      print('Search error: $e');
      setState(() {
        currentResults = [];
      });
    }
  }

  void _onSearchSubmitted(String query) {
    if (query.isEmpty) return;
    setState(() {
      _searchText = query;
      recentKeywords.remove(query);
      recentKeywords.insert(0, query);
      if (recentKeywords.length > 10) {
        recentKeywords = recentKeywords.sublist(0, 10);
      }
    });
    _searchFoods(query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> suggestedRestaurants = [
    {
      "name": "The Pizza Place",
      "image": "homepageUser/pizza_place.jpg",
      "rating": 4.8,
    },
    {
      "name": "Burger Heaven",
      "image": "homepageUser/burger_heaven.webp",
      "rating": 4.5,
    },
    {
      "name": "Sushi World",
      "image": "homepageUser/sushi_word.jpg",
      "rating": 4.9,
    },
  ];
  final List<Map<String, dynamic>> popularFoods = [
    {
      "image": "homepageUser/european_pizza.jpg",
      "name": "European Pizza",
      "restaurant": "European Pizza",
    },
    {
      "image": "homepageUser/buffano_pizza.jpg",
      "name": "Buffano Pizza",
      "restaurant": "Buffano Pizza",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Text(
                    "Tìm kiếm",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                  ),
                  Spacer(),
                  Consumer<CartProvider>(
                    builder: (context, cartProvider, child) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CartPage(),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.shopping_cart,
                                color: Colors.black,
                              ),
                            ),
                            if (cartProvider.itemCount > 0)
                              Positioned(
                                top: 5,
                                right: 4,
                                child: Container(
                                  padding: EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    cartProvider.itemCount.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _onSearchSubmitted,
                  onChanged: (value) {
                    // Tìm kiếm real-time khi người dùng gõ
                    if (value.trim().isNotEmpty) {
                      _searchFoods(value);
                    } else {
                      setState(() {
                        _searchText = '';
                        currentResults = [];
                      });
                    }
                  },
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "Nhập từ khóa tìm kiếm",
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchText = '';
                                currentResults = [];
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: 18),
              _searchText.isEmpty
                  ? Expanded(
                      child: ListView(
                        children: [
                          Text(
                            "Recent Keywords",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 9),
                          Wrap(
                            spacing: 10,
                            children: recentKeywords.isEmpty
                                ? [Text("Chưa có từ khóa tìm gần đây")]
                                : recentKeywords
                                      .map(
                                        (key) => ActionChip(
                                          label: Text(key),
                                          onPressed: () {
                                            _searchController.text = key;
                                            _onSearchSubmitted(key);
                                          },
                                        ),
                                      )
                                      .toList(),
                          ),
                          SizedBox(height: 20),
                          Text(
                            "Suggested Restaurants",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 7),
                          ...suggestedRestaurants.map(
                            (res) => ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RestaurantDetailPage(
                                      restaurant: {
                                        'name': res['name'],
                                        'image': res['image'],
                                        'rating': res['rating'],
                                        'deliveryTime': 20,
                                        'description':
                                            'Nhà hàng ${res['name']} với hương vị đặc biệt và chất lượng cao. Chúng tôi cam kết mang đến những món ăn tươi ngon nhất cho khách hàng.',
                                      },
                                    ),
                                  ),
                                );
                              },
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.asset(
                                  res['image'],
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              title: Text(
                                res['name'],
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    res['rating'].toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 2,
                                horizontal: 0,
                              ),
                              dense: true,
                            ),
                          ),
                          SizedBox(height: 13),
                          Text(
                            "Popular Fast Food",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 8),
                          SizedBox(
                            height: 75,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: popularFoods
                                  .map(
                                    (food) => GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ProductDetailPage(
                                              product: {
                                                'name': food['name'],
                                                'image': food['image'],
                                                'price': 40000, // Default price
                                                'rating': 4.5,
                                                'category': 'Fast Food',
                                                'description':
                                                    'Món ăn phổ biến từ ${food['restaurant']}',
                                                'restaurant':
                                                    food['restaurant'],
                                                'deliveryTime': 20,
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.only(right: 16),
                                        child: SizedBox(
                                          width: 70,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                                child: Image.asset(
                                                  food['image'],
                                                  width: 45,
                                                  height: 45,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                food['name'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                              Text(
                                                food['restaurant'],
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey[700],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Expanded(
                      child: currentResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Không tìm thấy kết quả",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Thử tìm kiếm với từ khóa khác",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchText = '';
                                        currentResults = [];
                                      });
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Tìm lại'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: currentResults.length,
                              itemBuilder: (context, index) {
                                final item = currentResults[index];
                                return Card(
                                  margin: EdgeInsets.symmetric(vertical: 4),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ProductDetailPage(product: item),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: ListTile(
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 50,
                                          height: 50,
                                          color: Color(0xffffe1c2),
                                          child: item['image'] != null
                                              ? Image.asset(
                                                  '${item['image']}',
                                                  fit: BoxFit.cover,
                                                )
                                              : Icon(
                                                  Icons.fastfood,
                                                  color: Colors.orange,
                                                ),
                                        ),
                                      ),
                                      title: Text(
                                        item['name'] ?? 'Unknown',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item['category'] ?? ''),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.star,
                                                size: 16,
                                                color: Colors.orange,
                                              ),
                                              SizedBox(width: 4),
                                              Text('${item['rating'] ?? 0.0}'),
                                              Spacer(),
                                              Text(
                                                '₫${item['price'] ?? 0}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: Consumer<CartProvider>(
                                        builder: (context, cartProvider, child) {
                                          final isInCart = cartProvider
                                              .isItemInCart(
                                                item['_id'] ??
                                                    item['id'] ??
                                                    DateTime.now()
                                                        .millisecondsSinceEpoch
                                                        .toString(),
                                                'M', // Default size
                                              );
                                          return GestureDetector(
                                            onTap: () {
                                              if (!isInCart) {
                                                final cartItem = CartItem(
                                                  id:
                                                      item['_id'] ??
                                                      item['id'] ??
                                                      DateTime.now()
                                                          .millisecondsSinceEpoch
                                                          .toString(),
                                                  name: item['name'] ?? '',
                                                  image: item['image'],
                                                  basePrice:
                                                      (item['price'] ?? 0)
                                                          as int,
                                                  size: 'M',
                                                  quantity: 1,
                                                  restaurant:
                                                      'Uttora Coffee House',
                                                  category:
                                                      item['category'] ?? '',
                                                  description:
                                                      item['description'],
                                                );
                                                cartProvider.addItem(cartItem);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Đã thêm ${item['name']} vào giỏ hàng',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                    duration: Duration(
                                                      seconds: 2,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(8),
                                              child: Icon(
                                                isInCart
                                                    ? Icons.check_circle
                                                    : Icons.add_circle_outline,
                                                color: isInCart
                                                    ? Colors.green
                                                    : Colors.orange,
                                                size: 24,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
