class_name MonsterEntity
extends CharacterBody3D

signal died(monster)
signal removed(monster)

var world: VoxelWorld
var main: Node
var spawner: Node
var species_id := ""
var sp: Dictionary = {}
var stats: Dictionary = {}
var level := 1
var variant := "normal"
var is_companion := false
var is_boss := false
var is_ridden := false
var party_index := -1
var wild_entry: Dictionary = {}
var hp := 10
var max_hp := 10
var dead := false
var ai_enabled := true
var aggro := false
var fleeing := false
var hover := false
var base_altitude := 0.0
var home := Vector3.ZERO
var wander_timer := 0.0
var wander_dir := Vector3.ZERO
var attack_timer := 0.0
var target_check := 0.0
var flee_timer := 0.0
var skill_cd := 0.0
var skill_cd_max := 8.0
var buff_timer := 0.0
var boss_skill_timer := 4.0
var model: MonsterModel
var name_label: Label3D
var bar_bg: Sprite3D
var bar_fill: Sprite3D
var label_timer := 0.0
var focused := false
var knock_timer := 0.0
var knock_velocity := Vector3.ZERO
var stuck_timer := 0.0
var last_pos := Vector3.ZERO
var display_name := ""
var anim_speed := 0.0

func setup(p_species: String, p_level: int, p_variant: String, p_companion: bool,
		p_party_index: int, p_boss: bool, p_world: VoxelWorld, p_main: Node, p_spawner: Node) -> void:
	species_id = p_species
	sp = Content.SPECIES.get(species_id, {})
	level = clampf(p_level, 1, 50)
	variant = p_variant
	is_companion = p_companion
	is_boss = p_boss
	party_index = p_party_index
	world = p_world
	main = p_main
	spawner = p_spawner
	hover = str(sp.get("shape", "quad")) in ["floater", "serpent"]
	stats = Content.monster_stats({"species": species_id, "level": level, "variant": variant})
	max_hp = int(stats.hp)
	if is_companion and party_index >= 0 and party_index < Game.party.size():
		var entry: Dictionary = Game.party[party_index]
		hp = clampi(int(entry.get("hp", max_hp)), 1, max_hp)
		display_name = str(entry.get("nickname", ""))
		if display_name == "":
			display_name = str(sp.get("name", species_id))
		hp = int(entry.get("hp", max_hp))
	else:
		hp = max_hp
		display_name = str(sp.get("name", species_id))
		wild_entry = {"species": species_id, "level": level, "variant": variant,
			"hp": hp, "uid": "wild_%d_%d" % [Time.get_ticks_usec(), randi()]}
	collision_layer = 2
	collision_mask = 1
	var min_scale: float = float(sp.get("scale", 0.8)) * (1.5 if is_boss else 1.0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = clampf(0.34 * min_scale, 0.24, 0.9)
	capsule.height = clampf(1.1 * min_scale, 0.7, 2.6)
	var col := CollisionShape3D.new()
	col.shape = capsule
	col.position.y = capsule.height * 0.5 + (0.5 if hover else 0.03)
	add_child(col)
	if hover:
		collision_layer = 0
		collision_mask = 0
	model = MonsterModel.new()
	add_child(model)
	model.build(species_id, variant, is_boss)
	model.base_hover = 0.55 if hover else 0.0
	_build_labels()
	skill_cd_max = float(sp.get("cooldown", 8.0))
	if is_boss:
		ai_enabled = true
	home = global_position
	if hover:
		base_altitude = global_position.y
	wander_timer = randf_range(0.5, 3.0)
	last_pos = global_position

func _build_labels() -> void:
	name_label = Label3D.new()
	name_label.text = _label_text()
	name_label.font_size = 30
	name_label.pixel_size = 0.0042
	name_label.outline_size = 8
	name_label.outline_modulate = Color(0.03, 0.07, 0.06, 0.9)
	name_label.modulate = Color("#f4efd9")
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	var label_y := float(sp.get("scale", 0.8)) * (2.0 if not is_boss else 2.6) + 0.35
	name_label.position = Vector3(0, label_y, 0)
	add_child(name_label)
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(white)
	bar_bg = Sprite3D.new()
	bar_bg.texture = tex
	bar_bg.modulate = Color(0.03, 0.06, 0.06, 0.8)
	bar_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar_bg.no_depth_test = true
	bar_bg.pixel_size = 0.01
	bar_bg.scale = Vector3(62, 6, 1)
	bar_bg.position = Vector3(0, label_y - 0.24, 0)
	bar_bg.visible = false
	add_child(bar_bg)
	bar_fill = Sprite3D.new()
	bar_fill.texture = tex
	bar_fill.modulate = Color("#74d68a")
	bar_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar_fill.no_depth_test = true
	bar_fill.pixel_size = 0.01
	bar_fill.scale = Vector3(58, 4, 1)
	bar_fill.position = Vector3(0, label_y - 0.24, 0.01)
	bar_fill.visible = false
	add_child(bar_fill)

func _label_text() -> String:
	var label := "Lv%d %s" % [level, display_name]
	if is_boss:
		label = "BOSS • " + label
	elif variant == "shiny":
		label = "Shiny • " + label
	return label

func _ready() -> void:
	if is_companion and is_ridden:
		ai_enabled = false

func _physics_process(delta: float) -> void:
	if dead:
		return
	skill_cd = maxf(0.0, skill_cd - delta)
	buff_timer = maxf(0.0, buff_timer - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	label_timer -= delta
	if label_timer <= 0.0:
		label_timer = 0.2
		_update_labels()
	if not ai_enabled or is_ridden:
		velocity = Vector3.ZERO
		return
	target_check -= delta
	if is_companion:
		_companion_ai(delta)
	else:
		_wild_ai(delta)
	# gravity and movement
	if hover:
		velocity.y = 0.0
		var target_y := base_altitude
		if is_companion and main != null and is_instance_valid(main.player):
			target_y = main.player.global_position.y + 1.05
		global_position.y = lerpf(global_position.y, target_y, delta * 3.0)
	else:
		if not is_on_floor():
			velocity.y -= 24.0 * delta
		elif velocity.y < 0.0:
			velocity.y = -0.1
	if knock_timer > 0.0:
		knock_timer -= delta
		velocity.x = knock_velocity.x
		velocity.z = knock_velocity.z
		knock_velocity = knock_velocity.lerp(Vector3.ZERO, delta * 6.0)
	move_and_slide()
	anim_speed = Vector2(velocity.x, velocity.z).length()
	if global_position.y < -6.0:
		_die(true)

func _process(delta: float) -> void:
	if dead or model == null:
		return
	model.animate(delta, anim_speed)
	anim_speed = lerpf(anim_speed, 0.0, delta * 5.0)

func _update_labels() -> void:
	if name_label == null:
		return
	var dist := 999.0
	if main != null and is_instance_valid(main.player):
		dist = global_position.distance_to(main.player.global_position)
	var show_name := (focused or hp < max_hp or is_boss) and not is_ridden
	name_label.visible = show_name
	name_label.text = _label_text()
	var show_bar := not is_ridden and (focused or hp < max_hp or is_boss)
	bar_bg.visible = show_bar
	bar_fill.visible = show_bar
	if show_bar:
		var ratio := clampf(float(hp) / maxf(1.0, float(max_hp)), 0.0, 1.0)
		bar_fill.scale.x = 58.0 * ratio
		if ratio > 0.55:
			bar_fill.modulate = Color("#74d68a")
		elif ratio > 0.25:
			bar_fill.modulate = Color("#f0c55a")
		else:
			bar_fill.modulate = Color("#e06a5a")
	if is_boss and main != null and main.has_method("update_boss_bar"):
		main.update_boss_bar(self)

func set_focused(value: bool) -> void:
	focused = value

func _player() -> Node3D:
	if main != null and is_instance_valid(main.player):
		return main.player
	return null

func _companion_node() -> Node3D:
	if main != null and main.has_method("get_companion_node"):
		return main.get_companion_node()
	return null

func _companion_ai(delta: float) -> void:
	var player := _player()
	if player == null:
		return
	var enemy = null
	if main.has_method("get_nearest_enemy_for"):
		enemy = main.get_nearest_enemy_for(self, 13.0)
	if enemy != null and is_instance_valid(enemy) and not enemy.dead:
		var d2: float = global_position.distance_to(enemy.global_position)
		var range2: float = 1.9 + float(sp.get("scale", 0.8)) * 0.5
		if d2 > range2:
			_move_toward(enemy.global_position, delta, float(stats.spd) * 1.35 + 2.0)
		else:
			velocity.x = move_toward(velocity.x, 0, 22.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 22.0 * delta)
			_face_towards(enemy.global_position, delta)
			if attack_timer <= 0.0:
				attack_timer = 1.05
				_attack_target(enemy)
	else:
		var dist := global_position.distance_to(player.global_position)
		var yaw := player.rotation.y
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var follow := player.global_position - fwd * 2.7 + right * 1.1
		if dist > 24.0:
			global_position = follow + Vector3(0, 0.4, 0)
			velocity = Vector3.ZERO
		elif dist > 3.4:
			_move_toward(follow, delta, float(stats.spd) * 1.15 + 1.2)
		else:
			velocity.x = move_toward(velocity.x, 0, 18.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 18.0 * delta)
			_face_towards(player.global_position, delta, 0.5)

func _wild_ai(delta: float) -> void:
	var player := _player()
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	var comp := _companion_node()
	var target: Node3D = player
	if comp != null and is_instance_valid(comp):
		if global_position.distance_to(comp.global_position) + 1.0 < dist:
			target = comp
	if is_boss:
		aggro = true
	if not aggro and bool(sp.get("aggro", false)) and dist < 13.0:
		aggro = true
	if aggro and dist > 28.0:
		aggro = false
		fleeing = false
	if fleeing:
		flee_timer -= delta
		if flee_timer <= 0.0:
			fleeing = false
		else:
			var away := (global_position - target.global_position).normalized()
			_move_toward(global_position + away * 4.0, delta, float(stats.spd) * 1.2)
			return
	if aggro and target != null:
		var td := global_position.distance_to(target.global_position)
		var atk_range := 1.8 + float(sp.get("scale", 0.8)) * 0.55
		if td > atk_range:
			_move_toward(target.global_position, delta, float(stats.spd) * 1.05)
		else:
			velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 20.0 * delta)
			_face_towards(target.global_position, delta)
			if attack_timer <= 0.0:
				attack_timer = 1.35 if not is_boss else 1.0
				_attack_target(target)
		if is_boss:
			boss_skill_timer -= delta
			if boss_skill_timer <= 0.0:
				boss_skill_timer = 6.5
				_cast_boss_skill()
		return
	# wander
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.2, 5.0)
		if randf() < 0.35:
			wander_dir = Vector3.ZERO
		else:
			var a := randf() * TAU
			wander_dir = Vector3(cos(a), 0, sin(a))
	if wander_dir.length() > 0.01:
		var next := global_position + wander_dir * 1.4
		if _safe_step(next):
			_move_toward(global_position + wander_dir * 3.0, delta, float(stats.spd) * 0.4)
		else:
			wander_dir = -wander_dir
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)

func _safe_step(next: Vector3) -> bool:
	if world == null:
		return true
	var b := world.block_at_float(next + Vector3(0, 0.4, 0))
	return not Content.is_liquid(b)

func _move_toward(target: Vector3, delta: float, speed: float) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() < 0.15:
		return
	dir = dir.normalized()
	var desired := dir * speed
	velocity.x = move_toward(velocity.x, desired.x, 18.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z, 18.0 * delta)
	_face_towards(global_position + dir, delta)

func _face_towards(target: Vector3, delta: float, strength: float = 1.0) -> void:
	var dir := target - global_position
	dir.y = 0
	if dir.length_squared() < 0.001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 8.0 * strength, 0.0, 1.0))

func _attack_target(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	model.lunge_forward(Vector3(0, 0, -1))
	var dmg := int(float(stats.atk) * 1.05 + float(level) * 0.65)
	if is_boss:
		dmg = int(dmg * 1.35)
	if buff_timer > 0.0:
		dmg = int(dmg * 1.3)
	if target == _player():
		if target.has_method("_take_damage"):
			target._take_damage(dmg, "monster")
	elif target.has_method("take_damage"):
		target.take_damage(dmg, "monster")
	if main != null and main.has_method("spawn_hit_fx"):
		main.spawn_hit_fx(target.global_position + Vector3(0, 0.9, 0), Content.element_color(str(sp.get("element", "Nature"))))
	Sfx.play("hit", 0.15)

func take_damage(amount: int, source: String = "player") -> void:
	if dead:
		return
	var reduction := int(float(stats.get("def", 3)) * 0.32)
	var dmg := maxi(1, amount - reduction)
	hp = maxi(0, hp - dmg)
	model.squash()
	if main != null and main.has_method("show_damage_number"):
		main.show_damage_number(global_position + Vector3(randf_range(-0.3, 0.3), 1.4, 0), dmg, Color("#ffe7a0"))
	if not is_companion:
		aggro = true
		wild_entry.hp = hp
		if not bool(sp.get("aggro", false)):
			fleeing = true
			flee_timer = 4.0
	else:
		if party_index >= 0 and party_index < Game.party.size():
			Game.party[party_index].hp = hp
			Game.party_changed.emit()
	if hp <= 0:
		_die(false)

func apply_knockback(dir: Vector3, strength: float) -> void:
	if hover:
		return
	dir.y = 0
	knock_velocity = dir.normalized() * strength
	knock_timer = 0.18

func _die(fell: bool) -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	if is_companion:
		if party_index >= 0 and party_index < Game.party.size():
			Game.party[party_index].hp = 0
			Game.party_changed.emit()
		Game.notify.emit("%s is exhausted and falls back. Feed it to restore." % display_name, Color("#ff9b8a"))
		if main != null and main.has_method("on_companion_fainted"):
			main.on_companion_fainted(self)
	else:
		if not fell:
			Game.monster_killed(wild_entry)
			var mult: float = Game.drop_multiplier()
			for d in Content.roll_drops(species_id):
				var n := int(d.n)
				if mult > 1.0:
					n = int(ceil(float(n) * mult))
				if main != null and main.has_method("spawn_item_drop"):
					main.spawn_item_drop(str(d.id), n, global_position + Vector3(0, 0.6, 0))
			if main != null and main.has_method("on_wild_monster_died"):
				main.on_wild_monster_died(self)
		died.emit(self)
	model.death_animation()
	name_label.visible = false
	bar_bg.visible = false
	bar_fill.visible = false
	Sfx.play("roar" if is_boss else "hit", 0.2)
	if is_boss and main != null and main.has_method("hide_boss_bar"):
		main.hide_boss_bar()
	await get_tree().create_timer(0.65).timeout
	queue_free()

func attempt_capture(orb_mult: float) -> Dictionary:
	if dead or is_companion:
		return {"ok": false, "chance": 0.0}
	wild_entry.hp = hp
	var res := Game.capture_monster(wild_entry, orb_mult)
	if res.ok:
		dead = true
		collision_layer = 0
		collision_mask = 0
		model.death_animation()
		name_label.visible = false
		bar_bg.visible = false
		bar_fill.visible = false
		died.emit(self)
		get_tree().create_timer(0.55).timeout.connect(queue_free)
	else:
		aggro = true
		fleeing = false
	return res

func attempt_tame() -> Dictionary:
	if dead or is_companion:
		return {"ok": false}
	wild_entry.hp = hp
	var chance := Content.catch_chance(species_id, level, float(hp) / maxf(1.0, float(max_hp)), 1.4)
	chance = clampf(chance + 0.15, 0.05, 0.95)
	if randf() <= chance:
		var caught := wild_entry.duplicate(true)
		caught.hp = max_hp
		caught.bond = 10
		caught.xp = 0
		caught.uid = "%s_%d" % [species_id, randi()]
		Game.add_monster(caught, true)
		Game.notify.emit("%s was tamed!" % display_name, Color("#ffe08a"))
		Sfx.play("capture")
		dead = true
		collision_layer = 0
		collision_mask = 0
		model.death_animation()
		died.emit(self)
		get_tree().create_timer(0.5).timeout.connect(queue_free)
		return {"ok": true}
	aggro = true
	if not bool(sp.get("aggro", false)):
		fleeing = true
		flee_timer = 3.0
	return {"ok": false, "chance": chance}

func use_skill(forced_target: Node3D = null) -> bool:
	if dead or skill_cd > 0.0:
		return false
	skill_cd = skill_cd_max
	model.lunge_forward(Vector3(0, 0, -1))
	var color := Content.element_color(str(sp.get("element", "Nature")))
	var kind := str(sp.get("skill", "projectile"))
	var power := int(sp.get("power", 10)) + int(float(stats.atk) * 0.7)
	var target: Node3D = forced_target
	if target == null or not is_instance_valid(target):
		if is_companion and main != null and main.has_method("get_nearest_enemy_for"):
			target = main.get_nearest_enemy_for(self, 13.0)
			if target == null:
				target = _player()
	match kind:
		"heal":
			hp = mini(max_hp, hp + int(power * 1.8))
			if is_companion and party_index >= 0:
				Game.party[party_index].hp = hp
				Game.heal_player(int(power * 0.7))
			if main != null and main.has_method("spawn_skill_heal"):
				main.spawn_skill_heal(global_position + Vector3(0, 0.8, 0), color)
			if is_companion:
				Game.notify.emit("%s used Healing Light." % display_name, color)
		"aoe":
			var radius := 4.5
			if main != null:
				main.spawn_skill_aoe(global_position, radius, color)
				if is_companion:
					for enemy in main.get_enemy_targets_in_radius(global_position, radius):
						if enemy != null and is_instance_valid(enemy) and not enemy.dead:
							enemy.take_damage(power, "companion")
				else:
					var p := _player()
					if p != null and p.global_position.distance_to(global_position) < radius:
						p._take_damage(int(power * 0.9), "monster")
					var c := _companion_node()
					if c != null and c.global_position.distance_to(global_position) < radius:
						c.take_damage(int(power * 0.9), "monster")
		"buff":
			buff_timer = 8.0
			speed_bonus_aura()
			if main != null and main.has_method("spawn_skill_aoe"):
				main.spawn_skill_aoe(global_position, 2.4, color)
			if is_companion:
				Game.notify.emit("%s empowered the team." % display_name, color)
		"dash":
			if target != null and is_instance_valid(target):
				var dir: Vector3 = target.global_position - global_position
				dir.y = 0
				if dir.length() > 0.1:
					dir = dir.normalized()
					global_position += dir * 1.2
					velocity += dir * 4.0
				if target.has_method("take_damage"):
					target.take_damage(power, "companion" if is_companion else "monster")
			if main != null and main.has_method("spawn_skill_aoe"):
				main.spawn_skill_aoe(global_position, 1.8, color)
		_:
			if target != null and is_instance_valid(target):
				var from := global_position + Vector3(0, 1.1, 0)
				var to: Vector3 = target.global_position + Vector3(0, 0.8, 0)
				if main != null and main.has_method("spawn_skill_projectile"):
					main.spawn_skill_projectile(from, to, color)
				await get_tree().create_timer(0.28).timeout
				if is_instance_valid(target) and not target.dead:
					if target.has_method("take_damage"):
						if target == _player():
							target._take_damage(int(power * 0.8), "monster")
						else:
							target.take_damage(power, "companion" if is_companion else "monster")
			elif main != null and main.has_method("spawn_skill_projectile"):
				main.spawn_skill_projectile(global_position + Vector3(0, 1.0, 0),
					global_position + -global_transform.basis.z * 4.0 + Vector3(0, 1.0, 0), color)
	if is_companion:
		Game.party_changed.emit()
	Sfx.play("roar" if is_boss else "hit", 0.1)
	return true

func speed_bonus_aura() -> void:
	pass

func _cast_boss_skill() -> void:
	var color := Content.element_color(str(sp.get("element", "Nature")))
	var player := _player()
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	if dist < 7.0:
		if main != null and main.has_method("spawn_skill_aoe"):
			main.spawn_skill_aoe(global_position, 5.0, color)
		player._take_damage(int(float(stats.atk) * 1.1 + 8), "monster")
		var comp := _companion_node()
		if comp != null and comp.global_position.distance_to(global_position) < 5.0:
			comp.take_damage(int(float(stats.atk) * 0.9), "monster")
		Game.notify.emit("%s released an energy wave!" % display_name, color)
	elif dist < 14.0:
		if main != null and main.has_method("spawn_skill_projectile"):
			main.spawn_skill_projectile(global_position + Vector3(0, 1.2, 0),
				player.global_position + Vector3(0, 0.9, 0), color)
		player._take_damage(int(float(stats.atk) * 0.75 + 6), "monster")
	Sfx.play("roar", 0.1)

func set_ridden(value: bool) -> void:
	is_ridden = value
	ai_enabled = not value
	velocity = Vector3.ZERO
	collision_layer = 0 if value else 2
	collision_mask = 0 if value else 1
	name_label.visible = not value
	bar_bg.visible = false
	bar_fill.visible = false
	if not value:
		home = global_position
		base_altitude = global_position.y

func capture_ratio() -> float:
	return float(hp) / maxf(1.0, float(max_hp))

func is_capturable() -> bool:
	return not is_companion and not dead and capture_ratio() <= 0.42

func skill_ratio() -> float:
	if skill_cd_max <= 0.0:
		return 1.0
	return clampf(1.0 - skill_cd / skill_cd_max, 0.0, 1.0)

func set_base_altitude_from_ground() -> void:
	if hover:
		base_altitude = global_position.y
