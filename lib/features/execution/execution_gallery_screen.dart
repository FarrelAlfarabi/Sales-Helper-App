import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';

/// Manajer: Galeri Foto. Satu tempat untuk melihat foto lapangan dengan
/// filter kampanye, bulan, salesman, dan toko, plus grafik toko per salesman
/// dan papan peringkat. Sumber: eksekusi kampanye, kunjungan toko, cek rak.
class ExecutionGalleryScreen extends StatefulWidget {
  const ExecutionGalleryScreen({super.key});

  @override
  State<ExecutionGalleryScreen> createState() => _ExecutionGalleryScreenState();
}

enum _Source { eksekusi, kunjungan, rak }

class _Photo {
  const _Photo(this.label, this.bucket, this.path);
  final String label;
  final String bucket;
  final String path;
}

class _Entry {
  _Entry({
    required this.source,
    required this.storeId,
    required this.storeName,
    required this.who,
    required this.month,
    required this.when,
    required this.photos,
    this.campaign,
  });
  final _Source source;
  final String storeId;
  final String storeName;
  final String who;
  final DateTime month; // tanggal 1 bulan laporan
  final DateTime when;
  final String? campaign;
  final List<_Photo> photos;
}

class _ExecutionGalleryScreenState extends State<ExecutionGalleryScreen> {
  static const _all = '__all__';

  final List<_Entry> _entries = [];
  final Map<String, String> _urls = {}; // "bucket/path" -> signed url
  _Source _source = _Source.eksekusi;
  bool _flat = false;
  String _campaign = _all;
  String _month = _all;
  String _sales = _all;
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _monthOf(dynamic iso) {
    final d = DateTime.tryParse('$iso')?.toLocal() ?? DateTime.now();
    return DateTime(d.year, d.month);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Future.wait<dynamic>([
        supabase
            .from('execution_reports')
            .select(
                'id, store_id, report_month, created_at, campaigns(name), stores(name), profiles(full_name), execution_photos(slot_label, photo_path)')
            .order('created_at', ascending: false)
            .limit(300),
        supabase
            .from('store_visits')
            .select('id, store_id, visit_started_at, store_photo_url, stores(name), profiles(full_name)')
            .not('store_photo_url', 'is', null)
            .order('visit_started_at', ascending: false)
            .limit(300),
        supabase
            .from('shelf_checks')
            .select('id, store_id, created_at, photo_path, stores(name), profiles(full_name)')
            .order('created_at', ascending: false)
            .limit(300),
      ]);
      final list = <_Entry>[];
      for (final r in res[0] as List) {
        final photos = [
          for (final p in (r['execution_photos'] as List? ?? const []))
            _Photo('${p['slot_label']}', 'execution-photos', '${p['photo_path']}'),
        ];
        list.add(_Entry(
          source: _Source.eksekusi,
          storeId: '${r['store_id']}',
          storeName: '${(r['stores'] as Map?)?['name'] ?? '?'}',
          who: '${(r['profiles'] as Map?)?['full_name'] ?? '?'}',
          month: _monthOf(r['report_month']),
          when: DateTime.tryParse('${r['created_at']}')?.toLocal() ?? DateTime.now(),
          campaign: '${(r['campaigns'] as Map?)?['name'] ?? '?'}',
          photos: photos,
        ));
      }
      for (final v in res[1] as List) {
        list.add(_Entry(
          source: _Source.kunjungan,
          storeId: '${v['store_id']}',
          storeName: '${(v['stores'] as Map?)?['name'] ?? '?'}',
          who: '${(v['profiles'] as Map?)?['full_name'] ?? '?'}',
          month: _monthOf(v['visit_started_at']),
          when: DateTime.tryParse('${v['visit_started_at']}')?.toLocal() ?? DateTime.now(),
          photos: [_Photo('Foto toko', 'store-visit-photos', '${v['store_photo_url']}')],
        ));
      }
      for (final s in res[2] as List) {
        list.add(_Entry(
          source: _Source.rak,
          storeId: '${s['store_id']}',
          storeName: '${(s['stores'] as Map?)?['name'] ?? '?'}',
          who: '${(s['profiles'] as Map?)?['full_name'] ?? '?'}',
          month: _monthOf(s['created_at']),
          when: DateTime.tryParse('${s['created_at']}')?.toLocal() ?? DateTime.now(),
          photos: [_Photo('Foto rak', 'osa-photos', '${s['photo_path']}')],
        ));
      }
      list.removeWhere((e) => e.photos.isEmpty);

      // Tanda tangan URL foto sekali per bucket, bukan satu per gambar.
      final byBucket = <String, List<String>>{};
      for (final e in list) {
        for (final p in e.photos) {
          byBucket.putIfAbsent(p.bucket, () => []).add(p.path);
        }
      }
      final urls = <String, String>{};
      for (final b in byBucket.entries) {
        for (var i = 0; i < b.value.length; i += 100) {
          final chunk = b.value.sublist(i, i + 100 > b.value.length ? b.value.length : i + 100);
          try {
            final signed = await supabase.storage.from(b.key).createSignedUrlsResult(chunk, 3600);
            for (final s in signed) {
              if (s is SignedUrlSuccess) urls['${b.key}/${s.path}'] = s.signedUrl;
            }
          } catch (_) {
            // Foto yang gagal ditandatangani tampil sebagai kotak kosong.
          }
        }
      }
      setState(() {
        _entries
          ..clear()
          ..addAll(list);
        _urls
          ..clear()
          ..addAll(urls);
      });
    } catch (e) {
      setState(() => _error = 'Gagal memuat galeri: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  List<_Entry> get _inSource => _entries.where((e) => e.source == _source).toList();

  List<_Entry> get _filtered {
    final q = _query.trim().toLowerCase();
    final out = _inSource.where((e) {
      if (_source == _Source.eksekusi && _campaign != _all && e.campaign != _campaign) return false;
      if (_month != _all && DateFormat('yyyy-MM').format(e.month) != _month) return false;
      if (_sales != _all && e.who != _sales) return false;
      if (q.isNotEmpty && !e.storeName.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    out.sort((a, b) => b.when.compareTo(a.when));
    return out;
  }

  String _monthLabel(String key) =>
      DateFormat('MMMM yyyy', 'id').format(DateTime.parse('$key-01'));

  void _openLightbox(List<_Photo> photos, int index, String Function(int) caption) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _Lightbox(photos: photos, start: index, urls: _urls, caption: caption),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final src = _inSource;
    final campaigns = {for (final e in src) if (e.campaign != null) e.campaign!}.toList()..sort();
    final months = {for (final e in src) DateFormat('yyyy-MM').format(e.month)}.toList()..sort((a, b) => b.compareTo(a));
    final people = {for (final e in src) e.who}.toList()..sort();
    final rows = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Galeri Foto'), actions: [
        IconButton(tooltip: 'Muat ulang', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (_error != null) Text(_error!, style: TextStyle(color: cs.error)),
                SegmentedButton<_Source>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _Source.eksekusi, label: Text('Eksekusi kampanye')),
                    ButtonSegment(value: _Source.kunjungan, label: Text('Kunjungan toko')),
                    ButtonSegment(value: _Source.rak, label: Text('Cek rak')),
                  ],
                  selected: {_source},
                  onSelectionChanged: (s) => setState(() {
                    _source = s.first;
                    _campaign = _all;
                    _month = _all;
                    _sales = _all;
                  }),
                ),
                const SizedBox(height: 16),
                Text('Filter laporan masuk', style: t.titleMedium),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  if (_source == _Source.eksekusi)
                    _drop('Kampanye', _campaign, 'Semua kampanye', {for (final c in campaigns) c: c},
                        (v) => setState(() => _campaign = v)),
                  _drop('Bulan', _month, 'Semua bulan', {for (final m in months) m: _monthLabel(m)},
                      (v) => setState(() => _month = v)),
                  _drop('Salesman', _sales, 'Semua salesman', {for (final p in people) p: p},
                      (v) => setState(() => _sales = v)),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Cari toko', prefixIcon: Icon(Icons.search)),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                _summary(rows),
                const SizedBox(height: 20),
                _chartAndBoard(rows),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: Text('Galeri (${rows.length} laporan)', style: t.titleMedium)),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, icon: Icon(Icons.view_agenda_outlined), label: Text('Per laporan')),
                      ButtonSegment(value: true, icon: Icon(Icons.grid_view), label: Text('Semua foto')),
                    ],
                    selected: {_flat},
                    onSelectionChanged: (s) => setState(() => _flat = s.first),
                  ),
                ]),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('Tidak ada foto untuk filter ini.')),
                  )
                else if (_flat)
                  _flatGrid(rows)
                else
                  Wrap(spacing: 12, runSpacing: 12, children: [for (final e in rows) _card(e)]),
              ]),
            ),
    );
  }

  Widget _drop(String label, String value, String allLabel, Map<String, String> options, ValueChanged<String> onChanged) {
    final safe = options.containsKey(value) ? value : _all;
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: safe,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: _all, child: Text(allLabel)),
          for (final o in options.entries) DropdownMenuItem(value: o.key, child: Text(o.value, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => onChanged(v ?? _all),
      ),
    );
  }

  Widget _summary(List<_Entry> rows) {
    final stores = {for (final e in rows) e.storeId}.length;
    final people = {for (final e in rows) e.who}.length;
    final photos = rows.fold<int>(0, (n, e) => n + e.photos.length);
    return Wrap(spacing: 12, runSpacing: 12, children: [
      _stat('Laporan', '${rows.length}'),
      _stat('Toko', '$stores'),
      _stat('Salesman', '$people'),
      _stat('Foto', '$photos'),
    ]);
  }

  Widget _stat(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }

  /// Toko unik per salesman dari laporan yang lolos filter.
  Widget _chartAndBoard(List<_Entry> rows) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final perSales = <String, Set<String>>{};
    for (final e in rows) {
      perSales.putIfAbsent(e.who, () => {}).add(e.storeId);
    }
    final board = perSales.entries.map((e) => MapEntry(e.key, e.value.length)).toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    final maxV = board.isEmpty ? 1 : board.first.value;

    final chart = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Kinerja salesman', style: t.titleMedium),
      Text('Jumlah toko yang dilaporkan per salesman', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 12),
      if (board.isEmpty)
        const Text('Belum ada data.')
      else
        for (final b in board.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 110, child: Text(b.key, overflow: TextOverflow.ellipsis)),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, box) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 20,
                      width: (box.maxWidth * b.value / maxV).clamp(6, box.maxWidth).toDouble(),
                      decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 36, child: Text('${b.value}', textAlign: TextAlign.right)),
            ]),
          ),
    ]);

    final total = board.fold<int>(0, (n, b) => n + b.value);
    final leaderboard = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Papan peringkat', style: t.titleMedium),
      Text('Total toko terverifikasi: $total', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 8),
      Table(
        columnWidths: const {0: FixedColumnWidth(36), 1: FlexColumnWidth(), 2: FixedColumnWidth(60)},
        children: [
          TableRow(children: [
            Padding(padding: const EdgeInsets.all(6), child: Text('#', style: t.labelMedium)),
            Padding(padding: const EdgeInsets.all(6), child: Text('Salesman', style: t.labelMedium)),
            Padding(padding: const EdgeInsets.all(6), child: Text('Toko', style: t.labelMedium, textAlign: TextAlign.right)),
          ]),
          for (var i = 0; i < board.length; i++)
            TableRow(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
              children: [
                Padding(padding: const EdgeInsets.all(6), child: Text('${i + 1}')),
                Padding(padding: const EdgeInsets.all(6), child: Text(board[i].key)),
                Padding(padding: const EdgeInsets.all(6), child: Text('${board[i].value}', textAlign: TextAlign.right)),
              ],
            ),
        ],
      ),
    ]);

    return LayoutBuilder(builder: (_, box) {
      final wide = box.maxWidth >= 720;
      final a = _panel(chart), b = _panel(leaderboard);
      return wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: a),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: b),
            ])
          : Column(children: [a, const SizedBox(height: 12), b]);
    });
  }

  Widget _panel(Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }

  Widget _thumb(_Photo p, {double? height}) {
    final cs = Theme.of(context).colorScheme;
    final url = _urls['${p.bucket}/${p.path}'];
    return Container(
      height: height,
      color: cs.surfaceContainerHighest,
      child: url == null
          ? Icon(Icons.image_not_supported_outlined, color: cs.onSurfaceVariant)
          : Image.network(url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant)),
    );
  }

  String _caption(_Entry e, _Photo p) {
    final date = DateFormat('d MMM yyyy, HH:mm', 'id').format(e.when);
    return '${p.label}\n${e.storeName} · ${e.who}${e.campaign != null ? ' · ${e.campaign}' : ''}\n$date';
  }

  Widget _card(_Entry e) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 250,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openLightbox(e.photos, 0, (i) => _caption(e, e.photos[i])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 150,
              child: Row(children: [
                Expanded(flex: 2, child: _thumb(e.photos.first)),
                if (e.photos.length > 1) ...[
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(children: [
                      for (var i = 1; i < e.photos.length && i < 3; i++) ...[
                        if (i > 1) const SizedBox(height: 2),
                        Expanded(child: SizedBox(width: double.infinity, child: _thumb(e.photos[i]))),
                      ],
                    ]),
                  ),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.storeName, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(e.who, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                if (e.campaign != null) ...[
                  const SizedBox(height: 6),
                  Chip(
                    label: Text(e.campaign!),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: cs.primaryContainer,
                    side: BorderSide.none,
                    labelStyle: TextStyle(color: cs.onPrimaryContainer),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('d MMM yyyy', 'id').format(e.when)} · ${e.photos.length} foto',
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _flatGrid(List<_Entry> rows) {
    final flat = <(_Entry, _Photo)>[
      for (final e in rows)
        for (final p in e.photos) (e, p),
    ];
    final photos = [for (final f in flat) f.$2];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1),
      itemCount: flat.length,
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(fit: StackFit.expand, children: [
          InkWell(
            onTap: () => _openLightbox(photos, i, (j) => _caption(flat[j].$1, flat[j].$2)),
            child: _thumb(flat[i].$2),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text('${flat[i].$1.storeName}\n${flat[i].$2.label}',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Penampil foto layar penuh: geser, tombol panah, atau panah keyboard.
class _Lightbox extends StatefulWidget {
  const _Lightbox({required this.photos, required this.start, required this.urls, required this.caption});
  final List<_Photo> photos;
  final int start;
  final Map<String, String> urls;
  final String Function(int) caption;

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late final PageController _c = PageController(initialPage: widget.start);
  late int _i = widget.start;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go(int d) {
    final n = _i + d;
    if (n < 0 || n >= widget.photos.length) return;
    _c.animateToPage(n, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: Stack(children: [
            PageView.builder(
              controller: _c,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) {
                final p = widget.photos[i];
                final url = widget.urls['${p.bucket}/${p.path}'];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(56, 56, 56, 110),
                  child: url == null
                      ? const Center(child: Text('Foto tidak tersedia', style: TextStyle(color: Colors.white)))
                      : InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Tutup',
                color: Colors.white,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            if (_i > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                    tooltip: 'Sebelumnya', color: Colors.white, onPressed: () => _go(-1), icon: const Icon(Icons.chevron_left, size: 36)),
              ),
            if (_i < widget.photos.length - 1)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                    tooltip: 'Berikutnya', color: Colors.white, onPressed: () => _go(1), icon: const Icon(Icons.chevron_right, size: 36)),
              ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 20,
              child: Text(
                '${_i + 1} / ${widget.photos.length}\n${widget.caption(_i)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
