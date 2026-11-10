import 'package:flutter/material.dart';
import '../../core/help.dart';
import 'package:intl/intl.dart';

import '../../core/product_field.dart';
import '../../core/supabase_client.dart';

/// Sales entry: a rep records units sold for a product at an assigned store
/// on a date. This is the data the AI sales insights read, so it exists
/// because the app had no sales numbers at all. ASSUMPTION: units per
/// product per day is enough to start; revenue/price can be added later.
class SalesEntryScreen extends StatefulWidget {
  const SalesEntryScreen({super.key, this.initialStoreId});

  /// Toko yang sudah dipilih (dibuka dari alur kunjungan toko).
  final String? initialStoreId;

  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> with SafeSetState<SalesEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _product = TextEditingController();
  final _units = TextEditingController();
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _recent = [];
  late String? _storeId = widget.initialStoreId;
  DateTime _date = DateTime.now();
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
    _units.dispose();
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
      final recent = await supabase
          .from('sales_reports')
          .select('product_name, units_sold, sale_date, stores(name)')
          .eq('employee_id', uid)
          .order('created_at', ascending: false)
          .limit(15);
      setState(() {
        _stores = rows.map((r) => r['stores'] as Map<String, dynamic>).toList();
        _recent = List<Map<String, dynamic>>.from(recent);
        if (!_stores.any((s) => s['id'] == _storeId)) _storeId = null;
        _storeId ??= _stores.isEmpty ? null : _stores.first['id'] as String;
      });
    } catch (e) {
      setState(() => _error = 'Gagal memuat: ${friendlyError(e)}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _storeId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await supabase.from('sales_reports').insert({
        'employee_id': supabase.auth.currentUser!.id,
        'store_id': _storeId,
        'product_name': _product.text.trim(),
        'units_sold': int.parse(_units.text.trim()),
        'sale_date': DateFormat('yyyy-MM-dd').format(_date),
      });
      _product.clear();
      _units.clear();
      await _load();
      if (mounted) showToast(context, 'Penjualan tersimpan.');
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan: ${friendlyError(e)}');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Input Penjualan'),
          actions: const [HelpButton(HelpTopic.sales)],
        bottom: const HelpBar(HelpTopic.sales),
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
                        ProductField(controller: _product),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _units,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Unit terjual'),
                          validator: (v) =>
                              (int.tryParse((v ?? '').trim()) ?? 0) <= 0
                                  ? 'Isi dengan angka bulat lebih dari 0'
                                  : null,
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.event),
                          label: Text(
                              'Tanggal: ${DateFormat('dd MMM yyyy').format(_date)}'),
                          onPressed: _pickDate,
                        ),
                        if (_error != null)
                          Text(_error!, style: TextStyle(color: cs.error)),
                        const SizedBox(height: 8),
                        FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(
                                _saving ? 'Menyimpan...' : 'Simpan penjualan')),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Text('Terbaru', style: Theme.of(context).textTheme.titleSmall),
                if (_recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Belum ada penjualan yang kamu catat.'),
                  ),
                for (final r in _recent)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r['product_name'] as String),
                    subtitle: Text(
                        '${(r['stores'] as Map?)?['name'] ?? ''}, ${fmtDate(r['sale_date'])}'),
                    trailing: Text('${r['units_sold']} unit'),
                  ),
              ],
            ),
    );
  }
}
