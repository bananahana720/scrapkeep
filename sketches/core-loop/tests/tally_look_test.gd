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
const Trees := preload("res://src/core/upgrade_tree.gd")
const Indicator := preload("res://src/movement/indicator.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const T := preload("res://tests/support/t.gd")

# Tally's presentation: ledger cream, punched program cards, and a count of four followed by
# a struck total. Card pitches follow the count intervals.
# Re-pinned 2026-10-11 for wave P-C unit PC-TALLY (design-v3/pilots/tally.md section 10,
# A2-CRITIC lore fix): her icons were pinned to brass #d9b44a, Brindle's colour on friendly gear;
# all nine now carry ledger cream #e6d9b8 and no brass. The special slot reads ab_tally_gather
# (Gather Plate is slot 2), and ICON_SLOTS gains the line (ab_tally_line) and ult (ab_tally_ult)
# icons. Measured on 4ae242b plus this unit: 79 checks, registry 70 ids.
const SHELL := "res://assets/models/world_one/shell_tally.glb"
const PILOT := "res://assets/models/pilot_tally_anim.glb"
const SLOTS := ["weapon", "move", "gather", "smash"]
const ICON_SLOTS := ["weapon", "move", "special", "smash", "gather", "link", "balance", "line", "ult"]
const LEDGER_CREAM := "#e6d9b8"
const BRASS := "#d9b44a"
const CUES := ["tally_balance_due", "tally_ready", "tally_break", "mind_tally"]

var _t := T.new("tally_look_test")


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
	_check_preview()
	quit(_t.verdict())
	return true


func _check_row() -> void:
	var def: Resource = ClassDef.by_id("tally")
	_t.eq("row motif", def.motif, "tally")
	_t.check("row shape", def.shape == "square" and def.shape in EventKinds.SHAPES and Icons.SHAPES.has(def.shape),
		"shape %s in EventKinds.SHAPES and Icons.SHAPES" % def.shape)
	_t.check("row colour", def.color == ClassDef.TALLY_COLOR, "colour %s" % def.color.to_html())
	_t.check("row sound", SfxBank.has_recipe(def.sound), "sound %s is a bank recipe" % def.sound)
	var sharing := ClassDef.all().filter(func(d): return d.id != "tally" and d.motif == "tally").map(func(d): return d.id)
	_t.eq("motif unshared", sharing, [])
	var shapes := ClassDef.all().filter(func(d): return d.id != "tally" and d.shape == "square").map(func(d): return d.id)
	_t.eq("shape unshared", shapes, [])


func _check_model() -> void:
	_t.eq("shell path", HeroAssets.SHELLS["tally"], SHELL)
	_t.eq("pilot path", HeroAssets.PILOTS["tally"], PILOT)
	var paired: Array = []
	for def in ClassDef.all():
		if def.id != "tally" and HeroAssets.SHELLS.get(def.id) == SHELL and HeroAssets.PILOTS.get(def.id) == PILOT:
			paired.append(def.id)
	_t.eq("model pair unshared", paired, [])
	var hook := HeroAssets.new()
	root.add_child(hook)
	var stub := StubPlayer.new()
	root.add_child(stub)
	hook.attach_player(stub)
	stub.class_def = ClassDef.by_id("tally")
	hook._process(0.016)
	var rec: Dictionary = hook.shell_of(stub)
	var core: Node3D = rec.get("core")
	var pod: Node3D = rec.get("pod")
	var pilot: Node3D = pod.get_node_or_null("AnimatedPilot") if pod != null else null
	_t.check("fit", core != null and pod != null and pilot != null, "Core, Pod and an AnimatedPilot under Pod")
	if pod != null:
		var accent := _accent_color(pod)
		_t.check("accent", accent.is_equal_approx(ClassDef.TALLY_COLOR), "class_accent %s" % accent.to_html())
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
	var tint: Color = tinter.paint_tint("tally", "paint_tally_cream")
	_t.eq("paint", tint, Color("f7f1e3"))
	_t.check("paint lighter", tint.get_luminance() - ClassDef.TALLY_COLOR.get_luminance() >= 0.08,
		"paint %.6f trim %.6f delta %.6f" % [tint.get_luminance(), ClassDef.TALLY_COLOR.get_luminance(), tint.get_luminance() - ClassDef.TALLY_COLOR.get_luminance()])
	_t.check("paint cream", tint.r >= tint.g and tint.g >= tint.b, "cream %s" % tint.to_html())
	tinter.free()
	var text := FileAccess.get_file_as_string("res://src/presentation/hero_assets.gd")
	var flagged: Array = []
	for line in text.split("\n"):
		if line.contains("\"tally\"") and (line.to_lower().contains("placeholder") or line.to_lower().contains("stands in") or line.to_lower().contains("stand-in")):
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
	var dir := DirAccess.open("res://assets/icons")
	var others: Array = []
	for file in dir.get_files():
		if file.begins_with("ab_") and not file.begins_with("ab_tally_") and file.ends_with(".svg"):
			others.append([file, FileAccess.get_file_as_string("res://assets/icons/" + file)])
	for slot in ICON_SLOTS:
		var id: String = "ab_tally_" + slot
		var path: String = "res://assets/icons/%s.svg" % id
		var svg := FileAccess.get_file_as_string(path)
		var copies: Array = []
		for other in others:
			if svg == other[1]:
				copies.append(other[0])
		_t.check(id + " drawn", FileAccess.file_exists(path) and svg != "" and copies.is_empty(), "%s exists; matching borrowed files %s" % [path, copies])
		_t.check(id + " palette", svg.contains(LEDGER_CREAM) and not svg.to_lower().contains(BRASS) and not svg.contains("#e5a044")
			and not svg.contains("#8bf0d3"), "ledger cream accent, no brass, amber or mint")
		var tex := Icons.texture(id)
		_t.check(id + " registered", Icons.EXTRA.has(id) and tex != null and tex.get_width() > 0 and Icons.from_file(id),
			"in Icons.EXTRA, loads from its file")
	_t.eq("registry ids", Icons.ids().size(), 70)
	var def: Resource = ClassDef.by_id("tally")
	var named: Array = []
	for ability in [def.weapon_id, def.movement_id, def.special_id, def.smash_id]:
		named.append(AbilityState.ABILITIES[ability]["icon"])
	_t.eq("ability icons", named, SLOTS.map(func(s): return "ab_tally_" + s))
	var borrowed: Array = []
	for node in Trees.TREES["tally"]:
		if not String(node.get("icon", "")).begins_with("ab_tally_"):
			borrowed.append(node.get("id"))
	_t.eq("tree icons", borrowed, [])


func _check_motif() -> void:
	_t.eq("motif family", Harmony.motif("tally").get("family"), "class")
	_t.eq("motif notes", Harmony.motif_notes("tally"), [62, 64, 65, 67, 74])
	_t.eq("release", Rows.releases("tally"), ["tally_balance_due"])
	_t.eq("ready", Rows.resolve("class_motif", {"motif": "tally"}), "tally_ready")
	_t.eq("break", Rows.resolve("class_break", {"motif": "tally"}), "tally_break")
	_t.eq("mind quote", Roster.voiced("mind_quote", "tally"), "mind_tally")
	for id in CUES:
		var peak := Synth.peak(SfxBank.samples(id))
		_t.check(id + " bakes", peak >= 0.1, "peak %.3f" % peak)
		_t.check(id + " keyed", id in Audio.KEYED_SOUNDS, "in Audio.KEYED_SOUNDS")
	_t.eq("mind gap", Audio.MIN_GAP_MS.get("mind_tally"), 600)
	_t.check("class motif listed", "tally" in Harmony.CLASS_MOTIFS, "tally in CLASS_MOTIFS")
	var quote := Harmony.mind_quote("tally").map(func(cell): return cell[1])
	_t.eq("mind intervals", quote, [62, 60, 59, 57, 49]) # D C B A C#, inverted around D.


func _check_feel() -> void:
	var notes := Harmony.motif_notes("tally")
	var cards := ["gather_plate", "link_clips", "balance_due"]
	for i in cards.size():
		var interval: int = notes[i + 1] - notes[0] if notes.size() > i + 1 else -999
		_t.eq(cards[i] + " pitch", Audio.WEAPON_PITCH.get(cards[i]), interval)


func _check_ticks() -> void:
	var counts: Array = []
	for ticks in ["square", ""]:
		var ind := Indicator.new()
		root.add_child(ind)
		ind.set_shape("special", {"kind": "ring", "centre": Vector3.ZERO, "radius": 6.0, "color": ClassDef.TALLY_COLOR,
			"ticks": ticks, "fill": 1.0})
		ind._process(0.0)
		counts.append(ind._tris.get_faces().size())
		ind.free()
	_t.check("square ticks draw", counts[0] > counts[1], "vertices with square ticks %d, without %d" % counts)


func _check_preview() -> void:
	var preview := ClassPreview.new(ClassDef.by_id("tally"))
	for id in ["plate0", "plate1", "plate2", "surge", "stamp", "slam"]:
		_t.check("preview " + id, preview._props.has(id), "has its own Tally prop")
	_t.check("preview no borrowed props", not preview._props.has("lane") and not preview._props.has("post"), "no cannon lane or Sable post")
	_t.eq("preview rest", ClassPreview.REST["tally"], 0.3)
	for phase in [[0.5, "surge"], [0.78, "stamp"], [0.78, "slam"]]:
		preview._pose(phase[0])
		_t.check("preview visible " + phase[1], preview._props[phase[1]].visible, "visible at %.2f" % phase[0])
	var props := ["plate0", "plate1", "plate2"]
	preview._pose(0.3)
	var climbing := props.filter(func(id): return preview._props[id].visible)
	preview._pose(0.95)
	var resting := props.filter(func(id): return preview._props[id].visible)
	_t.check("preview plates", not climbing.is_empty() and resting.is_empty(),
		"visible at 0.30 %s, at 0.95 %s" % [climbing, resting])
	preview.free()
