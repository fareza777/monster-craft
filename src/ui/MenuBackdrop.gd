class_name MenuBackdrop
extends Node3D

var camera: Camera3D
var _time := 0.0
var _monsters: Array[MonsterModel] = []
var _monster_roots: Array[Node3D] = []
var _box_batches: Dictionary = {}
var _clouds: Array[Node3D] = []
var _cloud_time := 0.0

func _ready() -> void:
	_build_environment()
	_build_island()
	_build_monsters()
	_commit_boxes()
	_build_clouds()

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#3f7796")
	sky_mat.sky_horizon_color = Color("#f0bd88")
	sky_mat.ground_bottom_color = Color("#234551")
	sky_mat.ground_horizon_color = Color("#7ba4ad")
	sky_mat.sun_angle_max = 12.0
	sky_mat.sun_curve = 0.18
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("#c89c83")
	env.fog_density = 0.006
	env.fog_sky_affect = 0.25
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, 38, 0)
	sun.light_energy = 1.15
	sun.light_color = Color("#ffe0b8")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 2.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -120, 0)
	fill.light_energy = 0.22
	fill.light_color = Color("#8fc4dc")
	fill.shadow_enabled = false
	add_child(fill)
	camera = Camera3D.new()
	camera.fov = 46.0
	camera.near = 0.1
	camera.far = 120.0
	camera.current = true
	add_child(camera)
	var sea_mat := StandardMaterial3D.new()
	sea_mat.albedo_color = Color("#3d7585")
	sea_mat.roughness = 1.0
	sea_mat.metallic = 0.0
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	plane.material = sea_mat
	sea.mesh = plane
	sea.position = Vector3(0, -7.5, 0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffcf7a")
	light.light_energy = 1.2
	light.omni_range = 7.0
	light.position = Vector3(2, 1.2, 2.5)
	add_child(light)

func _add_box(color: Color, pos: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO,
		emissive: bool = false) -> void:
	var key := color.to_html() + ("_e" if emissive else "")
	if not _box_batches.has(key):
		_box_batches[key] = {"color": color, "emissive": emissive, "transforms": []}
	var b := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))).scaled(size)
	var t := Transform3D(b, pos)
	_box_batches[key].transforms.append(t)

func _commit_boxes() -> void:
	for key in _box_batches:
		var batch: Dictionary = _box_batches[key]
		var transforms: Array = batch.transforms
		if transforms.is_empty():
			continue
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var mat := StandardMaterial3D.new()
		mat.albedo_color = batch.color
		mat.roughness = 0.92
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if batch.color.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if batch.emissive:
			mat.emission_enabled = true
			mat.emission = batch.color
			mat.emission_energy_multiplier = 0.45
		mesh.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)

func _build_island() -> void:
	var grass := Color("#6fbf5e")
	var grass_dark := Color("#548c48")
	var dirt := Color("#7b5839")
	var stone := Color("#6f777d")
	var stone_dark := Color("#555c61")
	for x in range(-5, 6):
		for z in range(-5, 6):
			var r := sqrt(x * x + z * z)
			if r > 5.9:
				continue
			var edge := r > 4.6
			var top_y := -0.5 - (1.0 if edge and (x + z) % 2 == 0 else 0.0)
			_add_box(grass if (x + z) % 4 != 0 else grass_dark, Vector3(x, top_y, z), Vector3.ONE)
			_add_box(dirt, Vector3(x, top_y - 1.0, z), Vector3.ONE)
			if r < 4.8:
				_add_box(stone, Vector3(x, top_y - 2.0, z), Vector3.ONE)
			if r < 3.7:
				_add_box(stone_dark, Vector3(x, top_y - 3.0, z), Vector3.ONE)
			if r < 2.3:
				_add_box(stone_dark.darkened(0.08), Vector3(x, top_y - 4.0, z), Vector3.ONE)
	# water pool
	for p in [Vector2(2, 2), Vector2(3, 2), Vector2(2, 3), Vector2(3, 3)]:
		_add_box(Color(0.22, 0.55, 0.72, 0.82), Vector3(p.x, -0.02, p.y), Vector3(1, 0.12, 1))
	# tree
	var trunk := Color("#6c4a2b")
	for i in 3:
		_add_box(trunk, Vector3(-2, 0.5 + i, -2), Vector3(0.8, 1, 0.8))
	_add_box(Color("#3e8748"), Vector3(-2, 3.5, -2), Vector3(2.6, 1.2, 2.6))
	_add_box(Color("#4f9d58"), Vector3(-2, 4.4, -2), Vector3(1.8, 0.9, 1.8))
	_add_box(Color("#3e8748"), Vector3(-3, 3.9, -1.5), Vector3(1.2, 1.0, 1.2))
	_add_box(Color("#3e8748"), Vector3(-1, 4.0, -2.6), Vector3(1.2, 1.0, 1.2))
	# grass tufts and flowers
	for p in [Vector3(-1, 0.15, 2), Vector3(1.5, 0.15, 0.2), Vector3(-3, 0.15, 1.5),
			Vector3(0.2, 0.15, 3), Vector3(2.8, 0.15, -1.8)]:
		_add_box(Color("#7fd36b"), p, Vector3(0.12, 0.32, 0.12))
	for p in [Vector3(-1.2, 0.25, 2.2), Vector3(2.1, 0.22, 1.2), Vector3(-3.2, 0.22, 2.4)]:
		_add_box(Color("#e76a6a"), p, Vector3(0.18, 0.18, 0.18), Vector3.ZERO, true)
	# crystals
	for spec in [[Vector3(3.5, 0.5, -2.2), 0.35, 1.6, Color("#6fe4d4")],
			[Vector3(4.0, 0.3, -1.4), 0.25, 1.1, Color("#8fdbc8")],
			[Vector3(4.2, 0.2, -2.8), 0.2, 0.9, Color("#6fe4d4")]]:
		_add_box(spec[3], spec[0], Vector3(spec[1], spec[2], spec[1]), Vector3(12, 30, 8), true)
	# campfire and logs
	for i in 4:
		_add_box(Color("#6b492e"), Vector3(1.6 + (i - 1.5) * 0.3, 0.08, 2.5), Vector3(0.5, 0.16, 0.16), Vector3(0, 25, 0))
	_add_box(Color("#ff9b4a"), Vector3(1.6, 0.35, 2.5), Vector3(0.3, 0.35, 0.3), Vector3.ZERO, true)
	_add_box(Color("#ffd166"), Vector3(1.6, 0.62, 2.5), Vector3(0.16, 0.3, 0.16), Vector3.ZERO, true)
	# banner
	_add_box(Color("#6f4e2c"), Vector3(-4, 1.0, 3.0), Vector3(0.16, 2.6, 0.16))
	_add_box(Color("#2f7d6e"), Vector3(-3.4, 1.8, 3.0), Vector3(1.1, 0.9, 0.08))
	_add_box(Color("#e8dcc0"), Vector3(-3.7, 1.85, 3.0), Vector3(0.25, 0.25, 0.1), Vector3.ZERO, true)

func _build_monsters() -> void:
	var specs := [["spriggle", Vector3(2.7, 0.0, 3.4), 0.3], ["breezel", Vector3(1.6, 1.2, 2.7), 2.4], ["pebbit", Vector3(4.0, 0.0, 1.8), -0.4]]
	for spec in specs:
		var root := Node3D.new()
		root.position = spec[1]
		root.rotation.y = spec[2]
		root.scale = Vector3(1.45, 1.45, 1.45)
		add_child(root)
		var m := MonsterModel.new()
		root.add_child(m)
		m.build(str(spec[0]), "normal", false)
		_monsters.append(m)
		_monster_roots.append(root)

func _build_clouds() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.96, 0.92, 0.86)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = mat
	for i in 6:
		var cloud := Node3D.new()
		cloud.position = Vector3(-12 + i * 4.6, 5.0 + (i % 3) * 0.9, -11 - i * 2.0)
		add_child(cloud)
		for j in 3:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3((j - 1) * 1.3, (j % 2) * 0.35, (j % 2) * 0.5)
			mi.scale = Vector3(1.7 + (j % 2) * 0.9, 0.35, 1.15)
			cloud.add_child(mi)
		_clouds.append(cloud)

func _process(delta: float) -> void:
	_time += delta
	_cloud_time += delta
	if camera != null:
		var angle := 0.72 + sin(_time * 0.05) * 0.2
		var dist := 18.5
		camera.position = Vector3(cos(angle) * dist, 6.8 + sin(_time * 0.22) * 0.18, sin(angle) * dist)
		camera.look_at(Vector3(-2.2, 0.5, 0), Vector3.UP)
	for i in _monsters.size():
		var m := _monsters[i]
		if m == null:
			continue
		m.animate(delta, 0.6 + 0.2 * sin(_time * 0.7 + i))
		if _monster_roots[i] != null:
			var base_y: float = [0.0, 1.2, 0.0][i]
			_monster_roots[i].position.y = base_y + sin(_time * 1.3 + i * 1.8) * 0.06
			if i == 0:
				_monster_roots[i].rotation.y = 0.2 + sin(_time * 0.4) * 0.25
	for i in _clouds.size():
		var c := _clouds[i]
		c.position.x += delta * (0.22 + i * 0.03)
		if c.position.x > 16.0:
			c.position.x = -16.0
