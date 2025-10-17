import 'package:flutter/material.dart';
import 'package:food_delivery_app/login_page_user/register_form.dart';
import 'package:provider/provider.dart';
import 'home_page_user/permission_page.dart';
import 'login_page_user/login_page.dart';
import 'login_page_user/login_form.dart';
import 'splash/splash_page.dart';
import 'admin/admin_dashboard_page.dart';

import 'home_page_user/cart_provider.dart';
import 'home_page_user/address_provider.dart';
import 'home_page_user/recent_provider.dart';
import 'auth/auth_provider.dart';

void main() {
  runApp(FoodDeliveryApp());
}

class FoodDeliveryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => AddressProvider()),
        ChangeNotifierProvider(create: (context) => RecentProvider()),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Giao Đồ Ăn',
        theme: ThemeData(primarySwatch: Colors.orange),
        initialRoute: '/splash',
        routes: {
          '/splash': (_) => SplashPage(), //SplashPage AdminDashboardPage
          '/login': (_) => LoginPage(),
          '/permissions': (_) => PermissionPage(),
          '/auth': (_) => LoginFormPage(),
          '/register': (_) => RegisterFormPage(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
