extends Node

var world: VoxelWorld
var player: CraftPlayer
var spawner: MonsterSpawner
var ui: UIRoot
var ui_layer: CanvasLayer
var loading_layer: CanvasLayer
var loading_bar: ProgressBar
var loading_status: Label
var loading_tips: Label
var menu_layer: CanvasLayer
var menu: MainMenu
var menu_backdrop: MenuBackdrop
var dialog_layer: CanvasLayer
var tracked_waypoint := Vector3.ZERO
var quest_beacons: Dictionary = {}
var _quest_marker_timer := 0.0
var village_spawns: Dictionary = {}
var npc_list: Array = []
var _village_timer := 1.0
var boss_entity: MonsterEntity
var _startup_args: PackedStringArray
var _shot_timer := -1.0
var _auto_starter := false
var _skip_starter := false
var _showcase := false
var _ui_test := false
var _panel_arg := ""
var _goto_arg := ""
var _autoload_slot := 0
var _time_arg := -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_startup_args = OS.get_cmdline_user_args()
	for a in _startup_args:
		if a == "--skip-starter":
			_skip_starter = true
		elif a.begins_with("--shot="):
			_shot_timer = float(a.split("=")[1])
		elif a == "--showcase":
			_showcase = true
		elif a == "--ui-test":
			_ui_test = true
			_skip_starter = true
		elif a.begins_with("--panel="):
			_panel_arg = a.split("=")[1]
		elif a.begins_with("--goto="):
			_goto_arg = a.split("=")[1]
		elif a.begins_with("--load-slot="):
			_autoload_slot = int(a.split("=")[1])
			_skip_starter = true
		elif a.begins_with("--time="):
			_time_arg = float(a.split("=")[1])
	Game.load_settings()
	var autostart := _skip_starter or _showcase or _ui_test or _panel_arg != "" or _goto_arg != ""
	for a in _startup_args:
		if a == "--autostart":
			autostart = true
	if autostart:
		if _autoload_slot > 0:
			_on_menu_load_world(_autoload_slot)
		else:
			_start_new_world(1, 828281)
	else:
		_show_menu()

func _process(delta: float) -> void:

	_quest_marker_timer -= delta
	if _quest_marker_timer <= 0.0:
		_quest_marker_timer = 0.6
		_update_quest_markers()
	if Game.in_game and player != null and not get_tree().paused:
		_village_timer -= delta
		if _village_timer <= 0.0:
			_village_timer = 2.5
			_update_villages()
	if _shot_timer > 0.0:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_take_screenshot()
	if loading_layer != null and loading_layer.visible and world != null:
		loading_bar.value = world.get_initial_progress() * 100.0
		loading_status.text = "Shaping the world... %d%%" % int(world.get_initial_progress() * 100.0)

func _take_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/boot.png")
	print("[MonsterCraft] shot saved FPS=", Engine.get_frames_per_second())
	if world != null:
		world.shutdown()
	await get_tree().process_frame
	get_tree().quit()

# ------------------------------------------------------------------ world lifecycle

func _build_loading() -> void:
	UITheme.font_boost = 1.32 if is_touch() else 1.0
	loading_layer = CanvasLayer.new()
	loading_layer.layer = 20
	add_child(loading_layer)
	var bg := ColorRect.new()
	bg.color = Color("#071719")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_layer.add_child(bg)
	var glow := ColorRect.new()
	glow.color = Color(0.15, 0.4, 0.32, 0.12)
	glow.anchor_left = 0.5
	glow.anchor_right = 0.5
	glow.offset_left = -380
	glow.offset_right = 380
	glow.offset_top = 80
	glow.offset_bottom = 640
	loading_layer.add_child(glow)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_layer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(500, 0)
	center.add_child(v)
	var title := Label.new()
	title.text = "MONSTERCRAFT"
	title.add_theme_font_override("font", UITheme.title_font())
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#f3f0df"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Label.new()
	sub.text = "V O X E L   A D V E N T U R E"
	sub.add_theme_font_override("font", UITheme.body_font())
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", UITheme.AMBER)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	v.add_child(spacer)
	loading_bar = UITheme.make_bar(v, 480, 10, UITheme.AMBER)
	loading_status = Label.new()
	loading_status.text = "Preparing world..."
	loading_status.add_theme_font_override("font", UITheme.body_font())
	loading_status.add_theme_font_size_override("font_size", 14)
	loading_status.add_theme_color_override("font_color", UITheme.MUTED)
	loading_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(loading_status)
	loading_tips = Label.new()
	loading_tips.add_theme_font_override("font", UITheme.body_font())
	loading_tips.add_theme_font_size_override("font_size", 13)
	loading_tips.add_theme_color_override("font_color", Color(0.7, 0.78, 0.7, 0.7))
	loading_tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_tips.text = "Tip: passive monsters are easier to tame with Feed.\nBuild a Ranch Banner for breeding and automated workers."
	v.add_child(loading_tips)

func _show_menu() -> void:
	_clear_menu()
	menu_backdrop = MenuBackdrop.new()
	menu_backdrop.name = "MenuBackdrop"
	add_child(menu_backdrop)
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	menu = MainMenu.new()
	menu_layer.add_child(menu)
	menu.setup(self)
	menu.new_world_requested.connect(_on_menu_new_world)
	menu.load_world_requested.connect(_on_menu_load_world)
	menu.quit_requested.connect(_on_menu_quit)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.start_music()

func _clear_menu() -> void:
	if menu_layer != null:
		menu_layer.queue_free()
		menu_layer = null
		menu = null
	if menu_backdrop != null:
		menu_backdrop.queue_free()
		menu_backdrop = null

func _on_menu_new_world(slot: int, world_seed: int) -> void:
	_clear_menu()
	Game.begin_new_world(slot, world_seed)
	_launch_world(false)

func _on_menu_load_world(slot: int) -> void:
	if not Game.load_game(slot):
		Game.notify.emit("Failed to load the save.", Color("#ff9b8a"))
		return
	_clear_menu()
	_launch_world(true)

func _on_menu_quit() -> void:
	get_tree().quit()

func _launch_world(loaded: bool) -> void:
	if loading_layer != null:
		loading_layer.queue_free()
		loading_layer = null
	_build_loading()
	world = VoxelWorld.new()
	world.name = "VoxelWorld"
	add_child(world)
	world.initial_ready.connect(_on_world_ready, CONNECT_ONE_SHOT)
	world.setup(Game.seed_value, Game.pending_world_data if loaded else {}, Vector3.ZERO)
	Game.spawn_point = world.spawn_point
	Game.attach_world(world)
	world.view_distance = Game.view_distance

func _start_new_world(slot: int, world_seed: int) -> void:
	Game.begin_new_world(slot, world_seed)
	_launch_world(false)

func _on_world_ready() -> void:
	player = CraftPlayer.new()
	player.name = "Player"
	world.add_child(player)
	player.world = world
	player.main = self
	var state: Dictionary = world.saved_player_state
	if state.is_empty():
		player.global_position = world.spawn_point + Vector3(0, 0.4, 0)
		player.yaw = 0.85
		player.pitch = -0.14
	else:
		player.apply_save_state(state)
	player.rotation.y = player.yaw
	player.camera.rotation.x = player.pitch
	if _time_arg >= 0.0:
		Game.day_time = fmod(_time_arg, 24.0) / 24.0
	world.set_player(player)
	spawner = MonsterSpawner.new()
	spawner.name = "MonsterSpawner"
	world.add_child(spawner)
	spawner.setup(world, self)
	spawner.set_player(player)
	world.player = player
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)
	ui = UIRoot.new()
	ui_layer.add_child(ui)
	ui.setup(player, world, self, spawner)
	if not is_touch():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if loading_layer != null:
		loading_layer.queue_free()
		loading_layer = null
	Sfx.start_music()
	if Game.pending_starter or Game.party.is_empty():
		Game.pending_starter = true
		if _skip_starter:
			Game.choose_starter("spriggle")
			spawner._refresh_companion()
			player.input_enabled = true
			Game.save_game(Game.current_slot, true)
		else:
			ui.call_deferred("show_starter_choice")
	else:
		spawner._refresh_companion()
	Game.notify.emit("Welcome to %s." % Game._world_name(), UITheme.INK)
	if _goto_arg != "":
		_goto_debug()
	if _showcase:
		_showcase_spawns()
	if _ui_test:
		_ui_smoke_test()
	elif _panel_arg != "":
		_open_named_panel()
	if _shot_timer < 0.0:
		print("[MonsterCraft] World ready. seed=", Game.seed_value)

func _open_named_panel() -> void:
	await get_tree().create_timer(0.4).timeout
	match _panel_arg:
		"starter": ui.show_starter_choice()
		"ranch": ui.open_ranch()
		"inventory": ui.open_inventory()
		"crafting": ui.open_crafting()
		"party": ui.open_party()
		"codex": ui.open_codex()
		"quests": ui.open_quests()
		"map": ui.open_map()
		"pause": ui.open_pause()
		"settings": ui.open_settings()

func _ui_smoke_test() -> void:
	await get_tree().create_timer(0.6).timeout
	var methods := ["open_inventory", "open_crafting", "open_party", "open_codex", "open_quests", "open_map", "open_pause", "open_settings", "open_guide"]
	for m in methods:
		ui.call(m)
		await get_tree().process_frame
		await get_tree().process_frame
		if ui.modal_open:
			ui._close_modal()
		await get_tree().process_frame
	ui.party_tab = "Storage"
	ui.open_party()
	await get_tree().process_frame
	ui._close_modal()
	ui.party_tab = "Ranch"
	ui.open_party()
	await get_tree().process_frame
	ui._close_modal()
	ui.open_chest("0,0,0", 0)
	await get_tree().process_frame
	ui._close_modal()
	var npc := {"name": "Jaka", "role": "elder", "village_id": "test_village", "village_name": "Test Village"}
	ui.open_npc(npc)
	await get_tree().process_frame
	ui.open_shop(npc)
	await get_tree().process_frame
	ui._close_modal()
	print("[MonsterCraft] UI TEST DONE")
	await get_tree().process_frame
	if world != null:
		world.shutdown()
	await get_tree().process_frame
	get_tree().quit()

func _goto_debug() -> void:
	await get_tree().create_timer(0.6).timeout
	match _goto_arg:
		"village": _teleport_nearest_village()
		"dungeon": _teleport_nearest_dungeon(false)
		"bossroom": _teleport_nearest_dungeon(true)

func _update_villages() -> void:
	if world == null or player == null:
		return
	npc_list.clear()
	var infos := world.get_nearby_villages(player.global_position)
	for info in infos:
		var center: Vector3i = info.center
		var dist := player.global_position.distance_to(Vector3(center))
		if dist > 130.0:
			continue
		if dist < 55.0 and not Game.discovered_villages.has(str(info.id)):
			Game.discovered_village(str(info.id), Vector3(center))
			Game._story_event("village", str(info.id), 1)
			Game.banner.emit("Village Discovered", str(info.get("name", "Village")))
		var vid := str(info.id)
		if village_spawns.has(vid):
			var nodes: Array = village_spawns[vid]
			var alive := false
			for n in nodes:
				if n != null and is_instance_valid(n):
					alive = true
					npc_list.append(n)
			if not alive:
				village_spawns.erase(vid)
			continue
		if dist > 72.0:
			continue
		_spawn_village_npcs(info)
	for vid in village_spawns.keys():
		var nodes2: Array = village_spawns[vid]
		var keep: Array = []
		for n in nodes2:
			if n == null or not is_instance_valid(n):
				continue
			if n.global_position.distance_to(player.global_position) > 120.0:
				n.queue_free()
			else:
				keep.append(n)
				npc_list.append(n)
		if keep.is_empty():
			village_spawns.erase(vid)
		else:
			village_spawns[vid] = keep

func _spawn_village_npcs(info: Dictionary) -> void:
	var vid := str(info.id)
	var points: Array = info.npc_points
	var plateau: int = int(info.center.y)
	var nodes: Array = []
	var count := mini(points.size(), 4)
	for i in count:
		var pt: Vector2i = points[i]
		var role := "elder" if i == 0 else ("merchant" if i == 1 else ("farmer" if i == 2 else "villager"))
		var name_index := absi(hash(str(vid) + str(i))) % Content.NPC_NAMES.size()
		var npc := Villager.new()
		npc.position = Vector3(pt.x + 0.5, plateau + 1.2, pt.y + 0.5)
		world.add_child(npc)
		npc.player = player
		npc.setup({"id": vid + "_" + str(i), "name": Content.NPC_NAMES[name_index],
			"role": role, "village_id": vid, "village_name": str(info.get("name", "Village"))})
		nodes.append(npc)
	village_spawns[vid] = nodes

func _find_npc_near(from_pos: Vector3, forward: Vector3) -> Villager:
	var best: Villager = null
	var best_d := 5.2
	for n in npc_list:
		if n == null or not is_instance_valid(n):
			continue
		var to: Vector3 = n.global_position - from_pos
		var d: float = to.length()
		if d > 5.2 or forward.dot(to.normalized()) < 0.25:
			continue
		if d < best_d:
			best_d = d
			best = n
	return best

func _teleport_nearest_village() -> void:
	if world == null or player == null:
		return
	var info := world.get_nearest_village(player.global_position)
	if info.is_empty():
		Game.notify.emit("No village nearby.", UITheme.MUTED)
		return
	var c: Vector3i = info.center
	world.force_load_area(Vector3(c), 2)
	player.global_position = Vector3(c.x + 0.5, c.y + 1.5, c.z + 3.5)
	Game.notify.emit("Teleported to village %s (debug)." % info.get("name", ""), UITheme.AMBER)

func _teleport_nearest_dungeon(room: bool = false) -> void:
	if world == null or player == null:
		return
	var info := world.get_nearest_dungeon(player.global_position)
	if info.is_empty():
		Game.notify.emit("No dungeon nearby.", UITheme.MUTED)
		return
	if room:
		var r: Vector3i = info.room_center
		world.force_load_area(Vector3(r), 2)
		player.global_position = Vector3(r.x + 0.5, r.y + 1.2, r.z + 3.5)
		Game.notify.emit("Teleported to the boss room of %s (debug)." % info.get("name", ""), UITheme.AMBER)
	else:
		var e: Vector3i = info.entrance
		world.force_load_area(Vector3(e), 1)
		player.global_position = Vector3(e.x + 0.5, e.y + 1.5, e.z + 2.5)
		Game.notify.emit("Teleported to the dungeon entrance %s (debug)." % info.get("name", ""), UITheme.AMBER)

func _unhandled_input(event: InputEvent) -> void:
	if not Game.in_game or player == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F7:
				_teleport_nearest_village()
				get_viewport().set_input_as_handled()
			KEY_F8:
				_teleport_nearest_dungeon(false)
				get_viewport().set_input_as_handled()
			KEY_F9:
				_teleport_nearest_dungeon(true)
				get_viewport().set_input_as_handled()

func _showcase_spawns() -> void:
	await get_tree().create_timer(1.2).timeout
	if spawner == null or player == null:
		return
	var fwd := -player.camera.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0, fwd.x)
	var specs := [["spriggle", 5, -1.7], ["brezel_placeholder", 1, 0], ["frostbun", 4, 1.8]]
	var comp := spawner.get_companion()
	if comp != null:
		comp.ai_enabled = false
		comp.global_position = player.global_position + right * 2.2 + Vector3(0, 0.2, 0)
	for spec in [["spriggle", 5, -1.7], ["pebbit", 6, 0.2], ["frostbun", 4, 1.8]]:
		var p: Vector3 = player.global_position + fwd * 4.5 + right * float(spec[2])
		var pos := world.get_loaded_monster_spawn(floori(p.x), floori(p.z))
		if pos != Vector3.ZERO:
			var mon := spawner.spawn_wild(str(spec[0]), int(spec[1]), "normal", pos)
			if mon != null:
				mon.ai_enabled = false
				mon.aggro = false
				mon.rotation.y = atan2(-(player.global_position.x - mon.global_position.x), -(player.global_position.z - mon.global_position.z))

func is_touch() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

# ------------------------------------------------------------------ combat bridge

func get_melee_target(origin: Vector3, forward: Vector3, max_dist: float = 3.4) -> MonsterEntity:
	if spawner == null:
		return null
	return spawner.get_melee_target(origin, forward, max_dist)

func get_target_monster() -> MonsterEntity:
	if spawner == null or player == null:
		return null
	var cam := player.camera
	var forward := -cam.global_transform.basis.z
	var best: MonsterEntity = null
	var best_d := 13.0
	for m in spawner.wild:
		if m == null or not is_instance_valid(m) or m.dead:
			continue
		var to := m.global_position + Vector3(0, 0.5, 0) - cam.global_position
		var d := to.length()
		if d > 13.0 or d < 0.4:
			continue
		if forward.dot(to.normalized()) < 0.6:
			continue
		if d < best_d:
			best_d = d
			best = m
	return best

func get_nearest_enemy_for(mon: MonsterEntity, radius: float) -> MonsterEntity:
	if spawner == null:
		return null
	return spawner.get_nearest_enemy_for(mon, radius)

func get_enemy_targets_in_radius(pos: Vector3, radius: float) -> Array:
	if spawner == null:
		return []
	return spawner.get_enemies_in_radius(pos, radius)

func get_companion_node() -> MonsterEntity:
	if spawner == null:
		return null
	return spawner.get_companion()

func use_companion_skill() -> void:
	if spawner != null:
		spawner.use_skill()

func try_capture_with_orb(orb_id: String) -> void:
	if spawner == null or player == null:
		return
	if Game.count_item(orb_id) < 1:
		Game.notify.emit("No capture orbs left.", UITheme.RED)
		return
	var forward := -player.camera.global_transform.basis.z
	var target := spawner.get_capture_target(player.camera.global_position, forward, 11.0)
	if target == null:
		Game.notify.emit("Aim at the monster you want to capture.", Color("#ffb28a"))
		return
	if not target.is_capturable():
		Game.notify.emit("Weaken the monster below 42% HP first.", Color("#ffb28a"))
		return
	Game.remove_item(orb_id, 1)
	var item: Dictionary = Content.ITEMS.get(orb_id, {})
	var mult: float = float(item.get("orb_mult", 1.0))
	Sfx.play("swing", 0.1)
	spawn_orb_projectile(player.camera.global_position, target.global_position + Vector3(0, 0.8, 0))
	var res := target.attempt_capture(mult)
	if res.get("ok", false):
		Game.banner.emit("Captured!", "%s joined your team." % target.display_name)
		spawner._refresh_companion()
	else:
		var pct := int(float(res.get("chance", 0.0)) * 100.0)
		Game.notify.emit("Capture failed (%d%%). The monster became aggressive!" % pct, Color("#ff9b8a"))

func try_interact_nearby(from_pos: Vector3, forward: Vector3) -> bool:
	if ui != null and not npc_list.is_empty():
		var npc := _find_npc_near(from_pos, forward)
		if npc != null:
			ui.open_npc(npc.dialogue_data())
			return true
	if spawner == null:
		return false
	var best: MonsterEntity = null
	var best_d := 5.0
	for m in spawner.wild:
		if m == null or not is_instance_valid(m) or m.dead:
			continue
		var to := m.global_position - from_pos
		var d := to.length()
		if d > 5.0 or forward.dot(to.normalized()) < 0.3:
			continue
		if d < best_d:
			best_d = d
			best = m
	if best == null:
		return false
	var sel := Game.get_hotbar_item()
	if str(sel.get("id", "")) == "feed":
		Game.remove_item("feed", 1)
		var res := best.attempt_tame()
		if not res.get("ok", false):
			Game.notify.emit("%s refused the feed. Try weakening it first." % best.display_name, Color("#ffb28a"))
		else:
			Game.banner.emit("Tamed!", "%s becomes your friend." % best.display_name)
			spawner._refresh_companion()
	else:
		Game.notify.emit("%s • Lv%d • HP %d/%d. Select Feed and press USE to tame it." % [
			best.display_name, best.level, best.hp, best.max_hp], UITheme.INK)
	return true

func interact_rune(info: Dictionary) -> void:
	if info.is_empty():
		Game.notify.emit("This rune core is sealed.", Color("#ffb28a"))
		return
	var boss_id := str(info.get("boss", ""))
	if bool(Game.flags.get("boss_" + boss_id, false)):
		if Game.count_item("rift_key") > 0:
			spawner.start_rift()
		else:
			Game.notify.emit("The boss is defeated. Craft a Rift Key to open the World Rift.", Color("#d9a6ff"))
		return
	if spawner.boss_alive_for(info):
		Game.notify.emit("The boss is still alive. Finish the fight!", Color("#ff9b8a"))
		return
	spawner.spawn_boss(info)
	Game.flags["boss_spawned_" + str(info.get("id", ""))] = true

func entity_blocks_place(pos: Vector3i) -> bool:
	var box := AABB(Vector3(pos), Vector3.ONE)
	if spawner == null:
		return false
	for m in spawner.wild:
		if m != null and is_instance_valid(m):
			if box.intersects(AABB(m.global_position - Vector3(0.4, 0.2, 0.4), Vector3(0.8, 1.6, 0.8))):
				return true
	var comp := spawner.get_companion()
	if comp != null and is_instance_valid(comp):
		if box.intersects(AABB(comp.global_position - Vector3(0.4, 0.2, 0.4), Vector3(0.8, 1.6, 0.8))):
			return true
	for n in npc_list:
		if n != null and is_instance_valid(n):
			if box.intersects(AABB(n.global_position - Vector3(0.35, 0.2, 0.35), Vector3(0.7, 1.7, 0.7))):
				return true
	return false

func on_wild_monster_died(mon: MonsterEntity) -> void:
	if mon == boss_entity:
		boss_entity = null

func on_companion_fainted(_mon: MonsterEntity) -> void:
	if player != null:
		player.companion_guard = false
		player.speed_multiplier = 1.0
		player.can_glide = false
	Game.notify.emit("Your partner is down. Feed it to restore.", Color("#ff9b8a"))

func show_boss_bar(boss: MonsterEntity) -> void:
	boss_entity = boss
	if ui != null:
		ui.show_boss(boss.display_name, boss.hp, boss.max_hp)

func update_boss_bar(boss: MonsterEntity) -> void:
	if ui != null and boss == boss_entity:
		ui.update_boss(boss.hp, boss.max_hp)

func hide_boss_bar() -> void:
	if ui != null:
		ui.hide_boss()
	if boss_entity != null and (not is_instance_valid(boss_entity) or boss_entity.dead):
		boss_entity = null

func on_rift_state(wave: int, remaining: int) -> void:
	if ui != null:
		ui.on_rift_state(wave, remaining)

# ------------------------------------------------------------------ fx & drops

func spawn_item_drop(item_id: String, n: int, pos: Vector3) -> void:
	var drop := ItemDrop.new()
	world.add_child(drop)
	drop.global_position = pos
	drop.setup(item_id, n, player)

func show_damage_number(pos: Vector3, amount: int, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = str(amount)
	lbl.font_size = 34
	lbl.pixel_size = 0.0045
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.02, 0.05, 0.05, 0.9)
	lbl.modulate = color
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	world.add_child(lbl)
	lbl.global_position = pos
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", pos.y + 0.9, 0.65)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.65)
	tw.chain().tween_callback(lbl.queue_free)

func spawn_hit_fx(pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.16, 0.16)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mesh.material = mat
	for i in 5:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		mi.global_position = pos
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized()
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "global_position", pos + dir * randf_range(0.5, 1.2), 0.3)
		tw.tween_property(mi, "scale", Vector3(0.05, 0.05, 0.05), 0.3)
		tw.chain().tween_callback(mi.queue_free)

func spawn_skill_projectile(from: Vector3, to: Vector3, color: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	sphere.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = from
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 4.0
	mi.add_child(light)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", to, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mi, "scale", Vector3(1.8, 1.8, 1.8), 0.28)
	tw.chain().tween_callback(mi.queue_free)

func spawn_skill_aoe(pos: Vector3, radius: float, color: Color) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	torus.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.12, 0)
	mi.rotation_degrees.x = 90
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, radius * 0.4, radius), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.42)
	tw.chain().tween_callback(mi.queue_free)

func spawn_skill_heal(pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 30.0
	p.gravity = Vector3(0, 3, 0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07, 0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mesh.material = mat
	p.mesh = mesh
	p.emitting = true
	world.add_child(p)
	p.global_position = pos
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func spawn_orb_projectile(from: Vector3, to: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#7fe6da")
	mat.emission_enabled = true
	mat.emission = Color("#7fe6da")
	sphere.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = from
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", to, 0.25)
	tw.chain().tween_callback(mi.queue_free)

# ------------------------------------------------------------------ misc

func on_block_broken(_pos: Vector3i, _block: int) -> void:
	pass

func on_block_placed(_pos: Vector3i, _block: int) -> void:
	pass

func quit_to_menu() -> void:
	if Game.in_game and Game.current_slot >= 0:
		Game.save_game(Game.current_slot, true)
	get_tree().paused = false
	if ui_layer != null:
		ui_layer.queue_free()
		ui_layer = null
		ui = null
	if world != null:
		world.shutdown()
		world.queue_free()
		world = null
	player = null
	spawner = null
	boss_entity = null
	tracked_waypoint = Vector3.ZERO
	village_spawns.clear()
	npc_list.clear()
	Game.in_game = false
	Game.world_ref = null
	Game.pending_world_data = {}
	if loading_layer != null:
		loading_layer.queue_free()
		loading_layer = null
	_show_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Game.in_game and Game.current_slot >= 0 and Game.world_ref != null:
			Game.save_game(Game.current_slot, true)
			if world != null:
				world.shutdown()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if ui != null and Game.in_game:
			ui.handle_back_pressed()


# ------------------------------------------------------------------ story quest markers

func quest_marker_position(q: Dictionary) -> Vector3:
	if world == null or player == null or q.is_empty():
		return Vector3.ZERO
	if str(q.get("marker", "village")) == "dungeon":
		var d := world.get_nearest_dungeon(player.global_position)
		if d.is_empty():
			return Vector3.ZERO
		var e: Vector3i = d.entrance
		return Vector3(e) + Vector3(0.5, 1.0, 0.5)
	var v := world.get_nearest_village(player.global_position)
	if v.is_empty():
		return Vector3.ZERO
	var c: Vector3i = v.center
	return Vector3(c) + Vector3(0.5, 1.0, 0.5)

func quest_marker_points() -> Array:
	var out: Array = []
	for e in Game.active_story_quests():
		var pos := quest_marker_position(e.q)
		if pos == Vector3.ZERO:
			continue
		out.append({"pos": pos, "kind": str(e.q.kind), "done": bool(e.rec.get("done", false))})
	return out

func track_quest(qid: String) -> void:
	var q := Story.by_id(qid)
	if q.is_empty() or player == null:
		return
	Game.tracked_quest = qid
	var pos := quest_marker_position(q)
	if pos != Vector3.ZERO:
		tracked_waypoint = pos
		Game.notify.emit("Tracking %s (%dm)" % [str(q.title), int(player.global_position.distance_to(pos))],
			UITheme.AMBER if str(q.kind) == "main" else UITheme.TEAL)
	else:
		Game.notify.emit("Tracking %s" % str(q.title), UITheme.AMBER)

func _update_quest_markers() -> void:
	if world == null or player == null or not Game.in_game:
		return
	var wanted: Dictionary = {}
	for e in Game.active_story_quests():
		var q: Dictionary = e.q
		var qid := str(q.id)
		var pos := quest_marker_position(q)
		if pos == Vector3.ZERO:
			continue
		wanted[qid] = true
		var root: Node3D = quest_beacons.get(qid)
		var color: Color = UITheme.AMBER if str(q.kind) == "main" else UITheme.TEAL
		if root == null:
			root = _make_quest_beacon(color)
			world.add_child(root)
			quest_beacons[qid] = root
		var mat: StandardMaterial3D = root.get_meta("mat")
		var lbl: Label3D = root.get_meta("label")
		var mi: MeshInstance3D = root.get_meta("mesh")
		var dist := int(player.global_position.distance_to(pos))
		root.global_position = pos + Vector3(0, 2.6, 0)
		root.visible = dist < 150
		var done := bool(e.rec.get("done", false))
		var shown := Color("#9ff5b0") if done else color
		mat.albedo_color = shown
		mat.emission = shown
		lbl.modulate = shown
		lbl.text = "%s\n%d m" % [str(q.title), dist]
		mi.rotation.y += 0.03
		mi.position.y = sin(Game.play_time * 2.2) * 0.16
	for qid in quest_beacons.keys():
		if wanted.has(qid):
			continue
		var b: Node3D = quest_beacons[qid]
		if b != null and is_instance_valid(b):
			b.queue_free()
		quest_beacons.erase(qid)

func _make_quest_beacon(color: Color) -> Node3D:
	var root := Node3D.new()
	root.top_level = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.3, 0.3, 0.3)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.rotation_degrees = Vector3(45, 45, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var beam := CylinderMesh.new()
	beam.top_radius = 0.03
	beam.bottom_radius = 0.11
	beam.height = 2.6
	beam.radial_segments = 8
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.16)
	beam_mat.emission_enabled = true
	beam_mat.emission = color
	beam_mat.emission_energy_multiplier = 0.7
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material = beam_mat
	var bi := MeshInstance3D.new()
	bi.mesh = beam
	bi.position = Vector3(0, -1.2, 0)
	bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bi)
	var lbl := Label3D.new()
	lbl.font = UITheme.body_font()
	lbl.font_size = 34
	lbl.pixel_size = 0.006
	lbl.outline_size = 9
	lbl.outline_modulate = Color(0.02, 0.05, 0.05, 0.92)
	lbl.modulate = color
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 0.5, 0)
	root.add_child(lbl)
	root.set_meta("mat", mat)
	root.set_meta("mesh", mi)
	root.set_meta("label", lbl)
	return root

func interact_landmark(pos: Vector3i) -> void:
	if world == null or player == null:
		return
	var lm: Dictionary = world.get_landmark_at(Vector3(pos) + Vector3(0.5, 0.5, 0.5))
	if lm.is_empty():
		Game.notify.emit("This rune is dead stone now.", UITheme.MUTED)
		return
	if str(lm.get("kind", "")) == "gate":
		var v := world.get_nearest_village(player.global_position)
		if v.is_empty():
			Game.notify.emit("The gate finds no village to anchor to.", Color("#ff9b8a"))
			return
		var c: Vector3i = v.center
		world.force_load_area(Vector3(c), 2)
		player.global_position = Vector3(c.x + 0.5, c.y + 1.6, c.z + 3.5)
		Game.notify.emit("Ancient Gate: travelled to %s." % str(v.get("name", "village")), Color("#d9a6ff"))
		Sfx.play("rift", 0.08)
		return
	Game.notify.emit("%s - its story is worn away, but someone left something here." % str(lm.get("name", "Old landmark")), Color("#d9d2b0"))
