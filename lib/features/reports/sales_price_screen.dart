import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';

/// Penjualan dan harga, 30 hari terakhir, dirangkum dari isian sales.
/// Hanya baca. Untuk manajer dan admin.
class SalesPriceScreen extends StatefulWidget {
  const SalesPriceScreen({super.key});

  @override
  State<SalesPriceScreen> createState() => _SalesPriceScreenState();
}

class _SalesPriceScreenState extends State<SalesPriceScreen> {
  bool _loading = true;
  String? _error;
  int _units = 0;
  int _storesFilled = 0;
  int _promoStores = 0;
  List<MapEntry<String, int>> _byProduct = [];
  List<List<String>> _prices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final since = DateTime.now().subtract(const Duration(days: 30));
      final sinceDate = since.toIso8601String().substring(0, 10);
      final res = await Future.wait<dynamic>([
        supabase.from('sales_reports').select('store_id, product_name, units_sold').gte('sale_date', sinceDate).limit(5000),
        supabase
            .from('price_reports')
            .select('store_id, product_name, price_idr, is_promo')
            .gte('created_at', since.toUtc().toIso8601String())
            .limit(5000),
      ]);
      final sales = List<Map<String, dynamic>>.from(res[0] as List);
      final prices = List<Map<String, dynamic>>.from(res[1] as List);

      final byProduct = <String, int>{};
      final stores = <dynamic>{};
      var units = 0;
      for (final s in sales) {
        final u = (s['units_sold'] as num?)?.toInt() ?? 0;
        units += u;
        stores.add(s['store_id']);
        byProduct.update('${s['product_name']}', (v) => v + u, ifAbsent: () => u);
      }
      final top = byProduct.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      final money = NumberFormat.decimalPattern('id');
      final priceMap = <String, List<Map<String, dynamic>>>{};
      final promoStores = <dynamic>{};
      for (final p in prices) {
        priceMap.putIfAbsent('${p['product_name']}', () => []).add(p);
        if (p['is_promo'] == true) promoStores.add(p['store_id']);
      }
      final priceRows = <List<String>>[];
      priceMap.forEach((name, list) {
        final vals = list.map((e) => (e['price_idr'] as num).toInt()).toList()..sort();
        final promo = list.where((e) => e['is_promo'] == true).map((e) => e['store_id']).toSet().length;
        priceRows.add([name, 'Rp ${money.format(vals.first)}', 'Rp ${money.format(vals.last)}', promo == 0 ? '0' : '$promo toko']);
      });

      setState(() {
        _units = units;
        _storesFilled = stores.length;
        _promoStores = promoStores.length;
        _byProduct = top.take(10).toList();
        _prices = priceRows.take(10).toList();
      });
    } catch (e) {
      setState(() => _error = 'Gagal memuat: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.decimalPattern('id');

    Widget tile(String l, String v) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              Text(v, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
        );

    Widget table(List<String> heads, List<List<String>> rows) => Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              for (var i = 0; i < heads.length; i++)
                Expanded(flex: i == 0 ? 3 : 2, child: Text(heads[i], style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600))),
            ]),
          ),
          for (var r = 0; r < rows.length; r++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: r.isEven ? cs.surfaceContainerHighest : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                for (var i = 0; i < rows[r].length; i++)
                  Expanded(flex: i == 0 ? 3 : 2, child: Text(rows[r][i], style: t.bodyMedium)),
              ]),
            ),
        ]);

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                children: [
                  Text('Penjualan dan harga', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Diisi oleh sales. 30 hari terakhir.', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 18),
                  if (_error != null)
                    Text(_error!, style: TextStyle(color: cs.error))
                  else ...[
                    Row(children: [
                      tile('Unit terjual', fmt.format(_units)),
                      const SizedBox(width: 8),
                      tile('Toko mengisi', '$_storesFilled'),
                      const SizedBox(width: 8),
                      tile('Toko dengan promo', '$_promoStores'),
                    ]),
                    const SizedBox(height: 24),
                    Text('Unit terjual per produk', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _byProduct.isEmpty
                        ? Text('Belum ada data penjualan.', style: TextStyle(color: cs.onSurfaceVariant))
                        : table(['Produk', 'Unit'], [for (final e in _byProduct) [e.key, fmt.format(e.value)]]),
                    const SizedBox(height: 24),
                    Text('Harga rak terlihat', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _prices.isEmpty
                        ? Text('Belum ada laporan harga.', style: TextStyle(color: cs.onSurfaceVariant))
                        : table(['Produk', 'Terendah', 'Tertinggi', 'Promo'], _prices),
                  ],
                ],
              ),
            ),
    );
  }
}
