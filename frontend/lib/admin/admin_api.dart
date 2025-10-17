import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class AdminApi {
  final String baseUrl;

  const AdminApi({required this.baseUrl});

  factory AdminApi.fromDefaults() {
    if (kIsWeb) {
      return AdminApi(baseUrl: 'http://localhost:3000');
    }
    if (Platform.isAndroid) {
      return AdminApi(baseUrl: 'http://10.0.2.2:3000');
    }
    return AdminApi(baseUrl: 'http://localhost:3000');
  }

  Future<AdminCounters> fetchCounters({String? restaurantId}) async {
    final qs = restaurantId != null ? '?restaurantId=$restaurantId' : '';
    final res = await http.get(Uri.parse('$baseUrl/api/orders/stats/counters$qs'));
    if (res.statusCode != 200) {
      throw Exception('Lỗi tải counters: ${res.statusCode}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    return AdminCounters(
      running: (data['running'] ?? 0) as int,
      requests: (data['requests'] ?? 0) as int,
    );
  }

  Future<List<RevenuePoint>> fetchRevenue({String granularity = 'daily', String? restaurantId}) async {
    final extra = restaurantId != null ? '&restaurantId=$restaurantId' : '';
    final url = Uri.parse('$baseUrl/api/orders/stats/revenue?granularity=$granularity$extra');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Lỗi tải doanh thu: ${res.statusCode}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    final series = (data['series'] as List<dynamic>? ?? [])
        .map((e) => RevenuePoint(
              period: e['period'] as String,
              // Backend hiện tại trả về 'totalAmount'; fallback sang 'total' nếu có
              total: ((e['totalAmount'] ?? e['total']) as num).toDouble(),
              tooltip: (e['tooltip'] as String?) ?? '',
            ))
        .toList();
    return series;
  }

  Future<List<Map<String, dynamic>>> fetchRestaurants() async {
    final res = await http.get(Uri.parse('$baseUrl/api/restaurants'));
    if (res.statusCode != 200) {
      throw Exception('Lỗi tải nhà hàng: ${res.statusCode}');
    }
    final data = json.decode(res.body) as List<dynamic>;
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> fetchTopFoods({int limit = 3, String? restaurantId}) async {
    final extra = restaurantId != null ? '&restaurantId=$restaurantId' : '';
    final res = await http.get(Uri.parse('$baseUrl/api/orders/stats/top-foods?limit=$limit$extra'));
    if (res.statusCode != 200) {
      throw Exception('Lỗi tải món phổ biến: ${res.statusCode}');
    }
    final data = json.decode(res.body) as List<dynamic>;
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> fetchFoods({String? category, String? search}) async {
    final params = <String, String>{};
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$baseUrl/api/foods').replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Lỗi tải món ăn: ${res.statusCode}');
    }
    final data = json.decode(res.body) as List<dynamic>;
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> createFood(Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl/api/foods');
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: json.encode(body));
    if (res.statusCode != 201) {
      throw Exception('Lỗi tạo món: ${res.statusCode} ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<void> deleteFood(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/foods/$id'));
    if (res.statusCode != 200) {
      throw Exception('Lỗi xóa món: ${res.statusCode}');
    }
  }

  Future<Map<String, dynamic>> updateFood(String id, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/foods/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('Lỗi cập nhật món: ${res.statusCode}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final res = await http.get(Uri.parse('$baseUrl/api/orders/notifications'));
    if (res.statusCode != 200) {
      throw Exception('Lỗi tải thông báo: ${res.statusCode}');
    }
    final data = json.decode(res.body) as List<dynamic>;
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> deleteNotification(String id) async {
    final url = Uri.parse('$baseUrl/api/orders/notifications/$id');
    final res = await http.delete(url);
    if (res.statusCode != 200 && res.statusCode != 204) {
      // Allow 404 as already removed on server
      if (res.statusCode != 404) {
        throw Exception('Lỗi xóa thông báo: ${res.statusCode}');
      }
    }
  }

  Future<void> clearNotifications() async {
    final url = Uri.parse('$baseUrl/api/orders/notifications');
    final res = await http.delete(url);
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Lỗi xóa tất cả thông báo: ${res.statusCode}');
    }
  }

  // User Management APIs
  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final res = await http.get(Uri.parse('$baseUrl/api/users'));
    if (res.statusCode != 200) {
      throw Exception('Lỗi tải danh sách người dùng: ${res.statusCode}');
    }
    final data = json.decode(res.body) as List<dynamic>;
    return List<Map<String, dynamic>>.from(data);
  }

  Future<int> fetchUserCount() async {
    final res = await http.get(Uri.parse('$baseUrl/api/users/stats/count'));
    if (res.statusCode != 200) {
      throw Exception('Lỗi tải số lượng người dùng: ${res.statusCode}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    return data['totalUsers'] as int;
  }

  Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/users/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('Lỗi cập nhật người dùng: ${res.statusCode}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<void> deleteUser(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/users/$id'));
    if (res.statusCode != 200) {
      throw Exception('Lỗi xóa người dùng: ${res.statusCode}');
    }
  }

  // Shipper Management APIs
  Future<List<Map<String, dynamic>>> fetchShippers() async {
    final res = await http.get(Uri.parse('$baseUrl/api/users?role=shipper'));
    if (res.statusCode != 200) {
      throw Exception('Lỗi tải danh sách shipper: ${res.statusCode}');
    }
    final data = json.decode(res.body) as List<dynamic>;
    return List<Map<String, dynamic>>.from(data);
  }

  Future<int> fetchShipperCount() async {
    final res = await http.get(Uri.parse('$baseUrl/api/users/stats/count?role=shipper'));
    if (res.statusCode != 200) {
      throw Exception('Lỗi tải số lượng shipper: ${res.statusCode}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    return data['totalUsers'] as int;
  }
}

class AdminCounters {
  final int running;
  final int requests;
  const AdminCounters({required this.running, required this.requests});
}

class RevenuePoint {
  final String period;
  final double total;
  final String tooltip; // optional formatted date for daily buckets
  const RevenuePoint({required this.period, required this.total, this.tooltip = ''});
}


