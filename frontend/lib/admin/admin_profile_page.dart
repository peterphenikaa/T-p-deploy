import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'admin_profile_personal_info_page.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../login_page_user/login_page.dart';
import 'admin_profile_user_mgmt_page.dart';
import 'admin_profile_shipper_mgmt_page.dart';
import 'admin_profile_order_count_page.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({Key? key}) : super(key: key);

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  String avatar = 'assets/homepageUser/restaurant_img2.jpg';
  String name = 'Admin User';
  Uint8List? _pickedBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Orange header card (no back arrow)
          Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundImage: _pickedBytes != null
                              ? MemoryImage(_pickedBytes!)
                              : avatar.startsWith('assets/')
                                  ? AssetImage(avatar) as ImageProvider
                                  : FileImage(File(avatar)),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: _changeAvatar,
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.orange),
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                          const SizedBox(height: 6),
                          const Text('Quản trị viên', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _menuGroup([
            _menuItem(Icons.person_outline, 'Thông tin cá nhân', () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPersonalInfoPage()));
            }),
            _menuItem(Icons.group_outlined, 'Quản lý tài khoản user', () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminUserManagementPage()));
            }),
            _menuItem(Icons.delivery_dining_outlined, 'Quản lý tài khoản shipper', () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminShipperManagementPage()));
            }),
            _menuItem(Icons.receipt_long_outlined, 'Số lượng đơn hàng', () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminOrderCountPage()));
            }),
            _menuItem(Icons.logout, 'Đăng xuất', () {
              // Clear auth state and navigate to login
              try {
                Provider.of<AuthProvider>(context, listen: false).clear();
              } catch (_) {}
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginPage()),
                (route) => false,
              );
            }),
          ]),
        ],
      ),
    );
  }

  Widget _menuGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            children[i],
          ]
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(color: const Color(0xFFF6F6F6), borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _changeAvatar() async {
    try {
      // Xin quyền nếu cần (Android cũ)
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final photos = await Permission.photos.request();
        final storage = await Permission.storage.request();
        if (photos.isDenied && storage.isDenied) {
          return;
        }
      }

      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        setState(() {
          _pickedBytes = bytes;
        });
      } else {
        setState(() {
          avatar = file.path;
          _pickedBytes = null;
        });
      }
    } catch (_) {}
  }
}


