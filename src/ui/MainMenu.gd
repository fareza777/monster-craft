class_name MainMenu
extends Control

signal new_world_requested(slot: int, seed_value: int)
signal load_world_requested(slot: int)
signal quit_requested

var main: Node
var continue_button: Button
var slot_overlay: Control
var slot_mode := "new"
var seed_input: LineEdit
var settings_overlay: Control
var guide_overlay: Control
var confirm_overlay: Control
var confirm_cb: Callable
var _latest_slot := -1
var _last_overlay: Control

func setup(p_main: Node) -> void:
	main = p_main
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.font_boost = 1.2 if (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()) else 1.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.make_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	var art := TextureRect.new()
	art.texture = load("res://assets/art/menu_keyart.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var dim_all := ColorRect.new()
	dim_all.color = Color(0.0, 0.02, 0.02, 0.16)
	dim_all.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_all.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim_all)
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.015, 0.04, 0.045, 0.92), Color(0.015, 0.04, 0.045, 0.55), Color(0, 0, 0, 0)])
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0, 0.5)
	grad_tex.fill_to = Vector2(1, 0.5)
	grad_tex.width = 512
	grad_tex.height = 32
	shade.texture = grad_tex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.anchor_top = 0.5
	left.anchor_bottom = 0.5
	left.offset_left = 64
	left.offset_right = 590
	left.offset_top = -300
	left.offset_bottom = 300
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	var tag := UITheme.make_label(left, "OFFLINE VOXEL WORLD • MONSTERS & ADVENTURE", 11, UITheme.AMBER)
	tag.add_theme_constant_override("outline_size", 4)
	tag.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.05, 0.9))
	var title := UITheme.make_heading(left, "MONSTERCRAFT", 54, UITheme.INK)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	var sub := UITheme.make_heading(left, "VOXEL ADVENTURE", 22, UITheme.AMBER)
	var desc := UITheme.make_label(left, "Mine, build, tame monsters, and conquer a world shaped by your own seed.", 15, Color(0.86, 0.9, 0.82, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(480, 0)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	left.add_child(gap)
	var menu_card := PanelContainer.new()
	menu_card.add_theme_stylebox_override("panel", UITheme.style(Color(0.03, 0.09, 0.085, 0.86), Color(0.3, 0.51, 0.46, 0.65), 18, 1, 18))
	menu_card.custom_minimum_size = Vector2(360, 0)
	menu_card.mouse_filter = Control.MOUSE_FILTER_STOP
	left.add_child(menu_card)
	var buttons := UITheme.make_vbox(menu_card, 8)
	continue_button = UITheme.make_button(buttons, "Continue Adventure", "primary", 50, 17)
	continue_button.pressed.connect(_on_continue)
	UITheme.make_button(buttons, "New World", "normal", 46, 16).pressed.connect(func(): _open_slots("new"))
	UITheme.make_button(buttons, "Load Save", "normal", 46, 16).pressed.connect(func(): _open_slots("load"))
	UITheme.make_button(buttons, "Settings", "ghost", 42, 15).pressed.connect(_open_settings)
	UITheme.make_button(buttons, "How to Play", "ghost", 42, 15).pressed.connect(_open_guide)
	UITheme.make_button(buttons, "Quit", "ghost", 42, 15).pressed.connect(func(): quit_requested.emit())
	var footer := UITheme.make_label(left, "Offline • 3 world slots • v1.0", 11, Color(0.7, 0.78, 0.7, 0.6))
	footer.add_theme_constant_override("outline_size", 3)
	footer.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.05, 0.8))
	_refresh_continue()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		for ov in [confirm_overlay, settings_overlay, guide_overlay, slot_overlay]:
			if ov != null:
				ov.queue_free()
				if ov == confirm_overlay:
					confirm_overlay = null
				elif ov == settings_overlay:
					settings_overlay = null
				elif ov == guide_overlay:
					guide_overlay = null
				elif ov == slot_overlay:
					slot_overlay = null
				get_viewport().set_input_as_handled()
				return

func _refresh_continue() -> void:
	_latest_slot = -1
	var latest_time := ""
	for m in Game.list_saves():
		if m.exists:
			if str(m.saved_at) > latest_time:
				latest_time = str(m.saved_at)
				_latest_slot = int(m.slot)
	continue_button.disabled = _latest_slot < 0
	if _latest_slot < 0:
		continue_button.text = "No Saves Yet"
	else:
		var meta := Game.get_save_meta(_latest_slot)
		continue_button.text = "Continue • Day %d (Slot %d)" % [int(meta.day), _latest_slot]

func _on_continue() -> void:
	if _latest_slot >= 0:
		load_world_requested.emit(_latest_slot)

func _open_slots(mode: String) -> void:
	slot_mode = mode
	if slot_overlay != null:
		slot_overlay.queue_free()
		slot_overlay = null
	slot_overlay = _make_overlay()
	_last_overlay = slot_overlay
	var card := _modal_card(Vector2(940, 590))
	var v := UITheme.make_vbox(card, 10)
	UITheme.make_heading(v, "New World" if mode == "new" else "Load Save", 28, UITheme.INK)
	UITheme.make_label(v, "Choose one of the three slots. A new world uses a random seed unless you enter one." if mode == "new" else "Choose the world you want to continue.", 13, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if mode == "new":
		var srow := UITheme.make_hbox(v, 10)
		UITheme.make_label(srow, "Seed (optional)", 13, UITheme.MUTED)
		seed_input = LineEdit.new()
		seed_input.placeholder_text = "Leave blank for random"
		seed_input.custom_minimum_size = Vector2(300, 42)
		seed_input.add_theme_stylebox_override("normal", UITheme.style(Color(0.03, 0.08, 0.08, 0.9), Color(0.3, 0.5, 0.45, 0.6), 10, 1, 10))
		seed_input.add_theme_color_override("font_color", UITheme.INK)
		seed_input.add_theme_font_override("font", UITheme.body_font())
		srow.add_child(seed_input)
	for meta in Game.list_saves():
		_slot_card(v, meta)
	var back := UITheme.make_button(v, "Back", "ghost", 42, 14)
	back.pressed.connect(func(): slot_overlay.queue_free(); slot_overlay = null)
	var close := _overlay_close(slot_overlay)
	close.pressed.connect(func(): slot_overlay.queue_free(); slot_overlay = null)

func _slot_card(parent: Node, meta: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.style(Color(0.04, 0.115, 0.105, 0.88), Color(0.28, 0.46, 0.42, 0.7), 14, 1, 14))
	parent.add_child(card)
	var row := UITheme.make_hbox(card, 14)
	UITheme.make_heading(row, "S%d" % int(meta.slot), 24, UITheme.AMBER).custom_minimum_size = Vector2(48, 0)
	var info := UITheme.make_vbox(row, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bool(meta.exists):
		UITheme.make_heading(info, str(meta.world_name), 18, UITheme.INK)
		UITheme.make_label(info, "Day %d • Level %d • Played %s" % [int(meta.day), int(meta.level), UITheme.fmt_time(float(meta.play_time))], 12, UITheme.MUTED)
		UITheme.make_label(info, "Seed %d • Saved %s" % [int(meta.seed), str(meta.saved_at)], 11, UITheme.MUTED)
	else:
		UITheme.make_heading(info, "Empty Slot", 18, UITheme.MUTED)
		UITheme.make_label(info, "Ready for a new world.", 12, UITheme.MUTED)
	var actions := UITheme.make_hbox(row, 6)
	if bool(meta.exists):
		if slot_mode == "load":
			UITheme.make_button(actions, "Play", "primary", 42, 13).pressed.connect(func():
				_launch_load(int(meta.slot)))
		else:
			UITheme.make_button(actions, "Overwrite", "normal", 42, 13).pressed.connect(func():
				_ask_confirm("Overwrite slot %d?" % int(meta.slot), "The old world in this slot will be lost forever.", func():
					_launch_new(int(meta.slot))))
		UITheme.make_button(actions, "Delete", "danger", 42, 13).pressed.connect(func():
			_ask_confirm("Delete slot %d?" % int(meta.slot), "This save will be permanently deleted.", func():
				Game.delete_save(int(meta.slot))
				if slot_overlay != null:
					slot_overlay.queue_free()
					slot_overlay = null
				_open_slots(slot_mode)))
	else:
		if slot_mode == "new":
			UITheme.make_button(actions, "Create World", "primary", 42, 13).pressed.connect(func():
				_launch_new(int(meta.slot)))

func _launch_new(slot: int) -> void:
	var seed_value := 0
	if seed_input != null and seed_input.text.strip_edges() != "":
		seed_value = seed_input.text.strip_edges().to_int()
	new_world_requested.emit(slot, seed_value)

func _launch_load(slot: int) -> void:
	load_world_requested.emit(slot)

func _make_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	_last_overlay = overlay
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.025, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	return overlay

func _modal_card(min_size: Vector2) -> PanelContainer:
	var center := _overlay_center()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.panel_style(20))
	card.custom_minimum_size = min_size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	return card

func _overlay_center() -> CenterContainer:
	if _last_overlay != null:
		for cc in _last_overlay.get_children():
			if cc is CenterContainer:
				return cc
	return null

func _overlay_close(overlay: Control) -> Button:
	var buttons := Button.new()
	buttons.text = "X"
	buttons.custom_minimum_size = Vector2(44, 44)
	buttons.anchor_left = 1
	buttons.anchor_right = 1
	buttons.anchor_top = 0
	buttons.offset_left = -58
	buttons.offset_right = -14
	buttons.offset_top = 14
	buttons.add_theme_font_override("font", UITheme.title_font())
	buttons.add_theme_stylebox_override("normal", UITheme.style(Color(0.05, 0.12, 0.11, 0.9), Color(0.4, 0.6, 0.55, 0.6), 22, 1, 4))
	buttons.add_theme_stylebox_override("hover", UITheme.style(Color(0.1, 0.2, 0.18, 0.95), UITheme.AMBER, 22, 1, 4))
	overlay.add_child(buttons)
	return buttons

func _open_settings() -> void:
	if settings_overlay != null:
		settings_overlay.queue_free()
	settings_overlay = _make_overlay()
	_last_overlay = settings_overlay
	var card := _modal_card(Vector2(860, 640))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var v := UITheme.make_vbox(scroll, 10)
	v.custom_minimum_size = Vector2(800, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.make_heading(v, "Settings", 28, UITheme.INK)
	UITheme.make_heading(v, "Controls", 16, UITheme.AMBER)
	_settings_slider(v, "Sensitivity", 0.35, 2.5, Game.look_sensitivity, func(x): Game.look_sensitivity = x)
	_settings_toggle(v, "Invert look (Y)", Game.invert_look_y, func(x): Game.invert_look_y = x)
	_settings_toggle(v, "Left-handed layout", Game.left_handed, func(x): Game.left_handed = x)
	_settings_toggle(v, "Screen shake", Game.screen_shake, func(x): Game.screen_shake = x)
	UITheme.make_heading(v, "Audio", 16, UITheme.AMBER)
	_settings_slider(v, "Master", 0.0, 1.0, Game.master_volume, func(x): Game.master_volume = x; Sfx.set_master_volume(x))
	_settings_slider(v, "Music", 0.0, 1.0, Game.music_volume, func(x): Game.music_volume = x; Sfx.set_music_volume(x))
	_settings_slider(v, "Effects", 0.0, 1.0, Game.sfx_volume, func(x): Game.sfx_volume = x; Sfx.set_sfx_volume(x))
	UITheme.make_heading(v, "Render Distance", 16, UITheme.AMBER)
	var row := UITheme.make_hbox(v, 8)
	for d in [[3, "Low"], [4, "Balanced"], [5, "Far"], [6, "Ultra"], [7, "Massive"]]:
		var b := UITheme.make_button(row, str(d[1]), "primary" if Game.view_distance == int(d[0]) else "normal", 44, 14)
		b.pressed.connect(func():
			Game.view_distance = int(d[0])
			Game.save_settings()
			settings_overlay.queue_free()
			settings_overlay = null
			_open_settings())
	UITheme.make_label(v, "Settings apply to all worlds and are saved automatically. Mid-range phones should use Balanced.", 12, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := UITheme.make_hbox(v, 8)
	var reset := UITheme.make_button(actions, "Reset Defaults", "normal", 46)
	reset.pressed.connect(func():
		Game.reset_settings()
		Sfx.apply_volumes()
		settings_overlay.queue_free()
		settings_overlay = null
		_open_settings())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var back := UITheme.make_button(actions, "Save & Back", "primary", 46)
	back.pressed.connect(func():
		Game.save_settings()
		settings_overlay.queue_free()
		settings_overlay = null)
	var close := _overlay_close(settings_overlay)
	close.pressed.connect(func():
		Game.save_settings()
		settings_overlay.queue_free()
		settings_overlay = null)

func _settings_toggle(parent: Node, label: String, value: bool, on_change: Callable) -> void:
	var row := UITheme.make_hbox(parent, 10)
	UITheme.make_label(row, label, 14, UITheme.INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := UITheme.make_button(row, "On" if value else "Off", "primary" if value else "normal", 40, 13)
	b.custom_minimum_size = Vector2(96, 40)
	b.pressed.connect(func():
		on_change.call(not value)
		Game.save_settings()
		settings_overlay.queue_free()
		settings_overlay = null
		_open_settings())

func _settings_slider(parent: Node, label: String, min_v: float, max_v: float, value: float, on_change: Callable) -> void:
	var row := UITheme.make_hbox(parent, 10)
	UITheme.make_label(row, label, 14, UITheme.INK).custom_minimum_size = Vector2(160, 0)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(320, 36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(slider)
	var val := UITheme.make_label(row, "%.2f" % value, 12, UITheme.MUTED)
	val.custom_minimum_size = Vector2(50, 0)
	slider.value_changed.connect(func(x):
		val.text = "%.2f" % x
		on_change.call(x))
	slider.drag_ended.connect(func(_changed): Game.save_settings())

func _open_guide() -> void:
	if guide_overlay != null:
		guide_overlay.queue_free()
	guide_overlay = _make_overlay()
	_last_overlay = guide_overlay
	var card := _modal_card(Vector2(820, 540))
	var v := UITheme.make_vbox(card, 8)
	UITheme.make_heading(v, "How to Play", 28, UITheme.INK)
	UITheme.make_heading(v, "Controls", 16, UITheme.AMBER)
	var lines := [
		"Move: left joystick (Android) or WASD.",
		"Look: drag the right side of the screen or move the mouse.",
		"Mine & attack: hold MINE / left click.",
		"Place blocks: PLACE / right click. Use & interact: USE / F.",
		"Partner skill: SKILL / R. Bag: E. Crafting: C.",
		"Quests: J, map: M, codex: K, pause: Esc.",
	]
	UITheme.make_label(v, "\n".join(lines), 13, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.make_heading(v, "Alur Awal", 16, UITheme.AMBER)
	UITheme.make_label(v, "Choose a partner, gather wood and stone, craft a table, then improve your tools. Tame passive monsters with Feed or weaken aggressive ones and use a Capture Orb. Build a Ranch Banner for breeding and automated workers. Find villages for quests and trade, then challenge dungeons and the World Rift.", 13, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := UITheme.make_button(v, "Back", "primary", 44)
	back.pressed.connect(func(): guide_overlay.queue_free(); guide_overlay = null)
	var close := _overlay_close(guide_overlay)
	close.pressed.connect(func(): guide_overlay.queue_free(); guide_overlay = null)

func _ask_confirm(title: String, text: String, cb: Callable) -> void:
	if confirm_overlay != null:
		confirm_overlay.queue_free()
	confirm_cb = cb
	confirm_overlay = _make_overlay()
	_last_overlay = confirm_overlay
	var card := _modal_card(Vector2(560, 240))
	var v := UITheme.make_vbox(card, 10)
	UITheme.make_heading(v, title, 20, UITheme.INK)
	UITheme.make_label(v, text, 13, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := UITheme.make_hbox(v, 8)
	UITheme.make_button(row, "Yes", "danger", 44, 14).pressed.connect(func():
		var cb2 := confirm_cb
		confirm_overlay.queue_free()
		confirm_overlay = null
		if cb2.is_valid():
			cb2.call())
	UITheme.make_button(row, "Cancel", "normal", 44, 14).pressed.connect(func():
		confirm_overlay.queue_free()
		confirm_overlay = null)
