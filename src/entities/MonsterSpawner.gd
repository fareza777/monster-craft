class_name MonsterSpawner
extends Node

var world: VoxelWorld
var main: Node
var player: Node3D
var wild: Array[MonsterEntity] = []
var companion: MonsterEntity
var active_bosses: Dictionary = {}
var rift_enemies: Array = []
var spawn_timer := 3.0
var ability_timer := 32.0
var companion_check := 0.0
var active_boss_entity: MonsterEntity
var rift_active := false
var rift_wave := 0
var rift_center := Vector3.ZERO
var rift_state := "idle"
var rift_spawn_timer := 0.0
var rift_rate := 0.0
var companion_uid := ""
var companion_species := ""
var companion_glow: OmniLight3D

func setup(p_world: VoxelWorld, p_main: Node) -> void:
	world = p_world
	main = p_main

func set_player(p: Node3D) -> void:
	player = p

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	spawn_timer -= delta
	companion_check -= delta
	ability_timer -= delta
	if companion_check <= 0.0:
		companion_check = 0.5
		_refresh_companion()
	if spawn_timer <= 0.0:
		spawn_timer = 2.6
		_cleanup_wild()
		if not rift_active:
			var cap := 10
			if Game.is_night():
				cap += 4
			if Game.event_name == "horde" and Game.is_night():
				cap += 5
			if wild.size() < cap:
				_spawn_wild_near_player()
	if ability_timer <= 0.0:
		ability_timer = 36.0
		_apply_companion_ability()
	_update_rift(delta)

func _cleanup_wild() -> void:
	for i in range(wild.size() - 1, -1, -1):
		var m := wild[i]
		if m == null or not is_instance_valid(m):
			wild.remove_at(i)
			continue
		if m.dead:
			continue
		if m.is_boss:
			continue
		var d := m.global_position.distance_to(player.global_position)
		if d > 78.0 or m.global_position.y < -5.0:
			m.queue_free()
			wild.remove_at(i)

func _spawn_wild_near_player() -> void:
	var angle := randf() * TAU
	var dist := randf_range(15.0, 38.0)
	var x := floori(player.global_position.x + cos(angle) * dist)
	var z := floori(player.global_position.z + sin(angle) * dist)
	var spawn_pos := world.get_loaded_monster_spawn(x, z)
	if spawn_pos == Vector3.ZERO:
		return
	var biome := world.gen.biome_at(x, z)
	var species_id := Content.random_species_for_biome(biome, Game.is_night(), Game.weather)
	if species_id == "":
		return
	if Game.event_name == "migration" and randf() < 0.35:
		var pool := Content.species_for_biome(biome, Game.is_night(), Game.weather)
		if not pool.is_empty():
			species_id = str(pool[randi_range(0, pool.size() - 1)].id)
	var level := clampi(1 + int(Vector2(x - Game.spawn_point.x, z - Game.spawn_point.z).length() / 55.0) + int(Game.day / 2) + randi_range(-1, 1), 1, 32)
	var variant := "shiny" if randf() < 0.055 else "normal"
	var rare_pool: Array = Content.rare_species()
	if not rare_pool.is_empty() and randf() < 0.055:
		species_id = str(rare_pool[randi_range(0, rare_pool.size() - 1)])
		variant = "shiny"
	spawn_wild(species_id, level, variant, spawn_pos)

func spawn_wild(species_id: String, level: int, variant: String, pos: Vector3, boss: bool = false) -> MonsterEntity:
	var sp: Dictionary = Content.SPECIES.get(species_id, {})
	if sp.is_empty():
		return null
	var hover := str(sp.get("shape", "quad")) in ["floater", "serpent"]
	var m := MonsterEntity.new()
	m.position = pos + Vector3(0, 1.2 if hover else 0.1, 0)
	world.add_child(m)
	m.setup(species_id, level, variant, false, -1, boss, world, main, self)
	m.set_base_altitude_from_ground()
	wild.append(m)
	m.died.connect(_on_wild_died)
	if boss:
		main.show_boss_bar(m)
	return m

func _on_wild_died(monster: MonsterEntity) -> void:
	if monster in rift_enemies:
		rift_enemies.erase(monster)
	var was_boss := active_boss_entity == monster or monster.is_boss
	if active_boss_entity == monster:
		active_boss_entity = null
	for key in active_bosses.keys():
		if active_bosses[key] == monster:
			active_bosses.erase(key)
	if was_boss:
		main.hide_boss_bar()
	for i in range(wild.size() - 1, -1, -1):
		if wild[i] == monster:
			wild.remove_at(i)
			break

func get_capture_target(from_pos: Vector3, forward: Vector3, max_dist: float = 9.5) -> MonsterEntity:
	var best: MonsterEntity = null
	var best_d := 999.0
	for m in wild:
		if m == null or not is_instance_valid(m) or m.dead or m.is_companion:
			continue
		var to := m.global_position - from_pos
		var d := to.length()
		if d > max_dist or d < 0.1:
			continue
		if forward.dot(to.normalized()) < 0.55:
			continue
		if d < best_d:
			best_d = d
			best = m
	return best

func get_melee_target(from_pos: Vector3, forward: Vector3, max_dist: float = 3.4) -> MonsterEntity:
	var best: MonsterEntity = null
	var best_d := 999.0
	for m in wild:
		if m == null or not is_instance_valid(m) or m.dead:
			continue
		var to := m.global_position + Vector3(0, 0.4, 0) - from_pos
		var d := to.length()
		if d > max_dist + float(m.sp.get("scale", 1.0)) * 0.4:
			continue
		if forward.dot(to.normalized()) < 0.25:
			continue
		if d < best_d:
			best_d = d
			best = m
	return best

func get_nearest_enemy_for(mon: MonsterEntity, radius: float) -> MonsterEntity:
	var best: MonsterEntity = null
	var best_d := radius
	for m in wild:
		if m == null or not is_instance_valid(m) or m.dead:
			continue
		var d := mon.global_position.distance_to(m.global_position)
		if d < best_d:
			best_d = d
			best = m
	return best

func get_enemies_in_radius(pos: Vector3, radius: float) -> Array:
	var out: Array = []
	for m in wild:
		if m != null and is_instance_valid(m) and not m.dead and m.global_position.distance_to(pos) <= radius:
			out.append(m)
	return out

func _refresh_companion() -> void:
	var mon_data := Game.active_monster()
	if mon_data.is_empty() or int(mon_data.get("hp", 0)) <= 0:
		if companion != null and is_instance_valid(companion):
			companion.queue_free()
		companion = null
		companion_uid = ""
		companion_species = ""
		if player != null:
			player.companion_guard = false
			player.speed_multiplier = 1.0
			player.can_glide = false
		return
	var uid := str(mon_data.get("uid", ""))
	var species := str(mon_data.get("species", ""))
	if companion != null and is_instance_valid(companion) and companion_uid == uid and companion_species == species:
		if int(mon_data.get("hp", 0)) > companion.hp:
			companion.hp = int(mon_data.get("hp", companion.max_hp))
			companion._update_labels()
		return
	if companion != null and is_instance_valid(companion):
		if player.riding_monster == companion:
			player.stop_riding()
		companion.queue_free()
	companion = null
	companion_uid = uid
	companion_species = species
	var sprite: Dictionary = Content.SPECIES.get(species, {})
	if sprite.is_empty():
		return
	var hover := str(sprite.get("shape", "quad")) in ["floater", "serpent"]
	companion = MonsterEntity.new()
	var yaw := player.rotation.y
	var behind := -Vector3(-sin(yaw), 0, -cos(yaw)) * 2.9 + Vector3(cos(yaw), 0, -sin(yaw)) * 1.1
	companion.position = player.global_position + behind + Vector3(0, 1.4 if hover else 0.2, 0)
	world.add_child(companion)
	companion.setup(species, int(mon_data.get("level", 1)), str(mon_data.get("variant", "normal")),
		true, Game.active_index, false, world, main, self)
	companion.set_base_altitude_from_ground()
	_apply_ability_flags(str(sprite.get("ability", "")))
	if companion_glow != null and is_instance_valid(companion_glow):
		companion_glow.queue_free()
		companion_glow = null
	if str(sprite.get("ability", "")) == "glow":
		companion_glow = OmniLight3D.new()
		companion_glow.light_color = Content.element_color(str(sprite.get("element", "Light")))
		companion_glow.light_energy = 0.8
		companion_glow.omni_range = 7.0
		companion_glow.position = Vector3(0, 1.2, 0)
		companion.add_child(companion_glow)

func _apply_ability_flags(ability: String) -> void:
	if player == null:
		return
	player.companion_guard = ability == "guard"
	player.speed_multiplier = 1.12 if ability == "speed" else 1.0
	player.can_glide = ability == "glide"

func _apply_companion_ability() -> void:
	if companion == null or not is_instance_valid(companion) or companion.dead:
		return
	var sprite: Dictionary = Content.SPECIES.get(companion.species_id, {})
	var ability := str(sprite.get("ability", ""))
	var gained := ""
	match ability:
		"farming":
			Game.add_item("wheat", 1, true)
			if randf() < 0.4:
				Game.add_item("seeds", 1, true)
			gained = "wheat"
		"mining":
			Game.add_item("stone", 2, true)
			if randf() < 0.2:
				Game.add_item("coal", 1, true)
			gained = "stone"
		"gathering":
			Game.add_item("fiber", 2, true)
			if randf() < 0.25:
				Game.add_item("amber", 1, true)
			gained = "fiber"
		"harvest":
			Game.add_item("wheat", 1, true)
			if randf() < 0.3:
				Game.add_item("mush_cap", 1, true)
			gained = "crops"
		"fishing":
			if randf() < 0.4:
				Game.add_item("crystal", 1, true)
				gained = "crystal"
			else:
				Game.add_item("fiber", 1, true)
				gained = "fiber"
		"healing":
			if Game.hp < Game.max_hp:
				Game.heal_player(6)
				gained = "penyembuhan"
		"smelting":
			if randf() < 0.3:
				Game.add_item("iron_ingot", 1, true)
				gained = "iron ingot"
		"glow", "guard", "speed", "glide", "hauler", "spore":
			pass
		_:
			Game.add_item("fiber", 1, true)
			gained = "fiber"
	if gained != "" and gained != "penyembuhan":
		Game.notify.emit("%s found %s." % [companion.display_name, gained], Color("#c8e6c0"))

func use_skill() -> void:
	if companion == null or not is_instance_valid(companion) or companion.dead or companion.skill_cd > 0.0:
		Game.notify.emit("Partner skill is not ready.", Color("#cdc9b4"))
		return
	companion.use_skill()

func mount_active() -> void:
	var mon := Game.active_monster()
	if mon.is_empty():
		Game.notify.emit("No active partner.", Color("#ff9b8a"))
		return
	var sprite: Dictionary = Content.SPECIES.get(mon.species, {})
	if not bool(sprite.get("rideable", false)):
		Game.notify.emit("This monster cannot be ridden yet.", Color("#ff9b8a"))
		return
	if Game.count_item("saddle") < 1:
		Game.notify.emit("You need a Saddle to ride this monster.", Color("#ff9b8a"))
		return
	if companion == null or not is_instance_valid(companion):
		Game.notify.emit("Your partner is not nearby.", Color("#ff9b8a"))
		return
	if player.riding_monster != null:
		dismount()
		return
	player.set_riding(companion)
	companion.set_ridden(true)
	Game.notify.emit("Riding %s." % companion.display_name, Color("#a9d8c8"))

func dismount() -> void:
	if player.riding_monster != null:
		player.stop_riding()
	if companion != null and is_instance_valid(companion):
		companion.set_ridden(false)
		var yaw := player.rotation.y
		var behind := -Vector3(-sin(yaw), 0, -cos(yaw)) * 2.9 + Vector3(cos(yaw), 0, -sin(yaw)) * 1.1
		companion.global_position = player.global_position + behind + Vector3(0, 0.2, 0)
		companion.set_base_altitude_from_ground()

func spawn_boss(info: Dictionary) -> MonsterEntity:
	if info.is_empty():
		return null
	var id := str(info.get("id", "dungeon"))
	if active_bosses.has(id) and is_instance_valid(active_bosses[id]):
		return active_bosses[id]
	var room: Vector3i = info.room_center
	var species_id := str(info.get("boss", "warden_stone"))
	var level := clampi(16 + Game.day / 2, 16, 30)
	var boss := spawn_wild(species_id, level, "normal",
		Vector3(room.x + 0.5, room.y + 0.1, room.z + 1.5), true)
	if boss == null:
		return null
	active_bosses[id] = boss
	active_boss_entity = boss
	Game.notify.emit("Dungeon boss awakened!", Color("#f0a0a0"))
	Game.banner.emit(str(Content.SPECIES[species_id].name), "The guardian of %s has risen." % str(info.get("name", "dungeon")))
	Sfx.play("roar", 0.05)
	return boss

func boss_alive_for(info: Dictionary) -> bool:
	var id := str(info.get("id", ""))
	return active_bosses.has(id) and is_instance_valid(active_bosses[id]) and not active_bosses[id].dead

func start_rift() -> void:
	if rift_active:
		Game.notify.emit("The Rift is still open.", Color("#ff9b8a"))
		return
	if Game.count_item("rift_key") < 1:
		Game.notify.emit("You need a Rift Key to open the World Rift.", Color("#ff9b8a"))
		return
	Game.remove_item("rift_key", 1)
	rift_active = true
	rift_wave = 1
	rift_center = player.global_position
	rift_state = "spawning"
	rift_spawn_timer = 2.0
	rift_enemies.clear()
	Game.banner.emit("WORLD RIFT", "Wave 1 of 5. Hold your ground!")
	Game.notify.emit("The Rift opens! Wave 1.", Color("#d9a6ff"))
	Sfx.play("rift", 0.03)
	main.on_rift_state(1, 0)

func _spawn_rift_wave() -> void:
	rift_enemies.clear()
	var count := 2 + rift_wave
	var candidates: Array = []
	for id in Content.SPECIES:
		var sp: Dictionary = Content.SPECIES[id]
		if not sp.get("boss", false) and sp.get("wild", true):
			candidates.append(id)
	for i in count:
		var a := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var r := randf_range(5.0, 9.0)
		var x := floori(rift_center.x + cos(a) * r)
		var z := floori(rift_center.z + sin(a) * r)
		var pos := world.get_loaded_monster_spawn(x, z)
		if pos == Vector3.ZERO:
			continue
		var sid: String = candidates[randi_range(0, candidates.size() - 1)]
		var level := clampi(12 + rift_wave * 2 + Game.level, 12, 45)
		var m := spawn_wild(sid, level, "normal", pos)
		if m != null:
			rift_enemies.append(m)
	if rift_wave >= 5:
		var room := player.global_position
		var boss_pos := world.get_loaded_monster_spawn(floori(room.x + 4), floori(room.z + 4))
		if boss_pos != Vector3.ZERO:
			var boss := spawn_wild("riftmaw", 24 + Game.level, "normal", boss_pos, true)
			if boss != null:
				rift_enemies.append(boss)
				active_boss_entity = boss
	rift_state = "fighting"
	main.on_rift_state(rift_wave, rift_enemies.size())

func _update_rift(delta: float) -> void:
	if not rift_active:
		return
	if player.global_position.distance_to(rift_center) > 42.0:
		_cancel_rift()
		return
	if rift_state == "spawning":
		rift_spawn_timer -= delta
		if rift_spawn_timer <= 0.0:
			_spawn_rift_wave()
	elif rift_state == "fighting":
		rift_rate -= delta
		if rift_rate <= 0.0:
			rift_rate = 0.8
			rift_enemies = rift_enemies.filter(func(m): return m != null and is_instance_valid(m) and not m.dead)
			main.on_rift_state(rift_wave, rift_enemies.size())
			if rift_enemies.is_empty():
				_on_rift_wave_cleared()
	elif rift_state == "cleared":
		rift_spawn_timer -= delta
		if rift_spawn_timer <= 0.0:
			rift_wave += 1
			rift_state = "spawning"
			rift_spawn_timer = 1.6
			Game.notify.emit("Wave %d/5!" % rift_wave, Color("#d9a6ff"))
			main.on_rift_state(rift_wave, 0)

func _on_rift_wave_cleared() -> void:
	Game.add_rift_wave()
	if rift_wave >= 5:
		_finish_rift()
		return
	rift_state = "cleared"
	rift_spawn_timer = 3.0
	Game.notify.emit("Wave %d cleared!" % rift_wave, Color("#a9e5a0"))
	Sfx.play("quest")
	Game.add_player_xp(35)
	Game.wallet += 20

func _finish_rift() -> void:
	rift_active = false
	rift_state = "idle"
	rift_enemies.clear()
	Game.add_item("crystal", 8, true)
	Game.add_item("monster_core", 3, true)
	Game.wallet += 150
	Game.add_player_xp(400)
	Game.banner.emit("RIFT CLOSED", "You cleared five waves. Great rewards await.")
	Game.notify.emit("Rift closed! +8 Crystal, +3 Monster Core, +150 Amber.", Color("#ffe08a"))
	Sfx.play("victory")
	main.on_rift_state(0, 0)
	main.hide_boss_bar()

func _cancel_rift() -> void:
	rift_active = false
	rift_state = "idle"
	for m in rift_enemies:
		if m != null and is_instance_valid(m):
			m.queue_free()
	rift_enemies.clear()
	Game.notify.emit("You left the Rift. Challenge failed.", Color("#ff9b8a"))
	main.on_rift_state(0, 0)
	main.hide_boss_bar()

func get_companion() -> MonsterEntity:
	if companion != null and is_instance_valid(companion):
		return companion
	return null
