class_name UITheme
extends RefCounted

const INK := Color("#f3f0df")
const MUTED := Color("#a9bcae")
const BG := Color("#061515")
const PANEL := Color(0.035, 0.105, 0.105, 0.94)
const PANEL_SOFT := Color(0.05, 0.14, 0.14, 0.88)
const SLOT := Color(0.055, 0.15, 0.15, 0.9)
const LINE := Color("#2f4f49")
const AMBER := Color("#f0b857")
const AMBER_DIM := Color("#a77a33")
const GREEN := Color("#7fd39a")
const RED := Color("#e47c6a")
const TEAL := Color("#59cbb3")
const SHADOW := Color(0, 0, 0, 0.35)

static var _body: Font
static var _title: Font
static var _theme: Theme
static var font_boost := 1.0

static func body_font() -> Font:
	if _body == null:
		_body = load("res://assets/fonts/Nunito-Variable.ttf")
	return _body

static func title_font() -> Font:
	if _title == null:
		_title = load("res://assets/fonts/Silkscreen-Bold.ttf")
	return _title

static func make_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 20
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_color", "LineEdit", INK)
	t.set_font("font", "Button", body_font())
	t.set_font_size("font_size", "Button", 18)
	_theme = t
	return t

static func style(bg: Color, border: Color, radius: int = 12, border_width: int = 1,
		margin: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_width
	sb.border_width_top = border_width
	sb.border_width_right = border_width
	sb.border_width_bottom = border_width
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = maxi(margin - 4, 4)
	sb.content_margin_bottom = maxi(margin - 4, 4)
	return sb

static func panel_style(radius: int = 20) -> StyleBoxFlat:
	var sb := style(Color(0.04, 0.105, 0.105, 0.975), Color("#3f6259"), radius, 2, 20)
	sb.shadow_color = SHADOW
	sb.shadow_size = 26
	sb.shadow_offset = Vector2(0, 12)
	sb.corner_detail = 12
	sb.anti_aliasing = true
	sb.expand_margin_left = 1
	sb.expand_margin_right = 1
	sb.expand_margin_top = 1
	sb.expand_margin_bottom = 1
	sb.shadow_offset = Vector2(0, 8)
	return sb

static func glass_style(radius: int = 14, alpha: float = 0.82) -> StyleBoxFlat:
	return style(Color(0.035, 0.1, 0.1, alpha), Color(0.36, 0.58, 0.53, 0.5), radius, 1, 10)

static func button_style(kind: String = "normal") -> StyleBoxFlat:
	match kind:
		"primary":
			return style(Color("#d99f3f"), Color("#ffe0a0"), 12, 1, 16)
		"ghost":
			return style(Color(0.05, 0.13, 0.13, 0.55), Color(0.4, 0.6, 0.55, 0.35), 12, 1, 12)
		"danger":
			return style(Color(0.27, 0.1, 0.09, 0.92), Color(0.72, 0.33, 0.29, 0.9), 12, 1, 14)
		"slot":
			return style(SLOT, LINE, 10, 1, 4)
		_:
			return style(Color(0.055, 0.145, 0.14, 0.92), Color(0.32, 0.52, 0.48, 0.85), 12, 1, 14)

static func make_button(parent: Node, text: String, kind: String = "normal",
		min_height: int = 52, font_size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, int(min_height * (1.0 + (font_boost - 1.0) * 0.35)))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", body_font())
	b.add_theme_font_size_override("font_size", int(max(16, (font_size + 4) * font_boost)))
	b.add_theme_color_override("font_color", INK if kind != "primary" else Color("#20170a"))
	b.add_theme_color_override("font_hover_color", Color.WHITE if kind != "primary" else Color("#120d05"))
	b.add_theme_color_override("font_pressed_color", Color("#e8e2cc") if kind != "primary" else Color("#0b0702"))
	b.add_theme_color_override("font_disabled_color", Color(0.65, 0.7, 0.65, 0.45))
	_wire_hover_motion(b)
	if kind == "primary":
		b.add_theme_stylebox_override("normal", style(Color("#e0aa4a"), Color("#ffe3a2"), 12, 1, 16))
		b.add_theme_stylebox_override("hover", style(Color("#f0bd5c"), Color("#fff0c4"), 12, 1, 16))
		b.add_theme_stylebox_override("pressed", style(Color("#c08834"), Color("#ffe3a2"), 12, 1, 16))
		b.add_theme_stylebox_override("disabled", style(Color(0.35, 0.3, 0.18, 0.7), Color(0.4, 0.36, 0.22, 0.6), 12, 1, 16))
	else:
		var normal := button_style(kind)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.09, 0.22, 0.21, 0.95)
		hover.border_color = Color(0.55, 0.78, 0.69, 0.8)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0.02, 0.08, 0.08, 0.98)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", pressed)
		b.add_theme_stylebox_override("disabled", style(Color(0.04, 0.09, 0.09, 0.55), Color(0.22, 0.3, 0.28, 0.5), 12, 1, 14))
	if parent != null:
		parent.add_child(b)
	return b

static func make_round_button(parent: Node, text: String, size: int = 56, font_size: int = 14) -> Button:
	var b := make_button(parent, text, "ghost", size, font_size)
	b.custom_minimum_size = Vector2(size, size)
	var sb := style(Color(0.035, 0.105, 0.105, 0.78), Color(0.42, 0.64, 0.58, 0.55), size / 2, 1, 4)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.08, 0.2, 0.19, 0.92)
	sb_h.border_color = AMBER
	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.02, 0.07, 0.07, 0.95)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", int(min(20, (font_size + 5) * font_boost)))
	b.add_theme_color_override("font_color", INK)
	return b

static func make_label(parent: Node, text: String, size: int = 18, color: Color = INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", body_font())
	l.add_theme_font_size_override("font_size", int(max(15, (size + 4) * font_boost)))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(l)
	return l

static func make_heading(parent: Node, text: String, size: int = 28,
		color: Color = INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", int(max(15, (size + 4) * font_boost)))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(l)
	return l

static func make_bar(parent: Node, width: float, height: float, fill: Color,
		bg: Color = Color(0.02, 0.06, 0.06, 0.9)) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(width, height)
	pb.show_percentage = false
	pb.max_value = 100.0
	pb.value = 100.0
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_theme_stylebox_override("background", style(bg, Color(0.2, 0.33, 0.3, 0.6), int(height / 2.0), 1, 0))
	pb.add_theme_stylebox_override("fill", style(fill, fill.lightened(0.2), int(height / 2.0), 0, 0))
	if parent != null:
		parent.add_child(pb)
	return pb

static func _wire_hover_motion(b: Button) -> void:
	b.pivot_offset = b.custom_minimum_size * 0.5
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	b.button_down.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2(0.965, 0.965), 0.06))
	b.button_up.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2(1.03, 1.03), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))

static func make_vignette(strength: float = 0.5) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.03, 0.03, 0.0))
	g.set_color(1, Color(0.01, 0.03, 0.03, strength))
	g.add_point(0.6, Color(0.01, 0.03, 0.03, 0.0))
	g.add_point(0.85, Color(0.01, 0.03, 0.03, strength * 0.5))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return tr

static func make_slot(parent: Node, size: int = 58) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.expand_icon = true
	b.add_theme_stylebox_override("normal", button_style("slot"))
	var h := style(Color(0.08, 0.2, 0.18, 0.95), AMBER_DIM, 10, 1, 4)
	h.bg_color = Color(0.08, 0.2, 0.185, 0.95)
	b.add_theme_stylebox_override("hover", h)
	var p := style(Color(0.02, 0.07, 0.07, 1), AMBER, 10, 1, 4)
	b.add_theme_stylebox_override("pressed", p)
	_wire_hover_motion(b)
	if parent != null:
		parent.add_child(b)
	return b

static func make_scroll(parent: Node) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if parent != null:
		parent.add_child(sc)
	return sc

static func make_vbox(parent: Node, sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(v)
	return v

static func make_hbox(parent: Node, sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(h)
	return h

static func make_margin(parent: Node, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(m)
	return m

static func make_card(parent: Node, radius: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(Color(0.045, 0.125, 0.12, 0.85), Color(0.26, 0.43, 0.39, 0.75), radius, 1, 14))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(p)
	return p

static func chip(parent: Node, text: String, color: Color = MUTED, size: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(Color(0.03, 0.08, 0.08, 0.65), Color(color.r, color.g, color.b, 0.45), 20, 1, 10))
	var l := make_label(p, text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(p)
	return p

static func divider(parent: Node) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.3, 0.45, 0.41, 0.35)
	c.custom_minimum_size = Vector2(0, 1)
	if parent != null:
		parent.add_child(c)
	return c

static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

static func fmt_time(seconds: float) -> String:
	var s := int(seconds)
	var h := s / 3600
	var m := (s % 3600) / 60
	return "%dj %02d:%02d" % [h, m, s % 60]
