class_name MinimapView
extends Control

var world: VoxelWorld
var player: Node3D
var main: Node
var large := false
var _refresh := 0.0
var _cells := 34
var _range_blocks := 52.0
var _font: Font
var _map_texture: ImageTexture
var _map_image: Image
var _tex_size := 128

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UITheme.title_font()
	if large:
		_cells = 64
		_range_blocks = 150.0
		_tex_size = 96
	else:
		_tex_size = 40
	_refresh_map()

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 2.4 if not large else 2.0
		_refresh_map()

func _refresh_map() -> void:
	if world == null or player == null or world.gen == null:
		return
	if _map_image == null or _map_image.get_width() != _tex_size:
		_map_image = Image.create(_tex_size, _tex_size, false, Image.FORMAT_RGBA8)
		_map_texture = ImageTexture.create_from_image(_map_image)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var px := floori(player.global_position.x)
	var pz := floori(player.global_position.z)
	var step := _range_blocks / float(_tex_size)
	for y in _tex_size:
		for x in _tex_size:
			var wx := px + int((x - _tex_size * 0.5) * step)
			var wz := pz + int((y - _tex_size * 0.5) * step)
			var col := world.gen.map_color_at(wx, wz)
			var h := world.gen.height_at(wx, wz)
			if h < world.gen.SEA:
				col = col.darkened(0.04)
			elif h % 5 == 0:
				col = col.darkened(0.07)
			_map_image.set_pixel(x, y, col)
	_map_texture.update(_map_image)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.02, 0.05, 0.05, 0.9))
	var inner := rect.grow(-5)
	draw_rect(inner, Color(0.03, 0.08, 0.08, 1.0))
	if _map_texture != null:
		var map_rect := inner
		draw_texture_rect(_map_texture, map_rect, false)
	# subtle vignette / border
	draw_rect(inner, Color(0.5, 0.75, 0.66, 0.22), false, 1.0)
	if player == null or world == null:
		draw_rect(rect, Color(0.02, 0.05, 0.05, 1), false, 3.0)
		return
	var center := rect.position + rect.size * 0.5
	var scale_factor := inner.size.x / (_range_blocks * 2.0)
	var ppos := player.global_position
	# villages
	for key in Game.discovered_villages:
		var v = Game.discovered_villages[key]
		if v is Array and v.size() >= 3:
			var vp := Vector2(float(v[0]) - ppos.x, float(v[2]) - ppos.z)
			if absf(vp.x) <= _range_blocks and absf(vp.y) <= _range_blocks:
				var sp := center + vp * scale_factor
				_draw_marker_house(sp)
	# dungeons nearby (always show the nearest)
	if world.gen != null:
		var d := world.get_nearest_dungeon(ppos)
		if not d.is_empty():
			var c: Vector3i = d.entrance
			var dp := Vector2(c.x - ppos.x, c.z - ppos.z)
			if absf(dp.x) <= _range_blocks and absf(dp.y) <= _range_blocks:
				_draw_marker_dungeon(center + dp * scale_factor)
	# tracked waypoint
	if main != null and main.get("tracked_waypoint") != null:
		var wp: Vector3 = main.tracked_waypoint
		if wp != Vector3.ZERO:
			var tp := Vector2(wp.x - ppos.x, wp.z - ppos.z)
			if absf(tp.x) <= _range_blocks and absf(tp.y) <= _range_blocks:
				var sp2 := center + tp * scale_factor
				draw_arc(sp2, 8.0, 0, TAU, 32, UITheme.AMBER, 2.0, true)
				draw_circle(sp2, 3.0, UITheme.AMBER)
	# story quest markers
	if main != null and main.has_method("quest_marker_points"):
		for qm in main.call("quest_marker_points"):
			var qp: Vector3 = qm.pos
			var rel := Vector2(qp.x - ppos.x, qp.z - ppos.z)
			if absf(rel.x) <= _range_blocks and absf(rel.y) <= _range_blocks:
				_draw_marker_quest(center + rel * scale_factor, str(qm.kind), bool(qm.done))
	# player arrow
	draw_circle(center, 9.0, Color(0.02, 0.07, 0.07, 0.9))
	var yaw: float = player.rotation.y
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(-fwd.y, fwd.x)
	var p1 := center + fwd * 10.0
	var p2 := center - fwd * 6.0 + right * 6.0
	var p3 := center - fwd * 6.0 - right * 6.0
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), UITheme.AMBER)
	draw_polyline(PackedVector2Array([p1, p2, p3, p1]), Color("#2a1d0a"), 1.5, true)
	# corners
	var nsize := 16 if large else 13
	draw_string(_font, Vector2(center.x - 6, rect.position.y + nsize), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, nsize, Color("#eef3e2"))
	draw_rect(rect, Color(0.26, 0.42, 0.38, 0.7), false, 2.0)
	if large:
		var dist_txt := "Local map"
		draw_string(_font, Vector2(rect.position.x + 10, rect.position.y + 22), dist_txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.9, 0.82, 0.75))

func _draw_marker_house(p: Vector2) -> void:
	var s := 6.0
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0),
		p + Vector2(-s, 0)]), Color("#e2b45b"))
	draw_rect(Rect2(p + Vector2(-s * 0.6, 0), Vector2(s * 1.2, s * 0.8)), Color("#c98c3c"))

func _draw_marker_dungeon(p: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(8, 0),
		p + Vector2(0, 8), p + Vector2(-8, 0)]), Color("#c39bf0"))
	draw_circle(p, 2.8, Color("#3c2b52"))


func _draw_marker_quest(p: Vector2, kind: String, done: bool) -> void:
	var col: Color = UITheme.GREEN if done else (UITheme.AMBER if kind == "main" else UITheme.TEAL)
	draw_circle(p, 9.0, Color(0.02, 0.06, 0.05, 0.85))
	var pts := PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 0), p + Vector2(0, 7), p + Vector2(-6, 0)])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.05, 0.09, 0.07, 0.9), 1.4, true)
