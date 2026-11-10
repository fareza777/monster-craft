class_name GreedyMesher
extends RefCounted
## Optimized greedy voxel mesher. A padded voxel buffer removes all border
## checks, block data is flattened into lookup tables, and both face directions
## are gathered in the same pass.

const CHUNK := 16
const HEIGHT := 80
const PW := CHUNK + 2
const PH := HEIGHT + 2
const PSTRIDE := PW
const PYSTRIDE := PW * PW
const PADSIZE := PW * PW * PH

static var active_tint := Color.WHITE

class Builder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func is_empty() -> bool:
		return verts.is_empty()

	func add_quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3,
			u0: Vector2, u1: Vector2, u2: Vector2, u3: Vector2, tile: int,
			shade: float, emit: float, tint: Color = Color.WHITE,
			rough: float = 0.9) -> void:
		var base := verts.size()
		verts.append(p0)
		verts.append(p1)
		verts.append(p2)
		verts.append(p3)
		for i in 4:
			normals.append(n)
			uv2s.append(Vector2(tile, rough))
			colors.append(Color(shade * tint.r, shade * tint.g, shade * tint.b, emit))
		uvs.append(u0)
		uvs.append(u1)
		uvs.append(u2)
		uvs.append(u3)
		indices.append(base + 0)
		indices.append(base + 2)
		indices.append(base + 1)
		indices.append(base + 0)
		indices.append(base + 3)
		indices.append(base + 2)

	func to_dict() -> Dictionary:
		return {"v": verts, "n": normals, "uv": uvs, "uv2": uv2s, "c": colors, "i": indices}

static func prewarm() -> void:
	pass

static func build(data: PackedByteArray, nx: PackedByteArray, px: PackedByteArray,
		nz: PackedByteArray, pz: PackedByteArray, cx: int, cz: int,
		tint: Color = Color.WHITE) -> Dictionary:
	active_tint = tint
	var pad := _pad(data, nx, px, nz, pz)
	var tables := _tables()
	var tops: PackedInt32Array = tables["tops"]
	var sides: PackedInt32Array = tables["sides"]
	var bottoms: PackedInt32Array = tables["bottoms"]
	var groups: PackedInt32Array = tables["groups"]
	var opaque: PackedByteArray = tables["opaque"]
	var emits: PackedFloat32Array = tables["emits"]
	var solid := Builder.new()
	var transparent := Builder.new()
	var liquid := Builder.new()
	var plants := Builder.new()
	var base_x := cx * CHUNK
	var base_z := cz * CHUNK
	for d in 3:
		var w := CHUNK
		var h := HEIGHT
		var slices := CHUNK
		var step := 1
		if d == 1:
			h = CHUNK
			slices = HEIGHT
			step = PYSTRIDE
		elif d == 2:
			slices = CHUNK
			step = PSTRIDE
		var mask_pos := PackedInt32Array()
		mask_pos.resize(w * h)
		var mask_neg := PackedInt32Array()
		mask_neg.resize(w * h)
		var used_pos := PackedByteArray()
		used_pos.resize(w * h)
		var used_neg := PackedByteArray()
		used_neg.resize(w * h)
		for q in slices:
			mask_pos.fill(0)
			mask_neg.fill(0)
			used_pos.fill(0)
			used_neg.fill(0)
			for vi in h:
				var row := vi * w
				for ui in w:
					var idx := 0
					var face := 1
					match d:
						0:
							idx = (q + 1) + (ui + 1) * PSTRIDE + (vi + 1) * PYSTRIDE
						1:
							idx = (ui + 1) + (vi + 1) * PSTRIDE + (q + 1) * PYSTRIDE
							face = 0
						2:
							idx = (ui + 1) + (q + 1) * PSTRIDE + (vi + 1) * PYSTRIDE
					var b := pad[idx]
					if b == 0:
						continue
					var g := groups[b]
					if g == 0 or g == 4:
						continue
					var nb := pad[idx + step]
					if nb == 0 or (opaque[nb] == 0 and nb != b):
						mask_pos[row + ui] = b * 4 + face + 1
					var nb2 := pad[idx - step]
					if nb2 == 0 or (opaque[nb2] == 0 and nb2 != b):
						var f2 := 2 if d == 1 else 1
						mask_neg[row + ui] = b * 4 + f2 + 1
			_merge_emit(mask_pos, used_pos, w, h, d, 1, q, solid, transparent, liquid,
				base_x, base_z, tops, sides, bottoms, groups, emits)
			_merge_emit(mask_neg, used_neg, w, h, d, -1, q, solid, transparent, liquid,
				base_x, base_z, tops, sides, bottoms, groups, emits)
	# plants use two crossed quads
	for y in HEIGHT:
		for z in CHUNK:
			var zrow := (z + 1) * PSTRIDE + (y + 1) * PYSTRIDE
			for x in CHUNK:
				var b := pad[(x + 1) + zrow]
				if b == 0 or groups[b] != 4:
					continue
				var tile := sides[b]
				var emit := emits[b]
				var px0 := float(x) + 0.12
				var px1 := float(x) + 0.88
				var pz0 := float(z) + 0.12
				var pz1 := float(z) + 0.88
				var py0 := float(y)
				var py1 := float(y) + 1.0
				plants.add_quad(Vector3(px0, py0, pz0), Vector3(px1, py0, pz1),
					Vector3(px1, py1, pz1), Vector3(px0, py1, pz0), Vector3(0, 0, 1),
					Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), tile, 1.0, emit)
				plants.add_quad(Vector3(px1, py0, pz0), Vector3(px0, py0, pz1),
					Vector3(px0, py1, pz1), Vector3(px1, py1, pz0), Vector3(0, 0, 1),
					Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), tile, 1.0, emit)
	return {
		"solid": solid.to_dict(),
		"transparent": transparent.to_dict(),
		"liquid": liquid.to_dict(),
		"plants": plants.to_dict(),
	}

static func _tables() -> Dictionary:
	var tops := PackedInt32Array()
	tops.resize(256)
	var sides := PackedInt32Array()
	sides.resize(256)
	var bottoms := PackedInt32Array()
	bottoms.resize(256)
	var groups := PackedInt32Array()
	groups.resize(256)
	var opaque := PackedByteArray()
	opaque.resize(256)
	var emits := PackedFloat32Array()
	emits.resize(256)
	for i in 256:
		var bd: Dictionary = Content.BLOCKS.get(i, {})
		if bd.is_empty():
			groups[i] = 0
			opaque[i] = 1
			emits[i] = 0.0
			continue
		tops[i] = int(bd.top)
		sides[i] = int(bd.side)
		bottoms[i] = int(bd.bottom)
		var render: String = bd.get("render", "opaque")
		match render:
			"transparent":
				groups[i] = 2
			"liquid":
				groups[i] = 3
			"plant":
				groups[i] = 4
			_:
				groups[i] = 1
		opaque[i] = 1 if bd.get("opaque", true) else 0
		emits[i] = clampf(float(bd.get("light", 0.0)), 0.0, 1.0)
	return {"tops": tops, "sides": sides, "bottoms": bottoms, "groups": groups,
		"opaque": opaque, "emits": emits}

static func _pad(data: PackedByteArray, nx: PackedByteArray, px: PackedByteArray,
		nz: PackedByteArray, pz: PackedByteArray) -> PackedByteArray:
	var pad := PackedByteArray()
	pad.resize(PADSIZE)
	pad.fill(0)
	for z in PW:
		for x in PW:
			pad[x + z * PSTRIDE] = Content.STONE
			pad[x + z * PSTRIDE + (PH - 1) * PYSTRIDE] = Content.STONE
	for y in HEIGHT:
		var yoff := (y + 1) * PYSTRIDE
		for z in CHUNK:
			var zoff := (z + 1) * PSTRIDE + yoff
			var src_z := z * CHUNK + y * CHUNK * CHUNK
			for x in CHUNK:
				pad[(x + 1) + zoff] = data[x + src_z]
		if not nx.is_empty():
			for z in CHUNK:
				pad[(z + 1) * PSTRIDE + yoff] = nx[(CHUNK - 1) + z * CHUNK + y * CHUNK * CHUNK]
		if not px.is_empty():
			for z in CHUNK:
				pad[(PW - 1) + (z + 1) * PSTRIDE + yoff] = px[z * CHUNK + y * CHUNK * CHUNK]
		if not nz.is_empty():
			for x in CHUNK:
				pad[(x + 1) + yoff] = nz[x + (CHUNK - 1) * CHUNK + y * CHUNK * CHUNK]
		if not pz.is_empty():
			for x in CHUNK:
				pad[(x + 1) + (PW - 1) * PSTRIDE + yoff] = pz[x + y * CHUNK * CHUNK]
	return pad

static func _merge_emit(mask: PackedInt32Array, used: PackedByteArray, w: int, h: int,
		d: int, sign: int, q: int, solid: Builder, transparent: Builder, liquid: Builder,
		base_x: int, base_z: int, tops: PackedInt32Array, sides: PackedInt32Array,
		bottoms: PackedInt32Array, groups: PackedInt32Array, emits: PackedFloat32Array) -> void:
	for vi in h:
		var row := vi * w
		for ui in w:
			var idx := row + ui
			var key := mask[idx]
			if key == 0 or used[idx] == 1:
				continue
			var ww := 1
			while ui + ww < w and used[row + ui + ww] == 0 and mask[row + ui + ww] == key:
				ww += 1
			var hh := 1
			var stop := false
			while vi + hh < h and not stop:
				var nrow := (vi + hh) * w
				for uu in ww:
					if used[nrow + ui + uu] == 1 or mask[nrow + ui + uu] != key:
						stop = true
						break
				if not stop:
					hh += 1
			for vv in hh:
				var frow := (vi + vv) * w
				for uu in ww:
					used[frow + ui + uu] = 1
			var vkey := key - 1
			var b_id: int = vkey >> 2
			var f_id: int = vkey & 3
			var tile := sides[b_id]
			if f_id == 0:
				tile = tops[b_id]
			elif f_id == 2:
				tile = bottoms[b_id]
			var emit := emits[b_id]
			var shade := 1.0
			var n := Vector3.ZERO
			var u1 := ui + ww
			var v1 := vi + hh
			var p0: Vector3
			var p1: Vector3
			var p2: Vector3
			var p3: Vector3
			var uv0: Vector2
			var uv1: Vector2
			var uv2: Vector2
			var uv3: Vector2
			if d == 0:
				var xp := float(q + (1 if sign > 0 else 0))
				var y0 := float(vi)
				var y1 := float(v1)
				var z0 := float(ui)
				var z1 := float(u1)
				n = Vector3(float(sign), 0, 0)
				var wz0 := base_z + z0
				var wz1 := base_z + z1
				if sign > 0:
					p0 = Vector3(xp, y0, z1); p1 = Vector3(xp, y0, z0)
					p2 = Vector3(xp, y1, z0); p3 = Vector3(xp, y1, z1)
					uv0 = Vector2(wz1, y0); uv1 = Vector2(wz0, y0)
					uv2 = Vector2(wz0, y1); uv3 = Vector2(wz1, y1)
					shade = 0.90
				else:
					p0 = Vector3(xp, y0, z0); p1 = Vector3(xp, y0, z1)
					p2 = Vector3(xp, y1, z1); p3 = Vector3(xp, y1, z0)
					uv0 = Vector2(wz0, y0); uv1 = Vector2(wz1, y0)
					uv2 = Vector2(wz1, y1); uv3 = Vector2(wz0, y1)
					shade = 0.884
			elif d == 1:
				var yp := float(q + (1 if sign > 0 else 0))
				var x0 := float(ui)
				var x1 := float(u1)
				var z0 := float(vi)
				var z1 := float(v1)
				n = Vector3(0, float(sign), 0)
				var wx0 := base_x + x0
				var wx1 := base_x + x1
				var wz0b := base_z + z0
				var wz1b := base_z + z1
				if sign > 0:
					p0 = Vector3(x0, yp, z1); p1 = Vector3(x1, yp, z1)
					p2 = Vector3(x1, yp, z0); p3 = Vector3(x0, yp, z0)
					uv0 = Vector2(wx0, wz1b); uv1 = Vector2(wx1, wz1b)
					uv2 = Vector2(wx1, wz0b); uv3 = Vector2(wx0, wz0b)
					shade = 1.0
				else:
					p0 = Vector3(x0, yp, z0); p1 = Vector3(x1, yp, z0)
					p2 = Vector3(x1, yp, z1); p3 = Vector3(x0, yp, z1)
					uv0 = Vector2(wx0, wz0b); uv1 = Vector2(wx1, wz0b)
					uv2 = Vector2(wx1, wz1b); uv3 = Vector2(wx0, wz1b)
					shade = 0.52
			else:
				var zp := float(q + (1 if sign > 0 else 0))
				var x0 := float(ui)
				var x1 := float(u1)
				var y0 := float(vi)
				var y1 := float(v1)
				n = Vector3(0, 0, float(sign))
				var wx0 := base_x + x0
				var wx1 := base_x + x1
				if sign > 0:
					p0 = Vector3(x0, y0, zp); p1 = Vector3(x1, y0, zp)
					p2 = Vector3(x1, y1, zp); p3 = Vector3(x0, y1, zp)
					uv0 = Vector2(wx0, y0); uv1 = Vector2(wx1, y0)
					uv2 = Vector2(wx1, y1); uv3 = Vector2(wx0, y1)
					shade = 0.94
				else:
					p0 = Vector3(x1, y0, zp); p1 = Vector3(x0, y0, zp)
					p2 = Vector3(x0, y1, zp); p3 = Vector3(x1, y1, zp)
					uv0 = Vector2(wx1, y0); uv1 = Vector2(wx0, y0)
					uv2 = Vector2(wx0, y1); uv3 = Vector2(wx1, y1)
					shade = 0.8
			var wobble := 1.0 + (fmod(float(absi(hash(Vector2i(base_x + ui, base_z + vi)))), 100.0) / 100.0 - 0.5) * 0.07
			shade *= wobble
			var rough := _roughness(b_id)
			var target := solid
			var g := groups[b_id]
			if g == 2:
				target = transparent
			elif g == 3:
				target = liquid
			target.add_quad(p0, p1, p2, p3, n, uv0, uv1, uv2, uv3, tile, shade, emit, active_tint, rough)

## Per-material surface response. Wet/clear blocks stay glossy, raw stone and
## foliage stay matte, ore and crystal catch a highlight.
static func _roughness(id: int) -> float:
	if id == Content.WATER or id == Content.LAVA:
		return 0.10
	if id == Content.ICE or id == Content.GLASS:
		return 0.16
	if id == Content.CRYSTAL_BLOCK or id == Content.CRYSTAL_ORE:
		return 0.24
	if id == Content.COAL_ORE or id == Content.IRON_ORE or id == Content.GOLD_ORE:
		return 0.44
	if id == Content.LAMP or id == Content.RUNE:
		return 0.30
	if id == Content.LOG or id == Content.PLANKS or id == Content.CHEST or id == Content.TABLE or id == Content.DOOR:
		return 0.78
	if id == Content.LEAVES or id == Content.PINE_LEAVES:
		return 0.95
	if id == Content.SNOW or id == Content.SAND or id == Content.GRAVEL:
		return 0.88
	return 0.86
