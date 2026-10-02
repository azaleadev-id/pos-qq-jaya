QQ Jaya Cell API Starter

1. Ekstrak seluruh isi ZIP ke C:\xampp\htdocs\qq-jaya-cell-api
2. Pastikan Apache dan MySQL aktif.
3. Pastikan database qq_jaya_cell dan tabel-tabelnya sudah tersedia.
4. Buka http://localhost/qq-jaya-cell-api/api/health

Respons yang diharapkan:
{"success":true,"message":"API dan database terhubung.","data":{"api":"online","database":"connected","php_version":"8.2.12"}}

API key lokal bawaan:
qq-jaya-cell-local-key

Ganti API key sebelum deploy ke hosting.

Endpoint produk:
GET    /api/products
POST   /api/products
GET    /api/products/{uuid}
PUT    /api/products/{uuid}
PATCH  /api/products/{uuid}
DELETE /api/products/{uuid}

Endpoint stok:
GET  /api/stock-movements
GET  /api/stock/low
POST /api/stock/in

Header wajib untuk endpoint selain health:
X-API-Key: qq-jaya-cell-local-key
QQ Jaya Cell API v1.3 - Penjualan

UPDATE v1.4 - SERVIS HP
- GET    /api/services
- POST   /api/services
- GET    /api/services/{id}
- PUT    /api/services/{id}
- DELETE /api/services/{id}
- PATCH  /api/services/{id}/status
- POST   /api/services/{id}/payments
- GET    /api/service-presets

Status: in, waiting, working, completed.
Metode pembayaran: cash, transfer, qris.
Garansi baru dikirim ketika status diubah menjadi completed.

UPDATE v1.5 - JUAL BELI HP
- GET    /api/phones
- POST   /api/phones/purchases
- POST   /api/phones/{id}/sell
- POST   /api/phones/direct-sale
- GET    /api/phones/{id}
- PUT    /api/phones/{id}
- DELETE /api/phones/{id}

phone_code menjadi isi QR untuk melacak satu unit HP.

UPDATE v1.6 - PENGELUARAN
- GET    /api/expenses
- POST   /api/expenses
- GET    /api/expenses/{id}
- PUT    /api/expenses/{id}
- DELETE /api/expenses/{id}

UPDATE v1.7 - DASHBOARD DAN REKAP
- GET /api/dashboard
- GET /api/recaps/overall
- GET /api/recaps/products
- GET /api/recaps/services
- GET /api/recaps/phones
- GET /api/recaps/expenses
- GET /api/recaps/payments

Gunakan query from dan to dalam format YYYY-MM-DD.

Endpoint penjualan:
- GET    /api/sales
- POST   /api/sales
- GET    /api/sales/{id}
- PUT    /api/sales/{id}
- DELETE /api/sales/{id}

POST/PUT JSON:
{
  "payment_method": "cash",
  "paid_amount": 100000,
  "notes": "opsional",
  "items": [
    {
      "product_id": "UUID-PRODUK",
      "quantity": 2,
      "unit_price": 25000
    }
  ]
}

unit_price boleh tidak dikirim agar memakai harga jual produk.
DELETE membatalkan transaksi dan mengembalikan stok.
