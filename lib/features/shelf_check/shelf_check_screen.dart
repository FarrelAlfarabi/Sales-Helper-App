import 'package:flutter/material.dart';
import '../../core/help.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/photo_capture.dart';
import '../../core/signed_photo.dart';
import '../../core/supabase_client.dart';
import 'shelf_actions.dart';

/// Shelf Check: photograph a product aisle, get a detailed AI read of it.
/// The photo goes to the osa-photos bucket (own folder), then the shelf-check
/// Edge Function analyses it and saves the result. One photo only shows the
/// shelf front, so results are prompts to check, not stock counts.
/// Needs migration 20261030100000 and the deployed function.
class ShelfCheckScreen extends StatefulWidget {
  const ShelfCheckScreen({super.key, this.initialStoreId});

  /// Toko yang sudah dipilih (dibuka dari alur kunjungan toko).
  final String? initialStoreId;

  @override
  State<ShelfCheckScreen> createState() => _ShelfCheckScreenState();
}

class _ShelfCheckScreenState extends State<ShelfCheckScreen> with SafeSetState<ShelfCheckScreen> {
  final _brands = TextEditingController();
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _history = [];
  late String? _storeId = widget.initialStoreId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _brands.dispose();
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
      final hist = await supabase
          .from('shelf_checks')
          .select('id, employee_id, summary, analysis, photo_path, created_at, stores(name), '
              'shelf_check_actions(actions)')
          .eq('employee_id', uid)
          .order('created_at', ascending: false)
          .limit(10);
      setState(() {
        _stores = rows.map((r) => r['stores'] as Map<String, dynamic>).toList();
        _history = List<Map<String, dynamic>>.from(hist);
        if (!_stores.any((s) => s['id'] == _storeId)) _storeId = null;
        _storeId ??= _stores.isEmpty ? null : _stores.first['id'] as String;
      });
    } catch (e) {
      setState(() => _error = 'Gagal memuat: ${friendlyError(e)}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _capture() async {
    if (_storeId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await PhotoCapture.capture(source: ImageSource.camera);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      final uid = supabase.auth.currentUser!.id;
      final path = '$uid/shelf-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('osa-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      final res = await supabase.functions.invoke('shelf-check', body: {
        'store_id': _storeId,
        'photo_path': path,
        'focus_brands': _brands.text.trim(),
      });
      final data = res.data as Map<String, dynamic>;
      if (data['error'] != null) throw Exception(data['error']);
      final check = Map<String, dynamic>.from(data['shelf_check'] as Map);
      final name = _stores.firstWhere((s) => s['id'] == _storeId,
          orElse: () => {})['name'];
      check['stores'] = {'name': name};
      _load();
      if (!mounted) return;
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ShelfResultScreen(check: check)));
    } on FunctionException catch (e) {
      setState(() => _error = 'Analisis gagal. ${friendlyError(e)}');
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static int _actionCount(Map<String, dynamic> h) =>
      shelfActionCodes(firstRelation(h['shelf_check_actions'])?['actions'])
          .length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Cek Rak'),
          actions: const [HelpButton(HelpTopic.shelfCheck)],
        bottom: const HelpBar(HelpTopic.shelfCheck),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_stores.isEmpty)
                  const Text('Belum ada toko yang ditugaskan kepadamu.')
                else ...[
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
                  TextField(
                    controller: _brands,
                    decoration: const InputDecoration(
                      labelText: 'Merek kamu (opsional)',
                      helperText:
                          'Pisahkan dengan koma. Membantu AI menghitung porsi rak dan pesaing.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ambil satu foto lorong yang jelas dari depan, seluruh rak masuk bingkai agar label dan celah terlihat.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_busy ? 'Menganalisis...' : 'Foto lorong rak'),
                    onPressed: _busy ? null : _capture,
                  ),
                ],
                if (_busy)
                  const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator()),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_error!, style: TextStyle(color: cs.error))),
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Cek terbaru',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final h in _history)
                    Card(
                      child: ListTile(
                        title:
                            Text('${(h['stores'] as Map?)?['name'] ?? 'Toko'}'),
                        subtitle: Text(
                          '${DateFormat('dd MMM HH:mm').format(DateTime.parse(h['created_at']).toLocal())}'
                          '${h['summary'] != null ? '\n${h['summary']}' : ''}'
                          '${_actionCount(h) > 0 ? '\n${_actionCount(h)} tindakan dicatat' : '\nBelum ada catatan tindakan'}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ShelfResultScreen(check: h))),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

/// Full result: Key actions first (what to do), then Analysis, shelf read,
/// products, gaps, competitors, placement issues and the photo's limits.
class ShelfResultScreen extends StatelessWidget {
  const ShelfResultScreen({super.key, required this.check});

  final Map<String, dynamic> check;

  static List<Map<String, dynamic>> _list(Object? v) =>
      [...((v as List?) ?? const [])]
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : {'text': '$e'})
          .toList();

  static const _statusOrder = {'out': 0, 'low': 1, 'ok': 2};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final a = (check['analysis'] as Map?)?.cast<String, dynamic>() ?? const {};
    final quality = (a['photo_quality'] as Map?)?.cast<String, dynamic>();
    final shelf = (a['shelf'] as Map?)?.cast<String, dynamic>() ?? const {};
    final actions = _list(a['key_actions'])
      ..sort((x, y) => ((x['priority'] ?? 99) as num)
          .compareTo((y['priority'] ?? 99) as num));
    final analysis = _list(a['analysis']);
    final products = _list(a['products'])
      ..sort((x, y) => (_statusOrder[x['status']] ?? 3)
          .compareTo(_statusOrder[y['status']] ?? 3));
    final gaps = _list(a['gaps']);
    final comps = _list(a['competitors']);
    final issues = _list(a['placement_issues']);
    final limits =
        ((a['limits'] as List?) ?? const []).map((e) => '$e').toList();
    final unusable = quality != null && quality['usable'] == false;
    final stores = (check['stores'] as Map?)?['name'];

    Widget stat(String label, String? value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value ?? '-', style: t.titleLarge),
              Text(label, style: t.bodySmall),
            ]),
          ),
        );

    String pct(Object? v) => v == null ? '-' : '${(v as num).round()}%';

    return Scaffold(
      appBar: AppBar(title: Text(stores != null ? '$stores' : 'Hasil cek rak')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (check['photo_path'] != null)
            SignedPhoto(
                bucket: 'osa-photos',
                path: check['photo_path'] as String?,
                height: 200),
          if (unusable)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                  'Foto tidak bisa dipakai: ${quality['issue'] ?? 'ambil ulang foto'}',
                  style: TextStyle(color: cs.error)),
            ),
          if ((check['summary'] ?? shelf['summary']) != null) ...[
            const SizedBox(height: 16),
            Text('${check['summary'] ?? shelf['summary']}', style: t.bodyLarge),
          ],
          if (shelf.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              stat('Rak terisi', pct(shelf['fullness_pct'])),
              const SizedBox(width: 8),
              stat('Porsi kamu', pct(shelf['our_share_pct'])),
              const SizedBox(width: 8),
              stat('Facing terlihat', shelf['total_facings']?.toString()),
            ]),
          ],
          if (check['id'] != null) ...[
            _Heading(check['employee_id'] == supabase.auth.currentUser?.id
                ? 'Yang kamu kerjakan di rak'
                : 'Tindakan sales di rak'),
            ShelfActionsCard(
              shelfCheckId: check['id'] as String,
              canEdit: check['employee_id'] == supabase.auth.currentUser?.id,
            ),
          ],
          _Heading('Tindakan utama'),
          if (actions.isEmpty) const Text('Tidak ada tindakan disarankan.'),
          for (final x in actions)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                          radius: 13,
                          child: Text(
                              '${(x['priority'] as num?)?.toInt() ?? '-'}')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${x['action'] ?? ''}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              if (x['why'] != null) Text('${x['why']}'),
                              const SizedBox(height: 6),
                              Wrap(spacing: 6, children: [
                                _Tag(_urgency(x['urgency'])),
                                _Tag(x['owner'] == 'manager'
                                    ? 'Perlu manajer'
                                    : 'Kamu'),
                                if (x['product'] != null)
                                  _Tag('${x['product']}'),
                              ]),
                            ]),
                      ),
                    ]),
              ),
            ),
          _Heading('Analisis'),
          if (analysis.isEmpty) const Text('Tidak ada analisis.'),
          for (final x in analysis)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${x['title'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (x['detail'] != null) Text('${x['detail']}'),
                      if ((x['evidence'] ?? '').toString().isNotEmpty)
                        Text('${x['evidence']}', style: t.bodySmall),
                    ]),
              ),
            ),
          _Heading('Produk'),
          for (final p in products) _ProductTile(p: p),
          if (gaps.isNotEmpty) ...[
            _Heading('Celah di rak'),
            for (final g in gaps)
              Card(
                child: ListTile(
                  title: Text('${g['location'] ?? ''}'),
                  subtitle: Text(
                      '${g['description'] ?? ''}${g['likely_product'] != null ? '\nLikely: ${g['likely_product']}' : ''}'),
                ),
              ),
          ],
          if (comps.isNotEmpty) ...[
            _Heading('Pesaing'),
            for (final c in comps)
              Card(
                child: ListTile(
                  title: Text('${c['brand'] ?? ''}'),
                  subtitle: Text('${c['note'] ?? ''}'),
                  trailing: Text(
                      '${c['facings'] ?? '-'} facings\n${pct(c['share_pct'])}',
                      textAlign: TextAlign.end),
                ),
              ),
          ],
          if (issues.isNotEmpty) ...[
            _Heading('Masalah penempatan'),
            for (final i in issues)
              Card(
                  child: ListTile(
                      title: Text('${i['issue'] ?? ''}'),
                      subtitle: Text('${i['detail'] ?? ''}'))),
          ],
          _Heading('Yang tidak bisa dilihat dari foto ini'),
          for (final l in limits)
            Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $l', style: t.bodySmall)),
          Text(
            'Perkiraan AI dari satu foto. Jumlah dan porsi hanya kira-kira. Pastikan sebelum memesan.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _urgency(Object? u) => switch (u) {
        'now' => 'Lakukan sekarang',
        'this_visit' => 'Kunjungan ini',
        'next_visit' => 'Kunjungan berikutnya',
        _ => '${u ?? ''}',
      };
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99)),
      child: Text(text,
          style: TextStyle(
              color: cs.primary, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.p});
  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final status = p['status'] as String?;
    final color = status == 'out'
        ? cs.error
        : status == 'low'
            ? const Color(0xFFB45309)
            : cs.primary;
    final price = (p['price_tag'] as Map?)?.cast<String, dynamic>();
    final money = NumberFormat.decimalPattern('id');
    final bits = <String>[
      if (p['brand'] != null) '${p['brand']}',
      if (p['facings'] != null) '${p['facings']} facing',
      if (p['share_pct'] != null)
        '${(p['share_pct'] as num).round()}% dari rak',
      if (p['shelf_row'] != null && p['shelf_row'] != 'unknown')
        '${p['shelf_row']} rak',
      if (p['is_focus_brand'] == true) 'merek kamu',
    ];
    String priceText() {
      if (price == null || price['seen'] != true)
        return 'Label harga tidak terlihat';
      final v = price['price_idr'];
      final base = v == null
          ? 'Label harga terlihat, tidak terbaca'
          : 'Rp ${money.format(v)}';
      return price['promo'] == true ? '$base (promo)' : base;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99)),
              child: Text((status ?? '?').toUpperCase(),
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text('${p['name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          if (bits.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(bits.join('  ·  '), style: t.bodySmall)),
          Text(priceText(), style: t.bodySmall),
          if ((p['note'] ?? '').toString().isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${p['note']}')),
          if (p['confidence'] != null && p['confidence'] != 'high')
            Text('${p['confidence']} keyakinan', style: t.bodySmall),
        ]),
      ),
    );
  }
}
