extends SceneTree
# 2026-10-11 (PC-CANNON): add line/ultimate icons and the family-note map; shell pins stay PD-owned.

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
const ClassPreview := preload("res://src/ui/class_preview.gd")
const CannonTree := preload("res://src/core/trees/cannon.gd")
const T := preload("res://tests/support/t.gd")

# The Mind's gun turned outward: one cannon identity across every presentation layer.

const SHELL := "res://assets/models/world_one/shell_cannon.glb"
const PILOT := "res://assets/models/pilot_cannon_anim.glb"
const SLOTS := ["weapon", "move", "special", "smash"]
const CUES := ["cannon_recall", "cannon_ready", "cannon_break", "mind_cannon"]

var _t := T.new("cannon_look_test")


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
	for family in ["lane", "split_lane", "rush", "plate"]:
		_t.eq("family note " + family, Harmony.family_note(family), Harmony.motif_notes("cannon")[["lane", "split_lane", "rush", "plate"].find(family)])
	for icon in ["ab_cannon_line", "ab_cannon_ult"]:
		_t.check(icon + " ancient green", FileAccess.get_file_as_string("res://assets/icons/" + icon + ".svg").contains("#9dff3c"))
		_t.check(icon + " resolves", Icons.texture(icon) != null)
	_check_motif()
	_check_feel()
	_check_ticks()
	_check_preview()
	quit(_t.verdict())
	return true


func _check_row() -> void:
	var def: Resource = ClassDef.by_id("remembered_cannon")
	_t.eq("row motif", def.motif, "cannon")
	_t.check("row shape", def.shape == "lane" and def.shape in EventKinds.SHAPES and Icons.SHAPES.get(def.shape) == "lane",
		"lane in EventKinds.SHAPES and Icons.SHAPES")
	_t.eq("row colour", def.color, ClassDef.CANNON_COLOR)
	_t.check("row sound", def.sound == "launch_roar" and SfxBank.has_recipe(def.sound), "launch_roar is a bank recipe")
	var sharing := ClassDef.all().filter(func(d): return d.id != "remembered_cannon" and d.motif == "cannon").map(func(d): return d.id)
	_t.eq("motif unshared", sharing, [])
	var shapes := ClassDef.all().filter(func(d): return d.id != "remembered_cannon" and d.shape == "lane").map(func(d): return d.id)
	_t.eq("shape unshared", shapes, [])


func _check_model() -> void:
	_t.eq("shell path", HeroAssets.SHELLS["remembered_cannon"], SHELL)
	_t.eq("pilot path", HeroAssets.PILOTS["remembered_cannon"], PILOT)
	for id in HeroAssets.SHELLS:
		if id != "remembered_cannon":
			_t.check("pair differs from " + id, [HeroAssets.SHELLS[id], HeroAssets.PILOTS[id]] != [SHELL, PILOT], "unique shell and pilot pairing")
	var hook := HeroAssets.new()
	root.add_child(hook)
	var stub := StubPlayer.new()
	root.add_child(stub)
	hook.attach_player(stub)
	stub.class_def = ClassDef.by_id("remembered_cannon")
	hook._process(0.016)
	var rec: Dictionary = hook.shell_of(stub)
	var core: Node3D = rec.get("core")
	var pod: Node3D = rec.get("pod")
	var pilot: Node3D = pod.get_node_or_null("AnimatedPilot") if pod != null else null
	_t.check("fit", core != null and pod != null and pilot != null, "Core, Pod and an AnimatedPilot under Pod")
	if pod != null:
		var accent := _accent_color(pod)
		_t.check("accent", accent.is_equal_approx(ClassDef.CANNON_COLOR), "class_accent %s" % accent.to_html())
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
	_t.eq("paint", tinter.paint_tint("remembered_cannon", "paint_cannon_verdigris"), Color("4f7f7a"))
	tinter.free()
	var flagged: Array = []
	for file in ["src/core/class_def.gd", "src/presentation/hero_assets.gd", "src/ui/class_preview.gd"]:
		var lines := FileAccess.get_file_as_string("res://" + file).split("\n")
		for i in lines.size():
			var line: String = lines[i].to_lower()
			if line.contains("remembered_cannon") and (line.contains("stand-in") or line.contains("placeholder")):
				flagged.append(lines[i].strip_edges())
			if file == "src/core/class_def.gd" and line.contains('make({"id": "remembered_cannon"') and i > 0:
				var above: String = lines[i - 1].to_lower()
				if above.contains("stand-in") or above.contains("placeholder"):
					flagged.append(lines[i - 1].strip_edges())
	_t.eq("no stand-in or placeholder", flagged, [])
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
		var id: String = "ab_cannon_" + slot
		var path: String = "res://assets/icons/%s.svg" % id
		var svg := FileAccess.get_file_as_string(path)
		var kest := FileAccess.get_file_as_string("res://assets/icons/ab_kest_%s.svg" % slot)
		_t.check(id + " drawn", svg != "" and svg != kest, "%s exists and differs from Kest's" % path)
		_t.check(id + " palette", svg.contains("#9dff3c") and not svg.contains("#e5a044"), "ancient green accent, no amber")
		var tex := Icons.texture(id)
		_t.check(id + " registered", Icons.EXTRA.has(id) and tex != null and tex.get_width() > 0 and Icons.from_file(id),
			"in Icons.EXTRA, loads from its file")
	_t.eq("registry ids", Icons.ids().size(), 70)
	var def: Resource = ClassDef.by_id("remembered_cannon")
	var named: Array = []
	for ability in [def.weapon_id, def.movement_id, def.special_id, def.smash_id]:
		named.append(AbilityState.ABILITIES[ability]["icon"])
	_t.eq("ability icons", named, SLOTS.map(func(s): return "ab_cannon_" + s))

	var icons := {"weapon": "ab_cannon_weapon", "movement": "ab_cannon_move", "special": "ab_cannon_special", "smash": "ab_cannon_smash"}
	for node in CannonTree.NODES:
		_t.eq("tree icon " + node.id, node.icon, icons[node.key])


func _check_motif() -> void:
	_t.eq("motif family", Harmony.motif("cannon").get("family"), "class")
	_t.eq("motif notes", Harmony.motif_notes("cannon"), [59, 64, 67, 74])
	_t.eq("mind quote notes", Harmony.mind_quote("cannon").map(func(c): return c[1]), [59, 54, 51, 43])
	_t.check("class motif", "cannon" in Harmony.CLASS_MOTIFS, "in CLASS_MOTIFS")
	_t.eq("release", Rows.releases("cannon"), ["cannon_recall"])
	_t.eq("ready", Rows.resolve("class_motif", {"motif": "cannon"}), "cannon_ready")
	_t.eq("break", Rows.resolve("class_break", {"motif": "cannon"}), "cannon_break")
	_t.eq("mind quote", Roster.voiced("mind_quote", "cannon"), "mind_cannon")
	for id in CUES:
		var peak := Synth.peak(SfxBank.samples(id))
		_t.check(id + " bakes", peak >= 0.1, "peak %.3f" % peak)
		_t.check(id + " keyed", id in Audio.KEYED_SOUNDS, "in Audio.KEYED_SOUNDS")
	_t.eq("mind gap", Audio.MIN_GAP_MS.get("mind_cannon"), 600)


func _check_feel() -> void:
	_t.check("cannon pitch", Audio.WEAPON_PITCH.get("cannon_lane", 0.0) < Audio.WEAPON_PITCH["claw_sweep"],
		"cannon_lane %.1f below claw_sweep %.1f" % [Audio.WEAPON_PITCH.get("cannon_lane", 0.0), Audio.WEAPON_PITCH["claw_sweep"]])


func _check_ticks() -> void:
	var counts: Array = []
	for ticks in ["lane", "burst", ""]:
		var ind := Indicator.new()
		root.add_child(ind)
		ind.set_shape("special", {"kind": "ring", "centre": Vector3.ZERO, "radius": 6.0, "color": ClassDef.CANNON_COLOR,
			"ticks": ticks, "fill": 1.0})
		ind._process(0.0)
		counts.append(ind._tris.get_faces().size())
		ind.free()
	_t.check("lane ticks draw", counts[0] > counts[1] and counts[1] > counts[2], "vertices lane %d, burst %d, without %d" % counts)


func _check_preview() -> void:
	var preview := ClassPreview.new(ClassDef.by_id("remembered_cannon"))
	for id in ["lane", "split0", "split1", "plate", "ring", "bolt"]:
		_t.check("preview " + id, preview._props.has(id), "has its own cannon prop")
	_t.check("preview no Kest props", not preview._props.has("charge0") and not preview._props.has("smoke0"), "no charge0 or smoke0")
	_t.eq("preview rest", ClassPreview.REST["remembered_cannon"], 0.22)
	for phase in [[0.15, "lane"], [0.6, "plate"], [0.9, "ring"]]:
		preview._pose(phase[0])
		_t.check("preview visible " + phase[1], preview._props[phase[1]].visible, "visible at %.2f" % phase[0])
	preview.free()
