import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/photo_capture.dart';
import '../../core/supabase_client.dart';

/// Rep (dan manajer): kirim laporan eksekusi kampanye. Pilih kampanye, bulan,
/// toko, lalu foto untuk setiap slot yang ditentukan kampanye.
class ExecutionFormScreen extends StatefulWidget {
  const ExecutionFormScreen({super.key});

  @override
  State<ExecutionFormScreen> createState() => _ExecutionFormScreenState();
}

class _ExecutionFormScreenState extends State<ExecutionFormScreen> with SafeSetState<ExecutionFormScreen> {
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _stores = [];
  String? _campaignId;
  String? _storeId;
  late DateTime _month;
  final Map<int, XFile> _photos = {};
  final Map<int, Uint8List> _previews = {};
  String _salesName = '';
  bool _loading = true;
  bool _submitting = false;
  bool _saved = false;
  String? _error;
  final _storeCtrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _storeCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = supabase.auth.currentUser!.id;
      final res = await Future.wait<dynamic>([
        supabase.from('campaigns').select('id, name, photo_slots').eq('is_active', true).order('name'),
        supabase.from('store_assignments').select('stores(id, name, code, address)').eq('employee_id', uid).eq('is_active', true),
        supabase.from('profiles').select('full_name').eq('id', uid).single(),
      ]);
      final stores = <Map<String, dynamic>>[
        for (final r in res[1] as List)
          if (r['stores'] != null) Map<String, dynamic>.from(r['stores'] as Map),
      ]..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      setState(() {
        _campaigns = List<Map<String, dynamic>>.from(res[0] as List);
        _stores = stores;
        _salesName = '${(res[2] as Map)['full_name'] ?? ''}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat data: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? get _campaign {
    for (final c in _campaigns) {
      if (c['id'] == _campaignId) return c;
    }
    return null;
  }

  List<String> get _slots => List<String>.from((_campaign?['photo_slots'] as List?) ?? const []);

  Map<String, dynamic>? get _store {
    for (final s in _stores) {
      if (s['id'] == _storeId) return s;
    }
    return null;
  }

  List<DateTime> get _monthChoices {
    final now = DateTime.now();
    return [for (var i = 0; i < 4; i++) DateTime(now.year, now.month - i)];
  }

  Future<void> _pick(int slot, ImageSource source) async {
    try {
      final f = await PhotoCapture.capture(source: source);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _error = null;
        _photos[slot] = f;
        _previews[slot] = bytes;
      });
    } catch (e) {
      setState(() => _error = 'Foto gagal diambil: ${friendlyError(e)}');
    }
  }

  Future<void> _submit() async {
    final c = _campaign;
    if (c == null) return setState(() => _error = 'Pilih kampanye dulu.');
    if (_storeId == null) return setState(() => _error = 'Pilih toko dari daftar.');
    final slots = _slots;
    for (var i = 0; i < slots.length; i++) {
      if (!_photos.containsKey(i)) {
        return setState(() => _error = 'Foto "${slots[i]}" wajib diisi.');
      }
    }
    setState(() {
      _submitting = true;
      _error = null;
      _saved = false;
    });
    try {
      final uid = supabase.auth.currentUser!.id;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final uploaded = <int, String>{};
      for (var i = 0; i < slots.length; i++) {
        final path = '$uid/${stamp}_$i.jpg';
        await supabase.storage.from('execution-photos').uploadBinary(
              path,
              _previews[i]!,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        uploaded[i] = path;
      }
      final report = await supabase
          .from('execution_reports')
          .insert({
            'employee_id': uid,
            'store_id': _storeId,
            'campaign_id': _campaignId,
            'report_month': DateFormat('yyyy-MM-dd').format(_month),
          })
          .select('id')
          .single();
      await supabase.from('execution_photos').insert([
        for (var i = 0; i < slots.length; i++)
          {'report_id': report['id'], 'slot_label': slots[i], 'photo_path': uploaded[i]},
      ]);
      if (!mounted) return;
      _storeCtrl.clear();
      setState(() {
        _saved = true;
        _storeId = null;
        _photos.clear();
        _previews.clear();
      });
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan terkirim. Pilih toko berikutnya untuk lanjut.')));
    } on PostgrestException catch (e) {
      setState(() => _error = e.code == '23505'
          ? 'Toko ini sudah punya laporan untuk kampanye dan bulan yang sama.'
          : 'Gagal menyimpan laporan: ${friendlyError(e)}');
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan laporan: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final slots = _slots;
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Eksekusi Kampanye'), actions: [
        IconButton(tooltip: 'Muat ulang', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
                  if (_saved)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Icon(Icons.check_circle, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Laporan eksekusi tersimpan dan sudah tampil di Galeri Foto.',
                              style: t.bodyMedium?.copyWith(color: cs.onPrimaryContainer)),
                        ),
                        IconButton(
                            tooltip: 'Tutup', onPressed: () => setState(() => _saved = false), icon: const Icon(Icons.close)),
                      ]),
                    ),
                  Text('Detail kampanye', style: t.titleMedium),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _campaignId,
                    decoration: const InputDecoration(labelText: 'Nama kampanye *'),
                    hint: Text(_campaigns.isEmpty ? 'Belum ada kampanye aktif' : 'Pilih kampanye...'),
                    items: [for (final c in _campaigns) DropdownMenuItem(value: c['id'] as String, child: Text('${c['name']}'))],
                    onChanged: (v) => setState(() {
                      _campaignId = v;
                      _photos.clear();
                      _previews.clear();
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<DateTime>(
                    initialValue: _month,
                    decoration: const InputDecoration(labelText: 'Bulan *'),
                    items: [
                      for (final m in _monthChoices)
                        DropdownMenuItem(value: m, child: Text(DateFormat('MMMM yyyy', 'id').format(m))),
                    ],
                    onChanged: (v) => setState(() => _month = v ?? _month),
                  ),
                  const SizedBox(height: 24),
                  Text('Informasi toko', style: t.titleMedium),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, box) => DropdownMenu<String>(
                      width: box.maxWidth,
                      enableFilter: true,
                      requestFocusOnTap: true,
                      label: const Text('Cari toko *'),
                      helperText: _stores.isEmpty ? 'Kamu belum punya toko tugas.' : null,
                      controller: _storeCtrl,
                      initialSelection: _storeId,
                      dropdownMenuEntries: [
                        for (final s in _stores)
                          DropdownMenuEntry(value: s['id'] as String, label: '${s['name']} (${s['code']})'),
                      ],
                      onSelected: (v) => setState(() => _storeId = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Alamat toko'),
                    child: Text('${_store?['address'] ?? '-'}'),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Nama sales'),
                    child: Text(_salesName.isEmpty ? '-' : _salesName),
                  ),
                  const SizedBox(height: 24),
                  Text('Foto eksekusi', style: t.titleMedium),
                  Text('Ambil dari kamera atau pilih dari galeri.', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  if (slots.isEmpty)
                    Text('Pilih kampanye untuk melihat foto yang diminta.', style: t.bodyMedium)
                  else
                    for (var i = 0; i < slots.length; i++) _slotCard(i, slots[i]),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: TextStyle(color: cs.error)),
                    ),
                  if (_campaigns.isEmpty && _error != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Kirim laporan eksekusi'),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _slotCard(int i, String label) {
    final cs = Theme.of(context).colorScheme;
    final bytes = _previews[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 96,
              height: 96,
              color: cs.surfaceContainerHighest,
              child: bytes == null
                  ? Icon(Icons.add_a_photo_outlined, color: cs.onSurfaceVariant)
                  : Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}. $label *', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                if (!kIsWeb)
                  OutlinedButton.icon(
                    onPressed: () => _pick(i, ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Kamera'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _pick(i, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(kIsWeb ? 'Pilih foto' : 'Galeri'),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
