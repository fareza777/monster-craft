# MonsterCraft — Full Audit Visual & Gameplay

Tanggal: 2026-11-10
Cakupan: render pipeline, palet, tekstur, dunia/worldgen, vegetasi, viewmodel, HUD/UI, serta loop gameplay.
Metode: pembacaan kode sumber + 3 screenshot QA (siang `--time=12`, senja `--time=18`, malam `--time=0`) + `--ui-test` headless.

Catatan jujur di depan: masalah utama bukan "kurang fitur", tapi **kontras, hierarki, dan variasi**. Dunia memakai satu palet hijau jenuh di seluruh layar, semua material matte, HUD berupa banyak kotak gelap berbingkai di atas dunia terang. Hasilnya terasa seperti prototype, bukan game premium — meskipun isi sistemnya sudah banyak.

---

## 1. Skor audit

| Aspek | Skor | Catatan singkat |
|---|---|---|
| Palet & color grading | 3/10 | Satu hijau jenuh mendominasi; senja jadi coklat lumpur |
| Lighting & shadow | 4/10 | Ambient sky terlalu kuat, bayangan nyaris tak terbaca |
| Material & shader | 3/10 | Semua permukaan matte (`ROUGHNESS=1`, `specular_disabled`) |
| Tekstur blok | 5/10 | Noise 16px terlalu ramai + tidak ada variasi warna per-lokasi |
| Vegetasi & komposisi | 4/10 | Kanopi blob, ukuran seragam, tidak ada semak/rumput tinggi |
| Terrain & silhouette | 3/10 | Spawn datar, bukit langka, horizon rata |
| Atmosfer (fog/sky) | 5/10 | Fog tipis, horizon pucat, malam kehilangan bentuk |
| Viewmodel | 4/10 | Pickaxe besar & melayang tanpa lengan, menutupi 20% layar |
| HUD/UI | 5/10 | Bersih dari tumpang tindih, tapi terlalu banyak kotak & kontras teks rendah |
| Gameplay depth | 6/10 | Sistem banyak (tame, farm, dungeon, boss, quest) tapi feedback tipis |

---

## 2. Bukti dari screenshot

**Siang (12:04).** Langit hampir putih, tanah hijau limau seragam sampai horizon. Tidak ada bayangan yang terbaca di lapangan; kedalaman hanya dari gelap-terang sisi blok. Pohon di kejauhan menjadi siluet hijau gelap dengan tepi keras. Pickaxe menutupi sudut kanan bawah dan menabrak hotbar.

**Senja (18:04).** Seluruh frame jadi coklat kehijauan. `horizon` di-lerp ke `#f0a878` sebesar 0.55 **sekaligus** `_sun.light_color` jadi `#ffb17a`, sehingga dua sumber warna hangat menumpuk di atas hijau → lumpur. Tidak ada bayangan panjang dramatis yang diharapkan dari matahari rendah.

**Malam (00:04).** Hampir hitam total; yang terbaca hanya hamparan hijau gelap. Bintang hampir tak terlihat, tidak ada aksen hangat (lampu/torch) untuk memandu mata, siluet pohon menempel ke langit.

**UI (ketiga kondisi).** Tujuh tombol ikon di kanan atas (BAG, CRAFT, TEAM, CODEX, QUEST, MAP, PAUSE) semua bobot visual sama. Teks hint kiri bawah (`WASD: move …`) kecil, mint pucat, di atas rumput terang → praktis tidak terbaca. Dua toast (`Spriggle joined your team!`, `Welcome to World of Spore Village.`) menumpuk di kanan bawah, tepat di tengah area bermain, gayanya identik dengan panel debug. Hotbar 9 slot selalu penuh kotak, termasuk slot kosong.

---

## 3. Temuan visual + akar kode + rekomendasi

### V1. Grading terlalu "hijau neon" (severity: tinggi)
- `World.gd` → `adjustment_saturation = 1.1 - night*0.12 - rain*0.08`, `brightness = 1.02`, `contrast = 1.04`, tonemap ACES, `exposure = 1.05`.
- `ambient_light_energy = 0.36 + day*0.6` dengan `AMBIENT_SOURCE_SKY` + `sky_contribution = 1.0` → langit hijau-kebiruan menerangi semua permukaan dari segala arah, sehingga bentuk blok hilang.
- Tile `grass_top` `#65b45a` sudah sangat jenuh; dikali saturasi 1.1 + ambient hijau = neon.
- **Rekomendasi:** turunkan `grass_top` ke sekitar `#5c8f4e` (desaturasi ~12%), set `adjustment_saturation` dinamis 0.98–1.04, `contrast` 1.08, dan **turunkan `ambient_light_sky_contribution` ke 0.75** dengan `ambient_light_color` netral hangat (`#cfd8cf`) supaya ambient tidak mewarnai seluruh dunia hijau. Tambahkan satu "look" tetap: sedikit lift di shadow (brightness shadow) + warm highlight, cool shadow.

### V2. Semua material matte → tidak ada identitas material (severity: tinggi)
- `voxel_solid.gdshader`: `render_mode diffuse_lambert, specular_disabled`; `ROUGHNESS = 1.0`.
- Akibat: batu, kayu, kristal, es, air semuanya memantulkan cahaya identik. Kristal tidak berkilau, air tidak berkilau, logam tidak berkilau.
- **Rekomendasi:** hapus `specular_disabled`, pakai `diffuse_burley`. Tambahkan uniform `roughness` per material (batu 0.85, kayu 0.8, es 0.25, kristal 0.2, logam/ore 0.45) dan `metallic` kecil untuk ore. Efeknya besar tanpa perlu glow (aman di `gl_compatibility`).

### V3. Bayangan tidak membentuk gambar (severity: tinggi)
- `_sun.light_energy = 0.06 + day*1.25` (siang 1.31) **bersamaan** ambient 0.96 → rasio kontras bayangan ≈ 1.3:1, nyaris tak terlihat.
- `directional_shadow_max_distance = 120`, 2 split, 2048 → resolusi bayangan encer di jarak jauh.
- **Rekomendasi:** ambient siang 0.55–0.65 (bukan 0.96), sinar 1.15; `directional_shadow_max_distance = 80` (lebih tajam dekat pemain), `shadow_normal_bias = 1.0`, `shadow_blur` 1.2. Tambahkan Contact Shadow ringan (atau AO palsu via vertex shade bawah blok) agar blok terasa menapak.

### V4. Shading per-sisi konstan bikin pola "cekered" (severity: sedang-tinggi)
- `GreedyMesher.gd`: top `1.0`, +X `0.84`, -X `0.74`, +Z `0.93`, -Z `0.8`, bottom `0.52`, konstan per sisi.
- Di lapangan rumput luas, ini menghasilkan pola berlian/cekered yang bersaing dengan tekstur — terlihat di screenshot siang sebagai bercak gelap-terang berulang.
- **Rekomendasi:** kurangi rentang shade (top 1.0, sisi 0.90/0.84/0.88/0.86, bottom 0.62) dan **tambahkan variasi halus per-kolom** (mis. noise 2D frekuensi rendah ±3% pada top face) supaya bidang besar tidak rata mati.

### V5. Tekstur terlalu "berisik" untuk dilihat dari jauh (severity: sedang)
- `grass_top`: `_noise_fill` 0.16 + 22 + 14 speckle; `leaves`: noise 0.22 + 26 + 18 speckle + 10 lubang transparan.
- Pada FOV 74 dan blok 1m, tile 16px direntangkan → bintik-bintik menjadi titik acak yang tidak terbaca sebagai rumput/daun.
- **Rekomendasi:** turunkan jumlah speckle ~40%, ganti sebagian speckle dengan **pola terarah** (goresan vertikal 1–2px untuk rumput, gugus daun 2×2 untuk kanopi), dan naikkan kontras mikro hanya di tepi tile.

### V6. Tidak ada variasi warna dunia (severity: tinggi, dampak besar)
- `Content.BIOMES` punya `sky/horizon/grass`, tapi `grass` hanya dipakai untuk `ground_horizon_color` langit. Blok di dunia **tidak pernah di-tint**.
- Akibat: perjalanan 500 blok terasa seperti tempat yang sama; batas biome tidak terlihat kecuali dari pohon.
- **Rekomendasi (dampak tertinggi per usaha):** tint per-vertikal-chunk. Di mesher, kalikan `shade` dengan warna biome (`grass` untuk permukaan hijau) plus noise besar (frekuensi 0.004) ±6%. Ini satu perubahan di `GreedyMesher` + data yang sudah ada, dan langsung membuat peta terasa luas.

### V7. Vegetasi monoton & kanopi blob (severity: tinggi)
- `TerrainGen._stamp_tree`: oak trunk 4–6, kanopi radius 2/1 dengan sudut 60% dipotong; pine 4 lapis; semua oak identik.
- Tidak ada semak, tunggul, batu permukaan, akar, atau pohon tumbang. Kepadatan pohon seragam → hutan terasa seperti deretan aset.
- **Rekomendasi:** (a) 3 varian oak (kecil 4, sedang 6, besar 9 dengan kanopi radius 3 dan cabang), (b) tambah "bush" (kanopi 2×2×1 di atas tanah), batu permukaan 1–2 blok, log tumbang, dan tunggul; (c) kelompokkan pohon dalam clump (noise 0.018 yang sudah ada, pakai sebagai mask kepadatan) supaya ada rimbun vs padang.

### V8. Spawn & silhouette datar (severity: tinggi)
- `height_at`: `32 + cont*13 + detail*1.35`; ridge hanya jika `cont > 0.16` (`pow(ridge,2.5)*78`).
- Di sekitar spawn, `cont` kecil → terrain praktis rata. Screenshot siang memperlihatkan horizon lurus tanpa bukit.
- **Rekomendasi:** pilih spawn dengan komposisi: cari titik dengan `slope` sedang + delta tinggi ≥ 8 dalam radius 24 + air dalam 60 blok, lalu orientasikan kamera ke arah bukit. Naikkan ridge: `cont > 0.06` dan skala 78 → 96, plus plateau bertingkat (terracing 3–5 blok) agar silhouette punya "langkah".

### V9. Atmosfer kurang (severity: sedang)
- Fog `0.0045` siang, `aerial_perspective 0.55`, `fog_sky_affect 0.2`, height fog `26 @ 0.05`.
- Pohon jauh masih bertepi keras; kedalaman tidak terbaca.
- **Rekomendasi:** fog density 0.006–0.008 siang, warna fog = horizon biome (bukan abu-abu), `fog_sky_affect 0.35`, dan tambahkan **lapisan kabut rendah** (height fog density 0.12, height 6) di pagi/senja → kedalaman instan.

### V10. Malam tidak terbaca (severity: tinggi)
- `_moon.light_energy = night * 0.62`, ambient 0.36, `fog_light_color` lerp `#3c4c54`.
- Tidak ada sumber hangat; lamp/torch ada tapi jarang dan emission hanya 0.7 tanpa bloom.
- **Rekomendasi:** malam biru-tinta (`#2a3a5c` ambient), moon 0.75 dingin `#9fc0ff`, fog malam 0.010 dengan warna biru gelap; naikkan `EMISSION` lamp/torch/kristal ke 1.6–2.2 dan tambahkan **glow palsu** (sprite halo additive di lampu) karena glow 3D tidak tersedia di renderer ini.

### V11. Viewmodel menutupi layar & melayang (severity: sedang-tinggi)
- `hand_root.position ≈ (0.42, -0.31, -0.74)`, rotasi `-4°`, skala tool besar; tidak ada lengan/hand mesh.
- Pickaxe menempati ~20% frame kanan bawah dan bertabrakan visual dengan hotbar.
- **Rekomendasi:** geser ke `(0.36, -0.36, -0.82)`, perkecil skala tool 0.85, tambahkan **lengan voxel** (2 blok, warna kulit/glove) supaya tidak melayang, dan turunkan amplitudo swing 62° → 46° agar tidak menyapu HUD.

### V12. HUD: terlalu banyak kotak, kontras teks rendah (severity: tinggi)
- `UITheme`: alpha panel 0.94/0.975/0.88/0.78 bercampur; radius 10/12/14/20 bercampur; border 1–2px.
- 7 tombol ikon kanan atas bobot sama; hint kiri bawah 13px mint pucat di atas rumput terang; toast kanan bawah menutupi playfield.
- **Rekomendasi:**
  1. **Satu bahasa visual**: radius 14 untuk semua, border 1px alpha 0.35, bg `rgba(9,20,20,0.72)` + backdrop blur palsu (gradient atas).
  2. **Hierarki kanan atas**: CRAFT sebagai tombol amber primary; BAG/TEAM sebagai sekunder; CODEX/QUEST/MAP/PAUSE masuk satu tombol "≡" menu → dari 7 kotak jadi 3.
  3. **Hint**: pindahkan ke kartu bawah-tengah yang muncul 8 detik lalu fade, atau ke panel pause; jangan permanen di atas dunia.
  4. **Toast**: satukan jadi satu stack maksimal 3, lebar 260, di kanan atas di bawah jam (bukan kanan bawah), animasi slide+fade, ikon kecil.
  5. **Hotbar**: sembunyikan slot kosong di luar 1–9? Tidak — lebih baik: slot kosong jadi garis tipis tanpa bg, nomor hanya muncul saat hover/scroll.
  6. **Kontras**: teks sekunder minimal `#cfe0d6` di atas panel gelap; jangan pernah teks terang langsung di atas dunia tanpa panel.

### V13. Minimap datar (severity: rendah-sedang)
- Kotak hijau polos, ikon pemain kecil, tanpa border yang menyatu dengan tema.
- **Rekomendasi:** tint minimap per biome (pakai warna `BIOMES.grass/surface`), border radius 14 + vignette dalam, arah hadap sebagai kerucut, dan marker quest berbentuk diamond amber.

---

## 4. Temuan gameplay + rekomendasi

Sistem yang sudah ada: mining + tool tier, crafting, inventory/chest, farming (hoe/seed/wheat), taming & breeding monster, skill monster, riding, quest + story, village + NPC + shop, dungeon + boss, biomas (meadow/desert/frost/mushroom/ash), rare species.

Yang belum ada (grep tidak menemukan implementasi): **cooking, enchanting, dodge/block, durability, fishing**.

### G1. Loop menambang belum "berbunyi" (severity: tinggi)
Tidak ada progress bar/retak blok, tidak ada partikel per-jenis-blok, tidak ada pitch variasi suara per material. Menambang 1 blok terasa sama untuk batu, kayu, kristal.
**Rekomendasi:** crack overlay 4 tahap (tekstur 16px overlay), partikel warna dari tile blok, pitch sfx per material, dan angka "progress" halus di crosshair (arc tipis) — bukan bar besar.

### G2. Combat terlalu datar (severity: tinggi)
Hanya serangan jarak dekat + skill monster. Tidak ada dodge, block, knockback yang terbaca, atau telegraph musuh.
**Rekomendasi:** (a) dodge roll (0.35s, i-frame) dengan cooldown 1.2s; (b) telegraph 0.5s sebelum serangan boss (ring merah di tanah); (c) hit-stop 60ms + knockback kecil; (d) variasi 3 archetype perilaku (charger, ranged, summoner).

### G3. Progresi tanpa "momen" (severity: sedang)
Tool tier naik, tapi tidak ada upacara/feedback besar. Unlock baru (mount, ranch, dungeon) tidak dirayakan.
**Rekomendasi:** banner tipis full-width saat unlock (bukan modal), suara "chime", dan satu quest tutorial yang memandu urutan: kayu → pickaxe batu → ranch → tame pertama.

### G4. Quest cenderung checklist (severity: sedang)
Struktur `QUEST_TEMPLATES` berbasis kumpulkan/bunuh. Tidak ada quest bercerita dengan pilihan.
**Rekomendasi:** 5 quest bertipe "kunjungi tempat + temui NPC + pilih" dengan reward unik (resep/langit baru), bukan hanya jumlah item.

### G5. Ekonomi & desa dangkal (severity: sedang)
Shop ada, tapi tanpa kebutuhan yang mendesak (tidak ada durability/konsumsi).
**Rekomendasi:** tambah cooking (3 resep) yang memberi buff singkat → bahan pangan jadi berharga; tambah 1 NPC "peneliti" yang membeli sampel monster untuk mengisi codex.

### G6. Tidak ada alasan menjelajah jauh (severity: tinggi)
Bioma ada tapi tanpa struktur khusus (tidak ada ruang bawah tanah terpisah, menara, kuil).
**Rekomendasi:** satu "landmark" per bioma dengan reward unik (mis. menara es yang memaksa memakai torch), dan kompas quest yang menunjuk landmark terdekat yang belum ditemukan.

### G7. Pertanian & ranch tidak saling terhubung (severity: rendah-sedang)
Ada wheat + hewan ternak, tapi tidak ada rantai produksi.
**Rekomendasi:** ranch menghasilkan material (bulu/susu/telur) yang jadi bahan cooking/crafting → satu rantai produksi kecil yang jelas.

---

## 5. Roadmap prioritas (dampak ÷ usaha)

**Sprint A — "Sekali lihat langsung beda" (±1 sesi)**
1. V1 grading + ambient (angka di atas).
2. V3 rasio sinar:ambient + shadow 80m.
3. V6 tint biome per chunk di mesher (dampak terbesar).
4. V12.2 hierarki kanan atas: 7 → 3 tombol.
5. V12.3 hint kiri bawah dihapus/fade.
Kriteria sukses: screenshot siang menunjukkan ≥3 nuansa hijau berbeda dalam satu frame, bayangan pohon terbaca, dan tidak ada teks kecil di atas rumput.

**Sprint B — "Dunia terasa hidup" (±2 sesi)**
6. V2 material roughness/specular per blok.
7. V7 varian pohon + semak + batu permukaan.
8. V8 spawn composition + ridge lebih tegas.
9. V9 fog berlapis + warna fog per biome.
10. V5 tekstur dirapikan (speckle −40%, pola terarah).

**Sprint C — "Premium feel" (±2 sesi)**
11. V10 malam biru + halo lampu additive.
12. V11 viewmodel: lengan + skala 0.85 + posisi baru.
13. V13 minimap bertema.
14. G1 crack overlay + partikel per material + pitch sfx.
15. G3 banner unlock + quest tutorial berantai.

**Sprint D — "Kedalaman gameplay" (±3 sesi)**
16. G2 dodge + telegraph boss + hit-stop.
17. G5 cooking (3 resep) + NPC peneliti.
18. G6 satu landmark per biome + kompas.
19. G7 rantai ranch → cooking.

---

## 6. Kalau hanya boleh lima perubahan

1. **Ambient 0.96 → 0.6 & sky contribution 1.0 → 0.75** — bayangan dan bentuk blok langsung muncul.
2. **Tint warna biome per chunk di mesher** — dunia berhenti terasa satu warna.
3. **Buka `specular_disabled`, roughness per material** — batu/kayu/kristal/es beda karakter.
4. **HUD: 7 tombol → 3, hapus hint permanen, toast ke kanan atas** — layar bersih dan tenang.
5. **Palet rumput/daun diturunkan saturasinya + ACES exposure 1.0** — hilang kesan "hijau neon prototype".

Kelima poin ini tidak menambah satu fitur pun, tapi mengubah persepsi tampilan paling besar.
