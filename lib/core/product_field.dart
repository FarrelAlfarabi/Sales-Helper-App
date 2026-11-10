import 'package:flutter/material.dart';

import 'supabase_client.dart';

/// Isian produk: ketik untuk mencari di daftar produk, atau ketuk produk
/// yang sering dipakai. Nama baru tetap boleh diketik (daftar produk diatur
/// manajer), tetapi saran mengurangi salah ketik yang memecah laporan.
class ProductField extends StatefulWidget {
  const ProductField({super.key, required this.controller, this.label = 'Produk'});

  final TextEditingController controller;
  final String label;

  @override
  State<ProductField> createState() => _ProductFieldState();
}

class _ProductFieldState extends State<ProductField>
    with SafeSetState<ProductField> {
  final _focus = FocusNode();
  List<String> _all = [];
  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = supabase.auth.currentUser?.id;
    final names = <String, String>{};
    void add(dynamic n) {
      final s = '${n ?? ''}'.trim();
      if (s.isNotEmpty) names.putIfAbsent(s.toLowerCase(), () => s);
    }

    final recent = <String>[];
    try {
      final rows = await supabase
          .from('products')
          .select('name')
          .eq('is_active', true)
          .order('name');
      for (final r in rows) {
        add(r['name']);
      }
    } catch (_) {
      // Tabel produk belum ada: cukup pakai riwayat sendiri di bawah.
    }
    if (uid != null) {
      try {
        final rows = await supabase
            .from('sales_reports')
            .select('product_name')
            .eq('employee_id', uid)
            .order('created_at', ascending: false)
            .limit(60);
        for (final r in rows) {
          add(r['product_name']);
          final n = '${r['product_name'] ?? ''}'.trim();
          if (n.isNotEmpty &&
              !recent.any((x) => x.toLowerCase() == n.toLowerCase())) {
            recent.add(n);
          }
        }
      } catch (_) {}
    }
    final all = names.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    setState(() {
      _all = all;
      _recent = recent.take(6).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focus,
        optionsBuilder: (v) {
          final q = v.text.trim().toLowerCase();
          if (q.isEmpty) return const Iterable<String>.empty();
          return _all.where((n) => n.toLowerCase().contains(q)).take(8);
        },
        fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextFormField(
          controller: ctrl,
          focusNode: focus,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: _all.isEmpty ? null : 'Ketik untuk mencari produk',
            suffixIcon: const Icon(Icons.search),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Produk wajib diisi' : null,
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 480),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(dense: true, title: Text(o), onTap: () => onSelected(o)),
                ],
              ),
            ),
          ),
        ),
      ),
      if (_recent.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final r in _recent)
            ActionChip(
              label: Text(r),
              onPressed: () {
                widget.controller.text = r;
                FocusScope.of(context).nextFocus();
              },
            ),
        ]),
      ],
    ]);
  }
}
