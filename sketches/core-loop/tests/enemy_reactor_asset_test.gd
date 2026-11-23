extends SceneTree

const Reactor := preload("res://src/combat/reactor_relic.gd")
const Palette := preload("res://src/core/palette.gd")
const GLB := "res://assets/models/world_one/enemy_reactor.glb"
const BASE_CONSTS := {"VENT_RADIUS":5.5, "LEAD":1.0, "CHARGE":2.4, "CRATER":5.0,
	"ERUPT_DAMAGE":14.0, "ERUPT_LIFT":9.0, "BURN":4.0, "HP":140.0, "BODY_RADIUS":1.6, "BODY_HALF":1.2}
# Exact gameplay function hashes from base 38a1526; visual builders and _pose excluded.
const BASE_METHODS := {"_configure": "848f7ba725039013ee25dcbf1f41d2bf59a6e885fd553136a854868427599304", "_commit": "78ac8b66da03577966374696192be224cb96ca27572ca8938e60ac18760a05dc", "_go_live": "13aa02cb11373ae2ca066efb92a6ee762676bc3c3bbe6b96dc0bc72140476760", "_live": "7b62eb59fe7fa8dc2d39a8242303ade8247e04ae22901d72bfa1ef9025089ece"}
var failures := 0
var world: Node3D

func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	_run.call_deferred()

func _spawn(at: Vector3) -> Node3D:
	var enemy := Reactor.new()
	world.add_child(enemy)
	enemy.position = at
	enemy.setup(null, null, world, func(): return false, 1.0, {"kind":"reactor_relic"})
	enemy.set_physics_process(false)
	return enemy

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])

# MultiMesh geometry counts all live copies, while draws count its surfaces once.
func _assembly(node: Node3D) -> Array:
	var out := []
	for n in node.find_children("*", "GeometryInstance3D", true, false):
		if n is MeshInstance3D:
			out.append({"mesh":n.mesh, "xf":node.global_transform.affine_inverse() * n.global_transform, "node":n})
		elif n is MultiMeshInstance3D:
			var mm: MultiMesh = n.multimesh
			var count := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
			for i in count:
				out.append({"mesh":mm.mesh, "xf":node.global_transform.affine_inverse() * n.global_transform * (node._stacks[i] as Node3D).transform, "node":n})
	return out

func _mat(n: GeometryInstance3D, mesh: Mesh, s: int) -> Material:
	if n.material_override != null:
		return n.material_override
	if n is MeshInstance3D and n.get_surface_override_material(s) != null:
		return n.get_surface_override_material(s)
	return mesh.surface_get_material(s)

func _measure(node: Node3D) -> Dictionary:
	var tris := 0
	var draws := 0
	var seen := []
	var opaque := true
	var points := PackedVector3Array()
	for part in _assembly(node):
		var mesh: Mesh = part.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			var idx = a[Mesh.ARRAY_INDEX]
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			tris += (idx.size() if idx != null else vs.size()) / 3
			for v in vs:
				points.append(part.xf * v)
			var mat := _mat(part.node, mesh, s)
			if mat is BaseMaterial3D:
				opaque = opaque and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and is_equal_approx(mat.albedo_color.a, 1.0)
			elif mat is ShaderMaterial:
				opaque = opaque and not mat.shader.code.contains("ALPHA")
		if not part.node in seen:
			draws += mesh.get_surface_count()
			seen.append(part.node)
	return {"tris":tris, "draws":draws, "opaque":opaque, "points":points}

func _bounds(pts: PackedVector3Array) -> AABB:
	var lo := Vector3(INF,INF,INF)
	var hi := -lo
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return AABB(lo,hi-lo)

func _base(enemy: Node3D) -> void:
	var constants: Dictionary = enemy.get_script().get_script_constant_map()
	var same := true
	for key in BASE_CONSTS:
		same = same and constants.get(key) == BASE_CONSTS[key]
	_check(same, "all gameplay constants equal base")
	var source := FileAccess.get_file_as_string("res://src/combat/reactor_relic.gd")
	var immutable := true
	for method in BASE_METHODS:
		var regex := RegEx.new()
		regex.compile("(?ms)^func " + method + "\\(.*?(?=\\n\\n(?:#|func)|\\z)")
		var found := regex.search(source)
		immutable = immutable and found != null and found.get_string().strip_edges().sha256_text() == BASE_METHODS[method]
	_check(immutable, "every base gameplay source literal and function unchanged")
	_check(enemy.radius == 1.6 and enemy.half_height == 1.2 and enemy.weight == 4.0 and enemy.scrap_value == 10
		and enemy.walk_speed == 1.6 and enemy.keep_near == 14.0 and enemy.keep_far == 27.0 and enemy.attack_range == 30.0
		and enemy.warn_seconds == 2.4 and enemy.live_seconds == 5.0 and enemy.rest_seconds == 2.0
		and enemy.first_rest == 2.5 and not enemy.interruptible and enemy.max_hp == 140.0,
		"runtime health, tuning and keep_far 34 clamped to 27 equal base")
	var shapes := enemy.find_children("*", "CollisionShape3D", true, false)
	var cap: CapsuleShape3D = shapes[0].shape if shapes.size() == 1 else null
	print("CAPSULE: radius %s height %s transform %s objects %d" % [cap.radius, cap.height, shapes[0].transform, enemy.find_children("*", "CollisionObject3D", true, false).size()])
	_check(cap != null and is_equal_approx(cap.radius,1.2) and is_equal_approx(cap.height,2.4) and shapes[0].transform == Transform3D.IDENTITY
		and enemy.find_children("*", "CollisionObject3D", true, false).is_empty(), "one unchanged base capsule, clamped radius 1.2 height 2.4 and no added collider")

func _run() -> void:
	var enemy: Node3D = _spawn(Vector3(0,30,0))
	enemy.set_physics_process(false)
	await process_frame
	_base(enemy)
	var live := _measure(enemy)
	print("LIVE: %d T / %d D" % [live.tris,live.draws])
	_check(live.tris > 0 and live.tris <= 5100, "full live assembly triangle ceiling 5100 (polished; was 1200)")
	_check(live.draws > 0 and live.draws <= 3, "full live assembly draw ceiling 3")
	_check(live.opaque, "full live assembly opaque including shader surfaces")
	_check(enemy.find_children("*", "Light3D", true, false).is_empty(), "zero added lights")
	var body := enemy.find_child("ReactorBody",true,false) as MeshInstance3D
	var vents := enemy.find_child("ReactorStacks",true,false) as MultiMeshInstance3D
	_check(body != null and vents != null, "imported cast body and vent assembly replace primitives")
	if body == null or vents == null:
		print("enemy_reactor_asset_test: FAIL")
		quit(1)
		return
	_materials(enemy,body,vents)
	_forms(body,vents)
	var pose_ok := FileAccess.get_file_as_string("res://src/combat/reactor_relic.gd").contains("_vent_mesh.multimesh.set_instance_transform(i, stack.transform)")
	var envelope_ok := true
	var footprint_ok := true
	var charge_ok := true
	for progress in [0.0,0.5,1.0,2.0]:
		enemy.phase = enemy.Phase.WARN
		enemy._t = enemy.warn_seconds * progress
		enemy._pose()
		var swell: float = clampf(progress,0,1)
		for i in vents.multimesh.instance_count:
			var xf := (enemy._stacks[i] as Node3D).transform
			var angle: float = TAU * i / 3.0
			var pivot := Vector3(cos(angle)*0.8,1.6,sin(angle)*0.8)
			pose_ok = pose_ok and xf.origin.is_equal_approx(pivot) and xf.basis.get_scale().is_equal_approx(Vector3(1+0.2*swell,1+0.5*swell,1+0.2*swell))
			for s in vents.multimesh.mesh.get_surface_count():
				for v in vents.multimesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
					envelope_ok = envelope_ok and Vector2(v.x,v.z).length() <= 0.34+0.001 and absf(v.y) <= 0.60+0.001
		var m := _measure(enemy)
		var bounds := _bounds(m.points)
		print("POSE %.1f: bounds %s" % [progress,bounds])
		for p in m.points:
			footprint_ok = footprint_ok and Vector2(p.x,p.z).length() <= 1.2+0.001
			envelope_ok = envelope_ok and p.y >= -1.6-0.001 and p.y <= 2.5+0.001
		charge_ok = charge_ok and is_equal_approx(vents.material_override.get_shader_parameter("charge"),swell)
	_check(pose_ok and vents.multimesh.instance_count == 3, "three vent pivots at .8m radius and 1.2x width / 1.5x height swell at rest, half, full and clamped charge")
	_check(envelope_ok, "every point stays inside base moving envelope")
	_check(footprint_ok, "every point stays inside actual collider radial footprint 1.2 at every pose")
	_check(charge_ok, "vent light reads existing charge clock")
	var recovery_ok := true
	for phase in [enemy.Phase.ROAM,enemy.Phase.LIVE]:
		enemy.phase = phase
		enemy._t = 99.0
		enemy._pose()
		recovery_ok = recovery_ok and (enemy._stacks[0] as Node3D).basis == Basis.IDENTITY and is_zero_approx(vents.material_override.get_shader_parameter("charge"))
	_check(recovery_ok, "strike and recovery restore unswollen stacks and rest light")
	var other: Node3D = _spawn(Vector3(10,30,0))
	other.set_physics_process(false)
	# Its deferred dress (the bake's look, then InkOutline's welded mesh) runs before the bodies compare.
	await process_frame
	var other_body := other.find_child("ReactorBody",true,false) as MeshInstance3D
	var other_vents := other.find_child("ReactorStacks",true,false) as MultiMeshInstance3D
	_check(body.mesh == other_body.mesh and vents.multimesh.mesh == other_vents.multimesh.mesh
		and enemy._material != other._material and vents.material_override != other_vents.material_override,
		"cached glb meshes shared, flash and vent charge materials private")
	print("enemy_reactor_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _materials(enemy: Node3D, body: MeshInstance3D, vents: MultiMeshInstance3D) -> void:
	var scene := (load(GLB) as PackedScene).instantiate()
	var slot := -1
	var count := 0
	var asset_opaque := true
	for node in scene.find_children("*", "MeshInstance3D",true,false):
		for s in node.mesh.get_surface_count():
			var mat: StandardMaterial3D = node.mesh.surface_get_material(s)
			asset_opaque = asset_opaque and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_color.a == 1.0
			if mat.resource_name == "ancient_enamel":
				slot = s
				count += 1
				_check(_enamel_colors(node.mesh.surface_get_arrays(s)) and not mat.emission_enabled, "glb body ancient enamel capped and unlit")
	scene.free()
	_check(count == 1 and slot >= 0 and asset_opaque, "glb itself names exactly one opaque ancient_enamel body surface")
	var correct := slot >= 0
	for s in body.mesh.get_surface_count():
		correct = correct and ((body.get_surface_override_material(s) == enemy._material) == (s == slot))
	_check(correct, "enemy flashing material sits only on glb body slot")
	_check(enemy._base_color == Palette.VERDIGRIS and enemy._material.albedo_color == Palette.VERDIGRIS
		and enemy._material.albedo_color.s <= 0.45 and enemy._material.albedo_color.v <= 0.45
		and not enemy._material.emission_enabled and is_equal_approx(enemy._material.roughness,0.72),
		"ancient cast petrol enamel S/V <=45%, roughness .72, no rest emission")
	enemy.flash()
	enemy._update_flash(0.0)
	_check(enemy._material.albedo_color.is_equal_approx(Palette.VERDIGRIS.lerp(Color(1,1,0.85),1)) and enemy._material.emission_enabled,
		"existing hit flash reaches glb body")
	for i in 20:
		enemy._update_flash(0.1)
	_check(enemy._material.albedo_color == Palette.VERDIGRIS and not enemy._material.emission_enabled, "hit recovery restores unlit ancient petrol")
	var shader: ShaderMaterial = vents.material_override
	_check(shader.get_shader_parameter("ancient_light") == Palette.ANCIENT
		and shader.shader.code.contains("EMISSION = ancient_light.rgb * blue * (0.35 + 1.65 * charge)")
		and shader.shader.code.contains("step(COLOR.r * 1.8, COLOR.b) * step(COLOR.g * 1.4, COLOR.b)"),
		"Cherenkov light confined to blue vent band, no whole-body charge glow")

# Imported vertex colours are linear; the art cap is in display HSV.
func _enamel_colors(a: Array) -> bool:
	var colors: PackedColorArray = a[Mesh.ARRAY_COLOR]
	if colors.is_empty(): return false
	for color in colors:
		var c := color.linear_to_srgb()
		if c.s > 0.451 or c.v > 0.451 or c.a != 1.0: return false
	return true

func _forms(body: MeshInstance3D, vents: MultiMeshInstance3D) -> void:
	var points: PackedVector3Array = _measure(body.get_parent()).points
	var foot := 0.0
	var neck := 0.0
	var shoulder := 0.0
	var crown := 0.0
	for p in points:
		var r := Vector2(p.x,p.z).length()
		if p.y < -1.0: foot = maxf(foot,r)
		if absf(p.y+0.5)<0.02: neck = maxf(neck,r)
		if absf(p.y-0.28)<0.06: shoulder = maxf(shoulder,r)
		if p.y>1.35 and p.y<1.51: crown = maxf(crown,r)
	print("CAST: foot %.3f neck %.3f shoulder %.3f crown %.3f" % [foot,neck,shoulder,crown])
	_check(foot >= 1.15 and neck >= 0.79 and neck <= 0.84 and shoulder >= 1.10, "squat cooling waist: flared foot, narrow neck, wide shoulder")
	_check(crown > 0.20 and crown < 0.62, "low dome crown retained above broad shoulder")
	var mesh: Mesh = vents.multimesh.mesh
	var blue_area := 0.0
	var dark_area := 0.0
	var colors_ok := true
	var blue_lo := INF
	var blue_hi := -INF
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		colors_ok = colors_ok and colors.size() == vs.size()
		if colors.size() != vs.size(): continue
		for i in range(0,idx.size(),3):
			var c := colors[idx[i]].linear_to_srgb()
			var area := (vs[idx[i+1]]-vs[idx[i]]).cross(vs[idx[i+2]]-vs[idx[i]]).length()/2
			if c.b > c.r*1.8 and c.b > c.g*1.4:
				blue_area += area
				# All three corners: polished GLBs sort their vertices, so a triangle's first
				# corner no longer spans the band.
				for k in 3:
					blue_lo = minf(blue_lo,vs[idx[i+k]].y)
					blue_hi = maxf(blue_hi,vs[idx[i+k]].y)
			else:
				colors_ok = colors_ok and c.v <= 0.451 and c.s <= 0.451 and c.a == 1.0
				if c.v < 0.18: dark_area += area
	print("VENT: blue area %.3f m2, dark area %.3f m2, band height %.3f m" % [blue_area,dark_area,blue_hi-blue_lo])
	_check(colors_ok, "vent vertex paint present; nonlight enamel muted and opaque, no Fleet oxide or brass")
	_check(blue_area >= 0.15 and blue_hi-blue_lo >= 0.095 and dark_area >= blue_area*2,
		"broad blue charge band >=.15 m2 / .10m with twice-area dark recess per stack")
