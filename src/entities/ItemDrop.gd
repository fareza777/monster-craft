class_name ItemDrop
extends Node3D

var item_id := ""
var count := 1
var life := 0.0
var player: Node3D
var collected := false
var mesh: MeshInstance3D
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
	mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.19, 0.19, 0.19)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if item_id in ["crystal", "amber", "monster_core", "rift_key", "orb_great"]:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.5
	box.material = mat
	mesh.mesh = box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	if count > 1:
		count_label = Label3D.new()
		count_label.text = "x%d" % count
		count_label.font_size = 28
		count_label.pixel_size = 0.005
		count_label.outline_size = 5
		count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		count_label.position = Vector3(0, 0.28, 0)
		count_label.modulate = Color("#f6f0d8")
		add_child(count_label)
	var light := OmniLight3D.new()
	light.light_energy = 0.25
	light.omni_range = 1.4
	light.light_color = color
	add_child(light)

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
