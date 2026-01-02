class Product {
  final String id;
  final String name;
  final int price;

  const Product({required this.id, required this.name, required this.price});
}

class ProductStore {
  ProductStore._();

  static final List<Product> products = [
    const Product(id: 'p1', name: 'Es Teh', price: 5000),
    const Product(id: 'p2', name: 'Kopi Susu', price: 18000),
  ];

  static void add({required String name, required int price}) {
    final id = 'p${products.length + 1}';
    products.add(Product(id: id, name: name, price: price));
  }
}
