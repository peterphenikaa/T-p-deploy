import 'package:flutter/foundation.dart';

class AuthProvider with ChangeNotifier {
  String? _userId;
  String? _userName;
  String? _email;

  String? get userId => _userId;
  String? get userName => _userName;
  String? get email => _email;
  bool get isLoggedIn => _userId != null;

  void setUser({required String id, required String name, required String email}) {
    _userId = id;
    _userName = name;
    _email = email;
    notifyListeners();
  }

  void clear() {
    _userId = null;
    _userName = null;
    _email = null;
    notifyListeners();
  }
}


