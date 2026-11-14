extends SceneTree

const BallLooks := preload("res://src/presentation/ball_looks.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const PilotGlance := preload("res://src/presentation/pilot_glance.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# The ball looks (ball_looks.gd, --ball-look): the switch is "today" by default, and a painter
# under "today" or with no tuning swaps no shell and dresses nothing. Under a look a painter with
# the game's tuning fits that look for every pilot and dresses it itself. The gyro and the bell
# swap the whole shell. The cutaway keeps each pilot's own shell (kit, weapon ring, hub mounts)
# and plates its rolling part: every heft class has plating inside the collider, the lattice's
# gap panels are hidden, the window is on every surface of the rolling part but the class
# accents, an equipped paint reaches the plating, nothing new blends, and what rides the ball
# (scrap, panel plates) takes the window without touching a mesh another ball shares.

const CORE_LIMIT := 0.985
const PILOTS: Array = ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]

var t := T.new("ball_looks_test")


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	var tuning := Tuning.new()
	t.eq("the cutaway is the default look", tuning.option(Tuning.BALL_LOOK_KEY), "cutaway")
	t.eq("every look is an option of the switch", tuning.options_of(Tuning.BALL_LOOK_KEY), BallLooks.ids())
	t.eq("today swaps no shell", BallLooks.asset_paths(BallLooks.TODAY, PILOTS), {})
	t.eq("an unknown look swaps no shell", BallLooks.asset_paths("bogus", PILOTS), {})
	_unchanged("no tuning", null)
	_unchanged("today", _tuning(BallLooks.TODAY))
	for look in BallLooks.LOOKS:
		if BallLooks.PLATED.has(look):
			_plated(look)
		else:
			_look(look)
	_riders()
	_glance()
	quit(t.verdict())


func _tuning(look: String) -> Tuning:
	var tuning := Tuning.new()
	tuning.apply_args(PackedStringArray(["--ball-look=" + look]))
	return tuning


func _painter(tuning) -> HeroAssets:
	var painter := HeroAssets.new()
	if tuning != null:
		painter.ctx = {"tuning": tuning}
	root.add_child(painter)
	return painter


# A painter with no look fits the pilot's own shell at the heaviest heft class exactly as a
# painter with no tuning does: the same meshes, the same ones drawing, hero_assets' materials.
func _unchanged(label: String, tuning) -> void:
	var plain := _painter(null)
	var painter := _painter(tuning)
	var ball := Node3D.new()
	root.add_child(ball)
	var want: Dictionary = plain.fit_shell_into(ball, PILOTS[0], "", 5, {"class": Color.WHITE})
	var shell: Dictionary = painter.fit_shell_into(ball, PILOTS[0], "", 5, {"class": Color.WHITE})
	var swapped: Array = PILOTS.filter(func(pilot): return painter.shell_assets.has(pilot))
	t.eq("%s: no pilot's shell is swapped" % label, swapped, [])
	t.eq("%s: every mesh is the pilot's own and draws as it did" % label, _drawn(shell), _drawn(want))
	t.check("%s: no cockpit is added" % label, not (shell.pod as Node).has_node(BallLooks.COCKPIT_NODE))
	var dressed := 0
	for view in _views(shell.core) + _views(shell.pod):
		for i in view.mesh.get_surface_count():
			var mat := view.get_active_material(i) as ShaderMaterial
			if mat != null and (mat.shader.code.contains("uniform float window") or mat.shader.code.contains("glint")):
				dressed += 1
	t.eq("%s: no surface wears a look's material" % label, dressed, 0)
	ball.free()
	painter.free()
	plain.free()


# Every mesh of a fitted shell with the render layers it draws on, in tree order.
# How many of a pilot's surfaces take light through from their far side.
func _backlit(pilot: Node) -> int:
	var count := 0
	for view in _views(pilot):
		for i in view.mesh.get_surface_count():
			var mat := view.get_active_material(i) as BaseMaterial3D
			if mat != null and mat.backlight_enabled:
				count += 1
	return count


func _drawn(shell: Dictionary) -> Array:
	var out: Array = []
	for view in _views(shell.core) + _views(shell.pod):
		out.append([view.mesh, view.layers])
	return out


func _look(look: String) -> void:
	var painter := _painter(_tuning(look))
	t.eq("%s: the painter reads the look from the tuning" % look, painter.ball_look(), look)
	for pilot in PILOTS:
		var ball := Node3D.new()
		root.add_child(ball)
		var shell: Dictionary = painter.fit_shell_into(ball, pilot, "", 1, {"class": Color.WHITE})
		t.check("%s: fits %s through the game's loader" % [look, pilot], not shell.is_empty())
		t.eq("%s: %s wears the look's shell" % [look, pilot], painter.shell_assets.get(pilot, ""), BallLooks.LOOKS[look])
		if not shell.is_empty() and pilot == PILOTS[0]:
			_shape(look, shell)
		ball.free()
	painter.free()


# A plated look: each pilot's own shell at the heaviest heft class, with its rolling part plated.
func _plated(look: String) -> void:
	var plain := _painter(null)
	var painter := _painter(_tuning(look))
	t.eq("%s: the painter reads the look from the tuning" % look, painter.ball_look(), look)
	t.eq("%s: no pilot's whole shell is swapped" % look, BallLooks.asset_paths(look, PILOTS), {})
	var paint := Color(0.85, 0.3, 0.55)
	for pilot in PILOTS:
		var ball := Node3D.new()
		root.add_child(ball)
		var own: Dictionary = plain.fit_shell_into(ball, pilot, "", 5, {"class": Color.WHITE})
		var shell: Dictionary = painter.fit_shell_into(ball, pilot, "", 5, {"class": Color.WHITE, "paint": paint})
		t.check("%s: fits %s through the game's loader" % [look, pilot], not shell.is_empty())
		if shell.is_empty() or own.is_empty():
			ball.free()
			continue
		var core: Node3D = shell.core
		var pod: Node3D = shell.pod
		t.check("%s: %s keeps its hub mounts, so scrap still clamps on" % [look, pilot], core.has_node("Hub_00") == (own.core as Node).has_node("Hub_00"))
		t.eq("%s: %s keeps its weapon ring" % [look, pilot], pod.has_node("WeaponRing"), (own.pod as Node).has_node("WeaponRing"))
		t.check("%s: %s's rolling part stays inside the collider at every heft class" % [look, pilot], _reach(core) <= CORE_LIMIT + 0.001, "reach %.4f" % _reach(core))
		var bare: Array = []
		for n in shell.layers:
			if _views(shell.layers[n].core).is_empty():
				bare.append(n)
		t.eq("%s: every heft class of %s has plating" % [look, pilot], bare, [])
		var floating := 0
		for n in shell.layers:
			for view in _views(shell.layers[n].pod):
				if view.layers != 0 and _far(view.mesh) < BallLooks.INSIDE_RADIUS:
					floating += 1
		t.eq("%s: no gap panel of %s floats inside the ball" % [look, pilot], floating, 0)
		var cut := 0
		var total := 0
		var painted := 0
		var enamelled := 0
		for view in _views(core):
			for i in view.mesh.get_surface_count():
				var mat: Material = view.get_active_material(i)
				if mat != null and mat.resource_name == "class_accent":
					continue
				total += 1
				if _is_window(mat):
					cut += 1
					if _number(mat, "paint_take") > 0.0:
						painted += 1
					if _number(mat, "enamel_take") > 0.0:
						enamelled += 1
		t.check("%s: the window is on every surface of %s's rolling part" % [look, pilot], total > 0 and cut == total, "%d of %d" % [cut, total])
		t.check("%s: an equipped paint reaches %s's plating" % [look, pilot], painted > 0)
		t.check("%s: %s's plating wears the pilot's own enamel" % [look, pilot], enamelled > 0)
		var kit := 0
		for view in _views(pod):
			for i in view.mesh.get_surface_count():
				var mat: Material = view.get_active_material(i)
				if _is_window(mat):
					kit += 1
					if _number(mat, "keep_within") < 0.9:
						t.check("%s: %s's cockpit is never cut" % [look, pilot], false, "keep_within %s" % mat.get_shader_parameter("keep_within"))
		t.check("%s: %s's outer kit takes the window" % [look, pilot], kit > 0)
		var seat := 9.0
		for i in (pod as MeshInstance3D).mesh.get_surface_count():
			var mat: Material = (pod as MeshInstance3D).get_active_material(i)
			if _is_window(mat):
				seat = minf(seat, _number(mat, "seat_back_top"))
		t.eq("%s: only a small pilot's seat back is lowered (%s)" % [look, pilot], seat, float(BallLooks.LOW_SEAT_BACK.get(pilot, 9.0)))
		t.eq("%s: no light node rides %s's ball" % [look, pilot], (pod as Node).find_children("*", "Light3D", true, false).size(), 0)
		var cockpits: Array = (pod as Node).find_children(BallLooks.COCKPIT_NODE, "MeshInstance3D", true, false)
		t.eq("%s: %s's level part carries one cockpit" % [look, pilot], cockpits.size(), 1)
		if cockpits.size() == 1:
			var far := 0.0
			for point in (cockpits[0] as MeshInstance3D).mesh.get_faces():
				far = maxf(far, point.length())
			t.check("%s: the cockpit stays inside the plating" % look, far < BallLooks.PLATING_RADIUS, str(far))
			var hidden := 0
			for i in (cockpits[0] as MeshInstance3D).mesh.get_surface_count():
				var mat: Material = (cockpits[0] as MeshInstance3D).get_active_material(i)
				if _is_window(mat) and _number(mat, "keep_within") < 0.9:
					hidden += 1
			t.eq("%s: the cockpit is never cut" % look, hidden, 0)
		var seated: Dictionary = painter.fit_pilot_into(pod, pilot, Color.WHITE)
		if not seated.is_empty():
			t.check("%s: %s's shaded side takes light from their far side" % [look, pilot], _backlit(seated.pilot) > 0)
			var plainly: Dictionary = plain.fit_pilot_into(pod, pilot, Color.WHITE)
			t.eq("%s: today's %s is lit as before" % [look, pilot], _backlit(plainly.pilot), 0)
			plainly.pilot.free()
		var outfits: Array = Cosmetics.ROWS.keys().filter(func(id): return Cosmetics.ROWS[id].get("slot", "") == "outfit" and Cosmetics.ROWS[id].get("pilot", "") == pilot)
		if not seated.is_empty() and not outfits.is_empty():
			t.check("%s: %s's outfit %s mounts on the pilot behind the window" % [look, pilot, outfits[0]], not painter.fit_outfit(seated.pilot, outfits[0], {"class": Color.WHITE}).is_empty())
		var accents := 0
		for view in _views(core) + _views(pod):
			for i in view.mesh.get_surface_count():
				var mat: Material = view.get_active_material(i)
				if mat != null and mat.resource_name == "class_accent":
					accents += 1
		t.check("%s: the ready glow still lights %s's class accents" % [look, pilot], accents > 0 and painter._glow_rec(shell, true) == accents, "%d accents" % accents)
		t.eq("%s: %s blends nothing its own shell does not" % [look, pilot], _blended(core) + _blended(pod), _blended(own.core) + _blended(own.pod))
		ball.free()
	painter.free()
	plain.free()


# What rides the rolling ball takes the window under a plated look, and only then.
func _riders() -> void:
	var roll := Node3D.new()
	root.add_child(roll)
	roll.position = Vector3(3.0, 1.0, -2.0)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.4, 0.4, 0.45)
	var chunk := MeshInstance3D.new()
	chunk.mesh = BoxMesh.new()
	chunk.material_override = steel
	roll.add_child(chunk)
	var shared := ArrayMesh.new()
	shared.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().get_mesh_arrays())
	var face := StandardMaterial3D.new()
	face.vertex_color_use_as_albedo = true
	shared.surface_set_material(0, face)
	var plates := MultiMeshInstance3D.new()
	plates.multimesh = MultiMesh.new()
	plates.multimesh.mesh = shared
	roll.add_child(plates)
	var halo := MeshInstance3D.new()
	halo.mesh = BoxMesh.new()
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.material_override = flat
	roll.add_child(halo)
	var ghost := MeshInstance3D.new()
	ghost.mesh = BoxMesh.new()
	var clear := StandardMaterial3D.new()
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.material_override = clear
	roll.add_child(ghost)
	var lamp := MeshInstance3D.new()
	lamp.mesh = BoxMesh.new()
	var lit := StandardMaterial3D.new()
	lit.emission_enabled = true
	lit.emission = Color(0.5, 0.5, 0.5)
	lit.emission_energy_multiplier = 3.0
	lamp.material_override = lit
	roll.add_child(lamp)
	BallLooks.ride(BallLooks.TODAY, roll)
	t.check("today: a rider keeps its material", chunk.material_override == steel and plates.multimesh.mesh == shared)
	BallLooks.ride("cutaway", roll)
	var cut := chunk.material_override as ShaderMaterial
	t.check("cutaway: a rider takes the window", _is_window(cut))
	t.check("cutaway: a rider's window is held at the ball's centre", cut != null and cut.get_shader_parameter("held") == true and cut.get_shader_parameter("centre_at") == roll.global_position)
	t.check("cutaway: panel plates take the window on a mesh of their own", plates.multimesh.mesh != shared and _is_window(plates.multimesh.mesh.surface_get_material(0)))
	t.check("cutaway: the mesh other balls share is untouched", shared.surface_get_material(0) == face)
	t.check("cutaway: an unshaded or see-through rider keeps its material", halo.material_override == flat and ghost.material_override == clear)
	var glow = (lamp.material_override as ShaderMaterial).get_shader_parameter("glow")
	t.check("cutaway: a rider's glow is its linear colour times its energy", glow is Vector3 and absf(glow.x - Color(0.5, 0.5, 0.5).srgb_to_linear().r * 3.0) < 0.001, str(glow))
	var twin := MeshInstance3D.new()
	twin.mesh = BoxMesh.new()
	var steel_again := StandardMaterial3D.new()
	steel_again.albedo_color = steel.albedo_color
	twin.material_override = steel_again
	var holder := Node3D.new()
	roll.add_child(holder)
	BallLooks.ride("cutaway", roll)
	holder.add_child(twin)
	roll.position = Vector3(5.0, 1.0, 0.0)
	BallLooks.ride("cutaway", roll)
	t.check("cutaway: a rider added later under a child is cut and shares the material", twin.material_override == cut)
	t.eq("cutaway: the window follows the ball", cut.get_shader_parameter("centre_at"), roll.global_position)
	t.eq("cutaway: riders add one material per look", (roll.get_meta(BallLooks.RIDER_META).cuts as Dictionary).size(), 3)
	roll.free()


# Stands in for the player where the game's own pilot fitting asks for the class colour.
class _Rider:
	func class_color() -> Color:
		return Color.WHITE


# The pilot's glance back at the camera (pilot_glance.gd): only at rest, only toward a camera
# behind, over the shoulder on the camera's side, and gone the moment the ball moves.
func _glance() -> void:
	var painter := _painter(_tuning("cutaway"))
	var ball := Node3D.new()
	root.add_child(ball)
	var shell: Dictionary = painter.fit_shell_into(ball, PILOTS[0], "", 1, {"class": Color.WHITE})
	var seated: Dictionary = painter.fit_pilot_into(shell.pod, PILOTS[0], Color.WHITE)
	var glance = PilotGlance.seat(seated.pilot)
	t.check("glance: seats on the pilot's skeleton", glance != null and glance.get_parent() is Skeleton3D)
	if glance == null:
		return
	var skeleton: Skeleton3D = glance.get_parent()
	var behind_right := skeleton.global_transform * Vector3(2.0, 1.0, 6.0)
	var behind_left := skeleton.global_transform * Vector3(-2.0, 1.0, 6.0)
	var ahead := skeleton.global_transform * Vector3(0.5, 1.0, -6.0)
	for i in 120:
		glance.observe(false, behind_right, 1.0 / 60.0)
	t.eq("glance: a moving ball's pilot looks ahead", glance.turn, 0.0)
	for i in int(PilotGlance.FIRST_AFTER * 60.0) - 6:
		glance.observe(true, behind_right, 1.0 / 60.0)
	t.eq("glance: nothing before the ball has sat still a moment", glance.turn, 0.0)
	for i in 40:
		glance.observe(true, behind_right, 1.0 / 60.0)
	t.check("glance: then over the right shoulder to a camera behind on the right", glance.turn > 0.8, str(glance.turn))
	var head := skeleton.find_bone("head")
	var rests := {}
	for bone_name in PilotGlance.SHARES:
		rests[bone_name] = skeleton.get_bone_pose_rotation(skeleton.find_bone(bone_name))
	# The way the face points, in the head bone's own axes; the pilot faces -Z at rest.
	var face: Vector3 = skeleton.get_bone_global_pose(head).basis.orthonormalized().inverse() * Vector3.FORWARD
	glance._process_modification()
	var faces: Vector3 = skeleton.get_bone_global_pose(head).basis.orthonormalized() * face
	t.check("glance: the face turns to the camera's side and past the shoulder", faces.x > 0.5 and faces.z > 0.0, str(faces))
	for bone_name in rests:
		skeleton.set_bone_pose_rotation(skeleton.find_bone(bone_name), rests[bone_name])
	for i in 30:
		glance.observe(false, behind_right, 1.0 / 60.0)
	t.check("glance: gone within half a second of the ball moving", absf(glance.turn) < 0.02, str(glance.turn))
	for i in int((PilotGlance.FIRST_AFTER + 0.6) * 60.0):
		glance.observe(true, behind_left, 1.0 / 60.0)
	t.check("glance: over the left shoulder to a camera on the left", glance.turn < -0.8, str(glance.turn))
	for i in int((PilotGlance.HOLD + 1.0) * 60.0):
		glance.observe(true, behind_left, 1.0 / 60.0)
	t.check("glance: the look is held, then the pilot turns back", absf(glance.turn) < 0.02, str(glance.turn))
	for i in 60:
		glance.observe(false, ahead, 1.0 / 60.0)
	for i in int((PilotGlance.FIRST_AFTER + 0.6) * 60.0):
		glance.observe(true, ahead, 1.0 / 60.0)
	t.eq("glance: no glance at a camera in front", glance.turn, 0.0)
	var plain := _painter(null)
	for case in [[painter, true], [plain, false]]:
		var rec: Dictionary = case[0].fit_shell_into(ball, PILOTS[0], "", 1, {"class": Color.WHITE})
		rec["class"] = PILOTS[0]
		rec["player"] = _Rider.new()
		case[0]._fit_pilot(rec)
		t.eq("glance: the game seats one under %s: %s" % [case[0].ball_look(), case[1]], rec.get("glance") != null, case[1])
		if rec.get("pilot") != null:
			t.eq("glance: one modifier at most on that pilot", rec.pilot.find_children("PilotGlance", "", true, false).size(), 1 if case[1] else 0)
	t.check("glance: a still ball is at rest", painter._at_rest({"reaction": ""}, 0.1))
	t.check("glance: a moving ball is not", not painter._at_rest({"reaction": ""}, 2.0))
	t.check("glance: a reaction clip ends the rest", not painter._at_rest({"reaction": "hit"}, 0.1))
	ball.free()
	painter.free()
	plain.free()


func _is_window(mat: Material) -> bool:
	return mat is ShaderMaterial and mat.shader != null and mat.shader.code.contains("uniform float window")


func _number(mat: ShaderMaterial, key: String) -> float:
	var value = mat.get_shader_parameter(key)
	return float(value) if value != null else 0.0


func _far(mesh: Mesh) -> float:
	var far := 0.0
	for point in mesh.get_faces():
		far = maxf(far, point.length())
	return far


func _shape(look: String, shell: Dictionary) -> void:
	var core: Node3D = shell.core
	var pod: Node3D = shell.pod
	t.check("%s: the rolling part stays inside the collider" % look, _reach(core) <= CORE_LIMIT + 0.001, "reach %.4f" % _reach(core))
	for mount in ["Dome", "Control_Grip_L", "Control_Grip_R", "Control_LapBar", "Control_Pedal_L", "Control_Pedal_R"]:
		t.check("%s: the cockpit keeps %s" % [look, mount], pod.find_child(mount, true, false) != null)
	var core_blend := _blended(core)
	var pod_blend := _blended(pod)
	if look == "bell":
		t.eq("bell: the glass is the one blended surface", [core_blend, pod_blend], [0, 1])
		var canopies := 0
		for view in _views(pod):
			for i in view.mesh.get_surface_count():
				var mat := view.get_active_material(i) as ShaderMaterial
				if mat != null and mat.shader.code.contains("glint"):
					canopies += 1
		t.eq("bell: the glass wears the canopy", canopies, 1)
	else:
		t.eq("%s: nothing blends" % look, core_blend + pod_blend, 0)


func _views(node: Node) -> Array:
	var views: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		views.append(node)
	return views


func _reach(core: Node3D) -> float:
	var far := 0.0
	for view in _views(core):
		for i in view.mesh.get_surface_count():
			for v in view.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
				far = maxf(far, (core.transform.affine_inverse() * _to_root(view) * v).length())
	return far


func _to_root(node: Node3D) -> Transform3D:
	var core := node
	var out := Transform3D.IDENTITY
	while core != null and String(core.name) != "HeroCore":
		out = core.transform * out
		core = core.get_parent() as Node3D
	return (core.transform if core != null else Transform3D.IDENTITY) * out


func _blended(node: Node) -> int:
	var count := 0
	for view in _views(node):
		for i in view.mesh.get_surface_count():
			var mat: Material = view.get_active_material(i)
			if mat is BaseMaterial3D and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				count += 1
			elif mat is ShaderMaterial and mat.shader != null and mat.shader.code.contains("ALPHA ="):
				count += 1
	return count
