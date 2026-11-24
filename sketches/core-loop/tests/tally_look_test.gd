# 2026-10-12, W13 smoke triage: class c re-pin for d6e89a9.
# Tally special-slot icon ab_tally_special -> ab_tally_gather; the gather_plate declaration.
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
# 2026-11-23 (wave 46 unit E2-05, PILOT-CADENCE.md section 5.3): the flywheel's beat. The shell's
# budget, satin brass rims, the index notch under the index shoe, and clips/tally.json's beat and
# stamp rows played frame by frame on the real fitted shell (_check_shell, _check_beat).
const SHELL := "res://assets/models/world_one/shell_tally.glb"
const PILOT := "res://assets/models/pilot_tally_anim.glb"
const SLOTS := ["weapon", "move", "gather", "smash"]
const ICON_SLOTS := ["weapon", "move", "special", "smash", "gather", "link", "balance", "line", "ult"]
const LEDGER_CREAM := "#e6d9b8"
const BRASS := "#d9b44a"
const CUES := ["tally_balance_due", "tally_ready", "tally_break", "mind_tally"]
const Palette := preload("res://src/core/palette.gd")
const MechaMotion := preload("res://src/presentation/mecha_motion.gd")
# E2-05's shell budget: draws in play (registry exception 11; never past 13), triangles under the
# Hoberman shell band's top (hero_six_pilot_budget_test SHELL_CAP), and the weapon reach Andrew
# lifted from PILOT-CADENCE section 5.1's 1.35 m to 1.70 m (23 Nov 2026, cutaway-first heroes).
const MAX_DRAWS := 13
const MAX_TRIS := 6500
const MAX_REACH := 1.70
# The drum (tools/blender/shell_tally.py): its rim radius, the index notch's centre angle measured
# from forward (-Z) toward up (+Y) about the drum axis, and the notch's half-width; the charcoal
# timing bands across the tape at quarter turns from the notch, and the ground line no drum
# vertex may pass, the stamp included.
const DRUM_R := 0.505
const DRUM_Z := 0.28
const DRUM_DEPTH := 0.24
const NOTCH_AT := 123.75
const NOTCH_HALF := 10.0
const TIMING_AT := [213.75, 303.75, 33.75]
const TIMING_HALF := 6.0
const GROUND := -0.55
# The beat row: one whole turn forward (negative about X) in 0.40 s; the stamp drops 40 mm in 0.05 s.
const BEAT_DEG := -360.0
const BEAT_S := 0.40
const STAMP_M := -0.04
const STAMP_S := 0.05
const FRAME := 1.0 / 60.0
# No frame may pass the out_quad kick's first frame (29.4 degrees and 22.2 mm at 60 Hz) by more
# than a hair: anything bigger is a snap.
const TURN_JUMP := 31.0
const STAMP_JUMP := 0.0225

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
	_check_shell()
	_check_beat()
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


# --- E2-05: the shell's budget, satin brass and the index notch under the index shoe ---------

func _check_shell() -> void:
	var shell: Node3D = (load(SHELL) as PackedScene).instantiate()
	root.add_child(shell)
	var draws := 0
	var tris := 0
	var reach := 0.0
	var slots := {}
	for node in shell.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var to_root: Transform3D = shell.global_transform.affine_inverse() * mi.global_transform
		for i in mi.mesh.get_surface_count():
			draws += 1
			slots[HeroAssets.slot_of(mi.mesh, i)] = true
			var arrays := mi.mesh.surface_get_arrays(i)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			tris += (index.size() if not index.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			for v in arrays[Mesh.ARRAY_VERTEX]:
				reach = maxf(reach, (to_root * v).length())
	_t.check("shell draws", draws <= MAX_DRAWS, "%d draws, at most %d" % [draws, MAX_DRAWS])
	_t.check("shell tris", tris <= MAX_TRIS, "%d tris, at most %d" % [tris, MAX_TRIS])
	_t.check("shell reach", reach <= MAX_REACH, "%.4f m, at most %.2f m" % [reach, MAX_REACH])
	_t.check("no Fleet brass slot", not slots.has("requisition_tag"), "slots %s" % [slots.keys()])
	var wheel := shell.find_child("Flywheel_R", true, false) as MeshInstance3D
	var brackets := shell.find_child("DrumBrackets", true, false) as MeshInstance3D
	_t.check("beat parts", wheel != null and brackets != null and shell.find_child("StampContact", true, false) != null,
		"Flywheel_R and DrumBrackets meshes and the StampContact socket")
	if wheel == null or brackets == null:
		shell.free()
		return
	# Satin brass: the rims carry Palette.BRASS at alpha 0 (no paint tints them) on the drum's one
	# paint surface, and the paint material in play is never glossier than the one satin brass finish.
	var arrays := wheel.mesh.surface_get_arrays(0)
	var brass := 0
	var brass_out := 0
	var notch_slot: Array = []
	var bands := [0, 0, 0]
	var stray: Array = []
	var low := INF
	for i in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var v: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
		var c: Color = arrays[Mesh.ARRAY_COLOR][i]
		var r := Vector2(v.y, v.z).length()
		# glTF vertex colours load linear.
		if c.a == 0.0 and _near_colour(c, Palette.BRASS.srgb_to_linear()):
			brass += 1
			if r > DRUM_R - 0.001:
				brass_out += 1
		elif c.a == 0.0 and _near_colour(c, Palette.CHARCOAL.srgb_to_linear()) and v.x > -1.0 \
				and v.x < DRUM_DEPTH / 2 - 0.02:
			# On the tape (the face bar stands on the outer face): the index slot or a timing band.
			var a := _angle(v)
			var band := TIMING_AT.find_custom(func(t): return absf(angle_difference(deg_to_rad(a), deg_to_rad(t))) <= deg_to_rad(TIMING_HALF))
			if absf(a - NOTCH_AT) <= NOTCH_HALF:
				notch_slot.append(a)
			elif band >= 0:
				bands[band] += 1
			else:
				stray.append(a)
		low = minf(low, wheel.position.y + v.y)
	_t.check("brass rims", wheel.mesh.get_surface_count() == 1 and HeroAssets.slot_of(wheel.mesh, 0) == "paint"
		and brass > 0 and brass_out > 0, "%d brass vertices at alpha 0, %d on the rim, one paint surface" % [brass, brass_out])
	var hero := HeroAssets.new()
	var paint := hero.material("paint") as StandardMaterial3D
	_t.check("satin, never glossy", paint != null and paint.roughness >= Palette.BRASS_FINISH.roughness
		and paint.metallic <= Palette.BRASS_FINISH.metallic,
		"paint roughness %.2f >= %.2f, metallic %.2f <= %.2f" % [paint.roughness if paint else -1.0,
		Palette.BRASS_FINISH.roughness, paint.metallic if paint else -1.0, Palette.BRASS_FINISH.metallic])
	hero.free()
	# The index notch: the charcoal slot in it sits at NOTCH_AT on the right drum; the only other
	# charcoal on the tape is the three timing bands, a quarter turn apart.
	var slot_ok := not notch_slot.is_empty() and stray.is_empty()
	_t.check("index notch", slot_ok, "%d slot vertices at %.1f..%.1f degrees, %d stray at %s" % [notch_slot.size(),
		notch_slot.min() if not notch_slot.is_empty() else -1.0, notch_slot.max() if not notch_slot.is_empty() else -1.0,
		stray.size(), stray.slice(0, 4)])
	_t.check("timing bands", bands.all(func(n): return n > 0), "vertices per band at %s: %s" % [TIMING_AT, bands])
	# The ground line: the drum's lowest point stays above it at the stamp's full drop.
	_t.check("drums clear the ground line under the stamp", low + STAMP_M > GROUND,
		"lowest %.4f m, %.4f m at the stamp, line %.2f m" % [low, low + STAMP_M, GROUND])
	# The index shoe: the bracket parts beside the right drum (its axial span and a hand inboard of
	# it, short of the beam's run to the gimbal) past the rim, all at the notch angle and clear of it.
	var shoe: Array = []
	var shoe_min := INF
	var drum_at := wheel.position
	for v in brackets.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var local: Vector3 = v - drum_at
		var r := Vector2(local.y, local.z).length()
		if local.x >= -(DRUM_DEPTH / 2 + 0.05) and local.x <= DRUM_DEPTH / 2 and r > DRUM_R:
			shoe.append(_angle(local))
			shoe_min = minf(shoe_min, r)
	var shoe_ok := not shoe.is_empty() and shoe.all(func(a): return absf(a - NOTCH_AT) <= NOTCH_HALF)
	_t.check("index shoe over the notch", shoe_ok and shoe_min >= DRUM_R + 0.005,
		"%d shoe vertices past the rim at %s degrees, inner face %.4f m" % [shoe.size(),
		"%.1f..%.1f" % [shoe.min(), shoe.max()] if shoe_ok else "?", shoe_min])
	shell.free()


# The angle about the drum axis from forward (-Z) toward up (+Y), in degrees 0..360.
static func _angle(v: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(v.y, -v.z)), 360.0)


static func _near_colour(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


# --- E2-05: the beat and the stamp, frame by frame on the fitted shell -----------------------

func _check_beat() -> void:
	var hook := HeroAssets.new()
	root.add_child(hook)
	var stub := StubPlayer.new()
	root.add_child(stub)
	hook.attach_player(stub)
	stub.class_def = ClassDef.by_id("tally")
	hook._process(0.016)
	var rec: Dictionary = hook.shell_of(stub)
	var mecha = rec.get("mecha")
	var wheel: Node3D = rec.pod.find_child("Flywheel_R", true, false) if rec.get("pod") != null else null
	if not _t.check("beat rows on the fitted drums", mecha != null and wheel != null and mecha.needs_facts(),
			"mecha %s, Flywheel_R %s" % [mecha, wheel]):
		stub.free()
		hook.free()
		return
	var rest := wheel.transform
	var idle := {"set_piece_phase": "idle"}
	# Still: no shot, no turn.
	var still := _play(mecha, wheel, idle, 0.5)
	_t.check("still drums stay put", is_zero_approx(still.turn) and wheel.transform.is_equal_approx(rest), "turned %.3f" % still.turn)
	# One shot: one whole turn forward, kicked fast, landed eased, stamped down and sprung back.
	mecha.shot()
	var beat := _play(mecha, wheel, idle, 0.70)
	_t.near("one shot turns one whole turn", beat.turn, BEAT_DEG, 0.01)
	_t.check("the turn only goes forward", beat.backward == 0, "%d backward frames" % beat.backward)
	_t.check("the turn never snaps", beat.jump <= TURN_JUMP, "largest frame %.2f degrees" % beat.jump)
	_t.near("the notch lands under the shoe as the window opens", beat.settled_at, BEAT_S, FRAME + 0.0001)
	_t.check("the turn lands eased", beat.last_step < 3.0, "last moving frame %.2f degrees" % beat.last_step)
	_t.check("the stamp drops", beat.drop <= STAMP_M + 0.001 and beat.drop_at <= 0.06,
		"%.4f m at %.3f s" % [beat.drop, beat.drop_at])
	_t.check("the stamp springs back without a snap", beat.dy_jump <= STAMP_JUMP and beat.back_at <= 0.26,
		"largest frame %.4f m, back at %.3f s" % [beat.dy_jump, beat.back_at])
	_t.check("the drums rest where they began", wheel.transform.is_equal_approx(rest), "%s" % wheel.transform)
	# A second shot mid-turn chains a second whole turn: the notch still parks under the shoe.
	mecha.shot()
	var first := _play(mecha, wheel, idle, 0.2)
	mecha.shot()
	var chain := _play(mecha, wheel, idle, 0.8)
	_t.near("a chained shot adds a whole turn", first.turn + chain.turn, 2.0 * BEAT_DEG, 0.01)
	# The chained shot kicks the turn left (here 1.25 turns) out_quad from where the drum is: its
	# first frame is the largest, and nothing jumps past it.
	var u := FRAME / BEAT_S
	var kick := absf(2.0 * BEAT_DEG - first.turn) * (1.0 - (1.0 - u) * (1.0 - u)) + 0.01
	_t.check("the chain never snaps or backs up", first.jump <= TURN_JUMP and chain.jump <= kick and first.backward + chain.backward == 0,
		"largest frames %.2f and %.2f (kick %.2f), backward frames %d" % [first.jump, chain.jump, kick, first.backward + chain.backward])
	_t.check("the chain rests where it began", wheel.transform.is_equal_approx(rest), "%s" % wheel.transform)
	# The set piece's flight takes one whole turn, and shots inside it add none.
	var flight := {"set_piece_phase": "flight"}
	var ride := _play(mecha, wheel, flight, 0.1)
	mecha.shot()
	ride = _merge(ride, _play(mecha, wheel, flight, 0.9))
	var after := _play(mecha, wheel, idle, 0.5)
	_t.near("the flight turns one whole turn", ride.turn + after.turn, BEAT_DEG, 0.01)
	_t.check("the flight rests where it began", wheel.transform.is_equal_approx(rest), "%s" % wheel.transform)
	stub.free()
	hook.free()


# Steps the mecha at 60 Hz for seconds with facts and reads Flywheel_R: the turn about X (unwrapped),
# frames that turned backward, the largest frame, when it last moved, the last moving frame, and
# the stamp's lowest Y offset, when, the largest Y frame and when Y came back to rest.
func _play(mecha, wheel: Node3D, facts: Dictionary, seconds: float) -> Dictionary:
	var out := {"turn": 0.0, "backward": 0, "jump": 0.0, "settled_at": 0.0, "last_step": 0.0,
		"drop": 0.0, "drop_at": 0.0, "dy_jump": 0.0, "back_at": 0.0}
	var rest_y := DRUM_Z
	var angle := wheel.rotation_degrees.x
	var y := wheel.position.y
	var t := 0.0
	for i in roundi(seconds / FRAME):
		mecha.step(FRAME, facts)
		t += FRAME
		var turned := wrapf(wheel.rotation_degrees.x - angle, -180.0, 180.0)
		angle = wheel.rotation_degrees.x
		out.turn += turned
		if turned > 1e-4:
			out.backward += 1
		out.jump = maxf(out.jump, absf(turned))
		if absf(turned) > 1e-4:
			out.settled_at = t
			out.last_step = absf(turned)
		var dy := wheel.position.y - y
		y = wheel.position.y
		out.dy_jump = maxf(out.dy_jump, absf(dy))
		if y - rest_y < out.drop:
			out.drop = y - rest_y
			out.drop_at = t
		if absf(dy) > 1e-6:
			out.back_at = t
	return out


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	return {"turn": a.turn + b.turn, "backward": a.backward + b.backward, "jump": maxf(a.jump, b.jump)}
