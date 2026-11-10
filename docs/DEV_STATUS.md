# MonsterCraft: Voxel Adventure — Development Status

Updated: 2026-11-07  
Engine: Godot 4.7.2 · Android release APK: `builds/MonsterCraft.apk` (~53 MB)  
Target: Android mid-range, fully offline. Test device: Redmi Note 11 (2201117TY).

## Build & run

```bash
# Export
"/c/dev/godot/Godot_v4.7.2-stable_win64.exe" --headless --path . \
  --export-release "Android" "builds/MonsterCraft.apk"

# Install on phone
adb install -r builds/MonsterCraft.apk

# Desktop QA (touch HUD, no phone needed)
Godot --path . -- --skip-starter --touch-ui --shot=5
```

The export excludes `screenshots/`, `tools/`, and `builds/`. A headless compile check (`--quit-after 120`) passes with no script errors.

---

## Phase 1 — Foundation: complete

- Seed-based chunked voxel terrain, greedy meshing, background chunk generation, chunk streaming, fog/culling, render-distance setting (Low/Balanced/Far/Ultra).
- First-person movement, gravity, swimming, sprint, jump, fall damage, touch joystick + drag look.
- Mining with per-block hardness/tool tiers, block highlight, progress bar, break particles, drops, placement, hotbar and 36-slot inventory.
- 48 data-driven crafting recipes, crafting panel, storage chests, equipment slots.
- Autosave + manual save, 3 save slots, settings file.
- Main menu, pause, controls guide, notifications, target/boss panels, minimap.

Critical fixes in this pass:

- `CraftPlayer.world` and `CraftPlayer.main` are now assigned in `Main._on_world_ready`. Previously both were null, so the player's `_physics_process` exited immediately: no walking, jumping, mining, or combat even though the world rendered.
- Touch look: left/right screen split is applied only to the joystick, so repeated right-side drags keep rotating the camera.
- 1-block terrain steps now trigger a small automatic step-up jump, so walking uphill no longer stalls.
- Companion spawns/follows behind the player instead of filling the camera.
- Android Back opens the pause menu; it no longer exits the game.
- Safe-load recovery: if a saved position ends up inside solid blocks (e.g. after a long idle session), the player is lifted to the first open air column instead of spawning with the camera inside terrain.

Verified on the phone: walking across terraced terrain, jumping (no crash), mining leaves/dirt (inventory increments, e.g. +2 Fiber, +1 Wild Berries), block placement (dirt 12 → 11).

## Phase 2 — Core gameplay: complete

- 5 biomes: Emerald Vale, Amber Desert, Frozen Peaks, Sporewood, Ashen Reach.
- 41 original species, data-driven stages/evolutions/variants; wild spawns, day/night behavior, combat, capture orbs, feed taming, bond/leveling, evolution, party of active companions.
- Monster utility abilities: farming, mining, smelting, speed, guard, hauling, exploration; companion panel and SKILL action.
- Real-time melee combat, elemental stats, loot, XP, level-ups, equipment defense.

Verified: wild monster target panel (Breezel), companion skill cast with live cooldown, mining and block placement via action buttons.

## Phase 3 — Expansion: complete

- Dungeons with waves, bosses, rune/route tracking, rewards; bosses show the boss bar.
- NPC villages with dialogue, shop, quests; village discovery and routing.
- Farming (hoe → farmland → seeds → wheat), ranch banner, automated workers, breeding, mounts with saddle and dismount button, World Rift endless waves.
- Quest/objective chain, codex discovery, world map, chest loot tiers.

Spot-checked: quests/codex/map panels open; ranch/party tabs present. Full on-device regression of village/shop/dungeon/rift still on the QA list below.

## Phase 4 — Content, polish, optimization: in progress

Implemented:

- 48 crafting recipes, tool tiers, armor, food, orbs, feed, saddle, rift key; blocks, plants, ores, chests.
- Day/night cycle, weather (rain/storm), world events, autosave, multiple slots.
- New icon pipeline:
  - Redesigned 32×32 item icons (tools, orbs, food, ores, armor, misc).
  - Isometric 3D block icons (flat icons for plants/torch/glass).
  - Custom action icons: MINE, JUMP, PLACE, USE, SKILL, DISMOUNT, with dynamic captions (MINE/EAT/THROW/TILL/PLANT).
  - Icon contact sheet: `screenshots/icons_sheet.png` (regenerate with `Godot --headless --script tools/render_icons.gd`).
- Held-item viewmodel rebuilt: swords use a true 3D voxel model (stepped blade, raised ridge, crossguard, wrapped grip, pommel) with tier-specific materials: wood, stone, iron, crystal (glowing edges/gem). A camera fill light only affects the viewmodel layer so the sword stays readable at night. Other tools/food/items use enlarged pixel-art sprites, blocks use a 3D cube, orbs use a glowing sphere.
- Main menu now uses generated ultra-wide key art with a left-side readability gradient; HUD target/companion/boss cards are compact (portrait + name + slim HP + short status) so they no longer block the center view.
- Top menu bar uses drawn icon glyphs with labels (bag, craft, paw, codex, scroll, map, pause) instead of text-only buttons; modal headers have an amber accent line.
- Block placement now shows a green ghost preview at the exact target cell while holding a block, supports stacking (occupied face falls back to the top cell), and reports why a placement failed.
- Mining HUD enlarged (13 px label with outline, 270×12 progress bar).
- Complete settings panel (in-game and main menu), persisted to `user://settings.cfg`:
  - Controls: sensitivity, invert look Y, left-handed layout (joystick side swap), screen shake.
  - Audio: master, music, effects (applied live).
  - Video: render distance Low/Balanced/Far/Ultra, applied immediately.
  - Reset defaults, Save & Back, auto-save on toggle/slider release.
- Phone UI at 1.5× font boost; scrollable settings; English UI (crafting title and item names cleaned up).

## Controls (phone)

- Move: drag the left half (right half if left-handed is enabled).
- Look: drag the other half.
- MINE: hold to mine/attack; JUMP; PLACE; USE; SKILL; DISMOUNT when mounted.
- Hotbar: tap slots. Top bar: BAG, MAKE, TEAM, BOOK, TASK, MAP, pause.
- Android Back: pause menu.

## Verification log (this session)

- Phone: main-menu settings open, scroll, toggle Invert (On), close, reopen in-game settings (persisted On), toggle Off (saved).
- Phone: movement + step-up, jump, mining, placement, skill cooldown, bag/crafting panels, pause, resume.
- Phone: held sword/pickaxe sprites readable; block ghost preview visible; two dirt blocks placed in a row (count 11 → 10 → 9).
- Desktop: settings panel at 1.0×, touch HUD at 1.5×, icon contact sheet, compile check clean.
- Phone: generated key art fills the menu at 20:9; compact target card rendered with portrait, name/level/element, slim HP and short capture/aggro note; companion card and top icon bar fit at 1.5× scaling.
- Phone: 3D voxel wooden sword visible in first person at night/rain, angled from the lower right; hotbar selection switches viewmodel without leftover sprites.
- Screenshots: `screenshots/phone_game_icons.png`, `phone_settings_ingame.png`, `phone_craft_final.png`, `phone_sword_3d_v2.png`, `phone_menu_premium.png`, `icons_sheet.png`.

## Known gaps / next steps

1. Grow species/biomes via the data tables (target: hundreds of species); current 41 species / 5 biomes.
2. Full device regression of villages, shop, dungeon boss, ranch breeding, mount, World Rift.
3. USE near a wild monster interacts contextually (feed/pet) without a toast; keep or add a small confirmation.
4. The game does not auto-pause when left in the foreground with no input; add an AFK pause option if desired.
5. Performance pass on 4 GB RAM devices at Far/Ultra render distance.
6. Add more endgame loops and long-term progression content.
7. Consider a font-size setting if 1.5× is not enough on small phones.

## Overhaul AAA - Dunia Massive, Rare Species, Landmark & Story Quest

Putaran ini menuntaskan permintaan besar terakhir: dunia yang jauh lebih luas dan hidup,
makhluk rare yang unik, landmark interaktif, serta sistem story quest lengkap dengan marker
dan halaman quest baru. Semua perubahan di bawah sudah diverifikasi headless + render.

### Dunia
- Skala kontinen: noise kontinen 0.0045 -> 0.0034, ridge 62 -> 78 dengan threshold 0.16 -> 0.135,
  sehingga daratan menyatu jadi massa benua besar (bukan pulau-pulau kecil).
- Jarak pandang baru: tier "Massive" (7 chunk), default naik dari 4 ke 5, clamp 2..8.
  Tersedia di Settings (in-game) dan di menu utama.

### Landmark unik (TerrainGen + World + Main + Player)
- `TerrainGen.LANDMARK_GRID` (148 blok) dengan 6 jenis landmark: Sunken Obelisk, Weathered Ruins,
  Forgotten Shrine, Broken Watchtower, Fairy Ring, Ancient Gate. Semua di-stamp deterministik
  per sel (cache `_landmark_cache`), lengkap dengan Rune Core, lampu, dan dekorasi.
- Rune Core landmark bisa di-interact: Ancient Gate memindahkan pemain ke desa terdekat,
  landmark lain memberi pesan lore. Fallback ditambahkan di `CraftPlayer.interact_now`
  (cabang "rune") lewat `Main.interact_landmark`, jadi rune dungeon tetap berfungsi normal.
- API baru: `TerrainGen.landmark_at_cell/nearby_landmarks/landmark_at_pos/nearby_landmarks_at`,
  `VoxelWorld.get_landmark_at/get_nearby_landmarks`.

### Makhluk rare
- 8 spesies rare baru (`rare: true`, stat tinggi, catch rate 0.06-0.07, lore khusus):
  Prismawing, Voidwhisk, Cindermane, Glaciermaw, Mycelord, Dunestrider, Stormcaller, Thornback.
- `Content.rare_species()` + hook spawner: 5.5% spawn wild diganti spesies rare dengan variant
  shiny, sehingga perjumpaan terasa istimewa tapi tetap bisa ditemukan.

### Story quest
- Data naratif baru `src/game/Story.gd`: 5 chapter main (The Waking Vale, A Bond in the Wild,
  Beneath the Roots, Shards of the Rift, Heart of the Vale) + 7 side quest, masing-masing
  punya giver, cerita, step, reward, dan jenis marker.
- Runtime di `Game`: `story`, `tracked_quest`, `init_story()`, `_story_event()` (nyambung ke
  objective/quest bus yang sudah ada), `story_unlocked()`, `claim_story()`, `active_story_quests()`,
  `tracked_story_quest()`, `story_step_text()`. Progres ikut tersimpan di save/load.
- Main story terkunci berurutan (chapter berikutnya terbuka setelah chapter sebelumnya selesai).

### Marker & HUD
- Beacon 3D di dunia (`Main._update_quest_markers`): kristal berputar + beam + label nama/jarak,
  amber untuk main quest, teal untuk side quest, hijau saat selesai. Di-refresh tiap 0.6 detik.
- Marker quest juga muncul di minimap (`MinimapView._draw_marker_quest`).
- Quest tracker glass di kanan atas HUD: judul, step aktif dengan progres, giver, dan jarak.
- `Elder` desa otomatis menandai flag `met_elder` saat dialog dibuka (step story pertama).

### Halaman quest baru
- `UIRoot._build_quests` ditulis ulang: header "Story Journal" + kartu Current Act,
  progress bar chapter, bagian MAIN STORY dan SIDE QUESTS.
- Tiap kartu menampilkan status (LOCKED / ACTIVE / READY TO CLAIM / CLAIMED), cerita,
  checklist step dengan progres, reward, tombol Track, dan tombol Claim Reward.

### Dunia lebih hidup
- NPC (`Villager`) punya speech bubble Label3D: dialog singkat per role (elder, merchant,
  farmer, villager) muncul saat pemain dalam 5 m, dengan cooldown acak.
- Atmosfer sebelumnya (ACES tonemap, aerial/height fog, sun shadow, star dome, partikel
  pollen/firefly) tetap aktif dan sekarang terlihat lebih jauh berkat view distance baru.

### Verifikasi
- `--headless -- --ui-test` exit 0, tanpa parse/runtime error.
- Render windowed `--skip-starter --shot=6` dan `--panel=quests --shot=6` exit 0;
  screenshot: `screenshots/game.png`, `screenshots/quests.png`.
- `tools/validate_content.gd` lolos tanpa problem setelah biome data dirapikan dan validator
  template quest diperbaiki (template memang tidak menyimpan title; title dibuat `make_quest`).

## Held Viewmodel - Voxel Tools

Viewmodel alat yang sebelumnya memakai billboard sprite 2D (datar dan terlihat melayang)
diganti model voxel 3D sungguhan, dibangun dari box bertingkat seperti pedang.

- Model voxel baru untuk pickaxe, axe, shovel, hoe, dan torch, plus lengan/fist blocky
  supaya alat terlihat dipegang, bukan melayang.
- Posisi, rotasi, dan skala per-alat disetel agar kepala alat terbaca jelas di kamera;
  cache `tool_models` per `kind_tier` supaya tidak dibangun ulang saat ganti slot.
- Warna material mengikuti tier item: kayu, batu, besi, crystal (tier 3-4 memakai emission).
  Torch memakai emisi amber dan tetap menyala di tangan.
- Pedang voxel yang sudah ada tetap dipakai; blok dan orb tidak berubah.
- Verifikasi: `--headless -- --ui-test` exit 0; screenshot gameplay memperlihatkan
  pickaxe voxel di tangan kanan.

## World Items & Creature Textures

- Item drop di dunia tidak lagi kotak polos: setiap kategori punya model voxel mini
  (pickaxe/axe/shovel/hoe/sword, torch menyala, ingot, gem, orb, potion, berry, seeds,
  wheat, fiber, leather, feed, saddle, stick). Model berputar dan bob seperti item drop
  pada umumnya, dengan emissive untuk crystal/amber/core/rift key/orb.
- Tekstur creature baru: Content.monster_texture() membuat tekstur 24x24 prosedural per
  warna dengan gradient vertikal (atas lebih terang, bawah lebih gelap) plus pola sesuai
  elemen - fur, scale, crack, ember, spark, spore, sand, crystal, void.
  Content.monster_material() memakainya dengan filter NEAREST dan uv scale 1.7, sehingga badan
  monster tidak lagi flat satu warna.
- Portrait Codex diberi grain halus (fur/scale specks) di area kepala, jadi ilustrasi
  terasa bertekstur tanpa mengganggu mata dan muka.
- Verifikasi: --headless -- --ui-test exit 0 tanpa parse/runtime error; screenshot
  gameplay memperlihatkan pickaxe voxel di tangan.

## HUD Cleanup - No Overlap, Compact Tracker

- Quest tracker dikecilkan dari kartu 362x154 menjadi kartu ringkas 306x76 di kanan atas:
  satu baris kicker + jarak, satu baris judul quest, satu baris step aktif dengan clip,
  dan garis aksen kiri yang mengikuti warna main/side. Tidak lagi menutupi layar.
- Notifikasi/toast dipindah ke kanan bawah (di atas hotbar) untuk desktop, jadi tidak
  pernah menimpa tracker quest. Di perangkat sentuh tetap di kanan atas, tapi dimulai
  di bawah tracker.
- Baris atas dirapikan: panel jam dipersempit (280) dan dock menu digeser, sehingga jam
  dan tombol menu tidak lagi saling menumpuk di lebar 1280.
- Kartu target monster turun ke y 124-188 (jeda 12px dari jam) dan banner dipindah ke
  y 204-320; saat boss muncul target bergeser ke 176-240 tanpa menabrak.
- Verifikasi: `--headless -- --ui-test` exit 0; screenshot gameplay 1280x720 diperiksa
  langsung untuk memastikan tidak ada panel yang bertumpuk.
