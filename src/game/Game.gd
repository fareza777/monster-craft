extends Node
## Persistent game state and rules. The world node is rebuilt from this state,
## so every system can be saved to one of three offline slots.

signal inventory_changed
signal stats_changed
signal party_changed
signal objectives_changed
signal quests_changed
signal story_changed
signal notify(text: String, color: Color)
signal banner(title: String, subtitle: String)
signal day_changed(day: int)
signal weather_changed(weather: String)
signal event_started(kind: String)
signal saved(slot: int)
signal evolved(new_species: String)
signal starter_needed
signal monster_killed_signal(mon: Dictionary, xp: int)

const SAVE_VERSION := 1
const INVENTORY_SIZE := 36
const HOTBAR_SIZE := 9
const DAY_SECONDS := 540.0
const SAVE_DIR := "user://saves"
const MAX_SLOTS := 3

var in_game := false
var current_slot := -1
var pending_starter := false
var play_time := 0.0
var seed_value := 0

var day := 1
var day_time := 0.28
var weather := "clear"
var weather_timer := 150.0
var event_name := ""
var event_timer := 0.0
var event_drop_mult := 1.0
var _autosave_timer := 45.0
var _last_hit_time := -99.0

var hp := 100
var max_hp := 100
var stamina := 100.0
var max_stamina := 100.0
var level := 1
var xp := 0
var wallet := 15
var kills := 0
var captures := 0
var deaths := 0

var inventory: Array = []
var selected_hotbar := 0
var party: Array = []
var storage: Array = []
var active_index := -1
var equipment := {"head": null, "body": null, "feet": null}

var objectives: Dictionary = {}
var codex: Dictionary = {}
var quests: Array = []
var flags: Dictionary = {}
var chests: Dictionary = {}
var village_quests: Dictionary = {}
var story: Dictionary = {}
var tracked_quest := ""
var ranch := {"workers": [], "cooldown": 0.0, "last_real": 0.0}
var rift_waves := 0
var dungeons_cleared: Dictionary = {}
var discovered_villages: Dictionary = {}

var spawn_point := Vector3.ZERO
var pending_world_data: Dictionary = {}
var world_ref: Node = null
var loaded_from_slot := false

var _rng := RandomNumberGenerator.new()
var look_sensitivity := 1.0
var master_volume := 0.8
var music_volume := 0.75
var sfx_volume := 0.9
var invert_look_y := false
var left_handed := false
var screen_shake := true
var view_distance := 5
var settings_path := "user://settings.cfg"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_rng.randomize()
	load_settings()
	Sfx.apply_volumes()
	_clear_state()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		look_sensitivity = clampf(float(cfg.get_value("controls", "sensitivity", 1.0)), 0.35, 2.5)
		invert_look_y = bool(cfg.get_value("controls", "invert_y", false))
		left_handed = bool(cfg.get_value("controls", "left_handed", false))
		master_volume = clampf(float(cfg.get_value("audio", "volume", 0.8)), 0.0, 1.0)
		music_volume = clampf(float(cfg.get_value("audio", "music", 0.75)), 0.0, 1.0)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 0.9)), 0.0, 1.0)
		screen_shake = bool(cfg.get_value("video", "screen_shake", true))
		view_distance = clampi(int(cfg.get_value("video", "view_distance", 5)), 2, 8)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "sensitivity", look_sensitivity)
	cfg.set_value("controls", "invert_y", invert_look_y)
	cfg.set_value("controls", "left_handed", left_handed)
	cfg.set_value("audio", "volume", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.set_value("video", "view_distance", view_distance)
	cfg.save(settings_path)
	Sfx.apply_volumes()

func reset_settings() -> void:
	look_sensitivity = 1.0
	invert_look_y = false
	left_handed = false
	master_volume = 0.8
	music_volume = 0.75
	sfx_volume = 0.9
	screen_shake = true
	view_distance = 5
	save_settings()

func _process(delta: float) -> void:
	if not in_game:
		return
	play_time += delta
	day_time += delta / DAY_SECONDS
	while day_time >= 1.0:
		day_time -= 1.0
		day += 1
		day_changed.emit(day)
		_daily_roll()
	weather_timer -= delta
	if weather_timer <= 0.0:
		_roll_weather()
	event_timer -= 1.0 if event_name != "" else 0.0
	if event_name != "" and event_timer <= 0.0:
		event_name = ""
		event_drop_mult = 1.0
	if ranch.cooldown > 0.0:
		ranch.cooldown = maxf(0.0, ranch.cooldown - delta)
	_autosave_timer -= delta
	if _autosave_timer <= 0.0 and current_slot >= 0 and world_ref != null:
		_autosave_timer = 45.0
		save_game(current_slot, true)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9 and in_game and current_slot >= 0:
			save_game(current_slot, false)

func _clear_state() -> void:
	in_game = false
	current_slot = -1
	pending_starter = false
	play_time = 0.0
	seed_value = 0
	day = 1
	day_time = 0.28
	weather = "clear"
	weather_timer = 150.0
	event_name = ""
	event_timer = 0.0
	event_drop_mult = 1.0
	hp = 100
	max_hp = 100
	stamina = 100.0
	max_stamina = 100.0
	level = 1
	xp = 0
	wallet = 15
	init_story()
	kills = 0
	captures = 0
	deaths = 0
	inventory = []
	inventory.resize(INVENTORY_SIZE)
	selected_hotbar = 0
	party = []
	storage = []
	active_index = -1
	equipment = {"head": null, "body": null, "feet": null}
	objectives = {}
	codex = {}
	quests = []
	flags = {}
	chests = {}
	village_quests = {}
	story = {}
	tracked_quest = ""
	ranch = {"workers": [], "cooldown": 0.0, "last_real": 0.0}
	rift_waves = 0
	dungeons_cleared = {}
	discovered_villages = {}
	spawn_point = Vector3.ZERO
	pending_world_data = {}
	world_ref = null
	loaded_from_slot = false
	if Content != null:
		for o in Content.OBJECTIVES:
			objectives[o.id] = {"progress": 0, "done": false}

# ---------------------------------------------------------------- new / save / load

func begin_new_world(slot: int, world_seed: int = 0, world_name: String = "") -> void:
	_clear_state()
	in_game = true
	current_slot = slot
	seed_value = world_seed if world_seed != 0 else int(Time.get_unix_time_from_system()) ^ randi()
	day = 1
	day_time = 0.28
	hp = max_hp
	stamina = max_stamina
	wallet = 15
	pending_starter = true
	add_item("pick_wood", 1, true)
	add_item("sword_wood", 1, true)
	add_item("planks", 12, true)
	add_item("berry", 4, true)
	add_item("torch", 3, true)
	add_item("orb", 3, true)
	add_item("feed", 2, true)
	print("[MonsterCraft] New world slot=%d seed=%d name=%s" % [slot, seed_value, world_name])

func attach_world(world: Node) -> void:
	world_ref = world

func choose_starter(species_id: String) -> void:
	if not Content.SPECIES.has(species_id):
		return
	pending_starter = false
	var mon := Content.new_monster(species_id, 5, "normal")
	party.append(mon)
	active_index = 0
	_register_codex(species_id)
	notify.emit("%s joined your team!" % Content.SPECIES[species_id].name, Color("#9ee8a0"))
	party_changed.emit()
	if current_slot >= 0:
		save_game(current_slot, true)

func save_game(slot: int = -1, silent: bool = false) -> bool:
	if not in_game:
		return false
	if slot < 0:
		slot = current_slot
	if slot < 0:
		return false
	current_slot = slot
	var wd: Dictionary = {}
	if world_ref != null and world_ref.has_method("get_save_data"):
		wd = world_ref.get_save_data()
		spawn_point = world_ref.get("spawn_point") if world_ref.get("spawn_point") != null else spawn_point
	ranch.last_real = Time.get_unix_time_from_system()
	var data := {
		"version": SAVE_VERSION,
		"slot": slot,
		"seed": seed_value,
		"name": _world_name(),
		"saved_at": Time.get_datetime_string_from_system(),
		"real_time": ranch.last_real,
		"play_time": play_time,
		"day": day,
		"day_time": day_time,
		"weather": weather,
		"event_name": event_name,
		"hp": hp,
		"max_hp": max_hp,
		"stamina": stamina,
		"level": level,
		"xp": xp,
		"wallet": wallet,
		"kills": kills,
		"captures": captures,
		"deaths": deaths,
		"inventory": inventory,
		"selected_hotbar": selected_hotbar,
		"party": party,
		"storage": storage,
		"active_index": active_index,
		"equipment": equipment,
		"objectives": objectives,
		"codex": codex,
		"quests": quests,
		"flags": flags,
		"chests": chests,
		"village_quests": village_quests,
		"story": story,
		"tracked_quest": tracked_quest,
		"ranch": ranch,
		"rift_waves": rift_waves,
		"dungeons_cleared": dungeons_cleared,
		"discovered_villages": discovered_villages,
		"spawn_point": [spawn_point.x, spawn_point.y, spawn_point.z],
		"world": wd,
	}
	var path := _save_path(slot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		if not silent:
			notify.emit("Failed to save the world.", Color("#ff8a7a"))
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	saved.emit(slot)
	if not silent:
		notify.emit("World saved.", Color("#a9d8c8"))
	return true

func load_game(slot: int) -> bool:
	var path := _save_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null or not parsed is Dictionary:
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		return false
	_clear_state()
	in_game = true
	current_slot = slot
	loaded_from_slot = true
	seed_value = int(data.get("seed", 1))
	play_time = float(data.get("play_time", 0.0))
	day = int(data.get("day", 1))
	day_time = float(data.get("day_time", 0.28))
	weather = str(data.get("weather", "clear"))
	event_name = str(data.get("event_name", ""))
	hp = int(data.get("hp", 100))
	max_hp = int(data.get("max_hp", 100))
	stamina = float(data.get("stamina", 100.0))
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	wallet = int(data.get("wallet", 15))
	kills = int(data.get("kills", 0))
	captures = int(data.get("captures", 0))
	deaths = int(data.get("deaths", 0))
	inventory = _normalize_inventory(data.get("inventory", []))
	selected_hotbar = int(data.get("selected_hotbar", 0))
	party = _array_of_dicts(data.get("party", []))
	storage = _array_of_dicts(data.get("storage", []))
	active_index = int(data.get("active_index", -1))
	equipment = data.get("equipment", {"head": null, "body": null, "feet": null})
	objectives = data.get("objectives", {})
	codex = data.get("codex", {})
	quests = _array_of_dicts(data.get("quests", []))
	flags = data.get("flags", {})
	chests = data.get("chests", {})
	village_quests = data.get("village_quests", {})
	story = data.get("story", {})
	tracked_quest = str(data.get("tracked_quest", ""))
	init_story()
	ranch = data.get("ranch", {"workers": [], "cooldown": 0.0})
	ranch["workers"] = _array_of_dicts(ranch.get("workers", []))
	rift_waves = int(data.get("rift_waves", 0))
	dungeons_cleared = data.get("dungeons_cleared", {})
	discovered_villages = data.get("discovered_villages", {})
	var sp: Array = data.get("spawn_point", [0, 40, 0])
	spawn_point = Vector3(float(sp[0]), float(sp[1]), float(sp[2]))
	pending_world_data = data.get("world", {})
	for o in Content.OBJECTIVES:
		if not objectives.has(o.id):
			objectives[o.id] = {"progress": 0, "done": false}
	var offline: float = clampf(Time.get_unix_time_from_system() - float(data.get("real_time", Time.get_unix_time_from_system())), 0.0, 4.0 * 3600.0)
	if offline > 60.0:
		call_deferred("_collect_offline_ranch", offline)
	notify.emit("World loaded. Day %d." % day, Color("#a9d8c8"))
	return true

func _collect_offline_ranch(seconds: float) -> void:
	var ticks := int(seconds / 150.0)
	if ticks <= 0:
		return
	var gained: Dictionary = {}
	var mine := 0
	for mon in ranch.workers:
		var sp: Dictionary = Content.SPECIES.get(mon.get("species", ""), {})
		var ability: String = sp.get("ability", "")
		for i in mini(ticks, 24):
			match ability:
				"farming":
					gained["wheat"] = int(gained.get("wheat", 0)) + 1
					if randf() < 0.4: gained["seeds"] = int(gained.get("seeds", 0)) + 1
				"mining":
					gained["stone"] = int(gained.get("stone", 0)) + 2
					if randf() < 0.25: gained["coal"] = int(gained.get("coal", 0)) + 1
					if randf() < 0.08: gained["iron_ore"] = int(gained.get("iron_ore", 0)) + 1
				"gathering":
					gained["fiber"] = int(gained.get("fiber", 0)) + 2
					if randf() < 0.3: gained["amber"] = int(gained.get("amber", 0)) + 1
				"harvest":
					gained["wheat"] = int(gained.get("wheat", 0)) + 1
					if randf() < 0.3: gained["mush_cap"] = int(gained.get("mush_cap", 0)) + 1
				"smelting":
					if randf() < 0.3: gained["iron_ingot"] = int(gained.get("iron_ingot", 0)) + 1
				"healing":
					if randf() < 0.35: gained["berry"] = int(gained.get("berry", 0)) + 2
				"fishing":
					gained["fiber"] = int(gained.get("fiber", 0)) + 1
					if randf() < 0.12: gained["crystal"] = int(gained.get("crystal", 0)) + 1
				"glow":
					if randf() < 0.25: gained["amber"] = int(gained.get("amber", 0)) + 2
				"hauler":
					gained["stone"] = int(gained.get("stone", 0)) + 1
				"spore":
					if randf() < 0.4: gained["mush_cap"] = int(gained.get("mush_cap", 0)) + 1
				_:
					gained["fiber"] = int(gained.get("fiber", 0)) + 1
		mine += 1
	if gained.is_empty():
		return
	var parts: Array = []
	for id in gained:
		var n: int = int(gained[id])
		add_item(id, n, true)
		parts.append("%s x%d" % [Content.get_item_name(id), n])
	if not parts.is_empty():
		notify.emit("Ranch produced: " + ", ".join(parts), Color("#f0cf91"))

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_save_path(slot))

func get_save_meta(slot: int) -> Dictionary:
	var path := _save_path(slot)
	var out := {"slot": slot, "exists": false, "name": "Empty Slot", "day": 0,
		"level": 0, "play_time": 0.0, "seed": 0, "saved_at": "", "world_name": ""}
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		return out
	out.exists = true
	out.day = int(parsed.get("day", 1))
	out.level = int(parsed.get("level", 1))
	out.play_time = float(parsed.get("play_time", 0.0))
	out.seed = int(parsed.get("seed", 0))
	out.saved_at = str(parsed.get("saved_at", ""))
	out.world_name = str(parsed.get("name", "World"))
	out.name = "Day %d • Lv %d" % [out.day, out.level]
	return out

func list_saves() -> Array:
	var out: Array = []
	for i in range(1, MAX_SLOTS + 1):
		out.append(get_save_meta(i))
	return out

func delete_save(slot: int) -> void:
	var path := _save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _save_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]

func _world_name() -> String:
	var names: Array = Content.VILLAGE_NAMES
	var idx := absi(seed_value) % maxi(names.size(), 1)
	return "World of %s" % names[idx]

func _normalize_inventory(src: Array) -> Array:
	var out: Array = []
	out.resize(INVENTORY_SIZE)
	for i in mini(src.size(), INVENTORY_SIZE):
		var s = src[i]
		if s is Dictionary and Content.ITEMS.has(str(s.get("id", ""))):
			out[i] = {"id": str(s.id), "n": clampi(int(s.get("n", 1)), 1, 99)}
	return out

func _array_of_dicts(src) -> Array:
	var out: Array = []
	if src is Array:
		for v in src:
			if v is Dictionary:
				out.append(v)
	return out

# ---------------------------------------------------------------- inventory

func add_item(id: String, n: int, silent: bool = false) -> int:
	if not Content.ITEMS.has(id) or n <= 0:
		return n
	var remaining := n
	var stack_max: int = int(Content.ITEMS[id].get("stack", 99))
	for i in inventory.size():
		if remaining <= 0:
			break
		var s = inventory[i]
		if s is Dictionary and s.id == id and int(s.n) < stack_max:
			var add := mini(remaining, stack_max - int(s.n))
			s.n = int(s.n) + add
			remaining -= add
	for i in inventory.size():
		if remaining <= 0:
			break
		if inventory[i] == null:
			var add := mini(remaining, stack_max)
			inventory[i] = {"id": id, "n": add}
			remaining -= add
	var added := n - remaining
	if added > 0:
		_progress_quests("gather", id, added)
		_progress_objectives("item", id, added)
		inventory_changed.emit()
		if not silent:
			notify.emit("+%d %s" % [added, Content.get_item_name(id)], Color("#d8e8c0"))
	return remaining

func remove_item(id: String, n: int) -> bool:
	if count_item(id) < n:
		return false
	var remaining := n
	for i in inventory.size():
		if remaining <= 0:
			break
		var s = inventory[i]
		if s is Dictionary and s.id == id:
			var take := mini(remaining, int(s.n))
			s.n = int(s.n) - take
			remaining -= take
			if int(s.n) <= 0:
				inventory[i] = null
	inventory_changed.emit()
	return true

func count_item(id: String) -> int:
	var total := 0
	for s in inventory:
		if s is Dictionary and s.id == id:
			total += int(s.n)
	return total

func has_items(need: Dictionary) -> bool:
	for id in need:
		if count_item(str(id)) < int(need[id]):
			return false
	return true

func consume_items(need: Dictionary) -> bool:
	if not has_items(need):
		return false
	for id in need:
		remove_item(str(id), int(need[id]))
	return true

func try_craft(recipe: Dictionary) -> bool:
	if not has_items(recipe.need):
		return false
	if not consume_items(recipe.need):
		return false
	add_item(recipe.out, recipe.n)
	if recipe.out == "table":
		pass
	return true

func get_slot(i: int) -> Dictionary:
	if i < 0 or i >= inventory.size() or inventory[i] == null:
		return {}
	return inventory[i]

func get_hotbar_item() -> Dictionary:
	return get_slot(selected_hotbar)

func get_best_tool(kind: String) -> String:
	var best_id := ""
	var best_tier := -1
	for s in inventory:
		if not s is Dictionary:
			continue
		var it: Dictionary = Content.ITEMS.get(s.id, {})
		if it.get("type", "") == "tool" and it.get("tool_kind", "") == kind:
			if int(it.get("tier", 0)) > best_tier:
				best_tier = int(it.tier)
				best_id = str(s.id)
	return best_id

func tool_tier(kind: String) -> int:
	var id := get_best_tool(kind)
	return int(Content.ITEMS.get(id, {}).get("tier", 0))

func attack_damage() -> int:
	var sid := get_best_tool("sword")
	if sid == "":
		return 3 + int(level * 0.5)
	return int(Content.ITEMS[sid].get("damage", 4)) + int(level * 0.3)

func defense_total() -> int:
	var total := 0
	for slot in equipment:
		var item_id = equipment[slot]
		if item_id != null and Content.ITEMS.has(item_id):
			total += int(Content.ITEMS[item_id].get("defense", 0))
	return total

func equip_armor(index: int) -> bool:
	var s = inventory[index] if index >= 0 and index < inventory.size() else null
	if not s is Dictionary:
		return false
	var it: Dictionary = Content.ITEMS.get(s.id, {})
	if it.get("type", "") != "armor":
		return false
	var slot: String = it.get("slot", "body")
	var old = equipment.get(slot)
	equipment[slot] = s.id
	inventory[index] = null
	if old != null:
		add_item(str(old), 1, true)
	inventory_changed.emit()
	stats_changed.emit()
	notify.emit("%s equipped." % Content.get_item_name(s.id), Color("#a9d8c8"))
	return true

func unequip(slot: String) -> void:
	var old = equipment.get(slot)
	if old == null:
		return
	equipment[slot] = null
	add_item(str(old), 1)
	inventory_changed.emit()

func use_food(index: int) -> bool:
	var s = inventory[index] if index >= 0 and index < inventory.size() else null
	if not s is Dictionary:
		return false
	var it: Dictionary = Content.ITEMS.get(s.id, {})
	if it.get("type", "") != "food":
		return false
	var amount := int(it.get("heal", 10))
	heal_player(amount)
	s.n = int(s.n) - 1
	if int(s.n) <= 0:
		inventory[index] = null
	inventory_changed.emit()
	notify.emit("Restored %d HP." % amount, Color("#a9e5a0"))
	return true

func heal_player(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	stats_changed.emit()

func damage_player(raw: int, reason: String = "") -> void:
	var def := defense_total()
	var dmg := maxi(1, raw - int(def * 0.6))
	hp = maxi(0, hp - dmg)
	_last_hit_time = play_time
	stats_changed.emit()
	Sfx.play("hurt")
	if reason == "lava":
		stats_changed.emit()
	if hp <= 0:
		deaths += 1
		hp = int(max_hp * 0.5)
		notify.emit("You fell... You respawn at the start.", Color("#ff9b8a"))
		if world_ref != null and world_ref.has_method("respawn_player"):
			world_ref.respawn_player()

func add_stamina(amount: float) -> void:
	stamina = clampf(stamina + amount, 0.0, max_stamina)

func drain_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina = maxf(0.0, stamina - amount)
	return true

func add_player_xp(amount: int) -> void:
	xp += amount
	var guard := 0
	while xp >= xp_to_next() and guard < 30:
		guard += 1
		xp -= xp_to_next()
		level += 1
		max_hp += 10
		hp = max_hp
		notify.emit("Level %d! Max HP meningkat." % level, Color("#ffe08a"))
		Sfx.play("level")
	stats_changed.emit()

func xp_to_next() -> int:
	return 60 + level * 35

# ---------------------------------------------------------------- party

func active_monster() -> Dictionary:
	if active_index >= 0 and active_index < party.size():
		return party[active_index]
	return {}

func party_has_space() -> bool:
	return party.size() < 6

func add_monster(mon: Dictionary, to_party: bool = true) -> bool:
	var dest: Array = party if to_party and party_has_space() else storage
	dest.append(mon)
	_register_codex(mon.species)
	if active_index < 0 and party.size() == 1:
		active_index = 0
	party_changed.emit()
	return true

func capture_monster(mon: Dictionary, orb_mult: float) -> Dictionary:
	var sp: Dictionary = Content.SPECIES.get(mon.get("species", ""), {})
	var maxhp := Content.monster_max_hp(mon)
	var ratio := float(mon.get("hp", 1)) / maxf(1.0, float(maxhp))
	var chance := Content.catch_chance(mon.species, int(mon.level), ratio, orb_mult)
	var roll := randf()
	if roll <= chance:
		var caught: Dictionary = mon.duplicate(true)
		caught.hp = maxhp
		caught.bond = 5
		caught.xp = 0
		caught.uid = "%s_%d" % [caught.species, randi()]
		add_monster(caught, true)
		captures += 1
		_progress_objectives("capture", "", 1)
		_progress_quests("capture", caught.species, 1)
		Sfx.play("capture")
		notify.emit("%s was captured!" % sp.get("name", "Monster"), Color("#ffe08a"))
		return {"ok": true, "chance": chance, "caught": caught}
	return {"ok": false, "chance": chance}

func set_active(index: int) -> void:
	if index >= 0 and index < party.size():
		active_index = index
		party_changed.emit()

func swap_active(index: int) -> void:
	set_active(index)

func feed_active() -> String:
	return feed_party_monster(active_index)

func feed_party_monster(index: int) -> String:
	if index < 0 or index >= party.size():
		return "No active partner."
	var mon: Dictionary = party[index]
	if count_item("feed") < 1:
		return "Out of feed. Craft more from wheat, berries, and fiber."
	remove_item("feed", 1)
	mon.bond = mini(100, int(mon.get("bond", 0)) + 8)
	var maxhp := Content.monster_max_hp(mon)
	mon.hp = mini(maxhp, int(mon.get("hp", 0)) + int(maxhp * 0.3))
	add_monster_xp(index, 20)
	notify.emit("%s is happy! Bond increased." % _monster_display(mon), Color("#f0cf91"))
	party_changed.emit()
	Sfx.play("feed")
	return ""

func move_storage_to_party(index: int) -> bool:
	if index < 0 or index >= storage.size():
		return false
	if not party_has_space():
		notify.emit("Team is full. Release a monster or send one to the ranch.", Color("#ff9b8a"))
		return false
	var mon: Dictionary = storage[index]
	storage.remove_at(index)
	party.append(mon)
	if active_index < 0:
		active_index = party.size() - 1
	party_changed.emit()
	notify.emit("%s joined the team." % _monster_display(mon), Color("#a9d8c8"))
	return true

func add_monster_xp(index: int, amount: int) -> void:
	if index < 0 or index >= party.size():
		return
	var mon: Dictionary = party[index]
	mon.xp = int(mon.get("xp", 0)) + amount
	var guard := 0
	while int(mon.xp) >= Content.xp_to_next(int(mon.level)) and int(mon.level) < 50 and guard < 40:
		guard += 1
		mon.xp = int(mon.xp) - Content.xp_to_next(int(mon.level))
		mon.level = int(mon.level) + 1
		var ratio := float(mon.get("hp", 1)) / maxf(1.0, float(Content.monster_max_hp(mon)))
		mon.hp = maxi(1, int(Content.monster_max_hp(mon) * maxf(0.6, ratio)))
		Sfx.play("level")
		_check_evolution(index)
	party_changed.emit()

func _check_evolution(index: int) -> void:
	var mon: Dictionary = party[index]
	var sp: Dictionary = Content.SPECIES.get(mon.species, {})
	var evo: String = str(sp.get("evolve", ""))
	var unlock := int(sp.get("evolve_level", 0))
	if evo == "" or not Content.SPECIES.has(evo) or int(mon.level) < unlock:
		return
	var old_name: String = sp.name
	var old_hp_ratio := float(mon.get("hp", 1)) / maxf(1.0, float(Content.monster_max_hp(mon)))
	mon.species = evo
	_register_codex(evo)
	mon.hp = maxi(1, int(Content.monster_max_hp(mon) * clampf(old_hp_ratio, 0.6, 1.0)))
	notify.emit("%s evolved into %s!" % [old_name, Content.SPECIES[evo].name], Color("#ffe08a"))
	evolved.emit(evo)
	_progress_objectives("flag", "evolved", 1)
	Sfx.play("evolve")
	party_changed.emit()

func heal_party() -> void:
	for mon in party:
		mon.hp = Content.monster_max_hp(mon)
	party_changed.emit()

func _register_codex(species_id: String) -> void:
	var is_new := not codex.has(species_id)
	if is_new:
		codex[species_id] = {"count": 0, "shiny": 0}
	codex[species_id].count = int(codex[species_id].count) + 1
	if is_new:
		_progress_objectives("codex", "", 1)

func _monster_display(mon: Dictionary) -> String:
	var nickname: String = str(mon.get("nickname", ""))
	if nickname != "":
		return nickname
	return str(Content.SPECIES.get(mon.get("species", ""), {}).get("name", "Monster"))

func release_monster(idx: int, is_storage: bool = false) -> void:
	var arr: Array = storage if is_storage else party
	if idx < 0 or idx >= arr.size():
		return
	var mon: Dictionary = arr[idx]
	arr.remove_at(idx)
	wallet += 10 + int(mon.get("level", 1)) * 2
	if not is_storage:
		active_index = clampi(active_index, -1, party.size() - 1)
		if party.is_empty():
			active_index = -1
	party_changed.emit()
	notify.emit("%s released. +Amber." % _monster_display(mon), Color("#f0cf91"))

func monster_killed(mon: Dictionary) -> void:
	kills += 1
	var sp: Dictionary = Content.SPECIES.get(mon.get("species", ""), {})
	var mon_level := int(mon.get("level", 1))
	var xp_gain := 12 + int(sp.get("stage", 1)) * 8 + mon_level * 4
	add_player_xp(xp_gain)
	if active_index >= 0:
		add_monster_xp(active_index, xp_gain)
		party[active_index].bond = mini(100, int(party[active_index].get("bond", 0)) + 1)
	_progress_quests("hunt", mon.species, 1)
	if sp.get("boss", false):
		boss_defeated(str(mon.species))
	monster_killed_signal.emit(mon, xp_gain)

func boss_defeated(species_id: String) -> void:
	var dungeon_id := ""
	match species_id:
		"warden_stone": dungeon_id = "stone"
		"vulcanyx": dungeon_id = "ember"
		"glacira": dungeon_id = "frost"
		"riftmaw": dungeon_id = "rift"
	dungeons_cleared[dungeon_id] = true
	flags["boss_" + species_id] = true
	_progress_objectives("boss", species_id, 1)
	add_player_xp(180)
	notify.emit("BOSS DEFEATED!", Color("#ffe08a"))
	banner.emit("Victory!", "%s has fallen." % Content.SPECIES.get(species_id, {}).get("name", "Boss"))
	Sfx.play("victory")
	party_changed.emit()

func add_rift_wave() -> void:
	rift_waves += 1
	_progress_objectives("rift", "", 1)

# ---------------------------------------------------------------- ranch & breeding

func assign_to_ranch(mon: Dictionary, from_storage: bool = false) -> bool:
	if ranch.workers.size() >= 3:
		notify.emit("The ranch is full (3 workers).", Color("#ff9b8a"))
		return false
	var arr: Array = storage if from_storage else party
	var found := -1
	for i in arr.size():
		if str(arr[i].get("uid", "")) == str(mon.get("uid", "")):
			found = i
			break
	if found < 0:
		return false
	arr.remove_at(found)
	ranch.workers.append(mon)
	if not from_storage:
		active_index = clampi(active_index, -1, party.size() - 1)
		if party.is_empty():
			active_index = -1
	party_changed.emit()
	notify.emit("%s is now working at the ranch." % _monster_display(mon), Color("#a9d8c8"))
	return true

func recall_from_ranch(uid: String) -> void:
	for i in ranch.workers.size():
		if str(ranch.workers[i].get("uid", "")) == uid:
			storage.append(ranch.workers[i])
			ranch.workers.remove_at(i)
			party_changed.emit()
			return

func can_breed() -> Dictionary:
	if ranch.workers.size() < 2:
		return {"ok": false, "msg": "Requires 2 ranch workers."}
	if ranch.cooldown > 0.0:
		return {"ok": false, "msg": "The ranch is resting (%ds)." % int(ranch.cooldown)}
	if count_item("feed") < 2:
		return {"ok": false, "msg": "Requires 2 Monster Feed."}
	var a: Dictionary = Content.SPECIES.get(ranch.workers[0].species, {})
	var b: Dictionary = Content.SPECIES.get(ranch.workers[1].species, {})
	if a.get("egg", "") != b.get("egg", ""):
		return {"ok": false, "msg": "The two monsters have different egg groups."}
	if int(ranch.workers[0].level) < 5 or int(ranch.workers[1].level) < 5:
		return {"ok": false, "msg": "Both monsters must be at least level 5."}
	return {"ok": true, "msg": ""}

func breed_ranch() -> Dictionary:
	var check := can_breed()
	if not check.ok:
		return check
	remove_item("feed", 2)
	ranch.cooldown = 180.0
	var parent_a: String = ranch.workers[0].species
	var parent_b: String = ranch.workers[1].species
	var chosen := parent_a if randf() < 0.5 else parent_b
	var base := Content.base_form(chosen)
	var variant := "shiny" if randf() < 0.1 else "normal"
	var level := 1
	var baby := Content.new_monster(base, level, variant)
	if party.size() < 6:
		party.append(baby)
		notify.emit("The egg hatched! %s joined." % Content.SPECIES[base].name, Color("#ffe08a"))
	else:
		storage.append(baby)
		notify.emit("The egg hatched! %s was sent to storage." % Content.SPECIES[base].name, Color("#ffe08a"))
	_register_codex(base)
	party_changed.emit()
	Sfx.play("capture")
	return {"ok": true, "msg": "The egg hatched into %s!" % Content.SPECIES[base].name, "species": base}

func add_worker_production_ready() -> void:
	pass

# ---------------------------------------------------------------- quests & objectives

func _progress_objectives(type: String, target: String, amount: int) -> void:
	_story_event(type, target, amount)
	if amount <= 0 or not in_game:
		return
	var changed := false
	for o in Content.OBJECTIVES:
		var rec = objectives.get(o.id, {"progress": 0, "done": false})
		if rec.get("done", false):
			continue
		if o.type != type:
			continue
		if str(o.get("target", "")) != "" and str(o.target) != target:
			continue
		var progress := int(rec.get("progress", 0))
		progress = mini(int(o.goal), progress + amount)
		rec["progress"] = progress
		objectives[o.id] = rec
		changed = true
		if progress >= int(o.goal):
			rec["done"] = true
			objectives[o.id] = rec
			add_player_xp(int(o.get("xp", 0)))
			wallet += int(o.get("amber", 0))
			notify.emit("Goal complete: %s (+%d XP)" % [o.title, int(o.get("xp", 0))], Color("#ffe08a"))
			Sfx.play("quest")
	if changed:
		objectives_changed.emit()

func set_flag(flag_id: String) -> void:
	if flags.get(flag_id, false):
		return
	flags[flag_id] = true
	_progress_objectives("flag", flag_id, 1)

func _progress_quests(kind: String, target: String, amount: int) -> void:
	_story_event(kind, target, amount)
	if quests.is_empty():
		return
	var changed := false
	for q in quests:
		if q.get("done", false) or q.get("kind", "") != kind:
			continue
		if str(q.get("target", "")) != target:
			continue
		q.progress = mini(int(q.count), int(q.get("progress", 0)) + amount)
		if int(q.progress) >= int(q.count):
			q.done = true
			notify.emit("Quest ready to turn in: %s" % q.get("title", "Quest"), Color("#ffe08a"))
		changed = true
	if changed:
		quests_changed.emit()

func accept_village_quest(village_id: String) -> Dictionary:
	var q: Dictionary
	if village_quests.has(village_id):
		q = village_quests[village_id]
		if q.get("claimed", false):
			return {}
		if q.get("accepted", false):
			return q
	else:
		q = Content.make_quest(village_id, day)
		village_quests[village_id] = q
	q["accepted"] = true
	quests.append(q)
	quests_changed.emit()
	notify.emit("Quest accepted: %s" % q.get("title", "Quest"), Color("#a9d8c8"))
	return q

func claim_quest(quest_id: String) -> bool:
	for i in quests.size():
		var q: Dictionary = quests[i]
		if str(q.get("id", "")) == quest_id:
			if not q.get("done", false):
				return false
			var xp_r := int(q.get("reward_xp", 0))
			var amber_r := int(q.get("reward_amber", 0))
			add_player_xp(xp_r)
			wallet += amber_r
			q["claimed"] = true
			q["accepted"] = false
			quests.remove_at(i)
			quests_changed.emit()
			notify.emit("Quest complete! +%d XP, +%d Amber." % [xp_r, amber_r], Color("#ffe08a"))
			Sfx.play("quest")
			return true
	return false

# ---------------------------------------------------------------- trading

func merchant_buy(index: int) -> bool:
	if index < 0 or index >= Content.MERCHANT_STOCK.size():
		return false
	var off: Dictionary = Content.MERCHANT_STOCK[index]
	if wallet < int(off.price):
		notify.emit("Not enough Amber.", Color("#ff9b8a"))
		return false
	wallet -= int(off.price)
	add_item(off.id, int(off.n))
	inventory_changed.emit()
	return true

func merchant_sell(item_id: String, n: int = 1) -> bool:
	var price := -1
	for off in Content.MERCHANT_BUY:
		if off.id == item_id:
			price = int(off.price)
			break
	if price < 0 or count_item(item_id) < n:
		return false
	remove_item(item_id, n)
	wallet += price * n
	inventory_changed.emit()
	notify.emit("Sold %d %s (+%d Amber)" % [n, Content.get_item_name(item_id), price * n], Color("#f0cf91"))
	return true

# ---------------------------------------------------------------- chests / loot

func block_key(pos: Vector3i) -> String:
	return "%d,%d,%d" % [pos.x, pos.y, pos.z]

func get_chest(key: String) -> Array:
	if chests.has(key):
		return chests[key]
	var arr: Array = []
	arr.resize(18)
	chests[key] = arr
	return arr

func set_chest(key: String, arr: Array) -> void:
	chests[key] = arr

func fill_loot_chest(key: String, tier: int = 1) -> void:
	if chests.has(key):
		return
	var arr: Array = []
	arr.resize(18)
	var pool := [
		{"id": "amber", "n": [3, 9]}, {"id": "orb", "n": [1, 2]}, {"id": "iron_ingot", "n": [1, 3]},
		{"id": "feed", "n": [1, 3]}, {"id": "crystal", "n": [1, 3]}, {"id": "seeds", "n": [2, 5]},
		{"id": "torch", "n": [3, 7]}, {"id": "potion", "n": [1, 2]}, {"id": "gold_ingot", "n": [1, 2]},
	]
	if tier >= 2:
		pool.append({"id": "orb_great", "n": [1, 2]})
		pool.append({"id": "saddle", "n": [1, 1]})
	if tier >= 3:
		pool.append({"id": "rift_key", "n": [1, 1]})
		pool.append({"id": "monster_core", "n": [1, 2]})
	var count := 2 + tier + randi_range(0, 2)
	for i in count:
		var e: Dictionary = pool[randi_range(0, pool.size() - 1)]
		var n := randi_range(int(e.n[0]), int(e.n[1]))
		var placed := false
		for j in arr.size():
			if arr[j] == null:
				arr[j] = {"id": e.id, "n": n}
				placed = true
				break
		if not placed:
			break
	chests[key] = arr

# ---------------------------------------------------------------- daily events / weather

func _roll_weather() -> void:
	weather_timer = randf_range(100.0, 220.0)
	var roll := randf()
	var new_weather := "clear"
	if roll > 0.88:
		new_weather = "storm"
	elif roll > 0.62:
		new_weather = "rain"
	if new_weather == weather:
		if randf() < 0.4:
			new_weather = "clear" if weather != "clear" else "rain"
	weather = new_weather
	weather_changed.emit(weather)
	if weather != "clear":
		notify.emit("Weather changed: %s" % ("Storm" if weather == "storm" else "Rain"), Color("#a9d8e8"))

func _daily_roll() -> void:
	weather_timer = randf_range(90.0, 200.0)
	if randf() < 0.8:
		hp = max_hp
		stamina = max_stamina
		stats_changed.emit()
		notify.emit("Day %d. Your strength is restored." % day, Color("#e8e4c8"))
	if day >= 2 and randf() < 0.32:
		_start_event()
	if ranch.workers.size() > 0:
		_ranch_daily_tick()

func _start_event() -> void:
	var options := ["golden", "horde", "migration"]
	var kind: String = options[randi_range(0, options.size() - 1)]
	event_name = kind
	event_timer = 240.0
	match kind:
		"golden":
			event_drop_mult = 2.0
			banner.emit("Golden Hour", "All monsters drop double rewards for 4 minutes.")
		"horde":
			event_drop_mult = 1.0
			banner.emit("Night Migration", "More aggressive monsters appear tonight.")
		"migration":
			event_drop_mult = 1.0
			banner.emit("Monster Migration", "Rare species roam the valley.")
	event_started.emit(kind)

func _ranch_daily_tick() -> void:
	var summary: Dictionary = {}
	for mon in ranch.workers:
		var sp: Dictionary = Content.SPECIES.get(mon.get("species", ""), {})
		var ability: String = sp.get("ability", "")
		match ability:
			"farming", "harvest": summary["wheat"] = int(summary.get("wheat", 0)) + 2
			"mining": summary["stone"] = int(summary.get("stone", 0)) + 4
			"gathering": summary["fiber"] = int(summary.get("fiber", 0)) + 4
			"glow": summary["amber"] = int(summary.get("amber", 0)) + 2
			"healing": summary["berry"] = int(summary.get("berry", 0)) + 2
			"fishing": summary["fiber"] = int(summary.get("fiber", 0)) + 2
			_: summary["fiber"] = int(summary.get("fiber", 0)) + 2
	if summary.is_empty():
		return
	for id in summary:
		add_item(id, int(summary[id]), true)
	notify.emit("Ranch workers gathered materials.", Color("#f0cf91"))

func is_night() -> bool:
	return day_time > 0.76 or day_time < 0.22

func time_string() -> String:
	var hours := int(day_time * 24.0)
	var mins := int((day_time * 24.0 - hours) * 60.0)
	return "%02d:%02d" % [hours, mins]

func drop_multiplier() -> float:
	return event_drop_mult

func discovered_village(id: String, center: Vector3) -> void:
	if discovered_villages.has(id):
		return
	discovered_villages[id] = [center.x, center.y, center.z]
	notify.emit("Village discovered!", Color("#f0cf91"))


# ---------------------------------------------------------------- story quests

func init_story() -> void:
	for q in Story.all():
		var qid := str(q.id)
		var steps: Array = []
		for st in q.steps:
			steps.append(0)
		if story.has(qid):
			var rec: Dictionary = story[qid]
			var old_steps = rec.get("steps", null)
			if not (old_steps is Array) or (old_steps as Array).size() != (q.steps as Array).size():
				rec["steps"] = steps
				story[qid] = rec
			continue
		story[qid] = {"steps": steps, "done": false, "claimed": false}
	story_changed.emit()

func story_unlocked(q: Dictionary) -> bool:
	if str(q.kind) == "side":
		return true
	var mains: Array = Story.of_kind("main")
	for i in mains.size():
		if str(mains[i].id) != str(q.id):
			continue
		if i == 0:
			return true
		var prev: Dictionary = story.get(str(mains[i - 1].id), {})
		return bool(prev.get("done", false)) or bool(prev.get("claimed", false))
	return false

func story_ready(q: Dictionary, rec: Dictionary) -> bool:
	var prog: Array = rec.get("steps", [])
	var steps: Array = q.steps
	if prog.size() != steps.size():
		return false
	for i in steps.size():
		if int(prog[i]) < int(steps[i].goal):
			return false
	return true

func _story_event(type: String, target: String, amount: int) -> void:
	if not in_game or amount <= 0:
		return
	if story.is_empty():
		init_story()
	var changed := false
	for q in Story.all():
		var qid := str(q.id)
		if not story.has(qid):
			continue
		var rec: Dictionary = story[qid]
		if bool(rec.get("done", false)) or not story_unlocked(q):
			continue
		var steps: Array = q.steps
		var prog: Array = rec.get("steps", [])
		if prog.size() != steps.size():
			prog = []
			for st in steps:
				prog.append(0)
		var touched := false
		for i in steps.size():
			var st: Dictionary = steps[i]
			if str(st.type) != type:
				continue
			var want := str(st.get("target", ""))
			if want != "" and want != target:
				continue
			if int(prog[i]) >= int(st.goal):
				continue
			prog[i] = mini(int(st.goal), int(prog[i]) + amount)
			touched = true
		if not touched:
			continue
		rec["steps"] = prog
		story[qid] = rec
		changed = true
		if story_ready(q, rec):
			rec["done"] = true
			story[qid] = rec
			notify.emit("Quest complete: %s" % str(q.title), Color("#ffe08a"))
			banner.emit("QUEST COMPLETE", str(q.title))
			Sfx.play("quest")
	if changed:
		story_changed.emit()

func claim_story(qid: String) -> bool:
	var q := Story.by_id(qid)
	if q.is_empty():
		return false
	var rec: Dictionary = story.get(qid, {})
	if not bool(rec.get("done", false)) or bool(rec.get("claimed", false)):
		return false
	var rw: Dictionary = q.reward
	add_player_xp(int(rw.get("xp", 0)))
	wallet += int(rw.get("amber", 0))
	var item := str(rw.get("item", ""))
	if item != "":
		add_item(item, int(rw.get("n", 1)))
	rec["claimed"] = true
	story[qid] = rec
	story_changed.emit()
	notify.emit("Reward claimed: %s (+%d XP, +%d Amber)" % [str(q.title), int(rw.get("xp", 0)), int(rw.get("amber", 0))], Color("#ffe08a"))
	Sfx.play("quest")
	return true

func active_story_quests() -> Array:
	var out: Array = []
	for q in Story.all():
		var qid := str(q.id)
		var rec: Dictionary = story.get(qid, {})
		if rec.is_empty() or bool(rec.get("claimed", false)):
			continue
		if not story_unlocked(q):
			continue
		out.append({"q": q, "rec": rec})
	out.sort_custom(func(a, b):
		var am := 0 if str(a.q.kind) == "main" else 1
		var bm := 0 if str(b.q.kind) == "main" else 1
		if am != bm:
			return am < bm
		return str(a.q.id) < str(b.q.id))
	return out

func tracked_story_quest() -> Dictionary:
	var tq := Story.by_id(tracked_quest)
	if not tq.is_empty():
		return tq
	for e in active_story_quests():
		if str(e.q.kind) == "main" and not bool(e.rec.get("done", false)):
			return e.q
	for e in active_story_quests():
		return e.q
	return {}

func story_step_text(q: Dictionary, rec: Dictionary) -> String:
	var prog: Array = rec.get("steps", [])
	for i in q.steps.size():
		var st: Dictionary = q.steps[i]
		var p := int(prog[i]) if i < prog.size() else 0
		if p >= int(st.goal):
			continue
		return "%s  (%d/%d)" % [str(st.text), p, int(st.goal)]
	if bool(rec.get("done", false)):
		return "Complete - claim your reward"
	return "In progress"
