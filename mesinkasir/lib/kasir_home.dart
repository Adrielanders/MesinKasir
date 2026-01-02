import 'package:flutter/material.dart';
import 'pos_screen.dart';

class KasirHome extends StatelessWidget {
  const KasirHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kasir')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PosScreen()),
                );
              },
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Mulai Transaksi'),
            ),
          ],
        ),
      ),
    );
  }
}
