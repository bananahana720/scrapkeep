extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Rules := preload("res://src/boss/boss_rules.gd")

const HOUSING := "res://assets/models/world_one/shell_cannon.glb"
static var housing_path := HOUSING
const FALL_SECONDS := 0.6
var module
var barrel: Node3D
var plug: Node3D
var bands: Array[MeshInstance3D] = []
var lit := 0
var fallen := false
var notes: Array = []
var _fall_time := 0.0
var _rest_basis := Basis.IDENTITY
static var _meshes := {}
static var _materials := {}


static func _material(key: String, tint: Color, glow := false) -> StandardMaterial3D:
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.65
		mat.emission_enabled = glow
		mat.emission = tint if glow else Color.BLACK
		mat.emission_energy_multiplier = 0.8 if glow else 0.0
		_materials[key] = mat
	return _materials[key]


static func _cylinder(key: String, radius: float, length: float, tint: Color, glow := false) -> CylinderMesh:
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = length
		mesh.radial_segments = 16
		mesh.material = _material(key, tint, glow)
		_meshes[key] = mesh
	return _meshes[key]


static func make(pilot: String):
	var gun = new()
	gun.name = "QuietGun"
	var cradle := MeshInstance3D.new()
	cradle.name = "EmptyCradle"
	cradle.mesh = _cylinder("cradle", 0.75, 0.18, Palette.VERDIGRIS)
	gun.add_child(cradle)
	if pilot == "remembered_cannon":
		return gun
	gun.barrel = Node3D.new()
	gun.barrel.name = "Barrel"
	gun.add_child(gun.barrel)
	gun.barrel.position.y = 0.7
	var housing: Node3D
	if ResourceLoader.exists(housing_path):
		var scene: Node = load(housing_path).instantiate()
		var source := scene.find_child("BarrelHousing", true, false)
		if source != null:
			housing = source.duplicate()
		scene.free()
	if housing == null:
		var greybox := MeshInstance3D.new()
		greybox.mesh = _cylinder("housing", 0.32, 1.6, Palette.VERDIGRIS)
		greybox.rotation.x = PI * 0.5
		housing = greybox
	housing.name = "BarrelHousing"
	gun.barrel.add_child(housing)
	for i in 4:
		var band := MeshInstance3D.new()
		band.name = "FamilyBand%d" % (i + 1)
		band.mesh = _cylinder("dark_band", 0.34, 0.055, Palette.CHARCOAL)
		band.rotation.x = PI * 0.5
		band.position.z = 0.5 - i * 0.32
		gun.barrel.add_child(band)
		gun.bands.append(band)
	gun.plug = MeshInstance3D.new()
	gun.plug.name = "BorePlug"
	gun.plug.mesh = _cylinder("plug", 0.25, 0.1, Palette.CHARCOAL)
	gun.plug.rotation.x = PI * 0.5
	gun.plug.position.z = -0.85
	gun.barrel.add_child(gun.plug)
	return gun


static func attach(owner):
	var pilot: String = owner.ctx.run.class_def.id if owner.ctx.run.class_def != null else ""
	var gun = make(pilot)
	gun.module = owner
	owner.add_child(gun)
	gun.global_position = owner.pad.global_position + Vector3(0.0, 1.0, -owner.PAD_RADIUS - 3.0)
	return gun


func _physics_process(delta: float) -> void:
	if module == null:
		return
	if not is_instance_valid(module) or not is_instance_valid(module.pad):
		queue_free()
		return
	step(delta)


func step(delta: float) -> void:
	if module == null or barrel == null:
		return
	if module.clock >= Rules.INTRO_SECONDS:
		while lit < clampi(module.phase, 0, 4):
			light_next()
	if module.state == module.DEFEATED and not fallen:
		fall()
	if fallen:
		_fall_time = minf(FALL_SECONDS, _fall_time + delta)
		plug.position.z = -0.85 - minf(1.0, _fall_time / 0.3) * 0.6
		plug.visible = _fall_time < 0.3
		var toward: Vector3 = module.ctx.player.shown_position() - barrel.global_position
		if Vector2(toward.x, toward.z).length() > 0.01:
			var basis := Basis.looking_at(Vector3(toward.x, 0.0, toward.z).normalized(), Vector3.UP)
			barrel.basis = _rest_basis.slerp(basis, smoothstep(0.0, 1.0, _fall_time / FALL_SECONDS))
			barrel.rotate_object_local(Vector3.RIGHT, sin(PI * _fall_time / FALL_SECONDS) * 0.12)


func _audio():
	var presentation = module.ctx.root.get("presentation") if module != null else null
	return presentation.audio if presentation != null else null


func light_next() -> void:
	if lit >= bands.size():
		return
	bands[lit].mesh = _live_band()
	var family: String = MindAttacks.FAMILIES[lit]
	notes.append(Harmony.family_note(family))
	lit += 1
	var audio = _audio()
	if audio != null:
		audio.cannon_family(family, true, "mind_quiet_gun_phase")


func fall() -> void:
	if fallen:
		return
	fallen = true
	_rest_basis = barrel.basis
	notes.append(Harmony.motif_notes("cannon"))
	var audio = _audio()
	if audio != null:
		audio.cannon_motif("mind_quiet_gun_fall", true)


func ending_ready() -> void:
	while lit < bands.size():
		bands[lit].mesh = _live_band()
		lit += 1
	if plug != null:
		plug.visible = false


static func _live_band() -> ArrayMesh:
	if not _meshes.has("dashed_band"):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 12:
			var a := TAU * i / 12.0
			var b := TAU * (i + 0.55) / 12.0
			var p := Vector3(cos(a) * 0.34, -0.028, sin(a) * 0.34)
			var q := Vector3(cos(b) * 0.34, -0.028, sin(b) * 0.34)
			for v in [p, q, p + Vector3.UP * 0.056, q, q + Vector3.UP * 0.056, p + Vector3.UP * 0.056]:
				surface.add_vertex(v)
		var mesh := surface.commit()
		mesh.surface_set_material(0, _material("dashed_band", Palette.ANCIENT, true))
		_meshes["dashed_band"] = mesh
	return _meshes["dashed_band"]
