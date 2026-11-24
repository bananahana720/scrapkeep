extends SceneTree
# E2-03 (wave 46, ruling en): Kest's clacker, kest_clacker.glb, mounted by hero_assets.gd on the
# shell's Pod beside her right yoke (WEAPONS, COCKPIT_WEAPONS, mount_weapon), and the throw that
# snaps it: clips/kest.json's machinery rows snap the handle shut, kick the mortar pods back and
# flick the vent slats on every shot (wave 46 3D review, Kest "cook and snap").
#
# What it checks:
#   tree       KestClacker > ClackerRig > Skeleton3D (Godot's import of the armature) > Clacker,
#              one skinned mesh.
#   bones      mount > lever, every vertex weighted whole to one bone; the handle, knob and pin
#              (copper) on lever, every paint piece on mount, the knob the highest point.
#   budget     2 draws (paint, copper), triangles in TRIS and the detail class cap.
#   paint      every paint vertex carries alpha 0, so an equipped paint never recolours it.
#   reach      no vertex past REACH from the ball centre: it rides inside the gimbal's sweep.
#   closed     every edge of the welded mesh is shared by exactly two triangles.
#   mount      fit_shell_into mounts the file on Pod at identity (not on the ring, so it stays at
#              her hands while the ring aims); Kest draws 16 in play with it, base and Roost
#              Frame; the ink pass lines it; it keeps out of the chase sight cone and the yoke
#              grip; no heft layer reaches into it.
#   snap       the shell's machinery rows resolve with no skip line; one shot snaps the lever 24
#              degrees shut in 0.04 s and drops the handle, kicks the Mortar 9 cm back and flicks
#              both vent blades 22 degrees open, and all of it is home again 0.4 s later.
# The run must make EXPECTED_CHECKS checks, so an early return or a skipped loop fails it.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Mecha := preload("res://src/presentation/mecha_motion.gd")
const Revolvers := preload("res://tests/rivet_revolvers_test.gd")
const ShellTest := preload("res://tests/world_one_shell_kest_test.gd")
const T := preload("res://tests/support/t.gd")

const CLACKER := "res://assets/models/world_one/kest_clacker.glb"
const LAYER := "res://assets/models/world_one/shell_kest_c%d.glb"
const BUDGETS := "res://assets/asset_budgets.json"
const PILOT := "demolitions_caster"
const VARIANT := "shell_kest_roost"
const EXPECTED_CHECKS := 21
const TRIS := Vector2i(150, 600)
const SLOTS := ["copper", "paint"]
const REACH := 0.80
const DRAW_CAP := 16
const BONES := {"mount": "", "lever": "mount"}
const DT := 0.002
const SNAP_DEG := -24.0
const SNAP_S := 0.04
const KICK_M := 0.09
const FLICK_DEG := 22.0
# The right hand's hold on the yoke grip (shell_base CONTROLS Grip.R): the clacker keeps this far off.
const GRIP_CLEAR := 0.07

var _t := T.new("kest_clacker_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Mecha.echo = false
	var scene := Revolvers._load(CLACKER)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false) if scene != null else []
	var skel: Skeleton3D = skeletons[0] if skeletons.size() == 1 else null
	var mesh := skel.get_node_or_null("Clacker") as MeshInstance3D if skel != null else null
	_t.check("KestClacker > ClackerRig > Skeleton3D > Clacker", scene != null and skel != null
		and String(scene.get_path_to(skel)) == "KestClacker/ClackerRig/Skeleton3D" and mesh != null and mesh.skin != null,
		"scene %s, skeletons %s, skinned mesh %s" % [scene != null, skeletons.map(func(k): return scene.get_path_to(k)),
		mesh != null and mesh.skin != null])
	if mesh == null:
		if scene != null:
			scene.free()
		for i in EXPECTED_CHECKS - 2:
			_t.check("clacker skipped", false)
		_finish()
		return
	root.add_child(scene)
	_bones(skel, mesh)
	_budget(mesh)
	_reach_and_closed(mesh)
	var box := _box(mesh)
	_mounted("", box)
	_mounted(VARIANT, box)
	_heft(box)
	scene.queue_free()
	_finish()


func _finish() -> void:
	_t.eq("check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


# --- the model ---------------------------------------------------------------------------------

func _bones(skel: Skeleton3D, mesh: MeshInstance3D) -> void:
	var got := {}
	for i in skel.get_bone_count():
		var parent := skel.get_bone_parent(i)
		got[skel.get_bone_name(i)] = skel.get_bone_name(parent) if parent >= 0 else ""
	_t.check("two bones: mount > lever", got == BONES, "%s, want %s" % [got, BONES])
	var per_vertex := Revolvers.vertex_bones(skel, mesh)
	var blended := per_vertex.filter(func(b): return b < 0).size()
	_t.check("every vertex weighted whole to one bone", not per_vertex.is_empty() and blended == 0,
		"%d of %d vertices blend or carry no bone" % [blended, per_vertex.size()])
	var lever := skel.find_bone("lever")
	var wrong := 0
	var top := -INF
	var top_bone := -1
	var k := 0
	for s in mesh.mesh.get_surface_count():
		var slot := Revolvers.slot_of(mesh.mesh, s)
		for v: Vector3 in mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var b: int = per_vertex[k]
			k += 1
			if (b == lever) != (slot == "copper" and v.y > 0.03):
				wrong += 1
			if v.y > top:
				top = v.y
				top_bone = b
	_t.check("handle, knob and pin on lever, the rest on mount", wrong == 0 and top_bone == lever,
		"%d vertices on the wrong bone; the highest point (%.3f) on bone %d, lever %d" % [wrong, top, top_bone, lever])


func _budget(mesh: MeshInstance3D) -> void:
	var slots := []
	var tris := 0
	for s in mesh.mesh.get_surface_count():
		slots.append(Revolvers.slot_of(mesh.mesh, s))
		tris += (mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	slots.sort()
	var cap: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS))["classes"]["detail"]
	_t.check("2 draws: paint and copper (no glow: the fuses stay Kest's only one)", slots == SLOTS, str(slots))
	_t.check("triangles in band and within the detail cap", tris >= TRIS.x and tris <= TRIS.y and tris <= int(cap.tris),
		"%d tris in %d..%d, detail cap %d" % [tris, TRIS.x, TRIS.y, cap.tris])
	var alphas := []
	for s in mesh.mesh.get_surface_count():
		if Revolvers.slot_of(mesh.mesh, s) == "paint":
			alphas.append_array(Array(mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]))
	var painted := alphas.filter(func(c): return c.a >= 0.05).size()
	_t.check("paint keeps its colour under any equipped paint (alpha 0)", not alphas.is_empty() and painted == 0,
		"%d of %d paint vertices take paint" % [painted, alphas.size()])


func _reach_and_closed(mesh: MeshInstance3D) -> void:
	var far := 0.0
	for v in Revolvers.points(mesh, mesh.get_parent().get_parent().get_parent() as Node3D):
		far = maxf(far, v.length())
	_t.check("reach inside the gimbal sweep", far > 0.6 and far <= REACH, "%.4f m, limit %.2f" % [far, REACH])
	var edges := Revolvers.open_edges(mesh.mesh)
	_t.check("closed: no open or non-manifold edge", edges == Vector2i.ZERO, "%d open, %d non-manifold" % [edges.x, edges.y])


# The clacker's bounds in the file's (the Pod's) frame, the handle raised.
func _box(mesh: MeshInstance3D) -> AABB:
	var pts := Revolvers.points(mesh, mesh.get_parent().get_parent().get_parent() as Node3D)
	var box := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box = box.expand(p)
	return box


# --- mounted as the game mounts it -------------------------------------------------------------

func _mounted(variant: String, box: AABB) -> void:
	var label := variant if variant != "" else "shell_kest"
	var hook := HeroAssets.new()
	hook.set_process(false)
	root.add_child(hook)
	var ball := Node3D.new()
	root.add_child(ball)
	var rec: Dictionary = hook.fit_shell_into(ball, PILOT, variant, 1, {})
	var pod: Node3D = rec.get("pod")
	var weapon: Node3D = pod.get_node_or_null(HeroAssets.WEAPON_NODE) if pod != null else null
	var clacker := weapon.find_child("Clacker", true, false) as MeshInstance3D if weapon != null else null
	var ring_held: bool = pod != null and pod.get_node_or_null("WeaponRing/" + HeroAssets.WEAPON_NODE) != null
	_t.check(label + ": clacker mounted on Pod at identity", clacker != null and clacker.is_visible_in_tree()
		and rec.get("variant") == variant and weapon.transform.is_equal_approx(Transform3D.IDENTITY) and not ring_held,
		"pod %s, weapon %s, mesh %s, on the ring %s" % [pod != null, weapon != null, clacker != null, ring_held])
	if clacker == null:
		for i in (6 if variant == "" else 1):
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
	_t.check(label + ": 16 draws in play with the clacker", draws == DRAW_CAP, "%d draws %s, cap %d" % [draws, drawn, DRAW_CAP])
	if variant == "":
		_inked(clacker)
		_clear(pod, clacker, box)
		_snap(rec, clacker)
	ball.free()
	hook.free()


func _inked(clacker: MeshInstance3D) -> void:
	var lined := 0
	for i in clacker.mesh.get_surface_count():
		var mat := clacker.get_active_material(i)
		if mat != null and (mat.has_meta("ink_source") or (mat.next_pass != null and mat.next_pass.has_meta("ink_role"))):
			lined += 1
	_t.check("the ink pass lines both surfaces", lined == clacker.mesh.get_surface_count(), "%d of %d lined" % [lined, clacker.mesh.get_surface_count()])


# No clacker vertex in the chase sight cone or within GRIP_CLEAR of the yoke grip the pilot's
# right hand holds.
func _clear(pod: Node3D, clacker: MeshInstance3D, box: AABB) -> void:
	var cone := 0
	var near := INF
	var grip := pod.find_child("Control_Grip_R", true, false) as Node3D
	var hold := (pod.global_transform.affine_inverse() * grip.global_transform).origin if grip != null else Vector3.INF
	for p in Revolvers.points(clacker, pod):
		if ShellTest.in_cone(p):
			cone += 1
		near = minf(near, p.distance_to(hold))
	_t.check("clear of the sight cone and the right grip", grip != null and cone == 0 and near >= GRIP_CLEAR,
		"%d in the cone, %.3f m from the grip at %s (want %.2f; clacker %s)" % [cone, near, hold, GRIP_CLEAR, box])


# One shot through the shell's own machinery rows: the clacker snaps, the mortar kicks, the vents
# flick, and everything is home 0.4 s later.
func _snap(rec: Dictionary, clacker: MeshInstance3D) -> void:
	var table = JSON.parse_string(FileAccess.get_file_as_string("res://src/presentation/clips/kest.json"))
	var rows: Array = Array(table.get("machinery", []))
	var motion = Mecha.new(rec.pod, rec.core, PILOT, rows)
	var skips: Array = motion.skip_lines.filter(func(l): return "Weapon" in l or "Mortar" in l or "Vane" in l)
	_t.check("the throw rows resolve on the fitted shell", skips.is_empty(), "skip lines %s" % [skips])
	var skel := clacker.get_parent() as Skeleton3D
	var lever := skel.find_bone("lever")
	var mortar := (rec.pod as Node3D).get_node_or_null("WeaponRing/Mortar") as Node3D
	var blades := [(rec.pod as Node3D).find_child("VaneL_Blade", true, false) as Node3D,
		(rec.pod as Node3D).find_child("VaneR_Blade", true, false) as Node3D]
	if mortar == null or blades.has(null):
		for i in 3:
			_t.check("snap skipped", false, "Mortar %s, blades %s" % [mortar, blades])
		return
	var rest_top := _lever_top(skel, clacker, lever)
	var rest_z := mortar.position.z
	var rest_blades := [blades[0].rotation_degrees.z, blades[1].rotation_degrees.z]
	motion.shot()
	var deepest := 0.0
	var at_snap := 0.0
	var low_top := INF
	var kick := 0.0
	var flick := [0.0, 0.0]
	for i in roundi(0.1 / DT):
		motion.step(DT, {})
		var turned := _about_x(skel, lever)
		deepest = minf(deepest, turned)
		if absf((i + 1) * DT - SNAP_S) < DT * 0.5:
			at_snap = turned
		low_top = minf(low_top, _lever_top(skel, clacker, lever))
		kick = maxf(kick, mortar.position.z - rest_z)
		flick[0] = maxf(flick[0], blades[0].rotation_degrees.z - rest_blades[0])
		flick[1] = minf(flick[1], blades[1].rotation_degrees.z - rest_blades[1])
	_t.check("one shot snaps the clacker shut in 0.04 s", absf(at_snap - SNAP_DEG) < 0.5 and absf(deepest - SNAP_DEG) < 0.5
		and rest_top - low_top > 0.07, "lever %.2f deg at 0.04 s, deepest %.2f, handle top drops %.3f m" % [at_snap, deepest, rest_top - low_top])
	_t.check("the same shot kicks the mortar back and flicks both vents open", absf(kick - KICK_M) < 0.002
		and absf(flick[0] - FLICK_DEG) < 0.5 and absf(flick[1] + FLICK_DEG) < 0.5,
		"mortar back %.3f m, VaneL blade %+.1f deg, VaneR blade %+.1f deg" % [kick, flick[0], flick[1]])
	for i in roundi(0.4 / DT):
		motion.step(DT, {})
	var home := absf(_about_x(skel, lever)) < 0.01 and absf(mortar.position.z - rest_z) < 1e-4
	home = home and absf(blades[0].rotation_degrees.z - rest_blades[0]) < 0.01 and absf(blades[1].rotation_degrees.z - rest_blades[1]) < 0.01
	_t.check("lever, mortar and vents home 0.4 s later", home, "lever %.3f deg, mortar %.5f m, blades %.3f / %.3f deg" % [_about_x(skel, lever),
		mortar.position.z - rest_z, blades[0].rotation_degrees.z - rest_blades[0], blades[1].rotation_degrees.z - rest_blades[1]])


# The lever's pose offset about its own X, degrees.
static func _about_x(skel: Skeleton3D, bone: int) -> float:
	var off := skel.get_bone_rest(bone).basis.get_rotation_quaternion().inverse() * skel.get_bone_pose_rotation(bone)
	return off.get_euler().x * (180.0 / PI)


# The highest lever vertex with the bone's current pose applied (the mesh sits at the skeleton's
# origin, so its vertices are in skeleton space).
static func _lever_top(skel: Skeleton3D, clacker: MeshInstance3D, bone: int) -> float:
	var posed := skel.get_bone_global_pose(bone) * skel.get_bone_global_rest(bone).affine_inverse()
	var per_vertex := Revolvers.vertex_bones(skel, clacker)
	var top := -INF
	var k := 0
	for s in clacker.mesh.get_surface_count():
		for v: Vector3 in clacker.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if per_vertex[k] == bone:
				top = maxf(top, (posed * v).y)
			k += 1
	return top


# --- heft layers -------------------------------------------------------------------------------

# The layers hang on the Pod (and c3's rims on Core, out at the lattice), so no layer vertex may
# fall inside the clacker's bounds.
func _heft(box: AABB) -> void:
	var hits := []
	var loaded := 0
	for n in [2, 3, 4, 5]:
		var layer := Revolvers._load(LAYER % n)
		if layer == null:
			continue
		loaded += 1
		root.add_child(layer)
		for mi: MeshInstance3D in layer.find_children("*", "MeshInstance3D", true, false):
			for v in Revolvers.points(mi, layer):
				if box.grow(0.01).has_point(v):
					hits.append("c%d %s %s" % [n, mi.name, v])
		layer.queue_free()
	_t.check("no heft layer reaches into the clacker", loaded == 4 and hits.is_empty(), "%d layers, %d hits %s" % [loaded, hits.size(), hits.slice(0, 3)])
