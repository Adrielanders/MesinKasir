class UserAccount {
  final String username;
  final String pin;
  final String role; // 'admin' atau 'kasir'
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

class AuthStore {
  AuthStore._();

  static final List<UserAccount> users = [
    const UserAccount(username: 'admin', pin: '1234', role: 'admin'),
    const UserAccount(username: 'kasir1', pin: '1111', role: 'kasir'),
  ];

  static UserAccount? login(String username, String pin) {
    for (final u in users) {
      if (u.username == username && u.pin == pin && u.active) return u;
    }
    return null;
  }

  static void createKasir({required String username, required String pin}) {
    users.add(UserAccount(username: username, pin: pin, role: 'kasir'));
  }

  static void toggleActive(String username) {
    final idx = users.indexWhere((u) => u.username == username);
    if (idx == -1) return;
    users[idx] = users[idx].copyWith(active: !users[idx].active);
  }
}
