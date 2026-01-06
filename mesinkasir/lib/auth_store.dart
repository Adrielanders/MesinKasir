import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';

class UserAccount {
  final String username;
  final String pin;
  final String role;
  final bool active;

  const UserAccount({
    required this.username,
    required this.pin,
    required this.role,
    this.active = true,
  });

  UserAccount copyWith({String? pin, String? role, bool? active}) {
    return UserAccount(
      username: username,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      active: active ?? this.active,
    );
  }
}

class AuthUser {
  final int id;
  final String username;
  final String role;
  final bool active;

  const AuthUser({
    required this.id,
    required this.username,
    required this.role,
    required this.active,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    final rawActive = json['active'];
    final bool active = rawActive is bool
        ? rawActive
        : rawActive is int
        ? rawActive == 1
        : (rawActive?.toString().toLowerCase() == '1' ||
              rawActive?.toString().toLowerCase() == 'true');

    return AuthUser(
      id: id,
      username: (json['username'] ?? json['email'] ?? '') as String,
      role: (json['role'] ?? 'kasir') as String,
      active: active,
    );
  }
}

class AuthStore {
  AuthStore._();

  static final List<UserAccount> users = [];

  static void createKasir({required String username, required String pin}) {
    users.add(UserAccount(username: username, pin: pin, role: 'kasir'));
  }

  static void toggleActive(String username) {
    final idx = users.indexWhere((u) => u.username == username);
    if (idx == -1) return;
    users[idx] = users[idx].copyWith(active: !users[idx].active);
  }
  // ====================================================================

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  static const String baseUrl = 'http://127.0.0.1:8000';
  // static const String baseUrl = 'http://10.0.2.2:8000'; // aktifkan ini kalau pakai Android emulator

  static Future<String?> token() => _storage.read(key: _tokenKey);
  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  static Future<AuthUser?> login({
    required String email,
    required String password,
    String deviceName = 'pc',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': deviceName,
      }),
    );

    if (res.statusCode != 200) {
      return null;
    }

    final root = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (root['data'] is Map<String, dynamic>)
        ? (root['data'] as Map<String, dynamic>)
        : root;

    final t = (data['token'] ?? data['access_token']) as String?;
    final u = data['user'] as Map<String, dynamic>?;

    if (t == null || t.isEmpty || u == null) return null;

    await saveToken(t);
    return AuthUser.fromJson(u);
  }

  static Future<AuthUser?> me() async {
    final t = await token();
    if (t == null || t.isEmpty) return null;

    final res = await http.get(
      Uri.parse('$baseUrl/api/me'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $t',
      },
    );

    if (res.statusCode == 401) {
      await clearToken();
      return null;
    }

    if (res.statusCode != 200) {
      // Debug kalau perlu:
      // print('ME ERROR ${res.statusCode}: ${res.body}');
      return null;
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return AuthUser.fromJson(data);
  }

  static Future<void> logout() async {
    final t = await token();

    if (t != null && t.isNotEmpty) {
      await http.post(
        Uri.parse('$baseUrl/api/logout'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $t'},
      );
    }

    await clearToken();
  }
}
