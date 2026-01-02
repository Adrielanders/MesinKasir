import 'package:flutter/material.dart';
import 'product_store.dart';

class CartItem {
  final Product product;
  int qty;

  CartItem({required this.product, required this.qty});

  int get subtotal => product.price * qty;
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final Map<String, CartItem> cart = {};

  List<Product> get products => ProductStore.products;

  int get total => cart.values.fold(0, (sum, item) => sum + item.subtotal);

  void addToCart(Product p) {
    setState(() {
      final existing = cart[p.id];
      if (existing == null) {
        cart[p.id] = CartItem(product: p, qty: 1);
      } else {
        existing.qty += 1;
      }
    });
  }

  void decFromCart(Product p) {
    setState(() {
      final existing = cart[p.id];
      if (existing == null) return;

      if (existing.qty <= 1) {
        cart.remove(p.id);
      } else {
        existing.qty -= 1;
      }
    });
  }

  void clearCart() {
    setState(() => cart.clear());
  }

  String idr(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write('.');
    }
    return 'Rp $buf';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    final productPanel = _ProductPanel(
      products: products,
      qtyOf: (id) => cart[id]?.qty ?? 0,
      onAdd: addToCart,
      onDec: decFromCart,
      idr: idr,
    );

    final cartPanel = _CartPanel(
      items: cart.values.toList(),
      total: total,
      onAdd: addToCart,
      onDec: decFromCart,
      onClear: clearCart,
      onPay: () {
        if (total == 0) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Pembayaran'),
            content: Text('Total: ${idr(total)}\n\n(Nanti kita bikin Payment Screen)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  clearCart();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaksi selesai (dummy)')),
                  );
                },
                child: const Text('Selesaikan'),
              ),
            ],
          ),
        );
      },
      idr: idr,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS'),
        actions: [
          TextButton(
            onPressed: cart.isEmpty ? null : clearCart,
            child: const Text('Clear'),
          ),
        ],
      ),
      body: products.isEmpty
          ? const Center(child: Text('Belum ada produk. Tambah dulu dari Admin.'))
          : isWide
              ? Row(
                  children: [
                    Expanded(flex: 3, child: productPanel),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 360, child: cartPanel),
                  ],
                )
              : Stack(
                  children: [
                    productPanel,
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: ElevatedButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => DraggableScrollableSheet(
                              expand: false,
                              initialChildSize: 0.85,
                              minChildSize: 0.4,
                              maxChildSize: 0.95,
                              builder: (context, scroll) => SingleChildScrollView(
                                controller: scroll,
                                child: cartPanel,
                              ),
                            ),
                          );
                        },
                        child: Text('Keranjang • ${idr(total)}'),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ProductPanel extends StatelessWidget {
  final List<Product> products;
  final int Function(String id) qtyOf;
  final void Function(Product p) onAdd;
  final void Function(Product p) onDec;
  final String Function(int value) idr;

  const _ProductPanel({
    required this.products,
    required this.qtyOf,
    required this.onAdd,
    required this.onDec,
    required this.idr,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        final qty = qtyOf(p.id);

        return Card(
          child: InkWell(
            onTap: () => onAdd(p),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: Icon(
                        Icons.fastfood,
                        size: 46,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(idr(p.price), style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (qty > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Theme.of(context).colorScheme.primaryContainer,
                          ),
                          child: Text('x$qty'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton(
                        onPressed: qty == 0 ? null : () => onDec(p),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => onAdd(p),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CartPanel extends StatelessWidget {
  final List<CartItem> items;
  final int total;
  final void Function(Product p) onAdd;
  final void Function(Product p) onDec;
  final VoidCallback onClear;
  final VoidCallback onPay;
  final String Function(int value) idr;

  const _CartPanel({
    required this.items,
    required this.total,
    required this.onAdd,
    required this.onDec,
    required this.onClear,
    required this.onPay,
    required this.idr,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Keranjang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              TextButton(onPressed: items.isEmpty ? null : onClear, child: const Text('Clear')),
            ],
          ),
          const Divider(),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Belum ada item')),
            )
          else
            ...items.map((item) {
              return ListTile(
                dense: true,
                title: Text(item.product.name),
                subtitle: Text(idr(item.product.price)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => onDec(item.product),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${item.qty}'),
                    IconButton(
                      onPressed: () => onAdd(item.product),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              );
            }),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(idr(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: total == 0 ? null : onPay,
            child: const Text('Bayar'),
          ),
        ],
      ),
    );
  }
}
