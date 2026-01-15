import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'auth_store.dart';

class _Cat {
  final int id;
  final String name;
  final bool active;

  const _Cat({required this.id, required this.name, required this.active});

  factory _Cat.fromJson(Map<String, dynamic> json) {
    final rawActive = json['active'];
    final bool active = rawActive is bool
        ? rawActive
        : rawActive is int
        ? rawActive == 1
        : (rawActive?.toString().toLowerCase() == '1' ||
              rawActive?.toString().toLowerCase() == 'true');

    return _Cat(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      active: active,
    );
  }
}

class _Prod {
  final int id;
  final int categoryId;
  final String categoryName;
  final String name;
  final int price;
  final int qty;
  final bool active;

  const _Prod({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.price,
    required this.qty,
    required this.active,
  });

  factory _Prod.fromJson(Map<String, dynamic> json) {
    final rawActive = json['active'];
    final bool active = rawActive is bool
        ? rawActive
        : rawActive is int
        ? rawActive == 1
        : (rawActive?.toString().toLowerCase() == '1' ||
              rawActive?.toString().toLowerCase() == 'true');

    final cat = (json['category'] is Map)
        ? Map<String, dynamic>.from(json['category'] as Map)
        : null;

    return _Prod(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      categoryId: (json['category_id'] is int)
          ? json['category_id'] as int
          : int.tryParse('${json['category_id']}') ?? 0,
      categoryName: (cat?['name'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] is int)
          ? json['price'] as int
          : int.tryParse('${json['price']}') ?? 0,
      qty: (json['qty'] is int)
          ? json['qty'] as int
          : int.tryParse('${json['qty']}') ?? 0,
      active: active,
    );
  }

  _Prod copyWith({
    int? id,
    int? categoryId,
    String? categoryName,
    String? name,
    int? price,
    int? qty,
    bool? active,
  }) {
    return _Prod(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      active: active ?? this.active,
    );
  }
}

class _Stock {
  final int id;
  final String name;
  final String unit;
  final bool active;

  const _Stock({
    required this.id,
    required this.name,
    required this.unit,
    required this.active,
  });

  factory _Stock.fromJson(Map<String, dynamic> json) {
    final rawActive = json['active'];
    final bool active = rawActive is bool
        ? rawActive
        : rawActive is int
        ? rawActive == 1
        : (rawActive?.toString().toLowerCase() == '1' ||
              rawActive?.toString().toLowerCase() == 'true');

    return _Stock(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      unit: (json['unit'] ?? 'pcs').toString(),
      active: active,
    );
  }
}

class _ProductStockLink {
  final _Stock stock;
  final int qty;
  final bool active;

  const _ProductStockLink({
    required this.stock,
    required this.qty,
    required this.active,
  });

  factory _ProductStockLink.fromJson(Map<String, dynamic> json) {
    final pivot = (json['pivot'] is Map)
        ? Map<String, dynamic>.from(json['pivot'] as Map)
        : const <String, dynamic>{};

    final rawActive = pivot['active'];
    final bool pActive = rawActive is bool
        ? rawActive
        : rawActive is int
        ? rawActive == 1
        : (rawActive?.toString().toLowerCase() == '1' ||
              rawActive?.toString().toLowerCase() == 'true');

    return _ProductStockLink(
      stock: _Stock.fromJson(json),
      qty: (pivot['qty'] is int)
          ? pivot['qty'] as int
          : int.tryParse('${pivot['qty']}') ?? 0,
      active: pActive,
    );
  }
}

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '0');

  final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  int? _selectedCategoryId;

  final List<_Cat> _categories = [];
  bool _loadingCats = true;

  final List<_Prod> _products = [];
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    await _fetchCategories();
    await _fetchProducts();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

  int? _parsePriceFrom(String input) {
    final raw = input.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw);
  }

  int? _parsePrice() => _parsePriceFrom(priceCtrl.text);

  int? _parseQtyFrom(String input) {
    final raw = input.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw);
  }

  int? _parseQty() => _parseQtyFrom(qtyCtrl.text);

  dynamic _tryJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  String _errMsg(http.Response res) {
    final body = _tryJson(res.body);
    if (body is Map) {
      final msg = body['message'];
      if (msg != null && msg.toString().trim().isNotEmpty)
        return msg.toString();
      final errors = body['errors'];
      if (errors is Map) {
        for (final v in errors.values) {
          if (v is List && v.isNotEmpty) return v.first.toString();
          if (v != null) return v.toString();
        }
      }
    }
    return 'HTTP ${res.statusCode}';
  }

  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final t = await AuthStore.token();
    final h = <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    return h;
  }

  String _catNameById(int id) {
    for (final c in _categories) {
      if (c.id == id) return c.name;
    }
    return '';
  }

  Future<void> _fetchCategories() async {
    if (mounted) setState(() => _loadingCats = true);

    final res = await http.get(
      Uri.parse('${AuthStore.baseUrl}/api/categories'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
        setState(() => _loadingCats = false);
      }
      return;
    }

    final body = _tryJson(res.body);
    final list = body is List ? body : (body is Map ? body['data'] : null);

    _categories.clear();
    if (list is List) {
      _categories.addAll(
        list
            .map((e) => _Cat.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((c) => c.active)
            .toList(),
      );
      _categories.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    if (_selectedCategoryId != null &&
        !_categories.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = null;
    }

    if (mounted) setState(() => _loadingCats = false);
  }

  Future<void> _fetchProducts() async {
    if (mounted) setState(() => _loadingProducts = true);

    final res = await http.get(
      Uri.parse('${AuthStore.baseUrl}/api/products?per_page=100'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
        setState(() => _loadingProducts = false);
      }
      return;
    }

    final body = _tryJson(res.body);

    dynamic items;
    if (body is Map) {
      final data = body['data'];
      items = (data is Map) ? data['data'] : data;
    } else {
      items = body;
    }

    _products.clear();
    if (items is List) {
      _products.addAll(
        items
            .map((e) => _Prod.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
    }

    if (mounted) setState(() => _loadingProducts = false);
  }

  Future<void> addProduct() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = nameCtrl.text.trim();
    final price = _parsePrice()!;
    final qty = _parseQty() ?? 0;
    final categoryId = _selectedCategoryId!;

    final res = await http.post(
      Uri.parse('${AuthStore.baseUrl}/api/products'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'category_id': categoryId,
        'name': name,
        'price': price,
        'qty': qty,
        'active': true,
      }),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return;
    }

    nameCtrl.clear();
    priceCtrl.clear();
    qtyCtrl.text = '0';
    if (mounted) setState(() => _selectedCategoryId = null);

    await _fetchProducts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk berhasil ditambahkan ✅')),
      );
    }
  }

  Future<_Prod?> _fetchProductDetail(int id) async {
    final res = await http.get(
      Uri.parse('${AuthStore.baseUrl}/api/products/$id'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return null;
    }

    final body = _tryJson(res.body);
    final data = (body is Map) ? body['data'] : null;
    if (data is Map) return _Prod.fromJson(Map<String, dynamic>.from(data));
    return null;
  }

  Future<bool> _updateProduct(
    _Prod p, {
    int? categoryId,
    String? name,
    int? price,
    int? qty,
    bool? active,
  }) async {
    final payload = <String, dynamic>{};
    if (categoryId != null) payload['category_id'] = categoryId;
    if (name != null) payload['name'] = name;
    if (price != null) payload['price'] = price;
    if (qty != null) payload['qty'] = qty;
    if (active != null) payload['active'] = active;

    final res = await http.patch(
      Uri.parse('${AuthStore.baseUrl}/api/products/${p.id}'),
      headers: await _authHeaders(json: true),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return false;
    }

    await _fetchProducts();
    return true;
  }

  Future<bool> _deleteProduct(int id) async {
    final res = await http.delete(
      Uri.parse('${AuthStore.baseUrl}/api/products/$id'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return false;
    }

    await _fetchProducts();
    return true;
  }

  Future<List<_Stock>> _fetchAllStocks() async {
    final res = await http.get(
      Uri.parse('${AuthStore.baseUrl}/api/products/stocks-master'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return [];
    }

    final body = _tryJson(res.body);
    final list = body is List ? body : (body is Map ? body['data'] : null);

    if (list is List) {
      return list
          .map((e) => _Stock.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((s) => s.active)
          .toList();
    }
    return [];
  }

  Future<void> _openProductDetail(_Prod p) async {
    final detail = await _fetchProductDetail(p.id);
    if (!mounted) return;
    if (detail == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ProductDetailScreen(
          product: detail,
          categories: _categories,
          rupiah: _rupiah,
          loadAllStocks: _fetchAllStocks,
          onPatchProduct: (payload) async {
            final ok = await _updateProduct(
              detail,
              categoryId: payload['category_id'] as int?,
              name: payload['name'] as String?,
              price: payload['price'] as int?,
              qty: payload['qty'] as int?,
              active: payload['active'] as bool?,
            );
            return ok;
          },
          onDeleteProduct: () async => await _deleteProduct(detail.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Produk'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: (_loadingCats || _loadingProducts)
                ? null
                : () async => await _initLoad(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _HeaderCard(
                    title: 'Kelola Produk',
                    subtitle:
                        'Tambah produk baru dan lihat daftar produk di bawah.',
                    icon: Icons.inventory_2_rounded,
                  ),
                  const SizedBox(height: 14),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Tambah Produk',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: _selectedCategoryId,
                              items: _categories
                                  .map(
                                    (c) => DropdownMenuItem<int>(
                                      value: c.id,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _loadingCats
                                  ? null
                                  : (v) =>
                                        setState(() => _selectedCategoryId = v),
                              decoration: InputDecoration(
                                labelText: 'Kategori',
                                prefixIcon: const Icon(Icons.category_rounded),
                                suffixIcon: _loadingCats
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              validator: (v) =>
                                  (v == null) ? 'Kategori wajib dipilih' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: nameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Nama produk',
                                hintText: 'Contoh: Kopi Susu 250ml',
                                prefixIcon: const Icon(Icons.sell_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) return 'Nama produk wajib diisi';
                                if (s.length < 3) return 'Nama terlalu pendek';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _ThousandSeparatorInputFormatter(),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Harga',
                                hintText: 'Contoh: 15000',
                                prefixIcon: const Icon(Icons.payments_rounded),
                                prefixText: 'Rp ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                helperText:
                                    'Masukkan angka tanpa titik/koma (akan diformat otomatis).',
                              ),
                              validator: (_) {
                                final p = _parsePrice();
                                if (p == null) return 'Harga wajib diisi';
                                if (p <= 0) return 'Harga harus lebih dari 0';
                                if (p > 1000000000)
                                  return 'Harga terlalu besar';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Qty (produk)',
                                hintText: 'Contoh: 10',
                                prefixIcon: const Icon(Icons.inventory_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              validator: (_) {
                                final q = _parseQty();
                                if (q == null) return 'Qty wajib diisi';
                                if (q < 0) return 'Qty tidak boleh minus';
                                if (q > 1000000000) return 'Qty terlalu besar';
                                return null;
                              },
                              onFieldSubmitted: (_) => addProduct(),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: addProduct,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Tambah Produk'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Daftar Produk',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (_loadingProducts)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Chip(
                          label: Text('${products.length} item'),
                          avatar: const Icon(Icons.list_rounded, size: 18),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ]),
              ),
            ),
            if (!_loadingProducts && products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyState(
                    title: 'Belum ada produk',
                    subtitle:
                        'Tambahkan produk pertama kamu dari form di atas.',
                    icon: Icons.inbox_rounded,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: products.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = products[i];
                        final catLabel = p.categoryName.isNotEmpty
                            ? p.categoryName
                            : _catNameById(p.categoryId);
                        final catText = catLabel.isNotEmpty
                            ? catLabel
                            : 'Kategori #${p.categoryId}';
                        return ListTile(
                          onTap: () => _openProductDetail(p),
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${_rupiah.format(p.price)} • $catText • Qty ${p.qty}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailScreen extends StatefulWidget {
  const _ProductDetailScreen({
    required this.product,
    required this.categories,
    required this.rupiah,
    required this.loadAllStocks,
    required this.onPatchProduct,
    required this.onDeleteProduct,
  });

  final _Prod product;
  final List<_Cat> categories;
  final NumberFormat rupiah;
  final Future<List<_Stock>> Function() loadAllStocks;
  final Future<bool> Function(Map<String, dynamic> payload) onPatchProduct;
  final Future<bool> Function() onDeleteProduct;

  @override
  State<_ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<_ProductDetailScreen> {
  late _Prod _p;

  final List<_ProductStockLink> _links = [];
  bool _loadingLinks = true;

  @override
  void initState() {
    super.initState();
    _p = widget.product;
    _fetchProductStocks();
  }

  dynamic _tryJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  String _errMsg(http.Response res) {
    final body = _tryJson(res.body);
    if (body is Map) {
      final msg = body['message'];
      if (msg != null && msg.toString().trim().isNotEmpty)
        return msg.toString();
      final errors = body['errors'];
      if (errors is Map) {
        for (final v in errors.values) {
          if (v is List && v.isNotEmpty) return v.first.toString();
          if (v != null) return v.toString();
        }
      }
    }
    return 'HTTP ${res.statusCode}';
  }

  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final t = await AuthStore.token();
    final h = <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    return h;
  }

  Future<void> _fetchProductStocks() async {
    if (mounted) setState(() => _loadingLinks = true);

    final res = await http.get(
      Uri.parse('${AuthStore.baseUrl}/api/products/${_p.id}/stocks'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
        setState(() => _loadingLinks = false);
      }
      return;
    }

    final body = _tryJson(res.body);
    final list = body is List ? body : (body is Map ? body['data'] : null);

    _links.clear();
    if (list is List) {
      _links.addAll(
        list
            .map(
              (e) => _ProductStockLink.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
    }

    if (mounted) setState(() => _loadingLinks = false);
  }

  Future<bool> _attachStock(int stockId, int qty) async {
    final res = await http.post(
      Uri.parse('${AuthStore.baseUrl}/api/products/${_p.id}/stocks'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({'stock_id': stockId, 'qty': qty, 'active': true}),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return false;
    }
    return true;
  }

  Future<bool> _updateStockQty(int stockId, int qty) async {
    final res = await http.patch(
      Uri.parse('${AuthStore.baseUrl}/api/products/${_p.id}/stocks/$stockId'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({'qty': qty}),
    );

    if (res.statusCode != 200) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return false;
    }
    return true;
  }

  Future<bool> _detachStock(int stockId) async {
    final res = await http.delete(
      Uri.parse('${AuthStore.baseUrl}/api/products/${_p.id}/stocks/$stockId'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return false;
    }
    return true;
  }

  Future<void> _openConfigureStocks() async {
    final all = await widget.loadAllStocks();
    if (!mounted) return;

    final result = await showDialog<_ConfigureStocksResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _ConfigureProductStocksDialog(allStocks: all, attachedLinks: _links),
    );

    if (result == null) return;

    final selectedIds = result.selectedQty.keys.toSet();
    final currentlyAttachedIds = _links.map((e) => e.stock.id).toSet();

    for (final id in selectedIds) {
      final newQty = result.selectedQty[id] ?? 0;
      final existing = _links.where((e) => e.stock.id == id).toList();
      if (existing.isEmpty) {
        await _attachStock(id, newQty);
      } else {
        final oldQty = existing.first.qty;
        if (oldQty != newQty) {
          await _updateStockQty(id, newQty);
        }
      }
    }

    for (final id in currentlyAttachedIds.difference(selectedIds)) {
      await _detachStock(id);
    }

    await _fetchProductStocks();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Stock produk tersimpan ✅')));
  }

  Future<void> _editProduct() async {
    final result = await showDialog<_Prod>(
      context: context,
      builder: (_) =>
          _EditProductDialog(product: _p, categories: widget.categories),
    );

    if (result == null) return;

    final payload = <String, dynamic>{
      'category_id': result.categoryId,
      'name': result.name,
      'price': result.price,
      'qty': result.qty,
      'active': result.active,
    };

    final ok = await widget.onPatchProduct(payload);
    if (!ok) return;

    if (!mounted) return;
    setState(() => _p = result);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Produk berhasil diupdate ✅')));
  }

  Future<void> _deleteProduct() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text('Hapus "${_p.name}" dari daftar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (yes != true) return;

    final ok = await widget.onDeleteProduct();
    if (!ok) return;

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Produk berhasil dihapus ✅')));
  }

  String _unitText(_Stock s) {
    return s.unit;
  }

  @override
  Widget build(BuildContext context) {
    final cat = _p.categoryName.isNotEmpty
        ? _p.categoryName
        : (widget.categories.where((e) => e.id == _p.categoryId).isNotEmpty
              ? widget.categories.firstWhere((e) => e.id == _p.categoryId).name
              : 'Kategori #${_p.categoryId}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _editProduct,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            onPressed: _deleteProduct,
            icon: const Icon(Icons.delete_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _p.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Kategori', value: cat),
                    _InfoRow(
                      label: 'Harga',
                      value: widget.rupiah.format(_p.price),
                    ),
                    _InfoRow(label: 'Qty (produk)', value: '${_p.qty}'),
                    _InfoRow(
                      label: 'Status',
                      value: _p.active ? 'Aktif' : 'Nonaktif',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _editProduct,
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit Produk'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Stock untuk Produk Ini',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _loadingLinks
                              ? null
                              : _openConfigureStocks,
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Atur Stock'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loadingLinks)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_links.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Belum ada stock yang dipakai produk ini. Tekan "Atur Stock".',
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _links.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final l = _links[i];
                          return ListTile(
                            title: Text(
                              l.stock.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              'Butuh: ${l.qty} ${_unitText(l.stock)}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _openConfigureStocks,
                          );
                        },
                      ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _fetchProductStocks,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigureStocksResult {
  final Map<int, int> selectedQty; // stockId -> qtyNeeded
  const _ConfigureStocksResult(this.selectedQty);
}

class _ConfigureProductStocksDialog extends StatefulWidget {
  const _ConfigureProductStocksDialog({
    required this.allStocks,
    required this.attachedLinks,
  });

  final List<_Stock> allStocks;
  final List<_ProductStockLink> attachedLinks;

  @override
  State<_ConfigureProductStocksDialog> createState() =>
      _ConfigureProductStocksDialogState();
}

class _ConfigureProductStocksDialogState
    extends State<_ConfigureProductStocksDialog> {
  final _search = TextEditingController();
  final Map<int, bool> _checked = {};
  final Map<int, TextEditingController> _qtyCtrls = {};

  @override
  void initState() {
    super.initState();
    final attachedMap = {
      for (final l in widget.attachedLinks) l.stock.id: l.qty,
    };

    for (final s in widget.allStocks) {
      final isOn = attachedMap.containsKey(s.id);
      _checked[s.id] = isOn;
      _qtyCtrls[s.id] = TextEditingController(
        text: (attachedMap[s.id] ?? 1).toString(),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _parseQty(TextEditingController c) {
    final raw = c.text.replaceAll(RegExp(r'[^0-9]'), '');
    final v = int.tryParse(raw) ?? 0;
    return v < 0 ? 0 : v;
  }

  String _unitText(_Stock s) {
    return s.unit;
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final list =
        widget.allStocks
            .where((s) => s.active)
            .where((s) => q.isEmpty ? true : s.name.toLowerCase().contains(q))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return AlertDialog(
      title: const Text('Pilih Stock & Kebutuhan'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Cari stock',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = list[i];
                  final checked = _checked[s.id] ?? false;
                  final ctrl = _qtyCtrls[s.id]!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: checked,
                          onChanged: (v) =>
                              setState(() => _checked[s.id] = v ?? false),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Unit: ${_unitText(s)}',
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                              if (checked) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: ctrl,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        decoration: InputDecoration(
                                          labelText: 'Kebutuhan per 1 produk',
                                          hintText: 'Contoh: 1',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      height: 48,
                                      width: 48,
                                      child: FilledButton(
                                        onPressed: () {
                                          final v = _parseQty(ctrl);
                                          ctrl.text = (v <= 0 ? 1 : v)
                                              .toString();
                                        },
                                        style: FilledButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: const Icon(Icons.check_rounded),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Centang stock yang dipakai, lalu isi “kebutuhan per 1 produk”.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final Map<int, int> out = {};
            _checked.forEach((id, on) {
              if (on) {
                final ctrl = _qtyCtrls[id]!;
                var qty = _parseQty(ctrl);
                if (qty <= 0) qty = 1;
                out[id] = qty;
              }
            });
            Navigator.pop(context, _ConfigureStocksResult(out));
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _EditProductDialog extends StatefulWidget {
  const _EditProductDialog({required this.product, required this.categories});

  final _Prod product;
  final List<_Cat> categories;

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _price;
  late TextEditingController _qty;
  late int _categoryId;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.product.name);
    _price = TextEditingController(text: widget.product.price.toString());
    _qty = TextEditingController(text: widget.product.qty.toString());
    _categoryId = widget.product.categoryId;
    _active = widget.product.active;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _qty.dispose();
    super.dispose();
  }

  int? _parseInt(String s) {
    final raw = s.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Produk'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: _categoryId,
                  items: widget.categories
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _categoryId = v ?? _categoryId),
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  validator: (v) => (v == null) ? 'Kategori wajib' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nama'),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Nama wajib';
                    if (s.length < 3) return 'Nama terlalu pendek';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Harga'),
                  validator: (_) {
                    final p = _parseInt(_price.text);
                    if (p == null) return 'Harga wajib';
                    if (p <= 0) return 'Harga harus > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Qty (produk)'),
                  validator: (_) {
                    final q = _parseInt(_qty.text);
                    if (q == null) return 'Qty wajib';
                    if (q < 0) return 'Qty tidak boleh minus';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: const Text('Aktif'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final price = _parseInt(_price.text)!;
            final qty = _parseInt(_qty.text)!;
            Navigator.pop(
              context,
              widget.product.copyWith(
                categoryId: _categoryId,
                name: _name.text.trim(),
                price: price,
                qty: qty,
                active: _active,
                categoryName: '',
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withOpacity(0.65);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: muted)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withOpacity(0.7);

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: muted),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');

    final number = int.parse(digits);
    final formatted = NumberFormat(
      '#,###',
      'id_ID',
    ).format(number).replaceAll(',', '.');

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
