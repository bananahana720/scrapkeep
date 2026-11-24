extends SceneTree
# 2026-10-11 (PC-CANNON): add line/ultimate icons and the family-note map; shell pins stay PD-owned.
# 2026-11-23 (E2-06): the rebuilt shell's budget, reach and moving parts, and the machinery rows of
# clips/cannon.json played frame by frame on the real shell_cannon.glb: the split ports' rear jaws
# close as gauge_fill rises and meet flush at the lock, snap open on the shot and settle at rest,
# and the breech collar kicks back along the bore and eases home, carrying on (never snapping
# home) when a second shot lands mid-return.

const ClassDef := preload("res://src/core/class_def.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Icons := preload("res://src/ui/icons.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const MechaMotion := preload("res://src/presentation/mecha_motion.gd")
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
const CLIPS := "res://src/presentation/clips/cannon.json"
# Shell budget: draws within the registry exception (and never past 14), triangles held at
# hero_six_pilot_budget_test's OVER_CAP row, vertices within the shell class.
const DRAW_CAP := 14
const TRI_HOLD := 7738
const VERT_CAP := 11600
# Andrew's ruling of 23 Nov 2026: weapon reach up to 1.75 m, nothing outside the ball below -0.55 m.
const REACH_CAP := 1.75
const LATTICE := 0.985
const GROUND_Y := -0.55
const JAWS := ["JawUpper.R", "JawLower.R", "JawUpper.L", "JawLower.L"]
# shell_cannon.py: each jaw is 0.075 m tall and travels 0.07 m, so the pair stand 0.14 m apart open.
const JAW_H := 0.075
const JAW_OPEN := 0.14
const COLLAR_KICK := 0.09
const DT := 1.0 / 60.0

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
	_check_shell_build()
	_check_motion()
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


func _load_shell() -> Node3D:
	var scene := (load(SHELL) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	return scene


# Draws, triangles and vertices of every mesh; the reach of the ring and gun; the lowest vertex
# outside the ball; and the moving parts' nodes.
func _check_shell_build() -> void:
	var shell := _load_shell()
	var draws := 0
	var tris := 0
	var verts := 0
	var reach := 0.0
	var lowest := INF
	var ring := shell.find_child("WeaponRing", true, false) as Node3D
	for mi: MeshInstance3D in shell.find_children("*", "MeshInstance3D", true, false):
		var to_shell := shell.global_transform.affine_inverse() * mi.global_transform
		for i in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(i)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			draws += 1
			verts += vs.size()
			tris += (idx.size() if idx != null and idx.size() > 0 else vs.size()) / 3
			for v in vs:
				var p := to_shell * v
				if ring != null and (mi == ring or ring.is_ancestor_of(mi)):
					reach = maxf(reach, p.length())
				if p.length() > LATTICE:
					lowest = minf(lowest, p.y)
	var exception := 0
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/registry.json"))
	for entry in registry.get("assets", []):
		if entry is Dictionary and entry.get("id", "") == "shell_cannon":
			exception = int(entry.get("exception", {}).get("draws", 0))
	_t.check("shell draws", draws <= exception and draws <= DRAW_CAP, "%d draws within the registry's %d and %d" % [draws, exception, DRAW_CAP])
	_t.check("shell tris held", tris <= TRI_HOLD, "%d tris within %d" % [tris, TRI_HOLD])
	_t.check("shell verts", verts <= VERT_CAP, "%d vertices within %d" % [verts, VERT_CAP])
	_t.check("gun reach", reach > 1.48 and reach <= REACH_CAP, "WeaponRing, MainBarrel and BreechCollar reach %.3f m, cap %.2f" % [reach, REACH_CAP])
	_t.check("ground clearance", lowest > GROUND_Y, "lowest vertex outside the ball at y %.3f, floor %.2f" % [lowest, GROUND_Y])
	var barrel := shell.find_child("MainBarrel", true, false)
	var collar := shell.find_child("BreechCollar", true, false)
	_t.check("breech collar", collar is MeshInstance3D and collar.get_parent() == barrel and barrel.get_parent() == ring,
		"WeaponRing > MainBarrel > BreechCollar")
	var ports := shell.find_child("SplitPorts", true, false)
	var skel := _skeleton(ports)
	var mesh := ports.find_child("SplitPortsMesh", true, false) as MeshInstance3D if ports != null else null
	_t.check("split port jaws", ports != null and ports.get_parent().name == "Pod" and skel != null and mesh != null
		and mesh.skin != null and JAWS.all(func(b): return skel.find_bone(b) >= 0),
		"Pod > SplitPorts > Skeleton3D with %s, and the skinned SplitPortsMesh" % [JAWS])
	shell.free()


# Plays the machinery rows of clips/cannon.json on the real shell at 60 Hz.
func _check_motion() -> void:
	var shell := _load_shell()
	var pod := shell.find_child("Pod", true, false) as Node3D
	var core := shell.find_child("Core", true, false) as Node3D
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLIPS))
	var rows: Array = table.get("machinery", [])
	MechaMotion.echo = false
	var motion = MechaMotion.new(pod, core, "remembered_cannon", rows)
	_t.eq("machinery rows all bind", motion.skip_lines, [])
	_t.check("machinery rows read facts", motion.needs_facts() and rows.size() == 9, "%d rows" % rows.size())
	var skel := _skeleton(pod.find_child("SplitPorts", true, false))
	var collar := shell.find_child("BreechCollar", true, false) as Node3D
	var collar_rest := collar.position
	# Close: the gauge rises 0 to 1 over 0.40 s and holds 0.25 s.
	var gaps: Array = []
	for f in 39:
		var g := clampf(f * DT / 0.40, 0.0, 1.0)
		motion.step(DT, {"gauge_fill": g})
		gaps.append(_gaps(skel))
	_t.check("jaws open at rest", absf(_gaps_at_rest(skel)[0] - JAW_OPEN) < 0.001, "rest gap %.4f m" % _gaps_at_rest(skel)[0])
	var shrinking := true
	var biggest := 0.0
	for i in range(1, gaps.size()):
		for side in 2:
			shrinking = shrinking and gaps[i][side] <= gaps[i - 1][side] + 1e-6
			biggest = maxf(biggest, gaps[i - 1][side] - gaps[i][side])
	_t.check("jaws close smoothly as the gauge rises", shrinking and biggest < 0.02, "never reopen; largest frame step %.4f m" % biggest)
	_t.check("jaws still closing mid-lock", gaps[12][0] > 0.02 and gaps[12][0] < JAW_OPEN - 0.01, "gap %.4f m at gauge 0.5" % gaps[12][0])
	var closed: Array = gaps[gaps.size() - 1]
	_t.check("jaws flush at the lock", absf(closed[0]) < 0.002 and absf(closed[1]) < 0.002, "gaps R %.4f, L %.4f m at a full gauge" % closed)
	# The shot: the gauge drops with it; the jaws snap open past rest and settle at rest.
	motion.shot()
	var widest := 0.0
	var settle: Array = []
	var collar_track: Array = []
	for f in 30:
		motion.step(DT, {"gauge_fill": 0.0})
		var now: Array = _gaps(skel)
		widest = maxf(widest, now[0])
		settle.append(now[0])
		collar_track.append(collar.position.z - collar_rest.z)
	_t.check("jaws snap open on the shot", settle[3] > JAW_OPEN, "gap %.4f m 4 frames after the shot (rest %.2f)" % [settle[3], JAW_OPEN])
	_t.check("jaws settle open", absf(settle[settle.size() - 1] - JAW_OPEN) < 0.001 and widest < JAW_OPEN + 0.07,
		"gap %.4f m after 0.5 s, widest %.4f" % [settle[settle.size() - 1], widest])
	var peak := 0.0
	for v in collar_track:
		peak = maxf(peak, v)
	_t.check("collar kicks back along the bore", absf(peak - COLLAR_KICK) < 0.001 and collar_track[3] > 0.08,
		"peak %.4f m on MainBarrel +Z by frame 4" % peak)
	_t.check("collar returns home", absf(collar_track[collar_track.size() - 1]) < 1e-4 and collar.position.is_equal_approx(collar_rest),
		"offset %.5f m after 0.5 s" % collar_track[collar_track.size() - 1])
	var falling := true
	for i in range(5, collar_track.size()):
		falling = falling and collar_track[i] <= collar_track[i - 1] + 1e-6 and collar_track[i - 1] - collar_track[i] < 0.012
	_t.check("collar return is smooth", falling, "out_quad return, every frame step under 0.012 m")
	# Re-trigger mid-return: the collar carries on from where it stands.
	motion.shot()
	for f in 10:
		motion.step(DT, {"gauge_fill": 0.0})
	var before := collar.position.z - collar_rest.z
	motion.shot()
	motion.step(DT, {"gauge_fill": 0.0})
	var after := collar.position.z - collar_rest.z
	_t.check("re-trigger never snaps home", before > 0.01 and after >= before - 1e-6 and after <= COLLAR_KICK + 1e-6,
		"offset %.4f m before the second shot, %.4f m one frame after" % [before, after])
	var hits := 0
	for n in shell.find_children("*", "", true, false):
		if n is Light3D or (n is GeometryInstance3D and (n as GeometryInstance3D).material_override != null):
			hits += 1
	_t.eq("no light or material_override from the rows", hits, 0)
	MechaMotion.reset_for_tests()
	shell.free()


static func _skeleton(ports: Node) -> Skeleton3D:
	var found := ports.find_children("*", "Skeleton3D", true, false) if ports != null else []
	return found[0] as Skeleton3D if not found.is_empty() else null


# Each port's gap between its jaws' facing edges (R, L), from the posed bones.
static func _gaps(skel: Skeleton3D) -> Array:
	var out: Array = []
	for side in ["R", "L"]:
		var up := skel.get_bone_global_pose(skel.find_bone("JawUpper." + side)).origin
		var low := skel.get_bone_global_pose(skel.find_bone("JawLower." + side)).origin
		out.append(up.distance_to(low) - JAW_H)
	return out


static func _gaps_at_rest(skel: Skeleton3D) -> Array:
	var out: Array = []
	for side in ["R", "L"]:
		var up := skel.get_bone_global_rest(skel.find_bone("JawUpper." + side)).origin
		var low := skel.get_bone_global_rest(skel.find_bone("JawLower." + side)).origin
		out.append(up.distance_to(low) - JAW_H)
	return out
