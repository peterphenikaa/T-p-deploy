import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:food_delivery_app/config/env.dart';
import 'address_model.dart';

class EditAddressPage extends StatefulWidget {
  final AddressModel? address;
  final String userId;
  final String? initialStreet;
  final String? initialWard;
  final String? initialDistrict;
  final String? initialCity;
  final String? initialFullName;
  final String? initialPhoneNumber;

  const EditAddressPage({
    Key? key,
    this.address,
    required this.userId,
    this.initialStreet,
    this.initialWard,
    this.initialDistrict,
    this.initialCity,
    this.initialFullName,
    this.initialPhoneNumber,
  }) : super(key: key);

  @override
  _EditAddressPageState createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _wardController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      _fullNameController.text = widget.address!.fullName;
      _phoneController.text = widget.address!.phoneNumber;
      _streetController.text = widget.address!.street;
      _wardController.text = widget.address!.ward;
      _districtController.text = widget.address!.district;
      _cityController.text = widget.address!.city;
      _noteController.text = widget.address!.note ?? '';
      _isDefault = widget.address!.isDefault;
    } else {
      // Pre-fill from reverse geocoded components if provided
      if (widget.initialFullName != null &&
          widget.initialFullName!.trim().isNotEmpty) {
        _fullNameController.text = widget.initialFullName!;
      }
      if (widget.initialPhoneNumber != null &&
          widget.initialPhoneNumber!.trim().isNotEmpty) {
        _phoneController.text = widget.initialPhoneNumber!;
      }
      if (widget.initialStreet != null &&
          widget.initialStreet!.trim().isNotEmpty) {
        _streetController.text = widget.initialStreet!;
      }
      if (widget.initialWard != null && widget.initialWard!.trim().isNotEmpty) {
        _wardController.text = widget.initialWard!;
      }
      if (widget.initialDistrict != null &&
          widget.initialDistrict!.trim().isNotEmpty) {
        _districtController.text = widget.initialDistrict!;
      }
      if (widget.initialCity != null && widget.initialCity!.trim().isNotEmpty) {
        _cityController.text = widget.initialCity!;
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _wardController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final _apiBase = API_BASE_URL;
      final addressData = {
        'userId': widget.userId,
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'street': _streetController.text.trim(),
        'ward': _wardController.text.trim(),
        'district': _districtController.text.trim(),
        'city': _cityController.text.trim(),
        'note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        'isDefault': _isDefault,
      };

      final response = widget.address == null
          ? await http.post(
              Uri.parse('$_apiBase/api/addresses'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(addressData),
            )
          : await http.put(
              Uri.parse('$_apiBase/api/addresses/${widget.address!.id}'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(addressData),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.address == null
                  ? 'Thêm địa chỉ thành công!'
                  : 'Cập nhật địa chỉ thành công!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception('Lỗi lưu địa chỉ: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        backgroundColor: const Color(0xfff8f9fa),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
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
        title: Text(
          widget.address == null ? 'Thêm địa chỉ mới' : 'Chỉnh sửa địa chỉ',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.address != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _showDeleteDialog,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormCard(),
              const SizedBox(height: 20),
              _buildDefaultToggle(),
              const SizedBox(height: 30),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              const Text(
                'Thông tin địa chỉ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Full Name
          _buildTextField(
            controller: _fullNameController,
            label: 'Họ và tên',
            hint: 'Nhập họ và tên người nhận',
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập họ và tên';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Phone Number
          _buildTextField(
            controller: _phoneController,
            label: 'Số điện thoại',
            hint: 'Nhập số điện thoại',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập số điện thoại';
              }
              if (!RegExp(r'^[0-9]{10,11}$').hasMatch(value.trim())) {
                return 'Số điện thoại không hợp lệ';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Street
          _buildTextField(
            controller: _streetController,
            label: 'Số nhà, tên đường',
            hint: 'Nhập số nhà và tên đường',
            icon: Icons.home,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập địa chỉ chi tiết';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Ward
          _buildTextField(
            controller: _wardController,
            label: 'Phường/Xã',
            hint: 'Nhập phường/xã',
            icon: Icons.location_city,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập phường/xã';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // District
          _buildTextField(
            controller: _districtController,
            label: 'Quận/Huyện',
            hint: 'Nhập quận/huyện',
            icon: Icons.location_city,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập quận/huyện';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // City
          _buildTextField(
            controller: _cityController,
            label: 'Thành phố/Tỉnh',
            hint: 'Nhập thành phố/tỉnh',
            icon: Icons.location_city,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập thành phố/tỉnh';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Note
          _buildTextField(
            controller: _noteController,
            label: 'Ghi chú (tùy chọn)',
            hint: 'Nhập ghi chú thêm...',
            icon: Icons.note,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.orange, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.amber[700], size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Đặt làm địa chỉ mặc định',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Switch(
            value: _isDefault,
            onChanged: (value) {
              setState(() {
                _isDefault = value;
              });
            },
            activeColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveAddress,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                widget.address == null ? 'THÊM ĐỊA CHỈ' : 'CẬP NHẬT ĐỊA CHỈ',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xóa địa chỉ'),
          content: const Text('Bạn có chắc chắn muốn xóa địa chỉ này không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAddress();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAddress() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final _apiBase = API_BASE_URL;
      final response = await http.delete(
        Uri.parse('$_apiBase/api/addresses/${widget.address!.id}'),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xóa địa chỉ thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception('Lỗi xóa địa chỉ: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
