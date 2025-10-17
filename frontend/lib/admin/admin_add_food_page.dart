import 'package:flutter/material.dart';
import 'admin_api.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class AdminAddFoodPage extends StatefulWidget {
  final Map<String, dynamic>? initial; // if provided -> edit mode
  const AdminAddFoodPage({Key? key, this.initial}) : super(key: key);

  @override
  State<AdminAddFoodPage> createState() => _AdminAddFoodPageState();
}

class _AdminAddFoodPageState extends State<AdminAddFoodPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _image = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _ingredientsInput = TextEditingController();

  bool pickUp = true;
  bool delivery = false;
  bool saving = false;
  late final AdminApi _api;
  // Known asset images to auto-match with food names
  static const List<String> _assetImages = [
    'assets/homepageUser/burger_classic.jpg',
    'assets/homepageUser/burger_heaven.webp',
    'assets/homepageUser/chicken_sandwich.jpg',
    'assets/homepageUser/hot_dog_special.jpg',
    'assets/homepageUser/pepperoni_pizza.jpg',
    'assets/homepageUser/european_pizza.jpg',
    'assets/homepageUser/buffano_pizza.jpg',
    'assets/homepageUser/caesar_salad.jpg',
    'assets/homepageUser/salad_fresh.jpg',
    'assets/homepageUser/fish_and_chips.jpg',
    'assets/homepageUser/sushi_word.jpg',
    'assets/assets_restaurant_img2.jpg', // fallback examples
    'assets/pizza_place.jpg',
  ];

  String? _guessAssetForName(String name) {
    final slug = name.toLowerCase();
    String? best;
    int bestScore = 0;
    for (final p in _assetImages) {
      final file = p.split('/').last.toLowerCase();
      int score = 0;
      for (final token in slug.split(RegExp(r'\s+'))) {
        if (token.isEmpty) continue;
        if (file.contains(token)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    return bestScore > 0 ? best : null;
  }
  String? _selectedRestaurantId;
  List<Map<String, dynamic>> _restaurants = [];

  @override
  void initState() {
    super.initState();
    _api = AdminApi.fromDefaults();
    _loadRestaurants();
    // preload if editing
    final init = widget.initial;
    if (init != null) {
      _name.text = (init['name'] ?? '').toString();
      _price.text = ((init['price'] ?? 0) as num).toString();
      _image.text = (init['image'] ?? '').toString();
      _description.text = (init['description'] ?? '').toString();
      _category.text = (init['category'] ?? '').toString();
      final ingredients = (init['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? [];
      _ingredientsInput.text = ingredients.join(', ');
    }
    // Auto-fill image based on name typing
    _name.addListener(() {
      final guess = _guessAssetForName(_name.text);
      if (guess != null) {
        // Only set if user chưa nhập hình
        if (_image.text.isEmpty || _image.text.startsWith('assets')) {
          _image.text = guess;
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _image.dispose();
    _description.dispose();
    _category.dispose();
    _ingredientsInput.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurants() async {
    try {
      final res = await http.get(Uri.parse('${_api.baseUrl}/api/restaurants'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        setState(() {
          _restaurants = List<Map<String, dynamic>>.from(data);
          if (_selectedRestaurantId == null && _restaurants.isNotEmpty) {
            final firstId = (_restaurants.first['_id'] ?? _restaurants.first['id']).toString();
            _selectedRestaurantId = firstId;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final ingredients = _ingredientsInput.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final body = {
        'name': _name.text.trim(),
        'category': _category.text.trim(),
        'price': int.tryParse(_price.text.trim()) ?? 0,
        'image': _image.text.trim(),
        'description': _description.text.trim(),
        'ingredients': ingredients,
        if (_selectedRestaurantId != null) 'restaurantId': _selectedRestaurantId,
      };
      if (widget.initial != null && widget.initial!['_id'] != null) {
        await _api.updateFood(widget.initial!['_id'].toString(), body);
      } else {
        await _api.createFood(body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm món ăn thành công')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tạo món thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Thêm món mới', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              const Text('TÊN MÓN'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _name,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên món' : null,
                decoration: _decoration('Ví dụ: Chicken Bhuna'),
              ),
              const SizedBox(height: 16),
              const Text('GIÁ (VND)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                validator: (v) => (int.tryParse(v ?? '') == null) ? 'Nhập số hợp lệ' : null,
                decoration: _decoration('60000'),
              ),
              const SizedBox(height: 16),
              const Text('DANH MỤC'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _category,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập danh mục' : null,
                decoration: _decoration('Burger / Pizza / ...'),
              ),
              const SizedBox(height: 16),
              const Text('NHÀ HÀNG'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRestaurantId,
                      items: _restaurants.map((r) {
                        final id = (r['_id'] ?? r['id']).toString();
                        final name = (r['name'] ?? 'Nhà hàng').toString();
                        return DropdownMenuItem<String>(value: id, child: Text(name));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedRestaurantId = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Chọn nhà hàng' : null,
                      decoration: _decoration('Chọn nhà hàng'),
                    ),
                  ),
                ],
              ),
              const Text('HÌNH (đường dẫn assets)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _image,
                decoration: _decoration('assets/homepageUser/burger_img1.jpg'),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _pickImageInto(_image),
                  icon: const Icon(Icons.image),
                  label: const Text('Chọn ảnh từ máy'),
                ),
              ),
              const SizedBox(height: 16),
              const Text('MÔ TẢ'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 3,
                decoration: _decoration('Mô tả ngắn...'),
              ),
              const SizedBox(height: 16),
              const Text('NGUYÊN LIỆU (ngăn cách bằng dấu phẩy)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _ingredientsInput,
                minLines: 1,
                maxLines: 2,
                decoration: _decoration('Salt, Chicken, Onion'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(saving ? 'Đang lưu...' : 'LƯU'),
                ),
              )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    );
  }

  // Removed create-restaurant form per requirements

  Future<void> _pickImageInto(TextEditingController controller) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      if (kIsWeb) {
        final Uint8List bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        final mime = file.mimeType ?? 'image/jpeg';
        controller.text = 'data:$mime;base64,$b64';
      } else {
        controller.text = file.path;
      }
      setState(() {});
    } catch (_) {}
  }
}


