# Sumber iCloud: kirim baterai iPhone/iPad lewat Shortcuts

Dengan sumber iCloud, BatStats tetap bisa menampilkan baterai iPhone/iPad **walaupun perangkat jauh dari Mac** atau sedang memakai Wi-Fi publik (bandara, hotel, kafe). iPhone menulis persen baterainya ke iCloud Drive, lalu BatStats di Mac membacanya.

- USB dan Wi-Fi tetap jadi sumber utama. iCloud hanya mengisi saat perangkat tidak terlihat.
- Angka dari iCloud diberi label oranye **iCloud** dan jam pengirimannya.
- Data iCloud yang lebih dari 3 jam tampil abu-abu.

Pemasangan cukup sekali per perangkat, sekitar 5 menit. Lakukan di iPhone, lalu ulangi di iPad.

> **Cara cepat (disarankan):** di Mac, jalankan
> `python3 shortcut/buat_pintasan.py --nama "Nama iPhone" --jenis iPhone`
> (dan sekali lagi dengan `--jenis iPad` untuk iPad). Skrip ini membuat pintasan yang sudah ditandatangani atas Apple ID kamu. Salin ke iCloud Drive, buka dari app **File** di perangkat yang sesuai, ketuk **Tambahkan Pintasan**, lalu lompat ke Langkah 2.
> Pintasan ini menulis nama dan model sebagai teks tetap, jadi tidak memakai *Dapatkan Detail Perangkat*. Dengan begitu iOS tidak terus memunculkan pop-up "Izinkan … menyimpan item teks ke file?". `--nama` harus sama persis dengan Pengaturan › Umum › Mengenai › Nama.

## Syarat

- iCloud Drive aktif di iPhone/iPad dan di Mac, dengan Apple ID yang sama.
- Di iPhone: **Pengaturan › [nama kamu] › iCloud › Aplikasi yang Menggunakan iCloud** → **Pintasan (Shortcuts)** aktif.
- Di BatStats: panel › ⚙︎ › **Sumber iCloud (lewat Shortcuts)** menyala (bawaannya sudah menyala).

## Langkah 1: buat pintasan "Kirim Baterai ke BatStats"

Buka app **Pintasan (Shortcuts)** → tab **Pintasan** → **＋**, lalu tambahkan tindakan berikut berurutan. Ketik nama tindakannya di kolom pencarian.

1. **Dapatkan Tingkat Baterai** (*Get Battery Level*)
2. **Sedang Mengisi Daya** (*Is Charging*). Kalau tidak ada, pakai **Tersambung ke Pengisi Daya** (*Is Connected to Charger*).
3. **Kamus** (*Dictionary*). Ketuk **Tambah item baru** sebanyak 4 kali, lalu isi:

   | Kunci | Jenis | Nilai |
   |---|---|---|
   | `name` | Teks | variabel **Nama Perangkat** (ketuk kolom nilai → *Pilih Variabel* → **Perangkat** → *Nama Perangkat*) |
   | `level` | Angka | variabel **Tingkat Baterai** |
   | `charging` | Boolean | variabel **Sedang Mengisi Daya** |
   | `model` | Teks | variabel **Perangkat** → *Model* |

4. **Simpan File** (*Save File*):
   - Berkas: **Kamus**
   - Ketuk **›** untuk membuka opsi:
     - **Tanya Tempat Menyimpan**: **mati**
     - **Subjalur** (*Subpath*): `BatStats/` lalu sisipkan variabel **Nama Perangkat**, lalu ketik `.json`.
       Hasilnya terlihat seperti `BatStats/[Nama Perangkat].json`
     - **Timpa Jika File Ada** (*Overwrite If File Exists*): **nyala**

Beri nama pintasan **Kirim Baterai ke BatStats**, lalu ketuk **Selesai**.

**Tes:** jalankan pintasannya sekali. Di Mac, buka BatStats › ⚙︎ › **Buka folder iCloud**. Dalam beberapa detik akan muncul file `[nama iPhone].json`, dan iPhone kamu tampil dengan label **iCloud** kalau sedang tidak tersambung lewat USB/Wi-Fi.

> Nama file harus sama dengan nama perangkat (Pengaturan › Umum › Mengenai › Nama). Dengan begitu BatStats menggabungkannya dengan perangkat yang sudah dikenal, sehingga tidak muncul ganda.

## Langkah 2: jalankan otomatis dengan Otomasi

Di app **Pintasan**, buka tab **Otomasi** → **＋** → **Buat Otomasi Pribadi**. Buat beberapa otomasi di bawah ini. Masing-masing menjalankan **Kirim Baterai ke BatStats**.

| Pemicu | Pengaturan | Kenapa |
|---|---|---|
| **Pengisi Daya** | *Tersambung* | Langsung terlihat "mengisi daya" |
| **Pengisi Daya** | *Terputus* | Langsung terlihat saat lepas charger |
| **Tingkat Baterai** | *Turun di Bawah* 50% | Pembaruan di tengah hari |
| **Tingkat Baterai** | *Turun di Bawah* 20% | Peringatan baterai lemah tetap sampai ke Mac |
| **Aplikasi** | *Dibuka*: pilih app yang sering kamu pakai (WhatsApp, Instagram, dst.) | Pembaruan rutin sepanjang hari |

Untuk **setiap** otomasi, pilih **Jalankan Segera** (*Run Immediately*) dan matikan **Beri Tahu Saat Berjalan** (*Notify When Run*), supaya berjalan diam-diam tanpa bertanya.

## Pertanyaan umum

**Seberapa sering angkanya diperbarui?**
Setiap kali salah satu otomasi berjalan. BatStats sendiri mengecek folder iCloud setiap 60 detik dan setiap kali panel dibuka. Jeda dari iPhone ke Mac biasanya beberapa detik sampai satu menit, tergantung koneksi.

**Apakah memakai kuota atau baterai?**
Sangat sedikit, karena filenya kurang dari 200 byte.

**Data saya dikirim ke mana?**
Hanya ke iCloud Drive milikmu sendiri. BatStats tidak punya server dan tidak mengirim data ke mana pun.

**Format file**
JSON dari tindakan *Kamus*, misalnya:

```json
{"name": "iPhone Saya", "level": 72, "charging": false, "model": "iPhone"}
```

File teks yang hanya berisi angka (misalnya `85`) juga diterima. Nilai `level` antara 0–1 (misalnya `0.72`) otomatis dianggap persen.
