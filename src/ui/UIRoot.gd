class_name UIRoot
extends Control

var player: CraftPlayer
var world: VoxelWorld
var main: Node
var spawner: MonsterSpawner
var is_touch := false

var hud: Control
var touch_area: Control
var joystick: TouchJoystick
var joy_idx := -1
var look_idx := -1

var stats_panel: PanelContainer
var level_label: Label
var hero_label: Label
var wallet_label: Label
var hp_bar: ProgressBar
var hp_text: Label
var stamina_bar: ProgressBar
var stamina_text: Label
var xp_bar: ProgressBar
var clock_panel: PanelContainer
var clock_time: Label
var clock_info: Label
var rift_label: Label
var menu_bar: PanelContainer
var minimap: MinimapView

var target_panel: PanelContainer
var target_portrait: TextureRect
var target_name: Label
var target_sub: Label
var target_hp: ProgressBar
var target_note: Label
var target_monster: MonsterEntity

var boss_panel: PanelContainer
var boss_name: Label
var boss_bar: ProgressBar

var companion_panel: PanelContainer
var comp_portrait: TextureRect
var comp_name: Label
var comp_ability: Label
var comp_hp: ProgressBar
var comp_skill: Label

var hotbar_panel: PanelContainer
var hotbar_slots: Array[Button] = []
var _hotbar_sig := ""

var mining_wrap: Control
var mining_bar: ProgressBar
var mining_label: Label

var crosshair: Control
var cross_parts: Array[ColorRect] = []

var action_layer: Control
var btn_action: Button
var action_icon: TextureRect
var action_caption: Label
var _action_tex_cache: Dictionary = {}
var _action_kind_current := ""
var btn_jump: Button
var btn_place: Button
var btn_interact: Button
var btn_skill: Button
var btn_dismount: Button
var skill_cd_label: Label

var notif_box: VBoxContainer
var tracker_card: PanelContainer
var tracker_box: VBoxContainer
var tracker_title: Label
var tracker_name: Label
var tracker_step: Label
var tracker_hint: Label
var banner_box: VBoxContainer
var banner_title: Label
var banner_sub: Label
var banner_tween: Tween
var damage_flash: ColorRect
var hint_label: Label

var modal: Control
var modal_card: PanelContainer
var modal_title: Label
var modal_close: Button
var modal_scroll: ScrollContainer
var modal_content: VBoxContainer
var modal_open := false
var modal_kind := ""
var modal_args: Dictionary = {}
var modal_closeable := true
var starter_open := false
var confirm_cb: Callable

var selected_slot := -1
var craft_cat := "All"
var party_tab := "Team"
var party_selected := 0
var storage_selected := 0
var codex_selected := ""
var shop_tab := "Buy"
var shop_npc: Dictionary = {}

var _hud_timer := 0.0
var _target_timer := 0.0
var _prev_target: MonsterEntity
var _hint_left := 14.0
var _touch_blockers: Array[Control] = []
var _touch_debug := 2

func setup(p: CraftPlayer, w: VoxelWorld, m: Node, s: MonsterSpawner) -> void:
	player = p
	world = w
	main = m
	spawner = s
	is_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch-ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.font_boost = 1.5 if is_touch else 1.0
	theme = UITheme.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.ui = self
	player.look_sensitivity = Game.look_sensitivity
	_build_hud()
	_build_modal()
	_connect_signals()
	_refresh_hotbar()
	_show_hint()

func _connect_signals() -> void:
	Game.notify.connect(_on_notify)
	Game.banner.connect(_on_banner)
	Game.evolved.connect(func(species): _on_banner("Evolution!", str(Content.SPECIES.get(species, {}).get("name", ""))))
	Game.inventory_changed.connect(_on_inventory_changed)
	Game.party_changed.connect(_on_party_changed)
	Game.quests_changed.connect(_on_quests_changed)
	Game.story_changed.connect(_on_quests_changed)
	Game.objectives_changed.connect(_on_quests_changed)

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.12
		_update_hud()
	_target_timer -= delta
	if _target_timer <= 0.0:
		_target_timer = 0.12
		_update_target()
	_refresh_hotbar()
	if _hint_left > 0.0:
		_hint_left -= delta
		if _hint_left <= 0.0:
			_create_fade(hint_label)

func _show_hint() -> void:
	if hint_label == null:
		return
	hint_label.visible = true
	hint_label.modulate.a = 0.9
	if is_touch:
		if Game.left_handed:
			hint_label.text = "Move: joystick on the right • Look: drag left
Mine: hold MINE • Jump: JUMP"
		else:
			hint_label.text = "Move: joystick on the left • Look: drag right
Mine: hold MINE • Jump: JUMP"
	else:
		hint_label.text = "WASD: move • Mouse: look • LMB: mine/attack • E: bag • C: craft • F: use • R: skill • Esc: pause"
	_hint_left = 14.0

# ------------------------------------------------------------------ HUD

func _pin(node: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
	node.anchor_left = al
	node.anchor_top = at
	node.anchor_right = ar
	node.anchor_bottom = ab
	node.offset_left = ol
	node.offset_top = ot
	node.offset_right = orr
	node.offset_bottom = ob

func _build_hud() -> void:
	touch_area = Control.new()
	add_child(touch_area)
	touch_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hud = Control.new()
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(UITheme.make_vignette(0.34))
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_stats()
	_build_quest_tracker()
	_build_clock()
	_build_menu_buttons()
	_build_minimap()
	_build_companion()
	_build_target_panel()
	_build_boss_panel()
	_build_hotbar()
	_build_mining()
	_build_crosshair()
	_build_action_buttons()
	_build_notifications()
	_build_banner()
	_build_hint()

	damage_flash = ColorRect.new()
	damage_flash.color = Color(0.8, 0.12, 0.1, 0.0)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(damage_flash)

	joystick = TouchJoystick.new()
	hud.add_child(joystick)
	joystick.visible = false
	joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if is_touch:
		action_layer.visible = true
	else:
		action_layer.visible = false

func _build_stats() -> void:
	stats_panel = PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", UITheme.glass_style(16, 0.9))
	stats_panel.position = Vector2(16, 14)
	stats_panel.custom_minimum_size = Vector2(352, 0)
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(stats_panel)
	var v := UITheme.make_vbox(stats_panel, 4)
	var top := UITheme.make_hbox(v, 8)
	level_label = UITheme.make_heading(top, "LV 1", 17, UITheme.AMBER)
	hero_label = UITheme.make_label(top, "ADVENTURER", 11, UITheme.MUTED)
	hero_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallet_label = UITheme.make_label(top, "AMBER 15", 12, UITheme.AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	var hp_row := UITheme.make_hbox(v, 6)
	UITheme.make_label(hp_row, "HP", 11, UITheme.MUTED)
	hp_bar = UITheme.make_bar(hp_row, 0, 14, UITheme.GREEN)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_text = UITheme.make_label(hp_row, "100/100", 11, UITheme.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	hp_text.custom_minimum_size = Vector2(88, 0)
	var st_row := UITheme.make_hbox(v, 6)
	UITheme.make_label(st_row, "ST", 11, UITheme.MUTED)
	stamina_bar = UITheme.make_bar(st_row, 0, 9, UITheme.AMBER)
	stamina_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamina_text = UITheme.make_label(st_row, "100", 10, UITheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	stamina_text.custom_minimum_size = Vector2(52, 0)
	xp_bar = UITheme.make_bar(v, 0, 5, UITheme.TEAL)

func _build_clock() -> void:
	clock_panel = PanelContainer.new()
	clock_panel.add_theme_stylebox_override("panel", UITheme.glass_style(16, 0.82))
	clock_panel.custom_minimum_size = Vector2(280, 0)
	clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_panel.anchor_left = 0.5
	clock_panel.anchor_right = 0.5
	clock_panel.offset_left = -140
	clock_panel.offset_right = 140
	clock_panel.offset_top = 12
	clock_panel.offset_bottom = 112
	hud.add_child(clock_panel)
	var v := UITheme.make_vbox(clock_panel, 0)
	clock_time = UITheme.make_heading(v, "DAY 1 • 08:00", 15, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	clock_info = UITheme.make_label(v, "Clear • Emerald Vale", 12, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	rift_label = UITheme.make_label(v, "", 12, Color("#d9a6ff"), HORIZONTAL_ALIGNMENT_CENTER)
	rift_label.visible = false

func _build_menu_buttons() -> void:
	menu_bar = PanelContainer.new()
	menu_bar.add_theme_stylebox_override("panel", UITheme.glass_style(18, 0.78))
	menu_bar.anchor_left = 1
	menu_bar.anchor_right = 1
	menu_bar.offset_left = -484
	menu_bar.offset_right = -16
	menu_bar.offset_top = 14
	menu_bar.offset_bottom = 76
	menu_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(menu_bar)
	var row := UITheme.make_hbox(menu_bar, 4)
	row.alignment = BoxContainer.ALIGNMENT_END
	var defs := [
		["BAG", "bag", open_inventory], ["CRAFT", "craft", open_crafting],
		["TEAM", "team", open_party], ["CODEX", "codex", open_codex],
		["QUEST", "quest", open_quests], ["MAP", "map", open_map],
		["PAUSE", "pause", open_pause],
	]
	for d in defs:
		var b := _menu_icon_button(row, str(d[0]), str(d[1]), d[2])
		_touch_blockers.append(b)

func _menu_icon_button(parent: Node, caption: String, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(60, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := UITheme.style(Color(0.03, 0.09, 0.09, 0.62), Color(0.38, 0.58, 0.52, 0.38), 14, 1, 2)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.09, 0.22, 0.2, 0.92)
	hover.border_color = UITheme.AMBER
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.02, 0.06, 0.06, 0.95)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(PixelArt.ui_icon(kind, Color("#efe8d0")))
	tr.custom_minimum_size = Vector2(26, 26)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tr)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_override("font", UITheme.title_font())
	cap.add_theme_font_size_override("font_size", int(maxf(9.0, 9.5 * UITheme.font_boost)))
	cap.add_theme_color_override("font_color", UITheme.INK)
	cap.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.05, 0.9))
	cap.add_theme_constant_override("outline_size", 2)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(cap)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _build_minimap() -> void:
	minimap = MinimapView.new()
	minimap.world = world
	minimap.player = player
	minimap.main = main
	minimap.position = Vector2(16, 196)
	minimap.size = Vector2(158, 158)
	minimap.custom_minimum_size = Vector2(158, 158)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(minimap)

func _build_companion() -> void:
	companion_panel = PanelContainer.new()
	companion_panel.add_theme_stylebox_override("panel", UITheme.glass_style(14, 0.8))
	companion_panel.position = Vector2(16, 366)
	companion_panel.custom_minimum_size = Vector2(272, 0)
	companion_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(companion_panel)
	var row := UITheme.make_hbox(companion_panel, 8)
	comp_portrait = TextureRect.new()
	comp_portrait.custom_minimum_size = Vector2(44, 44)
	comp_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	comp_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	comp_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	comp_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(comp_portrait)
	var v := UITheme.make_vbox(row, 2)
	var top := UITheme.make_hbox(v, 6)
	comp_name = UITheme.make_label(top, "", 13, UITheme.INK)
	comp_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comp_skill = UITheme.make_label(top, "", 8, UITheme.AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	comp_skill.custom_minimum_size = Vector2(48, 0)
	comp_ability = UITheme.make_label(v, "", 8, UITheme.MUTED)
	comp_hp = UITheme.make_bar(v, 0, 5, UITheme.GREEN)
	companion_panel.visible = false

func _build_target_panel() -> void:
	target_panel = PanelContainer.new()
	target_panel.add_theme_stylebox_override("panel", UITheme.glass_style(14, 0.84))
	target_panel.anchor_left = 0.5
	target_panel.anchor_right = 0.5
	target_panel.offset_left = -164
	target_panel.offset_right = 164
	target_panel.offset_top = 116
	target_panel.offset_bottom = 180
	target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(target_panel)
	var row := UITheme.make_hbox(target_panel, 7)
	target_portrait = TextureRect.new()
	target_portrait.custom_minimum_size = Vector2(40, 40)
	target_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	target_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	target_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(target_portrait)
	var v := UITheme.make_vbox(row, 2)
	var top := UITheme.make_hbox(v, 6)
	target_name = UITheme.make_heading(top, "", 13, UITheme.INK)
	target_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_name.clip_text = true
	target_sub = UITheme.make_label(top, "", 8, UITheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	target_sub.custom_minimum_size = Vector2(78, 0)
	target_hp = UITheme.make_bar(v, 0, 6, UITheme.RED)
	target_note = UITheme.make_label(v, "", 8, UITheme.MUTED)
	target_note.clip_text = true
	target_panel.visible = false

func _build_boss_panel() -> void:
	boss_panel = PanelContainer.new()
	boss_panel.add_theme_stylebox_override("panel", UITheme.glass_style(14, 0.88))
	boss_panel.anchor_left = 0.5
	boss_panel.anchor_right = 0.5
	boss_panel.offset_left = -230
	boss_panel.offset_right = 230
	boss_panel.offset_top = 116
	boss_panel.offset_bottom = 168
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(boss_panel)
	var v := UITheme.make_vbox(boss_panel, 1)
	boss_name = UITheme.make_heading(v, "BOSS", 12, Color("#ffd2a1"), HORIZONTAL_ALIGNMENT_CENTER)
	boss_bar = UITheme.make_bar(v, 0, 8, Color("#d26d5f"))
	boss_panel.visible = false

func _build_hotbar() -> void:
	hotbar_panel = PanelContainer.new()
	hotbar_panel.add_theme_stylebox_override("panel", UITheme.glass_style(16, 0.85))
	hotbar_panel.anchor_left = 0.5
	hotbar_panel.anchor_right = 0.5
	hotbar_panel.anchor_top = 1
	hotbar_panel.anchor_bottom = 1
	hotbar_panel.offset_left = -302
	hotbar_panel.offset_right = 302
	hotbar_panel.offset_top = -94
	hotbar_panel.offset_bottom = -16
	hotbar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hotbar_panel)
	var row := UITheme.make_hbox(hotbar_panel, 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 9:
		var b := UITheme.make_slot(row, 56)
		b.name = "Hotbar%d" % i
		b.pressed.connect(_select_hotbar.bind(i))
		_touch_blockers.append(b)
		var lbl := Label.new()
		lbl.name = "Count"
		lbl.add_theme_font_override("font", UITheme.body_font())
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", UITheme.INK)
		lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.05, 0.95))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.anchor_left = 1
		lbl.anchor_top = 1
		lbl.anchor_right = 1
		lbl.anchor_bottom = 1
		lbl.offset_left = -30
		lbl.offset_top = -22
		lbl.offset_right = -4
		lbl.offset_bottom = -2
		b.add_child(lbl)
		var num := Label.new()
		num.text = str(i + 1)
		num.add_theme_font_override("font", UITheme.title_font())
		num.add_theme_font_size_override("font_size", int(15 * UITheme.font_boost))
		num.add_theme_color_override("font_color", Color(0.9, 0.95, 0.88, 0.55))
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num.position = Vector2(4, 2)
		b.add_child(num)
		hotbar_slots.append(b)

func _build_mining() -> void:
	mining_wrap = Control.new()
	mining_wrap.anchor_left = 0.5
	mining_wrap.anchor_right = 0.5
	mining_wrap.anchor_top = 1
	mining_wrap.anchor_bottom = 1
	mining_wrap.offset_left = -190
	mining_wrap.offset_right = 190
	mining_wrap.offset_top = -155
	mining_wrap.offset_bottom = -105
	mining_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(mining_wrap)
	mining_label = UITheme.make_label(mining_wrap, "", 13, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	mining_label.position = Vector2(0, 0)
	mining_label.size = Vector2(380, 24)
	mining_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.05, 0.95))
	mining_label.add_theme_constant_override("outline_size", 4)
	mining_bar = UITheme.make_bar(mining_wrap, 270, 12, UITheme.AMBER)
	mining_bar.position = Vector2(55, 32)
	mining_wrap.visible = false

func _build_crosshair() -> void:
	crosshair = Control.new()
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -16
	crosshair.offset_right = 16
	crosshair.offset_top = -16
	crosshair.offset_bottom = 16
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair)
	for spec in [[Vector2(15, 5), Vector2(2, 6)], [Vector2(15, 21), Vector2(2, 6)],
			[Vector2(5, 15), Vector2(6, 2)], [Vector2(21, 15), Vector2(6, 2)]]:
		var c := ColorRect.new()
		c.color = Color(0.95, 0.99, 0.9, 0.85)
		c.position = spec[0]
		c.size = spec[1]
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(c)
		cross_parts.append(c)
	var dot := ColorRect.new()
	dot.color = Color(1, 0.86, 0.48, 0.9)
	dot.position = Vector2(14, 14)
	dot.size = Vector2(4, 4)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(dot)
	crosshair.pivot_offset = Vector2(16, 16)
	var pulse := create_tween().set_loops()
	pulse.tween_property(crosshair, "scale", Vector2(1.07, 1.07), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(crosshair, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

func _build_action_buttons() -> void:
	action_layer = Control.new()
	add_child(action_layer)
	action_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	action_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_action = _action_button("MINE", 110, true)
	_touch_blockers.append(btn_action)
	_pin(btn_action, 1, 1, 1, 1, -142, -142, -28, -28)
	btn_action.button_down.connect(func(): if player != null: player.primary_pressed())
	btn_action.button_up.connect(func(): if player != null: player.primary_released())
	btn_jump = _action_button("JUMP", 64, false)
	_touch_blockers.append(btn_jump)
	_pin(btn_jump, 1, 1, 1, 1, -232, -108, -162, -38)
	btn_jump.button_down.connect(_jump_down)
	btn_jump.button_up.connect(_jump_up)
	btn_place = _action_button("PLACE", 64, false)
	_touch_blockers.append(btn_place)
	_pin(btn_place, 1, 1, 1, 1, -166, -232, -96, -162)
	btn_place.pressed.connect(func(): if player != null: player.place_selected())
	btn_interact = _action_button("USE", 64, false)
	_touch_blockers.append(btn_interact)
	_pin(btn_interact, 1, 1, 1, 1, -260, -222, -190, -152)
	btn_interact.pressed.connect(func(): if player != null: player.interact_now())
	btn_skill = _action_button("SKILL", 64, false)
	_touch_blockers.append(btn_skill)
	_pin(btn_skill, 1, 1, 1, 1, -350, -136, -280, -66)
	btn_skill.pressed.connect(_use_skill)
	skill_cd_label = Label.new()
	skill_cd_label.add_theme_font_override("font", UITheme.title_font())
	skill_cd_label.add_theme_font_size_override("font_size", 18)
	skill_cd_label.add_theme_color_override("font_color", UITheme.AMBER)
	skill_cd_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.05))
	skill_cd_label.add_theme_constant_override("outline_size", 4)
	skill_cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_cd_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn_skill.add_child(skill_cd_label)
	btn_dismount = _action_button("DISMOUNT", 64, false)
	_touch_blockers.append(btn_dismount)
	_pin(btn_dismount, 1, 1, 1, 1, -166, -320, -96, -250)
	btn_dismount.pressed.connect(_dismount)
	btn_dismount.visible = false
	action_layer.visible = false

func _action_button(text: String, size: int, primary: bool) -> Button:
	var b := Button.new()
	b.text = ""
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UITheme.title_font())
	b.add_theme_font_size_override("font_size", 17 if primary else 14)
	b.add_theme_color_override("font_color", Color("#1b1308") if primary else UITheme.INK)
	b.add_theme_color_override("font_pressed_color", Color("#0d0903") if primary else UITheme.AMBER)
	var base := UITheme.style(Color("#e5b152") if primary else Color(0.035, 0.11, 0.105, 0.8),
		Color("#ffe8b0") if primary else Color(0.42, 0.66, 0.6, 0.65), size / 2, 2 if primary else 1, 4)
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#f2c263") if primary else Color(0.08, 0.2, 0.19, 0.92)
	hover.border_color = Color("#fff3c9") if primary else UITheme.AMBER
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#c89038") if primary else Color(0.02, 0.07, 0.07, 0.95)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", UITheme.style(Color(0.05, 0.1, 0.1, 0.5), Color(0.2, 0.3, 0.28, 0.4), size / 2, 1, 4))
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var icon_kind: String = {"MINE": "mine", "JUMP": "jump", "PLACE": "place",
		"USE": "use", "SKILL": "skill", "DISMOUNT": "dismount"}.get(text, "")
	if icon_kind != "":
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", -1)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(box)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(PixelArt.ui_icon(icon_kind,
			Color("#1b1308") if primary else Color("#eff7e4")))
		tr.custom_minimum_size = Vector2(46 if primary else 28, 46 if primary else 28)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
		var cap := Label.new()
		cap.text = text
		cap.add_theme_font_override("font", UITheme.title_font())
		cap.add_theme_font_size_override("font_size", 15 if primary else 11)
		cap.add_theme_color_override("font_color", Color("#1b1308") if primary else UITheme.INK)
		cap.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.05, 0.8))
		cap.add_theme_constant_override("outline_size", 2 if not primary else 0)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(cap)
		if text == "MINE":
			action_icon = tr
			action_caption = cap
	action_layer.add_child(b)
	return b

func _build_notifications() -> void:
	notif_box = VBoxContainer.new()
	notif_box.anchor_left = 1
	notif_box.anchor_right = 1
	notif_box.add_theme_constant_override("separation", 6)
	notif_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_touch:
		notif_box.anchor_top = 0
		notif_box.anchor_bottom = 0
		notif_box.offset_left = -330
		notif_box.offset_right = -16
		notif_box.offset_top = 200
		notif_box.offset_bottom = 520
		notif_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	else:
		notif_box.anchor_top = 1
		notif_box.anchor_bottom = 1
		notif_box.offset_left = -330
		notif_box.offset_right = -16
		notif_box.offset_top = -322
		notif_box.offset_bottom = -108
		notif_box.alignment = BoxContainer.ALIGNMENT_END
	hud.add_child(notif_box)
func _build_banner() -> void:
	banner_box = VBoxContainer.new()
	banner_box.anchor_left = 0.5
	banner_box.anchor_right = 0.5
	banner_box.offset_left = -360
	banner_box.offset_right = 360
	banner_box.offset_top = 204
	banner_box.offset_bottom = 320
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(banner_box)
	banner_title = UITheme.make_heading(banner_box, "", 34, UITheme.AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	banner_sub = UITheme.make_label(banner_box, "", 15, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	banner_box.modulate.a = 0.0

func _build_hint() -> void:
	hint_label = UITheme.make_label(hud, "", 11, Color(0.9, 0.94, 0.85, 0.9))
	hint_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.05, 0.95))
	hint_label.add_theme_constant_override("outline_size", 5)
	hint_label.anchor_top = 1
	hint_label.anchor_bottom = 1
	hint_label.offset_left = 18
	hint_label.offset_top = -196
	hint_label.offset_right = 470
	hint_label.offset_bottom = -100
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# ------------------------------------------------------------------ HUD updates

func _update_hud() -> void:
	_update_quest_tracker()
	if player == null or Game == null or not Game.in_game:
		return
	hp_bar.max_value = Game.max_hp
	hp_bar.value = Game.hp
	hp_text.text = "%d/%d" % [Game.hp, Game.max_hp]
	stamina_bar.max_value = Game.max_stamina
	stamina_bar.value = Game.stamina
	stamina_text.text = "%d" % int(Game.stamina)
	xp_bar.max_value = Game.xp_to_next()
	xp_bar.value = Game.xp
	level_label.text = "LV %d" % Game.level
	wallet_label.text = "AMBER %d" % Game.wallet
	clock_time.text = "DAY %d • %s" % [Game.day, Game.time_string()]
	var biome := world.biome_at_pos(player.global_position)
	var bname: String = Content.BIOMES.get(biome, {}).get("name", "Wild")
	var weather := "Clear"
	if Game.weather == "rain":
		weather = "Rain"
	elif Game.weather == "storm":
		weather = "Storm"
	var extra := ""
	if main != null and main.get("tracked_waypoint") != null and main.tracked_waypoint != Vector3.ZERO:
		var dist := player.global_position.distance_to(main.tracked_waypoint)
		extra = " • Route %dm" % int(dist)
	clock_info.text = "%s • %s%s" % [weather, bname, extra]
	if Game.event_name != "":
		rift_label.visible = true
		rift_label.text = "Event: " + _event_name(Game.event_name)
	else:
		rift_label.visible = false
	mining_wrap.visible = player.mining_valid and player.mining_progress > 0.01
	if mining_wrap.visible:
		mining_bar.value = player.mining_progress * 100.0
		var bd: Dictionary = Content.BLOCKS.get(player.mining_block, {})
		mining_label.text = "Mining %s" % bd.get("name", "")
	# companion display
	var c := spawner.get_companion() if spawner != null else null
	if c != null and not c.dead:
		companion_panel.visible = true
		comp_name.text = "%s  Lv%d" % [c.display_name, c.level]
		comp_ability.text = "%s • %s" % [Content.element_name(str(c.sp.get("element", ""))),
			Content.ability_name(str(c.sp.get("ability", "")))]
		comp_hp.max_value = c.max_hp
		comp_hp.value = c.hp
		comp_portrait.texture = Content.get_monster_portrait(c.species_id)
		if c.skill_cd > 0.0:
			comp_skill.text = "%ds" % int(ceil(c.skill_cd))
			comp_skill.add_theme_color_override("font_color", UITheme.MUTED)
		else:
			comp_skill.text = "READY"
			comp_skill.add_theme_color_override("font_color", UITheme.AMBER)
		if is_touch:
			btn_skill.visible = true
			btn_skill.disabled = c.skill_cd > 0.0
			skill_cd_label.text = "" if c.skill_cd <= 0.0 else "%ds" % int(ceil(c.skill_cd))
		btn_dismount.visible = player.riding_monster != null
	else:
		companion_panel.visible = false
		btn_dismount.visible = player.riding_monster != null
		if is_touch:
			btn_skill.disabled = true
			skill_cd_label.text = ""
	# action button label
	var item := Game.get_hotbar_item()
	var itype: String = str(Content.ITEMS.get(str(item.get("id", "")), {}).get("type", ""))
	var atext := "MINE"
	var akind := "mine"
	if itype == "orb":
		atext = "THROW"
		akind = "throw"
	elif itype == "food":
		atext = "EAT"
		akind = "eat"
	elif itype == "tool" and str(Content.ITEMS[item.id].get("tool_kind", "")) == "hoe":
		atext = "TILL"
		akind = "till"
	elif str(item.get("id", "")) == "seeds":
		atext = "PLANT"
		akind = "plant"
	_set_action_label(akind, atext)
	btn_dismount.visible = player.riding_monster != null

func _set_action_label(kind: String, text: String) -> void:
	if action_caption != null and action_caption.text != text:
		action_caption.text = text
	if action_icon == null or kind == _action_kind_current:
		return
	_action_kind_current = kind
	if not _action_tex_cache.has(kind):
		_action_tex_cache[kind] = ImageTexture.create_from_image(PixelArt.ui_icon(kind, Color("#1b1308")))
	action_icon.texture = _action_tex_cache[kind]

func _weather_name() -> String:
	match Game.weather:
		"rain": return "Rain"
		"storm": return "Storm"
	return "Clear"

func _event_name(kind: String) -> String:
	match kind:
		"golden": return "Golden Hour"
		"horde": return "Night Migration"
		"migration": return "Monster Migration"
	return kind

func _update_target() -> void:
	if modal_open or player == null or main == null:
		_hide_target()
		return
	var target: MonsterEntity = main.get_target_monster()
	if target != null and (not is_instance_valid(target) or target.dead):
		target = null
	if target != _prev_target:
		if _prev_target != null and is_instance_valid(_prev_target):
			_prev_target.set_focused(false)
		_prev_target = target
		if target != null:
			target.set_focused(true)
	target_monster = target
	if target == null:
		_hide_target()
		return
	target_panel.visible = true
	if boss_panel.visible:
		if target_panel.offset_top != 176:
			target_panel.offset_top = 176
			target_panel.offset_bottom = 240
	else:
		if target_panel.offset_top != 124:
			target_panel.offset_top = 124
			target_panel.offset_bottom = 188
	target_name.text = target.display_name
	target_sub.text = "Lv%d • %s" % [target.level, Content.element_name(str(target.sp.get("element", "")))]
	target_sub.add_theme_color_override("font_color", Content.element_color(str(target.sp.get("element", ""))))
	target_portrait.texture = Content.get_monster_portrait(target.species_id)
	target_hp.max_value = target.max_hp
	target_hp.value = target.hp
	var ratio := clampf(float(target.hp) / maxf(1.0, float(target.max_hp)), 0.0, 1.0)
	var hp_col := UITheme.GREEN if ratio > 0.55 else (UITheme.AMBER if ratio > 0.25 else UITheme.RED)
	target_hp.add_theme_stylebox_override("fill", UITheme.style(hp_col, hp_col.lightened(0.2), 4, 0, 0))
	var hint := ""
	if target.is_capturable():
		hint = "Weakened — throw a Capture Orb."
		target_note.add_theme_color_override("font_color", UITheme.GREEN)
	elif int(target.sp.get("stage", 1)) >= 2:
		hint = "Evolved — weaken it to capture."
		target_note.add_theme_color_override("font_color", UITheme.AMBER)
	elif bool(target.sp.get("aggro", false)):
		hint = "Aggressive — ready your weapon."
		target_note.add_theme_color_override("font_color", UITheme.RED)
	else:
		hint = "Passive — offer Feed to tame."
		target_note.add_theme_color_override("font_color", UITheme.MUTED)
	target_note.text = hint
	for c in cross_parts:
		c.color = UITheme.AMBER if not target.is_capturable() else UITheme.GREEN

func _hide_target() -> void:
	if target_monster != null:
		if is_instance_valid(target_monster):
			target_monster.set_focused(false)
		target_monster = null
		_prev_target = null
	target_panel.visible = false
	for c in cross_parts:
		c.color = Color(0.95, 0.99, 0.9, 0.85)

func _refresh_hotbar() -> void:
	var sig := ""
	for i in 36:
		var s = Game.inventory[i] if i < Game.inventory.size() else null
		sig += "%s:%s:%s;" % [Game.selected_hotbar, s.get("id", "-") if s is Dictionary else "-", s.get("n", 0) if s is Dictionary else 0]
	if sig == _hotbar_sig:
		return
	_hotbar_sig = sig
	for i in hotbar_slots.size():
		var b := hotbar_slots[i]
		var s = Game.inventory[i] if i < Game.inventory.size() else null
		if s is Dictionary:
			b.icon = Content.get_icon(str(s.id))
			var lbl := b.get_node_or_null("Count") as Label
			if lbl != null:
				lbl.text = str(s.n) if int(s.n) > 1 else ""
		else:
			b.icon = null
			var lbl2 := b.get_node_or_null("Count") as Label
			if lbl2 != null:
				lbl2.text = ""
		if i == Game.selected_hotbar:
			b.add_theme_stylebox_override("normal", UITheme.style(Color(0.16, 0.24, 0.16, 0.95), UITheme.AMBER, 10, 2, 4))
			b.add_theme_stylebox_override("hover", UITheme.style(Color(0.2, 0.29, 0.19, 0.98), UITheme.AMBER, 10, 2, 4))
		else:
			b.add_theme_stylebox_override("normal", UITheme.button_style("slot"))
			var h := UITheme.style(Color(0.08, 0.2, 0.18, 0.95), UITheme.AMBER_DIM, 10, 1, 4)
			b.add_theme_stylebox_override("hover", h)

# ------------------------------------------------------------------ touch / actions

func _input(event: InputEvent) -> void:
	if not is_touch or player == null or modal_open or starter_open or not Game.in_game:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_over_blocker(event.position):
				return
			var joy_side: bool = (event.position.x < size.x * 0.5) != Game.left_handed
			if joy_side:
				if joy_idx == -1:
					joy_idx = event.index
					joystick.show_at(event.position, event.index)
					player.touch_move = Vector2.ZERO
			else:
				look_idx = event.index
		else:
			if event.index == joy_idx:
				joy_idx = -1
				joystick.release()
				player.touch_move = Vector2.ZERO
			if event.index == look_idx:
				look_idx = -1
	elif event is InputEventScreenDrag:
		if event.index == joy_idx:
			joystick.update_at(event.position)
			player.touch_move = joystick.value
		elif event.index == look_idx:
			player.add_look(event.relative)

func _is_over_blocker(pos: Vector2) -> bool:
	for b in _touch_blockers:
		if b != null and is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			return true
	return false

func _on_touch_input(_event: InputEvent) -> void:
	pass

func _jump_down() -> void:
	if player == null:
		return
	player.jump_held = true
	player.request_jump()

func _jump_up() -> void:
	if player == null:
		return
	player.jump_held = false

func _use_skill() -> void:
	if spawner != null:
		spawner.use_skill()

func _dismount() -> void:
	if spawner != null:
		spawner.dismount()

func _select_hotbar(i: int) -> void:
	Game.selected_hotbar = i
	Sfx.play("ui")
	_refresh_hotbar()

func _unhandled_input(event: InputEvent) -> void:
	if not Game.in_game or player == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if modal_open:
				if modal_closeable and not starter_open:
					_close_modal()
			else:
				open_pause()
			get_viewport().set_input_as_handled()
			return
		if modal_open:
			return
		match event.keycode:
			KEY_E: open_inventory()
			KEY_C: open_crafting()
			KEY_P: open_party()
			KEY_K: open_codex()
			KEY_J: open_quests()
			KEY_M: open_map()
			KEY_F: player.interact_now()
			KEY_R: player.request_skill()

func handle_back_pressed() -> bool:
	if starter_open:
		return true
	if modal_open:
		if modal_closeable:
			_close_modal()
		return true
	open_pause()
	return true

func show_starter_choice() -> void:
	starter_open = true
	_open_modal("starter", "Choose Your First Partner", {}, false, true)
	get_tree().paused = true

func show_boss(name: String, hp: int, maxhp: int) -> void:
	boss_panel.visible = true
	boss_name.text = name
	boss_bar.max_value = maxhp
	boss_bar.value = hp
	if target_panel.visible:
		target_panel.offset_top = 176
		target_panel.offset_bottom = 240

func update_boss(hp: int, maxhp: int) -> void:
	if not boss_panel.visible:
		return
	boss_bar.max_value = maxhp
	boss_bar.value = hp

func hide_boss() -> void:
	boss_panel.visible = false
	if target_panel.visible:
		target_panel.offset_top = 124
		target_panel.offset_bottom = 188

func on_rift_state(wave: int, remaining: int) -> void:
	if wave <= 0:
		rift_label.visible = false
		return
	rift_label.visible = true
	rift_label.text = "RIFT • Wave %d/5 • %d enemies" % [wave, remaining]

func flash_hurt() -> void:
	if damage_flash == null:
		return
	damage_flash.color.a = 0.2
	var tw := create_tween()
	tw.tween_property(damage_flash, "color:a", 0.0, 0.4)

func toast(text: String, color: Color = UITheme.INK) -> void:
	if notif_box == null:
		return
	if notif_box.get_child_count() >= 5:
		var old := notif_box.get_child(0)
		notif_box.remove_child(old)
		old.queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.style(Color(0.03, 0.09, 0.085, 0.92),
		Color(color.r, color.g, color.b, 0.5), 10, 1, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.make_label(p, text, 12, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notif_box.add_child(p)
	p.modulate.a = 0.0
	p.pivot_offset = Vector2(0, 24)
	p.scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): if is_instance_valid(p): p.queue_free())

func _on_notify(text: String, color: Color) -> void:
	toast(text, color)

func _on_banner(title: String, subtitle: String) -> void:
	if banner_box == null:
		return
	banner_title.text = title
	banner_sub.text = subtitle
	if banner_tween != null:
		banner_tween.kill()
	banner_box.modulate.a = 0.0
	banner_box.position.y = 10
	banner_tween = create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(banner_box, "modulate:a", 1.0, 0.25)
	banner_tween.tween_property(banner_box, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BACK)
	banner_tween.chain().tween_interval(2.6)
	banner_tween.chain().tween_property(banner_box, "modulate:a", 0.0, 0.5)

func _on_inventory_changed() -> void:
	_hotbar_sig = ""
	if modal_open and modal_kind in ["inventory", "chest"]:
		pass

func _on_party_changed() -> void:
	# HUD polls live; open panels refresh only after explicit actions.
	pass

func _on_quests_changed() -> void:
	_update_quest_tracker()
	pass

func _create_fade(node: CanvasItem) -> void:
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func(): node.visible = false)

# ------------------------------------------------------------------ modal shell

func _build_modal() -> void:
	modal = Control.new()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.03, 0.03, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and modal_closeable and not starter_open:
			_close_modal())
	modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)
	modal_card = PanelContainer.new()
	modal_card.add_theme_stylebox_override("panel", UITheme.panel_style(20))
	modal_card.custom_minimum_size = Vector2(1080, 620)
	modal_card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(modal_card)
	var v := UITheme.make_vbox(modal_card, 8)
	var header := UITheme.make_hbox(v, 8)
	var title_wrap := UITheme.make_vbox(header, 0)
	title_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_title = UITheme.make_heading(title_wrap, "", 26, UITheme.INK)
	var accent := ColorRect.new()
	accent.color = UITheme.AMBER
	accent.custom_minimum_size = Vector2(54, 3)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_wrap.add_child(accent)
	UITheme.make_label(title_wrap, "MONSTERCRAFT • VOXEL ADVENTURE", 9, UITheme.MUTED)
	modal_close = UITheme.make_round_button(header, "X", 54, 16)
	modal_close.pressed.connect(_close_modal)
	modal_scroll = UITheme.make_scroll(v)
	modal_content = UITheme.make_vbox(modal_scroll, 10)
	modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_content.custom_minimum_size = Vector2(1000, 0)

func _open_modal(kind: String, title: String, args: Dictionary = {}, closeable: bool = true,
		full_starter: bool = false) -> void:
	if starter_open and kind != "starter":
		return
	modal_kind = kind
	modal_args = args
	modal_closeable = closeable
	modal_open = true
	modal_title.text = title
	modal_close.visible = closeable
	modal.visible = true
	modal_card.visible = true
	if not full_starter:
		modal_card.custom_minimum_size = Vector2(minf(1080.0, size.x - 56.0), minf(620.0, size.y - 48.0))
	else:
		modal_card.custom_minimum_size = Vector2(minf(1160.0, size.x - 40.0), minf(620.0, size.y - 40.0))
	get_tree().paused = true
	if player != null:
		player.input_enabled = false
		player.primary_released()
		player.touch_move = Vector2.ZERO
	if joystick != null:
		joystick.release()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_modal_content()
	_animate_modal_open()

func _animate_modal_open() -> void:
	if modal_card == null:
		return
	modal.modulate.a = 0.0
	modal_card.pivot_offset = modal_card.custom_minimum_size * 0.5
	modal_card.scale = Vector2(0.955, 0.955)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(modal, "modulate:a", 1.0, 0.16)
	tw.tween_property(modal_card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _close_modal() -> void:
	if starter_open:
		return
	if not modal_open:
		return
	modal.visible = false
	modal_open = false
	modal_kind = ""
	modal_args = {}
	get_tree().paused = false
	if player != null:
		player.input_enabled = true
	if not is_touch and player != null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hide_target()

func _refresh_modal() -> void:
	if modal_open:
		_build_modal_content()

func _build_modal_content() -> void:
	UITheme.clear(modal_content)
	match modal_kind:
		"inventory": _build_inventory()
		"crafting": _build_crafting()
		"party": _build_party()
		"codex": _build_codex()
		"codex_detail": _build_codex_detail()
		"quests": _build_quests()
		"map": _build_map()
		"chest": _build_chest()
		"npc": _build_npc()
		"shop": _build_shop()
		"pause": _build_pause()
		"settings": _build_settings()
		"guide": _build_guide()
		"confirm": _build_confirm()
		"starter": _build_starter()
		_: UITheme.make_label(modal_content, "This panel is not available yet.", 18, UITheme.MUTED)

func open_inventory() -> void:
	if Game.in_game:
		selected_slot = -1
		_open_modal("inventory", "Bag & Equipment")

func open_crafting() -> void:
	if Game.in_game:
		_open_modal("crafting", "Crafting")

func open_party() -> void:
	if Game.in_game:
		party_tab = "Team"
		party_selected = clampi(party_selected, 0, maxi(Game.party.size() - 1, 0))
		_open_modal("party", "Monster & Ranch")

func open_ranch() -> void:
	if Game.in_game:
		party_tab = "Ranch"
		_open_modal("party", "Monster & Ranch")

func open_codex() -> void:
	if Game.in_game:
		codex_selected = ""
		_open_modal("codex", "Monster Codex")

func open_quests() -> void:
	if Game.in_game:
		_open_modal("quests", "Quests & Adventure")

func open_map() -> void:
	if Game.in_game:
		_open_modal("map", "World Map")

func open_chest(key: String, tier: int) -> void:
	if Game.in_game:
		_open_modal("chest", "Storage Chest", {"key": key, "tier": tier})

func open_npc(data: Dictionary) -> void:
	if Game.in_game:
		_open_modal("npc", str(data.get("name", "Villager")), {"npc": data})

func open_shop(data: Dictionary) -> void:
	if Game.in_game:
		shop_tab = "Buy"
		shop_npc = data
		_open_modal("shop", "Shop: " + str(data.get("name", "Merchant")), {"npc": data})

func open_pause() -> void:
	if Game.in_game and not starter_open:
		_open_modal("pause", "Paused")

func open_settings() -> void:
	_open_modal("settings", "Settings")

func open_guide() -> void:
	_open_modal("guide", "Quick Guide")

func _open_confirm(title: String, text: String, callback: Callable) -> void:
	confirm_cb = callback
	_open_modal("confirm", title, {"text": text})

# ------------------------------------------------------------------ panels: inventory

func _build_inventory() -> void:
	var top := UITheme.make_hbox(modal_content, 12)
	UITheme.make_heading(top, "Overview", 20, UITheme.INK)
	UITheme.make_label(top, "Level %d • Defense %d • Amber %d" % [Game.level, Game.defense_total(), Game.wallet], 13, UITheme.MUTED)
	var cols := UITheme.make_hbox(modal_content, 18)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := UITheme.make_vbox(cols, 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := UITheme.make_vbox(cols, 8)
	right.custom_minimum_size = Vector2(320, 0)
	# equipment
	UITheme.make_label(left, "EQUIPMENT", 12, UITheme.AMBER)
	var equip := UITheme.make_hbox(left, 8)
	var slots := [["head", "Head"], ["body", "Body"], ["feet", "Feet"]]
	for s in slots:
		var box := UITheme.make_vbox(equip, 2)
		box.custom_minimum_size = Vector2(88, 0)
		box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		UITheme.make_label(box, s[1], 10, UITheme.MUTED)
		var item_id = Game.equipment.get(s[0])
		var b := UITheme.make_slot(box, 52)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if item_id != null and Content.ITEMS.has(str(item_id)):
			b.icon = Content.get_icon(str(item_id))
		b.pressed.connect(_unequip.bind(str(s[0])))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip.add_child(spacer)
	# hotbar
	UITheme.make_label(left, "HOTBAR", 12, UITheme.AMBER)
	var hotgrid := GridContainer.new()
	hotgrid.columns = 9
	hotgrid.add_theme_constant_override("h_separation", 6)
	hotgrid.add_theme_constant_override("v_separation", 6)
	hotgrid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(hotgrid)
	for i in 9:
		_add_inventory_slot(hotgrid, i, 52)
	UITheme.make_label(left, "STORAGE", 12, UITheme.AMBER)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(grid)
	for i in range(9, 36):
		_add_inventory_slot(grid, i, 52)
	# right info
	var card := UITheme.make_card(right)
	var v := UITheme.make_vbox(card, 6)
	var selected: Dictionary = Game.get_slot(selected_slot) if selected_slot >= 0 else {}
	if selected.is_empty():
		UITheme.make_heading(v, "Select an item", 18, UITheme.INK)
		UITheme.make_label(v, "Tap a slot to select it. Tap a second slot to swap items. Armor can be equipped here.", 13, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		var item: Dictionary = Content.ITEMS.get(str(selected.id), {})
		var row := UITheme.make_hbox(v, 10)
		var icon := TextureRect.new()
		icon.texture = Content.get_icon(str(selected.id))
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var info := UITheme.make_vbox(row, 0)
		UITheme.make_heading(info, Content.get_item_name(str(selected.id)), 17, UITheme.INK)
		UITheme.make_label(info, "Quantity %d" % int(selected.n), 12, UITheme.MUTED)
		UITheme.make_label(v, str(item.get("desc", "")), 13, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if item.get("type", "") == "armor":
			UITheme.make_button(v, "Equip Armor", "primary", 44).pressed.connect(_equip_selected)
		elif item.get("type", "") == "food":
			UITheme.make_button(v, "Eat", "primary", 44).pressed.connect(_eat_selected)
		if selected_slot >= 9:
			UITheme.make_button(v, "Move to Active Hotbar Slot", "normal", 44).pressed.connect(_to_hotbar)
		else:
			UITheme.make_button(v, "Set as Active Hotbar Slot", "normal", 44).pressed.connect(_activate_slot)
	UITheme.make_label(v, "Tip: the best tool in your bag is used automatically when mining or attacking.", 11, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _add_inventory_slot(parent: Node, index: int, slot_size: int) -> void:
	var s = Game.inventory[index] if index < Game.inventory.size() else null
	var b := UITheme.make_slot(parent, slot_size)
	if s is Dictionary:
		b.icon = Content.get_icon(str(s.id))
		if int(s.n) > 1:
			var lbl := Label.new()
			lbl.text = str(s.n)
			lbl.add_theme_font_override("font", UITheme.body_font())
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", UITheme.INK)
			lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.05, 0.95))
			lbl.add_theme_constant_override("outline_size", 3)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.anchor_left = 1
			lbl.anchor_top = 1
			lbl.anchor_right = 1
			lbl.anchor_bottom = 1
			lbl.offset_left = -28
			lbl.offset_top = -19
			lbl.offset_right = -3
			lbl.offset_bottom = -1
			b.add_child(lbl)
	if index == selected_slot:
		b.add_theme_stylebox_override("normal", UITheme.style(Color(0.16, 0.24, 0.16, 0.95), UITheme.AMBER, 10, 2, 4))
	b.pressed.connect(_on_inventory_slot.bind(index))

func _on_inventory_slot(index: int) -> void:
	Sfx.play("ui")
	if selected_slot == -1:
		selected_slot = index
		_build_modal_content()
		return
	if selected_slot == index:
		selected_slot = -1
		_build_modal_content()
		return
	_swap_inventory(selected_slot, index)
	selected_slot = -1
	_build_modal_content()

func _swap_inventory(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= Game.inventory.size() or b >= Game.inventory.size():
		return
	var tmp = Game.inventory[a]
	Game.inventory[a] = Game.inventory[b]
	Game.inventory[b] = tmp
	Game.inventory_changed.emit()

func _equip_selected() -> void:
	if selected_slot >= 0 and Game.equip_armor(selected_slot):
		selected_slot = -1
		_build_modal_content()

func _eat_selected() -> void:
	if selected_slot >= 0:
		Game.use_food(selected_slot)
		_build_modal_content()

func _to_hotbar() -> void:
	if selected_slot >= 9:
		_swap_inventory(selected_slot, Game.selected_hotbar)
		selected_slot = -1
		_build_modal_content()

func _activate_slot() -> void:
	if selected_slot >= 0 and selected_slot < 9:
		Game.selected_hotbar = selected_slot
		_hotbar_sig = ""
		_build_modal_content()

func _unequip(slot: String) -> void:
	Game.unequip(slot)
	_build_modal_content()

# ------------------------------------------------------------------ panels: crafting

func _build_crafting() -> void:
	var cats := ["All", "Blocks", "Tools", "Monster", "Misc"]
	var row := UITheme.make_hbox(modal_content, 6)
	for cat in cats:
		var b := UITheme.make_button(row, cat, "primary" if craft_cat == cat else "normal", 40, 14)
		b.pressed.connect(func(): craft_cat = cat; _build_modal_content())
	UITheme.make_label(modal_content, "Ingredients are taken from your bag automatically. No crafting table is required.", 12, UITheme.MUTED)
	var count := 0
	for r in Content.RECIPES:
		if craft_cat != "All" and str(r.get("cat", "")) != craft_cat:
			continue
		count += 1
		_recipe_row(r)
	if count == 0:
		UITheme.make_label(modal_content, "No recipes in this category.", 14, UITheme.MUTED)

func _recipe_row(recipe: Dictionary) -> void:
	var out_id := str(recipe.out)
	var out_item: Dictionary = Content.ITEMS.get(out_id, {})
	var card := UITheme.make_card(modal_content)
	card.custom_minimum_size = Vector2(0, 70)
	var row := UITheme.make_hbox(card, 12)
	var icon := TextureRect.new()
	icon.texture = Content.get_icon(out_id)
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var info := UITheme.make_vbox(row, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.make_label(info, "%s%s" % [out_item.get("name", out_id), (" x%d" % int(recipe.n)) if int(recipe.n) > 1 else ""], 15, UITheme.INK)
	var need: Dictionary = recipe.need
	var parts: Array = []
	for id in need:
		var have := Game.count_item(str(id))
		parts.append("%s %d/%d" % [Content.get_item_name(str(id)), have, int(need[id])])
	var can := Game.has_items(need)
	var need_label := UITheme.make_label(info, "  •  ".join(parts), 11, UITheme.GREEN if can else UITheme.RED)
	var btn := UITheme.make_button(row, "Craft", "primary" if can else "ghost", 42, 13)
	btn.disabled = not can
	btn.custom_minimum_size = Vector2(92, 42)
	btn.pressed.connect(func():
		if Game.try_craft(recipe):
			Sfx.play("craft")
			Game.notify.emit("Crafted %s." % out_item.get("name", out_id), UITheme.GREEN)
			_hotbar_sig = ""
			_build_modal_content())

# ------------------------------------------------------------------ remaining panels (expanded below)

func _build_party() -> void:
	var tabs := [["Team", "Team"], ["Storage", "Storage"], ["Ranch", "Ranch"]]
	var row := UITheme.make_hbox(modal_content, 6)
	for t in tabs:
		var b := UITheme.make_button(row, t[0], "primary" if party_tab == t[1] else "normal", 40, 14)
		b.pressed.connect(func(): party_tab = t[1]; _build_modal_content())
	UITheme.make_label(modal_content, "Your team can hold up to 6 monsters. One partner fights at your side; the rest can work at the ranch.", 12, UITheme.MUTED)
	match party_tab:
		"Storage": _build_storage()
		"Ranch": _build_ranch()
		_: _build_team()

func _build_team() -> void:
	if Game.party.is_empty():
		UITheme.make_heading(modal_content, "No monsters yet", 20, UITheme.INK)
		UITheme.make_label(modal_content, "Capture or tame wild monsters to fill your team.", 14, UITheme.MUTED)
		return
	party_selected = clampi(party_selected, 0, Game.party.size() - 1)
	var cols := UITheme.make_hbox(modal_content, 16)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := UITheme.make_vbox(cols, 6)
	left.custom_minimum_size = Vector2(330, 0)
	for i in Game.party.size():
		_party_list_card(left, Game.party[i], i, Game.active_index == i)
	var right := UITheme.make_vbox(cols, 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_party_member(right, Game.party[party_selected], party_selected, false)

func _party_list_card(parent: Node, mon: Dictionary, index: int, active: bool) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(320, 70)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var base := UITheme.style(Color(0.04, 0.11, 0.105, 0.86), Color(0.27, 0.45, 0.4, 0.7), 12, 1, 6)
	if index == party_selected:
		base.border_color = UITheme.AMBER
		base.border_width_left = 2
		base.border_width_right = 2
		base.border_width_top = 2
		base.border_width_bottom = 2
		base.bg_color = Color(0.09, 0.16, 0.13, 0.95)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", base)
	b.add_theme_stylebox_override("pressed", base)
	parent.add_child(b)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(margin)
	var row := UITheme.make_hbox(margin, 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := TextureRect.new()
	portrait.texture = Content.get_monster_portrait(str(mon.get("species", "")))
	portrait.custom_minimum_size = Vector2(54, 54)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var v := UITheme.make_vbox(row, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := UITheme.make_label(v, "%s  Lv%d" % [Content.SPECIES.get(str(mon.get("species", "")), {}).get("name", "?"), int(mon.get("level", 1))], 14, UITheme.INK)
	if active:
		name_l.add_theme_color_override("font_color", UITheme.AMBER)
	var stats := Content.monster_stats(mon)
	UITheme.make_label(v, "HP %d/%d   •   %s" % [int(mon.get("hp", 0)), int(stats.hp), Content.ability_name(str(Content.SPECIES.get(str(mon.get("species", "")), {}).get("ability", "")))], 11, UITheme.MUTED)
	var hp := UITheme.make_bar(v, 0, 5, UITheme.GREEN)
	hp.max_value = int(stats.hp)
	hp.value = int(mon.get("hp", 0))
	b.pressed.connect(func(): party_selected = index; _build_modal_content())

func _detail_party_member(parent: Node, mon: Dictionary, index: int, from_storage: bool) -> void:
	var sp: Dictionary = Content.SPECIES.get(str(mon.get("species", "")), {})
	var stats := Content.monster_stats(mon)
	var card := UITheme.make_card(parent)
	var h := UITheme.make_hbox(card, 14)
	var portrait := TextureRect.new()
	portrait.texture = Content.get_monster_portrait(str(mon.get("species", "")))
	portrait.custom_minimum_size = Vector2(124, 124)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(portrait)
	var info := UITheme.make_vbox(h, 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.make_heading(info, str(sp.get("name", "?")), 24, Content.element_color(str(sp.get("element", ""))))
	UITheme.make_label(info, "Level %d • %s • Bond %d%%" % [int(mon.get("level", 1)), Content.element_name(str(sp.get("element", ""))), int(mon.get("bond", 0))], 13, UITheme.AMBER)
	UITheme.make_label(info, "HP %d/%d   ATK %d   DEF %d   SPD %.1f" % [int(mon.get("hp", 0)), int(stats.hp), int(stats.atk), int(stats.def), float(stats.spd)], 13, UITheme.INK)
	UITheme.make_label(info, "Ability: %s" % Content.ability_name(str(sp.get("ability", ""))), 13, UITheme.GREEN)
	UITheme.make_label(info, Content.ability_desc(str(sp.get("ability", ""))), 12, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.make_label(info, str(sp.get("lore", "")), 12, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var evo := str(sp.get("evolve", ""))
	if evo != "":
		UITheme.make_label(info, "Evolves into %s at Lv%d." % [Content.SPECIES[evo].name, int(sp.get("evolve_level", 0))], 12, UITheme.TEAL)
	else:
		UITheme.make_label(info, "Final form of its evolution line.", 12, UITheme.MUTED)
	UITheme.make_label(info, "XP %d / %d" % [int(mon.get("xp", 0)), Content.xp_to_next(int(mon.get("level", 1)))], 11, UITheme.MUTED)
	var row := UITheme.make_hbox(parent, 8)
	if from_storage:
		var to_team := UITheme.make_button(row, "Add to Team", "primary", 44, 14)
		to_team.disabled = not Game.party_has_space()
		to_team.pressed.connect(func():
			if Game.move_storage_to_party(index):
				spawner._refresh_companion()
				party_tab = "Team"
			_build_modal_content())
		UITheme.make_button(row, "Assign to Ranch", "normal", 44, 14).pressed.connect(func():
			Game.assign_to_ranch(mon, true)
			_build_modal_content())
		UITheme.make_button(row, "Release", "danger", 44, 14).pressed.connect(func():
			_open_confirm("Release monster?", "%s will be released and grant Amber." % str(sp.get("name", "Monster")), func():
				Game.release_monster(index, true)
				storage_selected = 0
				open_party()))
	else:
		if Game.active_index != index:
			UITheme.make_button(row, "Set Active", "primary", 44, 14).pressed.connect(func():
				Game.set_active(index)
				spawner._refresh_companion()
				_build_modal_content())
		else:
			UITheme.make_label(row, "Active partner", 13, UITheme.AMBER)
		UITheme.make_button(row, "Feed", "normal", 44, 14).pressed.connect(func():
			var msg := Game.feed_party_monster(index)
			if msg != "":
				Game.notify.emit(msg, UITheme.RED)
			_build_modal_content())
		if bool(sp.get("rideable", false)) and Game.active_index == index:
			var ride := UITheme.make_button(row, "Ride", "normal", 44, 14)
			ride.pressed.connect(func():
				if Game.count_item("saddle") < 1:
					Game.notify.emit("You need a Saddle in your bag.", UITheme.RED)
				else:
					spawner.mount_active()
					if player.riding_monster != null:
						_close_modal())
		UITheme.make_button(row, "Assign to Ranch", "normal", 44, 14).pressed.connect(func():
			Game.assign_to_ranch(mon, false)
			party_selected = clampi(party_selected, 0, maxi(Game.party.size() - 1, 0))
			_build_modal_content())
		UITheme.make_button(row, "Release", "danger", 44, 14).pressed.connect(func():
			_open_confirm("Release monster?", "%s will be released and grant Amber." % str(sp.get("name", "Monster")), func():
				Game.release_monster(index, false)
				party_selected = clampi(party_selected, 0, maxi(Game.party.size() - 1, 0))
				open_party()))

func _build_storage() -> void:
	if Game.storage.is_empty():
		UITheme.make_heading(modal_content, "Storage is empty", 20, UITheme.INK)
		UITheme.make_label(modal_content, "Monsters that do not fit in your team are sent to storage. You can also send them here when the team is full.", 14, UITheme.MUTED)
		return
	UITheme.make_label(modal_content, "Monsters in storage do not fight, but they are still recorded in the Codex.", 12, UITheme.MUTED)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_content.add_child(grid)
	storage_selected = clampi(storage_selected, 0, Game.storage.size() - 1)
	for i in Game.storage.size():
		var mon: Dictionary = Game.storage[i]
		var sp: Dictionary = Content.SPECIES.get(str(mon.get("species", "")), {})
		var b := Button.new()
		b.custom_minimum_size = Vector2(186, 88)
		b.focus_mode = Control.FOCUS_NONE
		var st := UITheme.style(Color(0.04, 0.11, 0.105, 0.86), Color(0.27, 0.45, 0.4, 0.7), 10, 1, 6)
		if i == storage_selected:
			st.border_color = UITheme.AMBER
			st.border_width_left = 2
			st.border_width_top = 2
			st.border_width_right = 2
			st.border_width_bottom = 2
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		grid.add_child(b)
		var r := UITheme.make_hbox(b, 6)
		var portrait := TextureRect.new()
		portrait.texture = Content.get_monster_portrait(str(mon.get("species", "")))
		portrait.custom_minimum_size = Vector2(50, 50)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(portrait)
		var v := UITheme.make_vbox(r, 0)
		UITheme.make_label(v, str(sp.get("name", "?")), 13, UITheme.INK)
		UITheme.make_label(v, "Lv%d • %s" % [int(mon.get("level", 1)), Content.element_name(str(sp.get("element", "")))], 10, UITheme.MUTED)
		b.pressed.connect(func(): storage_selected = i; _build_modal_content())
	var det := UITheme.make_vbox(modal_content, 8)
	_detail_party_member(det, Game.storage[storage_selected], storage_selected, true)

func _build_ranch() -> void:
	UITheme.make_heading(modal_content, "Ranch & Breeding", 22, UITheme.INK)
	UITheme.make_label(modal_content, "Ranch workers gather materials while you play and while the game is closed (up to 4 hours). Requires a placed Ranch Banner.", 13, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var workers_row := UITheme.make_hbox(modal_content, 8)
	for i in 3:
		var card := UITheme.make_card(workers_row)
		card.custom_minimum_size = Vector2(0, 140)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UITheme.make_vbox(card, 3)
		if i < Game.ranch.workers.size():
			var mon: Dictionary = Game.ranch.workers[i]
			var sp: Dictionary = Content.SPECIES.get(str(mon.get("species", "")), {})
			var portrait := TextureRect.new()
			portrait.texture = Content.get_monster_portrait(str(mon.get("species", "")))
			portrait.custom_minimum_size = Vector2(58, 58)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(portrait)
			UITheme.make_label(v, "%s Lv%d" % [sp.get("name", "?"), int(mon.get("level", 1))], 13, UITheme.INK)
			UITheme.make_label(v, Content.ability_name(str(sp.get("ability", ""))), 11, UITheme.AMBER)
			UITheme.make_button(v, "Recall", "normal", 32, 12).pressed.connect(func():
				Game.recall_from_ranch(str(mon.get("uid", "")))
				_build_modal_content())
		else:
			UITheme.make_label(v, "Worker Slot %d" % (i + 1), 13, UITheme.MUTED)
			UITheme.make_label(v, "Assign a monster from the Team or Storage tab.", 11, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.make_heading(modal_content, "Breed Two Workers", 18, UITheme.AMBER)
	var breed_row := UITheme.make_hbox(modal_content, 10)
	if Game.ranch.workers.size() >= 2:
		for i in 2:
			var mon: Dictionary = Game.ranch.workers[i]
			var sp: Dictionary = Content.SPECIES.get(str(mon.get("species", "")), {})
			var box := UITheme.make_vbox(breed_row, 2)
			var portrait := TextureRect.new()
			portrait.texture = Content.get_monster_portrait(str(mon.get("species", "")))
			portrait.custom_minimum_size = Vector2(64, 64)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(portrait)
			UITheme.make_label(box, sp.get("name", "?"), 12, UITheme.INK)
		var check := Game.can_breed()
		var msg := UITheme.make_label(breed_row, str(check.msg) if not check.ok else "Ready to breed. Result: the base form of one parent.", 12, UITheme.GREEN if check.ok else UITheme.MUTED)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		UITheme.make_label(breed_row, "Requires at least 2 ranch workers from the same egg group at level 5+.", 12, UITheme.MUTED)
	var actions := UITheme.make_hbox(modal_content, 8)
	var breed_btn := UITheme.make_button(actions, "Breed (2 Feed)", "primary", 42, 13)
	breed_btn.disabled = not Game.can_breed().ok
	breed_btn.pressed.connect(func():
		var res := Game.breed_ranch()
		Game.notify.emit(str(res.get("msg", "")), UITheme.GREEN if res.get("ok", false) else UITheme.RED)
		if res.get("ok", false):
			spawner._refresh_companion()
		_build_modal_content())
	UITheme.make_label(actions, "Feed: %d   •   Cooldown: %ds   •   Workers: %d/3" % [
		Game.count_item("feed"), int(ceil(Game.ranch.get("cooldown", 0.0))), Game.ranch.workers.size()], 12, UITheme.MUTED)
	UITheme.make_label(modal_content, "Breeding produces a level 1 monster. 10% chance for a Shiny variant. The result joins your team if there is room.", 11, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _ordered_species() -> Array:
	var ids: Array = Content.SPECIES.keys()
	ids.sort_custom(func(a, b):
		var sa: Dictionary = Content.SPECIES[a]
		var sb: Dictionary = Content.SPECIES[b]
		if int(sa.stage) != int(sb.stage):
			return int(sa.stage) < int(sb.stage)
		return str(sa.name) < str(sb.name))
	return ids

func _build_codex() -> void:
	var discovered := Game.codex.size()
	UITheme.make_label(modal_content, "%d / %d species discovered. Capture, tame, or evolve monsters to complete your collection." % [discovered, Content.SPECIES.size()], 13, UITheme.MUTED)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_content.add_child(grid)
	for id in _ordered_species():
		var sp: Dictionary = Content.SPECIES[id]
		var known := Game.codex.has(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(160, 118)
		b.focus_mode = Control.FOCUS_NONE
		var st := UITheme.style(Color(0.04, 0.11, 0.105, 0.86), Color(0.27, 0.45, 0.4, 0.7), 10, 1, 4)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", UITheme.style(Color(0.08, 0.19, 0.17, 0.95), UITheme.AMBER_DIM, 10, 1, 4))
		grid.add_child(b)
		var v := UITheme.make_vbox(b, 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait := TextureRect.new()
		portrait.texture = Content.get_monster_portrait(id)
		portrait.custom_minimum_size = Vector2(54, 54)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not known:
			portrait.modulate = Color(0.08, 0.12, 0.12, 0.9)
		v.add_child(portrait)
		UITheme.make_label(v, str(sp.name) if known else "???", 12, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
		UITheme.make_label(v, ("Lv%d %s" % [int(sp.stage), Content.element_name(str(sp.element))]) if known else "Undiscovered", 9, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		if known:
			UITheme.make_label(v, "x%d" % int(Game.codex[id].get("count", 0)), 9, UITheme.AMBER, HORIZONTAL_ALIGNMENT_CENTER)
		b.pressed.connect(func():
			if known:
				codex_selected = id
				_open_modal("codex_detail", str(sp.name))
			else:
				Game.notify.emit("This species has not been discovered yet.", UITheme.MUTED))

func _build_codex_detail() -> void:
	var id := codex_selected
	if id == "" or not Content.SPECIES.has(id):
		UITheme.make_button(modal_content, "Back", "primary", 44).pressed.connect(open_codex)
		return
	var sp: Dictionary = Content.SPECIES[id]
	var row := UITheme.make_hbox(modal_content, 16)
	var portrait := TextureRect.new()
	portrait.texture = Content.get_monster_portrait(id)
	portrait.custom_minimum_size = Vector2(220, 220)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var info := UITheme.make_vbox(row, 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.make_heading(info, str(sp.name), 28, Content.element_color(str(sp.element)))
	UITheme.make_label(info, "%s • %s • %s" % [Content.element_name(str(sp.element)), Content.ability_name(str(sp.ability)), "BOSS" if bool(sp.get("boss", false)) else "Wild"], 13, UITheme.AMBER)
	UITheme.make_label(info, str(sp.lore), 14, UITheme.INK).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.make_label(info, "HP dasar %d   ATK %d   DEF %d   SPD %.1f" % [int(sp.hp), int(sp.atk), int(sp.def), float(sp.spd)], 13, UITheme.MUTED)
	UITheme.make_label(info, Content.ability_desc(str(sp.ability)), 12, UITheme.GREEN).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var locs: Array = []
	for b in sp.get("biomes", []):
		locs.append(str(Content.BIOMES.get(b, {}).get("name", b)))
	if locs.is_empty():
		locs.append("Dungeon / Rift")
	UITheme.make_label(info, "Habitat: " + ", ".join(locs), 12, UITheme.MUTED)
	UITheme.make_label(info, "Caught: x%d   •   Shiny: x%d   •   Egg Group: %s" % [
		int(Game.codex.get(id, {}).get("count", 0)), int(Game.codex.get(id, {}).get("shiny", 0)),
		str(sp.get("egg", "-")).capitalize()], 12, UITheme.MUTED)
	var line := Content.evolution_line(id)
	UITheme.make_label(info, "Evolution line", 13, UITheme.AMBER)
	var erow := UITheme.make_hbox(info, 6)
	for evo_id in line:
		var esp: Dictionary = Content.SPECIES[evo_id]
		var box := UITheme.make_vbox(erow, 0)
		var ep := TextureRect.new()
		ep.texture = Content.get_monster_portrait(evo_id)
		ep.custom_minimum_size = Vector2(54, 54)
		ep.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ep.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not Game.codex.has(evo_id):
			ep.modulate = Color(0.1, 0.14, 0.14, 0.9)
		box.add_child(ep)
		UITheme.make_label(box, str(esp.name) if Game.codex.has(evo_id) else "???", 9, UITheme.MUTED)
	var back := UITheme.make_button(modal_content, "Back to Codex", "normal", 44)
	back.pressed.connect(open_codex)


func _build_quests() -> void:
	var tracked := Game.tracked_story_quest()
	var head := UITheme.make_hbox(modal_content, 14)
	var title_col := UITheme.make_vbox(head, 2)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.make_heading(title_col, "Story Journal", 30, UITheme.INK)
	UITheme.make_label(title_col, "The vale remembers every promise you keep.", 13, UITheme.MUTED)
	var act := int(tracked.get("act", 1)) if not tracked.is_empty() else 1
	var act_card := UITheme.make_card(head)
	var acv := UITheme.make_vbox(act_card, 2)
	acv.custom_minimum_size = Vector2(220, 0)
	UITheme.make_label(acv, "CURRENT ACT", 10, UITheme.AMBER)
	UITheme.make_heading(acv, "Act %d" % act, 20, UITheme.INK)
	UITheme.make_label(acv, _act_name(act), 12, UITheme.MUTED)

	var mains: Array = Story.of_kind("main")
	var cleared := 0
	for q in mains:
		var r: Dictionary = Game.story.get(str(q.id), {})
		if bool(r.get("claimed", false)):
			cleared += 1
	var prog_row := UITheme.make_hbox(modal_content, 10)
	UITheme.make_label(prog_row, "Main story", 14, UITheme.INK)
	var bar := UITheme.make_bar(prog_row, 380, 10, UITheme.AMBER)
	bar.max_value = mains.size()
	bar.value = cleared
	UITheme.make_label(prog_row, "%d / %d chapters" % [cleared, mains.size()], 12, UITheme.MUTED)

	var tracked_id := str(tracked.get("id", ""))
	UITheme.make_heading(modal_content, "MAIN STORY", 15, UITheme.AMBER)
	for i in mains.size():
		_story_card(mains[i], "main", i, tracked_id)
	UITheme.make_heading(modal_content, "SIDE QUESTS", 15, UITheme.TEAL)
	for q in Story.of_kind("side"):
		_story_card(q, "side", 0, tracked_id)

	var map_row := UITheme.make_hbox(modal_content, 8)
	UITheme.make_button(map_row, "Track Nearest Dungeon", "normal", 42, 13).pressed.connect(_track_dungeon)
	UITheme.make_button(map_row, "Track Nearest Village", "normal", 42, 13).pressed.connect(_track_village)
	UITheme.make_button(map_row, "Clear Route", "ghost", 42, 13).pressed.connect(func():
		main.tracked_waypoint = Vector3.ZERO
		Game.notify.emit("Route cleared.", UITheme.MUTED)
		_build_modal_content())

func _act_name(act: int) -> String:
	match act:
		1:
			return "Roots & Whispers"
		2:
			return "Under the Vale"
		3:
			return "The Hollow Heart"
	return "The Wandering Vale"

func _story_card(q: Dictionary, kind: String, index: int, tracked_id: String) -> void:
	var qid := str(q.id)
	var rec: Dictionary = Game.story.get(qid, {"steps": [], "done": false, "claimed": false})
	var unlocked := Game.story_unlocked(q)
	var done := bool(rec.get("done", false))
	var claimed := bool(rec.get("claimed", false))
	var accent: Color = UITheme.AMBER if kind == "main" else UITheme.TEAL
	var card := UITheme.make_card(modal_content)
	var v := UITheme.make_vbox(card, 6)
	var top := UITheme.make_hbox(v, 10)
	var tag_text := ("CHAPTER %d" % (index + 1)) if kind == "main" else "SIDE QUEST"
	UITheme.make_label(top, tag_text, 10, accent)
	var status := "LOCKED"
	var status_col := UITheme.MUTED
	if claimed:
		status = "CLAIMED"
		status_col = UITheme.MUTED
	elif done:
		status = "READY TO CLAIM"
		status_col = UITheme.GREEN
	elif unlocked:
		status = "ACTIVE"
		status_col = accent
	var status_lbl := UITheme.make_label(top, status, 10, status_col)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.make_heading(v, str(q.title), 19, UITheme.INK if unlocked else UITheme.MUTED)
	UITheme.make_label(v, "Given by %s" % str(q.giver), 11, accent)
	UITheme.make_label(v, str(q.story), 13, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if not unlocked:
		UITheme.make_label(v, "Finish the previous chapter to unlock this story.", 12, UITheme.MUTED)
		return

	var steps: Array = q.steps
	var prog: Array = rec.get("steps", [])
	for i in steps.size():
		var st: Dictionary = steps[i]
		var p := int(prog[i]) if i < prog.size() else 0
		var goal := int(st.goal)
		var finished := p >= goal
		var row := UITheme.make_hbox(v, 8)
		var mark := UITheme.make_label(row, "[x]" if finished else "[  ]", 11, UITheme.GREEN if finished else UITheme.MUTED)
		mark.custom_minimum_size = Vector2(34, 0)
		var text_lbl := UITheme.make_label(row, str(st.text), 13, UITheme.INK if finished else Color("#d8dfd2"))
		text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.make_label(row, "%d/%d" % [p, goal], 12, UITheme.GREEN if finished else UITheme.MUTED)

	var rw: Dictionary = q.reward
	var rw_txt := "+%d XP    +%d Amber" % [int(rw.get("xp", 0)), int(rw.get("amber", 0))]
	var rw_item := str(rw.get("item", ""))
	if rw_item != "":
		var item_name := str(Content.ITEMS.get(rw_item, {}).get("name", rw_item))
		rw_txt += "    +%s x%d" % [item_name, int(rw.get("n", 1))]
	UITheme.make_label(v, rw_txt, 12, UITheme.AMBER)

	var btns := UITheme.make_hbox(v, 8)
	if done and not claimed:
		var claim := UITheme.make_button(btns, "Claim Reward", "primary", 40, 13)
		claim.pressed.connect(func():
			Game.claim_story(qid)
			_build_modal_content())
	if not claimed:
		var track := UITheme.make_button(btns, "Tracking" if tracked_id == qid else "Track", "normal", 40, 13)
		track.disabled = tracked_id == qid
		track.pressed.connect(func():
			main.call("track_quest", qid)
			_build_modal_content())

func _build_quest_tracker() -> void:
	tracker_card = PanelContainer.new()
	var sb := UITheme.glass_style(14, 0.8)
	sb.content_margin_left = 12
	sb.content_margin_top = 9
	sb.content_margin_right = 12
	sb.content_margin_bottom = 9
	sb.border_width_left = 3
	tracker_card.add_theme_stylebox_override("panel", sb)
	tracker_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker_card.visible = false
	add_child(tracker_card)
	_pin(tracker_card, 1.0, 0.0, 1.0, 0.0, -322.0, 88.0, -16.0, 164.0)
	tracker_box = UITheme.make_vbox(tracker_card, 1)
	var head := UITheme.make_hbox(tracker_box, 6)
	tracker_title = UITheme.make_label(head, "MAIN STORY", 9, UITheme.AMBER)
	tracker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracker_hint = UITheme.make_label(head, "", 9, UITheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	tracker_name = UITheme.make_label(tracker_box, "", 13, UITheme.INK)
	tracker_name.clip_text = true
	tracker_name.custom_minimum_size = Vector2(286, 0)
	tracker_step = UITheme.make_label(tracker_box, "", 11, Color(0.83, 0.88, 0.8))
	tracker_step.clip_text = true
	tracker_step.custom_minimum_size = Vector2(286, 0)

func _update_quest_tracker() -> void:
	if tracker_card == null or not is_instance_valid(tracker_card):
		return
	if not Game.in_game:
		tracker_card.visible = false
		return
	var q := Game.tracked_story_quest()
	if q.is_empty():
		tracker_card.visible = false
		return
	var rec: Dictionary = Game.story.get(str(q.id), {})
	tracker_card.visible = true
	var is_main := str(q.kind) == "main"
	var accent: Color = UITheme.AMBER if is_main else UITheme.TEAL
	tracker_title.text = "MAIN STORY" if is_main else "SIDE QUEST"
	tracker_title.add_theme_color_override("font_color", accent)
	var sb := UITheme.glass_style(14, 0.8)
	sb.border_width_left = 3
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	tracker_card.add_theme_stylebox_override("panel", sb)
	tracker_name.text = str(q.title)
	tracker_step.text = Game.story_step_text(q, rec)
	var pos := Vector3.ZERO
	if main != null and main.has_method("quest_marker_position"):
		pos = main.call("quest_marker_position", q)
	if pos != Vector3.ZERO and player != null:
		tracker_hint.text = "%dm" % int(player.global_position.distance_to(pos))
	else:
		tracker_hint.text = str(q.giver)
func _track_dungeon() -> void:
	var info := world.get_nearest_dungeon(player.global_position)
	if info.is_empty():
		Game.notify.emit("No known dungeon nearby.", UITheme.MUTED)
		return
	var c: Vector3i = info.entrance
	main.tracked_waypoint = Vector3(c) + Vector3(0.5, 1.0, 0.5)
	Game.notify.emit("Route to %s set (%dm)." % [info.get("name", "dungeon"), int(player.global_position.distance_to(main.tracked_waypoint))], Color("#d9a6ff"))
	_build_modal_content()

func _track_village() -> void:
	var info := world.get_nearest_village(player.global_position)
	if info.is_empty():
		Game.notify.emit("No village nearby.", UITheme.MUTED)
		return
	var c: Vector3i = info.center
	main.tracked_waypoint = Vector3(c) + Vector3(0.5, 1.0, 0.5)
	Game.discovered_village(str(info.id), Vector3(c))
	Game.notify.emit("Route to %s set." % info.get("name", "village"), UITheme.AMBER)
	_build_modal_content()

func _build_map() -> void:
	var row := UITheme.make_hbox(modal_content, 16)
	var view := MinimapView.new()
	view.large = true
	view.world = world
	view.player = player
	view.main = main
	view.custom_minimum_size = Vector2(480, 480)
	view.size = Vector2(480, 480)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(view)
	var info := UITheme.make_vbox(row, 8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.make_heading(info, "World Map", 22, UITheme.INK)
	UITheme.make_label(info, "Position: %d, %d\nBiome: %s\nTime: Day %d %s\nWeather: %s" % [
		int(player.global_position.x), int(player.global_position.z),
		Content.BIOMES.get(world.biome_at_pos(player.global_position), {}).get("name", "?"),
		Game.day, Game.time_string(), _weather_name()], 13, UITheme.MUTED)
	UITheme.make_heading(info, "Legend", 16, UITheme.AMBER)
	UITheme.make_label(info, "Yellow: discovered village\nPurple: nearest dungeon\nAmber ring: active route", 12, UITheme.MUTED)
	var d := world.get_nearest_dungeon(player.global_position)
	if not d.is_empty():
		var c: Vector3i = d.entrance
		UITheme.make_label(info, "Dungeon: %s (%dm)\nBoss: %s" % [d.get("name", "?"), int(player.global_position.distance_to(Vector3(c))), Content.SPECIES.get(str(d.get("boss", "")), {}).get("name", "?")], 12, Color("#d9a6ff"))
	var v := world.get_nearest_village(player.global_position)
	if not v.is_empty():
		var vc: Vector3i = v.center
		UITheme.make_label(info, "Village: %s (%dm)" % [v.get("name", "?"), int(player.global_position.distance_to(Vector3(vc)))], 12, UITheme.AMBER)
	UITheme.make_button(info, "Track Dungeon", "normal", 42, 13).pressed.connect(_track_dungeon)
	UITheme.make_button(info, "Track Village", "normal", 42, 13).pressed.connect(_track_village)
	UITheme.make_button(info, "Clear Route", "ghost", 40, 13).pressed.connect(func():
		main.tracked_waypoint = Vector3.ZERO
		_build_modal_content())

func _build_chest() -> void:
	var key := str(modal_args.get("key", ""))
	if key == "":
		UITheme.make_label(modal_content, "Chest not found.", 14, UITheme.RED)
		return
	var chest: Array = Game.get_chest(key)
	var tier := int(modal_args.get("tier", 0))
	UITheme.make_label(modal_content, "Chest • %s • %d/18 slots used" % ["Dungeon" if tier > 0 else "Storage", _count_chest(chest)], 12, UITheme.MUTED)
	UITheme.make_heading(modal_content, "CHEST CONTENTS", 15, UITheme.AMBER)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_content.add_child(grid)
	for i in 18:
		var s = chest[i] if i < chest.size() else null
		var b := UITheme.make_slot(grid, 50)
		if s is Dictionary:
			b.icon = Content.get_icon(str(s.id))
			_add_count_label(b, int(s.n))
		b.pressed.connect(_chest_take.bind(i))
	UITheme.make_heading(modal_content, "YOUR BAG", 15, UITheme.AMBER)
	var pgrid := GridContainer.new()
	pgrid.columns = 9
	pgrid.add_theme_constant_override("h_separation", 6)
	pgrid.add_theme_constant_override("v_separation", 6)
	pgrid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_content.add_child(pgrid)
	for i in 36:
		var s = Game.inventory[i] if i < Game.inventory.size() else null
		var b := UITheme.make_slot(pgrid, 50)
		if s is Dictionary:
			b.icon = Content.get_icon(str(s.id))
			_add_count_label(b, int(s.n))
		b.pressed.connect(_chest_put.bind(i))

func _count_chest(arr: Array) -> int:
	var n := 0
	for s in arr:
		if s != null:
			n += 1
	return n

func _add_count_label(b: Button, n: int) -> void:
	if n <= 1:
		return
	var lbl := Label.new()
	lbl.text = str(n)
	lbl.add_theme_font_override("font", UITheme.body_font())
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", UITheme.INK)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.05, 0.95))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.anchor_left = 1
	lbl.anchor_top = 1
	lbl.anchor_right = 1
	lbl.anchor_bottom = 1
	lbl.offset_left = -28
	lbl.offset_top = -20
	lbl.offset_right = -3
	lbl.offset_bottom = -1
	b.add_child(lbl)

func _chest_take(index: int) -> void:
	var key := str(modal_args.get("key", ""))
	var chest: Array = Game.get_chest(key)
	if index < 0 or index >= chest.size() or chest[index] == null:
		return
	var item: Dictionary = chest[index]
	var left := Game.add_item(str(item.id), int(item.n), true)
	if left <= 0:
		chest[index] = null
	else:
		chest[index] = {"id": item.id, "n": left}
	Sfx.play("pickup")
	_build_modal_content()

func _chest_put(index: int) -> void:
	var key := str(modal_args.get("key", ""))
	var chest: Array = Game.get_chest(key)
	var s = Game.inventory[index] if index >= 0 and index < Game.inventory.size() else null
	if not s is Dictionary:
		return
	for i in chest.size():
		if chest[i] == null:
			chest[i] = {"id": s.id, "n": int(s.n)}
			Game.inventory[index] = null
			Game.inventory_changed.emit()
			Sfx.play("ui")
			_build_modal_content()
			return
	Game.notify.emit("Chest is full.", UITheme.RED)

func _avatar_letter(name: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(92, 92)
	var sb := UITheme.style(Color(0.08, 0.18, 0.16, 0.9), UITheme.AMBER_DIM, 46, 2, 8)
	p.add_theme_stylebox_override("panel", sb)
	var l := UITheme.make_heading(p, name.substr(0, 1).to_upper(), 38, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _build_npc() -> void:
	var npc: Dictionary = modal_args.get("npc", {})
	var name := str(npc.get("name", "Villager"))
	var role := str(npc.get("role", "villager"))
	if role == "elder":
		Game.set_flag("met_elder")
	var village := str(npc.get("village_name", "Village"))
	var row := UITheme.make_hbox(modal_content, 16)
	row.add_child(_avatar_letter(name))
	var info := UITheme.make_vbox(row, 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.make_heading(info, name, 24, UITheme.INK)
	UITheme.make_label(info, "%s • %s" % [village, _role_name(role)], 13, UITheme.AMBER)
	var greetings := {
		"elder": "The wild monsters grow bolder every day. Help the village and we will reward you.",
		"merchant": "Amber keeps this valley trading. I buy fresh materials and sell supplies.",
		"farmer": "The soil here is rich. Remember to plant seeds after tilling.",
		"villager": "Be careful in the woods. Passive monsters can be tamed with Feed.",
	}
	UITheme.make_label(info, greetings.get(role, "May your day be peaceful."), 14, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if role == "elder":
		UITheme.make_heading(info, "Village Quest", 16, UITheme.AMBER)
		var village_id := str(npc.get("village_id", "village"))
		var q = Game.village_quests.get(village_id)
		var active_quest = null
		for qq in Game.quests:
			if str(qq.get("giver", "")) == village_id:
				active_quest = qq
				break
		if active_quest == null:
			if q != null and q.get("claimed", false):
				UITheme.make_label(info, "The village quest is complete. Thank you for helping.", 12, UITheme.MUTED)
			else:
				UITheme.make_label(info, "I have work for a traveler. Will you help?", 12, UITheme.MUTED)
				UITheme.make_button(info, "Ask for a Quest", "primary", 40, 13).pressed.connect(func():
					Game.accept_village_quest(village_id)
					_build_modal_content())
		else:
			UITheme.make_label(info, str(active_quest.get("title", "Quest")), 13, UITheme.INK)
			UITheme.make_label(info, str(active_quest.get("desc", "")), 12, UITheme.MUTED)
			UITheme.make_label(info, "Progress %d/%d" % [int(active_quest.get("progress", 0)), int(active_quest.get("count", 1))], 12, UITheme.AMBER)
			var claim := UITheme.make_button(info, "Turn In Quest", "primary", 38, 13)
			claim.disabled = not bool(active_quest.get("done", false))
			claim.pressed.connect(func():
				if Game.claim_quest(str(active_quest.get("id", ""))):
					_build_modal_content())
	elif role == "merchant":
		UITheme.make_button(info, "Open Shop", "primary", 44, 14).pressed.connect(func():
			open_shop(npc))
	var btn_row := UITheme.make_hbox(modal_content, 8)
	UITheme.make_button(btn_row, "Close", "normal", 44).pressed.connect(_close_modal)

func _role_name(role: String) -> String:
	match role:
		"elder": return "Village Elder"
		"merchant": return "Merchant"
		"farmer": return "Farmer"
	return "Villager"

func _build_shop() -> void:
	var row := UITheme.make_hbox(modal_content, 6)
	for t in ["Buy", "Sell"]:
		var b := UITheme.make_button(row, t, "primary" if shop_tab == t else "normal", 40, 14)
		b.pressed.connect(func(): shop_tab = t; _build_modal_content())
	UITheme.make_label(modal_content, "Amber: %d" % Game.wallet, 14, UITheme.AMBER)
	if shop_tab == "Buy":
		for i in Content.MERCHANT_STOCK.size():
			var offer: Dictionary = Content.MERCHANT_STOCK[i]
			_shop_row(str(offer.id), int(offer.n), int(offer.price), true, i)
	else:
		for offer in Content.MERCHANT_BUY:
			if Game.count_item(str(offer.id)) > 0:
				_shop_row(str(offer.id), 1, int(offer.price), false, -1)
		if Game.count_item("fiber") == 0 and Game.count_item("log") == 0:
			UITheme.make_label(modal_content, "Nothing to sell. Gather fiber, wood, stone, or ore.", 13, UITheme.MUTED)
	var back := UITheme.make_button(modal_content, "Back to Villager", "ghost", 44, 13)
	back.pressed.connect(func(): _open_modal("npc", str(shop_npc.get("name", "Villager")), {"npc": shop_npc}))

func _shop_row(item_id: String, n: int, price: int, buying: bool, stock_index: int) -> void:
	var card := UITheme.make_card(modal_content)
	card.custom_minimum_size = Vector2(0, 62)
	var row := UITheme.make_hbox(card, 10)
	var icon := TextureRect.new()
	icon.texture = Content.get_icon(item_id)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var info := UITheme.make_vbox(row, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.make_label(info, "%s x%d" % [Content.get_item_name(item_id), n], 14, UITheme.INK)
	UITheme.make_label(info, "%s %d Amber" % ["Harga" if buying else "Sell", price], 11, UITheme.AMBER)
	var action := "Buy" if buying else "Sell"
	var b := UITheme.make_button(row, action, "primary" if buying else "normal", 40, 13)
	b.disabled = Game.wallet < price if buying else Game.count_item(item_id) < n
	b.pressed.connect(func():
		if buying:
			if Game.merchant_buy(stock_index):
				Sfx.play("ui")
		else:
			if Game.merchant_sell(item_id, n):
				Sfx.play("ui")
		_build_modal_content())

# ------------------------------------------------------------------ pause / settings / starter

func _build_pause() -> void:
	var row := UITheme.make_hbox(modal_content, 16)
	var left := UITheme.make_vbox(row, 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.make_heading(left, "Adventure Paused", 22, UITheme.INK)
	UITheme.make_label(left, "World: %s\nDay %d • %s\nLevel %d • Captured %d • Kills %d\nPlay time %s" % [
		Game._world_name(), Game.day, Game.time_string(), Game.level, Game.captures, Game.kills,
		UITheme.fmt_time(Game.play_time)], 14, UITheme.MUTED)
	UITheme.make_label(left, "Seed: %d" % Game.seed_value, 12, UITheme.MUTED)
	var right := UITheme.make_vbox(row, 8)
	right.custom_minimum_size = Vector2(340, 0)
	UITheme.make_button(right, "Resume", "primary", 52).pressed.connect(_close_modal)
	UITheme.make_button(right, "Save Now", "normal", 48).pressed.connect(func():
		Game.save_game(Game.current_slot, false)
		_close_modal())
	UITheme.make_button(right, "Settings", "normal", 48).pressed.connect(open_settings)
	UITheme.make_button(right, "Controls Guide", "normal", 48).pressed.connect(open_guide)
	UITheme.make_button(right, "Quit to Menu", "danger", 48).pressed.connect(func():
		_open_confirm("Quit to menu?", "The world will be saved automatically before exiting.", func(): main.quit_to_menu()))

func _build_settings() -> void:
	UITheme.make_heading(modal_content, "Controls", 18, UITheme.AMBER)
	_slider_row("Sensitivity", 0.35, 2.5, Game.look_sensitivity, func(v):
		Game.look_sensitivity = v
		if player != null:
			player.look_sensitivity = v)
	_toggle_row("Invert look (Y)", Game.invert_look_y, func(v): Game.invert_look_y = v)
	_toggle_row("Left-handed layout", Game.left_handed, func(v): Game.left_handed = v)
	_toggle_row("Screen shake", Game.screen_shake, func(v): Game.screen_shake = v)
	UITheme.make_heading(modal_content, "Audio", 18, UITheme.AMBER)
	_slider_row("Master", 0.0, 1.0, Game.master_volume, func(v):
		Game.master_volume = v
		Sfx.set_master_volume(v))
	_slider_row("Music", 0.0, 1.0, Game.music_volume, func(v):
		Game.music_volume = v
		Sfx.set_music_volume(v))
	_slider_row("Effects", 0.0, 1.0, Game.sfx_volume, func(v):
		Game.sfx_volume = v
		Sfx.set_sfx_volume(v))
	UITheme.make_heading(modal_content, "Video", 18, UITheme.AMBER)
	var dist_row := UITheme.make_hbox(modal_content, 8)
	for d in [[3, "Low"], [4, "Balanced"], [5, "Far"], [6, "Ultra"], [7, "Massive"]]:
		var b := UITheme.make_button(dist_row, str(d[1]), "primary" if Game.view_distance == int(d[0]) else "normal", 44, 14)
		b.pressed.connect(func():
			Game.view_distance = int(d[0])
			Game.save_settings()
			if world != null:
				world.view_distance = Game.view_distance
			_build_modal_content())
	UITheme.make_label(modal_content, "Settings are shared by all worlds and apply immediately. Longer render distances need a stronger device.", 12, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := UITheme.make_hbox(modal_content, 8)
	UITheme.make_button(row, "Reset Defaults", "normal", 46).pressed.connect(func():
		Game.reset_settings()
		if player != null:
			player.look_sensitivity = Game.look_sensitivity
		if world != null:
			world.view_distance = Game.view_distance
		Sfx.apply_volumes()
		_build_modal_content())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	UITheme.make_button(row, "Save & Back", "primary", 46).pressed.connect(func():
		Game.save_settings()
		open_pause())

func _toggle_row(label: String, value: bool, on_change: Callable) -> void:
	var row := UITheme.make_hbox(modal_content, 12)
	var l := UITheme.make_label(row, label, 14, UITheme.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := UITheme.make_button(row, "On" if value else "Off", "primary" if value else "normal", 40, 13)
	b.custom_minimum_size = Vector2(96, 40)
	b.pressed.connect(func():
		on_change.call(not value)
		Game.save_settings()
		_build_modal_content())

func _slider_row(label: String, min_v: float, max_v: float, value: float, on_change: Callable) -> void:
	var row := UITheme.make_hbox(modal_content, 12)
	var l := UITheme.make_label(row, label, 14, UITheme.INK)
	l.custom_minimum_size = Vector2(150, 0)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(300, 34)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(slider)
	var val_lbl := UITheme.make_label(row, "%.2f" % value, 13, UITheme.MUTED)
	val_lbl.custom_minimum_size = Vector2(54, 0)
	slider.value_changed.connect(func(v):
		val_lbl.text = "%.2f" % v
		on_change.call(v))
	slider.drag_ended.connect(func(_changed): Game.save_settings())

func _build_guide() -> void:
	var v := UITheme.make_vbox(modal_content, 10)
	UITheme.make_heading(v, "Welcome to MonsterCraft", 22, UITheme.AMBER)
	UITheme.make_label(v, "Welcome, Explorer! Break blocks, build a base, tame monsters, and face the dungeon guardians. Everything runs offline.", 15, UITheme.INK).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var controls := [
		["Move", "Left joystick / WASD"],
		["Look", "Drag the right side / mouse"],
		["Mine & attack", "Hold MINE / left click"],
		["Place blocks", "PLACE / right click"],
		["Use & interact", "USE / F"],
		["Partner skill", "SKILL / R"],
		["Bag & crafting", "BAG & CRAFT buttons / E & C"],
		["Quests, map, codex", "QUEST, MAP, CODEX buttons / J, M, K"],
	]
	for c in controls:
		var row := UITheme.make_hbox(v, 10)
		var name_l := UITheme.make_label(row, c[0], 14, UITheme.INK)
		name_l.custom_minimum_size = Vector2(230, 0)
		UITheme.make_label(row, c[1], 13, UITheme.MUTED)
	UITheme.make_label(v, "Tip: passive monsters can be tamed with Feed. Aggressive monsters must be weakened before capturing with a Capture Orb. Build a Ranch Banner for breeding and automated workers.", 13, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.make_button(v, "Back", "primary", 46).pressed.connect(open_pause)

func _build_starter() -> void:
	UITheme.make_label(modal_content, "Choose a partner to join you from the start. Every species can be found and raised in the world.", 14, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := UITheme.make_hbox(modal_content, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ids := ["spriggle", "emberpup", "pebbit"]
	for id in ids:
		var sp: Dictionary = Content.SPECIES[id]
		var card := UITheme.make_card(row)
		card.custom_minimum_size = Vector2(310, 430)
		var v := UITheme.make_vbox(card, 6)
		var portrait := TextureRect.new()
		portrait.texture = Content.get_monster_portrait(id)
		portrait.custom_minimum_size = Vector2(120, 120)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(portrait)
		UITheme.make_heading(v, str(sp.name), 22, Content.element_color(str(sp.element)))
		UITheme.make_label(v, "%s • %s" % [Content.element_name(str(sp.element)), Content.ability_name(str(sp.ability))], 13, UITheme.AMBER)
		UITheme.make_label(v, str(sp.lore), 12, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.make_label(v, "HP %d   ATK %d   DEF %d   SPD %.1f" % [int(sp.hp), int(sp.atk), int(sp.def), float(sp.spd)], 13, UITheme.INK)
		UITheme.make_label(v, Content.ability_desc(str(sp.ability)), 12, UITheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var b := UITheme.make_button(v, "Choose %s" % sp.name, "primary", 46)
		b.pressed.connect(_choose_starter.bind(id))
	UITheme.make_label(modal_content, "Feed and Capture Orbs can be crafted from the CRAFT menu.", 11, UITheme.MUTED)

func _choose_starter(species_id: String) -> void:
	Game.choose_starter(species_id)
	starter_open = false
	modal.visible = false
	modal_open = false
	modal_kind = ""
	get_tree().paused = false
	if player != null:
		player.input_enabled = true
	if not is_touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if spawner != null:
		spawner._refresh_companion()
	Sfx.play("level")
	_show_hint()

func _build_confirm() -> void:
	var v := UITheme.make_vbox(modal_content, 14)
	UITheme.make_label(v, str(modal_args.get("text", "")), 16, UITheme.INK).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := UITheme.make_hbox(v, 10)
	var yes := UITheme.make_button(row, "Yes, continue", "danger", 48)
	yes.pressed.connect(func():
		var cb := confirm_cb
		_close_modal()
		if cb.is_valid():
			cb.call())
	UITheme.make_button(row, "Cancel", "normal", 48).pressed.connect(_close_modal)

# ------------------------------------------------------------------ codex / party / quests / map / chest / npc / shop (to be filled)

func _build_codex_placeholder() -> void:
	pass
