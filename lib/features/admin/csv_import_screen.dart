import 'dart:convert';

import '../../core/help.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/supabase_client.dart';

enum CsvImportKind { stores, assignments }

/// Parses CSV text. Handles quoted fields, "" escapes, CRLF, a UTF-8 BOM and
/// either comma or semicolon as the separator (Excel in Indonesian locale
/// saves with semicolons).
List<List<String>> parseCsv(String input) {
  var text = input.startsWith('﻿') ? input.substring(1) : input;
  final firstLine = text.split('\n').first;
  final sep =
      (';'.allMatches(firstLine).length > ','.allMatches(firstLine).length)
          ? ';'
          : ',';
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == sep) {
      row.add(field.toString().trim());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString().trim());
      field.clear();
      if (row.any((v) => v.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  row.add(field.toString().trim());
  if (row.any((v) => v.isNotEmpty)) rows.add(row);
  return rows;
}

class _Row {
  _Row(this.line, this.label, {this.error, this.skip, this.data});
  final int line; // nomor baris di berkas (header = baris 1)
  final String label;
  final String? error; // baris ini tidak bisa diimpor
  final String? skip; // baris ini valid tapi akan dilewati
  final Map<String, dynamic>? data;
  bool get ok => error == null && skip == null;
}

/// Manager/admin: bulk import stores or store assignments from a CSV file.
/// Flow: pick file -> preview with per-row validation -> import valid rows.
/// Nothing is written until the user presses the import button.
class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key, required this.kind});
  final CsvImportKind kind;

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  List<_Row>? _rows;
  String? _fileName;
  String? _error;
  bool _busy = false;
  String? _done;

  bool get _isStores => widget.kind == CsvImportKind.stores;

  String get _template => _isStores
      ? 'kode,nama,alamat,lintang,bujur,radius\n'
          'ST-101,Toko Contoh Satu,"Jl. Contoh No. 1, Jakarta",-6.2088,106.8456,100\n'
          'ST-102,Toko Contoh Dua,Jl. Contoh No. 2,-6.2150,106.8300,150\n'
      : 'email,kode_toko\n'
          'sales1@perusahaan.com,ST-101\n'
          'sales1@perusahaan.com,ST-102\n';

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _done = null;
      _rows = null;
    });
    try {
      final f = await FilePicker.pickFile(
          type: FileType.custom, allowedExtensions: ['csv']);
      if (f == null) return;
      final size = await f.length();
      if (size != null && size > 2 * 1024 * 1024) {
        setState(() => _error = 'Berkas terlalu besar (maksimal 2 MB).');
        return;
      }
      final bytes = await f.readAsBytes();
      setState(() {
        _busy = true;
        _fileName = f.name;
      });
      final parsed = parseCsv(utf8.decode(bytes, allowMalformed: true));
      final rows = _isStores
          ? await _checkStores(parsed)
          : await _checkAssignments(parsed);
      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _error = 'Gagal membaca berkas: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');

  Map<String, int> _header(List<String> h, Map<String, List<String>> names) {
    final out = <String, int>{};
    final normed = h.map(_norm).toList();
    names.forEach((key, aliases) {
      for (final a in aliases) {
        final i = normed.indexOf(_norm(a));
        if (i >= 0) {
          out[key] = i;
          break;
        }
      }
    });
    return out;
  }

  String _cell(List<String> r, int? i) =>
      (i == null || i >= r.length) ? '' : r[i].trim();

  Future<List<_Row>> _checkStores(List<List<String>> parsed) async {
    if (parsed.isEmpty) throw 'Berkas kosong.';
    final h = _header(parsed.first, {
      'code': ['kode', 'kode toko', 'code'],
      'name': ['nama', 'nama toko', 'name'],
      'address': ['alamat', 'address'],
      'lat': ['lintang', 'latitude', 'lat'],
      'lng': ['bujur', 'longitude', 'lng', 'lon'],
      'radius': ['radius', 'radius geofence'],
    });
    final missing =
        ['code', 'name', 'lat', 'lng'].where((k) => !h.containsKey(k)).toList();
    if (missing.isNotEmpty) {
      throw 'Kolom wajib tidak ditemukan. Pakai header: kode, nama, alamat, lintang, bujur, radius.';
    }
    final existing = await supabase.from('stores').select('code');
    final existingCodes = {
      for (final s in existing) (s['code'] as String).toLowerCase()
    };
    final seen = <String>{};
    final rows = <_Row>[];
    for (var i = 1; i < parsed.length; i++) {
      final r = parsed[i];
      final line = i + 1;
      final code = _cell(r, h['code']);
      final name = _cell(r, h['name']);
      final label = '$code  $name';
      final lat = double.tryParse(_cell(r, h['lat']).replaceAll(',', '.'));
      final lng = double.tryParse(_cell(r, h['lng']).replaceAll(',', '.'));
      final radiusText = _cell(r, h['radius']);
      final radius = radiusText.isEmpty ? 100 : int.tryParse(radiusText);
      String? err;
      if (code.isEmpty) {
        err = 'Kode toko kosong';
      } else if (name.isEmpty) {
        err = 'Nama toko kosong';
      } else if (lat == null || lat < -90 || lat > 90) {
        err = 'Lintang tidak valid (harus -90 sampai 90)';
      } else if (lng == null || lng < -180 || lng > 180) {
        err = 'Bujur tidak valid (harus -180 sampai 180)';
      } else if (radius == null || radius < 10 || radius > 5000) {
        err = 'Radius harus angka 10 sampai 5000 meter';
      } else if (!seen.add(code.toLowerCase())) {
        err = 'Kode toko dobel di berkas ini';
      }
      if (err != null) {
        rows.add(_Row(line, label, error: err));
      } else if (existingCodes.contains(code.toLowerCase())) {
        rows.add(_Row(line, label, skip: 'Kode sudah ada, dilewati'));
      } else {
        final addr = _cell(r, h['address']);
        rows.add(_Row(line, label, data: {
          'code': code,
          'name': name,
          'address': addr.isEmpty ? null : addr,
          'latitude': lat,
          'longitude': lng,
          'geofence_radius_meters': radius,
          'created_by': supabase.auth.currentUser!.id,
        }));
      }
    }
    return rows;
  }

  Future<List<_Row>> _checkAssignments(List<List<String>> parsed) async {
    if (parsed.isEmpty) throw 'Berkas kosong.';
    final h = _header(parsed.first, {
      'email': ['email', 'email karyawan'],
      'code': ['kode toko', 'kode', 'code'],
      'name': ['nama toko', 'toko', 'nama', 'store'],
    });
    if (!h.containsKey('email') ||
        (!h.containsKey('code') && !h.containsKey('name'))) {
      throw 'Kolom wajib tidak ditemukan. Pakai header: email, kode_toko.';
    }
    final staff = await supabase.rpc('list_staff_for_import') as List;
    final byEmail = {
      for (final s in staff)
        (s['email'] as String).toLowerCase():
            Map<String, dynamic>.from(s as Map),
    };
    final stores = List<Map<String, dynamic>>.from(
        await supabase.from('stores').select('id, name, code'));
    final byCode = {
      for (final s in stores) (s['code'] as String).toLowerCase(): s
    };
    final existing = await supabase
        .from('store_assignments')
        .select('employee_id, store_id')
        .eq('is_active', true);
    final active = {
      for (final a in existing) '${a['employee_id']}|${a['store_id']}'
    };
    final seen = <String>{};
    final rows = <_Row>[];
    for (var i = 1; i < parsed.length; i++) {
      final r = parsed[i];
      final line = i + 1;
      final email = _cell(r, h['email']).toLowerCase();
      final code = _cell(r, h['code']);
      final name = _cell(r, h['name']);
      final label = '$email  ->  ${code.isNotEmpty ? code : name}';
      final emp = byEmail[email];
      Map<String, dynamic>? store;
      String? err;
      if (email.isEmpty) {
        err = 'Email kosong';
      } else if (emp == null) {
        err = 'Email tidak ditemukan di daftar karyawan';
      } else if (emp['role'] != 'field_rep') {
        err = 'Akun ini bukan sales lapangan';
      } else if (code.isEmpty && name.isEmpty) {
        err = 'Kode atau nama toko kosong';
      } else {
        if (code.isNotEmpty) {
          store = byCode[code.toLowerCase()];
        } else {
          final m = stores
              .where((s) =>
                  (s['name'] as String).toLowerCase() == name.toLowerCase())
              .toList();
          if (m.length > 1) {
            err = 'Nama toko ada lebih dari satu, pakai kode toko';
          } else if (m.length == 1) {
            store = m.first;
          }
        }
        if (err == null && store == null) err = 'Toko tidak ditemukan';
      }
      if (err != null) {
        rows.add(_Row(line, label, error: err));
        continue;
      }
      final key = '${emp!['id']}|${store!['id']}';
      if (!seen.add(key)) {
        rows.add(_Row(line, label, skip: 'Dobel di berkas ini, dilewati'));
      } else if (active.contains(key)) {
        rows.add(_Row(line, label, skip: 'Sudah ditugaskan, dilewati'));
      } else {
        rows.add(_Row(line, label, data: {
          'employee_id': emp['id'],
          'store_id': store['id'],
          'is_active': true,
          'assigned_by': supabase.auth.currentUser!.id,
        }));
      }
    }
    return rows;
  }

  Future<void> _import() async {
    final valid = _rows!.where((r) => r.ok).map((r) => r.data!).toList();
    if (valid.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      for (var i = 0; i < valid.length; i += 200) {
        final chunk =
            valid.sublist(i, i + 200 > valid.length ? valid.length : i + 200);
        if (_isStores) {
          await supabase.from('stores').insert(chunk);
        } else {
          await supabase
              .from('store_assignments')
              .upsert(chunk, onConflict: 'employee_id,store_id');
        }
      }
      setState(() {
        _done = '${valid.length} baris berhasil diimpor.';
        _rows = null;
      });
    } catch (e) {
      setState(() => _error =
          'Impor gagal, sebagian mungkin sudah masuk. Muat ulang daftar lalu cek. Detail: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = _rows;
    final okCount = rows?.where((r) => r.ok).length ?? 0;
    final errCount = rows?.where((r) => r.error != null).length ?? 0;
    final skipCount = rows?.where((r) => r.skip != null).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isStores ? 'Impor Toko dari CSV' : 'Impor Penugasan dari CSV'),
        actions: [
          HelpButton(_isStores ? HelpTopic.csvStores : HelpTopic.csvAssignments)
        ],
        bottom: HelpBar(_isStores ? HelpTopic.csvStores : HelpTopic.csvAssignments),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _isStores
                ? 'Kolom: kode, nama, alamat, lintang, bujur, radius. Radius boleh kosong (default 100 m). Toko dengan kode yang sudah ada dilewati.'
                : 'Kolom: email, kode_toko. Email harus akun sales lapangan yang sudah dibuat. Penugasan yang sudah aktif dilewati.',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contoh isi berkas',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    SelectableText(_template,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12)),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Salin contoh'),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _template));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Contoh disalin. Tempel di Excel atau Notepad lalu simpan sebagai .csv')));
                        }
                      },
                    ),
                  ]),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: Text(_busy ? 'Memproses...' : 'Pilih berkas CSV'),
            onPressed: _busy ? null : _pick,
          ),
          if (_busy)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator()),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: cs.error))),
          if (_done != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_done!,
                  style: TextStyle(
                      color: cs.primary, fontWeight: FontWeight.bold)),
            ),
          if (rows != null) ...[
            const SizedBox(height: 16),
            Text(
                '${_fileName ?? ''}: $okCount siap diimpor, $skipCount dilewati, $errCount salah.',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (errCount > 0)
              const Text(
                  'Baris yang salah tidak akan diimpor. Perbaiki berkas lalu pilih ulang, atau impor baris yang benar saja.'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: (_busy || okCount == 0) ? null : _import,
              child: Text('Impor $okCount baris'),
            ),
            const SizedBox(height: 8),
            for (final r in rows)
              Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    r.error != null
                        ? Icons.error_outline
                        : (r.skip != null
                            ? Icons.remove_circle_outline
                            : Icons.check_circle_outline),
                    color: r.error != null
                        ? cs.error
                        : (r.skip != null ? cs.outline : cs.primary),
                  ),
                  title: Text('Baris ${r.line}: ${r.label}'),
                  subtitle: (r.error ?? r.skip) == null
                      ? null
                      : Text((r.error ?? r.skip)!),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
