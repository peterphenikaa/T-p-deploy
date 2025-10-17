import 'package:flutter/material.dart';

class RecentProvider extends ChangeNotifier {
  // Store product maps (shallow copy) in-memory
  final List<Map<String, dynamic>> _recent = [];
  int maxItems = 10;

  List<Map<String, dynamic>> get recent => List.unmodifiable(_recent);

  void addRecent(Map<String, dynamic> product) {
    if (product.isEmpty) return;
    // determine id
    final rawId = product['_id'] ?? product['id'];
    final id = rawId is Map
        ? (rawId['_id'] ?? rawId['\$oid'] ?? rawId.toString())
        : (rawId?.toString() ?? '');
    if (id.isEmpty) return;

    // remove existing with same id
    _recent.removeWhere((p) {
      final rp = p['_id'] ?? p['id'];
      final rid = rp is Map
          ? (rp['_id'] ?? rp['\$oid'] ?? rp.toString())
          : (rp?.toString() ?? '');
      return rid == id;
    });

    // insert at front
    _recent.insert(0, Map<String, dynamic>.from(product));

    // trim
    if (_recent.length > maxItems)
      _recent.removeRange(maxItems, _recent.length);

    notifyListeners();
  }

  void clear() {
    _recent.clear();
    notifyListeners();
  }
}
