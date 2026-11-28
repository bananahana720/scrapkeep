extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Icons := preload("res://src/core/icons.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Roster := preload("res://src/combat/roster.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Indicator := preload("res://src/movement/indicator.gd")
const MechaMotion := preload("res://src/presentation/mecha_motion.gd")
const T := preload("res://tests/support/t.gd")

# Tarn's look (alpha wave 15): every layer reads "this is Tarn, the deliberate Redjaw
# tiger". The class row's shape, motif and sound; the tinted shell and pilot; the four
# drawn ability icons; the latch-and-tear motif and its cues; the claw sweep's feel; the
# claw-slash rim ticks.

const SHELL := "res://assets/models/world_one/shell_tarn.glb"
const PILOT := "res://assets/models/pilot_tarn_anim.glb"
const SLOTS := ["weapon", "move", "special", "smash"]
const CUES := ["tarn_latch_tear", "tarn_ready", "tarn_break", "mind_tarn"]
# The rig (wave 46 E2-04): Tarn stays at 17 draws, the heaviest pilot, with every part inside
# the 1.75 m weapon reach cap (lifted from 1.35 for heroic weapons, Andrew 23 Nov 2026).
const SHELL_DRAWS := 17
const REACH_CAP := 1.75
const JAWS := ["ClawUpper_L", "ClawUpper_R", "ClawLower_L", "ClawLower_R"]
const RIG_NODES := ["ClawUpper_L", "ClawUpper_R", "ClawLower_L", "ClawLower_R", "ClawPivot_L", "ClawPivot_R",
	"ClawTip_L", "ClawTip_R", "ClawHooks", "WeaponRing"]
# Each jaw's opening direction about its local X (the hinge pin): the right side opens its upper
# jaw positive and its lower negative, the left mirrors. The three beats' peaks (clips/tarn.json).
const OPENS := {"ClawUpper_L": -1.0, "ClawUpper_R": 1.0, "ClawLower_L": 1.0, "ClawLower_R": -1.0}
const BEATS := [
	{"ClawUpper_L": 55.0},
	{"ClawUpper_R": 70.0, "ClawLower_R": 25.0},
	{"ClawUpper_L": 80.0, "ClawUpper_R": 80.0, "ClawLower_L": 60.0, "ClawLower_R": 60.0},
]
# The upper jaws' rams are built for 0 to RAM_OPEN degrees open (shell_tarn.py): any further and
# the rod would leave its sleeve, any closing and its tail would leave the sleeve's foot.
const RAM_OPEN := 85.0
const DT := 1.0 / 60.0

var _t := T.new("tarn_look_test")


class StubState:
	var velocity := Vector3.ZERO


class StubKit:
	var gliding := false


class StubPlayer:
	extends Node3D
	var class_def: Resource
	var state := StubState.new()
	var kit := StubKit.new()
	var _juice := Node3D.new()
	var _mesh := MeshInstance3D.new()
	var _roll := Node3D.new()

	func _init() -> void:
		var visual := Node3D.new()
		add_child(visual)
		visual.add_child(_juice)
		_mesh.mesh = SphereMesh.new()
		_juice.add_child(_mesh)
		_mesh.add_child(_roll)

	func roll_node() -> Node3D:
		return _roll

	func juice_node() -> Node3D:
		return _juice

	func class_color() -> Color:
		return class_def.color if class_def != null else ClassDef.SABLE_COLOR


var _done := false


# The fit and the indicator need the tree, which is live from the first frame.
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_check_row()
	_check_model()
	_check_icons()
	_check_motif()
	_check_feel()
	_check_ticks()
	_check_rig()
	quit(_t.verdict())
	return true


func _check_row() -> void:
	var def: Resource = ClassDef.by_id("tarn")
	var rivet: Resource = ClassDef.by_id("runner_gunner")
	_t.eq("row motif", def.motif, "tarn")
	_t.check("row shape", def.shape == "cross" and def.shape in EventKinds.SHAPES and Icons.SHAPES.has(def.shape),
		"shape %s in EventKinds.SHAPES and Icons.SHAPES" % def.shape)
	_t.check("row colour", def.color == ClassDef.TARN_COLOR, "colour %s" % def.color.to_html())
	_t.check("row sound", SfxBank.has_recipe(def.sound), "sound %s is a bank recipe" % def.sound)
	var sharing := ClassDef.all().filter(func(d): return d.id != "tarn" and d.motif == "tarn").map(func(d): return d.id)
	_t.eq("motif unshared", sharing, [])
	_t.check("shape not Rivet's", def.shape != rivet.shape, "tarn %s, rivet %s" % [def.shape, rivet.shape])


func _check_model() -> void:
	_t.eq("shell path", HeroAssets.SHELLS["tarn"], SHELL)
	_t.eq("pilot path", HeroAssets.PILOTS["tarn"], PILOT)
	var hook := HeroAssets.new()
	root.add_child(hook)
	var stub := StubPlayer.new()
	root.add_child(stub)
	hook.attach_player(stub)
	stub.class_def = ClassDef.by_id("tarn")
	hook._process(0.016)
	var rec: Dictionary = hook.shell_of(stub)
	var core: Node3D = rec.get("core")
	var pod: Node3D = rec.get("pod")
	var pilot: Node3D = pod.get_node_or_null("AnimatedPilot") if pod != null else null
	_t.check("fit", core != null and pod != null and pilot != null, "Core, Pod and an AnimatedPilot under Pod")
	if pod != null:
		_t.check("accent", _accent_color(pod).is_equal_approx(ClassDef.TARN_COLOR), "class_accent %s" % _accent_color(pod).to_html())
	var dome := pod.find_child("Dome", true, false) as Node3D if pod != null else null
	if pilot != null and dome != null:
		var pbox := _box(pod, pilot)
		var dbox := _box(pod, dome)
		var centre := pbox.get_center()
		var inside := centre.x >= dbox.position.x and centre.x <= dbox.end.x and centre.z >= dbox.position.z and centre.z <= dbox.end.z
		var top_ok: bool = pbox.end.y <= dbox.end.y + 0.05
		if dbox.size == Vector3.ZERO:
			# The bespoke shell's Dome is an empty seat marker, not a mesh: the pilot sits on its origin.
			var seat := pod.to_local(dome.global_position)
			inside = absf(centre.x - seat.x) <= 0.15 and absf(centre.z - seat.z) <= 0.15
			top_ok = true
		_t.check("pilot in dome", inside and top_ok,
			"pilot centre %s top %.3f; dome %s..%s top %.3f" % [centre, pbox.end.y, dbox.position, dbox.end, dbox.end.y])
	else:
		_t.check("pilot in dome", false, "pilot %s dome %s" % [pilot, dome])
	var tinter := HeroAssets.new()
	_t.eq("paint", tinter.paint_tint("tarn", "paint_tarn_ash"), Color("5e5a54"))
	tinter.free()
	var text := FileAccess.get_file_as_string("res://src/presentation/hero_assets.gd")
	var flagged: Array = []
	for line in text.split("\n"):
		if line.contains("\"tarn\"") and line.to_lower().contains("placeholder"):
			flagged.append(line.strip_edges())
	_t.eq("no placeholder", flagged, [])
	stub.free()
	hook.free()


# The merged mesh AABB of a subtree in from's local space. The shell's Dome has no mesh of
# its own: its geometry is the hidden seat placeholder the shell was modelled around.
static func _box(from: Node3D, node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var todo: Array = [node]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			var local := from.global_transform.affine_inverse() * mi.global_transform * mi.mesh.get_aabb()
			box = local if first else box.merge(local)
			first = false
		todo.append_array(n.get_children())
	return box


static func _accent_color(pod: Node) -> Color:
	var todo: Array = [pod]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		todo.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			if HeroAssets.slot_of(mi.mesh, i) == "class_accent":
				return (mi.get_surface_override_material(i) as StandardMaterial3D).albedo_color
	return Color.BLACK


func _check_icons() -> void:
	for slot in SLOTS:
		var id: String = "ab_tarn_" + slot
		var path: String = "res://assets/icons/%s.svg" % id
		var svg := FileAccess.get_file_as_string(path)
		var rivet := FileAccess.get_file_as_string("res://assets/icons/ab_rivet_%s.svg" % slot)
		_t.check(id + " drawn", svg != "" and svg != rivet, "%s exists and differs from Rivet's" % path)
		_t.check(id + " palette", svg.contains("#9b513a") and not svg.contains("#b77843"), "iron oxide accent, no copper")
		var tex := Icons.texture(id)
		_t.check(id + " registered", Icons.EXTRA.has(id) and tex != null and tex.get_width() > 0 and Icons.from_file(id),
			"in Icons.EXTRA, loads from its file")
	_t.eq("registry ids", Icons.ids().size(), 70)
	var def: Resource = ClassDef.by_id("tarn")
	var named: Array = []
	for ability in [def.weapon_id, def.movement_id, def.special_id, def.smash_id]:
		named.append(AbilityState.ABILITIES[ability]["icon"])
	_t.eq("ability icons", named, SLOTS.map(func(s): return "ab_tarn_" + s))


func _check_motif() -> void:
	_t.eq("motif family", Harmony.motif("tarn").get("family"), "class")
	_t.eq("motif notes", Harmony.motif_notes("tarn"), [50, 50, 51, 57])
	_t.eq("release", Rows.releases("tarn"), ["tarn_latch_tear"])
	_t.eq("ready", Rows.resolve("class_motif", {"motif": "tarn"}), "tarn_ready")
	_t.eq("break", Rows.resolve("class_break", {"motif": "tarn"}), "tarn_break")
	_t.eq("mind quote", Roster.voiced("mind_quote", "tarn"), "mind_tarn")
	for id in CUES:
		var peak := Synth.peak(SfxBank.samples(id))
		_t.check(id + " bakes", peak >= 0.1, "peak %.3f" % peak)
		_t.check(id + " keyed", id in Audio.KEYED_SOUNDS, "in Audio.KEYED_SOUNDS")
	_t.eq("mind gap", Audio.MIN_GAP_MS.get("mind_tarn"), 600)


func _check_feel() -> void:
	_t.check("claw pitch", Audio.WEAPON_PITCH["claw_sweep"] < Audio.WEAPON_PITCH["arc_caster"],
		"claw_sweep %.1f below arc_caster %.1f" % [Audio.WEAPON_PITCH["claw_sweep"], Audio.WEAPON_PITCH["arc_caster"]])
	var weapons: Dictionary = EventJuice.JUICE["shot_fired"]["weapons"]
	var claw: Dictionary = weapons["claw_sweep"]
	_t.check("claw juice", claw["recoil"] > weapons["rapid_laser"]["recoil"] and claw["kick"] < weapons["sticky_charge"]["kick"],
		"claw %s, laser %s, sticky %s" % [claw, weapons["rapid_laser"], weapons["sticky_charge"]])


func _check_ticks() -> void:
	var counts: Array = []
	for ticks in ["cross", ""]:
		var ind := Indicator.new()
		root.add_child(ind)
		ind.set_shape("special", {"kind": "ring", "centre": Vector3.ZERO, "radius": 6.0, "color": ClassDef.TARN_COLOR,
			"ticks": ticks, "fill": 1.0})
		ind._process(0.0)
		counts.append(ind._tris.get_faces().size())
		ind.free()
	_t.check("cross ticks draw", counts[0] > counts[1], "vertices with cross ticks %d, without %d" % counts)


# The shell as the game loads it: draws, reach, the rig's nodes, each jaw hinged at its pivot,
# then clips/tarn.json played frame by frame through MechaMotion on the real shell.
func _check_rig() -> void:
	var scene: Node3D = (load(SHELL) as PackedScene).instantiate()
	root.add_child(scene)
	var pod := scene.find_child("Pod", true, false) as Node3D
	var core := scene.find_child("Core", true, false) as Node3D
	var draws := 0
	var reach := 0.0
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		draws += mi.mesh.get_surface_count()
		var to_scene: Transform3D = scene.global_transform.affine_inverse() * mi.global_transform
		for surface in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				reach = maxf(reach, (to_scene * v).length())
	_t.check("rig draws", draws <= SHELL_DRAWS, "%d surfaces, cap %d (no new draw for the rams)" % [draws, SHELL_DRAWS])
	_t.check("rig reach", reach > 1.0 and reach <= REACH_CAP, "furthest vertex %.3f m, cap %.2f" % [reach, REACH_CAP])
	var missing := RIG_NODES.filter(func(n): return pod.get_node_or_null(n) == null)
	_t.eq("rig nodes", missing, [])
	if not missing.is_empty():
		scene.free()
		return
	for jaw_name in JAWS:
		var jaw := pod.get_node(jaw_name) as Node3D
		var side: String = jaw_name.right(1)
		var pivot := pod.get_node("ClawPivot_" + side) as Node3D
		var arm := ((pod.get_node("ClawTip_" + side) as Node3D).position - pivot.position).normalized()
		var pin := jaw.basis.x.normalized()
		_t.check(jaw_name + " hinge", jaw.position.distance_to(pivot.position) < 1e-4 and absf(pin.y) < 1e-4 and absf(pin.dot(arm)) < 1e-4,
			"origin %.5f m from ClawPivot; local X %s level and square to the arm %s" % [jaw.position.distance_to(pivot.position), pin, arm])
	_check_beats(pod, core)
	scene.free()


func _check_beats(pod: Node3D, core: Node3D) -> void:
	var table = JSON.parse_string(FileAccess.get_file_as_string("res://src/presentation/clips/tarn.json"))
	var rows: Array = Array(table.get("machinery", [])) if table is Dictionary else []
	var motion = MechaMotion.new(pod, core, "tarn", rows)
	_t.check("rows load", rows.size() > 0 and motion._rows.size() == rows.size() and motion.skip_lines.is_empty(),
		"%d rows, %d live, skips %s" % [rows.size(), motion._rows.size(), motion.skip_lines])
	var jaws := {}
	var rest := {}
	for jaw_name in JAWS:
		jaws[jaw_name] = pod.get_node(jaw_name)
		rest[jaw_name] = (jaws[jaw_name] as Node3D).transform
	var facts := {"idle_still": false}
	var drift := 0.0
	for beat in BEATS.size():
		motion.shot()
		var peak := {}
		var low := {}
		for jaw_name in JAWS:
			peak[jaw_name] = 0.0
			low[jaw_name] = 0.0
		for frame in roundi(0.45 / DT):
			motion.step(DT, facts)
			for jaw_name in JAWS:
				var jaw: Node3D = jaws[jaw_name]
				var open := _open(jaw, jaw_name)
				peak[jaw_name] = maxf(peak[jaw_name], open)
				low[jaw_name] = minf(low[jaw_name], open)
				var at: Transform3D = rest[jaw_name]
				drift = maxf(drift, jaw.position.distance_to(at.origin))
				drift = maxf(drift, absf(jaw.rotation.y - at.basis.get_euler().y) + absf(jaw.rotation.z - at.basis.get_euler().z))
		var want: Dictionary = BEATS[beat]
		var got := []
		var good := true
		for jaw_name in JAWS:
			var target: float = want.get(jaw_name, 0.0)
			var p: float = peak[jaw_name]
			got.append("%s %.1f..%.1f" % [jaw_name, low[jaw_name], p])
			good = good and low[jaw_name] >= -0.01 and p <= RAM_OPEN
			good = good and (p >= 0.9 * target and p <= target + 0.01 if target > 0.0 else p < 0.01)
		_t.check("beat %d" % (beat + 1), good, "opening range of each jaw, want peaks %s; got %s" % [want, ", ".join(got)])
		var home := true
		for jaw_name in JAWS:
			home = home and (jaws[jaw_name] as Node3D).transform.is_equal_approx(rest[jaw_name])
		_t.check("beat %d returns to rest" % (beat + 1), home, "every jaw back on its rest transform 0.45 s after the beat")
	_t.check("hinge holds", drift < 1e-4, "jaws turn about their pins only: origin and yaw drift %.6f" % drift)
	_t.check("rend widest", BEATS[2]["ClawUpper_L"] > BEATS[0]["ClawUpper_L"] and BEATS[2]["ClawUpper_R"] > BEATS[1]["ClawUpper_R"],
		"beat three flares both upper jaws past beats one and two")
	# Beat three lands while beat two's hook is still on its way home: it carries on from there.
	motion.shot()
	_run(motion, 0.45, facts)
	motion.shot()
	_run(motion, 0.12, facts)
	var hook: Node3D = jaws["ClawUpper_R"]
	var before: float = hook.rotation_degrees.x
	motion.shot()
	var rising := true
	var last := before
	for frame in 3:
		motion.step(DT, facts)
		rising = rising and hook.rotation_degrees.x >= last - 1e-4
		last = hook.rotation_degrees.x
	_t.check("re-trigger never snaps", before > 1.0 and rising and last > before,
		"hook mid-return at %.1f deg, then %.1f after 3 frames of the next rend" % [before, last])
	_run(motion, 0.5, facts)
	# A still ball parts the jaws a little in their opening directions; a shot or a roll closes them.
	_run(motion, 3.0, {"idle_still": true})
	var tension := []
	var parted := true
	for jaw_name in JAWS:
		var open := _open(jaws[jaw_name], jaw_name)
		tension.append("%s %.1f" % [jaw_name, open])
		parted = parted and open > 2.0 and open < 10.0
	_t.check("idle tension", parted, ", ".join(tension))
	_run(motion, 3.0, facts)
	var shut := true
	for jaw_name in JAWS:
		shut = shut and absf((jaws[jaw_name] as Node3D).rotation_degrees.x) < 0.1
	_t.check("idle releases", shut, "jaws back within 0.1 degrees of rest once the ball moves")


# How far a jaw stands open from its rest, in its own opening direction (negative is closing).
static func _open(jaw: Node3D, jaw_name: String) -> float:
	return jaw.rotation_degrees.x * float(OPENS[jaw_name])


func _run(motion, seconds: float, facts: Dictionary) -> void:
	for i in roundi(seconds / DT):
		motion.step(DT, facts)
