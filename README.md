Lakukan **FINAL AUDIT menyeluruh** pada project Flutter **QQ Jaya Cell** yang sekarang.

Semua modul utama sudah diimplementasikan. Jangan menambahkan fitur baru dan jangan redesign aplikasi.

Tujuan audit ini adalah memastikan aplikasi benar-benar siap digunakan dan semua fitur saling terhubung dengan benar.

## 1. Jangan langsung mengubah kode

Audit project terlebih dahulu.

Petakan:

- seluruh shortcut Dashboard
- seluruh halaman
- route/navigation
- model
- repository/service
- API endpoint
- tabel database
- sumber data Dashboard
- Riwayat
- Rekap

Cari fitur yang:

- tombolnya mati
- route salah
- masih dummy
- masih hardcoded
- belum terhubung API
- menggunakan endpoint lama
- response JSON bermasalah
- mempunyai perhitungan berbeda dengan modul lain

Setelah audit, langsung perbaiki masalah yang ditemukan.

## 2. Audit seluruh shortcut Dashboard

Cek satu per satu SEMUA shortcut yang sekarang tampil di Dashboard.

Jangan hanya memeriksa shortcut yang disebut dalam prompt ini.

Setiap shortcut harus:

- bisa ditekan
- membuka halaman yang benar
- tidak membuka placeholder
- tidak error
- menggunakan data nyata jika memang fitur berbasis data

Khusus pastikan flow utama:

### Penjualan Barang
`Dashboard → Penjualan → transaksi`

### Servis
`Dashboard → Servis → tambah/detail/status/pembayaran`

### Jual Beli HP
Harus tersedia flow:

`Beli HP`
`Jual HP langsung`
`Stok HP → Jual HP`

### Voucher
`Tambah Voucher → Stok → Jual`

### Pulsa & Paket
`Jual Pulsa`
`Jual Paket Data`

### Pengeluaran
`Tambah → Edit → Hapus`

### Riwayat
Semua jenis transaksi dapat ditemukan.

### Rekap
Semua perhitungan berasal dari transaksi database.

## 3. Cari placeholder/dummy

Search seluruh project untuk kemungkinan:

- dummy
- mock
- sample
- testData
- hardcoded transaksi
- Future.delayed simulasi
- TODO fitur utama
- endpoint testing
- data lokal sementara

Jangan menghapus sesuatu hanya karena namanya `test`.

Periksa reference terlebih dahulu.

Hapus hanya dummy/runtime placeholder yang memang tidak lagi diperlukan.

Unit/widget test yang valid tidak perlu dihapus.

## 4. Audit API

Petakan semua endpoint yang benar-benar dipanggil aplikasi.

Pastikan:

- base URL konsisten
- endpoint tidak mati
- HTTP method benar
- parameter benar
- response konsisten
- error menghasilkan JSON
- response kosong ditangani

Tidak boleh ada lagi runtime error:

`JSON invalid`

`Unexpected end of input`

atau crash karena `jsonDecode()` body kosong.

Jangan hanya menyembunyikan error Flutter.

Jika backend menghasilkan response salah, perbaiki backend.

## 5. Audit database

Pastikan seluruh modul benar-benar menggunakan MySQL/API:

- Barang
- Penjualan
- Servis
- Pembayaran Servis
- HP
- Voucher
- Pulsa
- Paket Data
- Pengeluaran
- Riwayat
- Rekap

Periksa:

- tabel
- column
- foreign key/relation jika ada
- status
- timestamp
- query

Jangan gunakan `data.json` sebagai database aplikasi.

## 6. Audit transaksi Barang

Test:

`pilih barang → quantity → jual → stok berkurang → transaksi tersimpan`

Pastikan:

- omzet benar
- modal benar
- keuntungan benar
- Riwayat muncul
- Rekap berubah
- Dashboard berubah

Stok tidak boleh negatif.

## 7. Audit Servis

Test seluruh lifecycle:

`Masuk → Menunggu → Dikerjakan → Selesai`

Periksa:

- merk/model
- pekerjaan
- biaya
- pelanggan opsional
- pembayaran lunas
- DP
- pelunasan
- sisa pembayaran
- ongkir
- garansi
- detail servis

Pastikan perubahan status tersimpan database.

Pastikan pembayaran tidak dihitung dua kali sebagai omzet/keuntungan.

## 8. Audit HP

Test dua flow.

### HP stok

`Beli HP → masuk stok → Jual HP → terjual`

### HP langsung

`Jual HP → input HP baru → transaksi`

Pastikan:

- modal
- harga jual
- keuntungan
- status
- Riwayat
- Rekap
- Dashboard

benar.

HP terjual tidak boleh dijual dua kali.

## 9. Audit Voucher

Test:

`Tambah 10 → stok 10 → jual 1 → stok 9`

Pastikan keuntungan:

`(harga jual - modal) × quantity`

Scanner jangan menyebabkan crash jika kamera/permission bermasalah.

Manual input harus tetap tersedia.

## 10. Audit Pulsa & Paket

Test Pulsa dan Paket secara terpisah.

Pastikan:

- nomor tujuan tetap string
- angka 0 depan tidak hilang
- provider
- nominal/paket
- modal
- harga jual
- keuntungan
- Riwayat
- Rekap

Tidak ada stok untuk Pulsa/Paket.

## 11. Audit Pengeluaran

Test:

`Tambah → Edit → Hapus`

Pastikan Dashboard/Rekap langsung sinkron.

Pengeluaran hanya biaya operasional.

Jangan memasukkan kembali modal Barang/HP/Voucher/Pulsa/Paket sebagai Pengeluaran.

## 12. Audit Riwayat

Pastikan Riwayat membaca:

- Barang
- Servis
- HP
- Voucher
- Pulsa
- Paket
- Pengeluaran

Test:

- Semua
- filter kategori
- filter periode
- detail
- refresh

Urutan terbaru harus benar.

Cari duplicate transaction.

## 13. Audit Rekap

Pastikan tersedia:

- Omzet
- Keuntungan
- Pengeluaran
- Laba Bersih

Rumus dasar:

`Laba Bersih = Keuntungan - Pengeluaran Operasional`

Audit breakdown:

- Barang
- Servis
- HP
- Voucher
- Pulsa
- Paket
- Pengeluaran

Pastikan filter periode memengaruhi seluruh summary dan breakdown.

## 14. Audit Dashboard

Ini bagian penting.

Dashboard harus menggunakan data API/database terbaru.

Periksa:

- omzet
- keuntungan
- pengeluaran
- laba bersih
- Servis Aktif
- stok menipis
- transaksi terbaru
- grafik penjualan

Jangan ada angka dummy.

Bandingkan Dashboard dengan Rekap pada periode ekuivalen.

Jika berbeda, cari penyebabnya dan perbaiki sumber perhitungan.

## 15. Audit refresh

Cari masalah stale state.

Setelah transaksi dilakukan lalu kembali ke Dashboard:

- angka harus berubah
- transaksi terbaru harus berubah
- stok harus berubah

Tidak boleh perlu restart aplikasi untuk mendapatkan data terbaru.

Lakukan hal yang sama untuk Riwayat dan Rekap.

## 16. Audit double submit

Semua form transaksi harus mencegah tombol dikirim berkali-kali saat request berlangsung.

Periksa:

- Penjualan
- Servis
- Pembayaran
- HP
- Voucher
- Pulsa/Paket
- Pengeluaran

Pastikan tidak mudah menghasilkan transaksi duplikat akibat double tap.

Backend juga harus mempunyai validasi yang relevan untuk operasi kritis.

## 17. Audit formatting

Periksa seluruh aplikasi:

- Rupiah
- tanggal
- nomor HP
- angka besar
- nilai negatif
- quantity
- status

Jangan sampai `null`, `Instance of`, raw enum, atau format angka database tampil ke user.

## 18. Audit UI runtime

Cari:

- RenderFlex overflow
- red screen
- setState after dispose
- context after async gap yang berbahaya
- controller tidak dispose
- navigation error
- loading tidak berhenti
- snackbar setelah widget dispose
- duplicate GlobalKey

Perbaiki masalah nyata yang ditemukan.

Jangan melakukan refactor besar yang tidak diperlukan.

## 19. Audit Android

Pastikan permission yang benar untuk fitur yang digunakan, khususnya scanner/camera.

Jangan menambahkan permission yang tidak diperlukan.

Pastikan aplikasi tetap dapat build Android.

## 20. Analyzer

Jalankan:

`flutter analyze`

Perbaiki semua **error** yang berasal dari source aplikasi.

Untuk warning/info, perbaiki yang aman dan relevan tanpa melakukan refactor besar yang berisiko.

Jangan mengubah dependency secara sembarangan hanya demi menghilangkan warning.

## 21. Build

Setelah analyzer aman, jalankan build Android yang sesuai dengan environment project, minimal:

`flutter build apk --debug`

Jika build gagal, cari penyebab dan perbaiki jika berasal dari project.

Jangan mengklaim build sukses jika command sebenarnya gagal.

## 22. Jangan tinggalkan data test

Jika audit membuat transaksi test pada database, bersihkan data tersebut setelah pengujian jika aman.

Jangan menghapus data user sebenarnya.

Hanya hapus record yang secara pasti dibuat oleh proses test ini.

## 23. Jangan mengubah scope

Jangan:

- redesign Dashboard
- mengganti theme
- mengganti arsitektur
- menambahkan login
- menambahkan fitur baru
- mengganti backend
- mengganti database
- melakukan refactor besar tanpa alasan bug

Fokus pada stabilitas aplikasi existing.

## 24. Laporan akhir WAJIB

Setelah seluruh audit selesai, berikan laporan terstruktur:

### A. Shortcut
Daftar seluruh shortcut Dashboard dan status masing-masing.

### B. Bug ditemukan
Daftar bug yang benar-benar ditemukan.

### C. Bug diperbaiki
Jelaskan fix setiap bug.

### D. API
Endpoint yang diuji dan hasilnya.

### E. Database
Tabel yang digunakan setiap modul.

### F. Keuangan
Tampilkan definisi final:

- Omzet
- Keuntungan
- Pengeluaran
- Laba Bersih

### G. Integrasi
Status:

- Dashboard
- Riwayat
- Rekap

### H. Dummy
Sebutkan dummy/placeholder yang ditemukan dan dihapus.

### I. Analyzer
Berikan hasil nyata `flutter analyze`.

### J. Build
Berikan hasil nyata build APK debug.

### K. Masalah tersisa
Jika masih ada masalah, sebutkan secara spesifik.

Jangan mengatakan "semua aman" tanpa melakukan pemeriksaan.

Target akhir:

`Transaksi → API/MySQL → Dashboard → Riwayat → Rekap`

harus konsisten untuk seluruh modul aplikasi.