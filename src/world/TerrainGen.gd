class_name TerrainGen
extends RefCounted
## Deterministic, thread-safe world generator. Each worker instantiates its own
## TerrainGen because FastNoiseLite is not shared across threads.

const CHUNK := 16
const HEIGHT := 80
const SEA := 28
const VILLAGE_GRID := 160
const DUNGEON_GRID := 192

var seed_value := 1
var n_cont: FastNoiseLite
var n_detail: FastNoiseLite
var n_ridge: FastNoiseLite
var n_temp: FastNoiseLite
var n_moist: FastNoiseLite
var n_rare: FastNoiseLite
var n_cave: FastNoiseLite
var n_cave2: FastNoiseLite
var n_forest: FastNoiseLite
var n_surface: FastNoiseLite

var _village_cache: Dictionary = {}
var _dungeon_cache: Dictionary = {}
var _landmark_cache: Dictionary = {}

func _init(world_seed: int = 1) -> void:
	seed_value = world_seed
	n_cont = _noise(0.0034, 11, 4)
	n_detail = _noise(0.028, 23, 2)
	n_ridge = _noise(0.011, 37, 3)
	n_temp = _noise(0.0018, 51, 2)
	n_moist = _noise(0.0022, 67, 2)
	n_rare = _noise(0.0011, 79, 2)
	n_cave = _noise3(0.048, 91, 2)
	n_cave2 = _noise3(0.022, 103, 2)
	n_forest = _noise(0.018, 117, 2)
	n_surface = _noise(0.09, 131, 2)

func _noise(freq: float, seed_off: int, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value + seed_off
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_gain = 0.5
	n.fractal_lacunarity = 2.0
	return n

func _noise3(freq: float, seed_off: int, octaves: int) -> FastNoiseLite:
	var n := _noise(freq, seed_off, octaves)
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	return n

func hash01(x: int, y: int, z: int = 0, salt: int = 0) -> float:
	return fmod(float(absi(hash(Vector3i(x + salt, y - salt, z + seed_value)))), 10000.0) / 10000.0

func height_at(x: int, z: int) -> int:
	var cont := n_cont.get_noise_2d(x, z)
	var detail := n_detail.get_noise_2d(x, z)
	var ridge := 1.0 - absf(n_ridge.get_noise_2d(x, z))
	var h := float(SEA) + 4.0 + cont * 13.0 + detail * 1.35
	if cont > 0.16:
		h += pow(ridge, 2.5) * (cont - 0.135) * 78.0
	elif cont < -0.28:
		h -= (-cont - 0.28) * 7.0
	return clampi(int(round(h)), 4, HEIGHT - 6)

func biome_at(x: int, z: int) -> String:
	var t := n_temp.get_noise_2d(x, z)
	var m := n_moist.get_noise_2d(x, z)
	var rare := n_rare.get_noise_2d(x, z)
	if t < -0.3:
		return "frost"
	if t > 0.36 and m < 0.05:
		return "desert"
	if t > 0.44 and m < -0.18 and rare < -0.12:
		return "ash"
	if m > 0.33 and t > -0.25 and t < 0.4 and rare > 0.02:
		return "mushroom"
	return "meadow"

func surface_info(x: int, z: int) -> Dictionary:
	var h := height_at(x, z)
	return {"h": h, "biome": biome_at(x, z), "water": h < SEA, "sea": SEA}

func is_cave(x: int, y: int, z: int) -> bool:
	var v := n_cave.get_noise_3d(float(x), float(y) * 1.55, float(z))
	if absf(v) < 0.062:
		return true
	if y < 22 and v > 0.58:
		return true
	var v2 := n_cave2.get_noise_3d(float(x), float(y) * 1.2, float(z))
	if y < 34 and absf(v2) < 0.035:
		return true
	return false

func slope_at(x: int, z: int) -> int:
	var h := height_at(x, z)
	return maxi(absi(height_at(x + 2, z) - h), absi(height_at(x, z + 2) - h))

# ------------------------------------------------------------------ chunk gen

func generate_chunk(cx: int, cz: int) -> PackedByteArray:
	var size := CHUNK * CHUNK * HEIGHT
	var buf := PackedByteArray()
	buf.resize(size)
	buf.fill(Content.AIR)
	var base_x := cx * CHUNK
	var base_z := cz * CHUNK
	for lz in CHUNK:
		for lx in CHUNK:
			var wx := base_x + lx
			var wz := base_z + lz
			var h := height_at(wx, wz)
			var biome := biome_at(wx, wz)
			var bdata: Dictionary = Content.BIOMES.get(biome, Content.BIOMES["meadow"])
			var surface: int = int(bdata.surface)
			var sub: int = int(bdata.sub)
			if h < SEA:
				match biome:
					"desert": surface = Content.SAND
					"frost": surface = Content.GRAVEL
					"mushroom": surface = Content.DIRT
					"ash": surface = Content.BASALT
					_: surface = Content.SAND
			for y in range(0, h + 1):
				var id: int = Content.STONE
				if y <= 1:
					id = Content.BEDROCK
				elif y == h:
					id = surface
				elif y >= h - 3:
					id = sub
				elif y < 8:
					id = Content.BASALT
				buf[_idx(lx, y, lz)] = id
			if h < SEA:
				var liquid := Content.LAVA if biome == "ash" else Content.WATER
				for y in range(h + 1, SEA + 1):
					buf[_idx(lx, y, lz)] = liquid
				if biome == "frost":
					buf[_idx(lx, SEA, lz)] = Content.ICE
			# caves
			var max_cave := mini(h - 3, HEIGHT - 3)
			for y in range(3, max_cave):
				var id2 := buf[_idx(lx, y, lz)]
				if id2 == Content.BEDROCK:
					continue
				if is_cave(wx, y, wz):
					if y <= 6:
						buf[_idx(lx, y, lz)] = Content.LAVA
					else:
						buf[_idx(lx, y, lz)] = Content.AIR
			# ores
			var ore_top := mini(h - 4, 58)
			for y in range(4, ore_top):
				if buf[_idx(lx, y, lz)] != Content.STONE:
					continue
				var r := hash01(wx, y, wz, 5)
				var ore := -1
				if y < 48 and r < 0.0060:
					ore = Content.COAL_ORE
				elif y < 34 and r > 0.9972 and r < 0.9990:
					ore = Content.IRON_ORE
				elif y < 22 and r > 0.9991 and r < 0.9997:
					ore = Content.GOLD_ORE
				elif y < 17 and r > 0.99972:
					ore = Content.CRYSTAL_ORE
				if ore >= 0:
					buf[_idx(lx, y, lz)] = ore
					for d in 2:
						var ox := lx + (1 if hash01(wx, y, wz, 7 + d) > 0.5 else -1)
						var oy := y + (1 if hash01(wx, y, wz, 9 + d) > 0.7 else 0)
						var oz := lz + (1 if hash01(wx, y, wz, 11 + d) > 0.5 else -1)
						if ox >= 0 and ox < CHUNK and oz >= 0 and oz < CHUNK and oy >= 2 and oy < ore_top:
							if buf[_idx(ox, oy, oz)] == Content.STONE:
								buf[_idx(ox, oy, oz)] = ore
	# trees and plants
	_stamp_trees(buf, cx, cz)
	_stamp_plants(buf, cx, cz)
	# villages and dungeons overwrite natural decoration
	_stamp_nearby_villages(buf, cx, cz)
	_stamp_nearby_dungeons(buf, cx, cz)
	_stamp_nearby_landmarks(buf, cx, cz)
	return buf

func _idx(x: int, y: int, z: int) -> int:
	return x + z * CHUNK + y * CHUNK * CHUNK

func _in_chunk(x: int, z: int) -> bool:
	return x >= 0 and x < CHUNK and z >= 0 and z < CHUNK

func _vox(buf: PackedByteArray, x: int, y: int, z: int) -> int:
	if not _in_chunk(x, z) or y < 0 or y >= HEIGHT:
		return -1
	return buf[_idx(x, y, z)]

func _put(buf: PackedByteArray, x: int, y: int, z: int, id: int, only_air: bool = false) -> void:
	if not _in_chunk(x, z) or y < 1 or y >= HEIGHT:
		return
	var i := _idx(x, y, z)
	if only_air and buf[i] != Content.AIR:
		return
	buf[i] = id

func _put_world(buf: PackedByteArray, cx: int, cz: int, wx: int, wy: int, wz: int,
		id: int, only_air: bool = false) -> void:
	_put(buf, wx - cx * CHUNK, wy, wz - cz * CHUNK, id, only_air)

# ------------------------------------------------------------------ trees

func _tree_list_for_chunk(cx: int, cz: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(Vector3i(cx, cz, seed_value + 331)))
	var biome_center := biome_at(cx * CHUNK + 8, cz * CHUNK + 8)
	var base_count := 1
	var forest := n_forest.get_noise_2d(cx * CHUNK, cz * CHUNK)
	if forest > 0.15:
		base_count += 2
	match biome_center:
		"frost": base_count = 2
		"desert": base_count = 1
		"mushroom": base_count = 2
		"ash": base_count = 1
		_: base_count = 1 if forest < 0.2 else 3
	var count := base_count + rng.randi_range(0, 1)
	var out: Array = []
	for i in count:
		var lx := rng.randi_range(1, CHUNK - 2)
		var lz := rng.randi_range(1, CHUNK - 2)
		var wx := cx * CHUNK + lx
		var wz := cz * CHUNK + lz
		var h := height_at(wx, wz)
		var biome := biome_at(wx, wz)
		if h <= SEA + 1 or h >= HEIGHT - 12:
			continue
		if slope_at(wx, wz) > 3:
			continue
		var kind: String = Content.BIOMES[biome].tree
		if kind == "dead" and rng.randf() < 0.4:
			continue
		out.append({"x": wx, "z": wz, "y": h, "kind": kind, "seed": rng.randi()})
	return out

func _stamp_trees(buf: PackedByteArray, cx: int, cz: int) -> void:
	for ncx in range(cx - 1, cx + 2):
		for ncz in range(cz - 1, cz + 2):
			for t in _tree_list_for_chunk(ncx, ncz):
				_stamp_tree(buf, cx, cz, t)

func _stamp_tree(buf: PackedByteArray, cx: int, cz: int, t: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t.seed)
	var wx: int = int(t.x)
	var wz: int = int(t.z)
	var wy: int = int(t.y)
	var kind: String = t.kind
	match kind:
		"oak":
			var trunk_h := rng.randi_range(4, 6)
			for i in range(1, trunk_h + 1):
				_put_world(buf, cx, cz, wx, wy + i, wz, Content.LOG)
			var top := wy + trunk_h
			for dy in range(-2, 3):
				var radius := 2 if absi(dy) < 2 else 1
				for dx in range(-radius, radius + 1):
					for dz in range(-radius, radius + 1):
						if absi(dx) == radius and absi(dz) == radius and rng.randf() < 0.6:
							continue
						_put_world(buf, cx, cz, wx + dx, top + dy, wz + dz, Content.LEAVES, true)
			_put_world(buf, cx, cz, wx, top + 1, wz, Content.LEAVES, true)
			_put_world(buf, cx, cz, wx + 1, top + 1, wz, Content.LEAVES, true)
			_put_world(buf, cx, cz, wx - 1, top + 1, wz, Content.LEAVES, true)
			_put_world(buf, cx, cz, wx, top + 1, wz + 1, Content.LEAVES, true)
			_put_world(buf, cx, cz, wx, top + 1, wz - 1, Content.LEAVES, true)
		"pine":
			var trunk_h := rng.randi_range(6, 9)
			for i in range(1, trunk_h + 1):
				_put_world(buf, cx, cz, wx, wy + i, wz, Content.LOG)
			var layers := 4
			for l in layers:
				var ly := wy + trunk_h - l * 2
				var radius := l + 1
				for dx in range(-radius, radius + 1):
					for dz in range(-radius, radius + 1):
						if absi(dx) + absi(dz) > radius + 1:
							continue
						_put_world(buf, cx, cz, wx + dx, ly, wz + dz, Content.PINE_LEAVES, true)
				_put_world(buf, cx, cz, wx, ly + 1, wz, Content.PINE_LEAVES, true)
			_put_world(buf, cx, cz, wx, wy + trunk_h + 1, wz, Content.PINE_LEAVES, true)
		"cactus":
			var h := rng.randi_range(2, 4)
			for i in range(1, h + 1):
				_put_world(buf, cx, cz, wx, wy + i, wz, Content.CACTUS)
			if rng.randf() < 0.6:
				var side := 1 if rng.randf() < 0.5 else -1
				_put_world(buf, cx, cz, wx + side, wy + 2, wz, Content.CACTUS)
				_put_world(buf, cx, cz, wx + side, wy + 3, wz, Content.CACTUS)
		"giant_mushroom":
			var stem_h := rng.randi_range(4, 7)
			for i in range(1, stem_h + 1):
				_put_world(buf, cx, cz, wx, wy + i, wz, Content.MUSH_STEM)
			var top := wy + stem_h
			for dy in 0:
				for dx in range(-3, 4):
					for dz in range(-3, 4):
						if absi(dx) + absi(dz) <= 4:
							_put_world(buf, cx, cz, wx + dx, top + dy, wz + dz, Content.MUSH_CAP, true)
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					if absi(dx) + absi(dz) <= 2:
						_put_world(buf, cx, cz, wx + dx, top + 1, wz + dz, Content.MUSH_CAP, true)
			_put_world(buf, cx, cz, wx, top + 2, wz, Content.MUSH_CAP, true)
		"dead":
			var h := rng.randi_range(3, 5)
			for i in range(1, h + 1):
				_put_world(buf, cx, cz, wx, wy + i, wz, Content.LOG)
			_put_world(buf, cx, cz, wx + 1, wy + h, wz, Content.LOG)
			_put_world(buf, cx, cz, wx - 1, wy + h - 1, wz, Content.LOG)

func _stamp_plants(buf: PackedByteArray, cx: int, cz: int) -> void:
	var base_x := cx * CHUNK
	var base_z := cz * CHUNK
	for lz in CHUNK:
		for lx in CHUNK:
			var wx := base_x + lx
			var wz := base_z + lz
			var h := height_at(wx, wz)
			if h >= HEIGHT - 3 or h < SEA:
				continue
			if _vox(buf, lx, h + 2, lz) != Content.AIR or _vox(buf, lx, h + 1, lz) != Content.AIR:
				continue
			var ground := _vox(buf, lx, h, lz)
			var biome := biome_at(wx, wz)
			var r := hash01(wx, h, wz, 17)
			var plant := -1
			match biome:
				"meadow":
					if r < 0.11:
						plant = Content.TUFT
					elif r < 0.083:
						plant = [Content.FLOWER_RED, Content.FLOWER_YELLOW, Content.FLOWER_BLUE][int(hash01(wx, h, wz, 19) * 3.0) % 3]
				"mushroom":
					if r < 0.07:
						plant = Content.SMALL_MUSHROOM
					elif r < 0.07:
						plant = Content.FLOWER_BLUE
				"frost":
					if r < 0.018:
						plant = Content.FLOWER_BLUE
				"desert":
					if r < 0.008:
						plant = Content.TUFT
				_:
					pass
			if plant >= 0 and (ground == Content.GRASS or ground == Content.MYCELIUM or
					ground == Content.SNOW or ground == Content.SAND):
				_put(buf, lx, h + 1, lz, plant)

# ------------------------------------------------------------------ villages

func village_at_cell(sx: int, sz: int) -> Dictionary:
	var key := Vector2i(sx, sz)
	if _village_cache.has(key):
		return _village_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(Vector3i(sx, sz, seed_value + 401)))
	if rng.randf() > 0.62:
		_village_cache[key] = {}
		return {}
	var cx := sx * VILLAGE_GRID + rng.randi_range(36, VILLAGE_GRID - 36)
	var cz := sz * VILLAGE_GRID + rng.randi_range(36, VILLAGE_GRID - 36)
	var h := height_at(cx, cz)
	var biome := biome_at(cx, cz)
	if biome != "meadow" or h <= SEA + 1 or h > SEA + 20:
		_village_cache[key] = {}
		return {}
	var min_h := 999
	var max_h := -999
	for p in [Vector2i(-10, -10), Vector2i(10, -10), Vector2i(-10, 10), Vector2i(10, 10)]:
		var hh := height_at(cx + p.x, cz + p.y)
		min_h = mini(min_h, hh)
		max_h = maxi(max_h, hh)
	if max_h - min_h > 7:
		_village_cache[key] = {}
		return {}
	var info := {
		"id": "v%d_%d" % [sx, sz],
		"name": Content.VILLAGE_NAMES[absi(hash(Vector3i(sx, sz, seed_value + 407))) % Content.VILLAGE_NAMES.size()],
		"center": Vector3i(cx, h, cz),
		"radius": 17,
		"biome": biome,
		"houses": [],
		"npc_points": [],
		"field": Vector2i.ZERO,
	}
	var house_count := rng.randi_range(3, 4)
	for i in house_count:
		var angle := TAU * float(i) / float(house_count) + rng.randf_range(-0.35, 0.35)
		var dist := rng.randi_range(7, 11)
		var hx := cx + int(cos(angle) * dist)
		var hz := cz + int(sin(angle) * dist)
		var size := 7 if rng.randf() < 0.45 else 5
		var door_dir := Vector2i(signi(cx - hx), 0)
		if rng.randf() < 0.5:
			door_dir = Vector2i(0, signi(cz - hz))
		info.houses.append({"x": hx, "z": hz, "size": size, "door": door_dir,
			"style": rng.randi_range(0, 2), "chest": rng.randf() < 0.6})
		info.npc_points.append(Vector2i(hx + door_dir.x * (size / 2 + 1), hz + door_dir.y * (size / 2 + 1)))
	var field_x := cx + rng.randi_range(-12, 12)
	var field_z := cz + rng.randi_range(7, 12)
	var tries := 0
	while tries < 8:
		var ok := true
		for hs in info.houses:
			if Vector2i(field_x, field_z).distance_to(Vector2i(int(hs.x), int(hs.z))) < 7.0:
				ok = false
				break
		if ok:
			break
		field_x = cx + rng.randi_range(-13, 13)
		field_z = cz + rng.randi_range(-13, 13)
		tries += 1
	info.field = Vector2i(field_x, field_z)
	info.npc_points.append(Vector2i(cx + 3, cz))
	info.npc_points.append(Vector2i(cx - 3, cz + 2))
	_village_cache[key] = info
	return info

func nearby_villages(cx: int, cz: int) -> Array:
	var wx := cx * CHUNK
	var wz := cz * CHUNK
	var sx0 := int(floor(float(wx - 40) / VILLAGE_GRID))
	var sx1 := int(floor(float(wx + 40) / VILLAGE_GRID))
	var sz0 := int(floor(float(wz - 40) / VILLAGE_GRID))
	var sz1 := int(floor(float(wz + 40) / VILLAGE_GRID))
	var out: Array = []
	for sx in range(sx0, sx1 + 1):
		for sz in range(sz0, sz1 + 1):
			var info := village_at_cell(sx, sz)
			if not info.is_empty():
				out.append(info)
	return out

func _stamp_nearby_villages(buf: PackedByteArray, cx: int, cz: int) -> void:
	for info in nearby_villages(cx, cz):
		_stamp_village(buf, cx, cz, info)

func _stamp_village(buf: PackedByteArray, cx: int, cz: int, info: Dictionary) -> void:
	var center: Vector3i = info.center
	var base_x := cx * CHUNK
	var base_z := cz * CHUNK
	var radius := int(info.radius)
	var plateau := center.y
	if base_x + CHUNK < center.x - radius or base_x > center.x + radius:
		return
	if base_z + CHUNK < center.z - radius or base_z > center.z + radius:
		return
	# flatten ground
	for lz in CHUNK:
		for lx in CHUNK:
			var wx := base_x + lx
			var wz := base_z + lz
			var dx := wx - center.x
			var dz := wz - center.z
			if dx * dx + dz * dz > radius * radius:
				continue
			for y in range(1, plateau + 1):
				if y < plateau - 2:
					_put(buf, lx, y, lz, Content.STONE)
				else:
					buf[_idx(lx, y, lz)] = Content.DIRT
			buf[_idx(lx, plateau, lz)] = Content.GRASS
			for y in range(plateau + 1, mini(plateau + 14, HEIGHT)):
				buf[_idx(lx, y, lz)] = Content.AIR
			if absi(dx) <= 1 or absi(dz) <= 1:
				if dx * dx + dz * dz <= 12 * 12:
					buf[_idx(lx, plateau, lz)] = Content.GRAVEL
	# houses
	for hs in info.houses:
		_stamp_house(buf, cx, cz, info, hs, plateau)
	# village well
	var wcx: int = center.x
	var wcz: int = center.z
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			_put_world(buf, cx, cz, wcx + dx, plateau + 1, wcz + dz, Content.STONE_BRICK)
	_put_world(buf, cx, cz, wcx, plateau + 1, wcz, Content.WATER)
	# farm field
	var fx: int = info.field.x
	var fz: int = info.field.y
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			_put_world(buf, cx, cz, fx + dx, plateau, fz + dz, Content.FARMLAND)
			_put_world(buf, cx, cz, fx + dx, plateau + 1, fz + dz, Content.AIR)
			if dx == 0:
				_put_world(buf, cx, cz, fx + dx, plateau, fz + dz, Content.WATER)
			elif hash01(fx + dx, plateau, fz + dz, 29) < 0.65:
				_put_world(buf, cx, cz, fx + dx, plateau + 1, fz + dz, Content.WHEAT3)
	# lamps
	for p in [Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(-2, -2)]:
		_put_world(buf, cx, cz, center.x + p.x, plateau + 1, center.z + p.y, Content.LOG)
		_put_world(buf, cx, cz, center.x + p.x, plateau + 2, center.z + p.y, Content.LAMP)

func _stamp_house(buf: PackedByteArray, cx: int, cz: int, info: Dictionary, hs: Dictionary,
		plateau: int) -> void:
	var size: int = int(hs.size)
	var half := size / 2
	var hx: int = int(hs.x)
	var hz: int = int(hs.z)
	var y0 := plateau + 1
	var style: int = int(hs.style)
	var wall_a: int = [Content.PLASTER, Content.PLANKS, Content.STONE_BRICK][style % 3]
	var wall_b: int = [Content.PLANKS, Content.DOOR, Content.PLASTER][style % 3]
	for dx in range(-half - 1, half + 2):
		for dz in range(-half - 1, half + 2):
			_put_world(buf, cx, cz, hx + dx, plateau + 4, hz + dz, Content.ROOF)
			if absi(dx) <= half and absi(dz) <= half:
				_put_world(buf, cx, cz, hx + dx, plateau + 5, hz + dz, Content.AIR)
	for dx in range(-half + 1, half):
		for dz in range(-half + 1, half):
			_put_world(buf, cx, cz, hx + dx, plateau, hz + dz, Content.PLANKS)
			for y in range(y0, y0 + 3):
				_put_world(buf, cx, cz, hx + dx, y, hz + dz, Content.AIR)
	# walls
	for dx in range(-half, half + 1):
		for dz in range(-half, half + 1):
			var edge := absi(dx) == half or absi(dz) == half
			if not edge:
				continue
			for y in range(y0, y0 + 3):
				_put_world(buf, cx, cz, hx + dx, y, hz + dz, wall_a if (dx + dz) % 3 != 0 else wall_b)
			if (absi(dx) + absi(dz)) % 4 == 0:
				_put_world(buf, cx, cz, hx + dx, y0 + 1, hz + dz, Content.GLASS)
			_put_world(buf, cx, cz, hx + dx, plateau, hz + dz, Content.PLASTER)
	var door: Vector2i = hs.door
	var dxx := hx + door.x * half
	var dzz := hz + door.y * half
	_put_world(buf, cx, cz, dxx, y0, dzz, Content.AIR)
	_put_world(buf, cx, cz, dxx, y0 + 1, dzz, Content.AIR)
	_put_world(buf, cx, cz, dxx + door.y, y0 + 2, dzz + door.x, Content.LAMP)
	if bool(hs.chest):
		_put_world(buf, cx, cz, hx - half + 1, y0, hz - half + 1, Content.CHEST)
	_put_world(buf, cx, cz, hx, plateau + 5, hz, Content.ROOF)

# ------------------------------------------------------------------ dungeons

func dungeon_at_cell(sx: int, sz: int) -> Dictionary:
	var key := Vector2i(sx, sz)
	if _dungeon_cache.has(key):
		return _dungeon_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(Vector3i(sx, sz, seed_value + 503)))
	if rng.randf() > 0.58:
		_dungeon_cache[key] = {}
		return {}
	var cx := sx * DUNGEON_GRID + rng.randi_range(48, DUNGEON_GRID - 48)
	var cz := sz * DUNGEON_GRID + rng.randi_range(48, DUNGEON_GRID - 48)
	var h := height_at(cx, cz)
	var biome := biome_at(cx, cz)
	if h <= SEA or h >= HEIGHT - 8:
		_dungeon_cache[key] = {}
		return {}
	# keep some distance from villages
	for vsx in range(int(floor(float(cx) / VILLAGE_GRID)) - 1, int(floor(float(cx) / VILLAGE_GRID)) + 2):
		for vsz in range(int(floor(float(cz) / VILLAGE_GRID)) - 1, int(floor(float(cz) / VILLAGE_GRID)) + 2):
			var v := village_at_cell(vsx, vsz)
			if not v.is_empty() and Vector2(cx, cz).distance_to(Vector2(v.center.x, v.center.z)) < 64.0:
				_dungeon_cache[key] = {}
				return {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var dir: Vector2i = dirs[rng.randi_range(0, 3)]
	var d: Dictionary = Content.dungeon_for_biome(biome)
	var room_y := clampi(h - rng.randi_range(12, 16), 9, 28)
	var steps := maxi(7, h - room_y - 1)
	var room_center := Vector2i(cx, cz) + dir * (steps + 10)
	var info := {
		"id": "d%d_%d" % [sx, sz],
		"name": d.name,
		"type": d.id,
		"boss": d.boss,
		"biome": biome,
		"entrance": Vector3i(cx, h, cz),
		"dir": dir,
		"steps": steps,
		"room_y": room_y,
		"room_center": Vector3i(room_center.x, room_y, room_center.y),
		"radius": 12,
		"tier": 2 if biome != "meadow" else 1,
	}
	_dungeon_cache[key] = info
	return info

func nearby_dungeons(cx: int, cz: int) -> Array:
	var wx := cx * CHUNK
	var wz := cz * CHUNK
	var sx0 := int(floor(float(wx - 80) / DUNGEON_GRID))
	var sx1 := int(floor(float(wx + 80) / DUNGEON_GRID))
	var sz0 := int(floor(float(wz - 80) / DUNGEON_GRID))
	var sz1 := int(floor(float(wz + 80) / DUNGEON_GRID))
	var out: Array = []
	for sx in range(sx0, sx1 + 1):
		for sz in range(sz0, sz1 + 1):
			var info := dungeon_at_cell(sx, sz)
			if not info.is_empty():
				out.append(info)
	return out

func _stamp_nearby_dungeons(buf: PackedByteArray, cx: int, cz: int) -> void:
	for info in nearby_dungeons(cx, cz):
		_stamp_dungeon(buf, cx, cz, info)

func _stamp_dungeon(buf: PackedByteArray, cx: int, cz: int, info: Dictionary) -> void:
	var e: Vector3i = info.entrance
	var room: Vector3i = info.room_center
	var base_x := cx * CHUNK
	var base_z := cz * CHUNK
	# bounding box quick reject
	if base_x + CHUNK < mini(e.x, room.x - 10) or base_x > maxi(e.x, room.x + 10):
		return
	if base_z + CHUNK < mini(e.z, room.z - 10) or base_z > maxi(e.z, room.z + 10):
		return
	var dir: Vector2i = info.dir
	var room_y: int = int(info.room_y)
	var steps: int = int(info.steps)
	var brick := Content.DUNGEON_BRICK
	# entrance platform and arch
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			_put_world(buf, cx, cz, e.x + dx, e.y, e.z + dz, Content.STONE_BRICK)
			for y in range(e.y + 1, e.y + 6):
				_put_world(buf, cx, cz, e.x + dx, y, e.z + dz, Content.AIR)
	for dx in range(-2, 3):
		for y in range(e.y + 1, e.y + 5):
			if absi(dx) == 2:
				_put_world(buf, cx, cz, e.x + dx, y, e.z - 2, Content.STONE_BRICK)
				_put_world(buf, cx, cz, e.x + dx, y, e.z + 2, Content.STONE_BRICK)
	for dz in range(-2, 3):
		for y in range(e.y + 1, e.y + 5):
			if absi(dz) == 2:
				_put_world(buf, cx, cz, e.x - 2, y, e.z + dz, Content.STONE_BRICK)
				_put_world(buf, cx, cz, e.x + 2, y, e.z + dz, Content.STONE_BRICK)
	_put_world(buf, cx, cz, e.x, e.y + 4, e.z, Content.LAMP)
	# stairs
	for i in steps:
		var sx := e.x + dir.x * (i + 1)
		var sz := e.z + dir.y * (i + 1)
		var sy := e.y - 1 - i
		var perp := Vector2i(-dir.y, dir.x)
		for w in range(-1, 2):
			for hgt in 3:
				_put_world(buf, cx, cz, sx + perp.x * w, sy + hgt, sz + perp.y * w, Content.AIR)
			_put_world(buf, cx, cz, sx + perp.x * w, sy - 1, sz + perp.y * w, brick)
			_put_world(buf, cx, cz, sx + perp.x * w, sy + 3, sz + perp.y * w, brick)
		_put_world(buf, cx, cz, sx + perp.x * 2, sy, sz + perp.y * 2, brick)
		_put_world(buf, cx, cz, sx + perp.x * 2, sy + 1, sz + perp.y * 2, brick)
		_put_world(buf, cx, cz, sx - perp.x * 2, sy, sz - perp.y * 2, brick)
		_put_world(buf, cx, cz, sx - perp.x * 2, sy + 1, sz - perp.y * 2, brick)
		if i % 4 == 0:
			_put_world(buf, cx, cz, sx + perp.x * 2, sy + 2, sz + perp.y * 2, Content.TORCH)
	# room
	for dx in range(-7, 8):
		for dz in range(-7, 8):
			for y in range(room_y, room_y + 7):
				_put_world(buf, cx, cz, room.x + dx, y, room.z + dz, Content.AIR)
			_put_world(buf, cx, cz, room.x + dx, room_y - 1, room.z + dz, brick)
	# walls / ceiling
	for dx in range(-8, 9):
		for dz in range(-8, 9):
			var perimeter := absi(dx) == 8 or absi(dz) == 8
			if perimeter:
				for y in range(room_y - 1, room_y + 8):
					_put_world(buf, cx, cz, room.x + dx, y, room.z + dz, brick)
			_put_world(buf, cx, cz, room.x + dx, room_y + 7, room.z + dz, brick)
	# pillars and accent
	for p in [Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]:
		for y in range(room_y, room_y + 6):
			_put_world(buf, cx, cz, room.x + p.x, y, room.z + p.y, brick)
		_put_world(buf, cx, cz, room.x + p.x, room_y + 5, room.z + p.y, Content.LAMP)
	var accent := Content.CRYSTAL_BLOCK
	if info.type == "ember":
		accent = Content.LAVA
	elif info.type == "frost":
		accent = Content.ICE
	for dx in range(-2, 3):
		_put_world(buf, cx, cz, room.x + dx, room_y, room.z, Content.RUNE if dx == 0 else brick)
	# chests
	_put_world(buf, cx, cz, room.x - 5, room_y, room.z - 5, Content.CHEST)
	_put_world(buf, cx, cz, room.x + 5, room_y, room.z + 5, Content.CHEST)
	# entrance stairs railing accents
	for i in range(0, steps, 3):
		var sx2 := e.x + dir.x * (i + 1)
		var sz2 := e.z + dir.y * (i + 1)
		var sy2 := e.y - 1 - i
		var perp2 := Vector2i(-dir.y, dir.x)
		_put_world(buf, cx, cz, sx2 + perp2.x * 2, sy2, sz2 + perp2.y * 2, Content.CRYSTAL_BLOCK)
	# connection from stairs to room: carve a short hall
	var last_x := e.x + dir.x * steps
	var last_z := e.z + dir.y * steps
	var last_y := room_y
	var perp3 := Vector2i(-dir.y, dir.x)
	for t in 10:
		var hx := last_x + dir.x * t
		var hz := last_z + dir.y * t
		for w in range(-1, 2):
			for hgt in 4:
				_put_world(buf, cx, cz, hx + perp3.x * w, last_y + hgt, hz + perp3.y * w, Content.AIR)
			_put_world(buf, cx, cz, hx + perp3.x * w, last_y - 1, hz + perp3.y * w, brick)
			_put_world(buf, cx, cz, hx + perp3.x * w, last_y + 4, hz + perp3.y * w, brick)
		_put_world(buf, cx, cz, hx + perp3.x * 2, last_y + 1, hz + perp3.y * 2, brick)
		_put_world(buf, cx, cz, hx - perp3.x * 2, last_y + 1, hz - perp3.y * 2, brick)

# ------------------------------------------------------------------ world queries

func nearest_village(from: Vector3, max_cells: int = 2) -> Dictionary:
	var best := {}
	var best_dist := 1.0e20
	var csx := int(floor(from.x / VILLAGE_GRID))
	var csz := int(floor(from.z / VILLAGE_GRID))
	for sx in range(csx - max_cells, csx + max_cells + 1):
		for sz in range(csz - max_cells, csz + max_cells + 1):
			var info := village_at_cell(sx, sz)
			if info.is_empty():
				continue
			var c: Vector3i = info.center
			var d := Vector2(from.x - c.x, from.z - c.z).length()
			if d < best_dist:
				best_dist = d
				best = info
	return best

func nearest_dungeon(from: Vector3, max_cells: int = 2) -> Dictionary:
	var best := {}
	var best_dist := 1.0e20
	var csx := int(floor(from.x / DUNGEON_GRID))
	var csz := int(floor(from.z / DUNGEON_GRID))
	for sx in range(csx - max_cells, csx + max_cells + 1):
		for sz in range(csz - max_cells, csz + max_cells + 1):
			var info := dungeon_at_cell(sx, sz)
			if info.is_empty():
				continue
			var c: Vector3i = info.entrance
			var d := Vector2(from.x - c.x, from.z - c.z).length()
			if d < best_dist:
				best_dist = d
				best = info
	return best

func find_spawn() -> Vector3:
	var candidates: Array = []
	for radius in range(0, 260, 12):
		var steps := maxi(8, radius / 8)
		for i in steps:
			var a := TAU * float(i) / float(steps)
			var x := int(cos(a) * radius) + 8
			var z := int(sin(a) * radius) + 8
			var h := height_at(x, z)
			var biome := biome_at(x, z)
			if biome == "meadow" and h > SEA + 2 and slope_at(x, z) <= 2:
				candidates.append(Vector3(x + 0.5, h + 2.0, z + 0.5))
		if candidates.size() >= 4:
			break
	if candidates.is_empty():
		var h2 := height_at(8, 8)
		return Vector3(8.5, h2 + 3.0, 8.5)
	return candidates[absi(hash(seed_value)) % candidates.size()]

func map_color_at(x: int, z: int) -> Color:
	var h := height_at(x, z)
	var biome := biome_at(x, z)
	if h < SEA:
		if biome == "frost":
			return Color("#bfe6ee")
		if biome == "ash" and h < SEA:
			return Color("#d97a3a")
		return Color("#5fa8c8") if h > SEA - 8 else Color("#3d7fa6")
	var c: Color = Content.BIOMES[biome].map_color
	var jitter := n_surface.get_noise_2d(x, z) * 0.08
	if h > SEA + 18:
		c = c.lerp(Color("#e7e4dc"), clampf((h - SEA - 18) / 30.0, 0.0, 0.55))
	return c.lightened(jitter)


# ------------------------------------------------------------------ landmarks

const LANDMARK_GRID := 148

const LANDMARK_NAMES := {
	"obelisk": "Sunken Obelisk",
	"ruins": "Weathered Ruins",
	"shrine": "Forgotten Shrine",
	"watchtower": "Broken Watchtower",
	"mushroom_ring": "Fairy Ring",
	"gate": "Ancient Gate",
}

func landmark_at_cell(sx: int, sz: int) -> Dictionary:
	var key := Vector2i(sx, sz)
	if _landmark_cache.has(key):
		return _landmark_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(Vector3i(sx * 31 + seed_value, 977, sz * 17 - seed_value)))
	var out: Dictionary = {}
	if rng.randf() < 0.62:
		var kinds := ["ruins", "shrine", "watchtower", "mushroom_ring", "gate"]
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		if rng.randf() < 0.12:
			kind = "obelisk"
		var wx := sx * LANDMARK_GRID + rng.randi_range(24, LANDMARK_GRID - 24)
		var wz := sz * LANDMARK_GRID + rng.randi_range(24, LANDMARK_GRID - 24)
		var wy := height_at(wx, wz)
		if wy >= 6 and wy <= 96:
			out = {"id": "lm_%d_%d" % [sx, sz], "kind": kind, "pos": Vector3i(wx, wy, wz),
				"name": LANDMARK_NAMES.get(kind, "Old Stones"), "cell": key}
	_landmark_cache[key] = out
	return out

func nearby_landmarks(cx: int, cz: int) -> Array:
	var out: Array = []
	var base_x := cx * CHUNK
	var base_z := cz * CHUNK
	var sx0 := int(floor(float(base_x - 24) / LANDMARK_GRID))
	var sx1 := int(floor(float(base_x + CHUNK + 24) / LANDMARK_GRID))
	var sz0 := int(floor(float(base_z - 24) / LANDMARK_GRID))
	var sz1 := int(floor(float(base_z + CHUNK + 24) / LANDMARK_GRID))
	for sx in range(sx0, sx1 + 1):
		for sz in range(sz0, sz1 + 1):
			var info := landmark_at_cell(sx, sz)
			if not info.is_empty():
				out.append(info)
	return out

func landmark_at_pos(pos: Vector3) -> Dictionary:
	var sx := int(floor(pos.x / LANDMARK_GRID))
	var sz := int(floor(pos.z / LANDMARK_GRID))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var info := landmark_at_cell(sx + dx, sz + dz)
			if info.is_empty():
				continue
			var p: Vector3i = info.pos
			if absf(pos.x - p.x) < 22.0 and absf(pos.z - p.z) < 22.0 and absf(pos.y - p.y) < 22.0:
				return info
	return {}

func nearby_landmarks_at(pos: Vector3) -> Array:
	var out: Array = []
	var sx := int(floor(pos.x / LANDMARK_GRID))
	var sz := int(floor(pos.z / LANDMARK_GRID))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var info := landmark_at_cell(sx + dx, sz + dz)
			if not info.is_empty():
				out.append(info)
	return out

func _stamp_nearby_landmarks(buf: PackedByteArray, cx: int, cz: int) -> void:
	for info in nearby_landmarks(cx, cz):
		_stamp_landmark(buf, cx, cz, info)

func _stamp_landmark(buf: PackedByteArray, cx: int, cz: int, info: Dictionary) -> void:
	var p: Vector3i = info.pos
	var base_x := cx * CHUNK
	var base_z := cz * CHUNK
	if p.x + 16 < base_x or p.x - 16 > base_x + CHUNK:
		return
	if p.z + 16 < base_z or p.z - 16 > base_z + CHUNK:
		return
	var y := p.y
	var kind := str(info.kind)
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			_put_world(buf, cx, cz, p.x + dx, y, p.z + dz, Content.STONE_BRICK)
			for clear_h in range(1, 6):
				_put_world(buf, cx, cz, p.x + dx, y + clear_h, p.z + dz, Content.AIR)
	match kind:
		"obelisk":
			for oh in range(1, 14):
				var rad := 2 if oh < 9 else 1
				for dx in range(-rad, rad + 1):
					for dz in range(-rad, rad + 1):
						if absi(dx) == rad or absi(dz) == rad or oh < 2:
							_put_world(buf, cx, cz, p.x + dx, y + oh, p.z + dz, Content.STONE_BRICK)
			_put_world(buf, cx, cz, p.x, y + 14, p.z, Content.LAMP)
			_put_world(buf, cx, cz, p.x + 3, y + 1, p.z + 3, Content.RUNE)
			_put_world(buf, cx, cz, p.x - 3, y + 1, p.z - 3, Content.TORCH)
		"ruins":
			for dx in range(-5, 6):
				for dz in range(-5, 6):
					if absi(dx) != 5 and absi(dz) != 5:
						continue
					var hh := 1 + int(hash01(p.x + dx, y, p.z + dz, 3) * 5.0)
					for uh in range(1, hh + 1):
						_put_world(buf, cx, cz, p.x + dx, y + uh, p.z + dz, Content.STONE_BRICK)
			_put_world(buf, cx, cz, p.x, y + 1, p.z, Content.RUNE)
			_put_world(buf, cx, cz, p.x + 2, y + 1, p.z, Content.TORCH)
			_put_world(buf, cx, cz, p.x - 2, y + 1, p.z, Content.TORCH)
		"shrine":
			for dx in range(-4, 5):
				for dz in range(-4, 5):
					if absi(dx) == 4 or absi(dz) == 4:
						for sh in range(1, 5):
							_put_world(buf, cx, cz, p.x + dx, y + sh, p.z + dz, Content.STONE_BRICK)
			for corner in [Vector2i(-3, -3), Vector2i(3, -3), Vector2i(-3, 3), Vector2i(3, 3)]:
				for sh2 in range(1, 5):
					_put_world(buf, cx, cz, p.x + corner.x, y + sh2, p.z + corner.y, Content.STONE_BRICK)
				_put_world(buf, cx, cz, p.x + corner.x, y + 5, p.z + corner.y, Content.LAMP)
			_put_world(buf, cx, cz, p.x, y + 1, p.z, Content.RUNE)
		"watchtower":
			for ty in range(1, 9):
				for dx in range(-2, 3):
					for dz in range(-2, 3):
						if absi(dx) == 2 or absi(dz) == 2:
							if ty < 8 or absi(dx) < 2:
								_put_world(buf, cx, cz, p.x + dx, y + ty, p.z + dz, Content.STONE_BRICK)
			_put_world(buf, cx, cz, p.x, y + 9, p.z, Content.LAMP)
			_put_world(buf, cx, cz, p.x, y + 1, p.z, Content.RUNE)
			_put_world(buf, cx, cz, p.x + 4, y + 1, p.z, Content.TORCH)
		"mushroom_ring":
			for ri in 9:
				var ang := float(ri) * TAU / 9.0
				var rx := p.x + int(round(cos(ang) * 7.0))
				var rz := p.z + int(round(sin(ang) * 7.0))
				_put_world(buf, cx, cz, rx, y + 1, rz, Content.CRYSTAL_ORE)
				_put_world(buf, cx, cz, rx, y + 2, rz, Content.TORCH)
			_put_world(buf, cx, cz, p.x, y + 1, p.z, Content.RUNE)
		"gate":
			for gh in range(1, 7):
				_put_world(buf, cx, cz, p.x - 3, y + gh, p.z, Content.STONE_BRICK)
				_put_world(buf, cx, cz, p.x + 3, y + gh, p.z, Content.STONE_BRICK)
			for dx in range(-4, 5):
				_put_world(buf, cx, cz, p.x + dx, y + 7, p.z, Content.STONE_BRICK)
			_put_world(buf, cx, cz, p.x - 2, y + 5, p.z, Content.LAMP)
			_put_world(buf, cx, cz, p.x + 2, y + 5, p.z, Content.LAMP)
			_put_world(buf, cx, cz, p.x, y + 1, p.z - 1, Content.RUNE)
			_put_world(buf, cx, cz, p.x, y + 8, p.z, Content.CRYSTAL_ORE)
