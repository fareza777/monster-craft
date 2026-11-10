class_name Villager
extends CharacterBody3D

var world: VoxelWorld
var main: Node
var npc_id := ""
var npc_name := ""
var role := "villager"
var village_id := ""
var village_name := ""
var home := Vector3.ZERO
var wander_timer := 0.0
var wander_dir := Vector3.ZERO
var name_label: Label3D
var model: Node3D
var arm_l: Node3D
var arm_r: Node3D
var walk_time := 0.0
var player: Node3D
var bubble: Label3D
var bubble_time := 0.0
var bubble_cooldown := 0.0

func setup(data: Dictionary) -> void:
	npc_id = str(data.get("id", ""))
	npc_name = str(data.get("name", "Villager"))
	role = str(data.get("role", "villager"))
	village_id = str(data.get("village_id", ""))
	village_name = str(data.get("village_name", "Village"))
	home = global_position
	collision_layer = 2
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	var col := CollisionShape3D.new()
	col.shape = capsule
	col.position.y = 0.9
	add_child(col)
	_build_model()
	_build_label()
	_build_bubble()
	wander_timer = randf_range(0.5, 4.0)

func _build_label() -> void:
	name_label = Label3D.new()
	name_label.text = npc_name
	name_label.font_size = 28
	name_label.pixel_size = 0.004
	name_label.outline_size = 7
	name_label.outline_modulate = Color(0.02, 0.06, 0.05, 0.9)
	name_label.modulate = Color("#f2ebd4")
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.position = Vector3(0, 2.15, 0)
	add_child(name_label)

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Content.monster_material(color)
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var tunic := Color("#b56445")
	var pants := Color("#3d5560")
	var skin := Color("#e0b28a")
	var accent := Color("#e0c06a")
	match role:
		"elder":
			tunic = Color("#8b6b8e")
			accent = Color("#f0d59a")
		"merchant":
			tunic = Color("#4b8273")
			accent = Color("#e0b04a")
		"farmer":
			tunic = Color("#9b7b4a")
			accent = Color("#ddc58a")
	for ex in [-1.0, 1.0]:
		_box(model, Vector3(0.21, 0.48, 0.24), Vector3(ex * 0.14, 0.4, 0), pants.darkened(0.08))
		_box(model, Vector3(0.24, 0.12, 0.32), Vector3(ex * 0.14, 0.1, -0.03), Color("#5a4531"))
	_box(model, Vector3(0.56, 0.68, 0.38), Vector3(0, 0.9, 0), tunic)
	_box(model, Vector3(0.42, 0.22, 0.06), Vector3(0, 0.96, -0.22), tunic.lightened(0.12))
	_box(model, Vector3(0.06, 0.06, 0.04), Vector3(0, 0.9, -0.26), accent)
	_box(model, Vector3(0.42, 0.06, 0.4), Vector3(0, 0.7, 0), Color("#6b4d32"))
	# arms with simple pivots
	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.36, 1.18, 0)
	model.add_child(arm_l)
	_box(arm_l, Vector3(0.15, 0.55, 0.18), Vector3(0, -0.26, 0), tunic.darkened(0.08))
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.36, 1.18, 0)
	model.add_child(arm_r)
	_box(arm_r, Vector3(0.15, 0.55, 0.18), Vector3(0, -0.26, 0), tunic.darkened(0.08))
	_box(arm_l, Vector3(0.16, 0.14, 0.16), Vector3(0, -0.55, 0), skin)
	_box(arm_r, Vector3(0.16, 0.14, 0.16), Vector3(0, -0.55, 0), skin)
	# head
	_box(model, Vector3(0.4, 0.4, 0.38), Vector3(0, 1.52, 0), skin)
	_box(model, Vector3(0.07, 0.1, 0.04), Vector3(-0.1, 1.56, -0.205), Color("#2a211d"))
	_box(model, Vector3(0.07, 0.1, 0.04), Vector3(0.1, 1.56, -0.205), Color("#2a211d"))
	_box(model, Vector3(0.08, 0.09, 0.06), Vector3(0, 1.49, -0.22), skin.darkened(0.15))
	_box(model, Vector3(0.18, 0.04, 0.04), Vector3(0, 1.4, -0.205), Color("#7a4a3a"))
	_box(model, Vector3(0.32, 0.08, 0.06), Vector3(0, 1.34, -0.2), accent)
	match role:
		"elder":
			_box(model, Vector3(0.42, 0.14, 0.4), Vector3(0, 1.75, 0), Color("#e7e2d4"))
			_box(model, Vector3(0.2, 0.08, 0.06), Vector3(0, 1.32, -0.23), Color("#f6f0e4"))
			_box(arm_r, Vector3(0.06, 0.9, 0.06), Vector3(0.1, -0.75, 0), Color("#8a6a44"), Vector3(0, 0, -8))
		"merchant":
			_box(model, Vector3(0.48, 0.12, 0.44), Vector3(0, 1.76, 0), accent)
			_box(model, Vector3(0.35, 0.3, 0.2), Vector3(0, 1.0, 0.3), Color("#7a5b3c"))
			_box(model, Vector3(0.34, 0.26, 0.06), Vector3(0, 1.0, 0.42), Color("#5e452e"))
		"farmer":
			_box(model, Vector3(0.75, 0.06, 0.75), Vector3(0, 1.77, 0), Color("#d9c07a"))
			_box(model, Vector3(0.34, 0.2, 0.34), Vector3(0, 1.88, 0), Color("#c4a866"))
			_box(arm_r, Vector3(0.05, 0.7, 0.05), Vector3(0.03, -0.75, -0.05), Color("#7a5532"), Vector3(12, 0, 0))
			_box(arm_r, Vector3(0.18, 0.1, 0.05), Vector3(0.03, -1.06, -0.13), Color("#9aa0a3"))
		_:
			_box(model, Vector3(0.45, 0.1, 0.42), Vector3(0, 1.74, 0), Color("#6f4f39"))

func _physics_process(delta: float) -> void:
	_tick_bubble(delta)
	if player == null or not is_instance_valid(player):
		return
	if name_label != null:
		name_label.visible = global_position.distance_to(player.global_position) < 18.0
	var dist := global_position.distance_to(player.global_position)
	var target_yaw := rotation.y
	if dist < 5.0:
		var dir := player.global_position - global_position
		target_yaw = atan2(-dir.x, -dir.z)
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	else:
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = randf_range(2.5, 6.0)
			if randf() < 0.4 or Game.is_night():
				wander_dir = Vector3.ZERO
			else:
				var a := randf() * TAU
				wander_dir = Vector3(cos(a), 0, sin(a))
		if wander_dir.length() > 0.01 and global_position.distance_to(home) < 7.0:
			velocity.x = wander_dir.x * 1.4
			velocity.z = wander_dir.z * 1.4
			target_yaw = atan2(-wander_dir.x, -wander_dir.z)
		else:
			if global_position.distance_to(home) > 7.0:
				var back := (home - global_position)
				back.y = 0
				wander_dir = back.normalized() * 0.7
				velocity.x = wander_dir.x * 1.2
				velocity.z = wander_dir.z * 1.2
			else:
				velocity.x = move_toward(velocity.x, 0, 8.0 * delta)
				velocity.z = move_toward(velocity.z, 0, 8.0 * delta)
	rotation.y = lerp_angle(rotation.y, target_yaw, delta * 4.0)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	elif velocity.y < 0:
		velocity.y = -0.1
	move_and_slide()
	var speed := Vector2(velocity.x, velocity.z).length()
	walk_time += delta * (1.0 + speed * 1.8)
	if arm_l != null:
		arm_l.rotation.x = sin(walk_time * 3.0) * 0.25 * clampf(speed, 0.0, 1.5)
	if arm_r != null:
		arm_r.rotation.x = -sin(walk_time * 3.0) * 0.25 * clampf(speed, 0.0, 1.5)
	if model != null:
		model.position.y = abs(sin(walk_time * 2.4)) * 0.02 * clampf(speed, 0.0, 1.5)

func dialogue_data() -> Dictionary:
	return {"id": npc_id, "name": npc_name, "role": role, "village_id": village_id,
		"village_name": village_name}


func _build_bubble() -> void:
	bubble = Label3D.new()
	bubble.font_size = 22
	bubble.pixel_size = 0.0038
	bubble.outline_size = 8
	bubble.outline_modulate = Color(0.02, 0.05, 0.04, 0.95)
	bubble.modulate = Color("#f7f0d8")
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.position = Vector3(0, 2.62, 0)
	bubble.visible = false
	add_child(bubble)

func _tick_bubble(delta: float) -> void:
	bubble_cooldown = maxf(0.0, bubble_cooldown - delta)
	if bubble_time > 0.0:
		bubble_time -= delta
		if bubble_time <= 0.0 and bubble != null:
			bubble.visible = false
		return
	if bubble_cooldown > 0.0 or player == null or bubble == null:
		return
	if global_position.distance_to(player.global_position) > 5.0:
		return
	bubble.text = _bubble_line()
	bubble.visible = true
	bubble_time = 4.5
	bubble_cooldown = randf_range(11.0, 18.0)

func _bubble_line() -> String:
	var lines := {
		"elder": ["The vale is restless tonight.", "Bring me timber and I will ward the gate.", "You carry the valley's trust now."],
		"merchant": ["Fresh amber, fresh supplies!", "Iron for a fair price?", "Rift shards fetch a good coin."],
		"farmer": ["Rain would do the wheat good.", "Mind the crops, friend.", "Something big walked the field last night."],
		"villager": ["Rare beasts roam past the ridge.", "Did you see the obelisk glow?", "The old gate still hums at dusk."],
	}
	var pool: Array = lines.get(role, lines["villager"])
	return str(pool[randi_range(0, pool.size() - 1)])
