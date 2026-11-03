-- Demo data for Zonein (all text in Indonesian). Repeatable: it removes old demo data first.
-- Run as the database owner (service route / SQL editor): rows are inserted with no signed-in user,
-- so the integrity triggers allow the historical timestamps.
-- Demo accounts: demo.manager@zonein.app and demo.rep1..6@zonein.app, password bigma2026 (change it).
-- Store coordinates are approximate and for illustration. Photo paths are placeholders (no real files).
-- Remove everything with demo_cleanup.sql.

-- 0. start clean (safe to skip on a first run)
delete from public.stores where code like 'DEMO-%';
delete from public.leave_requests where employee_id in (select id from auth.users where email like 'demo.%@zonein.app');
delete from auth.users where email like 'demo.%@zonein.app';

-- 1. accounts
create temp table _u(n int, id uuid default gen_random_uuid(), email text, name text, role text, code text, phone text) on commit drop;
insert into _u(n, email, name, role, code, phone) values
 (0,'demo.manager@zonein.app','Maya Kusuma','manager','DEMO-M01','081200000000'),
 (1,'demo.rep1@zonein.app','Dewi Lestari','field_rep','DEMO-R01','081200000001'),
 (2,'demo.rep2@zonein.app','Rudi Hartono','field_rep','DEMO-R02','081200000002'),
 (3,'demo.rep3@zonein.app','Sari Wulandari','field_rep','DEMO-R03','081200000003'),
 (4,'demo.rep4@zonein.app','Agus Setiawan','field_rep','DEMO-R04','081200000004'),
 (5,'demo.rep5@zonein.app','Putri Rahayu','field_rep','DEMO-R05','081200000005'),
 (6,'demo.rep6@zonein.app','Budi Santoso','field_rep','DEMO-R06','081200000006');

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,
  confirmation_token,recovery_token,email_change,email_change_token_new,email_change_token_current,phone_change,phone_change_token,reauthentication_token)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated','authenticated', email,
  extensions.crypt('bigma2026', extensions.gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('full_name', name, 'role', role),
  now(), now(), '','','','','','','',''
from _u;
insert into auth.identities(id,user_id,provider_id,identity_data,provider,last_sign_in_at,created_at,updated_at)
select gen_random_uuid(), id, id::text, jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true), 'email', now(), now(), now() from _u;
update public.profiles p set employee_code = u.code, phone = u.phone from _u u where p.id = u.id;

-- 2. stores (approximate coordinates)
insert into public.stores(code,name,address,latitude,longitude,geofence_radius_meters,created_by)
select v.code, v.name, v.addr, v.lat, v.lng, v.r, (select id from _u where n = 0) from (values
 ('DEMO-JKT-01','Indomaret Kemang Raya','Jl. Kemang Raya, Jakarta Selatan',-6.2615,106.8133,100),
 ('DEMO-JKT-02','Alfamart Cipete','Jl. Cipete Raya, Jakarta Selatan',-6.2780,106.8000,100),
 ('DEMO-JKT-03','Superindo Fatmawati','Jl. RS Fatmawati, Jakarta Selatan',-6.2920,106.7970,150),
 ('DEMO-JKT-04','Indomaret Tebet Barat','Jl. Tebet Barat Dalam, Jakarta Selatan',-6.2386,106.8530,100),
 ('DEMO-JKT-05','Alfamidi Kuningan','Jl. HR Rasuna Said, Jakarta Selatan',-6.2297,106.8310,100),
 ('DEMO-JKT-06','Ranch Market Senopati','Jl. Senopati, Jakarta Selatan',-6.2350,106.8110,150),
 ('DEMO-JKT-07','Alfamart Kelapa Gading','Jl. Boulevard Raya, Jakarta Utara',-6.1580,106.9050,100),
 ('DEMO-JKT-08','Indomaret Pluit','Jl. Pluit Selatan, Jakarta Utara',-6.1270,106.7900,100),
 ('DEMO-JKT-09','Superindo Cengkareng','Jl. Daan Mogot, Jakarta Barat',-6.1500,106.7350,150),
 ('DEMO-BDG-01','Indomaret Dago','Jl. Ir. H. Juanda, Bandung',-6.8860,107.6130,100),
 ('DEMO-BDG-02','Alfamart Buah Batu','Jl. Buah Batu, Bandung',-6.9510,107.6350,100),
 ('DEMO-BDG-03','Superindo Setiabudi','Jl. Setiabudi, Bandung',-6.8620,107.5950,150),
 ('DEMO-BDG-04','Alfamidi Antapani','Jl. Terusan Jakarta, Bandung',-6.9150,107.6620,100),
 ('DEMO-BDG-05','Toserba Riau','Jl. LLRE Martadinata, Bandung',-6.9060,107.6190,150),
 ('DEMO-BDG-06','Indomaret Cihampelas','Jl. Cihampelas, Bandung',-6.8930,107.6050,100)
) v(code,name,addr,lat,lng,r);

-- 3. assignments (rep -> stores); the tester account gets three Jakarta stores
create temp table _map(n int, code text) on commit drop;
insert into _map values (1,'DEMO-JKT-01'),(1,'DEMO-JKT-02'),(1,'DEMO-JKT-03'),
 (2,'DEMO-JKT-04'),(2,'DEMO-JKT-05'),(2,'DEMO-JKT-06'),
 (3,'DEMO-JKT-07'),(3,'DEMO-JKT-08'),(3,'DEMO-JKT-09'),
 (4,'DEMO-BDG-01'),(4,'DEMO-BDG-02'),(5,'DEMO-BDG-03'),(5,'DEMO-BDG-04'),
 (6,'DEMO-BDG-05'),(6,'DEMO-BDG-06');
create temp table _as on commit drop as
 select u.id rep, u.n, s.id store, s.code, s.latitude lat, s.longitude lng, s.geofence_radius_meters r,
        row_number() over (partition by u.id order by s.code) k
 from _map m join _u u on u.n = m.n join public.stores s on s.code = m.code;
insert into public.store_assignments(employee_id, store_id, assigned_by)
select rep, store, (select id from _u where n = 0) from _as;
insert into public.store_assignments(employee_id, store_id, assigned_by)
select t.id, s.id, (select id from _u where n = 0)
from public.profiles t join auth.users au on au.id = t.id and au.email = 'tester@zonein.app'
join public.stores s on s.code in ('DEMO-JKT-01','DEMO-JKT-02','DEMO-JKT-03');

-- 4. leave requests (some pending, approved, rejected)
insert into public.leave_requests(employee_id, leave_type, start_date, end_date, reason, status, reviewed_by, reviewed_at, created_at)
select u.id, v.t::public.leave_type, (now() at time zone 'Asia/Jakarta')::date + v.s, (now() at time zone 'Asia/Jakarta')::date + v.e,
       v.reason, v.st::public.leave_status,
       case when v.st = 'pending' then null else (select id from _u where n = 0) end,
       case when v.st = 'pending' then null else now() - interval '1 day' end,
       now() - make_interval(days => v.ago)
from (values
 (1,'sick',-9,-9,'Demam dan flu, ada surat dokter.','approved',11),
 (2,'permit',2,2,'Mengurus perpanjangan KTP.','pending',1),
 (3,'leave',7,9,'Acara keluarga di Surabaya.','pending',2),
 (4,'off_day',-4,-4,'Tukar hari libur setelah lembur akhir pekan.','approved',6),
 (5,'leave',10,12,'Cuti tahunan.','pending',1),
 (6,'sick',-6,-5,'Sakit perut.','rejected',8),
 (2,'leave',-20,-18,'Cuti pulang kampung.','approved',25),
 (1,'permit',1,1,'Urusan pribadi.','rejected',2)
) v(n,t,s,e,reason,st,ago) join _u u on u.n = v.n;

-- 5. last 14 days (weekdays only, local time WIB)
create temp table _days on commit drop as
 select d::date d from generate_series((now() at time zone 'Asia/Jakarta')::date - 13, (now() at time zone 'Asia/Jakarta')::date, interval '1 day') d
 where extract(isodow from d) <= 5;

insert into public.attendance_records(employee_id, clock_in_at, clock_in_latitude, clock_in_longitude, clock_in_accuracy_meters, clock_in_selfie_url,
  clock_out_at, clock_out_latitude, clock_out_longitude, clock_out_accuracy_meters, clock_out_selfie_url)
select u.id, x.ci,
  a.lat + ((x.h % 40) - 20) / 111000.0, a.lng + (((x.h / 7) % 40) - 20) / 111000.0, 8 + x.h % 20, 'demo/selfie.jpg',
  x.co,
  case when x.co is null then null else a.lat + (((x.h / 11) % 40) - 20) / 111000.0 end,
  case when x.co is null then null else a.lng + (((x.h / 13) % 40) - 20) / 111000.0 end,
  case when x.co is null then null else 8 + (x.h / 3) % 20 end,
  case when x.co is null then null else 'demo/selfie.jpg' end
from _u u
join _days dd on u.n between 1 and 6
join _as a on a.rep = u.id and a.k = 1
cross join lateral (select abs(hashtext(u.email || dd.d::text)) h) hh
cross join lateral (select hh.h h,
   (dd.d::timestamp + (case when (hh.h / 100) % 100 < 25 then 545 + (hh.h / 10000) % 45 else 470 + (hh.h / 10000) % 65 end) * interval '1 minute') at time zone 'Asia/Jakarta' ci,
   case when dd.d >= (now() at time zone 'Asia/Jakarta')::date then null
        when (hh.h / 1000000) % 100 < 7 and dd.d < (now() at time zone 'Asia/Jakarta')::date - 2 then null
        else (dd.d::timestamp + (990 + (hh.h / 7) % 90) * interval '1 minute') at time zone 'Asia/Jakarta' end co) x
where hh.h % 100 >= 8
  and x.ci <= now()
  and not exists (select 1 from public.leave_requests l where l.employee_id = u.id and l.status = 'approved'
                  and dd.d between l.start_date and l.end_date);

-- 6. store visits (the geofence trigger computes distance and inside/outside)
create temp table _v on commit drop as
select * from (select gen_random_uuid() id, u.id rep, a.store, a.lat, a.lng, dd.d, s.slot, abs(hashtext(u.email || dd.d::text || s.slot::text)) h,
       (dd.d::timestamp + (case s.slot when 0 then 605 when 1 then 700 else 800 end + abs(hashtext(u.email || dd.d::text || s.slot::text)) % 20) * interval '1 minute') at time zone 'Asia/Jakarta' ts
from _u u
join _days dd on u.n between 1 and 6
cross join generate_series(0, 2) s(slot)
join _as a on a.rep = u.id and a.k = 1 + ((s.slot + extract(day from dd.d)::int) % (select count(*) from _as b where b.rep = u.id))
where exists (select 1 from public.attendance_records r where r.employee_id = u.id and (r.clock_in_at at time zone 'Asia/Jakarta')::date = dd.d)
  and (s.slot < 2 or abs(hashtext(u.email || dd.d::text)) % 2 = 0)) q where q.ts <= now();

insert into public.store_visits(id, employee_id, store_id, visit_started_at, visit_ended_at, check_in_latitude, check_in_longitude, check_in_accuracy_meters, store_photo_url, notes)
select id, rep, store, ts, least(ts + (15 + h % 25) * interval '1 minute', now()),
  lat + (case when (h / 13) % 100 < 80 then 15 + h % 60 else 160 + h % 240 end) / 111000.0, lng, 8 + h % 15, 'demo/store.jpg',
  (array['Stok aman, display rapi.','Rak mi instan kosong dua baris, sudah dilaporkan ke gudang.','Promo minggu ini belum dipasang.',
         'Kasir menanyakan jadwal pengiriman berikutnya.',null,null])[1 + h % 6]
from _v;

-- 7. products, sales, prices
create temp table _p(i int, name text, price int) on commit drop;
insert into _p values (0,'Mie Instan Goreng 85g',3500),(1,'Mie Instan Kuah Soto 70g',3300),(2,'Teh Botol 450ml',6000),(3,'Air Mineral 600ml',4000),
 (4,'Kopi Sachet 3in1',1500),(5,'Biskuit Kelapa 120g',9500),(6,'Minyak Goreng 1L',19500),(7,'Sabun Mandi Cair 250ml',22000),
 (8,'Susu UHT Cokelat 200ml',6500),(9,'Keripik Singkong 80g',8500);

insert into public.sales_reports(employee_id, store_id, product_name, units_sold, sale_date, created_at)
select v.rep, v.store, p.name, 3 + abs(hashtext(v.id::text || k.k::text)) % 38, v.d, v.ts + interval '20 minutes'
from _v v cross join generate_series(0, 2) k(k)
join _p p on p.i = (v.h % 10 + k.k * 3) % 10
where v.ts + interval '20 minutes' <= now();

insert into public.price_reports(employee_id, store_id, product_name, price_idr, is_promo, notes, created_at)
select v.rep, v.store, p.name,
  (round(p.price * (95 + abs(hashtext(v.store::text)) % 11) / 100.0 * (case when (v.h / 3) % 100 < 20 then 0.85 else 1 end) / 50.0) * 50)::int,
  (v.h / 3) % 100 < 20, case when (v.h / 3) % 100 < 20 then 'Harga promo terpasang di rak.' else null end, v.ts + interval '10 minutes'
from _v v cross join generate_series(0, 1) k(k)
join _p p on p.i = (v.h % 10 + k.k * 4) % 10
where (v.h / 17) % 100 < 55;

-- 8. shelf checks (analysis uses the same keys as the AI function) and display photos
create temp table _sc(i int, summary text, analysis jsonb) on commit drop;
insert into _sc values
 (0,'Rak terisi penuh, semua produk fokus terlihat dan harga terpasang.',
  '{"shelf":{"category":"Mi instan dan minuman","total_facings":42,"fullness_pct":96,"our_share_pct":38,"summary":"Rak penuh dan rapi."},
    "products":[{"name":"Mie Instan Goreng 85g","status":"ok","facings":8,"shelf_row":"baris 2","confidence":"high","note":"Harga terpasang."}],
    "gaps":[],
    "key_actions":[{"priority":1,"action":"Pertahankan susunan rak saat ini.","product":null,"why":"Rak penuh dan harga terpasang lengkap.","urgency":"next_visit","owner":"rep"}]}'),
 (1,'Rak terisi sekitar 85 persen, ada satu celah di baris kedua.',
  '{"shelf":{"category":"Mi instan dan minuman","total_facings":38,"fullness_pct":85,"our_share_pct":34,"summary":"Satu celah terlihat di baris kedua."},
    "products":[{"name":"Mie Instan Goreng 85g","status":"low","facings":3,"shelf_row":"baris 2","confidence":"high","note":"Facing menipis."}],
    "gaps":[{"location":"Baris kedua, kiri dari mi instan goreng","description":"Ruang kosong sekitar dua facing.","likely_product":"Mie Instan Goreng 85g"}],
    "key_actions":[{"priority":1,"action":"Ambil 2 dus Mie Instan Goreng 85g dari gudang belakang dan isi celah di baris kedua.","product":"Mie Instan Goreng 85g","why":"Produk laris dan celahnya terlihat pelanggan.","urgency":"now","owner":"rep"}]}'),
 (2,'Rak terisi sekitar dua pertiga dengan dua celah terlihat.',
  '{"shelf":{"category":"Minuman dan kopi","total_facings":36,"fullness_pct":68,"our_share_pct":29,"summary":"Dua celah, teh botol dan kopi sachet."},
    "products":[{"name":"Teh Botol 450ml","status":"out","facings":0,"shelf_row":"baris 1","confidence":"medium","note":"Kosong."},{"name":"Kopi Sachet 3in1","status":"low","facings":2,"shelf_row":"baris 3","confidence":"high","note":"Tinggal sedikit."}],
    "gaps":[{"location":"Baris pertama, kanan","description":"Teh botol habis.","likely_product":"Teh Botol 450ml"},{"location":"Baris ketiga, tengah","description":"Kopi sachet tinggal dua facing.","likely_product":"Kopi Sachet 3in1"}],
    "key_actions":[{"priority":1,"action":"Isi ulang Teh Botol 450ml dari stok belakang.","product":"Teh Botol 450ml","why":"Rak kosong, penjualan hilang.","urgency":"now","owner":"rep"},{"priority":2,"action":"Bicarakan tambahan ruang rak untuk minuman dengan manajer toko.","product":null,"why":"Ruang rak sempit untuk produk yang laris.","urgency":"next_visit","owner":"manager"}]}'),
 (3,'Rak hanya terisi separuh, tiga celah dan satu produk habis.',
  '{"shelf":{"category":"Kebutuhan dapur dan minuman","total_facings":34,"fullness_pct":52,"our_share_pct":24,"summary":"Banyak celah, perlu restok segera."},
    "products":[{"name":"Minyak Goreng 1L","status":"out","facings":0,"shelf_row":"baris 4","confidence":"high","note":"Habis."},{"name":"Air Mineral 600ml","status":"low","facings":2,"shelf_row":"baris 1","confidence":"medium","note":"Menipis."}],
    "gaps":[{"location":"Baris pertama, kiri","description":"Air mineral menipis.","likely_product":"Air Mineral 600ml"},{"location":"Baris keempat","description":"Minyak goreng habis.","likely_product":"Minyak Goreng 1L"},{"location":"Baris ketiga, kanan","description":"Biskuit kelapa tinggal sedikit.","likely_product":"Biskuit Kelapa 120g"}],
    "key_actions":[{"priority":1,"action":"Isi Air Mineral 600ml dan Biskuit Kelapa 120g dari gudang toko.","product":"Air Mineral 600ml","why":"Celah terlihat di baris depan.","urgency":"now","owner":"rep"},{"priority":2,"action":"Hubungi tim suplai: stok Minyak Goreng 1L habis di toko ini.","product":"Minyak Goreng 1L","why":"Tidak ada stok pengganti di gudang toko.","urgency":"this_visit","owner":"manager"}]}');

insert into public.shelf_checks(employee_id, store_id, store_visit_id, photo_path, summary, analysis, model, created_at)
select w.rep, w.store, w.id, 'demo/shelf.jpg', c.summary, c.analysis, 'demo-seed', w.ts + interval '25 minutes'
from (select v.*, row_number() over (order by v.ts desc) rn from _v v where v.ts + interval '25 minutes' <= now()) w
join _sc c on c.i = w.h % 4
where w.rn % 5 = 1 or w.rn <= 3;

insert into public.product_placements(store_visit_id, placement_type, photo_url, notes)
select id, 'main_shelf', 'demo/osa.jpg', 'Display rak utama sesuai standar.' from (select v.*, row_number() over (order by v.ts) rn from _v v) q where rn % 3 = 0;
insert into public.product_placements(store_visit_id, placement_type, photo_url, notes)
select id, 'checkout_display', 'demo/osa.jpg', null from (select v.*, row_number() over (order by v.ts) rn from _v v) q where rn % 6 = 0;

-- 9. AI insights (sample text)
insert into public.ai_insights(created_by, period_days, insight, data_summary, model, created_at)
select (select id from _u where n = 0), v.pd, v.ins::jsonb, '{"catatan":"Data contoh dari skrip seed"}'::jsonb, 'demo-seed', now() - make_interval(days => v.ago)
from (values
 (7,'{"headline":"Mi instan terjual paling banyak minggu ini, tetapi rak minuman sering kosong (data contoh).",
   "findings":[{"title":"Mi instan goreng paling laris","detail":"Penjualan unit tertinggi di sebagian besar toko Jakarta.","evidence":"Berdasarkan laporan penjualan 7 hari terakhir."},
               {"title":"Teh botol sering kosong di rak","detail":"Beberapa cek rak menandai teh botol habis.","evidence":"Terlihat di beberapa cek rak minggu ini."},
               {"title":"Beberapa kunjungan di luar zona","detail":"Sebagian check-in berjarak di atas radius toko.","evidence":"Lihat tabel Kunjungan di Dasbor."}],
   "restock_risks":[{"product":"Teh Botol 450ml","stores":["Alfamart Cipete","Indomaret Dago"],"why":"Ditandai habis pada cek rak terakhir."},
                    {"product":"Minyak Goreng 1L","stores":["Superindo Cengkareng"],"why":"Stok habis dan tidak ada pengganti."}],
   "price_notes":["Harga promo terlihat di beberapa toko Bandung.","Harga Air Mineral 600ml bervariasi antar toko."],
   "actions":[{"action":"Kirim restok Teh Botol 450ml ke dua toko yang kosong.","who":"manager","why":"Menghindari kehilangan penjualan."},
              {"action":"Minta tim lapangan memastikan check-in dilakukan di dalam toko.","who":"manager","why":"Menjaga data kunjungan akurat."}],
   "data_gaps":["Data penjualan baru dari sebagian toko."]}',1),
 (30,'{"headline":"Dalam 30 hari, kehadiran stabil dan penjualan merata di Jakarta dan Bandung (data contoh).",
   "findings":[{"title":"Kehadiran stabil","detail":"Sebagian besar tim absen masuk tepat waktu.","evidence":"Lihat laporan Absensi."},
               {"title":"Celah rak berulang di toko yang sama","detail":"Toko tertentu berulang kali menunjukkan celah.","evidence":"Berdasarkan cek rak 30 hari."}],
   "restock_risks":[{"product":"Air Mineral 600ml","stores":["Indomaret Pluit"],"why":"Sering menipis di rak depan."}],
   "price_notes":["Promo biskuit kelapa muncul di tiga toko."],
   "actions":[{"action":"Tinjau jadwal kunjungan toko dengan celah berulang.","who":"manager","why":"Mengurangi rak kosong."}],
   "data_gaps":["Belum ada data penjualan minggu pertama."]}',3)
) v(pd, ins, ago);

