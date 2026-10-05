extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Icons := preload("res://src/ui/icons.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Roster := preload("res://src/combat/roster.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Indicator := preload("res://src/movement/indicator.gd")
const T := preload("res://tests/support/t.gd")

# Tarn's look (alpha wave 15): every layer reads "this is Tarn, the deliberate Redjaw
# tiger". The class row's shape, motif and sound; the tinted shell and pilot; the four
# drawn ability icons; the latch-and-tear motif and its cues; the claw sweep's feel; the
# claw-slash rim ticks.

const SHELL := "res://assets/models/world_one/shell_kest.glb"
const PILOT := "res://assets/models/pilot_sable_anim.glb"
const SLOTS := ["weapon", "move", "special", "smash"]
const CUES := ["tarn_latch_tear", "tarn_ready", "tarn_break", "mind_tarn"]

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
		_t.check("pilot in dome", inside and pbox.end.y <= dbox.end.y + 0.05,
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
	var weapons: Dictionary = EventKinds.JUICE["shot_fired"]["weapons"]
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
