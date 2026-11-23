extends SceneTree
# E1-09 (wave 46, ruling ek): Rivet's twin rivet revolvers, rivet_revolvers.glb, mounted by
# hero_assets.gd under the shell's WeaponRing in place of the laser pods (wave 46 3D blueprint
# sections 2.1, 2.2 and 3.1; 3D review sections 1.3 to 1.5).
#
# What it checks:
#   tree       RivetRevolvers > RevolverRig > Skeleton3D (Godot's import of the armature) > Revolvers,
#              one skinned mesh.
#   bones      mount > tool.L/R > slide.L/R and crane.L/R > drum.L/R, nine bones, every vertex
#              weighted whole to one bone, and each piece on its bone (barrel on slide, drum on drum).
#   budget     2 draws (paint, copper), triangles in TRIS and the detail class cap.
#   paint      every paint vertex carries alpha 0, so an equipped paint never recolours the tools.
#   reach      no vertex past REACH from the ball centre (3D review section 1.3).
#   closed     every edge of the welded mesh is shared by exactly two triangles.
#   mirror     the two tools mirror across the centre line, bones and vertices.
#   muzzles    shell_rivet.glb's LaserMuzzle_L/R sit on the barrel tips, bores forward, mirrored.
#   mount      fit_shell_into mounts the file under WeaponRing; Rivet draws 16 in play with it
#              (base and Calibrated); the muzzles stay on the tips with the ring yawed 30 degrees;
#              the carrier bank's ring hull holds the revolvers' furthest point.
#   heft       no heft layer (c2 to c5) reaches into the revolvers at any class: Pod and Core
#              layers stay inside the saddles' sweep, a WeaponRing layer out of both tools.
# The run must make EXPECTED_CHECKS checks, so an early return or a skipped loop fails it.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const T := preload("res://tests/support/t.gd")

const REVOLVERS := "res://assets/models/world_one/rivet_revolvers.glb"
const SHELL := "res://assets/models/world_one/shell_rivet.glb"
const VARIANT := "shell_rivet_calibrated"
const LAYER := "res://assets/models/world_one/shell_rivet_c%d.glb"
const BUDGETS := "res://assets/asset_budgets.json"
const EXPECTED_CHECKS := 20
const TRIS := Vector2i(1200, 2200)
const SLOTS := ["copper", "paint"]
const REACH := 1.35
const DRAW_CAP := 16
const MIRROR := 0.001
# Bone -> parent, as Godot imports them (bone names keep their dots; node names do not).
const BONES := {
	"mount": "", "tool.L": "mount", "slide.L": "tool.L", "crane.L": "tool.L", "drum.L": "crane.L",
	"tool.R": "mount", "slide.R": "tool.R", "crane.R": "tool.R", "drum.R": "crane.R",
}

var _t := T.new("rivet_revolvers_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := _load(REVOLVERS)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false) if scene != null else []
	var skel: Skeleton3D = skeletons[0] if skeletons.size() == 1 else null
	var mesh := skel.get_node_or_null("Revolvers") as MeshInstance3D if skel != null else null
	_t.check("RivetRevolvers > RevolverRig > Skeleton3D > Revolvers", scene != null and skel != null
		and String(scene.get_path_to(skel)) == "RivetRevolvers/RevolverRig/Skeleton3D" and mesh != null and mesh.skin != null,
		"scene %s, skeletons %s, skinned mesh %s" % [scene != null, skeletons.map(func(k): return scene.get_path_to(k)),
		mesh != null and mesh.skin != null])
	if mesh == null:
		if scene != null:
			scene.free()
		for i in EXPECTED_CHECKS - 2:
			_t.check("revolvers skipped", false)
		_finish()
		return
	root.add_child(scene)
	_bones(skel)
	_weights(skel, mesh)
	_budget(mesh)
	_reach_and_closed(mesh)
	_mirror(skel, mesh)
	var tips := _barrel_tips(skel, mesh)
	_muzzles(skel, tips)
	scene.queue_free()
	_mounted("")
	_mounted(VARIANT)
	_heft(mesh)
	_finish()


func _finish() -> void:
	_t.eq("check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


# --- helpers -------------------------------------------------------------------------------------

static func _load(path: String) -> Node3D:
	var packed := load(path) as PackedScene
	return packed.instantiate() as Node3D if packed != null else null


static func slot_of(mesh: Mesh, surface: int) -> String:
	var mat := mesh.surface_get_material(surface)
	return mat.resource_name if mat != null else ""


# Vertices of a mesh in `top`'s frame (rest pose for a skinned mesh), optionally one slot.
static func points(mi: MeshInstance3D, top: Node3D, slot := "") -> PackedVector3Array:
	var xf := top.global_transform.affine_inverse() * mi.global_transform
	var out := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		if slot != "" and slot_of(mi.mesh, s) != slot:
			continue
		for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
	return out


# Open and non-manifold edges of a mesh after welding by position (as check_manifold.py does):
# Vector2i(open, non-manifold). A closed mesh is (0, 0).
static func open_edges(mesh: Mesh) -> Vector2i:
	var uses := {}
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var keys: Array[Vector3i] = []
		for v in verts:
			keys.append(Vector3i(roundi(v.x * 1e5), roundi(v.y * 1e5), roundi(v.z * 1e5)))
		for i in range(0, idx.size(), 3):
			var tri := [keys[idx[i]], keys[idx[i + 1]], keys[idx[i + 2]]]
			if tri[0] == tri[1] or tri[1] == tri[2] or tri[0] == tri[2]:
				continue
			for k in 3:
				var a: Vector3i = tri[k]
				var b: Vector3i = tri[(k + 1) % 3]
				var key := [a, b] if [a.x, a.y, a.z] < [b.x, b.y, b.z] else [b, a]
				uses[key] = int(uses.get(key, 0)) + 1
	var open := 0
	var many := 0
	for key in uses:
		open += 1 if uses[key] == 1 else 0
		many += 1 if uses[key] > 2 else 0
	return Vector2i(open, many)


# Each vertex's one bone (rigid weights), in surface order; -1 where a vertex blends bones.
static func vertex_bones(skel: Skeleton3D, mi: MeshInstance3D) -> Array:
	var out := []
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(1, (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		for v in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
			var bone := -1
			var whole := 0
			for k in per:
				var w := weights[v * per + k]
				if w > 0.999:
					whole += 1
					bone = bones[v * per + k]
				elif w > 0.001:
					whole += 10
			var joint := bone if whole == 1 else -1
			# Skin binds map to skeleton bones by name or index.
			if joint >= 0 and mi.skin != null and joint < mi.skin.get_bind_count():
				var bind_name := mi.skin.get_bind_name(joint)
				joint = skel.find_bone(bind_name) if bind_name != "" else mi.skin.get_bind_bone(joint)
			out.append(joint)
	return out


# Rest positions of a skeleton's bones in `top`'s frame.
static func bone_at(skel: Skeleton3D, top: Node3D, bone: String) -> Vector3:
	var i := skel.find_bone(bone)
	return (top.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_rest(i)).origin if i >= 0 else Vector3.INF


# --- the model ---------------------------------------------------------------------------------

func _bones(skel: Skeleton3D) -> void:
	var got := {}
	for i in skel.get_bone_count():
		var parent := skel.get_bone_parent(i)
		got[skel.get_bone_name(i)] = skel.get_bone_name(parent) if parent >= 0 else ""
	_t.check("nine bones: mount > tool > slide, crane > drum, per side", got == BONES, "%s, want %s" % [got, BONES])


func _weights(skel: Skeleton3D, mesh: MeshInstance3D) -> void:
	var per_vertex := vertex_bones(skel, mesh)
	var blended := per_vertex.filter(func(b): return b < 0).size()
	_t.check("every vertex weighted whole to one bone", not per_vertex.is_empty() and blended == 0,
		"%d of %d vertices blend or carry no bone" % [blended, per_vertex.size()])
	# Each piece rides its bone: copper forward of the drum is barrel (slide), charcoal at the drum's
	# axis height between the frame blocks is drum.
	var top := skel.get_parent() as Node3D
	var wrong := []
	var k := 0
	for s in mesh.mesh.get_surface_count():
		var slot := slot_of(mesh.mesh, s)
		for v in mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var b: int = per_vertex[k]
			k += 1
			var side := "L" if v.x < 0.0 else "R"
			var bore := bone_at(skel, top, "slide." + side)
			var drum := bone_at(skel, top, "drum." + side)
			if slot == "copper" and v.z < bore.z - 0.01 and Vector2(v.x - bore.x, v.y - bore.y).length() < 0.04:
				if b != skel.find_bone("slide." + side):
					wrong.append("barrel %s" % v)
			elif slot == "paint" and absf(v.z - drum.z) < 0.03 and Vector2(v.x - drum.x, v.y - drum.y).length() < 0.045:
				if b != skel.find_bone("drum." + side):
					wrong.append("drum %s" % v)
	_t.check("barrel on slide, drum on drum", wrong.is_empty(), "%d misplaced: %s" % [wrong.size(), wrong.slice(0, 3)])


func _budget(mesh: MeshInstance3D) -> void:
	var slots := []
	var tris := 0
	for s in mesh.mesh.get_surface_count():
		slots.append(slot_of(mesh.mesh, s))
		tris += (mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	slots.sort()
	var cap: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS))["classes"]["detail"]
	_t.check("2 draws: paint and copper", slots == SLOTS, str(slots))
	_t.check("triangles in band and within the detail cap", tris >= TRIS.x and tris <= TRIS.y and tris <= int(cap.tris),
		"%d tris in %d..%d, detail cap %d" % [tris, TRIS.x, TRIS.y, cap.tris])
	var alphas := []
	for s in mesh.mesh.get_surface_count():
		if slot_of(mesh.mesh, s) == "paint":
			alphas.append_array(Array(mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]))
	var painted := alphas.filter(func(c): return c.a >= 0.05).size()
	_t.check("paint keeps its colour under any equipped paint (alpha 0)", not alphas.is_empty() and painted == 0,
		"%d of %d paint vertices take paint" % [painted, alphas.size()])


func _reach_and_closed(mesh: MeshInstance3D) -> void:
	var far := 0.0
	for v in points(mesh, mesh.get_parent().get_parent() as Node3D):
		far = maxf(far, v.length())
	_t.check("reach within 1.35 m of the ball centre", far > 1.2 and far <= REACH, "%.4f m" % far)
	var edges := open_edges(mesh.mesh)
	_t.check("closed: no open or non-manifold edge", edges == Vector2i.ZERO, "%d open, %d non-manifold" % [edges.x, edges.y])


func _mirror(skel: Skeleton3D, mesh: MeshInstance3D) -> void:
	var top := skel.get_parent() as Node3D
	var off := 0.0
	for kind in ["tool", "slide", "crane", "drum"]:
		var l := bone_at(skel, top, kind + ".L")
		var r := bone_at(skel, top, kind + ".R")
		off = maxf(off, (l * Vector3(-1, 1, 1)).distance_to(r))
	var left := {}
	var right := {}
	for v in points(mesh, top):
		var key := Vector3i(roundi(absf(v.x) * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))
		(left if v.x < 0.0 else right)[key] = true
	var unmatched := left.keys().filter(func(k): return not right.has(k)).size() + right.keys().filter(func(k): return not left.has(k)).size()
	_t.check("the tools mirror across the centre line", off < MIRROR and unmatched == 0 and left.size() > 100,
		"bone offset %.5f m, %d unmatched of %d / %d vertex positions" % [off, unmatched, left.size(), right.size()])


# Each barrel's crown centre (the furthest-forward copper on the bore) in the model's frame.
func _barrel_tips(skel: Skeleton3D, mesh: MeshInstance3D) -> Dictionary:
	var top := skel.get_parent() as Node3D
	var tips := {}
	for side in ["L", "R"]:
		var bore := bone_at(skel, top, "slide." + side)
		var front := INF
		for v in points(mesh, top, "copper"):
			if (v.x < 0.0) == (side == "L") and Vector2(v.x - bore.x, v.y - bore.y).length() < 0.05:
				front = minf(front, v.z)
		tips[side] = Vector3(bore.x, bore.y, front)
	return tips


func _muzzles(skel: Skeleton3D, tips: Dictionary) -> void:
	var shell := _load(SHELL)
	if shell == null:
		_t.check("muzzles on the barrel tips", false, SHELL)
		_t.check("muzzles mirrored and forward", false, SHELL)
		return
	root.add_child(shell)
	var far := 0.0
	var fire := []
	var at := {}
	for side in ["L", "R"]:
		var m := shell.find_child("LaserMuzzle_" + side, true, false) as Node3D
		if m == null:
			far = INF
			continue
		var p := (shell.global_transform.affine_inverse() * m.global_transform).origin
		at[side] = p
		far = maxf(far, p.distance_to(tips[side] + Vector3(0, 0, -0.01)))
		fire.append(-(m.global_basis.z).normalized())
	_t.check("muzzles on the barrel tips, 1 cm past the crown", far < 0.002, "%.4f m from the tips %s" % [far, tips])
	_t.check("muzzles mirrored and forward", at.size() == 2 and absf(at.L.x + at.R.x) < 0.001 and at.L.x < -0.3
		and fire.size() == 2 and fire.all(func(f): return f.dot(Vector3(0, 0, -1)) > 0.9999), "%s, firing %s" % [at, fire])
	shell.queue_free()


# --- mounted as the game mounts it -------------------------------------------------------------

func _mounted(variant: String) -> void:
	var label := variant if variant != "" else "shell_rivet"
	var hook := HeroAssets.new()
	root.add_child(hook)
	var ball := Node3D.new()
	root.add_child(ball)
	var rec: Dictionary = hook.fit_shell_into(ball, "runner_gunner", variant, 1, {})
	var pod: Node3D = rec.get("pod")
	var ring: Node3D = pod.get_node_or_null("WeaponRing") if pod != null else null
	var weapon: Node3D = ring.get_node_or_null(HeroAssets.WEAPON_NODE) if ring != null else null
	var guns := weapon.find_child("Revolvers", true, false) as MeshInstance3D if weapon != null else null
	_t.check(label + ": revolvers mounted under WeaponRing", guns != null and guns.is_visible_in_tree() and rec.get("variant") == variant
		and weapon.transform.is_equal_approx(Transform3D.IDENTITY), "ring %s, weapon %s, mesh %s" % [ring != null, weapon != null, guns != null])
	if guns == null:
		for i in (3 if variant == "" else 1):
			_t.check(label + " skipped", false)
		ball.free()
		hook.free()
		return
	var draws := 0
	var drawn := {}
	for part in [rec.core, rec.pod]:
		var views: Array = (part as Node).find_children("*", "MeshInstance3D", true, false)
		if part is MeshInstance3D:
			views.append(part)
		for mi: MeshInstance3D in views:
			var placeholder := mi.name == &"Pilot" and mi.get_parent() != null and mi.get_parent().name == &"Dome"
			if mi.is_visible_in_tree() and mi.layers != 0 and not placeholder:
				draws += mi.mesh.get_surface_count()
				drawn[String(mi.name)] = mi.mesh.get_surface_count()
	_t.check(label + ": 16 draws in play with the revolvers", draws == DRAW_CAP, "%d draws %s, cap %d" % [draws, drawn, DRAW_CAP])
	if variant == "":
		_yawed(hook, pod, ring, guns)
		var hull: PackedVector3Array = HeroAssets._bank_hull(pod)["ring"]
		var reach := 0.0
		for p in hull:
			reach = maxf(reach, p.length())
		var gun_reach := 0.0
		for v in points(guns, ring):
			gun_reach = maxf(gun_reach, v.length())
		_t.check("the carrier bank's ring hull holds the revolvers", absf(reach - gun_reach) < 0.001 and gun_reach > 1.2,
			"hull reach %.4f, revolvers %.4f" % [reach, gun_reach])
	ball.free()
	hook.free()


# Aimed 30 degrees off the heading, each muzzle still sits 1 cm past its barrel's crown, read from
# the mounted mesh's world vertices.
func _yawed(hook: Node, pod: Node3D, ring: Node3D, guns: MeshInstance3D) -> void:
	var want := deg_to_rad(30.0)
	hook.steer_weapon_ring(pod, Vector3(-sin(want), 0.0, -cos(want)), 10.0)
	var fwd := -ring.global_basis.z.normalized()
	var off := 0.0
	for side in ["L", "R"]:
		var m := ring.get_node_or_null("LaserMuzzle_" + side) as Node3D
		if m == null:
			off = INF
			continue
		var near: Array[Vector3] = []
		for s in guns.mesh.get_surface_count():
			if slot_of(guns.mesh, s) != "copper":
				continue
			for v in guns.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var w: Vector3 = guns.global_transform * v
				var rel := w - m.global_position
				if (rel - fwd * rel.dot(fwd)).length() < 0.05:
					near.append(w)
		var front := -INF
		for w in near:
			front = maxf(front, w.dot(fwd))
		var crown := Vector3.ZERO
		var n := 0
		for w in near:
			if w.dot(fwd) > front - 0.0005:
				crown += w
				n += 1
		off = maxf(off, m.global_position.distance_to(crown / maxf(1.0, n) + fwd * 0.01) if n > 0 else INF)
	var yaw := rad_to_deg(atan2(-fwd.x, -fwd.z))
	_t.check("muzzles stay on the tips with the ring yawed 30 degrees", off < 0.002 and absf(absf(yaw) - 30.0) < 1.0,
		"%.4f m off, ring yaw %.1f degrees" % [off, yaw])


# --- heft layers -------------------------------------------------------------------------------

# Pod and Core layers turn with the heading, the revolvers with the aim, so a Pod or Core vertex
# must stay inside the horizontal radius the revolvers never come within (the saddles' inner face)
# or below or above the revolvers' height band. A layer's WeaponRing rides the base ring, so its
# vertices only stay out of either tool's box.
func _heft(mesh: MeshInstance3D) -> void:
	var top := mesh.get_parent().get_parent() as Node3D
	var inner := INF
	var low := INF
	var high := -INF
	var boxes := {"L": AABB(), "R": AABB()}
	var started := {"L": false, "R": false}
	for v in points(mesh, top):
		inner = minf(inner, Vector2(v.x, v.z).length())
		low = minf(low, v.y)
		high = maxf(high, v.y)
		var side := "L" if v.x < 0.0 else "R"
		if not started[side]:
			boxes[side] = AABB(v, Vector3.ZERO)
			started[side] = true
		else:
			boxes[side] = (boxes[side] as AABB).expand(v)
	var hits := []
	var loaded := 0
	for n in [2, 3, 4, 5]:
		var layer := _load(LAYER % n)
		if layer == null:
			continue
		loaded += 1
		root.add_child(layer)
		for mi: MeshInstance3D in layer.find_children("*", "MeshInstance3D", true, false):
			var on_ring := mi.get_parent() != null and String(mi.name) == "WeaponRing"
			for v in points(mi, layer):
				var swept := Vector2(v.x, v.z).length() >= inner - 0.01 and v.y > low - 0.01 and v.y < high + 0.01
				var boxed := (boxes.L as AABB).grow(0.01).has_point(v) or (boxes.R as AABB).grow(0.01).has_point(v)
				if (on_ring and boxed) or (not on_ring and swept):
					hits.append("c%d %s %s" % [n, mi.name, v])
		layer.queue_free()
	_t.check("no heft layer reaches into the revolvers at any class", loaded == 4 and hits.is_empty() and inner > 0.99,
		"%d layers, revolvers from %.3f m, height %.3f to %.3f; %d hits %s" % [loaded, inner, low, high, hits.size(), hits.slice(0, 3)])
