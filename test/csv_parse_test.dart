import 'package:flutter_test/flutter_test.dart';
import 'package:zonein/features/admin/csv_import_screen.dart';

void main() {
  test('parses quotes, CRLF, BOM and semicolons', () {
    final a = parseCsv('﻿kode,nama\r\nST-1,"Toko, Satu"\r\nST-2,"Dia ""X"""\r\n\r\n');
    expect(a, [
      ['kode', 'nama'],
      ['ST-1', 'Toko, Satu'],
      ['ST-2', 'Dia "X"'],
    ]);
    final b = parseCsv('kode;nama;lintang\nST-3;Toko Tiga;-6,2\n');
    expect(b[1], ['ST-3', 'Toko Tiga', '-6,2']);
  });
}
