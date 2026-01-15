import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'auth_store.dart';

class _StockItem {
  final int id;
  final String name;
  final int qty;
  final int buyPrice;
  final bool active;

  const _StockItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.buyPrice,
    required this.active,
  });

  factory _StockItem.fromJson(Map<String, dynamic> json) {
    final rawActive = json['active'];
    final bool active = rawActive is bool
        ? rawActive
        : rawActive is int
            ? rawActive == 1
            : (rawActive?.toString().toLowerCase() == '1' ||
                rawActive?.toString().toLowerCase() == 'true');

    return _StockItem(
      id: (json['id'] is int) ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      qty: (json['qty'] is int) ? json['qty'] as int : int.tryParse('${json['qty']}') ?? 0,
      buyPrice: (json['buy_price'] is int) ? json['buy_price'] as int : int.tryParse('${json['buy_price']}') ?? 0,
      active: active,
    );
  }
}

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _loading = true;
  final List<_StockItem> _stocks = [];

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
      if (msg != null && msg.toString().trim().isNotEmpty) return msg.toString();
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

  @override
  void initState() {
    super.initState();
    _fetchStocks();
  }

  Future<void> _fetchStocks() async {
    if (mounted) setState(() => _loading = true);

    final res = await http.get(
      Uri.parse('${AuthStore.baseUrl}/api/stocks'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      setState(() => _loading = false);
      return;
    }

    final body = _tryJson(res.body);
    final list = body is List ? body : (body is Map ? body['data'] : null);

    _stocks.clear();
    if (list is List) {
      _stocks.addAll(list.map((e) => _StockItem.fromJson(Map<String, dynamic>.from(e as Map))).toList());
      _stocks.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<bool> _updateStock(int id, {int? qty, int? buyPrice, bool? active, String? name}) async {
    final payload = <String, dynamic>{};
    if (qty != null) payload['qty'] = qty;
    if (buyPrice != null) payload['buy_price'] = buyPrice;
    if (active != null) payload['active'] = active;
    if (name != null) payload['name'] = name;

    final res = await http.patch(
      Uri.parse('${AuthStore.baseUrl}/api/stocks/$id'),
      headers: await _authHeaders(json: true),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return false;
    }

    await _fetchStocks();
    return true;
  }

  Future<bool> _createStock({
    required String name,
    required int qty,
    required int buyPrice,
    required bool active,
  }) async {
    final res = await http.post(
      Uri.parse('${AuthStore.baseUrl}/api/stocks'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'name': name,
        'qty': qty,
        'buy_price': buyPrice,
        'active': active,
      }),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return false;
    }

    await _fetchStocks();
    return true;
  }

  Future<bool> _deleteStock(int id) async {
    final res = await http.delete(
      Uri.parse('${AuthStore.baseUrl}/api/stocks/$id'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return false;
    }

    await _fetchStocks();
    return true;
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<_CreateStockResult>(
      context: context,
      builder: (_) => const _CreateStockDialog(),
    );

    if (result == null) return;

    final ok = await _createStock(
      name: result.name,
      qty: result.qty,
      buyPrice: result.buyPrice,
      active: result.active,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock berhasil dibuat ✅')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok (API)'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loading ? null : _fetchStocks,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _stocks.isEmpty
                ? const Center(child: Text('Belum ada stock'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _stocks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final s = _stocks[i];
                      return _StockTile(
                        name: s.name,
                        buyPriceText: rupiah.format(s.buyPrice),
                        qty: s.qty,
                        active: s.active,
                        onSet: (qty) => _updateStock(s.id, qty: qty),
                        onPlus: () => _updateStock(s.id, qty: s.qty + 1),
                        onMinus: () => _updateStock(s.id, qty: (s.qty - 1) < 0 ? 0 : (s.qty - 1)),
                        onToggleActive: (v) => _updateStock(s.id, active: v),
                        onDelete: () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Hapus stock?'),
                              content: Text('Hapus "${s.name}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
                              ],
                            ),
                          );
                          if (yes == true) {
                            await _deleteStock(s.id);
                          }
                        },
                      );
                    },
                  ),
      ),
    );
  }
}

class _StockTile extends StatefulWidget {
  const _StockTile({
    required this.name,
    required this.buyPriceText,
    required this.qty,
    required this.active,
    required this.onSet,
    required this.onPlus,
    required this.onMinus,
    required this.onToggleActive,
    required this.onDelete,
  });

  final String name;
  final String buyPriceText;
  final int qty;
  final bool active;
  final ValueChanged<int> onSet;
  final VoidCallback onPlus;
  final VoidCallback onMinus;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;

  @override
  State<_StockTile> createState() => _StockTileState();
}

class _StockTileState extends State<_StockTile> {
  late final TextEditingController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = TextEditingController(text: widget.qty.toString());
  }

  @override
  void didUpdateWidget(covariant _StockTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qty != widget.qty) ctrl.text = widget.qty.toString();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  int _parseQty() {
    final raw = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final qty = widget.qty;
    final muted = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(child: Text(qty.toString())),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                      Switch(value: widget.active, onChanged: widget.onToggleActive),
                      IconButton(onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline_rounded)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Harga beli: ${widget.buyPriceText}', style: TextStyle(color: muted)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Qty',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onSubmitted: (_) => widget.onSet(_parseQty()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => widget.onSet(_parseQty()),
                        child: const Text('Set'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                IconButton(onPressed: widget.onPlus, icon: const Icon(Icons.add_circle_outline_rounded)),
                IconButton(onPressed: widget.onMinus, icon: const Icon(Icons.remove_circle_outline_rounded)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateStockResult {
  final String name;
  final int qty;
  final int buyPrice;
  final bool active;

  const _CreateStockResult({
    required this.name,
    required this.qty,
    required this.buyPrice,
    required this.active,
  });
}

class _CreateStockDialog extends StatefulWidget {
  const _CreateStockDialog();

  @override
  State<_CreateStockDialog> createState() => _CreateStockDialogState();
}

class _CreateStockDialogState extends State<_CreateStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _qty = TextEditingController(text: '0');
  final _buy = TextEditingController(text: '0');
  bool _active = true;

  int _parseInt(TextEditingController c) {
    final raw = c.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _buy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Stock'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nama stock'),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Nama wajib';
                    if (s.length < 2) return 'Nama terlalu pendek';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Qty'),
                  validator: (_) {
                    final q = _parseInt(_qty);
                    if (q < 0) return 'Qty tidak boleh minus';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _buy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Harga beli'),
                  validator: (_) {
                    final p = _parseInt(_buy);
                    if (p < 0) return 'Harga beli tidak boleh minus';
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _CreateStockResult(
                name: _name.text.trim(),
                qty: _parseInt(_qty),
                buyPrice: _parseInt(_buy),
                active: _active,
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
