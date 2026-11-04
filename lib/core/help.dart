import 'package:flutter/material.dart';

/// Panduan singkat per layar. Semua teks dalam Bahasa Indonesia.
/// Isi ditulis berdasarkan perilaku aplikasi yang sebenarnya (kode dan
/// aturan database). Jika perilaku berubah, ubah teks di sini juga.
class HelpContent {
  const HelpContent({
    required this.title,
    required this.what,
    required this.who,
    required this.steps,
    this.rules = const [],
    this.notEnforced = const [],
  });

  final String title;
  final String what;
  final String who;
  final List<String> steps;
  final List<String> rules;
  final List<String> notEnforced;
}

enum HelpTopic {
  guide,
  attendance,
  storeVisit,
  osa,
  shelfCheck,
  sales,
  leave,
  pricing,
  myAttendance,
  summary,
  insights,
  stores,
  assignments,
  leaveReview,
  attendanceAll,
  visitReport,
  addUser,
  csvStores,
  csvAssignments,
}

const _contents = <HelpTopic, HelpContent>{
  HelpTopic.guide: HelpContent(
    title: 'Panduan Zonein',
    what:
        'Zonein membantu tim lapangan mencatat absensi, kunjungan toko, penjualan, harga, dan cuti, lalu membantu manajer membaca hasilnya.',
    who:
        'Sales lapangan memakai menu "Pekerjaanmu". Manajer dan admin juga melihat "Alat Manajer". Menu "Admin" hanya muncul untuk akun admin utama.',
    steps: [
      'Sales: absen masuk di awal hari, kunjungi toko yang ditugaskan, isi rak, penjualan, dan harga, lalu absen pulang.',
      'Manajer: tugaskan toko ke sales, tinjau cuti, dan lihat laporan.',
      'Admin: tambah karyawan baru dan beri perannya.',
      'Setiap layar punya tombol ? di pojok kanan atas untuk penjelasan layar itu.',
    ],
    rules: [
      'Sales hanya melihat data miliknya sendiri. Manajer dan admin melihat data semua orang.',
      'Foto selfie dan foto toko disimpan privat, hanya pemilik dan manajer/admin yang bisa melihat.',
    ],
  ),
  HelpTopic.attendance: HelpContent(
    title: 'Absensi',
    what: 'Mencatat jam masuk dan jam pulang kerja dengan selfie dan lokasi GPS.',
    who: 'Semua karyawan.',
    steps: [
      'Tekan "Absen Masuk", izinkan lokasi, lalu ambil selfie dengan kamera depan.',
      'Setelah berhasil, status berubah menjadi "Sudah absen masuk" dan tombol menjadi "Absen Pulang".',
      'Di akhir kerja tekan "Absen Pulang" dan ambil selfie lagi.',
    ],
    rules: [
      'GPS harus aktif dan izin lokasi harus diberikan. Tanpa itu absen ditolak.',
      'Selfie wajib untuk absen masuk dan absen pulang.',
      'Selama belum absen pulang, tombol tetap "Absen Pulang". Tidak bisa absen masuk dua kali berturut-turut lewat aplikasi.',
      'Waktu masuk dicatat oleh server. Waktu pulang diambil dari jam perangkatmu.',
      'Akurasi GPS ikut disimpan agar manajer bisa menilai seberapa bisa dipercaya lokasinya.',
    ],
    notEnforced: [
      'Tidak ada batas radius. Kamu bisa absen dari mana saja, lokasi hanya dicatat sebagai bukti.',
      'Tidak ada jam kerja, batas jam masuk, atau status "terlambat". Aplikasi tidak menghitung keterlambatan.',
      'Tidak ada batas satu kali absen per hari dan tidak ada penutupan otomatis. Jika lupa absen pulang, absen tetap terbuka sampai kamu absen pulang.',
      'Aplikasi tidak mendeteksi lokasi palsu (fake GPS).',
    ],
  ),
  HelpTopic.storeVisit: HelpContent(
    title: 'Kunjungan Toko',
    what: 'Mencatat kunjunganmu ke toko dengan foto toko dan lokasi, lalu lanjut mengisi ketersediaan produk di rak.',
    who: 'Sales lapangan. Hanya toko yang ditugaskan kepadamu yang muncul.',
    steps: [
      'Pilih toko dari daftar.',
      'Tekan check-in, izinkan lokasi, lalu foto tampak toko.',
      'Aplikasi langsung membuka layar "Ketersediaan di Rak" untuk kunjungan ini.',
    ],
    rules: [
      'Jarak ke toko dihitung otomatis oleh server dari lokasimu dan titik toko. Kamu tidak bisa mengisinya sendiri.',
      'Jika jarakmu lebih jauh dari radius toko (bawaan 100 meter, bisa diubah per toko), kunjungan tetap tersimpan tetapi ditandai "di luar zona" di laporan manajer.',
      'GPS dan foto toko wajib.',
    ],
    notEnforced: [
      'Berada di luar zona tidak memblokir kunjungan, hanya menandainya.',
      'Tidak ada tombol selesai kunjungan, jam keluar tidak dicatat.',
      'Aplikasi tidak mendeteksi lokasi palsu (fake GPS).',
    ],
  ),
  HelpTopic.osa: HelpContent(
    title: 'Ketersediaan di Rak',
    what: 'Memotret tempat produk dipajang di toko: rak utama, display kasir, dan display tambahan.',
    who: 'Sales lapangan, otomatis terbuka setelah check-in kunjungan toko.',
    steps: [
      'Ketuk salah satu lokasi pajang, lalu foto kondisi display.',
      'Status berubah menjadi "Tersimpan" setelah foto terkirim.',
      'Tekan "Selesai" setelah semua lokasi yang ada difoto.',
    ],
    rules: ['Foto terkait ke kunjungan yang baru kamu buat dan bisa dilihat manajer.'],
    notEnforced: ['Tidak wajib memotret ketiga lokasi. Aplikasi tidak mengecek kelengkapannya.'],
  ),
  HelpTopic.shelfCheck: HelpContent(
    title: 'Cek Rak',
    what: 'Kamu memotret satu lorong rak, lalu AI membaca foto dan memberi daftar produk yang perlu direstok.',
    who: 'Sales lapangan.',
    steps: [
      'Pilih toko, lalu foto lorong rak dari depan dan seluruh rak terlihat.',
      'Tunggu hasil. Bagian "Tindakan utama" ditampilkan paling atas.',
    ],
    rules: [
      'Hasil adalah perkiraan AI dari satu foto. Foto buram, gelap, atau terpotong membuat hasil kurang akurat.',
      'Hasil disimpan dan bisa dilihat manajer di Dasbor.',
    ],
    notEnforced: ['Akurasi AI belum diuji pada banyak foto toko nyata. Anggap sebagai saran, bukan fakta.'],
  ),
  HelpTopic.sales: HelpContent(
    title: 'Input Penjualan',
    what: 'Mencatat jumlah unit produk yang terjual di sebuah toko pada suatu tanggal.',
    who: 'Sales lapangan.',
    steps: [
      'Pilih toko, isi nama produk dan jumlah unit, pilih tanggal.',
      'Simpan. Entri terbaru muncul di daftar bawah.',
    ],
    rules: ['Hanya jumlah unit yang dicatat, belum nilai uang.', 'Data yang sudah tersimpan tidak bisa diubah dari aplikasi.'],
  ),
  HelpTopic.leave: HelpContent(
    title: 'Cuti',
    what: 'Mengajukan sakit, izin, libur, atau cuti, dan melihat statusnya.',
    who: 'Semua karyawan.',
    steps: [
      'Pilih jenis, tanggal mulai dan selesai, tulis alasan, lalu kirim.',
      'Status awal "menunggu". Manajer atau admin akan menyetujui atau menolak.',
      'Pengajuan yang masih menunggu bisa kamu batalkan.',
    ],
    rules: ['Tanggal selesai tidak boleh sebelum tanggal mulai.'],
    notEnforced: [
      'Cuti yang disetujui tidak mengunci absensi dan tidak mengurangi jatah cuti. Belum ada hitungan jatah cuti.',
    ],
  ),
  HelpTopic.pricing: HelpContent(
    title: 'Harga',
    what: 'Melaporkan harga produk di rak toko, termasuk apakah sedang promo.',
    who: 'Sales lapangan.',
    steps: ['Pilih toko, isi nama produk dan harga dalam Rupiah, centang promo bila ada, lalu simpan.'],
    rules: ['Harga tidak boleh negatif.', 'Laporan harga bisa dilihat manajer di Penjualan dan harga.'],
  ),
  HelpTopic.myAttendance: HelpContent(
    title: 'Laporan Kehadiran',
    what: 'Riwayat absensimu: jam masuk, jam pulang, foto, dan lokasi.',
    who: 'Semua karyawan melihat riwayatnya sendiri.',
    steps: ['Gunakan ikon filter untuk memilih rentang tanggal.', 'Ketuk satu baris untuk melihat foto dan lokasi.'],
    rules: ['Menampilkan paling banyak 200 catatan terbaru.'],
  ),
  HelpTopic.summary: HelpContent(
    title: 'Ringkasan Aktivitas',
    what: 'Ringkasan bulan ini: jumlah absen, kunjungan toko (di dalam dan di luar zona), dan cuti yang menunggu.',
    who: 'Semua karyawan, hanya data milikmu sendiri.',
    steps: ['Buka layar ini kapan saja untuk melihat angka bulan berjalan.'],
  ),
  HelpTopic.insights: HelpContent(
    title: 'Wawasan AI',
    what:
        'AI membaca data penjualan, harga, dan hasil cek rak dari periode yang dipilih, lalu menulis ringkasan, risiko, dan tindakan yang disarankan.',
    who: 'Manajer dan admin.',
    steps: [
      'Pilih periode, lalu tekan tombol untuk membuat wawasan baru.',
      'Wawasan terakhir langsung tampil saat layar dibuka, jadi tidak perlu membuat ulang.',
      'Baca "Tindakan": tiap tindakan menyebut siapa yang melakukan (sales atau manajer) dan alasannya.',
    ],
    rules: [
      'Setiap pembuatan wawasan memakai kredit AI. Kartu "Perkiraan sisa kredit AI" menunjukkan perkiraan dari anggaran \$5.',
      'AI hanya melihat data yang sudah diisi tim. Jika datanya sedikit, AI akan menyebutnya di "Kekurangan data".',
    ],
    notEnforced: ['Angka sisa kredit hanyalah perkiraan, bukan saldo resmi dari penyedia AI.'],
  ),
  HelpTopic.stores: HelpContent(
    title: 'Kelola Toko',
    what: 'Menambah dan mengubah daftar toko beserta titik lokasi dan radius zonanya.',
    who: 'Manajer dan admin.',
    steps: [
      'Tambah toko satu per satu, atau tekan ikon unggah untuk impor banyak toko dari CSV.',
      'Isi kode toko unik, nama, alamat, lintang, bujur, dan radius.',
    ],
    rules: [
      'Radius adalah batas jarak sales saat check-in kunjungan. Bawaan 100 meter. Toko di mal sering butuh radius lebih besar.',
      'Kode toko harus unik.',
    ],
  ),
  HelpTopic.assignments: HelpContent(
    title: 'Penugasan Toko',
    what: 'Menentukan sales mana yang mengunjungi toko mana.',
    who: 'Manajer dan admin.',
    steps: [
      'Pilih sales dan toko untuk membuat penugasan, atau impor banyak penugasan lewat ikon unggah (CSV).',
      'Nonaktifkan penugasan jika sales tidak lagi memegang toko itu.',
    ],
    rules: ['Sales hanya bisa melakukan kunjungan, input penjualan, dan lapor harga di toko yang ditugaskan kepadanya.'],
  ),
  HelpTopic.leaveReview: HelpContent(
    title: 'Tinjau Pengajuan Cuti',
    what: 'Menyetujui atau menolak pengajuan cuti karyawan.',
    who: 'Manajer dan admin.',
    steps: ['Buka pengajuan yang menunggu, baca alasan dan tanggal, lalu setujui atau tolak.'],
    rules: ['Semua manajer dan admin bisa meninjau pengajuan siapa pun. Belum ada atasan khusus per karyawan.'],
  ),
  HelpTopic.attendanceAll: HelpContent(
    title: 'Laporan Absensi',
    what: 'Melihat absensi semua karyawan: jam masuk, jam pulang, selfie, lokasi, dan akurasi GPS.',
    who: 'Manajer dan admin.',
    steps: ['Pilih rentang tanggal dengan ikon filter.', 'Ketuk satu baris untuk melihat selfie dan lokasi.'],
    rules: [
      'Akurasi GPS yang besar berarti lokasi kurang pasti. Periksa selfie bila ragu.',
      'Menampilkan paling banyak 200 catatan terbaru.',
    ],
    notEnforced: ['Tidak ada kolom "terlambat" karena aplikasi tidak punya aturan jam kerja.'],
  ),
  HelpTopic.visitReport: HelpContent(
    title: 'Laporan Kunjungan Toko',
    what: 'Melihat semua kunjungan sales ke toko, jaraknya dari toko, dan apakah di dalam zona.',
    who: 'Manajer dan admin.',
    steps: ['Cari kunjungan yang ditandai di luar zona.', 'Buka peta zona untuk melihat posisi sales terhadap radius toko.'],
    rules: ['Jarak dihitung server, bukan oleh sales.'],
    notEnforced: ['Lokasi palsu (fake GPS) tidak terdeteksi.'],
  ),
  HelpTopic.addUser: HelpContent(
    title: 'Tambah Karyawan',
    what: 'Membuat akun baru lengkap dengan peran.',
    who: 'Hanya akun admin utama.',
    steps: [
      'Isi nama, email, kata sandi awal, dan peran (sales, manajer, admin).',
      'Beri tahu orangnya untuk masuk dan segera mengganti kata sandi.',
    ],
    rules: ['Sales melihat data sendiri. Manajer dan admin melihat semua data.'],
    notEnforced: ['Belum ada layar ganti kata sandi di aplikasi.'],
  ),
  HelpTopic.csvStores: HelpContent(
    title: 'Impor Toko dari CSV',
    what: 'Menambah banyak toko sekaligus dari satu file CSV.',
    who: 'Manajer dan admin.',
    steps: [
      'Tekan "Salin contoh", tempel ke Excel atau Google Sheets, isi data, simpan sebagai CSV.',
      'Pilih file, periksa hasil pratinjau, lalu impor.',
    ],
    rules: [
      'Kolom: kode, nama, alamat, lintang, bujur, radius.',
      'Toko dengan kode yang sudah ada dilewati. Radius harus 10 sampai 5000 meter. Ukuran file maksimal 2 MB.',
    ],
  ),
  HelpTopic.csvAssignments: HelpContent(
    title: 'Impor Penugasan dari CSV',
    what: 'Menugaskan banyak sales ke banyak toko sekaligus dari satu file CSV.',
    who: 'Manajer dan admin.',
    steps: [
      'Tekan "Salin contoh", isi email sales dan kode toko, simpan sebagai CSV.',
      'Pilih file, periksa pratinjau, lalu impor.',
    ],
    rules: [
      'Kolom: email, kode_toko (atau nama_toko).',
      'Hanya akun sales yang bisa ditugaskan. Penugasan yang sudah aktif dilewati.',
    ],
  ),
};

/// Satu kalimat sederhana yang tampil langsung di bawah judul layar.
const _quick = <HelpTopic, String>{
  HelpTopic.guide: 'Buka menu sesuai tugasmu. Ketuk ? di layar mana pun untuk penjelasan.',
  HelpTopic.attendance: 'Ketuk Absen Masuk lalu selfie. Pulang kerja, ketuk Absen Pulang lalu selfie.',
  HelpTopic.storeVisit: 'Pilih toko, ketuk check-in, foto tampak toko. Lalu foto tiap display.',
  HelpTopic.osa: 'Ketuk tiap lokasi pajang, foto displaynya, lalu ketuk Selesai.',
  HelpTopic.shelfCheck: 'Pilih toko, foto satu lorong rak. AI memberi daftar yang perlu direstok.',
  HelpTopic.sales: 'Pilih toko, isi nama produk dan jumlah unit terjual, lalu simpan.',
  HelpTopic.leave: 'Pilih jenis dan tanggal, tulis alasan, kirim. Tunggu manajer menyetujui.',
  HelpTopic.pricing: 'Pilih toko, isi nama produk dan harga di rak, centang bila promo, simpan.',
  HelpTopic.myAttendance: 'Daftar absensimu. Ketuk satu baris untuk melihat foto dan lokasi.',
  HelpTopic.summary: 'Angka absen, kunjungan, dan cutimu bulan ini.',
  HelpTopic.insights: 'Pilih periode, ketuk tombol buat wawasan. AI menulis ringkasan dan saran tindakan.',
  HelpTopic.stores: 'Tambah toko dan atur radius zonanya. Banyak toko sekaligus: ikon unggah.',
  HelpTopic.assignments: 'Pilih sales dan toko untuk menugaskan. Banyak sekaligus: ikon unggah.',
  HelpTopic.leaveReview: 'Buka pengajuan, baca alasannya, lalu setujui atau tolak.',
  HelpTopic.attendanceAll: 'Absensi semua karyawan. Ketuk satu baris untuk melihat selfie dan lokasi.',
  HelpTopic.visitReport: 'Semua kunjungan sales. Cari yang bertanda di luar zona.',
  HelpTopic.addUser: 'Isi nama, email, kata sandi awal, dan peran. Minta orangnya segera ganti kata sandi.',
  HelpTopic.csvStores: 'Ketuk Salin contoh, isi di spreadsheet, simpan CSV, lalu pilih file di sini.',
  HelpTopic.csvAssignments: 'Ketuk Salin contoh, isi email sales dan kode toko, simpan CSV, pilih file.',
};

/// Strip petunjuk singkat di bawah judul layar. Ketuk untuk detail lengkap.
class HelpBar extends StatelessWidget implements PreferredSizeWidget {
  const HelpBar(this.topic, {super.key});
  final HelpTopic topic;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer.withAlpha(90),
      child: InkWell(
        onTap: () => showHelpSheet(context, topic),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.lightbulb_outline, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _quick[topic]!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface),
                ),
              ),
              const SizedBox(width: 8),
              Text('Detail', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.primary)),
            ]),
          ),
        ),
      ),
    );
  }
}

HelpContent helpFor(HelpTopic t) => _contents[t]!;

class HelpButton extends StatelessWidget {
  const HelpButton(this.topic, {super.key});
  final HelpTopic topic;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Bantuan',
        icon: const Icon(Icons.help_outline),
        onPressed: () => showHelpSheet(context, topic),
      );
}

Future<void> showHelpSheet(BuildContext context, HelpTopic topic) {
  final c = helpFor(topic);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      final cs = Theme.of(ctx).colorScheme;
      Widget section(String head, List<String> items, {Color? dot}) => items.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(head, style: t.titleSmall),
                const SizedBox(height: 6),
                for (final s in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 10),
                        child: Container(width: 5, height: 5, decoration: BoxDecoration(color: dot ?? cs.primary, shape: BoxShape.circle)),
                      ),
                      Expanded(child: Text(s, style: t.bodyMedium)),
                    ]),
                  ),
              ]),
            );
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Text(c.title, style: t.titleLarge),
            const SizedBox(height: 8),
            Text(c.what, style: t.bodyMedium),
            section('Siapa yang memakai', [c.who]),
            section('Langkah', c.steps),
            section('Aturan yang berlaku', c.rules),
            section('Belum ada / tidak dicek', c.notEnforced, dot: cs.error),
          ],
        ),
      );
    },
  );
}
