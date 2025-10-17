import 'package:flutter/material.dart';
import 'admin_api.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminShipperManagementPage extends StatefulWidget {
  const AdminShipperManagementPage({super.key});

  @override
  State<AdminShipperManagementPage> createState() => _AdminShipperManagementPageState();
}

class _AdminShipperManagementPageState extends State<AdminShipperManagementPage> {
  late final AdminApi _api;
  List<Map<String, dynamic>> shippers = [];
  int totalShippers = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _api = AdminApi.fromDefaults();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        _api.fetchShippers(),
        _api.fetchShipperCount(),
      ]);
      setState(() {
        shippers = results[0] as List<Map<String, dynamic>>;
        totalShippers = results[1] as int;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _deleteShipper(Map<String, dynamic> shipper) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa shipper "${shipper['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.deleteUser(shipper['_id']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa shipper "${shipper['name']}"')),
        );
        _loadData(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa shipper: $e')),
        );
      }
    }
  }

  Future<void> _editShipper(Map<String, dynamic> shipper) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EditShipperPage(shipper: shipper, api: _api),
      ),
    );
    if (result == true) {
      _loadData(); // Refresh the list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Quản lý tài khoản shipper', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => _CreateShipperPage(api: _api)),
              );
              if (created == true) _loadData();
            },
            icon: const Icon(Icons.add_circle_outline, color: Colors.deepOrange),
            tooltip: 'Thêm shipper',
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Total shippers count
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.delivery_dining, color: Colors.deepOrange, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Tổng số shipper: $totalShippers',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Shippers list
                Expanded(
                  child: shippers.isEmpty
                      ? const Center(child: Text('Không có shipper nào'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: shippers.length,
                          itemBuilder: (context, index) {
                            final shipper = shippers[index];
                            return _ShipperCard(
                              shipper: shipper,
                              onEdit: () => _editShipper(shipper),
                              onDelete: () => _deleteShipper(shipper),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _ShipperCard extends StatelessWidget {
  final Map<String, dynamic> shipper;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShipperCard({
    required this.shipper,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = shipper['name'] ?? 'Không có tên';
    final email = shipper['email'] ?? 'Không có email';
    final phone = shipper['phoneNumber'] ?? 'Không có SĐT';
    final address = shipper['address'] as Map<String, dynamic>?;
    final addressStr = address != null
        ? '${address['houseNumber'] ?? ''}, ${address['ward'] ?? ''}, ${address['city'] ?? ''}'
        : 'Không có địa chỉ';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.delivery_dining,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Sửa'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Xóa', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.phone, label: 'SĐT', value: phone),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.location_on, label: 'Địa chỉ', value: addressStr),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }
}

class _EditShipperPage extends StatefulWidget {
  final Map<String, dynamic> shipper;
  final AdminApi api;

  const _EditShipperPage({
    required this.shipper,
    required this.api,
  });

  @override
  State<_EditShipperPage> createState() => _EditShipperPageState();
}

class _EditShipperPageState extends State<_EditShipperPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _houseNumberController;
  late final TextEditingController _wardController;
  late final TextEditingController _cityController;
  final _formKey = GlobalKey<FormState>();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shipper['name'] ?? '');
    _emailController = TextEditingController(text: widget.shipper['email'] ?? '');
    _phoneController = TextEditingController(text: widget.shipper['phoneNumber'] ?? '');
    
    final address = widget.shipper['address'] as Map<String, dynamic>?;
    _houseNumberController = TextEditingController(text: address?['houseNumber'] ?? '');
    _wardController = TextEditingController(text: address?['ward'] ?? '');
    _cityController = TextEditingController(text: address?['city'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _houseNumberController.dispose();
    _wardController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => saving = true);
    try {
      final body = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'address': {
          'houseNumber': _houseNumberController.text.trim(),
          'ward': _wardController.text.trim(),
          'city': _cityController.text.trim(),
        },
      };

      await widget.api.updateUser(widget.shipper['_id'], body);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật thông tin shipper')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật: $e')),
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
        title: const Text('Chỉnh sửa shipper', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lưu'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin cơ bản',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập email';
                        }
                        if (!value.contains('@')) {
                          return 'Email không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập số điện thoại';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Địa chỉ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _houseNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Số nhà',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập số nhà';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _wardController,
                      decoration: const InputDecoration(
                        labelText: 'Phường/Xã',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập phường/xã';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Thành phố',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập thành phố';
                        }
                        return null;
                      },
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

class _CreateShipperPage extends StatefulWidget {
  final AdminApi api;
  const _CreateShipperPage({required this.api});

  @override
  State<_CreateShipperPage> createState() => _CreateShipperPageState();
}

class _CreateShipperPageState extends State<_CreateShipperPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _wardController = TextEditingController();
  final _cityController = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _houseNumberController.dispose();
    _wardController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final body = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'password': _passwordController.text,
        'role': 'shipper',
        'address': {
          'houseNumber': _houseNumberController.text.trim(),
          'ward': _wardController.text.trim(),
          'city': _cityController.text.trim(),
        },
      };
      // Tái sử dụng endpoint tạo user (nếu backend chưa có, tạm dùng update với id mới sẽ fail).
      // Ở đây dùng createFood pattern; nếu bạn có /api/users (POST) hãy chuyển sang AdminApi.createUser.
      final uri = Uri.parse('${widget.api.baseUrl}/api/users');
      final res = await AdminHttp.post(uri, body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo shipper')), 
        );
        Navigator.of(context).pop(true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tạo shipper: ${res.statusCode}')), 
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo shipper: $e')), 
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
        title: const Text('Thêm shipper', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: saving ? null : _create,
            child: saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Tạo'),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thông tin cơ bản', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Tên', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      validator: (v) => (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null,
                    ),
                    const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Mật khẩu', border: OutlineInputBorder()),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6) ? 'Tối thiểu 6 ký tự' : null,
                  ),
                  const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập SĐT' : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Địa chỉ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _houseNumberController,
                      decoration: const InputDecoration(labelText: 'Số nhà', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _wardController,
                      decoration: const InputDecoration(labelText: 'Phường/Xã', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'Thành phố', border: OutlineInputBorder()),
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

// Lightweight HTTP helper (local to this page)
class AdminHttp {
  static Future<http.Response> post(Uri uri, Map<String, dynamic> body) {
    return http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
  }
}


