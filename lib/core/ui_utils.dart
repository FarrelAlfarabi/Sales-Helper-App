import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hindari "setState() called after dispose()" saat pengguna pindah halaman
/// sebelum data selesai dimuat (sering terjadi di sidebar layar lebar).
mixin SafeSetState<T extends StatefulWidget> on State<T> {
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }
}

/// Ubah error teknis menjadi kalimat Indonesia yang bisa dibaca pengguna.
/// Pesan dari server kita sendiri (trigger, fungsi) sudah berbahasa Indonesia
/// dan diteruskan apa adanya.
String friendlyError(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'Email atau kata sandi salah.';
    }
    if (m.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Hubungi admin.';
    }
    if (m.contains('rate limit') || e.statusCode == '429') {
      return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
    }
    if (m.contains('different from the old password')) {
      return 'Kata sandi baru harus berbeda dari yang lama.';
    }
    if (m.contains('weak') || m.contains('at least')) {
      return 'Kata sandi terlalu lemah. Pakai minimal 8 karakter.';
    }
    if (m.contains('banned')) return 'Akun ini dinonaktifkan. Hubungi admin.';
    if (_looksOffline(m)) return _offline;
    return 'Tidak bisa masuk. Coba lagi atau hubungi admin.';
  }
  if (e is PostgrestException) {
    switch (e.code) {
      case '42501':
        // Pesan dari trigger kita berbahasa Indonesia; pesan bawaan RLS tidak.
        return e.message.contains('row-level security') ||
                e.message.contains('permission denied')
            ? 'Kamu tidak punya izin untuk tindakan ini.'
            : e.message;
      case '23505':
        return 'Data ini sudah ada.';
      case '23503':
        return 'Data terkait tidak ditemukan atau masih dipakai.';
      case '23514':
      case '22P02':
        return 'Ada isian yang tidak valid. Periksa lagi.';
      case 'PGRST116':
        return 'Data tidak ditemukan.';
    }
    if (e.code == 'P0001') return e.message;
    return 'Server menolak permintaan. Coba lagi. (kode ${e.code ?? '-'})';
  }
  if (e is StorageException) {
    return 'Foto gagal diunggah. Periksa koneksi lalu coba lagi.';
  }
  if (e is FunctionException) {
    final d = e.details;
    final msg = d is Map ? '${d['error'] ?? ''}' : '';
    if (msg.contains('ANTHROPIC_API_KEY') || msg.contains('Claude API')) {
      return 'Layanan AI belum siap. Hubungi admin.';
    }
    if (e.status == 401 || e.status == 403) {
      return 'Kamu tidak punya izin untuk tindakan ini.';
    }
    return 'Layanan sedang bermasalah. Coba lagi sebentar. (kode ${e.status})';
  }
  if (e is TimeoutException) return 'Koneksi terlalu lambat. Coba lagi.';
  var s = '$e';
  if (s.startsWith('Exception: ')) s = s.substring(11);
  if (s.contains('ANTHROPIC_API_KEY') || s.contains('Claude API')) {
    return 'Layanan AI belum siap. Hubungi admin.';
  }
  if (_looksOffline(s.toLowerCase())) return _offline;
  return s;
}

const _offline = 'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.';

bool _looksOffline(String m) =>
    m.contains('failed to fetch') ||
    m.contains('socketexception') ||
    m.contains('clientexception') ||
    m.contains('network') ||
    m.contains('failed host lookup');

DateTime? _parse(dynamic iso) =>
    iso == null ? null : DateTime.tryParse('$iso')?.toLocal();

/// "Sel, 10 Nov 2026, 09.15" dari timestamp server.
String fmtDateTime(dynamic iso) {
  final d = _parse(iso);
  return d == null ? '-' : DateFormat('EEE, d MMM y, HH.mm', 'id').format(d);
}

/// "10 Nov 2026" dari tanggal atau timestamp server.
String fmtDate(dynamic iso) {
  if (iso == null) return '-';
  // Kolom bertipe date ("2026-11-10") tidak punya zona waktu: jangan digeser.
  final s = '$iso';
  final d = s.length == 10 ? DateTime.tryParse(s) : _parse(s);
  return d == null ? '-' : DateFormat('d MMM y', 'id').format(d);
}

/// "10 Nov 2026" atau "10 s.d. 12 Nov 2026" untuk rentang tanggal.
String fmtDateRange(dynamic start, dynamic end) {
  final a = fmtDate(start);
  final b = fmtDate(end);
  return a == b ? a : '$a s.d. $b';
}

void showToast(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String yes = 'Ya',
  String no = 'Batal',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(no)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
      ],
    ),
  );
  return ok == true;
}

const kLeaveTypeLabels = {
  'sick': 'Sakit',
  'permit': 'Izin',
  'off_day': 'Hari Libur',
  'leave': 'Cuti',
};

const kRoleLabels = {
  'field_rep': 'Sales',
  'manager': 'Manajer',
  'admin': 'Admin',
};
