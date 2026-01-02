import 'package:flutter/material.dart';
import 'product_store.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  void addProduct() {
    final name = nameCtrl.text.trim();
    final priceText = priceCtrl.text.trim();
    final price = int.tryParse(priceText);

    if (name.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama & harga harus benar')),
      );
      return;
    }

    ProductStore.add(name: name, price: price);
    nameCtrl.clear();
    priceCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final products = ProductStore.products;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin - Produk')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama produk'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: 'Harga (angka)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: addProduct,
                child: const Text('Tambah Produk'),
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final p = products[i];
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text('Rp ${p.price}'),
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
