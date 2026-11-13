extends SceneTree

const BallLooks := preload("res://src/presentation/ball_looks.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# The ball looks (ball_looks.gd, --ball-look): the switch is "today" by default, and a painter
# under "today" or with no tuning swaps no shell and dresses nothing. Under a look a painter with
# the game's tuning fits that look's shell for every pilot and dresses it itself; the rolling part
# stays inside the collider, the cutaway's window is on every surface of the rolling part but the
# class accents and blends none, and the bell's glass wears the canopy, its one blended surface.

const CORE_LIMIT := 0.985
const PILOTS: Array = ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]

var t := T.new("ball_looks_test")


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	var tuning := Tuning.new()
	t.eq("the switch is today by default", tuning.option(Tuning.BALL_LOOK_KEY), BallLooks.TODAY)
	t.eq("every look is an option of the switch", tuning.options_of(Tuning.BALL_LOOK_KEY), BallLooks.ids())
	t.eq("today swaps no shell", BallLooks.asset_paths(BallLooks.TODAY, PILOTS), {})
	t.eq("an unknown look swaps no shell", BallLooks.asset_paths("bogus", PILOTS), {})
	_unchanged("no tuning", null)
	_unchanged("today", _tuning(BallLooks.TODAY))
	for look in BallLooks.LOOKS:
		_look(look)
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


# A painter with no look fits the pilot's own shell and leaves hero_assets' materials on it.
func _unchanged(label: String, tuning) -> void:
	var painter := _painter(tuning)
	var ball := Node3D.new()
	root.add_child(ball)
	var shell: Dictionary = painter.fit_shell_into(ball, PILOTS[0], "", 1, {"class": Color.WHITE})
	var swapped: Array = PILOTS.filter(func(pilot): return painter.shell_assets.has(pilot))
	t.eq("%s: no pilot's shell is swapped" % label, swapped, [])
	var dressed := 0
	for view in _views(shell.core) + _views(shell.pod):
		for i in view.mesh.get_surface_count():
			var mat := view.get_active_material(i) as ShaderMaterial
			if mat != null and (mat.shader.code.contains("uniform float window") or mat.shader.code.contains("glint")):
				dressed += 1
	t.eq("%s: no surface wears a look's material" % label, dressed, 0)
	ball.free()
	painter.free()


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


func _shape(look: String, shell: Dictionary) -> void:
	var core: Node3D = shell.core
	var pod: Node3D = shell.pod
	t.check("%s: the rolling part stays inside the collider" % look, _reach(core) <= CORE_LIMIT + 0.001, "reach %.4f" % _reach(core))
	for mount in ["Dome", "Control_Grip_L", "Control_Grip_R", "Control_LapBar", "Control_Pedal_L", "Control_Pedal_R"]:
		t.check("%s: the cockpit keeps %s" % [look, mount], pod.find_child(mount, true, false) != null)
	var core_blend := _blended(core)
	var pod_blend := _blended(pod)
	if look == "cutaway":
		var cut := 0
		var total := 0
		for view in _views(core):
			for i in view.mesh.get_surface_count():
				var mat: Material = view.get_active_material(i)
				if mat != null and mat.resource_name == "class_accent":
					continue
				total += 1
				if mat is ShaderMaterial and mat.shader.code.contains("uniform float window"):
					cut += 1
		t.check("cutaway: the window is on every surface of the rolling part", total > 0 and cut == total, "%d of %d" % [cut, total])
		t.eq("cutaway: nothing blends", core_blend + pod_blend, 0)
	elif look == "bell":
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
