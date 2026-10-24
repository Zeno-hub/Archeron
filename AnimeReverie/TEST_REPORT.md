# Anime Reverie — Laporan Audit & Hasil Tes
> **PEMBARUAN TERBARU (tahap 2 + audit repo Zeno-hub/Archeron): 79 tes lulus, 0 gagal; 21/21 mutasi tertangkap; 32 require() OK. Angka di bagian 1 = snapshot sebelum tahap 2; lihat bagian 9.**

Tanggal: 24 Okt 2026 · Cakupan: Fase 1A (data & stat) + revisi gameplay "SAKELAR AI", slice 1 (config + logika murni)
Lingkungan uji: sandbox Linux, Luau CLI + analyzer **0.743**, Python 3. **Tidak ada Roblox Studio / runtime Roblox.**

## 1. Hasil yang BENAR-BENAR dijalankan
| Pemeriksaan | Perintah | Hasil |
|---|---|---|
| Unit + integrasi + gameplay | `LUAU_BIN=/path/luau python3 tests/run_tests.py` | **68 lulus, 0 gagal** (inti 35, integrasi 17, gameplay 16) |
| Struktur / require / tipe skrip | `python3 tests/check_structure.py` | 14 `require()` OK, 0 masalah |
| Analisis statis (`luau-analyze`) | 15 file, global Roblox dideklarasikan lewat prelude | 1 temuan: lihat butir 2 di bawah |
| Uji mutasi (14 kerusakan sengaja) | sed pada salinan | **14/14 tertangkap** tes/pemeriksa |

Mutasi yang tertangkap: EXP normal=2, StatPoint/level=2, level-up tanpa poin, alokasi tanpa cek poin, load abaikan lock, save abaikan lock, require salah ketik, Main jadi ModuleScript, BindToClose tidak menunggu (4 tes gagal), migrasi v2 mati, klik abaikan pet/gacha, musuh agresif, peluang gacha ≠ 100, klaim quest berulang.

## 2. Audit 5 butir
**1. BindToClose / activeReleases** — dibuktikan dengan harness Roblox palsu (waktu virtual). Pada kode lama 2 tes GAGAL (bug terbukti), kini lulus:
- Error tak terduga di jalur release membuat `activeReleases` macet → BindToClose menunggu penuh 25 dtk dan profil tak pernah dibersihkan. **Diperbaiki** (`releaseProfile` dibungkus pcall; pembersihan selalu jalan).
- Pemain keluar saat loading lalu server mati → lock DataStore tertinggal (pelepasan tidak dilacak). **Diperbaiki** (dilacak di `activeReleases`; `onClose` juga menunggu `loading`, dan melepas profil yang baru selesai dimuat).
- Hardening (bukan bug terbukti): batas waktu BindToClose kini dari hasil `task.wait` (bukan `os.clock`); Playtime memakai `os.time`; `LoadProfile` dibungkus pcall. Alasan: semantik `os.clock` di Roblox tidak bisa saya verifikasi di sini.
- Teruji kini: 3 save paralel ditunggu semua; release yang sudah berjalan ikut ditunggu; timeout 25 dtk tidak menggantung; lock terlepas.
**2. run_tests.py** — berjalan di Luau CLI, exit code 1 bila ada yang gagal, 127 + petunjuk bila CLI tidak ada, baca file UTF-8. Jumlah tes cocok dengan jumlah `test(` di file. Pesan analyzer: *"An internal type is escaping this module"* di `StatFormulas.lua` (solver tipe baru; **deterministik**, solver lama = 0 temuan; menghilang bila `nonNegInt`/`RequiredEXP`/`SanitizeData` dihapus; anotasi tipe sederhana tidak menghilangkannya). Saya anggap bug analyzer, **penyebab pastinya belum ditemukan**; tidak memengaruhi tes runtime. Koreksi: bisect pertama saya keliru (hanya baca stdout) dan sudah diulang benar.
**3. Nama / path / struktur** — konsisten. Perubahan: `Main.lua`→`Main.server.lua`, `DevTools.lua`→`DevTools.server.lua` (konvensi Rojo; tanpa ini Rojo membuatnya ModuleScript yang tidak jalan). Pemeriksa sempat false positive (`local cfg = GameConfig.Data`), sudah diperbaiki.
**4. Skema ↔ ProfileStore ↔ PlayerStatsService** — kompatibel (tes integrasi memuat data lama skema 1 dengan field hilang/negatif). Skema naik ke v2 (lihat butir 6); migrasi teruji.
**5. Integrasi ke project Anda** — lihat bagian 5. Saya **tidak punya akses** ke place Studio Anda; tidak ada yang saya ubah di sana.

## 3. Revisi gameplay vs kode lama (revisi menang jika bentrok)
| Revisi | Sebelumnya | Tindakan (teruji) |
|---|---|---|
| Level 1–100 | MaxLevel 500 | `MaxLevel = 100` |
| Power hanya dari klik/pet/gacha/upgrade | atribut alokasi "Power" | atribut dihapus; `Power` = hasil klik (`AwardClick`); migrasi v2 mengembalikan poin lama sebagai StatPoints |
| Stars = mata uang gacha pet, bukan Power | tidak ada | field `Stars`, `AddStars/TrySpendStars` |
| Gacha Power terpisah, tidak pakai Stars | tidak ada | `GachaConfig`: pet=Stars, power=Coins |
| Nama world baru; Lobby terpisah | nama lama hanya di dokumen | `WorldConfig` (MapName berbeda, Lobby tanpa musuh/quest) |
| Musuh & boss diam | spec lama: AI/pola serangan boss | `EnemyConfig` + `Validate()`; spec lama itu digugurkan |
| Kill normal +1 EXP | sama | tidak berubah (tidak bertentangan) |
| Tanpa training | — | tes menolak kata "train" di nama/field config |
Asumsi saya (ubah di config bila salah): pet gacha memakai 5 rarity yang sama; sumber Stars = quest + boss; world terbuka di level 1/15/35/55/75; angka HP/biaya/multiplier hanyalah awal, belum diseimbangkan; spec lama soal telur 9 rarity belum dibangun dan tergantikan.

## 4. Checklist pengujian revisi (12 butir): apa yang teruji
| # | Butir | Status |
|---|---|---|
| 1 | Musuh tidak mengejar/menyerang | **Data** teruji (validator); perilaku runtime BELUM ada |
| 2 | Hit reaction | BELUM (butuh Roblox) |
| 3 | Animasi idle/attack | BELUM; tidak bisa diverifikasi di sandbox |
| 4 | Klik → Power | Logika server teruji; tombol/Remote/rate limit BELUM |
| 5 | Damage mengurangi HP musuh | BELUM (CombatService) |
| 6 | Kill → quest world benar | `QuestLogic` teruji; sambungan ke kill BELUM |
| 7 | Reward Stars & XP | Logika klaim teruji; service BELUM |
| 8 | Pet gacha & Power gacha terpisah | Config + undian teruji; pembayaran/penyimpanan BELUM |
| 9 | Pet bonus memengaruhi Power/klik | Teruji lewat provider; inventory/equip pet BELUM |
| 10 | Tiap world: Stars, 2 gacha, kill quest | Config teruji; UI/service BELUM |
| 11 | Lobby terpisah dari world | Config teruji; map & teleport BELUM |
| 12 | Level 1–100 tanpa training | MaxLevel teruji; tidak ada kode training |

## 5. Checklist integrasi ke project Roblox Anda
1. **Struktur**: folder `Configurations`, `SharedModules` (ReplicatedStorage) dan `Services` (ServerScriptService) persis; `Main`/`DevTools` = **Script**, sisanya ModuleScript. Hindari bentrok nama dengan skrip lama (Main, GameConfig, DataService…).
2. **Data lama**: store `AnimeReverie_PlayerData`, key `Player_<UserId>`, format `{SchemaVersion, SessionLock, Data}`. Data lama berformat lain TIDAK dibaca; record tanpa `Data` ditolak (`CorruptRecord`, pemain di-kick, tidak ditimpa). Perlu importer sekali jalan: beri tahu skema lama Anda.
3. **Satu sumber kebenaran**: EXP/koin/gem/Stars/Power hanya lewat `PlayerStatsService`; buang pembuat `leaderstats` lama (duplikat) dan kode yang menulis nilai langsung.
4. **Klik**: sambungkan tombol attack ke `AwardClick` HANYA dari server setelah validasi + rate limit (`GameConfig.Click.MaxClicksPerSecond`); jangan sambungkan `AwardKill/AddCoins/AddStars` ke RemoteEvent.
5. **EXP**: kode lama yang memberi EXP dari config musuh harus diganti `AwardKill({Kind="Normal"})` (tepat +1).
6. **Studio**: publish place + aktifkan "Enable Studio Access to API Services"; bila tidak, DevTools memakai data sementara (tidak disimpan).
7. **Urutan boot**: semua `Init()` dulu, `DataService.Start()` terakhir (lihat `Main`).
8. Hapus `DevTools` sebelum rilis (hanya aktif di Studio).

## 6. Perubahan file (lihat `CHANGES.patch`, relatif ke 10 file yang dikirim sebelumnya)
Diubah: GameConfig, StatFormulas, DataTemplate, DataService, PlayerStatsService, DevTools, run_tests.py, test_core.lua. Diganti nama: Main, DevTools (`.server.lua`). Baru: WorldConfig, EnemyConfig, QuestConfig, GachaConfig, QuestLogic, GachaLogic, DataMigrations, mock_roblox.lua, test_integration.lua, test_gameplay.lua, check_structure.py.
Skema data v2: + `Stars`, `Power` (klik), `Quests`; `Allocated.Power` dihapus (poin dikembalikan).

## 7. TIDAK terverifikasi
- Roblox Studio/runtime: DataStore asli (throttling, batas 4 MB, teks error), `UpdateAsync` saat transform membatalkan, BindToClose asli, leaderstats, ProximityPrompt DevTools, `Instance`/`Players` sungguhan. Tes memakai Roblox palsu yang hanya memodelkan alur logika.
- Petunjuk error "studio access" cuma diuji dengan pesan tiruan; bila beda, efeknya hanya retry lebih lama lalu data sementara.
- Rojo / sinkronisasi ke Studio (penamaan mengikuti konvensi, belum dijalankan).
- Penyeimbangan angka; animasi 3D; UI; map; teleport; penyimpanan permanen di Roblox sungguhan.

## 9. Tahap 2 + audit repo https://github.com/Zeno-hub/Archeron (24 Okt 2026)
**Inventaris**: repo publik, branch `main`, commit terakhir 99289f6, di-clone penuh. 35 file: 30 file isi (23 di `AnimeReverie/` + 7 file longgar di root) + 5 placeholder `Test` (1 byte). Semua terbaca; 30 file isi dibandingkan byte-per-byte dengan versi saya (isi `AnimeReverie/` = v3; file root = file tahap 2 yang ter-upload ke root). Tidak ada file yang gagal diperiksa. Tes bawaan repo (v3) dijalankan: 68 lulus.

**Konfirmasi aturan: Power berasal dari klik valid, BUKAN dari kill.** `CombatService.HandleClick` memanggil `PlayerStatsService.AwardClick` untuk setiap klik valid (target ada, world benar, level cukup, di bawah rate limit), sebelum cek HP/hidup-mati NPC. `AwardKill` dan jalur reward kill tidak menyentuh Power. Dibuktikan tes otomatis (bagian 9.3) dan mutasi (kill +1 Power => 7 tes gagal).

### 9.1 Temuan (Critical/High/Medium/Low)
| # | Tingkat | Lokasi | Bukti | Status |
|---|---|---|---|---|
| F1 | **High** | `CombatService.HandleClick` | `if not state.Alive then return nil, "TargetDead" end` terjadi SEBELUM `AwardClick` -> klik valid ke NPC mati tidak memberi Power (melanggar aturan 2). 3 tes gagal sebelum perbaikan | **Diperbaiki**: Power diberikan dulu; NPC mati hanya tidak kena damage/reward |
| F2 | **High** | `PlayerStatsService.SetCurrentWorld` | `HighestWorldUnlocked` tidak punya penulis (grep) dan jadi syarat -> pemain level 15 ditolak masuk World 2; World 2-5 tak terjangkau. Tes gagal sebelum perbaikan | **Diperbaiki**: syarat = Level >= RequiredLevel; `HighestWorldUnlocked` = world tertinggi yang pernah dimasuki; `CombatService` memakai syarat yang sama |
| F3 | **Medium** | `CombatService.Init` (remote) | payload invalid tidak kena batas dan selalu dibalas: 300 request -> 302 balasan `HitResult` | **Diperbaiki**: `MaxRequestsPerSecond = 30` untuk SEMUA payload, kelebihan dibuang tanpa balasan |
| F4 | **High** (integrasi) | root repo | `CombatService/QuestService/Remotes/Main.server.lua` ada di root, bukan `Services/`; `Main` root menunggu `Services:WaitForChild("CombatService")` selamanya | **Diatasi** lewat `sync_to_github.sh` (struktur benar) |
| F5 | Low | repo | 5 placeholder `Test` + 7 file longgar di root | dibersihkan `sync_to_github.sh` |
| F6 | **High** (belum ada) | pet/gacha | tidak ada PetService/GachaService: inventory, equip, pembelian pet gacha (Stars) & Power gacha (Coins) belum ada; tidak ada provider modifier terdaftar di kode produksi (grep) -> `PetClickMultiplier`/`PowerGachaMultiplier` tidak pernah aktif di game nyata. Hanya config + logika murni yang teruji | **Belum diimplementasikan** (tahap 3) |
| F7 | **High** (belum ada) | client | tidak ada LocalScript/UI/HUD/tombol klik/hit reaction/animasi -> belum bisa dimainkan | **Belum diimplementasikan** |
| F8 | Medium (belum ada) | world | tidak ada WorldService/teleport/map; Lobby vs World baru berupa data `CurrentWorld` | **Belum diimplementasikan** |
| F9 | Low | `CombatService` | rate limit jendela per detik (burst di batas detik s.d. ~2x); HP NPC satu instance bersama per server (bukan per pemain) | desain, didokumentasikan |
| F10 | Low | `GachaConfig` | Power gacha = Coins, Stars tidak dipakai untuk Power gacha | **Benar** (teruji) |

### 9.2 File yang diubah di tahap ini
`CombatService.lua` (ditulis ulang: F1, F3), `PlayerStatsService.lua` (`CanEnterWorld`, `SetCurrentWorld`: F2; `AddEXP`), `GameConfig.lua` (`MaxRequestsPerSecond`), baru: `Remotes.lua`, `QuestService.lua`, `tests/test_services.lua` (+ `mock_roblox.lua` mendukung RemoteEvent), `run_tests.py`, `Main.server.lua`, `DevTools.server.lua`.

### 9.3 Hasil tes aktual (Luau CLI + Roblox palsu; BUKAN Studio)
`LUAU_BIN=/path/luau python3 tests/run_tests.py` => **79 lulus, 0 gagal** (inti 35, integrasi 17, gameplay 16, layanan 11). Sebelum perbaikan: 74 lulus, 5 gagal (F1 x3, F3, F2). `check_structure.py`: 32 require OK. Tes layanan membuktikan:
- klik valid memberi Power saat NPC hidup dan saat damage tidak cukup membunuh;
- klik valid ke NPC mati tetap memberi Power tanpa damage/reward;
- kill TIDAK menambah Power (Power = jumlah Power klik; `AwardKill` langsung tidak mengubah Power; `AwardClick` jalan tanpa NPC);
- kill hanya memberi reward terkonfigurasi (normal +1 EXP + koin; boss bonus EXP + Stars + koin);
- klik invalid, target palsu, world salah/terkunci, di atas rate limit => tidak ada reward;
- kill + respawn tidak memberi reward ganda; reward kill hanya ke pemukul terakhir;
- spam remote dibatasi; klaim quest sekali; Power/Stars/Quests tersimpan setelah leave & rejoin.
Mutasi tambahan (7) tertangkap: kill+Power, NPC mati ditolak lagi, Power dicabut, batas remote dicabut, rate limit dicabut, cek world dicabut, respawn memberi koin ganda.
Analyzer (18 file, global Roblox dideklarasikan lewat prelude): satu-satunya temuan = pesan internal solver baru di `StatFormulas` (*"internal type is escaping"*; solver lama 0 temuan; penyebab pasti belum ditemukan). Dua peringatan tipe di `SetCurrentWorld` sempat muncul dan dihilangkan dengan anotasi `worldId: any` (tanpa ubah perilaku).

### 9.4 Tes yang HANYA bisa di Roblox Studio (belum dilakukan)
1) Play: leaderstats Level/EXP/Kills/Coins/Power/Stars muncul. 2) Tombol DEV "Toggle world" lalu "Click first enemy": Output menampilkan +Power tiap klik walau musuh belum mati, dan tetap +Power setelah mati. 3) Kill memberi +1 EXP, Power tidak ikut naik. 4) Stop lalu Play lagi: nilai tersimpan (butuh API Services aktif). 5) Output tanpa error merah; `ReplicatedStorage > Remotes` berisi ClickAttack/HitResult/ClaimQuest/QuestResult. 6) Hit reaction, animasi, UI, map, teleport: belum dibuat, jadi belum bisa dites.
