class_name TouchJoystick
extends Control

var active := false
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var radius := 96.0
var value := Vector2.ZERO
var touch_index := -1
var accent := Color("#f0b857")
var base_color := Color(0.04, 0.12, 0.12, 0.55)
var ring_color := Color(0.42, 0.64, 0.58, 0.45)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func show_at(pos: Vector2, index: int = -1) -> void:
	active = true
	touch_index = index
	origin = pos
	knob = pos
	value = Vector2.ZERO
	visible = true
	queue_redraw()

func update_at(pos: Vector2) -> void:
	if not active:
		return
	var delta := pos - origin
	if delta.length() > radius:
		delta = delta.normalized() * radius
	knob = origin + delta
	value = delta / radius
	value = Vector2(value.x, value.y)
	queue_redraw()

func release() -> void:
	active = false
	touch_index = -1
	value = Vector2.ZERO
	visible = false
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	draw_circle(origin, radius + 14.0, Color(0.01, 0.04, 0.04, 0.35))
	draw_circle(origin, radius, base_color)
	draw_arc(origin, radius, 0, TAU, 64, ring_color, 2.0, true)
	draw_arc(origin, radius * 0.62, 0, TAU, 48, Color(ring_color.r, ring_color.g, ring_color.b, 0.2), 1.2, true)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var p1 := origin + Vector2(cos(a), sin(a)) * (radius + 4.0)
		var p2 := origin + Vector2(cos(a), sin(a)) * (radius + 10.0)
		draw_line(p1, p2, Color(ring_color.r, ring_color.g, ring_color.b, 0.35), 1.0, true)
	draw_circle(knob, 42.0, Color(0.06, 0.17, 0.16, 0.95))
	draw_circle(knob, 37.0, Color(0.1, 0.24, 0.22, 1.0))
	draw_arc(knob, 37.0, 0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.7), 2.0, true)
	draw_circle(knob, 13.0, accent)
	draw_circle(knob + Vector2(-4, -4), 5.0, Color(1, 1, 1, 0.45))
