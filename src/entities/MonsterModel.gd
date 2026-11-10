class_name MonsterModel
extends Node3D
## Procedural blocky monster. Each archetype has a different silhouette and the
## element adds readable decorations, so all species are original and cheap.

var species_id := ""
var sp: Dictionary = {}
var colors: Dictionary = {}
var shape := "quad"
var variant := "normal"
var boss := false
var pattern := ""
var legs: Array[Node3D] = []
var wings: Array[Node3D] = []
var tails: Array[Node3D] = []
var head: MeshInstance3D
var body: MeshInstance3D
var hover := false
var time := 0.0
var base_hover := 0.0
var blob: MeshInstance3D

func build(p_species: String, p_variant: String = "normal", p_boss: bool = false) -> void:
	species_id = p_species
	variant = p_variant
	boss = p_boss
	sp = Content.SPECIES.get(species_id, {})
	if sp.is_empty():
		return
	colors = (sp.colors as Dictionary).duplicate()
	if variant == "shiny":
		colors.accent = Color("#ffd76a")
		colors.eye = Color("#5d3b0e")
	shape = str(sp.shape)
	pattern = _pattern_for_element(str(sp.get("element", "Nature")))
	var s: float = float(sp.get("scale", 0.8)) * (1.55 if boss else 1.0)
	scale = Vector3(s, s, s)
	_build_blob()
	match shape:
		"quad": _build_quad()
		"biped": _build_biped()
		"floater": _build_floater()
		"serpent": _build_serpent()
		"golem": _build_golem()
		"insect": _build_insect()
		_: _build_quad()
	_decorate()
	if boss:
		_add_boss_light()
	_finish_colors()

func _build_blob() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0.22)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	blob = MeshInstance3D.new()
	blob.mesh = quad
	blob.rotation_degrees.x = -90
	blob.position = Vector3(0, 0.035, 0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)


func _pattern_for_element(el: String) -> String:
	match el:
					"Fire":
									return "ember"
					"Frost":
									return "crystal"
					"Water":
									return "scale"
					"Stone":
									return "crack"
					"Sand":
									return "sand"
					"Spark":
									return "spark"
					"Toxic":
									return "spore"
					"Void":
									return "void"
					"Shadow":
									return "void"
					"Light":
									return "crystal"
					"Wind":
									return "fur"
	return "fur"

func _base() -> Color:
	return colors.get("body", Color("#7cc86a"))

func _belly() -> Color:
	return colors.get("belly", Color("#f1e4bf"))

func _accent() -> Color:
	return colors.get("accent", Color("#ffcf6b"))

func _eyes() -> Color:
	return colors.get("eye", Color("#243b2c"))

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color,
		rot: Vector3 = Vector3.ZERO, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := Content.monster_material(color, emissive, 1.0, pattern)
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if maxf(size.x, maxf(size.y, size.z)) >= 0.28 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _box_offset(parent: Node3D, size: Vector3, offset: Vector3, color: Color,
		rot: Vector3 = Vector3.ZERO, emissive: bool = false) -> MeshInstance3D:
	var pivot := Node3D.new()
	parent.add_child(pivot)
	var m := _box(pivot, size, offset, color, rot, emissive)
	return m

func _face(head_pos: Vector3, head_size: Vector3) -> void:
	var front := head_pos.z - head_size.z * 0.5 - 0.012
	for ex in [-1.0, 1.0]:
		var wx: float = head_pos.x + ex * head_size.x * 0.21
		_box(self, Vector3(0.145, 0.17, 0.05), Vector3(wx, head_pos.y + head_size.y * 0.12, front), Color("#f6efd8"))
		_box(self, Vector3(0.065, 0.11, 0.035), Vector3(wx + ex * 0.01, head_pos.y + head_size.y * 0.10, front - 0.025), _eyes())
	_box(self, Vector3(0.16, 0.045, 0.03), Vector3(head_pos.x, head_pos.y - head_size.y * 0.24, front), _eyes())
	_box(self, Vector3(0.15, 0.12, 0.04), Vector3(head_pos.x, head_pos.y - head_size.y * 0.12, front - 0.004), _belly())
	_box(self, Vector3(0.05, 0.04, 0.02), Vector3(head_pos.x - 0.055, head_pos.y - head_size.y * 0.1, front - 0.03), _eyes())
	_box(self, Vector3(0.05, 0.04, 0.02), Vector3(head_pos.x + 0.055, head_pos.y - head_size.y * 0.1, front - 0.03), _eyes())
	for ex in [-1.0, 1.0]:
		_box(self, Vector3(0.09, 0.035, 0.02), Vector3(head_pos.x + ex * head_size.x * 0.33, head_pos.y - 0.02, front - 0.01), _accent().darkened(0.15))

func _leg(pos: Vector3, size: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos + Vector3(0, size.y * 0.5, 0)
	add_child(pivot)
	_box(pivot, size, Vector3(0, -size.y * 0.5, 0), _base().darkened(0.14))
	legs.append(pivot)

func _build_quad() -> void:
	body = _box(self, Vector3(0.86, 0.62, 1.12), Vector3(0, 0.8, 0.03), _base())
	_box(self, Vector3(0.58, 0.38, 0.06), Vector3(0, 0.72, -0.57), _belly())
	head = _box(self, Vector3(0.66, 0.6, 0.62), Vector3(0, 1.16, -0.53), _base())
	_box(self, Vector3(0.34, 0.24, 0.2), Vector3(0, 1.03, -0.89), _belly())
	_face(Vector3(0, 1.16, -0.53), Vector3(0.66, 0.6, 0.62))
	legs = []
	_leg(Vector3(-0.3, 0.5, -0.35), Vector3(0.2, 0.5, 0.24))
	_leg(Vector3(0.3, 0.5, -0.35), Vector3(0.2, 0.5, 0.24))
	_leg(Vector3(-0.3, 0.5, 0.4), Vector3(0.2, 0.5, 0.24))
	_leg(Vector3(0.3, 0.5, 0.4), Vector3(0.2, 0.5, 0.24))
	var tail_pivot := Node3D.new()
	tail_pivot.position = Vector3(0, 0.9, 0.58)
	add_child(tail_pivot)
	_box(tail_pivot, Vector3(0.16, 0.16, 0.48), Vector3(0, 0.05, 0.22), _base().darkened(0.08))
	_box(tail_pivot, Vector3(0.12, 0.12, 0.18), Vector3(0, 0.1, 0.48), _accent())
	tails.append(tail_pivot)
	var ear := _accent()
	for ex in [-1.0, 1.0]:
		_box(self, Vector3(0.15, 0.24, 0.09), Vector3(ex * 0.23, 1.47, -0.45), ear, Vector3(0, 0, ex * 18.0))
	# back ridge
	for z in [-0.1, 0.18]:
		_box(self, Vector3(0.13, 0.14, 0.13), Vector3(0, 1.12, z), _accent().darkened(0.1), Vector3(45, 0, 0))

func _build_biped() -> void:
	body = _box(self, Vector3(0.72, 0.78, 0.52), Vector3(0, 0.88, 0), _base())
	_box(self, Vector3(0.5, 0.5, 0.06), Vector3(0, 0.84, -0.27), _belly())
	head = _box(self, Vector3(0.9, 0.76, 0.78), Vector3(0, 1.62, -0.05), _base())
	_face(Vector3(0, 1.62, -0.05), Vector3(0.9, 0.76, 0.78))
	legs = []
	_leg(Vector3(-0.21, 0.4, 0.05), Vector3(0.22, 0.45, 0.25))
	_leg(Vector3(0.21, 0.4, 0.05), Vector3(0.22, 0.45, 0.25))
	for ex in [-1.0, 1.0]:
		var arm := _box_offset(self, Vector3(0.17, 0.55, 0.19), Vector3(0, -0.24, 0),
			_base().darkened(0.1))
		arm.get_parent().position = Vector3(ex * 0.47, 1.1, 0)
		legs.append(arm.get_parent())
	# cap / leaf hat
	_box(self, Vector3(1.05, 0.18, 0.92), Vector3(0, 2.02, -0.05), _accent())
	_box(self, Vector3(0.72, 0.14, 0.62), Vector3(0, 2.14, -0.05), _accent().lightened(0.1))
	for p in [Vector2(-0.28, -0.14), Vector2(0.22, 0.1), Vector2(0.06, 0.3)]:
		_box(self, Vector3(0.13, 0.05, 0.13), Vector3(p.x, 2.12, p.y - 0.05), _belly())

func _build_floater() -> void:
	hover = true
	body = _box(self, Vector3(0.74, 0.62, 0.7), Vector3(0, 1.18, 0), _base())
	_box(self, Vector3(0.48, 0.4, 0.06), Vector3(0, 1.12, -0.36), _belly())
	head = body
	_face(Vector3(0, 1.24, -0.02), Vector3(0.74, 0.62, 0.7))
	for ex in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(ex * 0.35, 1.3, 0.12)
		add_child(wing)
		_box(wing, Vector3(0.62, 0.04, 0.38), Vector3(ex * 0.3, 0, 0), _accent(), Vector3(0, 0, ex * 18.0))
		_box(wing, Vector3(0.3, 0.035, 0.22), Vector3(ex * 0.62, 0.02, 0), _accent().lightened(0.15), Vector3(0, 0, ex * 24.0))
		wings.append(wing)
	for ex in [-1.0, 1.0]:
		_box(self, Vector3(0.05, 0.26, 0.05), Vector3(ex * 0.18, 1.62, -0.1), _accent(), Vector3(0, 0, ex * 18.0))
		_box(self, Vector3(0.12, 0.12, 0.12), Vector3(ex * 0.24, 1.78, -0.1), _accent(), Vector3(45, 45, 0), true)
	var t := Node3D.new()
	t.position = Vector3(0, 1.02, 0.3)
	add_child(t)
	_box(t, Vector3(0.12, 0.12, 0.42), Vector3(0, -0.05, 0.2), _accent().darkened(0.15))
	_box(t, Vector3(0.16, 0.16, 0.16), Vector3(0, -0.08, 0.42), _accent(), Vector3(45, 0, 45), true)
	tails.append(t)
	blob.visible = false

func _build_serpent() -> void:
	hover = true
	var sizes := [0.5, 0.58, 0.48, 0.36]
	var zs := [-0.1, 0.35, 0.72, 1.05]
	for i in sizes.size():
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 1.05 + (0.04 if i == 0 else 0.0), zs[i])
		add_child(pivot)
		_box(pivot, Vector3(sizes[i], sizes[i] * 0.9, 0.4), Vector3.ZERO,
			_base().darkened(0.03 * i))
		if i > 0:
			tails.append(pivot)
	head = _box(self, Vector3(0.66, 0.6, 0.62), Vector3(0, 1.32, -0.55), _base())
	_box(self, Vector3(0.36, 0.22, 0.2), Vector3(0, 1.22, -0.92), _belly())
	_face(Vector3(0, 1.32, -0.55), Vector3(0.66, 0.6, 0.62))
	_box(self, Vector3(0.5, 0.12, 0.16), Vector3(0, 1.7, -0.5), _accent())
	for ex in [-1.0, 1.0]:
		_box(self, Vector3(0.1, 0.42, 0.1), Vector3(ex * 0.27, 1.68, -0.38), _accent(), Vector3(0, 0, ex * 20.0))
	_box(self, Vector3(0.18, 0.18, 0.18), Vector3(0, 1.58, -0.9), _accent(), Vector3(45, 0, 45), true)
	blob.scale = Vector3(0.8, 0.8, 0.8)
	for i in 3:
		_box(self, Vector3(0.09, 0.09, 0.09), Vector3(0, 0.88 + i * 0.05, 0.65 + i * 0.06), _accent(), Vector3(45, 0, 0), true)

func _build_golem() -> void:
	blob.scale = Vector3(1.25, 1.25, 1.25)
	body = _box(self, Vector3(1.02, 1.0, 0.72), Vector3(0, 1.08, 0), _base())
	_box(self, Vector3(0.66, 0.6, 0.06), Vector3(0, 1.0, -0.38), _belly())
	head = _box(self, Vector3(0.6, 0.54, 0.56), Vector3(0, 1.86, -0.04), _base().lightened(0.06))
	_face(Vector3(0, 1.86, -0.04), Vector3(0.6, 0.54, 0.56))
	legs = []
	_leg(Vector3(-0.3, 0.6, 0), Vector3(0.36, 0.6, 0.4))
	_leg(Vector3(0.3, 0.6, 0), Vector3(0.36, 0.6, 0.4))
	for ex in [-1.0, 1.0]:
		var arm := _box_offset(self, Vector3(0.3, 0.9, 0.32), Vector3(0, -0.42, 0),
			_base().darkened(0.08))
		arm.get_parent().position = Vector3(ex * 0.66, 1.4, 0)
		_box(arm.get_parent(), Vector3(0.4, 0.34, 0.4), Vector3(0, -0.86, 0), _base().darkened(0.18))
		legs.append(arm.get_parent())
		_box(self, Vector3(0.3, 0.22, 0.3), Vector3(ex * 0.45, 1.62, 0.05), _accent().darkened(0.15))
	for ex in [-1.0, 1.0]:
		_box(self, Vector3(0.14, 0.4, 0.14), Vector3(ex * 0.28, 1.55, 0.32), _accent(), Vector3(35, 0, ex * 12.0), true)

func _build_insect() -> void:
	blob.scale = Vector3(0.65, 0.65, 0.65)
	body = _box(self, Vector3(0.48, 0.38, 0.72), Vector3(0, 0.62, 0.05), _base())
	_box(self, Vector3(0.3, 0.26, 0.06), Vector3(0, 0.58, -0.31), _belly())
	head = _box(self, Vector3(0.48, 0.42, 0.4), Vector3(0, 0.78, -0.46), _base().lightened(0.06))
	_face(Vector3(0, 0.78, -0.46), Vector3(0.48, 0.42, 0.4))
	for i in 3:
		for ex in [-1.0, 1.0]:
			var leg := Node3D.new()
			leg.position = Vector3(ex * 0.22, 0.55, -0.2 + i * 0.2)
			add_child(leg)
			_box(leg, Vector3(0.05, 0.3, 0.05), Vector3(ex * 0.16, -0.14, 0), _base().darkened(0.3), Vector3(0, 0, ex * 30.0))
			legs.append(leg)
	for ex in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(ex * 0.15, 0.85, 0.15)
		add_child(wing)
		_box(wing, Vector3(0.48, 0.03, 0.3), Vector3(ex * 0.25, 0, 0.05), _accent().lightened(0.1), Vector3(0, 0, ex * 12.0))
		wings.append(wing)
		_box(self, Vector3(0.04, 0.3, 0.04), Vector3(ex * 0.12, 1.1, -0.5), _accent(), Vector3(0, 0, ex * 22.0))
		_box(self, Vector3(0.09, 0.09, 0.09), Vector3(ex * 0.17, 1.25, -0.5), _accent(), Vector3(45, 45, 0), true)
	_box(self, Vector3(0.1, 0.1, 0.25), Vector3(0, 0.7, 0.45), _accent().darkened(0.1))

func _decorate() -> void:
	var el := str(sp.get("element", "Nature"))
	var a := _accent()
	match el:
		"Fire":
			for i in 3:
				_box(self, Vector3(0.14 - i * 0.03, 0.26 + i * 0.08, 0.12), Vector3(0.1 * (i - 1), 1.58 + i * 0.08, 0.22), a, Vector3(0, 0, 20 * (i - 1)), true)
		"Frost":
			for ex in [-1.0, 1.0]:
				_box(self, Vector3(0.12, 0.48, 0.12), Vector3(ex * 0.3, 1.72, 0.15), a, Vector3(-15, 0, ex * 15.0), true)
		"Stone":
			for i in 3:
				_box(self, Vector3(0.2, 0.16, 0.2), Vector3(0.18 * (i - 1), 1.15 + i * 0.14, 0.28), a.darkened(0.15), Vector3(25, 10 * i, 0))
		"Nature":
			_box(self, Vector3(0.22, 0.06, 0.34), Vector3(0.2, 1.5, -0.35), a, Vector3(0, 0, 35), true)
			_box(self, Vector3(0.18, 0.05, 0.26), Vector3(-0.22, 1.52, -0.3), a.lightened(0.1), Vector3(0, 0, -30), true)
		"Sand":
			for i in 2:
				_box(self, Vector3(0.12, 0.3 + i * 0.1, 0.26), Vector3(0, 1.4 + i * 0.05, 0.25 + i * 0.2), a, Vector3(-20, 0, 0))
		"Light":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.24
			torus.outer_radius = 0.34
			var mat := Content.monster_material(a, true)
			torus.material = mat
			var halo := MeshInstance3D.new()
			halo.mesh = torus
			halo.position = Vector3(0, 2.1, 0)
			halo.rotation_degrees.x = 90
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(halo)
		"Water":
			_box(self, Vector3(0.1, 0.36, 0.4), Vector3(0, 1.5, 0.1), a, Vector3(20, 0, 0), false)
		"Spark":
			for ex in [-1.0, 1.0]:
				_box(self, Vector3(0.05, 0.3, 0.05), Vector3(ex * 0.22, 1.6, -0.3), a, Vector3(0, 0, ex * 35.0), true)
		"Shadow":
			for ex in [-1.0, 1.0]:
				_box(self, Vector3(0.09, 0.38, 0.09), Vector3(ex * 0.2, 1.55, -0.25), a.darkened(0.25), Vector3(0, 0, ex * 24.0))
		"Toxic":
			for i in 3:
				_box(self, Vector3(0.1, 0.22, 0.1), Vector3((i - 1) * 0.22, 1.35, 0.28), a, Vector3(-20, 0, (i - 1) * 18.0))
		"Wind":
			for ex in [-1.0, 1.0]:
				_box(self, Vector3(0.36, 0.03, 0.18), Vector3(ex * 0.42, 1.3, 0.18), a, Vector3(0, 0, ex * 30.0))
		"Void":
			for i in 3:
				var ang := float(i) * TAU / 3.0
				_box(self, Vector3(0.13, 0.13, 0.13), Vector3(cos(ang) * 0.62, 1.15 + sin(ang) * 0.3, sin(ang) * 0.4), a, Vector3(45, 45, 0), true)

func _finish_colors() -> void:
	if variant == "shiny":
		_box(self, Vector3(0.1, 0.1, 0.1), Vector3(-0.34, 0.92, -0.58), Color("#fff1b0"), Vector3(45, 0, 45), true)

func animate(delta: float, move_speed: float) -> void:
	time += delta * (1.2 + clampf(move_speed, 0.0, 6.0) * 0.35)
	var amp := clampf(move_speed / 4.0, 0.0, 1.0)
	for i in legs.size():
		legs[i].rotation.x = sin(time * 7.0 + i * 1.7) * 0.55 * (0.25 + amp)
	for i in wings.size():
		wings[i].rotation.z = sin(time * 9.0 + i) * (0.18 + amp * 0.35) + (0.1 if i % 2 == 0 else -0.1)
	for i in tails.size():
		tails[i].rotation.y = sin(time * 2.6 + i * 0.9) * 0.22
	if head != null and head != body:
		head.rotation.y = sin(time * 1.4) * 0.08
	if hover:
		position.y = base_hover + sin(time * 2.2) * 0.07
	else:
		position.y = sin(time * 6.0) * 0.025 * amp
	if body != null:
		body.rotation.z = sin(time * 3.2) * 0.02 * amp
		body.scale = Vector3(1.0, 1.0 + sin(time * 2.4) * 0.018, 1.0)

func lunge_forward(dir: Vector3) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", position + dir * 0.28, 0.08)
	tw.tween_property(self, "position", position - dir * 0.05, 0.12)
	tw.tween_property(self, "position", position, 0.08)

func squash() -> void:
	var s := scale
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(s.x * 1.15, s.y * 0.82, s.z * 1.15), 0.06)
	tw.tween_property(self, "scale", s, 0.12)

func death_animation() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.02, 0.02, 0.02), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "rotation_degrees:y", 220.0, 0.45)

func _add_boss_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = _accent()
	light.light_energy = 1.4
	light.omni_range = 5.5
	light.omni_attenuation = 1.6
	light.position = Vector3(0, 1.4, 0)
	light.shadow_enabled = false
	add_child(light)
