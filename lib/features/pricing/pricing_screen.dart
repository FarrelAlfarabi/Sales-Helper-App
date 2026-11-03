import 'package:flutter/material.dart';
import '../../core/help.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';

/// Pricing: a field rep records the shelf price of a product at an assigned
/// store. ASSUMPTION: the ViewLT deck names "Harga" but does not describe
/// it, so this is a simple price check (store, product, price, promo flag),
/// not a copy of ViewLT. Needs migration 20261026100000_price_reports.sql.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _product = TextEditingController();
  final _price = TextEditingController();
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _recent = [];
  String? _storeId;
  bool _promo = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _product.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uid = supabase.auth.currentUser!.id;
      final rows = await supabase
          .from('store_assignments')
          .select('stores(id, name, code)')
          .eq('employee_id', uid)
          .eq('is_active', true);
      final stores =
          rows.map((r) => r['stores'] as Map<String, dynamic>).toList();
      final recent = await supabase
          .from('price_reports')
          .select('product_name, price_idr, is_promo, created_at, stores(name)')
          .eq('employee_id', uid)
          .order('created_at', ascending: false)
          .limit(20);
      setState(() {
        _stores = stores;
        _recent = List<Map<String, dynamic>>.from(recent);
        _storeId ??= stores.isEmpty ? null : stores.first['id'] as String;
      });
    } catch (e) {
      setState(() => _error = 'Gagal memuat: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _storeId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await supabase.from('price_reports').insert({
        'employee_id': supabase.auth.currentUser!.id,
        'store_id': _storeId,
        'product_name': _product.text.trim(),
        'price_idr': int.parse(_price.text.trim()),
        'is_promo': _promo,
      });
      _product.clear();
      _price.clear();
      setState(() => _promo = false);
      await _load();
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final money = NumberFormat.decimalPattern('id');
    return Scaffold(
      appBar: AppBar(
          title: const Text('Harga'),
          actions: const [HelpButton(HelpTopic.pricing)],
        bottom: const HelpBar(HelpTopic.pricing),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_stores.isEmpty)
                  const Text('Belum ada toko yang ditugaskan kepadamu.')
                else
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _storeId,
                          decoration: const InputDecoration(labelText: 'Toko'),
                          items: [
                            for (final s in _stores)
                              DropdownMenuItem(
                                  value: s['id'] as String,
                                  child: Text('${s['name']} (${s['code']})')),
                          ],
                          onChanged: (v) => setState(() => _storeId = v),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _product,
                          decoration:
                              const InputDecoration(labelText: 'Produk'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Produk wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _price,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Harga rak (Rp)'),
                          validator: (v) =>
                              int.tryParse((v ?? '').trim()) == null
                                  ? 'Isi dengan bilangan bulat'
                                  : null,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Harga promo'),
                          value: _promo,
                          onChanged: (v) => setState(() => _promo = v),
                        ),
                        if (_error != null)
                          Text(_error!, style: TextStyle(color: cs.error)),
                        const SizedBox(height: 8),
                        FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(
                                _saving ? 'Menyimpan...' : 'Simpan harga')),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Text('Terbaru', style: Theme.of(context).textTheme.titleSmall),
                for (final r in _recent)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r['product_name'] as String),
                    subtitle: Text(
                        '${(r['stores'] as Map?)?['name'] ?? ''}${r['is_promo'] == true ? ' - promo' : ''}'),
                    trailing: Text('Rp ${money.format(r['price_idr'])}'),
                  ),
              ],
            ),
    );
  }
}
