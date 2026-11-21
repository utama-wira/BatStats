# BatStats untuk iPhone & iPad

Lihat baterai iPhone, Mac, dan iPad kamu langsung dari iPhone, dengan cincin baterai, grafik 24 jam, dan notifikasi yang sama seperti di Mac.

## Cara kerjanya

iOS tidak mengizinkan aplikasi membaca baterai perangkat lain lewat kabel atau Wi-Fi. Karena itu, BatStats versi iPhone mengambil data dari dua sumber:

| Perangkat | Sumber |
|---|---|
| iPhone/iPad yang sedang dipakai | Dibaca langsung dan berubah seketika saat dicas atau dicabut |
| Mac | BatStats di Mac (versi 2.3 ke atas) menulis baterainya ke iCloud Drive › Shortcuts › BatStats |
| iPad (dan iPhone lain) | Ikut ditulis Mac selama terbaca lewat USB/Wi-Fi, atau ditulis sendiri oleh BatStats/pintasan di iPad itu |

Sebaliknya, BatStats di iPhone juga menulis baterainya ke folder yang sama, jadi BatStats di Mac tetap kebagian angkanya.

Semua data hanya disimpan di iCloud Drive milikmu sendiri. Tidak ada server dan tidak ada akun tambahan.

## Kebutuhan

- iPhone/iPad dengan iOS/iPadOS 17 atau lebih baru
- Mac dengan Xcode 16 atau lebih baru (gratis di App Store)
- Apple ID biasa. **Tidak perlu** akun Apple Developer berbayar.

## Pasang ke iPhone

1. Di Mac, buka `iOS/BatStats.xcodeproj` dengan Xcode.
2. Klik proyek **BatStats** di sidebar → target **BatStats** → tab **Signing & Capabilities**.
   - **Team**: pilih Apple ID kamu (tambahkan lewat *Add an Account…* kalau belum ada).
   - Kalau Xcode bilang bundle identifier sudah dipakai, ubah `io.github.utama-wira.batstats.ios` menjadi sesuatu yang unik, misalnya `com.namakamu.batstats`.
3. Colok iPhone ke Mac, lalu pilih iPhone itu di daftar perangkat di bagian atas Xcode.
4. Tekan **▶︎ Run** (⌘R).
5. Pertama kali dipasang, iPhone akan menolak membukanya. Buka **Pengaturan › Umum › VPN & Manajemen Perangkat**, ketuk Apple ID kamu, lalu **Percayai**.
6. Kalau diminta, nyalakan **Mode Pengembang** (Pengaturan › Privasi & Keamanan › Mode Pengembang), lalu iPhone akan restart.

> **Catatan Apple ID gratis:** app yang dipasang dengan Apple ID gratis berlaku 7 hari. Setelah itu app tidak bisa dibuka sampai kamu menekan **Run** lagi dari Xcode (datanya tetap aman). Dengan akun Apple Developer berbayar, masa berlakunya 1 tahun.

## Sambungkan Mac & iPad

1. **Perbarui BatStats di Mac** ke versi 2.3 (`git pull && ./build.sh install`) dan pastikan panel › ⚙︎ › **Sumber iCloud** menyala. Mac akan langsung membuat file `Mac - <nama Mac>.json` di iCloud Drive › Shortcuts › BatStats.
2. Buka BatStats di iPhone. Panduan *Sambungkan* akan muncul otomatis (atau lewat ⚙︎ › **Sambungkan folder iCloud**).
3. Isi **nama iPhone** persis seperti di Pengaturan › Umum › Mengenai › Nama. Sejak iOS 16, aplikasi tidak bisa membaca nama ini sendiri, padahal nama ini dipakai Mac supaya iPhone tidak muncul ganda.
4. Ketuk **Pilih folder**, buka **iCloud Drive › Shortcuts › BatStats**, lalu ketuk **Buka**. Kalau folder BatStats belum ada, pilih folder **Shortcuts** saja.

Selesai. Mac muncul dengan label oranye **iCloud**. iPad yang sedang terbaca oleh Mac lewat USB/Wi-Fi muncul dengan label biru **Lewat Mac**.

## Seberapa segar angkanya?

- **iPhone ini:** langsung, saat app dibuka.
- **Mac:** BatStats di Mac menulis setiap kali angkanya berubah, dan paling lambat tiap 10 menit selama Mac menyala. Kalau sudah lebih dari 25 menit tidak ada kabar (misalnya Mac tidur atau mati), Mac tampil abu-abu dengan jam terakhirnya.
- **iPad/iPhone lain lewat iCloud:** data dianggap aktif selama 3 jam, sama seperti di Mac.
- Ditambah jeda sinkronisasi iCloud, biasanya beberapa detik sampai satu menit.

Tarik layar ke bawah untuk memperbarui. Saat app ditutup, iOS sesekali membangunkannya di latar untuk memperbarui data dan mengirim notifikasi. Jadwalnya ditentukan iOS (biasanya tiap 15 menit sampai beberapa jam, tergantung seberapa sering kamu membuka app). Supaya baterai iPhone tetap sampai ke Mac secara rutin walaupun app jarang dibuka, tetap pasang otomasi Shortcuts dari [panduan Shortcuts](SHORTCUTS.md).

## Pertanyaan umum

**Bisa juga menampilkan Apple Watch atau AirPods?**
Belum. Baik iOS maupun macOS tidak menyediakan cara resmi untuk membacanya.

**Kenapa iPhone saya muncul dua kali di Mac?**
Nama di BatStats iPhone (⚙︎ › Nama iPhone ini) berbeda dengan nama perangkat di Pengaturan › Umum › Mengenai › Nama. Samakan, lalu hapus file lama yang namanya salah dari folder iCloud BatStats.

**Ada widget layar utama?**
Belum, tapi sudah direncanakan untuk versi berikutnya.
