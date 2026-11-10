class_name WorldChunk
extends Node3D

var key := Vector2i.ZERO
var data_version := 0
var mesh_version := -1
var needs_mesh := true
var materials: Dictionary = {}
var group_meshes: Dictionary = {}
var mesh_nodes: Array[MeshInstance3D] = []
var body: StaticBody3D
var collision_wanted := false

func setup(chunk_key: Vector2i, mats: Dictionary) -> void:
	key = chunk_key
	materials = mats
	position = Vector3(key.x * TerrainGen.CHUNK, 0, key.y * TerrainGen.CHUNK)
	name = "Chunk_%d_%d" % [key.x, key.y]

func apply_groups(groups: Dictionary, version: int) -> void:
	for node in mesh_nodes:
		node.queue_free()
	mesh_nodes.clear()
	group_meshes.clear()
	for group in ["solid", "transparent", "liquid", "plants"]:
		var data: Dictionary = groups.get(group, {})
		var indices: PackedInt32Array = data.get("i", PackedInt32Array())
		if indices.is_empty():
			continue
		var mesh := _make_mesh(data)
		if mesh == null:
			continue
		group_meshes[group] = mesh
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = materials.get(group)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if group == "solid" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mesh_nodes.append(mi)
	mesh_version = version
	needs_mesh = false
	if collision_wanted:
		_rebuild_collision()

func _make_mesh(data: Dictionary) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.v
	arrays[Mesh.ARRAY_NORMAL] = data.n
	arrays[Mesh.ARRAY_TEX_UV] = data.uv
	arrays[Mesh.ARRAY_TEX_UV2] = data.uv2
	arrays[Mesh.ARRAY_COLOR] = data.c
	arrays[Mesh.ARRAY_INDEX] = data.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func set_collision(active: bool) -> void:
	collision_wanted = active
	if not active:
		if body != null:
			body.queue_free()
			body = null
		return
	if body == null and not group_meshes.is_empty():
		_rebuild_collision()

func _rebuild_collision() -> void:
	if body != null:
		body.queue_free()
		body = null
	if not collision_wanted:
		return
	body = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for group in ["solid", "transparent"]:
		var mesh: ArrayMesh = group_meshes.get(group)
		if mesh == null:
			continue
		var shape := mesh.create_trimesh_shape()
		if shape == null:
			continue
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
