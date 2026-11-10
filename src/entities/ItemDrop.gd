class_name ItemDrop
extends Node3D

var item_id := ""
var count := 1
var life := 0.0
var player: Node3D
var collected := false
var mesh: Node3D
var count_label: Label3D

func setup(p_item: String, p_count: int, p_player: Node3D) -> void:
	item_id = p_item
	count = p_count
	player = p_player
	var item: Dictionary = Content.ITEMS.get(item_id, {})
	var color := Color("#d7c9a3")
	if item.get("type", "") == "block":
		color = Content.block_color(int(item.get("block", -1)))
	else:
		color = Content._as_color(item.get("color", "#d7c9a3"))
	mesh = _build_visual(item, color)
	mesh.position = Vector3(0, 0.22, 0)
	add_child(mesh)
	if count > 1:
		count_label = Label3D.new()
		count_label.text = "x%d" % count
		count_label.font_size = 28
		count_label.pixel_size = 0.005
		count_label.outline_size = 5
		count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		count_label.position = Vector3(0, 0.3, 0)
		count_label.modulate = Color("#f6f0d8")
		add_child(count_label)
	if item_id in ["crystal", "amber", "monster_core", "rift_key", "orb_great", "orb", "torch"]:
		var light := OmniLight3D.new()
		light.light_energy = 0.3
		light.omni_range = 1.5
		light.light_color = color if item_id != "torch" else Color("#f6c56a")
		add_child(light)

func _cube(parent: Node3D, size: Vector3, pos: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.9
	box.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _tier_color(tier: int) -> Color:
	match tier:
		1:
			return Color("#b98a4e")
		2:
			return Color("#9aa5a9")
		3:
			return Color("#ccd6da")
	return Color("#6fe4d4")

func _build_visual(item: Dictionary, color: Color) -> Node3D:
	var root := Node3D.new()
	var itype := str(item.get("type", ""))
	var kind := str(item.get("tool_kind", ""))
	var tier := int(item.get("tier", 1))
	var wood := Color("#7a542c")
	var wood_dark := Color("#55391f")
	if item_id == "torch":
		_cube(root, Vector3(0.035, 0.23, 0.035), Vector3(0, -0.02, 0), wood)
		_cube(root, Vector3(0.05, 0.02, 0.05), Vector3(0, 0.04, 0), wood_dark)
		_cube(root, Vector3(0.07, 0.07, 0.07), Vector3(0, 0.11, 0), Color("#3a2a18"))
		var flame := _cube(root, Vector3(0.062, 0.075, 0.062), Vector3(0, 0.17, 0), Color("#f6c05a"), true)
		flame.rotation_degrees.y = 45.0
	elif kind == "sword":
		var blade := _tier_color(tier)
		_cube(root, Vector3(0.055, 0.26, 0.03), Vector3(0, 0.09, 0), blade)
		_cube(root, Vector3(0.02, 0.24, 0.034), Vector3(0, 0.09, 0.002), blade.lightened(0.25))
		_cube(root, Vector3(0.135, 0.028, 0.045), Vector3(0, -0.05, 0), wood_dark)
		_cube(root, Vector3(0.04, 0.1, 0.04), Vector3(0, -0.11, 0), Color("#402812"))
		_cube(root, Vector3(0.055, 0.05, 0.055), Vector3(0, -0.17, 0), blade.darkened(0.2))
	elif kind != "":
		var head := _tier_color(tier)
		_cube(root, Vector3(0.03, 0.25, 0.03), Vector3(0, -0.01, 0), wood)
		if kind == "pick":
			_cube(root, Vector3(0.2, 0.035, 0.038), Vector3(0, 0.12, 0), head)
			for side in [-1.0, 1.0]:
				var tip := _cube(root, Vector3(0.075, 0.035, 0.038), Vector3(side * 0.11, 0.1, 0), head)
				tip.rotation_degrees.z = side * 32.0
		elif kind == "axe":
			_cube(root, Vector3(0.075, 0.115, 0.032), Vector3(0.05, 0.115, 0), head)
			_cube(root, Vector3(0.022, 0.115, 0.038), Vector3(0.093, 0.115, 0), head.lightened(0.28))
			_cube(root, Vector3(0.05, 0.05, 0.05), Vector3(-0.01, 0.115, 0), wood_dark)
		elif kind == "shovel":
			_cube(root, Vector3(0.055, 0.045, 0.045), Vector3(0, 0.12, 0), wood_dark)
			_cube(root, Vector3(0.105, 0.1, 0.026), Vector3(0, 0.17, 0.004), head)
			_cube(root, Vector3(0.115, 0.02, 0.032), Vector3(0, 0.225, 0.004), head.lightened(0.25))
		elif kind == "hoe":
			_cube(root, Vector3(0.04, 0.055, 0.04), Vector3(0, 0.115, 0), wood_dark)
			_cube(root, Vector3(0.115, 0.026, 0.032), Vector3(0.055, 0.135, 0), head)
			_cube(root, Vector3(0.022, 0.06, 0.032), Vector3(0.105, 0.108, 0), head.lightened(0.22))
		else:
			_cube(root, Vector3(0.07, 0.11, 0.07), Vector3(0, 0.13, 0), head)
	elif itype == "block":
		_cube(root, Vector3(0.19, 0.19, 0.19), Vector3.ZERO, color)
	elif itype == "orb":
		var sphere := SphereMesh.new()
		sphere.radius = 0.095
		sphere.height = 0.19
		sphere.radial_segments = 12
		sphere.rings = 6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.1
		mat.roughness = 0.4
		sphere.material = mat
		var orb := MeshInstance3D.new()
		orb.mesh = sphere
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(orb)
		_cube(root, Vector3(0.11, 0.03, 0.11), Vector3(0, 0, 0), color.lightened(0.3), true)
	elif itype == "food":
		if item_id == "potion":
			_cube(root, Vector3(0.105, 0.13, 0.105), Vector3(0, -0.01, 0), color)
			_cube(root, Vector3(0.045, 0.07, 0.045), Vector3(0, 0.09, 0), Color("#9fd6c4"))
			_cube(root, Vector3(0.055, 0.025, 0.055), Vector3(0, 0.135, 0), Color("#7a542c"))
			_cube(root, Vector3(0.075, 0.02, 0.075), Vector3(0, 0.045, 0), color.lightened(0.3))
		else:
			_cube(root, Vector3(0.12, 0.12, 0.12), Vector3(0, 0.02, 0), color)
			_cube(root, Vector3(0.075, 0.075, 0.075), Vector3(-0.06, -0.05, 0.03), color.darkened(0.15))
			_cube(root, Vector3(0.06, 0.06, 0.06), Vector3(0.06, -0.04, -0.03), color.lightened(0.12))
			_cube(root, Vector3(0.03, 0.045, 0.03), Vector3(0, 0.1, 0), Color("#6fae5c"))
	elif item_id in ["iron_ingot", "gold_ingot"]:
		_cube(root, Vector3(0.19, 0.065, 0.115), Vector3.ZERO, color)
		_cube(root, Vector3(0.145, 0.028, 0.07), Vector3(0, 0.045, 0), color.lightened(0.32))
	elif item_id in ["crystal", "amber", "monster_core", "rift_key"]:
		var gem := _cube(root, Vector3(0.13, 0.13, 0.13), Vector3.ZERO, color, true)
		gem.rotation_degrees = Vector3(35, 45, 0)
		_cube(root, Vector3(0.05, 0.05, 0.05), Vector3(0.05, 0.05, 0), color.lightened(0.4), true)
	elif item_id in ["seeds", "wheat", "fiber"]:
		_cube(root, Vector3(0.16, 0.045, 0.115), Vector3.ZERO, color)
		_cube(root, Vector3(0.055, 0.085, 0.055), Vector3(0.025, 0.05, 0), color.lightened(0.22))
		_cube(root, Vector3(0.04, 0.06, 0.04), Vector3(-0.05, 0.04, 0.01), color.darkened(0.12))
	elif item_id == "leather":
		_cube(root, Vector3(0.18, 0.04, 0.14), Vector3.ZERO, color)
		_cube(root, Vector3(0.12, 0.022, 0.085), Vector3(0, 0.03, 0), color.lightened(0.26))
	elif item_id == "stick":
		_cube(root, Vector3(0.035, 0.25, 0.035), Vector3.ZERO, color)
		_cube(root, Vector3(0.038, 0.02, 0.038), Vector3(0, 0.06, 0), color.darkened(0.2))
	elif item_id == "feed":
		_cube(root, Vector3(0.155, 0.14, 0.155), Vector3.ZERO, color)
		_cube(root, Vector3(0.175, 0.03, 0.175), Vector3(0, 0.08, 0), color.darkened(0.28))
		_cube(root, Vector3(0.06, 0.05, 0.06), Vector3(0, 0.1, 0), color.lightened(0.2))
	elif item_id == "saddle":
		_cube(root, Vector3(0.18, 0.06, 0.14), Vector3.ZERO, color)
		_cube(root, Vector3(0.05, 0.1, 0.14), Vector3(0.065, 0.055, 0), color.lightened(0.22))
		_cube(root, Vector3(0.03, 0.05, 0.03), Vector3(-0.06, 0.06, 0), Color("#e3c06b"))
	else:
		_cube(root, Vector3(0.16, 0.16, 0.16), Vector3.ZERO, color)
	root.rotation_degrees = Vector3(0, 14, 6)
	return root

func _process(delta: float) -> void:
	life += delta
	rotation.y += delta * 2.2
	if mesh != null:
		mesh.position.y = 0.22 + sin(life * 3.0) * 0.05
	if player != null and is_instance_valid(player) and not collected:
		var d := global_position.distance_to(player.global_position + Vector3(0, 0.7, 0))
		if life > 0.35 and d < 4.0:
			global_position = global_position.lerp(player.global_position + Vector3(0, 0.7, 0), delta * 5.5)
		if life > 0.45 and d < 1.35:
			var left := Game.add_item(item_id, count, true)
			if left <= 0:
				Sfx.play("pickup", 0.08)
				collected = true
				queue_free()
			elif left < count:
				count = left
				if count_label != null:
					count_label.text = "x%d" % count
					if count <= 1:
						count_label.visible = false
	if life > 90.0:
		queue_free()
