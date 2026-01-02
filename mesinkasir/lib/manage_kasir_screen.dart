import 'package:flutter/material.dart';
import 'auth_store.dart';

class ManageKasirScreen extends StatefulWidget {
  const ManageKasirScreen({super.key});

  @override
  State<ManageKasirScreen> createState() => _ManageKasirScreenState();
}

class _ManageKasirScreenState extends State<ManageKasirScreen> {
  final userCtrl = TextEditingController();
  final pinCtrl = TextEditingController();

  @override
  void dispose() {
    userCtrl.dispose();
    pinCtrl.dispose();
    super.dispose();
  }

  void create() {
    final u = userCtrl.text.trim();
    final p = pinCtrl.text.trim();
    if (u.isEmpty || p.isEmpty) return;

    AuthStore.createKasir(username: u, pin: p);
    userCtrl.clear();
    pinCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final kasirs = AuthStore.users.where((u) => u.role == 'kasir').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kasir')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(labelText: 'Username kasir'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              decoration: const InputDecoration(labelText: 'PIN kasir'),
              keyboardType: TextInputType.number,
              obscureText: true,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: create,
                child: const Text('Buat Akun Kasir'),
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: kasirs.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final k = kasirs[i];
                  return ListTile(
                    title: Text(k.username),
                    subtitle: Text(k.active ? 'Aktif' : 'Nonaktif'),
                    trailing: Switch(
                      value: k.active,
                      onChanged: (_) {
                        AuthStore.toggleActive(k.username);
                        setState(() {});
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
