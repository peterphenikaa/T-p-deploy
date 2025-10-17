import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'cart_provider.dart';
import 'cart_item.dart';
import 'breakdown_page.dart';
import 'checkout_page.dart';
import 'address_provider.dart';
import 'address_model.dart';
import 'edit_address_page.dart';
import 'package:food_delivery_app/config/env.dart';

class CartPage extends StatefulWidget {
  const CartPage({Key? key}) : super(key: key);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  String? _latestLatLng;
  String? _latestAddress;
  Map<String, String>? _latestComponents; // street, ward, district, city
  String? _suggestedFullName;
  String? _suggestedPhoneNumber;
  // Logged-in user info (from /api/auth/login response or stored globally)
  String? _userId;
  String? _userName;
  String? _userPhone;
  bool _loadingLocation = false;
  String? _locationError;

  String get _apiBase => API_BASE_URL;

  Future<void> _loadLatestLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });
    try {
      // NOTE: align with userId used when posting in PermissionPage
      const userId = 'anonymous';
      final url = Uri.parse('$_apiBase/api/location/$userId/latest');
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final lat = data['lat'];
        final lng = data['lng'];
        setState(() {
          _latestLatLng = (lat != null && lng != null) ? '$lat, $lng' : null;
        });
        if (lat != null && lng != null) {
          if (!DISABLE_REVERSE_GEOCODE_IN_PROD) {
            final result = await _reverseGeocode(lat, lng);
            if (result != null) {
              setState(() {
                _latestAddress = result['display'] as String?;
                final c = result['components'];
                if (c is Map<String, String>) {
                  _latestComponents = c;
                }
              });
            }
          }
        }
      } else {
        setState(() {
          _locationError = 'Không có vị trí';
        });
      }
    } catch (e) {
      setState(() {
        _locationError = 'Không thể tải vị trí';
      });
    } finally {
      setState(() {
        _loadingLocation = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _reverseGeocode(num lat, num lng) async {
    try {
      final uri = Uri.parse('$_apiBase/api/reverse-geocode?lat=$lat&lon=$lng');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        final address = body['address'];
        String? display = body['display_name'];
        Map<String, String> components = {};
        if (address is Map) {
          final road = address['road'];
          final house = address['house_number'];
          final ward =
              address['suburb'] ??
              address['neighbourhood'] ??
              address['quarter'] ??
              address['hamlet'] ??
              address['city_district'];
          final district =
              address['district'] ??
              address['county'] ??
              address['state_district'];
          final city =
              address['city'] ??
              address['town'] ??
              address['village'] ??
              address['county'] ??
              address['state'];
          // Try to extract name and phone from address tags if available
          final nameTag =
              address['name'] ?? address['contact_name'] ?? address['operator'];
          final phoneTag =
              address['phone'] ??
              address['contact:phone'] ??
              address['contact_phone'] ??
              address['telephone'];

          // build street string "house road"
          String? street;
          if (road != null && house != null)
            street = '$house $road';
          else
            street = road?.toString();

          if (street != null) components['street'] = street;
          if (ward != null) components['ward'] = ward.toString();
          if (district != null) components['district'] = district.toString();
          if (city != null) components['city'] = city.toString();
          if (nameTag != null) _suggestedFullName = nameTag.toString();
          if (phoneTag != null) _suggestedPhoneNumber = phoneTag.toString();
        }
        display ??= () {
          final parts = [
            components['street'],
            components['ward'],
            components['district'],
            components['city'],
          ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
          return parts.isNotEmpty ? parts : null;
        }();
        if (display != null || components.isNotEmpty) {
          return {'display': display, 'components': components};
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Load addresses when page initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final addressProvider = Provider.of<AddressProvider>(
        context,
        listen: false,
      );
      addressProvider.loadAddresses('user123'); // Replace with actual user ID
      _loadLatestLocation();
      _loadUserProfileFromStorage();
    });
  }

  Future<void> _loadUserProfileFromStorage() async {
    try {
      // Demo: fetch a profile from backend if userId/name not present
      if (_userId == null || _userName == null || _userPhone == null) {
        final url = Uri.parse('$_apiBase/api/auth/profile');
        final resp = await http.get(url);
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          setState(() {
            _userId = (data['id'] ?? 'user123').toString();
            _userName = data['name']?.toString();
            _userPhone = data['phoneNumber']?.toString();
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Try to receive user info passed via navigation
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is Map && _userId == null) {
      _userId = (routeArgs['userId'] ?? 'user123')?.toString();
      _userName = routeArgs['name']?.toString();
      _userPhone = routeArgs['phoneNumber']?.toString();
    }
    return Scaffold(
      backgroundColor: const Color(0xff2c2c2e), // Dark background
      appBar: AppBar(
        backgroundColor: const Color(0xff2c2c2e),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text(
          'Giỏ hàng',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer2<CartProvider, AddressProvider>(
        builder: (context, cartProvider, addressProvider, child) {
          if (cartProvider.isEmpty) {
            return _buildEmptyCart();
          }

          return Column(
            children: [
              // Cart Items Section (Dark)
              Expanded(
                child: Container(
                  color: const Color(0xff2c2c2e),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartProvider.items.length,
                    itemBuilder: (context, index) {
                      final item = cartProvider.items[index];
                      return _CartItemCard(
                        item: item,
                        onQuantityChanged: (newQuantity) {
                          cartProvider.updateQuantity(
                            item.id,
                            item.size,
                            newQuantity,
                          );
                        },
                        onRemove: () {
                          cartProvider.removeItem(item.id, item.size);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã xóa ${item.name} khỏi giỏ hàng',
                              ),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              _buildCartSummary(cartProvider, addressProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Container(
      color: const Color(0xff2c2c2e),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 120,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Giỏ hàng trống',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hãy thêm món ăn yêu thích vào giỏ hàng',
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),
            const SizedBox(height: 32),
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Tiếp tục mua sắm',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary(
    CartProvider cartProvider,
    AddressProvider addressProvider,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xfff8f9fa),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Delivery Address Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Địa chỉ giao hàng',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    Builder(
                      builder: (context) => TextButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditAddressPage(
                                userId:
                                    'user123', // Replace with actual user ID
                                initialStreet: _latestComponents?['street'],
                                initialWard: _latestComponents?['ward'],
                                initialDistrict: _latestComponents?['district'],
                                initialCity: _latestComponents?['city'],
                                initialFullName:
                                    _userName ?? _suggestedFullName,
                                initialPhoneNumber:
                                    _userPhone ?? _suggestedPhoneNumber,
                              ),
                            ),
                          );
                          if (result == true) {
                            // Reload addresses if address was added/updated
                            addressProvider.loadAddresses('user123');
                          }
                        },
                        child: const Text(
                          'Chỉnh sửa',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    addressProvider.defaultAddress?.fullAddress ??
                        (_latestAddress ??
                            (_latestLatLng != null
                                ? 'Vị trí hiện tại: $_latestLatLng'
                                : '2118 Thornridge Cir. Syracuse, New York, New York')),
                    style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  ),
                ),
              ],
            ),
          ),

          // Total Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '₫${cartProvider.totalPrice.toString()}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Builder(
                      builder: (context) => TextButton(
                        onPressed: () {
                          final addressText =
                              addressProvider.defaultAddress?.fullAddress ??
                              (_latestAddress ??
                                  (_latestLatLng != null
                                      ? 'Vị trí hiện tại: $_latestLatLng'
                                      : ''));
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BreakdownPage(deliveryAddress: addressText),
                            ),
                          );
                        },
                        child: const Text(
                          'Chi tiết hóa đơn >',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CheckoutPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Đặt hàng',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const _CartItemCard({
    Key? key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xff3a3a3c),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xff4a4a4c),
              ),
              child: ClipOval(
                child: item.image != null
                    ? Image.asset('${item.image}', fit: BoxFit.cover)
                    : const Icon(
                        Icons.fastfood,
                        size: 40,
                        color: Colors.orange,
                      ),
              ),
            ),
            const SizedBox(width: 16),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₫${item.price.toString()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Size:',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xff2c2c2e),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xff4a4a4c)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: item.size,
                            dropdownColor: const Color(0xff3a3a3c),
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            items: const [
                              DropdownMenuItem(
                                value: 'S',
                                child: Text('S (10")'),
                              ),
                              DropdownMenuItem(
                                value: 'M',
                                child: Text('M (14")'),
                              ),
                              DropdownMenuItem(
                                value: 'L',
                                child: Text('L (16")'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val == null || val == item.size) return;
                              Provider.of<CartProvider>(
                                context,
                                listen: false,
                              ).updateSize(item.id, item.size, val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Quantity Controls
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xff2c2c2e),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _QuantityButton(
                              icon: Icons.remove,
                              onTap: () {
                                if (item.quantity > 1) {
                                  onQuantityChanged(item.quantity - 1);
                                } else {
                                  onRemove();
                                }
                              },
                            ),
                            Container(
                              width: 40,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                item.quantity.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            _QuantityButton(
                              icon: Icons.add,
                              onTap: () => onQuantityChanged(item.quantity + 1),
                            ),
                          ],
                        ),
                      ),
                      // Remove Button
                      GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
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
      ),
    );
  }

  String _getSizeLabel(String size) {
    switch (size) {
      case 'S':
        return '10"';
      case 'M':
        return '14"';
      case 'L':
        return '16"';
      default:
        return size;
    }
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({Key? key, required this.icon, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xff4a4a4c),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
