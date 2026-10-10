extends SceneTree

# Loads a generated effect.tscn headless and checks every CPUParticles3D property against the
# expectations the forge derived from the spec. Never opens a window (headless, dummy renderer).
# Run: godot --headless --path sketches/core-loop --script <this file> -- <effect.tscn> <expect.json>
# Prints VFX_OK ... and exits 0, or VFX_FAIL lines and exits 1.

const TOL := 0.0005


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("VFX_FAIL usage: -- <effect.tscn> <expect.json>")
		quit(1)
		return
	var fails: Array[String] = []
	var expect: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if typeof(expect) != TYPE_DICTIONARY:
		printerr("VFX_FAIL cannot read %s" % args[1])
		quit(1)
		return
	var packed := load(args[0]) as PackedScene
	if packed == null:
		printerr("VFX_FAIL cannot load %s" % args[0])
		quit(1)
		return
	var scene := packed.instantiate()
	if scene == null:
		printerr("VFX_FAIL instantiate returned null")
		quit(1)
		return
	if String(scene.get_meta("forge_spec_sha256", "")) != String(expect["spec_sha256"]):
		fails.append("spec sha256 metadata differs")
	var want: Array = expect["emitters"]
	var got: Array = scene.get_children()
	if got.size() != want.size():
		fails.append("emitter count %d, expected %d" % [got.size(), want.size()])
	var particles := 0
	for i in mini(got.size(), want.size()):
		var p := got[i] as CPUParticles3D
		var w: Dictionary = want[i]
		if p == null:
			fails.append("child %d is not CPUParticles3D" % i)
			continue
		particles += p.amount
		_eq(fails, w["name"], "name", String(p.name), String(w["name"]))
		_eq(fails, w["name"], "amount", p.amount, int(w["amount"]))
		_near(fails, w["name"], "lifetime", p.lifetime, w["lifetime"])
		_eq(fails, w["name"], "one_shot", p.one_shot, w["one_shot"])
		_eq(fails, w["name"], "emitting", p.emitting, false)
		_near(fails, w["name"], "explosiveness", p.explosiveness, w["explosiveness"])
		_near(fails, w["name"], "randomness", p.randomness, w["randomness"])
		_eq(fails, w["name"], "seed", p.seed, int(w["seed"]))
		_eq(fails, w["name"], "use_fixed_seed", p.use_fixed_seed, true)
		_eq(fails, w["name"], "emission_shape", int(p.emission_shape), int(w["emission_shape"]))
		_vec(fails, w["name"], "position", p.position, w["position"])
		_vec(fails, w["name"], "direction", p.direction, w["direction"])
		_vec(fails, w["name"], "gravity", p.gravity, w["gravity"])
		if int(w["emission_shape"]) == 1:
			_near(fails, w["name"], "emission_sphere_radius", p.emission_sphere_radius, w["emission_sphere_radius"])
		if int(w["emission_shape"]) == 3:
			_vec(fails, w["name"], "emission_box_extents", p.emission_box_extents, w["emission_box_extents"])
		_near(fails, w["name"], "spread", p.spread, w["spread"])
		_near(fails, w["name"], "initial_velocity_min", p.initial_velocity_min, w["initial_velocity_min"])
		_near(fails, w["name"], "initial_velocity_max", p.initial_velocity_max, w["initial_velocity_max"])
		_near(fails, w["name"], "damping_min", p.damping_min, w["damping_min"])
		_near(fails, w["name"], "damping_max", p.damping_max, w["damping_max"])
		_near(fails, w["name"], "scale_amount_min", p.scale_amount_min, w["scale_amount_min"])
		_near(fails, w["name"], "scale_amount_max", p.scale_amount_max, w["scale_amount_max"])
		_eq(fails, w["name"], "align_y", p.particle_flag_align_y, w["particle_flag_align_y"])
		_eq(fails, w["name"], "cast_shadow", int(p.cast_shadow), 0)
		# colour ramp
		var grad: Gradient = p.color_ramp
		if grad == null:
			fails.append("%s: no color_ramp" % w["name"])
		else:
			var offs: Array = w["gradient_offsets"]
			var cols: Array = w["gradient_colors"]
			_eq(fails, w["name"], "ramp stops", grad.get_point_count(), offs.size())
			for k in mini(grad.get_point_count(), offs.size()):
				_near(fails, w["name"], "ramp offset %d" % k, grad.get_offset(k), offs[k])
				var c := grad.get_color(k)
				for ch in 4:
					_near(fails, w["name"], "ramp colour %d.%d" % [k, ch], c[ch], cols[k * 4 + ch])
		# scale curve: sample at the keyframes and at midpoints (the converter writes linear tangents)
		var curve: Curve = p.scale_amount_curve
		if curve == null:
			fails.append("%s: no scale_amount_curve" % w["name"])
		else:
			var pts: Array = w["curve"]
			for k in pts.size():
				_near(fails, w["name"], "curve at %s" % pts[k][0], curve.sample(pts[k][0]), pts[k][1], 0.01)
				if k > 0:
					var mid: float = (pts[k - 1][0] + pts[k][0]) * 0.5
					var mv: float = (pts[k - 1][1] + pts[k][1]) * 0.5
					_near(fails, w["name"], "curve at mid %s" % mid, curve.sample(mid), mv, 0.01)
		# mesh and material
		var mesh := p.mesh
		if mesh == null:
			fails.append("%s: no mesh" % w["name"])
		else:
			_eq(fails, w["name"], "mesh class", mesh.get_class(), String(w["mesh_class"]))
			var mat := mesh.material as StandardMaterial3D
			if mat == null:
				fails.append("%s: mesh has no StandardMaterial3D" % w["name"])
			else:
				_eq(fails, w["name"], "unshaded", int(mat.shading_mode), 0)
				_eq(fails, w["name"], "vertex colour albedo", mat.vertex_color_use_as_albedo, true)
				_near(fails, w["name"], "emissive", mat.albedo_color.r, w["emissive"])
				_eq(fails, w["name"], "additive", int(mat.blend_mode) == 1, w["additive"])
	scene.free()
	if fails.is_empty():
		print("VFX_OK %s emitters=%d particles=%d" % [args[0], want.size(), particles])
		quit(0)
	else:
		for line in fails:
			printerr("VFX_FAIL " + line)
		quit(1)


func _eq(fails: Array[String], who: String, what: String, got: Variant, want: Variant) -> void:
	if got != want:
		fails.append("%s: %s is %s, expected %s" % [who, what, str(got), str(want)])


func _near(fails: Array[String], who: String, what: String, got: float, want: float, tol := TOL) -> void:
	if absf(got - float(want)) > tol:
		fails.append("%s: %s is %s, expected %s" % [who, what, str(got), str(want)])


func _vec(fails: Array[String], who: String, what: String, got: Vector3, want: Array) -> void:
	for i in 3:
		if absf(got[i] - float(want[i])) > TOL:
			fails.append("%s: %s is %s, expected %s" % [who, what, str(got), str(want)])
			return
