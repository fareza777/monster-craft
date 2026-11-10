class_name CraftPlayer
extends CharacterBody3D

const WALK_SPEED := 5.0
const SPRINT_SPEED := 7.4
const SWIM_SPEED := 3.3
const GRAVITY := 24.0
const JUMP_SPEED := 7.6
const REACH := 5.4

var world: VoxelWorld
var ui: Control
var main: Node
var companion: Node3D

var yaw := 0.0
var pitch := -0.15
var look_sensitivity := 1.0
var touch_move := Vector2.ZERO
var speed_multiplier := 1.0
var can_glide := false
var companion_guard := false

var camera: Camera3D
var hand_root: Node3D
var held_sprite: Sprite3D
var sword_models: Dictionary = {}
var tool_models: Dictionary = {}
var block_cube: MeshInstance3D
var orb_mesh: MeshInstance3D
var place_ghost: MeshInstance3D
var highlight: MeshInstance3D
var break_particles: CPUParticles3D
var _head_mat: StandardMaterial3D
var _cube_mat: StandardMaterial3D
var _orb_mat: StandardMaterial3D
var _ghost_mat: StandardMaterial3D
var _particle_mat: StandardMaterial3D

var primary_held := false
var mining_target := Vector3i.ZERO
var mining_valid := false
var mining_progress := 0.0
var mining_block := 0
var attack_cooldown := 0.0
var hurt_cooldown := 0.0
var lava_timer := 0.0
var regen_timer := 0.0
var swing_timer := 0.0
var shake := 0.0
var walk_time := 0.0
var jump_buffer := 0.0
var was_on_floor := false
var fall_speed := 0.0
var was_in_water := false
var sfx_dig_timer := 0.0
var jump_held := false
var last_selected := -99
var last_item_sig := ""
var input_enabled := true
var riding_monster: Node3D = null
var _camera_base_y := 1.62
var _look_sway := Vector2.ZERO
var _land_dip := 0.0
var _dead := false
var _spawn_check_delay := 30

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	camera = Camera3D.new()
	camera.position = Vector3(0, _camera_base_y, 0)
	camera.fov = 74.0
	camera.near = 0.045
	camera.far = 180.0
	camera.current = true
	add_child(camera)
	_build_hand()
	_build_place_ghost()
	_build_highlight()
	_build_particles()
	_ensure_input()
	Game.inventory_changed.connect(_refresh_held)
	Game.stats_changed.connect(_on_stats_changed)
	Game.party_changed.connect(_refresh_held)
	_refresh_held()
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _ensure_input() -> void:
	var binds := {
		"mc_forward": [KEY_W], "mc_back": [KEY_S], "mc_left": [KEY_A], "mc_right": [KEY_D],
		"mc_jump": [KEY_SPACE], "mc_sprint": [KEY_SHIFT],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

func set_ui(u: Control) -> void:
	ui = u

func get_save_state() -> Dictionary:
	return {"pos": [global_position.x, global_position.y, global_position.z],
		"yaw": yaw, "pitch": pitch}

func apply_save_state(d: Dictionary) -> void:
	if d.has("pos"):
		var p = d.pos
		if p is Array and p.size() >= 3:
			global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		yaw = float(d.get("yaw", 0.0))
		pitch = clampf(float(d.get("pitch", -0.15)), -1.45, 1.45)
		rotation.y = yaw
		camera.rotation.x = pitch

func _ensure_safe_position() -> void:
	if world == null or _dead:
		return
	var x := floori(global_position.x)
	var z := floori(global_position.z)
	var y := floori(global_position.y + 0.1)
	if not _solid_block(x, y, z) and not _solid_block(x, y + 1, z):
		return
	var top := y
	while top < TerrainGen.HEIGHT - 2 and (_solid_block(x, top, z) or _solid_block(x, top + 1, z)):
		top += 1
	global_position.y = float(top) + 0.1
	velocity = Vector3.ZERO
	Game.notify.emit("Recovered to a safe spot.", Color("#cdc9b4"))

func _solid_block(x: int, y: int, z: int) -> bool:
	if y < 0 or y >= TerrainGen.HEIGHT:
		return false
	return Content.is_solid(world.get_block(Vector3i(x, y, z)))

func reset_after_death() -> void:
	velocity = Vector3.ZERO
	_dead = false
	Game.hp = int(Game.max_hp * 0.5)
	Game.stats_changed.emit()
	shake = 0.4
	if ui != null and ui.has_method("flash_hurt"):
		ui.flash_hurt()

func add_look(delta_px: Vector2) -> void:
	if not input_enabled or get_tree().paused:
		return
	var factor := 0.0026 * look_sensitivity
	var dy := -delta_px.y if Game.invert_look_y else delta_px.y
	yaw -= delta_px.x * factor
	pitch = clampf(pitch - dy * factor, -1.45, 1.45)
	_look_sway = (_look_sway + Vector2(delta_px.x, delta_px.y) * 0.0016).limit_length(1.0)
	rotation.y = yaw
	camera.rotation.x = pitch

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			primary_pressed()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			place_selected()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			Game.selected_hotbar = (Game.selected_hotbar + 8) % 9
			Sfx.play("ui")
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Game.selected_hotbar = (Game.selected_hotbar + 1) % 9
			Sfx.play("ui")
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			primary_released()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			Game.selected_hotbar = event.keycode - KEY_1
			Sfx.play("ui")
			_refresh_held()

func request_jump() -> void:
	jump_buffer = 0.16

func request_skill() -> void:
	if main != null and main.has_method("use_companion_skill"):
		main.use_companion_skill()

func primary_pressed() -> void:
	if not input_enabled or _dead:
		return
	primary_held = true
	swing_timer = 0.28
	var slot := Game.get_hotbar_item()
	if slot.is_empty():
		_start_mining()
		return
	var item: Dictionary = Content.ITEMS.get(slot.id, {})
	var itype: String = item.get("type", "")
	if itype == "orb":
		primary_held = false
		if main != null and main.has_method("try_capture_with_orb"):
			main.try_capture_with_orb(str(slot.id))
		return
	if itype == "food":
		Game.use_food(Game.selected_hotbar)
		primary_held = false
		return
	if itype == "tool" and item.get("tool_kind", "") == "hoe":
		_till_soil()
		primary_held = false
		return
	if slot.id == "seeds":
		_plant_seeds()
		primary_held = false
		return
	if _try_attack():
		return
	_start_mining()

func primary_released() -> void:
	primary_held = false
	mining_progress = 0.0
	mining_valid = false

func _start_mining() -> void:
	mining_progress = 0.0
	mining_target = Vector3i(999999, 999999, 999999)
	mining_valid = false

func _physics_process(delta: float) -> void:
	if world == null or _dead:
		return
	if _spawn_check_delay > 0:
		_spawn_check_delay -= 1
		if _spawn_check_delay == 0:
			_ensure_safe_position()
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if hurt_cooldown > 0.0:
		hurt_cooldown -= delta
	if swing_timer > 0.0:
		swing_timer -= delta
	if jump_buffer > 0.0:
		jump_buffer -= delta
	var in_water := world.is_liquid_at(global_position + Vector3(0, 0.9, 0))
	var feet_liquid := world.block_at_float(global_position + Vector3(0, 0.2, 0))
	var in_lava := feet_liquid == Content.LAVA or world.block_at_float(global_position + Vector3(0, 0.9, 0)) == Content.LAVA
	# movement input
	var input_vec := Vector2.ZERO
	if input_enabled:
		input_vec = Input.get_vector("mc_left", "mc_right", "mc_forward", "mc_back")
		if touch_move.length() > 0.08:
			input_vec = touch_move
		var jump_pressed := Input.is_action_just_pressed("mc_jump") or jump_buffer > 0.0 or jump_held
		if jump_pressed and jump_buffer > 0.0:
			jump_buffer = 0.0
		if jump_pressed and (is_on_floor() or in_water):
			velocity.y = JUMP_SPEED * (1.18 if riding_monster != null else 1.0)
			Sfx.play("jump")
			jump_held = false
		var want_sprint := Input.is_action_pressed("mc_sprint") or touch_move.length() > 0.92
		var speed := WALK_SPEED * speed_multiplier
		if riding_monster != null:
			var mon := Game.active_monster()
			var stats := Content.monster_stats(mon)
			speed = 6.8 + float(stats.get("spd", 3.5)) * 0.75
		elif in_water:
			speed = SWIM_SPEED
		elif want_sprint and Game.stamina > 2.0 and input_vec.length() > 0.2:
			speed = SPRINT_SPEED * speed_multiplier
			Game.drain_stamina(13.0 * delta)
		else:
			Game.add_stamina(18.0 * delta)
		var dir := Vector3(input_vec.x, 0, input_vec.y)
		if dir.length() > 1.0:
			dir = dir.normalized()
		dir = dir.rotated(Vector3.UP, yaw)
		if in_water:
			velocity.x = move_toward(velocity.x, dir.x * speed, 20.0 * delta)
			velocity.z = move_toward(velocity.z, dir.z * speed, 20.0 * delta)
			if Input.is_action_pressed("mc_jump") or jump_buffer > 0.0:
				velocity.y = move_toward(velocity.y, 4.0, 12.0 * delta)
			else:
				velocity.y = move_toward(velocity.y, -1.3, 6.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, dir.x * speed, 32.0 * delta)
			velocity.z = move_toward(velocity.z, dir.z * speed, 32.0 * delta)
			if not is_on_floor():
				velocity.y -= GRAVITY * delta
				if can_glide and (Input.is_action_pressed("mc_jump") or jump_held) and velocity.y < -3.5:
					velocity.y = maxf(velocity.y, -4.0)
			elif velocity.y < 0.0:
				velocity.y = -0.2
			if is_on_floor() and input_vec.length() > 0.2:
				var step_y := floori(global_position.y - 0.05) + 1
				var probe := global_position + dir.normalized() * 0.62
				var bx := floori(probe.x)
				var bz := floori(probe.z)
				var step_block := world.get_block(Vector3i(bx, step_y, bz))
				var step_above := world.get_block(Vector3i(bx, step_y + 1, bz))
				if Content.is_solid(step_block) and not Content.is_solid(step_above):
					velocity.y = JUMP_SPEED * 0.95
	# fall damage
	if not is_on_floor():
		fall_speed = minf(fall_speed, velocity.y)
	if is_on_floor() and not was_on_floor and fall_speed < -7.0:
		_land_dip = clampf(-fall_speed / 24.0, 0.12, 1.0)
	if is_on_floor() and not was_on_floor and fall_speed < -19.0:
		_take_damage(int((-fall_speed - 19.0) * 2.5), "fall")
		fall_speed = 0.0
	if is_on_floor():
		fall_speed = 0.0
	was_on_floor = is_on_floor()
	# hazards
	if in_lava:
		lava_timer -= delta
		if lava_timer <= 0.0:
			lava_timer = 0.75
			_take_damage(7, "lava")
	else:
		lava_timer = 0.0
	if in_water and not was_in_water:
		Sfx.play("splash", 0.1)
	was_in_water = in_water
	# regen
	regen_timer += delta
	if regen_timer > 3.0 and Game.hp < Game.max_hp and Game.play_time - Game._last_hit_time > 9.0:
		regen_timer = 0.0
		Game.heal_player(2)
	# safety: never fall out of the world
	if global_position.y < -10.0:
		world.respawn_player()
	move_and_slide()
	_update_look_and_hand(delta)
	_update_mining(delta)
	_update_riding()
	_detect_look_target()
	_poll_selected()

func _fov_target() -> float:
	var base := 74.0
	if riding_monster != null:
		return 79.0
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar > 6.2 and is_on_floor():
		base = 79.5
	return base

func _update_look_and_hand(delta: float) -> void:
	var speed2d := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and speed2d > 0.5:
		walk_time += delta * speed2d * 1.4
	else:
		walk_time = lerpf(walk_time, 0.0, delta * 6.0)
	var bob_amt := clampf(speed2d / WALK_SPEED, 0.0, 1.7)
	var bob := sin(walk_time * 2.0) * 0.032 * bob_amt
	var bob_roll := sin(walk_time) * 1.1 * bob_amt
	_look_sway = _look_sway.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	_land_dip = maxf(0.0, _land_dip - delta * 3.6)
	var dip := -sin(_land_dip * PI) * 0.16 if _land_dip > 0.0 else 0.0
	camera.position.y = lerpf(camera.position.y, _camera_base_y + bob + dip, delta * 12.0)
	camera.rotation.z = lerpf(camera.rotation.z, deg_to_rad(bob_roll) + _look_sway.x * 0.014, delta * 9.0)
	camera.fov = lerpf(camera.fov, _fov_target(), delta * 3.2)
	var shake_amt := shake if Game.screen_shake else 0.0
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 2.4)
	if shake_amt > 0.0:
		camera.position.x = randf_range(-shake_amt, shake_amt) * 0.12
		camera.position.y += randf_range(-shake_amt, shake_amt) * 0.08
	else:
		camera.position.x = lerpf(camera.position.x, 0.0, delta * 10.0)
	if hand_root != null:
		var swing := 0.0
		if swing_timer > 0.0:
			swing = sin((1.0 - swing_timer / 0.28) * PI) * 0.9
		elif primary_held and mining_valid:
			swing = sin(Time.get_ticks_msec() * 0.016) * 0.3
		var sway := sin(walk_time) * 0.012 * clampf(speed2d / WALK_SPEED, 0.0, 1.0)
		var sway2 := sin(walk_time * 2.0) * 0.02 * clampf(speed2d / WALK_SPEED, 0.0, 1.3)
		var idle := sin(Time.get_ticks_msec() * 0.0013) * 0.007
		hand_root.position = Vector3(0.42 + sway * 2.1 - _look_sway.x * 0.045 + sway2, -0.31 + bob * 0.95 + idle + dip * 0.55 - _look_sway.y * 0.03, -0.74 - swing * 0.17)
		hand_root.rotation_degrees = Vector3(-4.0 - swing * 62.0 + _look_sway.y * 4.0, swing * 14.0 + _look_sway.x * 7.0, -6.0 + sway * 170.0 + swing * 20.0)
	_update_place_ghost()

func _detect_look_target() -> void:
	if world == null or camera == null:
		return
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var hit := world.raycast_voxel(origin, dir, REACH)
	if hit.is_empty():
		highlight.visible = false
		if not primary_held:
			mining_valid = false
		return
	highlight.visible = true
	highlight.global_position = Vector3(hit.pos) + Vector3(0.5, 0.5, 0.5)
	highlight.scale = Vector3(1.006, 1.006, 1.006)

func _update_mining(delta: float) -> void:
	if primary_held and input_enabled:
		if main != null and main.has_method("get_melee_target"):
			if main.get_melee_target(global_position, -camera.global_transform.basis.z, 3.4) != null:
				mining_valid = false
				return
		var slot := Game.get_hotbar_item()
		if not slot.is_empty():
			var it: Dictionary = Content.ITEMS.get(slot.id, {})
			if it.get("type", "") == "orb" or it.get("type", "") == "food":
				return
			if it.get("type", "") == "tool" and it.get("tool_kind", "") == "hoe":
				return
			if slot.id == "seeds":
				return
		var origin := camera.global_position
		var dir := -camera.global_transform.basis.z
		var hit := world.raycast_voxel(origin, dir, REACH)
		if hit.is_empty():
			mining_valid = false
			return
		var target: Vector3i = hit.pos
		var block: int = hit.block
		var bd: Dictionary = Content.BLOCKS.get(block, {})
		var hardness := float(bd.get("hardness", 1.0))
		if hardness < 0.0:
			if mining_valid and mining_target == target:
				Game.notify.emit("This block cannot be broken.", Color("#ff9b8a"))
			mining_valid = false
			return
		if target != mining_target:
			mining_target = target
			mining_block = block
			mining_progress = 0.0
			mining_valid = true
			sfx_dig_timer = 0.0
		var tool_kind: String = str(bd.get("tool", ""))
		var tier := 0
		if tool_kind != "":
			tier = Game.tool_tier(tool_kind)
		var factor := 1.0 + float(tier) * 0.85
		if tool_kind == "":
			factor = 1.4
		var needed := maxf(0.08, hardness / factor)
		mining_progress += delta / needed
		sfx_dig_timer -= delta
		if sfx_dig_timer <= 0.0:
			sfx_dig_timer = 0.24
			Sfx.play("dig", 0.14)
		if mining_progress >= 1.0:
			_break_block(target, block)
			mining_progress = 0.0
			mining_valid = false
			mining_target = Vector3i(999999, 999999, 999999)

func _break_block(pos: Vector3i, block: int) -> void:
	var bd: Dictionary = Content.BLOCKS.get(block, {})
	var key := Game.block_key(pos)
	if block == Content.CHEST:
		var contents := Game.get_chest(key)
		for i in contents.size():
			if contents[i] != null:
				var left := Game.add_item(str(contents[i].id), int(contents[i].n), true)
				if left > 0 and main != null and main.has_method("spawn_item_drop"):
					main.spawn_item_drop(str(contents[i].id), left, Vector3(pos) + Vector3(0.5, 0.6, 0.5))
				contents[i] = null
		Game.chests.erase(key)
	if block == Content.RANCH:
		pass
	var drops: Array = bd.get("drops", [])
	if block >= Content.WHEAT0 and block <= Content.WHEAT3:
		drops = []
		if block == Content.WHEAT3:
			Game.add_item("wheat", randi_range(2, 3))
			Game.add_item("seeds", randi_range(1, 2))
		else:
			Game.add_item("seeds", 1)
	for d in drops:
		if randf() <= float(d.get("chance", 1.0)):
			Game.add_item(str(d.id), randi_range(int(d.get("min", 1)), int(d.get("max", 1))))
	world.set_block(pos, Content.AIR)
	_break_fx(pos, block)
	Sfx.play("break", 0.12)
	Game.add_player_xp(1 if block < Content.COAL_ORE or block > Content.CRYSTAL_ORE else 3)
	if main != null and main.has_method("on_block_broken"):
		main.on_block_broken(pos, block)
	if block == Content.RANCH:
		Game.flags.erase("ranch_built")

func _break_fx(pos: Vector3i, block: int) -> void:
	break_particles.global_position = Vector3(pos) + Vector3(0.5, 0.5, 0.5)
	_particle_mat.albedo_color = Content.block_color(block)
	break_particles.emitting = false
	break_particles.restart()
	break_particles.emitting = true

func _try_attack() -> bool:
	if attack_cooldown > 0.0 or main == null:
		return false
	if not main.has_method("get_melee_target"):
		return false
	var forward := -camera.global_transform.basis.z
	var target = main.get_melee_target(global_position, forward, 3.4)
	if target == null:
		return false
	attack_cooldown = 0.42
	swing_timer = 0.28
	var dmg := Game.attack_damage()
	if target.has_method("take_damage"):
		target.take_damage(dmg, "player")
	if target.has_method("apply_knockback"):
		target.apply_knockback(forward, 4.0)
	Sfx.play("swing", 0.12)
	Sfx.play("hit", 0.15)
	shake = maxf(shake, 0.15)
	return true

func _physics_attack_held() -> void:
	if primary_held and attack_cooldown <= 0.0:
		_try_attack()

func _place_target() -> Dictionary:
	if world == null:
		return {"valid": false}
	var slot := Game.get_hotbar_item()
	if slot.is_empty():
		return {"valid": false, "reason": "item"}
	var it: Dictionary = Content.ITEMS.get(str(slot.get("id", "")), {})
	if it.is_empty() or it.get("type", "") != "block":
		return {"valid": false, "reason": "item"}
	var block_id := int(it.get("block", -1))
	if block_id < 0:
		return {"valid": false, "reason": "item"}
	var hit := world.raycast_voxel(camera.global_position, -camera.global_transform.basis.z, REACH)
	if hit.is_empty():
		return {"valid": false, "reason": "aim"}
	var pos: Vector3i = hit.pos + hit.normal
	if Content.is_plant(hit.block):
		pos = hit.pos
	if pos.y < 1 or pos.y >= TerrainGen.HEIGHT:
		return {"valid": false, "reason": "aim", "pos": pos}
	if world.get_block(pos) != Content.AIR and not Content.is_plant(world.get_block(pos)):
		var top: Vector3i = hit.pos + Vector3i(0, 1, 0)
		if world.get_block(top) == Content.AIR:
			pos = top
		else:
			return {"valid": false, "reason": "occupied", "pos": pos}
	if Content.is_plant(block_id):
		var below := world.get_block(pos - Vector3i(0, 1, 0))
		if not Content.is_solid(below):
			return {"valid": false, "reason": "ground", "pos": pos}
	if Content.is_solid(block_id):
		var pbox := AABB(global_position + Vector3(-0.35, 0.05, -0.35), Vector3(0.7, 1.8, 0.7))
		var bbox := AABB(Vector3(pos), Vector3.ONE)
		if pbox.intersects(bbox):
			return {"valid": false, "reason": "too_close", "pos": pos}
		if main != null and main.has_method("entity_blocks_place") and main.entity_blocks_place(pos):
			return {"valid": false, "reason": "entity", "pos": pos}
	return {"valid": true, "pos": pos, "block": block_id, "slot": slot}

func place_selected() -> void:
	if not input_enabled or _dead:
		return
	var t := _place_target()
	if not t.get("valid", false):
		match str(t.get("reason", "")):
			"too_close":
				Game.notify.emit("Step back - that spot is too close.", Color("#ffb28a"))
			"occupied":
				Game.notify.emit("That spot is occupied.", Color("#ffb28a"))
			"ground":
				Game.notify.emit("Plants need solid ground below.", Color("#ffb28a"))
			"entity":
				Game.notify.emit("Something is in the way.", Color("#ffb28a"))
			"aim":
				Game.notify.emit("Aim at a surface to place a block.", Color("#ffb28a"))
			"item":
				Game.notify.emit("Select a block in the hotbar to place.", Color("#ffb28a"))
		return
	var slot: Dictionary = t.slot
	var pos: Vector3i = t.pos
	var block_id: int = t.block
	if world.set_block(pos, block_id):
		Game.remove_item(str(slot.get("id", "")), 1)
		Sfx.play("place", 0.1)
		if block_id == Content.CHEST:
			Game.get_chest(Game.block_key(pos))
		if block_id == Content.TABLE:
			Game.set_flag("table_placed")
		if block_id == Content.RANCH:
			Game.set_flag("ranch_built")
		if main != null and main.has_method("on_block_placed"):
			main.on_block_placed(pos, block_id)
		_refresh_held()
	else:
		Game.notify.emit("Could not place the block here.", Color("#ffb28a"))

func _update_place_ghost() -> void:
	if place_ghost == null:
		return
	if not input_enabled or _dead or riding_monster != null:
		place_ghost.visible = false
		return
	var t := _place_target()
	if t.get("valid", false):
		place_ghost.visible = true
		place_ghost.global_position = Vector3(t.pos) + Vector3(0.5, 0.5, 0.5)
		_ghost_mat.albedo_color = Color(0.45, 1.0, 0.55, 0.3)
	else:
		place_ghost.visible = false

func interact_now() -> void:
	if not input_enabled or _dead:
		return
	var hit := world.raycast_voxel(camera.global_position, -camera.global_transform.basis.z, REACH + 0.5)
	if not hit.is_empty():
		var bd: Dictionary = Content.BLOCKS.get(hit.block, {})
		var interact: String = str(bd.get("interact", ""))
		if interact != "":
			var key := Game.block_key(hit.pos)
			match interact:
				"chest":
					var tier := world.get_chest_tier(hit.pos)
					if tier > 0:
						Game.fill_loot_chest(key, tier)
					else:
						Game.get_chest(key)
					if ui != null and ui.has_method("open_chest"):
						ui.open_chest(key, tier)
					return
				"table":
					if ui != null and ui.has_method("open_crafting"):
						ui.open_crafting()
					return
				"ranch":
					Game.set_flag("ranch_built")
					if ui != null and ui.has_method("open_ranch"):
						ui.open_ranch()
					return
				"rune":
					var info := world.get_dungeon_at(Vector3(hit.pos) + Vector3(0.5, 0.5, 0.5))
					if info.is_empty() and main != null and main.has_method("interact_landmark"):
						main.interact_landmark(hit.pos)
					elif main != null and main.has_method("interact_rune"):
						main.interact_rune(info)
					return
	if main != null and main.has_method("try_interact_nearby"):
		if main.try_interact_nearby(global_position, -camera.global_transform.basis.z):
			return
	Game.notify.emit("Nothing to interact with.", Color("#cdc9b4"))

func _till_soil() -> void:
	var hit := world.raycast_voxel(camera.global_position, -camera.global_transform.basis.z, REACH)
	if hit.is_empty():
		return
	if hit.block != Content.GRASS and hit.block != Content.DIRT:
		Game.notify.emit("Use the hoe on dirt or grass to farm.", Color("#ffb28a"))
		return
	if world.get_block(hit.pos + Vector3i(0, 1, 0)) != Content.AIR:
		return
	world.set_block(hit.pos, Content.FARMLAND)
	Sfx.play("dig", 0.1)
	Game.add_player_xp(1)

func _plant_seeds() -> void:
	var hit := world.raycast_voxel(camera.global_position, -camera.global_transform.basis.z, REACH)
	if hit.is_empty() or hit.block != Content.FARMLAND:
		Game.notify.emit("Aim at farmland to plant seeds.", Color("#ffb28a"))
		return
	var above: Vector3i = hit.pos + Vector3i(0, 1, 0)
	if world.get_block(above) != Content.AIR:
		return
	if world.set_block(above, Content.WHEAT0):
		Game.remove_item("seeds", 1)
		Sfx.play("place", 0.1)

func spawn_attack_fx() -> void:
	swing_timer = 0.2

func _take_damage(amount: int, reason: String) -> void:
	if hurt_cooldown > 0.0:
		return
	hurt_cooldown = 0.62
	var reduced := amount
	if companion_guard:
		reduced = maxi(1, int(reduced * 0.85))
	Game.damage_player(reduced, reason)
	shake = 0.4
	if ui != null and ui.has_method("flash_hurt"):
		ui.flash_hurt()

func _poll_selected() -> void:
	var sig := "%d:%s" % [Game.selected_hotbar, Game.get_hotbar_item().get("id", "")]
	if sig != last_item_sig:
		last_item_sig = sig
		_refresh_held()

func _on_stats_changed() -> void:
	pass

func _build_hand() -> void:
	hand_root = Node3D.new()
	hand_root.position = Vector3(0.42, -0.31, -0.74)
	hand_root.scale = Vector3(0.78, 0.78, 0.78)
	hand_root.rotation_degrees = Vector3(-4, 0, -6)
	camera.add_child(hand_root)
	var view_light := OmniLight3D.new()
	view_light.position = Vector3(0.15, 0.15, -0.35)
	view_light.omni_range = 2.2
	view_light.light_energy = 1.2
	view_light.light_cull_mask = 2
	camera.add_child(view_light)
	held_sprite = Sprite3D.new()
	held_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	held_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	held_sprite.shaded = false
	held_sprite.no_depth_test = true
	held_sprite.render_priority = 2
	held_sprite.pixel_size = 0.008
	held_sprite.position = Vector3(0, 0.04, 0)
	held_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand_root.add_child(held_sprite)
	var cube := BoxMesh.new()
	cube.size = Vector3(0.3, 0.3, 0.3)
	_cube_mat = StandardMaterial3D.new()
	_cube_mat.albedo_color = Color("#7cc86a")
	_cube_mat.roughness = 1.0
	cube.material = _cube_mat
	block_cube = MeshInstance3D.new()
	block_cube.mesh = cube
	block_cube.position = Vector3(0, -0.02, 0)
	block_cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand_root.add_child(block_cube)
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.albedo_color = Color("#6acfc4")
	_orb_mat.emission_enabled = true
	_orb_mat.emission = Color("#6acfc4")
	_orb_mat.emission_energy_multiplier = 1.2
	sphere.material = _orb_mat
	orb_mesh = MeshInstance3D.new()
	orb_mesh.mesh = sphere
	orb_mesh.position = Vector3(0, -0.02, 0)
	orb_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand_root.add_child(orb_mesh)
	_refresh_held()

func _build_place_ghost() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.45, 1.0, 0.55, 0.32)
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var box := BoxMesh.new()
	box.size = Vector3(1.004, 1.004, 1.004)
	box.material = _ghost_mat
	place_ghost = MeshInstance3D.new()
	place_ghost.mesh = box
	place_ghost.top_level = true
	place_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	place_ghost.visible = false
	add_child(place_ghost)


func _refresh_held() -> void:
	if hand_root == null:
		return
	held_sprite.visible = false
	block_cube.visible = false
	orb_mesh.visible = false
	for model in sword_models.values():
		if model is Node3D:
			model.visible = false
	for model in tool_models.values():
		if model is Node3D:
			model.visible = false
	held_sprite.position = Vector3(0, 0.04, 0)
	if riding_monster != null:
		return
	var slot := Game.get_hotbar_item()
	if slot.is_empty():
		return
	var it: Dictionary = Content.ITEMS.get(str(slot.get("id", "")), {})
	var itype: String = str(it.get("type", ""))
	if str(slot.get("id", "")) == "torch":
		var torch_model := _get_tool_model("torch", 0)
		if torch_model != null:
			torch_model.visible = true
	elif itype == "block":
		block_cube.visible = true
		_cube_mat.albedo_color = Content.block_color(int(it.get("block", -1)))
	elif itype == "orb":
		orb_mesh.visible = true
		_orb_mat.albedo_color = Content._as_color(it.get("color", "#6acfc4"))
		_orb_mat.emission = Content._as_color(it.get("color", "#6acfc4"))
	elif str(it.get("tool_kind", "")) == "sword":
		_get_sword_model(int(it.get("tier", 1))).visible = true
	elif itype == "tool":
		var tool_model := _get_tool_model(str(it.get("tool_kind", "")), int(it.get("tier", 1)))
		if tool_model != null:
			tool_model.visible = true
	else:
		held_sprite.visible = true
		var tex := Content.get_held_texture(str(slot.get("id", "")))
		if tex == null:
			held_sprite.visible = false
			return
		held_sprite.texture = tex
		var tex_h := maxf(1.0, float(tex.get_height()))
		if itype == "tool":
			held_sprite.pixel_size = 0.34 / tex_h
		else:
			held_sprite.pixel_size = 0.27 / tex_h

func _get_tool_model(kind: String, tier: int) -> Node3D:
	if kind == "" or kind == "sword":
		return null
	var key := "%s_%d" % [kind, tier]
	if tool_models.has(key):
		return tool_models[key]
	var model := _make_voxel_tool(kind, tier)
	model.visible = false
	hand_root.add_child(model)
	tool_models[key] = model
	return model

func _tool_head_color(tier: int) -> Color:
	match tier:
		1:
			return Color("#a97a46")
		2:
			return Color("#8f989e")
		3:
			return Color("#c4ced3")
	return Color("#6fe4d4")

func _make_voxel_tool(kind: String, tier: int) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(-0.1, -0.075, 0.02)
	root.rotation_degrees = Vector3(-12.0, 8.0, -14.0)
	root.scale = Vector3(0.9, 0.9, 0.9)
	var head_col := _tool_head_color(tier)
	var metal := 0.0
	var glow := 0.0
	if kind == "torch":
		head_col = Color("#f0b857")
		metal = 0.3
		glow = 1.4
	else:
		if tier >= 2:
			metal = 0.5
		if tier >= 3:
			glow = 0.16
		if tier >= 4:
			glow = 0.5
	var head_mat := _sword_mat(head_col, glow, metal)
	var head_hi := _sword_mat(head_col.lightened(0.3), glow + 0.15, maxf(metal, 0.25))
	var wood := _sword_mat(Color("#7a542c"), 0.0, 0.0)
	var wood_hi := _sword_mat(Color("#a87944"), 0.0, 0.0)
	var wood_dark := _sword_mat(Color("#553a1f"), 0.0, 0.0)
	var skin := _sword_mat(Color("#d8a97f"), 0.0, 0.0)
	var sleeve := _sword_mat(Color("#3f6b5a"), 0.0, 0.0)
	if kind == "torch":
		_sword_box(root, Vector3(0.046, 0.46, 0.046), Vector3(0, 0.08, 0), wood)
		for i in 2:
			_sword_box(root, Vector3(0.052, 0.016, 0.052), Vector3(0, 0.02 + 0.07 * i, 0), wood_dark)
		_sword_box(root, Vector3(0.078, 0.08, 0.078), Vector3(0, 0.335, 0), wood_dark)
		_sword_box(root, Vector3(0.062, 0.062, 0.062), Vector3(0, 0.404, 0), head_mat)
		var tip := _sword_box(root, Vector3(0.038, 0.05, 0.038), Vector3(0, 0.458, 0), head_mat)
		tip.rotation_degrees.y = 45.0
	else:
		_sword_box(root, Vector3(0.05, 0.5, 0.05), Vector3(0, 0.09, 0), wood)
		_sword_box(root, Vector3(0.026, 0.46, 0.054), Vector3(0, 0.09, 0.002), wood_hi)
		for i in 3:
			_sword_box(root, Vector3(0.056, 0.016, 0.056), Vector3(0, 0.055 * i, 0), wood_dark)
		if kind == "pick":
			_sword_box(root, Vector3(0.32, 0.052, 0.058), Vector3(0, 0.335, 0), head_mat)
			_sword_box(root, Vector3(0.27, 0.013, 0.062), Vector3(0, 0.362, 0), head_hi)
			var left_tip := _sword_box(root, Vector3(0.14, 0.058, 0.058), Vector3(-0.175, 0.305, 0), head_mat)
			left_tip.rotation_degrees.z = 34.0
			var right_tip := _sword_box(root, Vector3(0.14, 0.058, 0.058), Vector3(0.175, 0.305, 0), head_mat)
			right_tip.rotation_degrees.z = -34.0
			_sword_box(root, Vector3(0.082, 0.075, 0.082), Vector3(0, 0.3, 0), wood_dark)
		elif kind == "axe":
			var blade := _sword_box(root, Vector3(0.145, 0.2, 0.055), Vector3(0.07, 0.315, 0), head_mat)
			blade.rotation_degrees.z = -7.0
			_sword_box(root, Vector3(0.032, 0.2, 0.06), Vector3(0.146, 0.315, 0), head_hi)
			_sword_box(root, Vector3(0.075, 0.105, 0.08), Vector3(-0.012, 0.315, 0), wood_dark)
			_sword_box(root, Vector3(0.11, 0.035, 0.058), Vector3(0.05, 0.418, 0), head_hi)
		elif kind == "shovel":
			_sword_box(root, Vector3(0.066, 0.08, 0.066), Vector3(0, 0.31, 0), wood_dark)
			_sword_box(root, Vector3(0.17, 0.16, 0.045), Vector3(0, 0.405, 0.012), head_mat)
			_sword_box(root, Vector3(0.182, 0.032, 0.058), Vector3(0, 0.487, 0.012), head_hi)
			_sword_box(root, Vector3(0.03, 0.13, 0.05), Vector3(0, 0.4, 0.02), head_hi)
		elif kind == "hoe":
			_sword_box(root, Vector3(0.05, 0.09, 0.05), Vector3(0, 0.31, 0), wood_dark)
			_sword_box(root, Vector3(0.18, 0.042, 0.05), Vector3(0.085, 0.35, 0), head_mat)
			_sword_box(root, Vector3(0.038, 0.095, 0.05), Vector3(0.166, 0.318, 0), head_hi)
		else:
			_sword_box(root, Vector3(0.1, 0.16, 0.1), Vector3(0, 0.34, 0), head_mat)
	_sword_box(root, Vector3(0.112, 0.12, 0.112), Vector3(0, -0.075, 0.008), skin)
	_sword_box(root, Vector3(0.078, 0.048, 0.052), Vector3(0.014, -0.055, 0.064), skin)
	_sword_box(root, Vector3(0.05, 0.038, 0.055), Vector3(-0.01, -0.088, 0.064), skin)
	_sword_box(root, Vector3(0.128, 0.15, 0.128), Vector3(0, -0.2, 0.006), sleeve)
	return root

func _get_sword_model(tier: int) -> Node3D:
	tier = clampi(tier, 1, 4)
	if sword_models.has(tier):
		return sword_models[tier]
	var model := _make_voxel_sword(tier)
	model.visible = false
	hand_root.add_child(model)
	sword_models[tier] = model
	return model

func _make_voxel_sword(tier: int) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(-0.06, 0.01, 0.02)
	root.rotation_degrees = Vector3(-6.0, 24.0, -14.0)
	var blade_col := Color("#96672f")
	var ridge_col := Color("#c09255")
	var edge_col := Color("#d8b073")
	var guard_col := Color("#5c3b1e")
	var guard_hi := Color("#8c6034")
	var grip_col := Color("#402812")
	var band_col := Color("#6f4a26")
	var pommel_col := Color("#7a4f25")
	match tier:
		2:
			blade_col = Color("#7f8a8f")
			ridge_col = Color("#aab5ba")
			edge_col = Color("#d2dbdf")
			guard_col = Color("#4d5853")
			guard_hi = Color("#79857f")
			grip_col = Color("#402a19")
			band_col = Color("#5f4228")
			pommel_col = Color("#6d7a72")
		3:
			blade_col = Color("#b9c5ca")
			ridge_col = Color("#ecf5f7")
			edge_col = Color("#ffffff")
			guard_col = Color("#5f6d74")
			guard_hi = Color("#9fb0b7")
			grip_col = Color("#382413")
			band_col = Color("#c4954e")
			pommel_col = Color("#b2c0c5")
		4:
			blade_col = Color("#54cfc0")
			ridge_col = Color("#b9fff6")
			edge_col = Color("#e6fffb")
			guard_col = Color("#d9a850")
			guard_hi = Color("#ffe3a0")
			grip_col = Color("#4a2f1c")
			band_col = Color("#e0b25a")
			pommel_col = Color("#6fe4d4")
	var metal := 0.0 if tier == 1 else (0.55 if tier >= 3 else 0.08)
	var glow := 0.55 if tier == 4 else 0.12
	var blade_mat := _sword_mat(blade_col, 0.08, 0.0)
	var ridge_mat := _sword_mat(ridge_col, glow + 0.1, metal)
	var edge_mat := _sword_mat(edge_col, glow + 0.2, metal)
	var guard_mat := _sword_mat(guard_col, 0.08, metal)
	var guard_hi_mat := _sword_mat(guard_hi, glow, metal)
	var grip_mat := _sword_mat(grip_col, 0.04, 0.0)
	var band_mat := _sword_mat(band_col, glow, metal)
	var pommel_mat := _sword_mat(pommel_col, glow, metal)
	for i in 12:
		var w := 0.09 - 0.006 * float(i)
		var y := 0.0485 + 0.037 * i
		_sword_box(root, Vector3(w, 0.037, 0.046), Vector3(0, y, 0), blade_mat)
		if i < 10:
			var ex := w * 0.5 - 0.001
			_sword_box(root, Vector3(0.009, 0.037, 0.052), Vector3(-ex, y, 0), edge_mat)
			_sword_box(root, Vector3(0.009, 0.037, 0.052), Vector3(ex, y, 0), edge_mat)
	var tip := _sword_box(root, Vector3(0.026, 0.026, 0.04), Vector3(0, 0.492, 0), blade_mat)
	tip.rotation_degrees.z = 45.0
	_sword_box(root, Vector3(0.022, 0.38, 0.062), Vector3(0, 0.245, 0), ridge_mat)
	_sword_box(root, Vector3(0.24, 0.055, 0.082), Vector3(0, 0, 0), guard_mat)
	_sword_box(root, Vector3(0.062, 0.086, 0.094), Vector3(-0.12, -0.008, 0), guard_hi_mat)
	_sword_box(root, Vector3(0.062, 0.086, 0.094), Vector3(0.12, -0.008, 0), guard_hi_mat)
	_sword_box(root, Vector3(0.078, 0.03, 0.078), Vector3(0, -0.036, 0), guard_hi_mat)
	_sword_box(root, Vector3(0.055, 0.15, 0.055), Vector3(0, -0.105, 0), grip_mat)
	for i in 4:
		_sword_box(root, Vector3(0.062, 0.013, 0.062), Vector3(0, -0.052 - 0.033 * i, 0), band_mat)
	_sword_box(root, Vector3(0.085, 0.085, 0.085), Vector3(0, -0.212, 0), pommel_mat)
	_sword_box(root, Vector3(0.052, 0.052, 0.02), Vector3(0, -0.212, 0.048), edge_mat)
	if tier == 1:
		var grain_mat := _sword_mat(blade_col.darkened(0.3), 0.02, 0.0)
		_sword_box(root, Vector3(0.011, 0.33, 0.004), Vector3(-0.022, 0.2, 0.024), grain_mat)
		_sword_box(root, Vector3(0.009, 0.28, 0.004), Vector3(0.024, 0.24, 0.024), grain_mat)
		_sword_box(root, Vector3(0.008, 0.22, 0.004), Vector3(-0.004, 0.15, -0.024), grain_mat)
	elif tier == 2:
		var chip_mat := _sword_mat(Color("#59655f"), 0.04, 0.0)
		for p in [Vector2(-0.026, 0.12), Vector2(0.022, 0.23), Vector2(-0.01, 0.34)]:
			_sword_box(root, Vector3(0.017, 0.017, 0.004), Vector3(p.x, p.y, 0.024), chip_mat)
	elif tier >= 3:
		var accent := Color("#f0c570") if tier == 3 else Color("#ffffff")
		var accent_mat := _sword_mat(accent, 0.35 if tier == 3 else 0.95, 0.6)
		_sword_box(root, Vector3(0.028, 0.028, 0.1), Vector3(-0.12, 0.016, 0), accent_mat)
		_sword_box(root, Vector3(0.028, 0.028, 0.1), Vector3(0.12, 0.016, 0), accent_mat)
		if tier == 4:
			var gem := _sword_box(root, Vector3(0.046, 0.046, 0.046), Vector3(0, 0, 0.07), accent_mat)
			gem.rotation_degrees.y = 45.0
	return root

func _sword_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2
	parent.add_child(mi)
	return mi

func _sword_mat(color: Color, emission: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	mat.metallic = metallic
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func _build_highlight() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.88, 0.52, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var box := BoxMesh.new()
	box.size = Vector3(1.012, 1.012, 1.012)
	box.material = mat
	highlight = MeshInstance3D.new()
	highlight.mesh = box
	highlight.top_level = true
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	highlight.visible = false
	add_child(highlight)

func _build_particles() -> void:
	break_particles = CPUParticles3D.new()
	break_particles.amount = 16
	break_particles.lifetime = 0.55
	break_particles.one_shot = true
	break_particles.explosiveness = 0.9
	break_particles.direction = Vector3(0, 1, 0)
	break_particles.spread = 80.0
	break_particles.gravity = Vector3(0, -18, 0)
	break_particles.initial_velocity_min = 2.0
	break_particles.initial_velocity_max = 5.0
	break_particles.scale_amount_min = 0.7
	break_particles.scale_amount_max = 1.4
	var m := BoxMesh.new()
	m.size = Vector3(0.12, 0.12, 0.12)
	_particle_mat = StandardMaterial3D.new()
	_particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_particle_mat.albedo_color = Color("#7cc86a")
	m.material = _particle_mat
	break_particles.mesh = m
	break_particles.emitting = false
	break_particles.top_level = true
	add_child(break_particles)

func set_riding(monster: Node3D) -> void:
	riding_monster = monster
	_camera_base_y = 2.35
	Game.notify.emit("Riding. Press DISMOUNT to stop.", Color("#a9d8c8"))
	_refresh_held()

func stop_riding() -> void:
	if riding_monster != null and riding_monster.has_method("set_ridden"):
		riding_monster.set_ridden(false)
	riding_monster = null
	_camera_base_y = 1.62
	_refresh_held()
	Game.notify.emit("Dismounted.", Color("#cdc9b4"))

func _update_riding() -> void:
	if riding_monster == null:
		return
	if not is_instance_valid(riding_monster):
		riding_monster = null
		_camera_base_y = 1.62
		return
	riding_monster.global_position = Vector3(global_position.x, global_position.y - 0.6, global_position.z)
	riding_monster.rotation.y = yaw

# Additional combat polling happens inside physics for held attacks.
func _process(_delta: float) -> void:
	if primary_held and not get_tree().paused:
		_physics_attack_held()
	if riding_monster != null and not is_instance_valid(riding_monster):
		riding_monster = null
		_camera_base_y = 1.62
