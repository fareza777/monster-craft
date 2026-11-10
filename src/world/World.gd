class_name VoxelWorld
extends Node3D
## Streaming voxel world. Generation and greedy meshing run on worker threads,
## chunks near the player get collision, distant ones are unloaded.

signal initial_ready
signal chunk_meshed(key: Vector2i)
signal load_progress(done: int, total: int)

const CHUNK := 16
const HEIGHT := 80
const SEA := 28
const MAX_GEN_TASKS := 2
const MAX_MESH_TASKS := 2

var seed_value := 1
var gen: TerrainGen
var view_distance := 4
var spawn_point := Vector3.ZERO
var focus := Vector3.ZERO
var player: Node3D = null
var saved_player_state: Dictionary = {}

var chunks: Dictionary = {}
var data: Dictionary = {}
var diffs: Dictionary = {}
var _gen_pending: Dictionary = {}
var _mesh_pending: Dictionary = {}
var _gen_workers: Dictionary = {}
var _mesh_workers: Dictionary = {}
var _results: Dictionary = {}
var _result_mutex := Mutex.new()
var _stream_timer := 0.0
var _env_timer := 0.0
var _farm_timer := 20.0
var _thunder_timer := 8.0
var _initial_done := false
var _initial_center := Vector2i.ZERO
var _initial_total := 9
var _materials: Dictionary = {}
var _environment: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _weather_particles: CPUParticles3D
var _weather_mesh: BoxMesh
var _weather_mat: StandardMaterial3D
var _flash: OmniLight3D
var _stars: MeshInstance3D
var _star_mat: ShaderMaterial
var _motes: CPUParticles3D
var _mote_mat: StandardMaterial3D
var _shutdown := false

func setup(world_seed: int, save_data: Dictionary, fallback_spawn: Vector3 = Vector3.ZERO) -> void:
	seed_value = world_seed
	gen = TerrainGen.new(seed_value)
	GreedyMesher.prewarm()
	ChunkWorker.new()
	spawn_point = fallback_spawn
	if save_data.has("spawn"):
		var s = save_data.spawn
		if s is Array and s.size() >= 3:
			spawn_point = Vector3(float(s[0]), float(s[1]), float(s[2]))
	if spawn_point == Vector3.ZERO:
		spawn_point = gen.find_spawn()
	var saved_pos := spawn_point
	if save_data.has("player"):
		saved_player_state = save_data.player
		if saved_player_state.has("pos"):
			var p = saved_player_state.pos
			if p is Array and p.size() >= 3:
				saved_pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
	focus = saved_pos
	_apply_saved_diffs(save_data.get("diffs", {}))
	_build_materials()
	_build_environment()
	_build_weather_fx()
	_build_motes()
	_initial_center = _chunk_of(focus)
	_stream_timer = 0.0
	print("[MonsterCraft] World setup seed=%d spawn=%s focus=%s" % [seed_value, spawn_point, focus])

func _ready() -> void:
	set_process(true)

func set_player(p: Node3D) -> void:
	player = p
	focus = p.global_position

func _chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / float(CHUNK)), floori(pos.z / float(CHUNK)))

func _process(delta: float) -> void:
	if gen == null or _shutdown:
		return
	if player != null and is_instance_valid(player):
		focus = player.global_position
	_stream_timer -= delta
	if _stream_timer <= 0.0:
		_stream_timer = 0.22
		_poll_tasks()
		_update_streaming()
	_poll_tasks()
	_env_timer -= delta
	if _env_timer <= 0.0:
		_env_timer = 0.35
		_update_environment()
	_farm_timer -= delta
	if _farm_timer <= 0.0:
		_farm_timer = 24.0
		_farm_growth()
	if _initial_done:
		_thunder_timer -= delta
		if _thunder_timer <= 0.0:
			_thunder_timer = randf_range(9.0, 22.0)
			if Game.weather == "storm":
				Sfx.play("thunder", 0.03)
				_flash.light_energy = 6.0
				create_tween().tween_property(_flash, "light_energy", 0.0, 0.35)

# ------------------------------------------------------------------ tasks

func _poll_tasks() -> void:
	for key in _gen_pending.keys():
		var tid: int = _gen_pending[key]
		if not WorkerThreadPool.is_task_completed(tid):
			continue
		_gen_pending.erase(key)
		WorkerThreadPool.wait_for_task_completion(tid)
		_gen_workers.erase(key)
		var res = _take_result(key)
		if res != null and str(res.get("type", "")) == "gen":
			_on_chunk_data(key, res.data)
	for key in _mesh_pending.keys():
		var tid2: int = _mesh_pending[key]
		if not WorkerThreadPool.is_task_completed(tid2):
			continue
		_mesh_pending.erase(key)
		WorkerThreadPool.wait_for_task_completion(tid2)
		_mesh_workers.erase(key)
		var res2 = _take_result(key)
		if res2 != null and str(res2.get("type", "")) == "mesh":
			_on_chunk_mesh(key, res2.data, int(res2.get("version", -1)))

func _take_result(key: Vector2i):
	_result_mutex.lock()
	var res = _results.get(key)
	_results.erase(key)
	_result_mutex.unlock()
	return res

func _start_gen(key: Vector2i) -> void:
	if _gen_pending.has(key):
		return
	var worker := ChunkWorker.new()
	worker.seed_value = seed_value
	worker.cx = key.x
	worker.cz = key.y
	worker.key = key
	worker.mutex = _result_mutex
	worker.results = _results
	var dd: Dictionary = diffs.get(key, {})
	worker.diff_dict = dd.duplicate()
	var tid := WorkerThreadPool.add_task(worker.run_generate)
	_gen_pending[key] = tid
	_gen_workers[key] = worker

func _start_mesh(key: Vector2i) -> void:
	if _mesh_pending.has(key) or not data.has(key) or not chunks.has(key):
		return
	var chunk: WorldChunk = chunks[key]
	if not chunk.needs_mesh:
		return
	var worker := ChunkWorker.new()
	worker.cx = key.x
	worker.cz = key.y
	worker.key = key
	worker.mutex = _result_mutex
	worker.results = _results
	worker.version = chunk.data_version
	var blocks: PackedByteArray = data[key]
	worker.blocks = blocks.duplicate()
	worker.nx = _neighbor_copy(key + Vector2i(-1, 0))
	worker.px = _neighbor_copy(key + Vector2i(1, 0))
	worker.nz = _neighbor_copy(key + Vector2i(0, -1))
	worker.pz = _neighbor_copy(key + Vector2i(0, 1))
	var tid := WorkerThreadPool.add_task(worker.run_mesh)
	_mesh_pending[key] = tid
	_mesh_workers[key] = worker

func _neighbor_copy(key: Vector2i) -> PackedByteArray:
	if data.has(key):
		var blocks: PackedByteArray = data[key]
		return blocks.duplicate()
	return PackedByteArray()

func _on_chunk_data(key: Vector2i, blocks: PackedByteArray) -> void:
	if not _is_desired(key):
		return
	if data.has(key):
		return
	data[key] = blocks
	if not chunks.has(key):
		var chunk := WorldChunk.new()
		add_child(chunk)
		chunk.setup(key, _materials)
		chunks[key] = chunk
	var chunk_ref: WorldChunk = chunks[key]
	chunk_ref.needs_mesh = true
	_start_mesh(key)

func _on_chunk_mesh(key: Vector2i, groups: Dictionary, version: int) -> void:
	if not chunks.has(key) or not data.has(key):
		return
	var chunk: WorldChunk = chunks[key]
	if version != chunk.data_version:
		chunk.needs_mesh = true
		return
	chunk.apply_groups(groups, version)
	chunk_meshed.emit(key)
	if _chunk_near_collision(key):
		chunk.set_collision(true)
	if not _initial_done:
		_recount_initial()
		if _initial_ready_now():
			_initial_done = true
			# widen collision area for the reveal
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var k := _initial_center + Vector2i(dx, dz)
					if chunks.has(k):
						chunks[k].set_collision(true)
			initial_ready.emit()
			print("[MonsterCraft] Initial chunks ready")

func _is_desired(key: Vector2i) -> bool:
	var radius := 2 if not _initial_done else view_distance + 2
	var fc := _chunk_of(focus)
	return absi(key.x - fc.x) <= radius and absi(key.y - fc.y) <= radius

func _chunk_near_collision(key: Vector2i) -> bool:
	var fc := _chunk_of(focus)
	var r := 2 if _initial_done else 2
	return absi(key.x - fc.x) <= r and absi(key.y - fc.y) <= r

func _update_streaming() -> void:
	var fc := _chunk_of(focus)
	var radius := 2 if not _initial_done else view_distance
	var wanted: Array = []
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			if dx * dx + dz * dz > radius * radius + 2:
				continue
			var key := fc + Vector2i(dx, dz)
			if data.has(key) or _gen_pending.has(key):
				continue
			wanted.append({"key": key, "d": dx * dx + dz * dz})
	wanted.sort_custom(func(a, b): return int(a.d) < int(b.d))
	var mesh_jobs: Array = []
	for key in data:
		if not chunks.has(key) or _mesh_pending.has(key):
			continue
		var chunk: WorldChunk = chunks[key]
		if not chunk.needs_mesh:
			continue
		var dx2: int = key.x - fc.x
		var dz2: int = key.y - fc.y
		var lim: int = 2 if not _initial_done else view_distance + 1
		if absi(dx2) > lim or absi(dz2) > lim:
			continue
		mesh_jobs.append({"key": key, "d": dx2 * dx2 + dz2 * dz2})
	mesh_jobs.sort_custom(func(a, b): return int(a.d) < int(b.d))
	var gen_budget := MAX_GEN_TASKS - _gen_pending.size()
	for i in mini(gen_budget, wanted.size()):
		_start_gen(wanted[i].key)
	var mesh_budget := MAX_MESH_TASKS - _mesh_pending.size()
	for i in mini(mesh_budget, mesh_jobs.size()):
		_start_mesh(mesh_jobs[i].key)
	# collision near player, no collision far away
	var cr := 2 if _initial_done else 2
	for key in chunks:
		var dx3: int = absi(key.x - fc.x)
		var dz3: int = absi(key.y - fc.y)
		var chunk2: WorldChunk = chunks[key]
		if dx3 <= cr and dz3 <= cr:
			if not chunk2.collision_wanted and chunk2.mesh_version >= 0:
				chunk2.set_collision(true)
		elif dx3 > cr + 1 or dz3 > cr + 1:
			if chunk2.collision_wanted:
				chunk2.set_collision(false)
	# unload distant chunks
	var unload_r := (2 if not _initial_done else view_distance) + 2
	for key in chunks.keys():
		if absi(key.x - fc.x) > unload_r or absi(key.y - fc.y) > unload_r:
			var ch: WorldChunk = chunks[key]
			ch.queue_free()
			chunks.erase(key)
			data.erase(key)

func _recount_initial() -> void:
	var done := 0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := _initial_center + Vector2i(dx, dz)
			var chunk: WorldChunk = chunks.get(key)
			if chunk != null and chunk.mesh_version >= 0:
				done += 1
	load_progress.emit(done, _initial_total)

func _initial_ready_now() -> bool:
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := _initial_center + Vector2i(dx, dz)
			var chunk: WorldChunk = chunks.get(key)
			if chunk == null or chunk.mesh_version < 0:
				return false
			if not chunk.collision_wanted:
				chunk.set_collision(true)
			if chunk.body == null:
				return false
	return true

func get_initial_progress() -> float:
	var done := 0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := _initial_center + Vector2i(dx, dz)
			var chunk: WorldChunk = chunks.get(key)
			if chunk != null and chunk.mesh_version >= 0:
				done += 1
	return float(done) / float(_initial_total) if not _initial_done else 1.0

# ------------------------------------------------------------------ block api

func get_block(pos: Vector3i) -> int:
	var key := Vector2i(floori(float(pos.x) / CHUNK), floori(float(pos.z) / CHUNK))
	if not data.has(key):
		return Content.AIR
	if pos.y < 0 or pos.y >= HEIGHT:
		return Content.AIR
	var lx := pos.x - key.x * CHUNK
	var lz := pos.z - key.y * CHUNK
	var blocks: PackedByteArray = data[key]
	return blocks[lx + lz * CHUNK + pos.y * CHUNK * CHUNK]

func set_block(pos: Vector3i, block_id: int, record: bool = true) -> bool:
	var key := Vector2i(floori(float(pos.x) / CHUNK), floori(float(pos.z) / CHUNK))
	if not data.has(key) or not chunks.has(key):
		return false
	if pos.y < 1 or pos.y >= HEIGHT:
		return false
	var lx := pos.x - key.x * CHUNK
	var lz := pos.z - key.y * CHUNK
	var idx := lx + lz * CHUNK + pos.y * CHUNK * CHUNK
	var blocks: PackedByteArray = data[key]
	if blocks[idx] == block_id:
		return false
	blocks[idx] = block_id
	data[key] = blocks
	if record:
		if not diffs.has(key):
			diffs[key] = {}
		diffs[key][idx] = block_id
	var chunk: WorldChunk = chunks[key]
	chunk.data_version += 1
	chunk.needs_mesh = true
	if lx == 0:
		_mark_neighbor_mesh(key + Vector2i(-1, 0))
	elif lx == CHUNK - 1:
		_mark_neighbor_mesh(key + Vector2i(1, 0))
	if lz == 0:
		_mark_neighbor_mesh(key + Vector2i(0, -1))
	elif lz == CHUNK - 1:
		_mark_neighbor_mesh(key + Vector2i(0, 1))
	return true

func _mark_neighbor_mesh(key: Vector2i) -> void:
	if chunks.has(key):
		var chunk: WorldChunk = chunks[key]
		chunk.needs_mesh = true

func is_solid(pos: Vector3i) -> bool:
	return Content.is_solid(get_block(pos))

func is_inside(pos: Vector3) -> bool:
	var b := get_block(Vector3i(floori(pos.x), floori(pos.y), floori(pos.z)))
	return Content.is_solid(b)

func is_liquid_at(pos: Vector3) -> bool:
	var b := get_block(Vector3i(floori(pos.x), floori(pos.y), floori(pos.z)))
	return Content.is_liquid(b)

func block_at_float(pos: Vector3) -> int:
	return get_block(Vector3i(floori(pos.x), floori(pos.y), floori(pos.z)))

func raycast_voxel(origin: Vector3, direction: Vector3, max_dist: float = 6.0) -> Dictionary:
	var dir := direction.normalized()
	if dir.length_squared() < 0.1:
		return {}
	var pos := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i(1 if dir.x > 0 else -1, 1 if dir.y > 0 else -1, 1 if dir.z > 0 else -1)
	var t_delta := Vector3(
		absf(1.0 / dir.x) if absf(dir.x) > 0.00001 else 1.0e20,
		absf(1.0 / dir.y) if absf(dir.y) > 0.00001 else 1.0e20,
		absf(1.0 / dir.z) if absf(dir.z) > 0.00001 else 1.0e20)
	var t_max := Vector3(
		((float(pos.x) + 1.0 - origin.x) / dir.x) if dir.x > 0 else ((float(pos.x) - origin.x) / dir.x) if dir.x < 0 else 1.0e20,
		((float(pos.y) + 1.0 - origin.y) / dir.y) if dir.y > 0 else ((float(pos.y) - origin.y) / dir.y) if dir.y < 0 else 1.0e20,
		((float(pos.z) + 1.0 - origin.z) / dir.z) if dir.z > 0 else ((float(pos.z) - origin.z) / dir.z) if dir.z < 0 else 1.0e20)
	var normal := Vector3i.ZERO
	var dist := 0.0
	for i in 128:
		var b := get_block(pos)
		if b != Content.AIR and not Content.is_liquid(b):
			return {"pos": pos, "normal": normal, "block": b,
				"distance": dist, "point": Vector3(pos) + Vector3(0.5, 0.5, 0.5)}
		if t_max.x < t_max.y and t_max.x < t_max.z:
			dist = t_max.x
			pos.x += step.x
			t_max.x += t_delta.x
			normal = Vector3i(-step.x, 0, 0)
		elif t_max.y < t_max.z:
			dist = t_max.y
			pos.y += step.y
			t_max.y += t_delta.y
			normal = Vector3i(0, -step.y, 0)
		else:
			dist = t_max.z
			pos.z += step.z
			t_max.z += t_delta.z
			normal = Vector3i(0, 0, -step.z)
		if dist > max_dist:
			break
	return {}

func force_load_area(center: Vector3, radius: int = 1) -> void:
	var fc := _chunk_of(center)
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var key := fc + Vector2i(dx, dz)
			if not data.has(key):
				if chunks.has(key):
					pass
				var blocks := gen.generate_chunk(key.x, key.y)
				var d: Dictionary = diffs.get(key, {})
				for idx in d:
					if int(idx) < blocks.size():
						blocks[int(idx)] = int(d[idx])
				data[key] = blocks
				if not chunks.has(key):
					var ch := WorldChunk.new()
					add_child(ch)
					ch.setup(key, _materials)
					chunks[key] = ch
			var chunk: WorldChunk = chunks[key]
			if chunk.mesh_version < 0:
				var groups := GreedyMesher.build(data[key], _neighbor_copy(key + Vector2i(-1, 0)),
					_neighbor_copy(key + Vector2i(1, 0)), _neighbor_copy(key + Vector2i(0, -1)),
					_neighbor_copy(key + Vector2i(0, 1)), key.x, key.y,
					_biome_tint(gen.biome_at(key.x * 16 + 8, key.y * 16 + 8)))
				chunk.apply_groups(groups, chunk.data_version)
			chunk.set_collision(true)


func _biome_tint(biome: String) -> Color:
	match biome:
		"desert":
			return Color(1.0, 0.94, 0.76)
		"frost":
			return Color(0.84, 0.93, 1.0)
		"mushroom":
			return Color(0.95, 0.87, 1.0)
		"ash":
			return Color(0.99, 0.82, 0.76)
	return Color(1.0, 1.0, 0.98)

func respawn_player() -> void:
	if player == null:
		return
	force_load_area(spawn_point, 1)
	player.global_position = spawn_point + Vector3(0.0, 1.0, 0.0)
	if player.has_method("reset_after_death"):
		player.reset_after_death()
	focus = player.global_position

# ------------------------------------------------------------------ queries

func surface_height(x: int, z: int) -> int:
	return gen.height_at(x, z) + 1

func biome_at_pos(pos: Vector3) -> String:
	return gen.biome_at(floori(pos.x), floori(pos.z))

func get_biome_list() -> Array:
	return Content.BIOMES.keys()

func get_nearby_villages(pos: Vector3) -> Array:
	var fc := _chunk_of(pos)
	return gen.nearby_villages(fc.x, fc.y)

func get_nearest_village(pos: Vector3) -> Dictionary:
	return gen.nearest_village(pos, 3)

func get_nearest_dungeon(pos: Vector3) -> Dictionary:
	return gen.nearest_dungeon(pos, 3)


func get_landmark_at(pos: Vector3) -> Dictionary:
	if gen == null:
		return {}
	return gen.landmark_at_pos(pos)

func get_nearby_landmarks(pos: Vector3) -> Array:
	if gen == null:
		return []
	return gen.nearby_landmarks_at(pos)

func get_dungeon_at(pos: Vector3) -> Dictionary:
	var fc := _chunk_of(pos)
	for d in gen.nearby_dungeons(fc.x, fc.y):
		var room: Vector3i = d.room_center
		if Vector2(pos.x - room.x, pos.z - room.z).length() < 12.0 and absf(pos.y - room.y) < 9.0:
			return d
	return {}

func get_chest_tier(pos: Vector3i) -> int:
	var d := get_dungeon_at(Vector3(pos) + Vector3(0.5, 0.5, 0.5))
	if not d.is_empty():
		return int(d.get("tier", 2)) + 1
	var v := get_nearest_village(Vector3(pos))
	if not v.is_empty():
		var c: Vector3i = v.center
		if Vector2(pos.x - c.x, pos.z - c.z).length() < 24.0:
			return 1
	return 0

func get_loaded_monster_spawn(x: int, z: int) -> Vector3:
	var h := gen.height_at(x, z)
	if h <= SEA:
		return Vector3.ZERO
	var pos := Vector3(x + 0.5, h + 1.2, z + 0.5)
	var ground := get_block(Vector3i(x, h, z))
	if Content.is_solid(ground) and get_block(Vector3i(x, h + 1, z)) == Content.AIR:
		return pos
	return Vector3.ZERO

func get_crop_positions_near(center: Vector3, radius: int = 22) -> Array:
	var out: Array = []
	var base := Vector3i(floori(center.x), floori(center.y), floori(center.z))
	for y in range(maxi(2, base.y - 6), mini(HEIGHT - 1, base.y + 8)):
		for z in range(base.z - radius, base.z + radius + 1, 2):
			for x in range(base.x - radius, base.x + radius + 1, 2):
				var b := get_block(Vector3i(x, y, z))
				if b >= Content.WHEAT0 and b <= Content.WHEAT3:
					out.append(Vector3i(x, y, z))
					if out.size() > 80:
						return out
	return out

func _farm_growth() -> void:
	if player == null:
		return
	var crops := get_crop_positions_near(player.global_position, 24)
	for p in crops:
		var b := get_block(p)
		if b >= Content.WHEAT0 and b < Content.WHEAT3 and randf() < 0.35:
			set_block(p, b + 1)

func get_save_data() -> Dictionary:
	var diff_out: Dictionary = {}
	for key in diffs:
		var arr: Array = []
		var d: Dictionary = diffs[key]
		for idx in d:
			arr.append([int(idx), int(d[idx])])
		diff_out["%d,%d" % [key.x, key.y]] = arr
	var pdata: Dictionary = {}
	if player != null and player.has_method("get_save_state"):
		pdata = player.get_save_state()
	else:
		pdata = {"pos": [focus.x, focus.y, focus.z], "yaw": 0.0, "pitch": 0.0}
	return {"diffs": diff_out, "player": pdata,
		"spawn": [spawn_point.x, spawn_point.y, spawn_point.z]}

func _apply_saved_diffs(raw) -> void:
	if not raw is Dictionary:
		return
	for key_str in raw:
		var parts := str(key_str).split(",")
		if parts.size() != 2:
			continue
		var key := Vector2i(int(parts[0]), int(parts[1]))
		var d: Dictionary = {}
		var arr = raw[key_str]
		if arr is Array:
			for pair in arr:
				if pair is Array and pair.size() >= 2:
					d[int(pair[0])] = int(pair[1])
		if not d.is_empty():
			diffs[key] = d

func shutdown() -> void:
	_shutdown = true
	for key in _gen_pending:
		WorkerThreadPool.wait_for_task_completion(_gen_pending[key])
	for key in _mesh_pending:
		WorkerThreadPool.wait_for_task_completion(_mesh_pending[key])
	_gen_pending.clear()
	_mesh_pending.clear()
	_gen_workers.clear()
	_mesh_workers.clear()

# ------------------------------------------------------------------ visuals

func _build_materials() -> void:
	var solid := ShaderMaterial.new()
	solid.shader = load("res://src/world/voxel_solid.gdshader")
	var transp := ShaderMaterial.new()
	transp.shader = load("res://src/world/voxel_transparent.gdshader")
	var liquid := ShaderMaterial.new()
	liquid.shader = load("res://src/world/voxel_transparent.gdshader")
	liquid.set_shader_parameter("wave_strength", 1.0)
	var plants := ShaderMaterial.new()
	plants.shader = load("res://src/world/voxel_plant.gdshader")
	for mat in [solid, transp, liquid, plants]:
		mat.set_shader_parameter("atlas_tex", Content.atlas_texture)
		mat.set_shader_parameter("atlas_size", Vector2(Content.atlas_texture.get_width(), Content.atlas_texture.get_height()))
		mat.set_shader_parameter("tile_px", 16.0)
	_materials = {"solid": solid, "transparent": transp, "liquid": liquid, "plants": plants}

func _build_environment() -> void:
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = Color("#78c4d8")
	_sky_mat.sky_horizon_color = Color("#dff1e3")
	_sky_mat.ground_bottom_color = Color("#415b58")
	_sky_mat.ground_horizon_color = Color("#a9cfc0")
	_sky_mat.sun_angle_max = 18.0
	_sky_mat.sun_curve = 0.12
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_energy = 0.85
	_environment.ambient_light_sky_contribution = 0.72
	_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_environment.tonemap_white = 6.0
	_environment.adjustment_enabled = true
	_environment.adjustment_brightness = 1.02
	_environment.adjustment_contrast = 1.09
	_environment.adjustment_saturation = 1.02
	_environment.tonemap_exposure = 1.0
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("#b6d9d0")
	_environment.fog_light_energy = 0.8
	_environment.fog_density = 0.0055
	_environment.fog_sky_affect = 0.2
	_environment.fog_aerial_perspective = 0.35
	_environment.fog_height = 10.0
	_environment.fog_height_density = 0.12
	var we := WorldEnvironment.new()
	we.environment = _environment
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_fade_start = 0.85
	_sun.directional_shadow_pancake_size = 20.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 84.0
	_sun.shadow_bias = 0.025
	_sun.shadow_normal_bias = 0.9
	_sun.light_energy = 1.1
	_sun.light_color = Color("#fff4da")
	_sun.rotation_degrees = Vector3(-70, -35, 0)
	add_child(_sun)
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color("#93b4e8")
	_moon.light_energy = 0.0
	_moon.shadow_enabled = false
	add_child(_moon)
	_flash = OmniLight3D.new()
	_flash.light_energy = 0.0
	_flash.omni_range = 70.0
	_flash.light_color = Color("#e8f2ff")
	add_child(_flash)
	_build_night_sky()
	_update_environment()

func _update_environment() -> void:
	if gen == null:
		return
	var t := Game.day_time
	var sun_elev := sin((t - 0.25) * TAU)
	var day := clampf(sun_elev * 1.6 + 0.15, 0.0, 1.0)
	var night := 1.0 - clampf(sun_elev * 2.2 + 0.3, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(sun_elev) / 0.32, 0.0, 1.0)
	var biome := gen.biome_at(floori(focus.x), floori(focus.z))
	var b: Dictionary = Content.BIOMES.get(biome, Content.BIOMES["meadow"])
	var sky_day: Color = b.sky
	var horizon_day: Color = b.horizon
	var sky_night := Color("#07141f")
	var horizon_night := Color("#142a3a")
	var sky := sky_day.lerp(sky_night, night)
	var horizon := horizon_day.lerp(horizon_night, night)
	horizon = horizon.lerp(Color("#f0a878"), dusk * 0.55)
	var rain := 0.0
	if Game.weather == "rain":
		rain = 0.35
	elif Game.weather == "storm":
		rain = 0.62
	if rain > 0.0:
		sky = sky.lerp(Color("#4b5a62"), rain)
		horizon = horizon.lerp(Color("#6c7a7e"), rain)
	_sky_mat.sky_top_color = sky
	_sky_mat.sky_horizon_color = horizon
	var grass_c: Color = b.get("grass", Color("#6aa84f"))
	_sky_mat.ground_horizon_color = horizon.lerp(grass_c.darkened(0.35), 0.45)
	_sky_mat.ground_bottom_color = Color("#2a3a3a")
	_sky_mat.sky_energy_multiplier = 0.5 + day * 0.3
	_sun.rotation_degrees = Vector3(-rad_to_deg(asin(clampf(sun_elev, -1.0, 1.0))), -35.0, 0.0)
	_sun.light_energy = 0.04 + day * 0.92
	if dusk > 0.15:
		_sun.light_color = Color("#fff4da").lerp(Color("#ffb17a"), dusk)
	else:
		_sun.light_color = Color("#fff4da").lerp(Color("#a8c4ff"), night * 0.7)
	_environment.ambient_light_energy = 0.24 + day * 0.18
	_environment.ambient_light_color = Color("#d4ded4").lerp(Color("#3d5680"), night)
	_environment.adjustment_brightness = 1.0 - night * 0.04
	_environment.adjustment_saturation = 1.03 - night * 0.10 - rain * 0.06
	_moon.rotation_degrees = Vector3(-rad_to_deg(asin(clampf(-sun_elev, -1.0, 1.0))), 145.0, 0.0)
	_moon.light_energy = night * 0.78 * (1.0 - rain * 0.7)
	_environment.fog_light_color = horizon.lerp(grass_c.darkened(0.16), 0.55).lerp(Color("#1e2f4a"), night * 0.62)
	_environment.fog_density = 0.0032 + rain * 0.009 + night * 0.0032
	_flash.global_position = focus + Vector3(0, 25, 0)
	_sun.shadow_enabled = true
	if _stars != null:
		_stars.global_position = focus
		_stars.rotation.y = Game.play_time * 0.0025
		_star_mat.set_shader_parameter("night", clampf(night - rain * 0.5, 0.0, 1.0))
		_star_mat.set_shader_parameter("drift", Game.play_time * 0.35)
	if _motes != null:
		_motes.global_position = focus + Vector3(0, 1.5, 0)
		var firefly := night > 0.55
		var mc := Color(0.95, 1.0, 0.55, 0.85) if firefly else Color(1.0, 0.94, 0.72, 0.22)
		mc = mc.lerp(Color(0.75, 0.85, 0.95, mc.a), rain)
		_mote_mat.albedo_color = mc
		_mote_mat.emission = mc
		_motes.amount = 110 if firefly else 46
	if _weather_particles != null:
		_weather_particles.global_position = focus + Vector3(0, 16, 0)
		var underground := focus.y < float(gen.height_at(floori(focus.x), floori(focus.z)) - 4)
		_weather_particles.emitting = Game.weather != "clear" and not underground
		var snowy := biome == "frost"
		var col := Color(0.82, 0.92, 1.0, 0.55) if snowy else Color(0.55, 0.76, 0.95, 0.42)
		_weather_mat.albedo_color = col
		if snowy:
			_weather_mesh.size = Vector3(0.05, 0.05, 0.05)
		else:
			_weather_mesh.size = Vector3(0.028, 0.6, 0.028)

func _build_weather_fx() -> void:
	if _weather_particles != null:
		return
	_weather_particles = CPUParticles3D.new()
	_weather_particles.amount = 170
	_weather_particles.lifetime = 0.9
	_weather_particles.preprocess = 0.8
	_weather_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_weather_particles.emission_box_extents = Vector3(22, 1.5, 22)
	_weather_particles.direction = Vector3(0, -1, 0)
	_weather_particles.spread = 4.0
	_weather_particles.gravity = Vector3(0, -32, 0)
	_weather_particles.initial_velocity_min = 4.0
	_weather_particles.initial_velocity_max = 9.0
	_weather_particles.scale_amount_min = 0.7
	_weather_particles.scale_amount_max = 1.3
	_weather_particles.emitting = false
	_weather_mesh = BoxMesh.new()
	_weather_mesh.size = Vector3(0.028, 0.6, 0.028)
	_weather_mat = StandardMaterial3D.new()
	_weather_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_weather_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_weather_mat.albedo_color = Color(0.55, 0.76, 0.95, 0.42)
	_weather_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_weather_mesh.material = _weather_mat
	_weather_particles.mesh = _weather_mesh
	add_child(_weather_particles)

func _build_night_sky() -> void:
	if _stars != null:
		return
	_star_mat = ShaderMaterial.new()
	_star_mat.shader = load("res://src/world/night_sky.gdshader")
	var sphere := SphereMesh.new()
	sphere.radius = 140.0
	sphere.height = 280.0
	sphere.radial_segments = 48
	sphere.rings = 24
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = _star_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stars = mi
	add_child(_stars)

func _build_motes() -> void:
	if _motes != null:
		return
	_motes = CPUParticles3D.new()
	_motes.amount = 46
	_motes.lifetime = 7.0
	_motes.preprocess = 5.0
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(15, 3.5, 15)
	_motes.direction = Vector3(0, 1, 0)
	_motes.spread = 180.0
	_motes.gravity = Vector3(0.25, 0.14, -0.18)
	_motes.initial_velocity_min = 0.04
	_motes.initial_velocity_max = 0.26
	_motes.scale_amount_min = 0.5
	_motes.scale_amount_max = 1.5
	_motes.emitting = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	_mote_mat = StandardMaterial3D.new()
	_mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mote_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mote_mat.vertex_color_use_as_albedo = true
	_mote_mat.albedo_color = Color(1.0, 0.94, 0.72, 0.22)
	_mote_mat.emission_enabled = true
	_mote_mat.emission = Color(1.0, 0.94, 0.72)
	_mote_mat.emission_energy_multiplier = 0.6
	_mote_mat.disable_receive_shadows = true
	quad.material = _mote_mat
	_motes.mesh = quad
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_motes)
