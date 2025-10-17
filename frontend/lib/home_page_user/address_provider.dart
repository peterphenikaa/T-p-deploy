import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'address_model.dart';
import 'package:food_delivery_app/config/env.dart';

class AddressProvider with ChangeNotifier {
  List<AddressModel> _addresses = [];
  AddressModel? _defaultAddress;
  bool _isLoading = false;

  List<AddressModel> get addresses => List.unmodifiable(_addresses);
  AddressModel? get defaultAddress => _defaultAddress;
  bool get isLoading => _isLoading;

  Future<void> loadAddresses(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/api/addresses/$userId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _addresses = data.map((json) => AddressModel.fromJson(json)).toList();

        // Find default address
        _defaultAddress = _addresses.firstWhere(
          (address) => address.isDefault,
          orElse: () => _addresses.isNotEmpty
              ? _addresses.first
              : AddressModel(
                  id: '',
                  userId: userId,
                  fullName: '',
                  phoneNumber: '',
                  street: '2118 Thornridge Cir.',
                  ward: 'Syracuse',
                  district: 'New York',
                  city: 'New York',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
        );
      } else {
        throw Exception('Failed to load addresses: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading addresses: $e');
      // Set default address if loading fails
      _defaultAddress = AddressModel(
        id: 'default',
        userId: userId,
        fullName: 'Người dùng',
        phoneNumber: '0123456789',
        street: '2118 Thornridge Cir.',
        ward: 'Syracuse',
        district: 'New York',
        city: 'New York',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addAddress(AddressModel address) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/api/addresses'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(address.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final newAddress = AddressModel.fromJson(data);
        _addresses.add(newAddress);

        if (newAddress.isDefault) {
          _setDefaultAddress(newAddress);
        }

        notifyListeners();
      } else {
        throw Exception('Failed to add address: ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding address: $e');
      rethrow;
    }
  }

  Future<void> updateAddress(AddressModel address) async {
    try {
      final response = await http.put(
        Uri.parse('$API_BASE_URL/api/addresses/${address.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(address.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updatedAddress = AddressModel.fromJson(data);

        final index = _addresses.indexWhere((a) => a.id == address.id);
        if (index != -1) {
          _addresses[index] = updatedAddress;
        }

        if (updatedAddress.isDefault) {
          _setDefaultAddress(updatedAddress);
        }

        notifyListeners();
      } else {
        throw Exception('Failed to update address: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating address: $e');
      rethrow;
    }
  }

  Future<void> deleteAddress(String addressId) async {
    try {
      final response = await http.delete(
        Uri.parse('$API_BASE_URL/api/addresses/$addressId'),
      );

      if (response.statusCode == 200) {
        _addresses.removeWhere((address) => address.id == addressId);

        // If deleted address was default, set another as default
        if (_defaultAddress?.id == addressId) {
          _defaultAddress = _addresses.isNotEmpty ? _addresses.first : null;
        }

        notifyListeners();
      } else {
        throw Exception('Failed to delete address: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting address: $e');
      rethrow;
    }
  }

  Future<void> setDefaultAddress(String addressId) async {
    try {
      final response = await http.put(
        Uri.parse('$API_BASE_URL/api/addresses/$addressId/set-default'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updatedAddress = AddressModel.fromJson(data);

        // Update all addresses
        for (int i = 0; i < _addresses.length; i++) {
          _addresses[i] = _addresses[i].copyWith(
            isDefault: _addresses[i].id == addressId,
          );
        }

        _setDefaultAddress(updatedAddress);
        notifyListeners();
      } else {
        throw Exception(
          'Failed to set default address: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error setting default address: $e');
      rethrow;
    }
  }

  void _setDefaultAddress(AddressModel address) {
    _defaultAddress = address;
    // Update the address in the list
    final index = _addresses.indexWhere((a) => a.id == address.id);
    if (index != -1) {
      _addresses[index] = address;
    }
  }

  AddressModel? getAddressById(String id) {
    try {
      return _addresses.firstWhere((address) => address.id == id);
    } catch (e) {
      return null;
    }
  }
}
