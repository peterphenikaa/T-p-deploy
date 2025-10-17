import 'package:flutter/foundation.dart';
import 'cart_item.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  int get totalPrice => _items.fold(0, (sum, item) => sum + item.totalPrice);

  bool get isEmpty => _items.isEmpty;

  void addItem(CartItem newItem) {
    final existingItemIndex = _items.indexWhere(
      (item) => item.id == newItem.id && item.size == newItem.size,
    );

    if (existingItemIndex >= 0) {
      // Item already exists, update quantity
      _items[existingItemIndex] = _items[existingItemIndex].copyWith(
        quantity: _items[existingItemIndex].quantity + newItem.quantity,
      );
    } else {
      // New item, add to cart
      _items.add(newItem);
    }
    notifyListeners();
  }

  void removeItem(String itemId, String size) {
    _items.removeWhere((item) => item.id == itemId && item.size == size);
    notifyListeners();
  }

  void updateQuantity(String itemId, String size, int quantity) {
    final index = _items.indexWhere(
      (item) => item.id == itemId && item.size == size,
    );

    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: quantity);
      }
      notifyListeners();
    }
  }

  void updateSize(String itemId, String oldSize, String newSize) {
    final index = _items.indexWhere(
      (item) => item.id == itemId && item.size == oldSize,
    );
    if (index < 0) return;

    final existingSameSizeIndex = _items.indexWhere(
      (item) => item.id == itemId && item.size == newSize,
    );

    if (existingSameSizeIndex >= 0) {
      // Merge quantities into existing target size
      final merged = _items[existingSameSizeIndex].copyWith(
        quantity: _items[existingSameSizeIndex].quantity + _items[index].quantity,
      );
      _items[existingSameSizeIndex] = merged;
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(size: newSize);
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  int getItemQuantity(String itemId, String size) {
    final item = _items.firstWhere(
      (item) => item.id == itemId && item.size == size,
      orElse: () => CartItem(
        id: '',
        name: '',
        basePrice: 0,
        size: '',
        quantity: 0,
        restaurant: '',
        category: '',
      ),
    );
    return item.quantity;
  }

  bool isItemInCart(String itemId, String size) {
    return _items.any((item) => item.id == itemId && item.size == size);
  }
}
