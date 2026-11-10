class_name PixelArt
extends RefCounted

const T := 16

const TILE_NAMES := [
	"grass_top", "grass_side", "dirt", "stone", "sand", "sandstone_top", "sandstone_side",
	"snow", "log_side", "log_top", "leaves", "cactus_side", "cactus_top", "planks",
	"stone_brick", "glass", "lamp", "coal_ore", "iron_ore", "gold_ore", "crystal_ore",
	"bedrock", "ash", "basalt", "lava", "mycelium_top", "mycelium_side", "mushroom_stem",
	"mushroom_cap", "ice", "farmland", "wheat_0", "wheat_1", "wheat_2", "wheat_3", "torch",
	"chest_side", "chest_top", "crafting_top", "crafting_side", "door", "roof", "plaster",
	"gravel", "flower_red", "flower_yellow", "grass_tuft", "small_mushroom", "dungeon_brick",
	"rune", "crystal_block", "pine_leaves", "ranch_banner", "flower_blue", "water",
	"mushroom_cap_cream", "wheat_seed", "ember_ore"
]

static func hash01(x: int, y: int, seed: int = 0) -> float:
	return fmod(float(absi(hash(Vector3i(x, y, seed)))), 1000.0) / 1000.0

static func hash01_2(x: int, y: int, seed: int = 0) -> float:
	return fmod(float(absi(hash(Vector2i(x + seed * 13, y - seed * 7)))), 1000.0) / 1000.0

static func _new_img(w: int = T, h: int = T) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)

static func _noise_fill(img: Image, base: Color, amount: float, seed: int, alpha_variation: float = 0.0) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var n := hash01(x, y, seed)
			var c := base
			if n < 0.33:
				c = base.darkened(amount * (0.35 + n))
			elif n > 0.72:
				c = base.lightened(amount * (n - 0.5))
			if alpha_variation > 0.0:
				c.a = clampf(c.a - (n - 0.5) * alpha_variation, 0.0, 1.0)
			img.set_pixel(x, y, c)

static func _speckles(img: Image, count: int, seed: int, c: Color, size_max: int = 2) -> void:
	for i in count:
		var x := int(hash01(i, 3, seed) * T)
		var y := int(hash01(i, 7, seed + 4) * T)
		var s := 1 + int(hash01(i, 11, seed + 9) * size_max)
		_rect(img, x, y, s, 1, c)

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	while true:
		_px(img, x, y, c)
		if x == x1 and y == y1:
			break
		var e2 := err * 2
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

static func _band(img: Image, x0: float, y0: float, x1: float, y1: float,
		w0: float, w1: float, c: Color) -> void:
	var dx := x1 - x0
	var dy := y1 - y0
	var length := sqrt(dx * dx + dy * dy)
	if length < 0.001:
		return
	var nx := -dy / length
	var ny := dx / length
	var steps := maxi(2, int(length * 2.0))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var cx := x0 + dx * t
		var cy := y0 + dy * t
		var hw := lerpf(w0, w1, t)
		var span := int(ceil(hw))
		for o in range(-span, span + 1):
			if absf(float(o)) <= hw:
				_px(img, int(round(cx + nx * o)), int(round(cy + ny * o)), c)

static func _circle(img: Image, cx: int, cy: int, r: float, c: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x - cx, y - cy).length() <= r:
				_px(img, x, y, c)

static func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				_px(img, x, y, c)

static func _diamond(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if absf(x + 0.5 - cx) + absf(y + 0.5 - cy) <= r:
				_px(img, x, y, c)

static func _poly(img: Image, pts: PackedVector2Array, c: Color) -> void:
	var n := pts.size()
	if n < 3:
		return
	var ymin := 999.0
	var ymax := -999.0
	for p in pts:
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	for y in range(int(floor(ymin)), int(ceil(ymax)) + 1):
		var yc := float(y) + 0.5
		var xs: Array[float] = []
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				xs.append(a.x + (yc - a.y) * (b.x - a.x) / (b.y - a.y))
		xs.sort()
		for j in range(0, xs.size() - 1, 2):
			var x0 := int(ceil(xs[j] - 0.5))
			var x1 := int(floor(xs[j + 1] - 0.5))
			if x1 >= x0:
				_rect(img, x0, y, x1 - x0 + 1, 1, c)

static func _avg_color(img: Image, fallback: Color = Color("#6f7a74")) -> Color:
	var sum := Vector3.ZERO
	var count := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.25:
				sum += Vector3(c.r, c.g, c.b)
				count += 1
	if count == 0:
		return fallback
	sum /= float(count)
	return Color(sum.x, sum.y, sum.z)

static func _outline(img: Image, c: Color, alpha_threshold: float = 0.05) -> void:
	var copy := img.duplicate() as Image
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if copy.get_pixel(x, y).a > alpha_threshold:
				continue
			var neighbour := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and copy.get_pixel(nx, ny).a > alpha_threshold:
					neighbour = true
					break
			if neighbour:
				img.set_pixel(x, y, c)

static func tile_image(tile_name: String) -> Image:
	var img := _new_img()
	match tile_name:
		"grass_top":
			_noise_fill(img, Color("#65b45a"), 0.16, 11)
			_speckles(img, 22, 12, Color("#7ec96c"), 1)
			_speckles(img, 14, 13, Color("#4d9446"), 2)
		"grass_side":
			_noise_fill(img, Color("#7b5839"), 0.18, 21)
			for x in T:
				var edge := 3 + int(hash01(x, 0, 22) * 3)
				for y in edge:
					var c := Color("#65b45a").darkened(hash01(x, y, 23) * 0.18)
					img.set_pixel(x, y, c)
			_speckles(img, 8, 24, Color("#5a4028"), 2)
		"dirt":
			_noise_fill(img, Color("#7b5839"), 0.2, 31)
			_speckles(img, 18, 32, Color("#936b44"), 2)
			_speckles(img, 12, 33, Color("#604529"), 1)
		"stone":
			_noise_fill(img, Color("#7d858b"), 0.12, 41)
			_speckles(img, 16, 42, Color("#929aa0"), 2)
			_speckles(img, 10, 43, Color("#666e74"), 2)
			_line(img, 3, 11, 7, 8, Color("#616970"))
			_line(img, 11, 4, 13, 9, Color("#616970"))
		"sand":
			_noise_fill(img, Color("#ddc38a"), 0.1, 51)
			_speckles(img, 24, 52, Color("#f0d8a1"), 1)
			_speckles(img, 12, 53, Color("#c4a76d"), 1)
		"sandstone_top":
			_noise_fill(img, Color("#e3c98e"), 0.08, 61)
			_speckles(img, 20, 62, Color("#f2dca6"), 1)
		"sandstone_side":
			_noise_fill(img, Color("#d6bb80"), 0.08, 63)
			for y in [3, 8, 13]:
				_line(img, 0, y, 15, y, Color("#b5a06a"))
			_speckles(img, 10, 64, Color("#c6ab74"), 2)
		"snow":
			_noise_fill(img, Color("#e7f0f3"), 0.06, 71)
			_speckles(img, 16, 72, Color("#ffffff"), 1)
			_speckles(img, 8, 73, Color("#c9dce5"), 2)
		"log_side":
			_noise_fill(img, Color("#6c4a2b"), 0.13, 81)
			for x in [2, 5, 8, 11, 14]:
				_line(img, x, 0, x + (1 if x % 3 == 0 else 0), 15, Color("#52371f"))
			_speckles(img, 8, 82, Color("#89613a"), 2)
		"log_top":
			_noise_fill(img, Color("#b18957"), 0.1, 83)
			for r in [6.5, 4.5, 2.5]:
				var c := Color("#7f5b35")
				for y in T:
					for x in T:
						var d := absf(x + 0.5 - 8.0) + absf(y + 0.5 - 8.0)
						if absf(d - r) < 0.55:
							img.set_pixel(x, y, c)
			_rect(img, 7, 7, 2, 2, Color("#6a4829"))
		"leaves":
			_noise_fill(img, Color("#3e8748"), 0.22, 91, 0.0)
			_speckles(img, 26, 92, Color("#2f6f3b"), 2)
			_speckles(img, 18, 93, Color("#57a65e"), 1)
			for i in 10:
				var x := int(hash01(i, 4, 94) * T)
				var y := int(hash01(i, 9, 95) * T)
				img.set_pixel(x, y, Color(0, 0, 0, 0))
		"pine_leaves":
			_noise_fill(img, Color("#2f6b59"), 0.2, 96)
			_speckles(img, 22, 97, Color("#204f43"), 2)
			_speckles(img, 14, 98, Color("#3f846c"), 1)
			for i in 8:
				img.set_pixel(int(hash01(i, 1, 99) * T), int(hash01(i, 6, 100) * T), Color(0, 0, 0, 0))
		"cactus_side":
			_noise_fill(img, Color("#4b9250"), 0.12, 101)
			for x in [3, 8, 13]:
				_line(img, x, 0, x, 15, Color("#357039"))
			for i in 6:
				var x := int(hash01(i, 2, 102) * T)
				var y := int(hash01(i, 8, 103) * T)
				_rect(img, x, y, 1, 2, Color("#d8e7c0"))
		"cactus_top":
			_noise_fill(img, Color("#5aa55d"), 0.1, 104)
			for y in T:
				for x in T:
					if Vector2(x - 8, y - 8).length() < 5.0:
						img.set_pixel(x, y, Color("#4b9250"))
			_circle(img, 8, 8, 2.0, Color("#a9d18a"))
		"planks":
			_noise_fill(img, Color("#b8894f"), 0.12, 111)
			for y in [3, 8, 13]:
				_line(img, 0, y, 15, y, Color("#8f6838"))
			_line(img, 4, 0, 4, 3, Color("#8f6838"))
			_line(img, 11, 8, 11, 13, Color("#8f6838"))
			_speckles(img, 12, 112, Color("#caa066"), 2)
		"stone_brick":
			_noise_fill(img, Color("#727c7d"), 0.1, 121)
			for y in [0, 5, 10, 15]:
				_line(img, 0, y, 15, y, Color("#596365"))
			for y in [0, 5, 10]:
				var offset := 0 if y % 10 == 0 else 8
				_line(img, offset, y, offset, y + 4, Color("#596365"))
				_line(img, (offset + 8) % 16, y, (offset + 8) % 16, y + 4, Color("#596365"))
			_speckles(img, 10, 122, Color("#87918f"), 2)
		"dungeon_brick":
			_noise_fill(img, Color("#4e5854"), 0.12, 123)
			for y in [0, 5, 10, 15]:
				_line(img, 0, y, 15, y, Color("#38413e"))
			for y in [0, 5, 10]:
				var offset := 4 if y % 10 == 0 else 12
				_line(img, offset, y, offset, y + 4, Color("#38413e"))
			_speckles(img, 8, 124, Color("#516b52"), 2)
		"glass":
			img.fill(Color(0.75, 0.9, 0.94, 0.22))
			for i in T:
				_px(img, 0, i, Color("#d3edf1"))
				_px(img, 15, i, Color("#a9ced6"))
				_px(img, i, 0, Color("#d3edf1"))
				_px(img, i, 15, Color("#a9ced6"))
			_line(img, 3, 12, 11, 4, Color(1, 1, 1, 0.5))
			_line(img, 4, 13, 12, 5, Color(1, 1, 1, 0.22))
		"lamp":
			_noise_fill(img, Color("#f3bd5c"), 0.14, 131)
			for y in T:
				for x in T:
					var d := maxf(absf(x - 7.5), absf(y - 7.5))
					if d > 5.0 and d < 6.5:
						img.set_pixel(x, y, Color("#8a5b2c"))
			for p in [Vector2i(4, 4), Vector2i(11, 4), Vector2i(4, 11), Vector2i(11, 11), Vector2i(7, 7)]:
				_circle(img, p.x, p.y, 1.3, Color("#fff0b0"))
		"coal_ore", "iron_ore", "gold_ore", "crystal_ore":
			_noise_fill(img, Color("#7d858b"), 0.12, 141)
			var ore := Color("#2d2f34")
			if tile_name == "iron_ore": ore = Color("#dca983")
			elif tile_name == "gold_ore": ore = Color("#ffd257")
			elif tile_name == "crystal_ore": ore = Color("#68e6d4")
			for p in [Vector2i(3, 4), Vector2i(9, 3), Vector2i(5, 10), Vector2i(11, 11), Vector2i(8, 7)]:
				_disc(img, p.x, p.y, 1.8, ore.darkened(0.2))
				_rect(img, p.x, p.y - 1, 2, 2, ore)
				_px(img, p.x, p.y - 1, ore.lightened(0.25))
		"bedrock":
			_noise_fill(img, Color("#3b3d40"), 0.3, 151)
			_speckles(img, 25, 152, Color("#232527"), 3)
			_speckles(img, 12, 153, Color("#55595c"), 2)
		"ash":
			_noise_fill(img, Color("#59504c"), 0.18, 161)
			_speckles(img, 10, 162, Color("#6c625c"), 2)
			_speckles(img, 5, 163, Color("#d9763f"), 1)
		"basalt":
			_noise_fill(img, Color("#38343d"), 0.12, 171)
			for x in [2, 6, 10, 14]:
				_line(img, x, 0, x, 15, Color("#27242c"))
			_speckles(img, 8, 172, Color("#4b4752"), 2)
		"lava":
			_noise_fill(img, Color("#f0782f"), 0.2, 181)
			_speckles(img, 18, 182, Color("#ffd166"), 2)
			_speckles(img, 12, 183, Color("#b93c1f"), 2)
			for i in 5:
				_line(img, int(hash01(i, 2, 184) * 16), 0, int(hash01(i, 8, 185) * 16), 15, Color("#ffae45"))
		"mycelium_top":
			_noise_fill(img, Color("#9a7ba6"), 0.15, 191)
			_speckles(img, 20, 192, Color("#b698c2"), 2)
			_speckles(img, 14, 193, Color("#7a5d86"), 1)
		"mycelium_side":
			_noise_fill(img, Color("#7b5839"), 0.16, 194)
			for x in T:
				var edge := 3 + int(hash01(x, 0, 195) * 3)
				for y in edge:
					img.set_pixel(x, y, Color("#9a7ba6").darkened(hash01(x, y, 196) * 0.15))
			_speckles(img, 6, 197, Color("#b698c2"), 1)
		"mushroom_stem":
			_noise_fill(img, Color("#e3d3b2"), 0.08, 201)
			for x in [3, 8, 12]:
				_line(img, x, 0, x + 1, 15, Color("#c9b58f"))
		"mushroom_cap":
			_noise_fill(img, Color("#bd4a4a"), 0.12, 211)
			for p in [Vector2i(3, 4), Vector2i(9, 3), Vector2i(6, 9), Vector2i(12, 10), Vector2i(2, 12)]:
				_disc(img, p.x, p.y, 1.6, Color("#f2e6d2"))
		"mushroom_cap_cream":
			_noise_fill(img, Color("#e4c98f"), 0.1, 212)
			for p in [Vector2i(4, 5), Vector2i(10, 4), Vector2i(7, 10), Vector2i(12, 12)]:
				_disc(img, p.x, p.y, 1.6, Color("#b7864d"))
		"ice":
			_noise_fill(img, Color("#b9dfe7"), 0.08, 221)
			_line(img, 2, 12, 9, 3, Color("#e2f5f8"))
			_line(img, 8, 14, 13, 7, Color("#8fc3d1"))
			_speckles(img, 8, 222, Color("#ffffff"), 1)
		"water":
			img.fill(Color(0.22, 0.54, 0.74, 0.68))
			for i in T:
				_px(img, i, 4, Color(0.55, 0.8, 0.9, 0.5))
				_px(img, i, 11, Color(0.55, 0.8, 0.9, 0.35))
			_speckles(img, 14, 231, Color(0.7, 0.9, 1.0, 0.5), 2)
		"farmland":
			_noise_fill(img, Color("#6a4a2d"), 0.12, 241)
			for y in [2, 6, 10, 14]:
				_line(img, 0, y, 15, y, Color("#543a22"))
			_speckles(img, 12, 242, Color("#805a36"), 2)
		"wheat_0", "wheat_1", "wheat_2", "wheat_3":
			var stage := int(tile_name.substr(6, 1))
			var stalk := Color("#8ea84e")
			var grain := Color("#d8bf68")
			var count := 4 + stage * 2
			for i in count:
				var x := 2 + (i * 12) / maxi(count - 1, 1)
				var top := 15 - (4 + stage * 3)
				_line(img, x, 15, x + (1 if i % 2 == 0 else -1), top, stalk)
				if stage >= 1 and i % 2 == 0:
					_rect(img, x + 1, top + 1, 2, 2, grain)
				if stage >= 2:
					_rect(img, x - 1, top + 4, 2, 2, grain)
				if stage >= 3:
					_rect(img, x + 1, top - 2, 2, 3, grain)
		"wheat_seed":
			_speckles(img, 8, 243, Color("#c9b26b"), 2)
		"torch":
			_rect(img, 7, 6, 2, 9, Color("#7a512b"))
			_rect(img, 6, 5, 4, 3, Color("#ffb44a"))
			_rect(img, 7, 3, 2, 3, Color("#ffe08a"))
			_px(img, 7, 2, Color("#fff4cc"))
		"chest_side":
			_noise_fill(img, Color("#9a6a3a"), 0.1, 251)
			_rect(img, 0, 0, 16, 2, Color("#6b4524"))
			_rect(img, 0, 6, 16, 2, Color("#6b4524"))
			_rect(img, 6, 5, 4, 5, Color("#e0c26a"))
			_rect(img, 7, 6, 2, 2, Color("#5b3c20"))
		"chest_top":
			_noise_fill(img, Color("#a87543"), 0.1, 252)
			for i in T:
				_px(img, 0, i, Color("#6b4524"))
				_px(img, 15, i, Color("#6b4524"))
				_px(img, i, 0, Color("#6b4524"))
				_px(img, i, 15, Color("#6b4524"))
			_rect(img, 6, 0, 4, 3, Color("#e0c26a"))
		"crafting_top":
			_noise_fill(img, Color("#b8894f"), 0.08, 261)
			for i in [0, 5, 10, 15]:
				_line(img, 0, i, 15, i, Color("#71502c"))
				_line(img, i, 0, i, 15, Color("#71502c"))
			_rect(img, 2, 2, 2, 2, Color("#5e4226"))
			_rect(img, 12, 12, 2, 2, Color("#5e4226"))
		"crafting_side":
			_noise_fill(img, Color("#a97c46"), 0.1, 262)
			for y in [3, 10]:
				_line(img, 0, y, 15, y, Color("#7d5a32"))
			_line(img, 3, 5, 7, 9, Color("#6d4c2b"))
			_rect(img, 10, 5, 3, 2, Color("#8c8f91"))
		"door":
			_noise_fill(img, Color("#9b7345"), 0.1, 271)
			_line(img, 0, 0, 0, 15, Color("#5c4025"))
			_line(img, 15, 0, 15, 15, Color("#5c4025"))
			_line(img, 0, 7, 15, 7, Color("#71502c"))
			_rect(img, 12, 8, 2, 2, Color("#e0c26a"))
		"roof":
			_noise_fill(img, Color("#9d4b43"), 0.13, 281)
			for y in [0, 5, 10, 15]:
				_line(img, 0, y, 15, y, Color("#74312c"))
			for x in [4, 12]:
				_line(img, x, 1, x, 4, Color("#b25d52"))
		"plaster":
			_noise_fill(img, Color("#e4d9c0"), 0.06, 291)
			_line(img, 2, 3, 6, 7, Color("#c4b69b"))
			_line(img, 9, 10, 13, 14, Color("#cfc1a5"))
			_speckles(img, 8, 292, Color("#f0e7d1"), 2)
		"gravel":
			_noise_fill(img, Color("#807b74"), 0.25, 301)
			_speckles(img, 18, 302, Color("#9c9790"), 2)
			_speckles(img, 14, 303, Color("#5f5b55"), 2)
		"flower_red", "flower_yellow", "flower_blue":
			var petal := Color("#d85858")
			if tile_name == "flower_yellow": petal = Color("#f0c64f")
			elif tile_name == "flower_blue": petal = Color("#6f9fe0")
			_line(img, 7, 15, 7, 7, Color("#4f8a4a"))
			_line(img, 7, 11, 4, 9, Color("#5b9a52"))
			_line(img, 7, 10, 10, 8, Color("#5b9a52"))
			for p in [Vector2i(5, 5), Vector2i(9, 5), Vector2i(7, 3), Vector2i(6, 7), Vector2i(9, 7)]:
				_circle(img, p.x, p.y, 1.4, petal)
			_px(img, 7, 5, Color("#ffe9a8"))
		"grass_tuft":
			for i in 6:
				var x := 2 + i * 2
				var top := 6 + int(hash01(i, 3, 311) * 6)
				_line(img, x, 15, x + (i - 3) / 2, top, Color("#5ba652").darkened(hash01(i, 4, 312) * 0.2))
		"small_mushroom":
			_rect(img, 7, 9, 2, 7, Color("#d8c7a4"))
			_disc(img, 8, 7, 4.2, Color("#bc5555"))
			_rect(img, 5, 4, 2, 2, Color("#efe4cd"))
			_rect(img, 10, 6, 2, 2, Color("#efe4cd"))
		"rune":
			_noise_fill(img, Color("#3b3747"), 0.14, 321)
			for d in [Vector2i(3, 3), Vector2i(-3, 3), Vector2i(3, -3), Vector2i(-3, -3)]:
				_line(img, 8, 8, 8 + d.x, 8 + d.y, Color("#b17de0"))
			_circle(img, 8, 8, 2.2, Color("#c99af0"))
			_circle(img, 8, 8, 1.0, Color("#f2ddff"))
		"crystal_block":
			_noise_fill(img, Color("#2f5d63"), 0.12, 331)
			for i in 5:
				var x := 3 + int(hash01(i, 4, 332) * 10)
				var y := 2 + int(hash01(i, 7, 333) * 8)
				_diamond(img, x, y, 1.8 + hash01(i, 8, 334) * 2.0, Color("#72e5d6"))
				_diamond(img, x - 1, y - 1, 0.8, Color("#d5fff8"))
		"ranch_banner":
			_noise_fill(img, Color("#b8894f"), 0.1, 341)
			_line(img, 3, 0, 3, 15, Color("#6f4e2c"))
			_rect(img, 4, 1, 10, 7, Color("#2f7d6e"))
			_rect(img, 4, 8, 10, 2, Color("#256458"))
			_rect(img, 6, 3, 3, 2, Color("#e8dcc0"))
			_rect(img, 9, 4, 2, 3, Color("#e8dcc0"))
		"ember_ore":
			_noise_fill(img, Color("#5b5154"), 0.14, 351)
			for p in [Vector2i(4, 4), Vector2i(10, 6), Vector2i(7, 11)]:
				_disc(img, p.x, p.y, 1.8, Color("#ff8a3c"))
				_px(img, p.x, p.y, Color("#ffe0a0"))
		_:
			_noise_fill(img, Color("#b04ac0"), 0.1, 999)
	return img

static func make_atlas(columns: int = 16) -> Image:
	var rows := int(ceil(float(TILE_NAMES.size()) / float(columns)))
	var atlas := Image.create(columns * T, rows * T, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for i in TILE_NAMES.size():
		var img := tile_image(TILE_NAMES[i])
		var x := (i % columns) * T
		var y := (i / columns) * T
		atlas.blit_rect(img, Rect2i(0, 0, T, T), Vector2i(x, y))
	return atlas

# ---------------------------------------------------------------------------
# Item icons
# ---------------------------------------------------------------------------

static func icon(kind: String, primary: Color, secondary: Color = Color.WHITE, tertiary: Color = Color("#ffe2a8")) -> Image:
	var img := _new_img(32, 32)
	var dark := Color("#1a2723")
	var wood_d := Color("#3a2514")
	var wood := Color("#7c502c")
	var wood_l := Color("#b5814a")
	var md := primary.darkened(0.35)
	var ml := primary.lightened(0.4)
	match kind:
		"stick":
			_line(img, 7, 27, 23, 7, dark)
			_line(img, 8, 27, 24, 7, wood)
			_line(img, 9, 27, 25, 7, wood_l)
			_line(img, 10, 25, 26, 5, wood_d)
			_line(img, 11, 24, 16, 18, Color("#5d3b1f"))
			_line(img, 18, 12, 22, 8, Color("#5d3b1f"))
			_disc(img, 25, 6, 2, Color("#6fae5c"))
			_px(img, 24, 5, Color("#a9d68a"))
			_outline(img, dark)
		"ore":
			var rock := Color("#737d77") if primary.v < 0.35 else Color("#5e6a64")
			_poly(img, PackedVector2Array([Vector2(4,21), Vector2(7,10), Vector2(14,4), Vector2(24,6),
				Vector2(29,14), Vector2(27,24), Vector2(17,29), Vector2(8,27)]), rock.darkened(0.3))
			_poly(img, PackedVector2Array([Vector2(5,20), Vector2(8,10), Vector2(14,5), Vector2(23,7),
				Vector2(28,14), Vector2(26,23), Vector2(17,28), Vector2(8,26)]), rock)
			_poly(img, PackedVector2Array([Vector2(8,10), Vector2(14,5), Vector2(23,7), Vector2(18,12), Vector2(11,14)]), rock.lightened(0.18))
			for p in [Vector2(11, 16), Vector2(20, 13), Vector2(17, 23)]:
				_disc(img, p.x, p.y, 4.4, primary.darkened(0.4))
				_disc(img, p.x - 0.3, p.y - 0.8, 3.2, primary)
				_disc(img, p.x - 1.4, p.y - 2.0, 1.2, ml)
			_px(img, 26, 8, ml)
			_px(img, 6, 15, ml)
			_outline(img, dark)
		"ingot":
			_poly(img, PackedVector2Array([Vector2(6,13), Vector2(16,8), Vector2(26,13), Vector2(16,19)]), ml)
			_poly(img, PackedVector2Array([Vector2(6,13), Vector2(16,19), Vector2(16,25), Vector2(6,19)]), primary)
			_poly(img, PackedVector2Array([Vector2(26,13), Vector2(16,19), Vector2(16,25), Vector2(26,19)]), md)
			_line(img, 9, 13, 16, 10, primary.lightened(0.65))
			_line(img, 18, 11, 23, 14, primary.lightened(0.25))
			_rect(img, 14, 15, 4, 2, primary.darkened(0.45))
			_outline(img, dark)
		"gem":
			_poly(img, PackedVector2Array([Vector2(16,2), Vector2(24,11), Vector2(20,27), Vector2(12,27), Vector2(8,11)]), md)
			_poly(img, PackedVector2Array([Vector2(16,3), Vector2(22,11), Vector2(19,25), Vector2(13,25), Vector2(10,11)]), primary)
			_poly(img, PackedVector2Array([Vector2(16,3), Vector2(22,11), Vector2(16,16), Vector2(10,11)]), ml)
			_line(img, 10, 12, 16, 16, primary.lightened(0.2))
			_line(img, 22, 12, 16, 16, md)
			_poly(img, PackedVector2Array([Vector2(7,13), Vector2(11,18), Vector2(9,26), Vector2(5,21)]), secondary.darkened(0.2))
			_poly(img, PackedVector2Array([Vector2(25,14), Vector2(29,19), Vector2(27,26), Vector2(23,21)]), secondary)
			_px(img, 6, 8, Color.WHITE)
			_px(img, 27, 8, Color.WHITE)
			_px(img, 24, 4, ml)
			_outline(img, dark)
		"amber":
			_poly(img, PackedVector2Array([Vector2(16,3), Vector2(22,12), Vector2(25,19), Vector2(22,26),
				Vector2(16,29), Vector2(10,26), Vector2(7,19), Vector2(10,12)]), primary.darkened(0.3))
			_poly(img, PackedVector2Array([Vector2(16,4), Vector2(21,12), Vector2(24,19), Vector2(21,25),
				Vector2(16,27), Vector2(11,25), Vector2(8,19), Vector2(11,12)]), primary)
			_disc(img, 13, 13, 3.4, Color(1, 1, 1, 0.45))
			_px(img, 11, 11, Color.WHITE)
			_disc(img, 17, 20, 1.6, primary.darkened(0.55))
			_line(img, 16, 19, 14, 22, primary.darkened(0.55))
			_line(img, 16, 19, 19, 22, primary.darkened(0.55))
			_outline(img, dark)
		"fiber":
			for i in 4:
				var x := 8 + i * 4
				_line(img, x, 27, x + 2, 16, primary.darkened(0.1 * i))
				_line(img, x + 2, 16, x + 1, 4, secondary.darkened(0.15 * i))
			_line(img, 6, 19, 25, 19, tertiary)
			_line(img, 6, 21, 25, 21, tertiary.darkened(0.3))
			_line(img, 22, 16, 25, 22, tertiary)
			_px(img, 11, 3, secondary.lightened(0.2))
			_px(img, 19, 3, secondary.lightened(0.2))
			_outline(img, dark)
		"leather":
			_poly(img, PackedVector2Array([Vector2(7,9), Vector2(13,5), Vector2(22,6), Vector2(27,12),
				Vector2(24,20), Vector2(27,25), Vector2(17,29), Vector2(9,25), Vector2(5,16)]), primary.darkened(0.3))
			_poly(img, PackedVector2Array([Vector2(8,10), Vector2(13,6), Vector2(21,7), Vector2(26,12),
				Vector2(23,20), Vector2(26,24), Vector2(17,28), Vector2(10,24), Vector2(6,16)]), primary)
			for p in [Vector2(12, 8), Vector2(18, 8), Vector2(23, 12), Vector2(24, 18),
					Vector2(22, 23), Vector2(16, 26), Vector2(11, 23), Vector2(8, 18), Vector2(9, 12)]:
				_px(img, int(p.x), int(p.y), secondary)
				_px(img, int(p.x) + 1, int(p.y) + 1, primary.darkened(0.2))
			_line(img, 13, 16, 19, 16, primary.darkened(0.5))
			_line(img, 16, 13, 16, 19, primary.darkened(0.5))
			_line(img, 14, 17, 18, 17, primary.darkened(0.35))
			_poly(img, PackedVector2Array([Vector2(21,19), Vector2(24,20), Vector2(23,24), Vector2(20,23)]), primary.darkened(0.18))
			_outline(img, dark)
		"core":
			_disc(img, 16, 16, 12, dark)
			_disc(img, 16, 16, 11, primary.darkened(0.65))
			_disc(img, 16, 16, 9, primary.darkened(0.3))
			_disc(img, 16, 16, 6, primary)
			_disc(img, 15, 14, 3, secondary)
			_disc(img, 14, 13, 1.4, Color.WHITE)
			for a in 8:
				var ang := TAU * a / 8.0
				_line(img, int(16 + cos(ang) * 7), int(16 + sin(ang) * 7),
					int(16 + cos(ang) * 11), int(16 + sin(ang) * 11), primary.darkened(0.2))
			_px(img, 27, 6, secondary)
			_px(img, 5, 24, secondary)
			_outline(img, dark)
		"orb", "orb_great":
			var gold := tertiary if kind == "orb_great" else Color("#d8fff8")
			_disc(img, 16, 16, 13, dark)
			_disc(img, 16, 16, 12, primary.darkened(0.55))
			_disc(img, 16, 16, 10.5, primary.darkened(0.2))
			_disc(img, 15, 14, 7.5, primary)
			_poly(img, PackedVector2Array([Vector2(4,16), Vector2(28,16), Vector2(27,20), Vector2(5,20)]), primary.darkened(0.6))
			_poly(img, PackedVector2Array([Vector2(5,17), Vector2(27,17), Vector2(26,19), Vector2(6,19)]), gold.darkened(0.15))
			_disc(img, 16, 18, 3.4, dark)
			_disc(img, 16, 18, 2.3, gold)
			_disc(img, 15.5, 17.5, 1.0, Color.WHITE)
			_disc(img, 11, 10, 3, Color(1, 1, 1, 0.7))
			_disc(img, 9, 12, 1.5, Color(1, 1, 1, 0.45))
			_px(img, 24, 25, primary.lightened(0.4))
			_px(img, 26, 23, primary.lightened(0.3))
			for p in [Vector2(27, 5), Vector2(5, 27)]:
				_px(img, int(p.x), int(p.y), gold)
				_px(img, int(p.x) - 1, int(p.y), gold)
				_px(img, int(p.x) + 1, int(p.y), gold)
				_px(img, int(p.x), int(p.y) - 1, gold)
				_px(img, int(p.x), int(p.y) + 1, gold)
			_outline(img, dark)
		"feed":
			_poly(img, PackedVector2Array([Vector2(8,12), Vector2(23,12), Vector2(26,28), Vector2(6,28)]), primary.darkened(0.35))
			_poly(img, PackedVector2Array([Vector2(9,13), Vector2(22,13), Vector2(24,27), Vector2(7,27)]), primary)
			_poly(img, PackedVector2Array([Vector2(11,7), Vector2(21,7), Vector2(22,14), Vector2(10,14)]), primary.darkened(0.2))
			_line(img, 9, 12, 23, 12, secondary.darkened(0.35))
			_line(img, 10, 14, 22, 14, secondary)
			_line(img, 10, 16, 22, 16, secondary.darkened(0.25))
			_line(img, 13, 20, 19, 24, tertiary)
			_disc(img, 12, 19, 2, tertiary)
			_disc(img, 20, 25, 2, tertiary)
			_px(img, 19, 15, secondary)
			_px(img, 21, 18, secondary)
			_outline(img, dark)
		"berry":
			_line(img, 16, 14, 20, 5, secondary.darkened(0.35))
			_line(img, 17, 12, 23, 7, secondary.darkened(0.25))
			_poly(img, PackedVector2Array([Vector2(19,7), Vector2(25,4), Vector2(27,9), Vector2(22,11)]), secondary)
			_poly(img, PackedVector2Array([Vector2(13,9), Vector2(19,6), Vector2(20,11), Vector2(15,12)]), secondary.darkened(0.15))
			for p in [Vector2(11, 18), Vector2(20, 16), Vector2(16, 24)]:
				_disc(img, p.x, p.y, 6, dark)
				_disc(img, p.x, p.y, 5, primary)
				_disc(img, p.x - 1.4, p.y - 1.6, 1.8, primary.lightened(0.4))
				_px(img, int(p.x - 2), int(p.y - 2), Color.WHITE)
			_outline(img, dark)
		"roast":
			for p in [Vector2(11, 17), Vector2(20, 18), Vector2(15, 24)]:
				_disc(img, p.x, p.y, 5.2, dark)
				_disc(img, p.x, p.y, 4.2, primary)
				_disc(img, p.x - 1, p.y - 1, 1.6, primary.lightened(0.3))
			_line(img, 8, 12, 12, 15, secondary)
			_line(img, 24, 10, 20, 14, secondary)
			_px(img, 24, 6, Color("#ffd9a0"))
			_px(img, 25, 5, Color("#fff2cf"))
			_outline(img, dark)
		"potion":
			_rect(img, 12, 2, 8, 2, dark)
			_rect(img, 13, 4, 6, 4, Color("#c9b28c"))
			_circle(img, 16, 20, 10, dark)
			_circle(img, 16, 20, 9, secondary)
			_disc(img, 16, 23, 6, primary)
			_disc(img, 13, 16, 2.6, Color(1, 1, 1, 0.55))
			_rect(img, 9, 21, 14, 2, tertiary.darkened(0.2))
			_rect(img, 15, 23, 2, 2, tertiary)
			_outline(img, dark)
		"wheat":
			for i in 3:
				var sx := 10 + i * 6
				_line(img, sx, 28, sx + 3, 7, secondary.darkened(0.2))
				for j in 4:
					var gy := 9 + j * 4
					_disc(img, sx + 2 + (j % 2), gy, 2.2, primary.darkened(0.25))
					_disc(img, sx + 2 + (j % 2), gy - 0.5, 1.6, primary)
					_px(img, sx + 2 + (j % 2), gy - 2, ml)
				_line(img, sx + 3, 7, sx + 5, 3, secondary.darkened(0.35))
			_line(img, 8, 20, 24, 20, tertiary.darkened(0.25))
			_line(img, 8, 22, 24, 22, tertiary)
			_line(img, 22, 17, 25, 23, tertiary)
			_outline(img, dark)
		"seeds":
			_poly(img, PackedVector2Array([Vector2(9,12), Vector2(23,12), Vector2(25,28), Vector2(7,28)]), primary.darkened(0.3))
			_poly(img, PackedVector2Array([Vector2(10,14), Vector2(22,14), Vector2(23,27), Vector2(8,27)]), primary)
			_line(img, 9, 12, 23, 12, secondary.darkened(0.35))
			_line(img, 10, 14, 22, 14, secondary)
			_line(img, 11, 16, 21, 16, secondary.darkened(0.2))
			for p in [Vector2(13, 8), Vector2(19, 7), Vector2(23, 10)]:
				_poly(img, PackedVector2Array([Vector2(p.x, p.y - 2), Vector2(p.x + 2, p.y), Vector2(p.x, p.y + 2), Vector2(p.x - 2, p.y)]), tertiary.darkened(0.2))
				_px(img, int(p.x - 1), int(p.y - 1), tertiary.lightened(0.3))
			_line(img, 12, 19, 20, 24, secondary.darkened(0.4))
			_outline(img, dark)
		"pick", "axe", "shovel", "sword", "hoe":
			_line(img, 6, 28, 18, 10, dark)
			_line(img, 7, 28, 19, 10, wood)
			_line(img, 8, 28, 20, 10, wood_l)
			_line(img, 9, 27, 20, 11, wood_d)
			_line(img, 8, 25, 13, 20, Color("#d2a467"))
			_line(img, 10, 27, 15, 22, wood_d)
			if kind == "pick":
				_poly(img, PackedVector2Array([Vector2(1,16), Vector2(4,10), Vector2(10,6), Vector2(18,10),
					Vector2(13,13), Vector2(7,16)]), md)
				_poly(img, PackedVector2Array([Vector2(2,15), Vector2(5,10), Vector2(10,7), Vector2(17,10),
					Vector2(12,12), Vector2(7,15)]), primary)
				_line(img, 5, 10, 10, 7, ml)
				_line(img, 12, 9, 17, 8, ml)
				_poly(img, PackedVector2Array([Vector2(18,10), Vector2(25,2), Vector2(31,3), Vector2(30,9),
					Vector2(23,13), Vector2(18,13)]), md)
				_poly(img, PackedVector2Array([Vector2(19,10), Vector2(25,3), Vector2(30,4), Vector2(29,8),
					Vector2(22,12), Vector2(18,12)]), primary)
				_line(img, 25, 4, 30, 4, ml)
				_line(img, 26, 5, 29, 8, ml)
				_poly(img, PackedVector2Array([Vector2(16,8), Vector2(23,8), Vector2(24,14), Vector2(18,15),
					Vector2(15,12)]), primary.darkened(0.5))
				_line(img, 17, 10, 22, 10, tertiary)
				_line(img, 17, 12, 22, 11, tertiary.darkened(0.2))
				_px(img, 2, 16, dark)
				_px(img, 31, 3, dark)
			elif kind == "axe":
				_poly(img, PackedVector2Array([Vector2(21,3), Vector2(27,1), Vector2(33,4), Vector2(33,11),
					Vector2(28,18), Vector2(23,19), Vector2(20,15), Vector2(22,8)]), md)
				_poly(img, PackedVector2Array([Vector2(22,4), Vector2(27,2), Vector2(32,5), Vector2(32,10),
					Vector2(27,17), Vector2(23,17), Vector2(21,14), Vector2(23,8)]), primary)
				_line(img, 27, 3, 32, 5, ml)
				_line(img, 32, 7, 28, 16, ml)
				_line(img, 21, 12, 24, 6, primary.darkened(0.5))
				_line(img, 18, 13, 21, 10, tertiary.darkened(0.2))
				_line(img, 19, 14, 22, 11, tertiary)
				_px(img, 23, 18, primary.darkened(0.55))
				_px(img, 32, 4, dark)
			elif kind == "shovel":
				_poly(img, PackedVector2Array([Vector2(19,11), Vector2(20,4), Vector2(25,2), Vector2(30,5),
					Vector2(30,11), Vector2(26,17), Vector2(21,15)]), md)
				_poly(img, PackedVector2Array([Vector2(20,10), Vector2(21,5), Vector2(25,3), Vector2(29,6),
					Vector2(29,10), Vector2(25,16), Vector2(21,14)]), primary)
				_line(img, 22, 5, 28, 6, ml)
				_line(img, 24, 8, 24, 13, primary.darkened(0.25))
				_poly(img, PackedVector2Array([Vector2(18,10), Vector2(21,9), Vector2(22,14), Vector2(19,14)]), primary.darkened(0.45))
				_line(img, 19, 11, 22, 11, tertiary)
				_px(img, 25, 16, dark)
			elif kind == "sword":
				_poly(img, PackedVector2Array([Vector2(12,24), Vector2(23,4), Vector2(27,2), Vector2(29,6), Vector2(17,27)]), md)
				_poly(img, PackedVector2Array([Vector2(13,24), Vector2(24,5), Vector2(27,4), Vector2(28,6), Vector2(17,26)]), primary)
				_line(img, 15, 21, 25, 5, ml)
				_line(img, 17, 22, 27, 7, primary.darkened(0.2))
				_line(img, 6, 20, 16, 27, dark)
				_line(img, 6, 19, 16, 26, tertiary)
				_line(img, 7, 20, 17, 27, tertiary.darkened(0.25))
				_line(img, 8, 27, 12, 23, wood)
				_line(img, 9, 28, 13, 24, wood_l)
				_disc(img, 6, 28, 3, tertiary.darkened(0.2))
				_px(img, 6, 27, tertiary.lightened(0.4))
			elif kind == "hoe":
				_line(img, 19, 12, 24, 7, primary.darkened(0.4))
				_line(img, 20, 12, 25, 7, primary)
				_poly(img, PackedVector2Array([Vector2(22,5), Vector2(30,3), Vector2(32,6), Vector2(31,9),
					Vector2(23,9)]), md)
				_poly(img, PackedVector2Array([Vector2(23,6), Vector2(30,4), Vector2(31,6), Vector2(30,8),
					Vector2(23,8)]), primary)
				_line(img, 23, 5, 30, 4, ml)
				_line(img, 26, 8, 30, 7, primary.lightened(0.2))
				_line(img, 18, 12, 21, 10, tertiary.darkened(0.25))
			_outline(img, dark)
		"helmet":
			_poly(img, PackedVector2Array([Vector2(7,15), Vector2(9,7), Vector2(16,4), Vector2(23,7),
				Vector2(25,15), Vector2(22,18), Vector2(22,25), Vector2(10,25), Vector2(10,18)]), primary.darkened(0.35))
			_poly(img, PackedVector2Array([Vector2(8,15), Vector2(10,8), Vector2(16,5), Vector2(22,8),
				Vector2(24,15), Vector2(21,17), Vector2(21,24), Vector2(11,24), Vector2(11,17)]), primary)
			_rect(img, 11, 14, 10, 3, dark)
			_rect(img, 12, 14, 3, 2, secondary)
			_rect(img, 17, 14, 3, 2, secondary)
			_line(img, 16, 5, 16, 12, secondary)
			_px(img, 12, 20, secondary)
			_px(img, 20, 20, secondary)
			_rect(img, 14, 18, 4, 4, primary.darkened(0.2))
			_outline(img, dark)
		"chestplate":
			_poly(img, PackedVector2Array([Vector2(9,7), Vector2(23,7), Vector2(26,13), Vector2(23,17),
				Vector2(23,27), Vector2(9,27), Vector2(9,17), Vector2(6,13)]), primary.darkened(0.35))
			_poly(img, PackedVector2Array([Vector2(10,8), Vector2(22,8), Vector2(25,13), Vector2(22,16),
				Vector2(22,26), Vector2(10,26), Vector2(10,16), Vector2(7,13)]), primary)
			_poly(img, PackedVector2Array([Vector2(10,8), Vector2(5,10), Vector2(6,16), Vector2(10,15)]), primary.darkened(0.2))
			_poly(img, PackedVector2Array([Vector2(22,8), Vector2(27,10), Vector2(26,16), Vector2(22,15)]), primary.darkened(0.2))
			_line(img, 10, 21, 22, 21, secondary.darkened(0.3))
			_line(img, 10, 23, 22, 23, secondary)
			_disc(img, 16, 13, 2.6, tertiary)
			_px(img, 15, 12, Color.WHITE)
			_rect(img, 14, 17, 4, 3, primary.darkened(0.25))
			_outline(img, dark)
		"boots":
			for x in [7, 18]:
				_poly(img, PackedVector2Array([Vector2(x, 8), Vector2(x + 7, 8), Vector2(x + 7, 20),
					Vector2(x + 11, 24), Vector2(x + 10, 28), Vector2(x, 28)]), primary.darkened(0.35))
				_poly(img, PackedVector2Array([Vector2(x + 1, 9), Vector2(x + 6, 9), Vector2(x + 6, 20),
					Vector2(x + 10, 24), Vector2(x + 9, 27), Vector2(x + 1, 27)]), primary)
				_rect(img, x + 1, 12, 5, 2, secondary)
				_rect(img, x, 26, 11, 2, dark)
			_px(img, 5, 12, tertiary)
			_px(img, 27, 12, tertiary)
			_outline(img, dark)
		"saddle":
			_poly(img, PackedVector2Array([Vector2(5,14), Vector2(9,8), Vector2(16,7), Vector2(23,8),
				Vector2(27,14), Vector2(24,19), Vector2(16,21), Vector2(8,19)]), primary.darkened(0.35))
			_poly(img, PackedVector2Array([Vector2(6,14), Vector2(10,9), Vector2(16,8), Vector2(22,9),
				Vector2(26,14), Vector2(23,18), Vector2(16,20), Vector2(9,18)]), primary)
			_poly(img, PackedVector2Array([Vector2(11,8), Vector2(14,4), Vector2(17,8), Vector2(15,10), Vector2(12,10)]), primary.lightened(0.22))
			_poly(img, PackedVector2Array([Vector2(21,7), Vector2(26,9), Vector2(25,13), Vector2(21,11)]), primary.darkened(0.15))
			_line(img, 8, 20, 8, 26, secondary.darkened(0.25))
			_line(img, 24, 20, 24, 26, secondary.darkened(0.25))
			_circle(img, 8, 27, 3, tertiary.darkened(0.25))
			_circle(img, 8, 27, 1.6, dark)
			_circle(img, 24, 27, 3, tertiary.darkened(0.25))
			_circle(img, 24, 27, 1.6, dark)
			_line(img, 5, 16, 27, 16, tertiary.darkened(0.1))
			_line(img, 7, 21, 25, 21, primary.darkened(0.3))
			_px(img, 22, 17, tertiary)
			_outline(img, dark)
		"banner":
			_line(img, 8, 3, 8, 29, wood_d)
			_line(img, 9, 3, 9, 29, wood)
			_poly(img, PackedVector2Array([Vector2(10,4), Vector2(27,4), Vector2(27,20), Vector2(18,17), Vector2(10,21)]), primary.darkened(0.35))
			_poly(img, PackedVector2Array([Vector2(10,5), Vector2(26,5), Vector2(26,19), Vector2(18,16), Vector2(10,20)]), primary)
			_line(img, 13, 9, 23, 9, secondary)
			_poly(img, PackedVector2Array([Vector2(16,8), Vector2(20,12), Vector2(16,16), Vector2(12,12)]), secondary)
			_disc(img, 16, 12, 1.6, tertiary)
			_outline(img, dark)
		"key":
			_disc(img, 11, 11, 8, dark)
			_disc(img, 11, 11, 6.5, primary)
			_disc(img, 11, 11, 3, Color(0, 0, 0, 0))
			_disc(img, 11, 11, 2.5, tertiary.darkened(0.2))
			_line(img, 16, 16, 27, 27, dark)
			_line(img, 17, 16, 28, 27, primary)
			_line(img, 22, 23, 26, 19, primary)
			_line(img, 24, 25, 28, 21, primary)
			_line(img, 22, 22, 26, 18, dark)
			_line(img, 24, 24, 28, 20, dark)
			_px(img, 8, 8, Color.WHITE)
			_px(img, 27, 8, tertiary)
			_outline(img, dark)
		"book":
			_poly(img, PackedVector2Array([Vector2(6,7), Vector2(24,5), Vector2(27,9), Vector2(27,27), Vector2(8,28)]), primary.darkened(0.35))
			_poly(img, PackedVector2Array([Vector2(7,7), Vector2(23,6), Vector2(25,9), Vector2(25,26), Vector2(8,27)]), primary)
			_rect(img, 7, 6, 4, 22, primary.darkened(0.25))
			_rect(img, 12, 10, 10, 2, secondary)
			_rect(img, 12, 14, 8, 2, secondary)
			_rect(img, 12, 18, 9, 2, secondary)
			_rect(img, 23, 12, 3, 10, tertiary.darkened(0.2))
			_disc(img, 24, 17, 1.4, tertiary)
			_outline(img, dark)
		"egg":
			_poly(img, PackedVector2Array([Vector2(16,2), Vector2(23,10), Vector2(26,19), Vector2(23,27),
				Vector2(16,30), Vector2(9,27), Vector2(6,19), Vector2(9,10)]), primary.darkened(0.3))
			_poly(img, PackedVector2Array([Vector2(16,3), Vector2(22,10), Vector2(25,19), Vector2(22,26),
				Vector2(16,29), Vector2(10,26), Vector2(7,19), Vector2(10,10)]), primary)
			for p in [Vector2(11, 13), Vector2(18, 11), Vector2(21, 18), Vector2(13, 22), Vector2(19, 25)]:
				_disc(img, p.x, p.y, 1.8, secondary)
			_line(img, 12, 17, 16, 20, primary.darkened(0.45))
			_line(img, 16, 20, 14, 24, primary.darkened(0.45))
			_disc(img, 12, 11, 2, Color(1, 1, 1, 0.4))
			_outline(img, dark)
		_:
			_disc(img, 16, 16, 10, primary)
			_outline(img, dark)
	return img


static func hand_icon() -> Image:
	var img := _new_img(32, 32)
	var skin := Color("#d9a06b")
	var shade := Color("#b47c4e")
	var dark := Color("#1a2723")
	_poly(img, PackedVector2Array([Vector2(7, 11), Vector2(25, 11), Vector2(26, 27), Vector2(6, 27)]), dark)
	_poly(img, PackedVector2Array([Vector2(8, 12), Vector2(24, 12), Vector2(25, 26), Vector2(7, 26)]), skin)
	for i in 4:
		var fx := 9 + i * 4
		_disc(img, fx + 1, 11, 2.6, dark)
		_disc(img, fx + 1, 11, 1.8, skin)
	_line(img, 9, 18, 23, 18, shade)
	_line(img, 10, 22, 22, 22, shade)
	_disc(img, 6, 17, 3.2, dark)
	_disc(img, 6.5, 17, 2.2, skin)
	_rect(img, 5, 26, 22, 4, dark)
	_rect(img, 6, 26, 20, 3, Color("#2f5547"))
	_outline(img, dark)
	return img

static func held_sword(tier: int, primary: Color) -> Image:
	var img := _new_img(96, 96)
	var dark := Color("#101b17")
	var steel := primary
	var steel_l := primary.lightened(0.42)
	var steel_d := primary.darkened(0.32)
	var edge := primary.lightened(0.72)
	var guard := Color("#e0b25a")
	var guard_l := Color("#ffe7a8")
	var guard_d := Color("#8d6125")
	var grip := Color("#5f3c20")
	var grip_d := Color("#301d0e")
	var pommel := primary
	match clampi(tier, 1, 4):
		1:
			steel_l = primary.lightened(0.34)
			steel_d = primary.darkened(0.3)
			edge = primary.lightened(0.52)
			guard = Color("#5c3a1e")
			guard_l = Color("#a5713d")
			guard_d = Color("#301c0c")
			grip = Color("#5b3a20")
			grip_d = Color("#2d1b0c")
			pommel = primary.darkened(0.08)
		2:
			steel = primary
			steel_l = primary.lightened(0.38)
			steel_d = primary.darkened(0.4)
			edge = primary.lightened(0.62)
			guard = Color("#5b6861")
			guard_l = Color("#a6b3ac")
			guard_d = Color("#333d38")
			grip = Color("#5a3a22")
			grip_d = Color("#2b1a0e")
			pommel = Color("#7d8b83")
		3:
			steel = Color("#d3dee2")
			steel_l = Color.WHITE
			steel_d = Color("#76878e")
			edge = Color.WHITE
			guard = Color("#8b99a0")
			guard_l = Color("#e8f0f2")
			guard_d = Color("#46535a")
			grip = Color("#4a2f1c")
			grip_d = Color("#21130a")
			pommel = Color("#c6d2d6")
		4:
			steel = primary
			steel_l = Color("#d8fff9")
			steel_d = Color("#2c8b82")
			edge = Color.WHITE
			guard = Color("#e0b25a")
			guard_l = Color("#ffe7a8")
			guard_d = Color("#8d6125")
			grip = Color("#7a4a22")
			grip_d = Color("#42250f")
			pommel = primary
	# blade: dark silhouette, steel, lit edge and shaded ridge
	_band(img, 38, 60, 89, 6, 9.5, 2.4, dark)
	_band(img, 38, 60, 88, 8, 7.4, 1.6, steel)
	_band(img, 35.4, 56.8, 86.0, 5.2, 1.5, 0.8, steel_l)
	_band(img, 41.0, 63.2, 89.0, 9.6, 1.7, 0.7, steel_d)
	_band(img, 38.5, 60.0, 87.0, 7.0, 0.7, 0.4, steel_l if tier != 1 else steel_d)
	match clampi(tier, 1, 4):
		1:
			for i in 3:
				var t := 0.28 + 0.2 * i
				var cx := 38.0 + 50.0 * t
				var cy := 60.0 - 52.0 * t
				_band(img, cx - 2.6, cy - 2.4, cx + 2.6, cy + 2.4, 0.6, 0.6, steel_d)
			_px(img, 82, 12, edge)
		2:
			for p in [Vector2i(47, 47), Vector2i(55, 38), Vector2i(63, 30),
					Vector2i(72, 21), Vector2i(78, 14), Vector2i(51, 43)]:
				_px(img, p.x, p.y, steel_d)
				_px(img, p.x + 1, p.y - 1, steel_l)
		3:
			_px(img, 84, 10, Color.WHITE)
			_px(img, 85, 9, Color.WHITE)
			_px(img, 82, 13, steel_l)
			_disc(img, 25, 47, 1.6, guard)
			_disc(img, 51, 71, 1.6, guard)
		4:
			for i in 2:
				var t := 0.34 + 0.3 * i
				var cx := 38.0 + 50.0 * t
				var cy := 60.0 - 52.0 * t
				_band(img, cx - 3.2, cy - 2.9, cx + 3.2, cy + 2.9, 0.55, 0.55, steel_l)
			_px(img, 90, 3, Color.WHITE)
			_px(img, 91, 2, Color.WHITE)
			_px(img, 92, 3, steel_l)
			_px(img, 55, 21, Color.WHITE)
			_px(img, 32, 64, steel_l)
	# crossguard
	_band(img, 55, 75, 21, 43, 5.8, 5.8, dark)
	_band(img, 55, 75, 21, 43, 4.3, 4.3, guard)
	_band(img, 52.5, 72.5, 22.5, 44.5, 1.2, 1.2, guard_l)
	_band(img, 57.0, 77.0, 23.5, 45.5, 1.2, 1.2, guard_d)
	_disc(img, 55, 75, 6.0, dark)
	_disc(img, 55, 75, 4.5, guard)
	_disc(img, 21, 43, 6.0, dark)
	_disc(img, 21, 43, 4.5, guard)
	_disc(img, 54, 74, 2.0, guard_l)
	_disc(img, 22, 44, 2.0, guard_l)
	if tier == 4:
		_diamond(img, 55, 75, 7.5, dark)
		_diamond(img, 55, 75, 5.8, guard)
		_diamond(img, 55, 75, 3.2, guard_l)
		_diamond(img, 21, 43, 7.5, dark)
		_diamond(img, 21, 43, 5.8, guard)
		_diamond(img, 21, 43, 3.2, guard_l)
	# grip with wraps
	_band(img, 36, 63, 23, 79, 5.2, 4.4, dark)
	_band(img, 36, 63, 23, 79, 3.9, 3.2, grip)
	_band(img, 34.5, 64.2, 21.8, 80.0, 0.7, 0.7, grip.lightened(0.25))
	for i in 4:
		var t := 0.16 + 0.22 * i
		var cx := lerpf(36.0, 23.0, t)
		var cy := lerpf(63.0, 79.0, t)
		_band(img, cx - 2.7, cy - 2.2, cx + 2.7, cy + 2.2, 0.7, 0.7, guard if tier == 4 else grip_d)
	# pommel
	_disc(img, 20, 82, 7.0, dark)
	_disc(img, 20, 82, 5.6, pommel)
	_disc(img, 18.8, 80.8, 2.2, pommel.lightened(0.35))
	if tier >= 3:
		_px(img, 17, 79, Color.WHITE)
	else:
		_px(img, 18, 80, pommel.darkened(0.25))
	if tier == 4:
		_diamond(img, 20, 82, 8.5, dark)
		_diamond(img, 20, 82, 6.8, guard)
		_diamond(img, 20, 82, 4.8, steel)
		_diamond(img, 20, 82, 2.0, steel_l)
		_px(img, 18, 80, Color.WHITE)
	_outline(img, Color("#0b1410"))
	return img

static func ui_icon(kind: String, ink: Color) -> Image:
	var img := _new_img(32, 32)
	var soft := Color(ink.r, ink.g, ink.b, 0.55)
	var faint := Color(ink.r, ink.g, ink.b, 0.25)
	match kind:
		"mine":
			_line(img, 7, 27, 19, 10, soft)
			_line(img, 8, 27, 20, 10, ink)
			_line(img, 9, 27, 21, 10, ink)
			_poly(img, PackedVector2Array([Vector2(2, 14), Vector2(5, 9), Vector2(11, 6), Vector2(17, 7),
				Vector2(20, 5), Vector2(25, 3), Vector2(30, 5), Vector2(28, 10), Vector2(22, 13),
				Vector2(17, 13), Vector2(12, 16), Vector2(6, 16)]), ink)
			_poly(img, PackedVector2Array([Vector2(17, 8), Vector2(23, 8), Vector2(24, 13),
				Vector2(19, 15), Vector2(16, 12)]), soft)
			_line(img, 4, 11, 11, 8, soft)
		"jump":
			_poly(img, PackedVector2Array([Vector2(16, 3), Vector2(27, 15), Vector2(21, 15),
				Vector2(21, 25), Vector2(11, 25), Vector2(11, 15), Vector2(5, 15)]), ink)
			_line(img, 8, 29, 24, 29, soft)
			_px(img, 16, 20, soft)
		"place":
			_poly(img, PackedVector2Array([Vector2(16, 5), Vector2(26, 10), Vector2(16, 16), Vector2(6, 10)]), faint)
			_poly(img, PackedVector2Array([Vector2(6, 10), Vector2(16, 16), Vector2(16, 27), Vector2(6, 21)]), faint)
			_poly(img, PackedVector2Array([Vector2(26, 10), Vector2(16, 16), Vector2(16, 27), Vector2(26, 21)]), faint)
			_line(img, 16, 5, 26, 10, ink)
			_line(img, 26, 10, 16, 16, ink)
			_line(img, 16, 16, 6, 10, ink)
			_line(img, 6, 10, 16, 5, ink)
			_line(img, 6, 10, 6, 21, ink)
			_line(img, 6, 21, 16, 27, ink)
			_line(img, 16, 27, 16, 16, ink)
			_line(img, 26, 10, 26, 21, ink)
			_line(img, 26, 21, 16, 27, ink)
			_rect(img, 23, 2, 2, 8, ink)
			_rect(img, 20, 4, 8, 2, ink)
		"use":
			_disc(img, 12, 12, 2.4, ink)
			_rect(img, 10, 12, 4, 9, ink)
			_disc(img, 16, 9, 2.4, ink)
			_rect(img, 14, 9, 4, 12, ink)
			_disc(img, 20, 11, 2.4, ink)
			_rect(img, 18, 11, 4, 10, ink)
			_disc(img, 24, 14, 2.2, ink)
			_rect(img, 22, 14, 4, 8, ink)
			_poly(img, PackedVector2Array([Vector2(9, 17), Vector2(26, 17), Vector2(25, 27),
				Vector2(12, 27), Vector2(8, 22)]), ink)
			_line(img, 12, 22, 23, 22, faint)
		"skill":
			_poly(img, PackedVector2Array([Vector2(16, 2), Vector2(19, 12), Vector2(29, 16),
				Vector2(19, 20), Vector2(16, 30), Vector2(13, 20), Vector2(3, 16), Vector2(13, 12)]), ink)
			_px(img, 25, 5, soft)
			_px(img, 26, 4, soft)
			_px(img, 27, 5, faint)
			_px(img, 7, 25, soft)
			_px(img, 5, 24, faint)
		"dismount":
			_poly(img, PackedVector2Array([Vector2(16, 28), Vector2(5, 15), Vector2(11, 15),
				Vector2(11, 5), Vector2(21, 5), Vector2(21, 15), Vector2(27, 15)]), ink)
			_line(img, 8, 30, 24, 30, soft)
		"throw":
			_disc(img, 17, 16, 11, ink)
			_disc(img, 17, 16, 8, soft)
			_disc(img, 17, 16, 5, ink)
			_disc(img, 14, 12, 2, soft)
			_line(img, 2, 10, 6, 10, soft)
			_line(img, 1, 13, 5, 13, faint)
			_px(img, 28, 5, soft)
		"eat":
			_disc(img, 16, 19, 8.5, ink)
			_disc(img, 13, 16, 3, soft)
			_line(img, 16, 11, 18, 6, soft)
			_poly(img, PackedVector2Array([Vector2(18, 8), Vector2(24, 4), Vector2(27, 7), Vector2(21, 11)]), soft)
			_px(img, 12, 13, faint)
		"till":
			_line(img, 8, 28, 21, 9, soft)
			_line(img, 9, 28, 22, 9, ink)
			_line(img, 19, 8, 29, 5, ink)
			_line(img, 19, 10, 28, 8, soft)
			_line(img, 26, 5, 26, 9, ink)
			_px(img, 24, 6, faint)
		"plant":
			_line(img, 16, 29, 16, 14, ink)
			_line(img, 16, 21, 10, 15, ink)
			_line(img, 16, 21, 22, 15, ink)
			_poly(img, PackedVector2Array([Vector2(6, 8), Vector2(12, 12), Vector2(10, 17), Vector2(4, 13)]), soft)
			_poly(img, PackedVector2Array([Vector2(25, 7), Vector2(29, 12), Vector2(25, 16), Vector2(21, 12)]), soft)
			_line(img, 8, 29, 24, 29, faint)
		"bag":
			_poly(img, PackedVector2Array([Vector2(7, 12), Vector2(11, 8), Vector2(21, 8),
				Vector2(25, 12), Vector2(25, 28), Vector2(7, 28)]), ink)
			_poly(img, PackedVector2Array([Vector2(9, 14), Vector2(12, 10), Vector2(20, 10),
				Vector2(23, 14), Vector2(23, 26), Vector2(9, 26)]), soft)
			_poly(img, PackedVector2Array([Vector2(7, 12), Vector2(11, 8), Vector2(21, 8),
				Vector2(25, 12), Vector2(23, 18), Vector2(9, 18)]), ink)
			_line(img, 11, 8, 16, 3, ink)
			_line(img, 12, 9, 17, 4, ink)
			_line(img, 21, 8, 16, 3, ink)
			_line(img, 20, 9, 15, 4, ink)
			_rect(img, 14, 15, 4, 5, faint)
			_px(img, 10, 20, faint)
			_px(img, 22, 20, faint)
			_px(img, 10, 23, faint)
			_px(img, 22, 23, faint)
		"craft":
			_line(img, 6, 28, 22, 9, ink)
			_line(img, 8, 28, 24, 9, soft)
			_poly(img, PackedVector2Array([Vector2(19, 11), Vector2(24, 3), Vector2(30, 6),
				Vector2(26, 15)]), ink)
			_poly(img, PackedVector2Array([Vector2(21, 11), Vector2(25, 5), Vector2(28, 6),
				Vector2(25, 13)]), soft)
			_line(img, 24, 4, 29, 6, ink)
			_px(img, 4, 9, ink)
			_px(img, 7, 6, soft)
			_px(img, 2, 13, faint)
			_line(img, 2, 18, 6, 18, faint)
		"team":
			_disc(img, 16, 21, 7.5, ink)
			_disc(img, 6.5, 13.5, 3.4, ink)
			_disc(img, 12.5, 8.0, 3.2, ink)
			_disc(img, 19.5, 8.0, 3.2, ink)
			_disc(img, 25.5, 13.5, 3.4, ink)
			_disc(img, 16, 21, 4.8, soft)
			_disc(img, 7.0, 13.8, 1.4, faint)
			_disc(img, 13.0, 8.5, 1.3, faint)
			_disc(img, 19.0, 8.5, 1.3, faint)
			_disc(img, 25.0, 13.8, 1.4, faint)
		"codex":
			_poly(img, PackedVector2Array([Vector2(4, 8), Vector2(15, 5), Vector2(15, 27),
				Vector2(4, 29)]), ink)
			_poly(img, PackedVector2Array([Vector2(17, 5), Vector2(28, 8), Vector2(28, 29),
				Vector2(17, 27)]), ink)
			_poly(img, PackedVector2Array([Vector2(6, 10), Vector2(13, 8), Vector2(13, 24.5),
				Vector2(6, 26)]), faint)
			_poly(img, PackedVector2Array([Vector2(19, 8), Vector2(26, 10), Vector2(26, 26),
				Vector2(19, 24.5)]), soft)
			_line(img, 16, 5, 16, 28, ink)
			for y in [13, 17, 21]:
				_line(img, 7, y, 12, y - 1, soft)
				_line(img, 20, y - 1, 25, y, faint)
		"quest":
			_rect(img, 8, 8, 16, 17, soft)
			_rect(img, 5, 5, 22, 4, ink)
			_rect(img, 5, 25, 22, 4, ink)
			_disc(img, 6, 7, 3, ink)
			_disc(img, 26, 7, 3, ink)
			_disc(img, 6, 27, 3, ink)
			_disc(img, 26, 27, 3, ink)
			_line(img, 11, 12, 21, 12, ink)
			_line(img, 11, 15, 21, 15, faint)
			_line(img, 11, 18, 18, 18, faint)
			_disc(img, 21, 22, 2.8, ink)
			_px(img, 20, 21, faint)
		"map":
			_poly(img, PackedVector2Array([Vector2(5, 8), Vector2(12, 6), Vector2(20, 9),
				Vector2(27, 7), Vector2(27, 25), Vector2(20, 27), Vector2(12, 24),
				Vector2(5, 26)]), ink)
			_poly(img, PackedVector2Array([Vector2(6.5, 10), Vector2(11.5, 8.5),
				Vector2(11.5, 24), Vector2(6.5, 25.5)]), faint)
			_poly(img, PackedVector2Array([Vector2(12.5, 8.8), Vector2(19.5, 11),
				Vector2(19.5, 25.5), Vector2(12.5, 24)]), soft)
			_poly(img, PackedVector2Array([Vector2(20.5, 11.2), Vector2(25.5, 9.5),
				Vector2(25.5, 24.5), Vector2(20.5, 25.8)]), faint)
			_line(img, 8, 22, 9, 18, ink)
			_line(img, 9, 18, 12, 16, ink)
			_px(img, 13, 15, ink)
			_line(img, 14, 14, 17, 15, ink)
			_line(img, 18, 15, 20, 18, ink)
			_line(img, 21, 12, 24, 15, ink)
			_line(img, 24, 12, 21, 15, ink)
		"pause":
			_rect(img, 9, 7, 5, 19, ink)
			_rect(img, 18, 7, 5, 19, ink)
			_rect(img, 9, 7, 2, 19, soft)
			_rect(img, 18, 7, 2, 19, soft)
		_:
			_disc(img, 16, 16, 9, ink)
	return img

static func block_icon(tile_img: Image, flat: bool = false) -> Image:
	var img := _new_img(32, 32)
	if flat:
		var big := tile_img.duplicate() as Image
		big.resize(30, 30, Image.INTERPOLATE_NEAREST)
		img.blit_rect(big, Rect2i(0, 0, 30, 30), Vector2i(1, 1))
		return img
	var base := _avg_color(tile_img)
	var top := base.lightened(0.2)
	var left := base.darkened(0.08)
	var right := base.darkened(0.32)
	_poly(img, PackedVector2Array([Vector2(16, 2), Vector2(29, 9), Vector2(16, 16), Vector2(3, 9)]), top)
	_poly(img, PackedVector2Array([Vector2(3, 9), Vector2(16, 16), Vector2(16, 29), Vector2(3, 21)]), left)
	_poly(img, PackedVector2Array([Vector2(29, 9), Vector2(16, 16), Vector2(16, 29), Vector2(29, 21)]), right)
	for p in [Vector2i(12, 7), Vector2i(19, 9), Vector2i(16, 12), Vector2i(22, 11), Vector2i(9, 10)]:
		_px(img, p.x, p.y, top.darkened(0.08))
	_px(img, 14, 6, top.lightened(0.15))
	for p in [Vector2i(6, 14), Vector2i(10, 18), Vector2i(8, 22), Vector2i(13, 23)]:
		_px(img, p.x, p.y, left.darkened(0.1))
	for p in [Vector2i(22, 13), Vector2i(25, 17), Vector2i(20, 22), Vector2i(24, 21)]:
		_px(img, p.x, p.y, right.lightened(0.08))
	_line(img, 4, 9, 16, 3, top.lightened(0.28))
	_line(img, 27, 9, 16, 3, top.lightened(0.12))
	_line(img, 16, 17, 16, 28, left.darkened(0.28))
	_outline(img, Color("#1a2723"))
	return img

static func portrait(shape: String, body: Color, belly: Color, accent: Color, eye: Color) -> Image:
	var img := _new_img(64, 64)
	var dark := body.darkened(0.55)
	_disc(img, 32, 38, 29, Color(accent.r, accent.g, accent.b, 0.10))
	# ears / silhouette decorations behind the head
	match shape:
		"quad":
			_diamond(img, 16, 18, 10, accent.darkened(0.15))
			_diamond(img, 48, 18, 10, accent.darkened(0.15))
			_diamond(img, 16, 18, 6.5, accent)
			_diamond(img, 48, 18, 6.5, accent)
		"floater":
			_diamond(img, 10, 34, 12, accent.darkened(0.2))
			_diamond(img, 54, 34, 12, accent.darkened(0.2))
			_diamond(img, 14, 34, 7, accent)
			_diamond(img, 50, 34, 7, accent)
		"serpent":
			_line(img, 20, 16, 12, 4, dark)
			_line(img, 44, 16, 52, 4, dark)
			_line(img, 20, 16, 12, 4, accent)
			_line(img, 44, 16, 52, 4, accent)
			_disc(img, 12, 4, 3.2, accent)
			_disc(img, 52, 4, 3.2, accent)
		"insect":
			_line(img, 22, 20, 14, 4, accent)
			_line(img, 42, 20, 50, 4, accent)
			_disc(img, 14, 4, 3.0, accent)
			_disc(img, 50, 4, 3.0, accent)
			_diamond(img, 8, 38, 10, accent.darkened(0.25))
			_diamond(img, 56, 38, 10, accent.darkened(0.25))
		"golem":
			_rect(img, 12, 18, 10, 10, accent.darkened(0.25))
			_rect(img, 42, 18, 10, 10, accent.darkened(0.25))
			_diamond(img, 32, 12, 6, accent)
		"biped":
			_disc(img, 32, 20, 22, accent.darkened(0.1))
			_disc(img, 32, 23, 18, accent)
			_disc(img, 22, 20, 3, accent.lightened(0.35))
			_disc(img, 42, 27, 2.5, accent.lightened(0.3))
	# head
	for y in range(20, 57):
		var w := 18 + sin((y - 20) / 37.0 * PI) * 16
		_rect(img, int(32 - w), y, int(w * 2), 1, body)
	_disc(img, 32, 31, 20, body)
	_disc(img, 23, 26, 8, body.lightened(0.08))
	# muzzle / belly patch
	_disc(img, 32, 46, 11, belly)
	# eyes
	for ex in [23, 41]:
		_disc(img, ex, 33, 5.4, Color("#f7f2dd"))
		_disc(img, ex + 0.5, 34, 3.0, eye)
		_disc(img, ex - 1, 32.5, 1.2, Color(1, 1, 1, 0.9))
	# nose and mouth
	_diamond(img, 32, 41, 3.0, dark)
	_line(img, 28, 47, 36, 47, dark)
	_px(img, 28, 46, dark)
	_px(img, 36, 46, dark)
	# cheeks
	_disc(img, 15, 44, 3.5, accent.lightened(0.15))
	_disc(img, 49, 44, 3.5, accent.lightened(0.15))
	# forehead accent
	_diamond(img, 32, 21, 4.5, accent)
	_diamond(img, 32, 21, 2.0, accent.lightened(0.4))

	# fine grain so the portrait reads as fur / scales instead of a flat fill
	var grain_dark := body.darkened(0.16)
	var grain_light := body.lightened(0.13)
	for gy in range(22, 57, 3):
		for gx in range(12, 53, 4):
			var base_px := img.get_pixel(gx, gy)
			if base_px.a < 0.5 or base_px.v > 0.82:
				continue
			var pick := int(abs(sin(float(gx) * 12.9898 + float(gy) * 78.233)) * 43758.55) % 3
			if pick == 0:
				_px(img, gx, gy, grain_dark)
			elif pick == 1 and gx + 1 < 64:
				_px(img, gx + 1, gy, grain_light)
	_outline(img, dark, 0.4)
	return img
