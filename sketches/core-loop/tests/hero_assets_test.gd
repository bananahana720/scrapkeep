extends SceneTree
# 2026-10-10 (PD-0): the glass-hull check becomes a lattice check for Hoberman shells (Core
# outer radius 0.95 to 0.985, no glass slot; Pod > Gyro and Pod > Dome > Pilot kept), run on
# the neutral fixture shell; the three VD-01 glass shells keep the glass check until their P-D
# units rebuild them on the lattice. The paint check adds ROSTER-LOOK section 6's enamels:
# Rivet's charcoal steel and Tally's mulberry (sampled from concepts/codex/tally/hero.png).
# 2026-10-10 (PD-0b): re-pin of 'gyro rolls'. A shell whose Gyro carries GyroInner (every
# shell_base.hoberman() shell) turns its rings from the Core's turn (counter_tilt), not the
# velocity, and counter_tilt reads global transforms, so it does nothing outside the tree.
# For those shells the velocity check gives way to the gimbal case: the stub steers before it
# is in the tree with no engine ERROR, then, in the tree with the Core turned by a known angle,
# Gyro.rotation.x and GyroInner.rotation.y follow counter_tilt within 0.01 rad. It always runs
# on the neutral shell, and on every pilot whose own shell has GyroInner. Shells without
# GyroInner keep the velocity check. The heft-layer case: a layer's WeaponRing node rides the
# base WeaponRing, so a module on it yaws with the aim.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Parts := preload("res://src/build/parts.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const Game := preload("res://src/game.gd")

# V3 hero assets: every glb carries only section 9 slot names and hits its tri band,
# each shell's rolling core fits the player collider, paint and enamel colours come from
# the palette, the hook dresses a stub player per class (and follows class changes,
# heading and the glide vane), and in a running game it dresses the player, the
# accretion chunks and each reward gate while hiding, not deleting, the placeholders.

const MODELS := "res://assets/models/"
const SHELL_TRIS := Vector2i(3000, 6500)
const PILOT_TRIS := Vector2i(400, 4800)
const CHUNK_TRIS := {"small": Vector2i(60, 120), "medium": Vector2i(150, 300), "large": Vector2i(400, 800)}
const GATE_TRIS := Vector2i(1500, 3700)  # 2026-10-18 polish: was 2500 (tools/blender/POLISH.md)
const WARDEN_BASE_TRIS := Vector2i(4000, 14000)  # polished 18 Oct (POLISH.md)
const WARDEN_KIT_TRIS := Vector2i(800, 4600)  # polished 18 Oct (POLISH.md)
const ANCIENT_SLOTS := ["ancient_enamel", "ancient_light", "bare_metal", "rubber"]
const ENAMEL_CAP := 0.45
const NEUTRAL_SHELL := "res://assets/models/world_one/shell_neutral.glb"
const MULBERRY := Color("8a3d46")
const LATTICE_RADIUS := Vector2(0.95, 0.985)


class StubState:
	var velocity := Vector3.ZERO


class StubKit:
	var gliding := false


# The whole surface the hook reads from a player: class_def, class_color(), state,
# kit, roll_node() under the rolling mesh, and juice_node().
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


# Engine errors, read as a count before and after one step.
class ErrorLog extends Logger:
	var errors: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file.get_file(), line, code, rationale])


const GIMBAL_TURN := Vector3(0.4, 0.25, 0.0)

var _failures := 0
var _game
var _ticks := 0
var _gate_ids: Array = []
var _errors := ErrorLog.new()
# Class ids whose own shell has Gyro > GyroInner; _check_stub fills it.
var _gimbal_ids: Array[String] = []
# [hook, stub, label] fitted outside the tree; _check_gimbals turns them once in it.
var _gimbals: Array = []
var _in_tree_done := false


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	OS.add_logger(_errors)
	_check_models()
	_check_stub()
	_fit_gimbals()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if not _in_tree_done:
		_in_tree_done = true
		_check_gimbals()
		_check_layer_ring()
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(1)
		return false
	if _ticks == 12:
		_game.build.accretion.show_build(400.0, [], [], 3)
		_gate_ids = Parts.ids().slice(0, 2)
		var ball: Vector3 = _game.player.body().global_position
		_game.build.gates.open(_gate_ids, ball, Vector3.FORWARD)
		return false
	if _ticks < 15:
		return false
	_check_game()
	print("hero_assets_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	OS.remove_logger(_errors)
	quit(0 if _failures == 0 else 1)
	return true


# --- glb checks ----------------------------------------------------------------------

static func tris(mesh: Mesh) -> int:
	var n := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var index = arrays[Mesh.ARRAY_INDEX]
		n += (index.size() if index != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


static func meshes(node: Node, out: Array = []) -> Array:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		meshes(c, out)
	return out


static func tri_sum(nodes: Array, skip: Array = []) -> int:
	var n := 0
	for mi in nodes:
		if not (String(mi.name) in skip):
			n += tris(mi.mesh)
	return n


func _slots_ok(label: String, scene: Node, allowed: Array) -> void:
	var bad := []
	for mi in meshes(scene):
		for i in mi.mesh.get_surface_count():
			var slot := HeroAssets.slot_of(mi.mesh, i)
			if not (slot in allowed):
				bad.append("%s:%s" % [mi.name, slot])
	_report(label + " slots", bad.is_empty(), "every surface is a section 9 slot %s" % [bad])


static func _near_any(c: Color, set: Array) -> bool:
	for p in set:
		var lin: Color = (p as Color).srgb_to_linear()
		if absf(c.r - lin.r) < 0.01 and absf(c.g - lin.g) < 0.01 and absf(c.b - lin.b) < 0.01:
			return true
	return false


# Vertex colours of every surface with this slot.
static func slot_colors(scene: Node, slot: String) -> Array:
	var out := []
	for mi in meshes(scene):
		for i in mi.mesh.get_surface_count():
			if HeroAssets.slot_of(mi.mesh, i) == slot:
				var cols = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
				if cols != null:
					out.append_array(Array(cols))
	return out


func _band(label: String, n: int, band: Vector2i) -> void:
	_report(label, n >= band.x and n <= band.y, "%d tris in %d..%d" % [n, band.x, band.y])


func _check_models() -> void:
	var slots: Array = HeroAssets.SLOTS.keys()
	var paint_set := [Palette.VERDIGRIS, Palette.RUST, Palette.SAND, Palette.CHARCOAL, MULBERRY]
	_check_lattice(slots, paint_set)
	for shell in ["sable", "rivet", "kest"]:
		var scene: Node = (load(MODELS + "shell_%s.glb" % shell) as PackedScene).instantiate()
		var all := meshes(scene)
		_slots_ok(shell, scene, slots)
		_band(shell + " shell", tri_sum(all, ["Pilot"]), SHELL_TRIS)
		var pilot := scene.find_child("Pilot", true, false) as MeshInstance3D
		_band(shell + " pilot", tris(pilot.mesh) if pilot != null else 0, PILOT_TRIS)
		var core := scene.find_child("Core", true, false) as MeshInstance3D
		var pod := scene.find_child("Pod", true, false) as Node3D
		var dome := scene.find_child("Dome", true, false) as Node3D
		_report(shell + " nodes", core != null and pod != null and dome != null and dome.get_parent() == pod
			and pilot != null and pilot.get_parent() == dome, "Core, Pod > Dome > Pilot")
		var far := 0.0
		for i in core.mesh.get_surface_count():
			for v in core.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
				far = maxf(far, (core.transform * v).length())
		_report(shell + " core", far <= Tuning.RADIUS, "rolling core reaches %.3f m, collider %.2f m" % [far, Tuning.RADIUS])
		if core.find_child("Hub_00", false, false) != null:
			_report(shell + " lattice", _lattice_ok(core), "Hoberman Core, outer radius %.2f to %.3f, no glass slot" % [LATTICE_RADIUS.x, LATTICE_RADIUS.y])
		else:
			# A VD-01 glass shell, until its P-D unit rebuilds it on the lattice.
			var glass_vertices := 0
			var sphere_error := 0.0
			for surface in core.mesh.get_surface_count():
				if HeroAssets.slot_of(core.mesh, surface) == "glass":
					for v in core.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
						glass_vertices += 1
						sphere_error = maxf(sphere_error, absf((core.transform * v).length() - 0.98))
			_report(shell + " sphere", glass_vertices > 500 and sphere_error < 0.001,
				"full radius-0.98 glass hull (%d vertices, error %.6f)" % [glass_vertices, sphere_error])
		var pilot_far := 0.0
		for surface in pilot.mesh.get_surface_count():
			for v in pilot.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				pilot_far = maxf(pilot_far, (pod.transform * dome.transform * pilot.transform * v).length())
		_report(shell + " seated inside", pilot_far < 0.94, "pilot enclosed, radius %.3f" % pilot_far)
		_report(shell + " gyro", pod.get_node_or_null("Gyro") != null, "independent gyro under upright Pod")
		var off := slot_colors(scene, "paint").filter(func(c): return not _near_any(c, paint_set))
		_report(shell + " paint", off.is_empty(), "paint vertex colours are petrol, iron oxide or bone (%d off)" % off.size())
		scene.free()
	var kest: Node = (load(MODELS + "shell_kest.glb") as PackedScene).instantiate()
	_report("kest vane", kest.find_child("VaneL", true, false) != null and kest.find_child("VaneR", true, false) != null, "VaneL and VaneR hinge under Pod")
	kest.free()
	var sable: Node = (load(MODELS + "shell_sable.glb") as PackedScene).instantiate()
	_report("sable rope", sable.find_child("RopeExit", true, false) != null, "RopeExit marks the fairlead")
	sable.free()

	var chunks: Node = (load(MODELS + "chunks.glb") as PackedScene).instantiate()
	_slots_ok("chunks", chunks, ["paint", "bare_metal", "rubber"])
	for size in CHUNK_TRIS:
		for v in 3:
			var mi := chunks.find_child("chunk_%s_%d" % [size, v], true, false) as MeshInstance3D
			_band("chunk_%s_%d" % [size, v], tris(mi.mesh) if mi != null else 0, CHUNK_TRIS[size])
	var chunk_paint := slot_colors(chunks, "paint").filter(func(c): return not _near_any(c, paint_set))
	_report("chunks paint", chunk_paint.is_empty(), "paint vertex colours are petrol, iron oxide or bone (%d off)" % chunk_paint.size())
	chunks.free()

	var gate: Node = (load(MODELS + "reward_gate.glb") as PackedScene).instantiate()
	_slots_ok("gate", gate, ["paint", "bare_metal", "rubber", "rarity", "field"])
	var base := 0
	for n in ["Arch", "GlyphPlate0", "GlyphPlate1", "GlyphPlate2"]:
		var mi := gate.find_child(n, true, false) as MeshInstance3D
		base += tris(mi.mesh) if mi != null else 0
	for rarity in ["common", "rare", "relic", "evolved"]:
		var top := gate.find_child(HeroAssets.topper_name(rarity), true, false) as MeshInstance3D
		_report("gate topper " + rarity, top != null and top.mesh != null, "%s resolves to a mesh" % HeroAssets.topper_name(rarity))
		_band("gate " + rarity, base + (tris(top.mesh) if top != null and top.mesh != null else 0), GATE_TRIS)
	gate.free()

	var warden: Node = (load(MODELS + "warden_clamp_base.glb") as PackedScene).instantiate()
	_slots_ok("warden base", warden, ANCIENT_SLOTS)
	_band("warden base", tri_sum(meshes(warden)), WARDEN_BASE_TRIS)
	var named := ["Housing", "Tower", "KitMount", "JawL", "JawR"].filter(func(n): return warden.find_child(n, true, false) == null)
	_report("warden nodes", named.is_empty(), "Housing, Tower > KitMount, JawL, JawR (missing %s)" % [named])
	_check_enamel("warden base", warden)
	warden.free()
	for fam in ["reactor", "hive", "mind"]:
		var kit: Node = (load(MODELS + "warden_kit_%s.glb" % fam) as PackedScene).instantiate()
		_slots_ok("kit " + fam, kit, ANCIENT_SLOTS)
		_band("kit " + fam, tri_sum(meshes(kit)), WARDEN_KIT_TRIS)
		_report("kit " + fam + " weak point", kit.find_child("WeakPoint", true, false) != null, "WeakPoint node")
		_check_enamel("kit " + fam, kit)
		kit.free()


# A Hoberman Core: outer radius inside LATTICE_RADIUS and no glass slot.
static func _lattice_ok(core: MeshInstance3D) -> bool:
	var far := 0.0
	for i in core.mesh.get_surface_count():
		if HeroAssets.slot_of(core.mesh, i) == "glass":
			return false
		for v in core.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
			far = maxf(far, (core.transform * v).length())
	return far >= LATTICE_RADIUS.x and far <= LATTICE_RADIUS.y + 0.0001


# PD-0's neutral Hoberman shell: the lattice check, slot names, paint colours and the node
# tree every pilot shell keeps (Pod > Gyro, Pod > Dome > Pilot, Pod > WeaponRing).
func _check_lattice(slots: Array, paint_set: Array) -> void:
	var packed := load(NEUTRAL_SHELL) as PackedScene
	_report("neutral shell", packed != null, NEUTRAL_SHELL)
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	_slots_ok("neutral", scene, slots)
	var core := scene.find_child("Core", true, false) as MeshInstance3D
	var pod := scene.find_child("Pod", true, false) as Node3D
	var dome: Node3D = null
	if pod != null:
		dome = pod.get_node_or_null("Dome") as Node3D
	_report("neutral lattice", core != null and _lattice_ok(core) and core.find_child("Hub_00", false, false) != null,
		"Hoberman Core, outer radius %.2f to %.3f, no glass slot" % [LATTICE_RADIUS.x, LATTICE_RADIUS.y])
	_report("neutral nodes", pod != null and pod.get_node_or_null("Gyro") != null and pod.get_node_or_null("WeaponRing") != null
		and dome != null and dome.get_node_or_null("Pilot") != null, "Pod > Gyro, Pod > WeaponRing, Pod > Dome > Pilot")
	var off := slot_colors(scene, "paint").filter(func(c): return not _near_any(c, paint_set))
	_report("neutral paint", off.is_empty(), "paint vertex colours are section 6 enamels (%d off)" % off.size())
	scene.free()


# Section 11: ancient enamel never passes HSV value or saturation 45%.
func _check_enamel(label: String, scene: Node) -> void:
	var worst := 0.0
	for c in slot_colors(scene, "ancient_enamel"):
		var s: Color = (c as Color).linear_to_srgb()
		worst = maxf(worst, maxf(s.v, s.s))
	_report(label + " enamel", worst <= ENAMEL_CAP + 0.005, "enamel HSV value and saturation peak %.3f, cap %.2f" % [worst, ENAMEL_CAP])


# --- the hook on a stub player ---------------------------------------------------------

func _check_stub() -> void:
	var hook := HeroAssets.new()
	root.add_child(hook)
	var stub := StubPlayer.new()
	root.add_child(stub)
	hook.attach_player(stub)
	for def in ClassDef.all():
		stub.class_def = def
		hook._process(0.016)
		var rec: Dictionary = hook.shell_of(stub)
		var core: Node3D = rec.get("core")
		var pod: Node3D = rec.get("pod")
		_report("stub " + def.id, rec.get("class") == def.id and core != null and core.get_parent() == stub._mesh
			and pod != null and pod.get_parent() == stub._juice and stub._mesh.layers == 0
			and pod.find_child("Pilot", true, false) != null,
			"shell fitted: core under the rolling mesh, pod on the juice node, placeholder hidden")
		var accent := _accent_color(pod)
		_report("stub " + def.id + " accent", accent.is_equal_approx(def.color), "class_accent wears the class row colour")
		if pod != null and pod.has_node("Gyro/GyroInner"):
			_gimbal_ids.append(def.id)
	# The vane check below is Kest's, so end the loop on Kest whatever order the roster ends in.
	stub.class_def = ClassDef.by_id("demolitions_caster")
	hook._process(0.016)
	var resting_gyro: Node3D = hook.shell_of(stub)["pod"].get_node("Gyro")
	var resting_basis := resting_gyro.basis
	hook._process(0.5)
	_report("gyro rests", resting_gyro.basis.is_equal_approx(resting_basis), "no velocity means no gyro motion")
	stub.state.velocity = Vector3(10.0, 0.0, 0.0)
	hook._process(1.0)
	var pod: Node3D = hook.shell_of(stub)["pod"]
	# A GyroInner shell's rings follow the Core, so _check_gimbals covers this class instead.
	if not resting_gyro.has_node("GyroInner"):
		_report("gyro rolls", not resting_gyro.basis.is_equal_approx(resting_basis), "real velocity moves the independent ring")
	_report("pilot upright", pod.basis.y.is_equal_approx(Vector3.UP), "gyro leaves pilot upright")
	var forward := -pod.transform.basis.z
	_report("stub heading", forward.dot(Vector3.RIGHT) > 0.99, "pod faces the heading (%s)" % forward)
	stub.kit.gliding = true
	hook._process(1.0)
	var vane := pod.find_child("VaneL", true, false) as Node3D
	_report("stub vane", vane != null and absf(vane.rotation.z - PI * 0.5) < 0.01, "Kest's vane opens while gliding")
	stub.free()
	hook.free()


static func _accent_color(pod: Node) -> Color:
	for mi in meshes(pod):
		for i in mi.mesh.get_surface_count():
			if HeroAssets.slot_of(mi.mesh, i) == "class_accent":
				return (mi.get_surface_override_material(i) as StandardMaterial3D).albedo_color
	return Color.BLACK


# --- the Hoberman gimbal on a stub (PD-0b) ------------------------------------------------

# Fits each GyroInner shell on a stub and steers it outside the tree before parenting it to
# root: the neutral shell as Sable's, plus every pilot whose own shell has GyroInner. Keeping
# hook and stub unparented during the check holds in both solo runs (where _initialize runs
# before root enters the tree) and warm batches (where root is already in the tree).
func _fit_gimbals() -> void:
	var setups: Array = [["neutral", "pylon_engineer", {"pylon_engineer": NEUTRAL_SHELL}]]
	for id in _gimbal_ids:
		setups.append([id, id, {}])
	for setup in setups:
		var hook := HeroAssets.new()
		hook.shell_assets = setup[2]
		var stub := StubPlayer.new()
		stub.class_def = ClassDef.by_id(setup[1])
		hook.attach_player(stub)
		var before := _errors.errors.size()
		hook._process(0.016)
		var pod = hook.shell_of(stub).get("pod")
		var fitted: bool = pod != null and pod.has_node("Gyro/GyroInner") and not pod.is_inside_tree()
		_report("gimbal %s out of tree" % setup[0], fitted and _errors.errors.size() == before,
			"GyroInner shell steered outside the tree, engine errors %s" % [_errors.errors.slice(before)])
		root.add_child(hook)
		root.add_child(stub)
		_gimbals.append([hook, stub, setup[0]])


# In the tree: turn each stub's Core by GIMBAL_TURN; Gyro.rotation.x and GyroInner.rotation.y
# follow counter_tilt (the Core's turn against the upright Pod) within 0.01 rad.
func _check_gimbals() -> void:
	for g in _gimbals:
		var hook: Node = g[0]
		var stub: StubPlayer = g[1]
		var rec: Dictionary = hook.shell_of(stub)
		var core: Node3D = rec.get("core")
		var pod: Node3D = rec.get("pod")
		var ok := core != null and pod != null and core.is_inside_tree()
		var detail := "no shell in the tree"
		if ok:
			core.basis = Basis.from_euler(GIMBAL_TURN, EULER_ORDER_XYZ)
			var before := _errors.errors.size()
			hook._process(0.016)
			var gyro := pod.get_node("Gyro") as Node3D
			var inner := gyro.get_node("GyroInner") as Node3D
			var rel := (pod.global_basis.orthonormalized().inverse() * core.global_basis.orthonormalized()).get_euler(EULER_ORDER_XYZ)
			ok = _errors.errors.size() == before and absf(gyro.rotation.x - rel.x) < 0.01 and absf(inner.rotation.y - rel.y) < 0.01 \
				and absf(gyro.rotation.x - GIMBAL_TURN.x) < 0.01 and absf(inner.rotation.y - GIMBAL_TURN.y) < 0.01
			detail = "Gyro.x %.3f, GyroInner.y %.3f, counter_tilt %.3f, %.3f, turn %.2f, %.2f" % [gyro.rotation.x, inner.rotation.y, rel.x, rel.y, GIMBAL_TURN.x, GIMBAL_TURN.y]
		_report("gimbal %s follows the Core" % g[2], ok, detail)
		stub.free()
		hook.free()
	_gimbals.clear()


# A heft layer whose Pod carries a WeaponRing node: its children ride the base WeaponRing, so
# after steer_weapon_ring to a 30 degree yaw a module on it has the base ring's world yaw, and
# it shows and hides with its class.
func _check_layer_ring() -> void:
	var layer := Node3D.new()
	var lcore := Node3D.new()
	lcore.name = "Core"
	var lpod := Node3D.new()
	lpod.name = "Pod"
	var lring := Node3D.new()
	lring.name = "WeaponRing"
	var module := MeshInstance3D.new()
	module.name = "RingModule"
	module.mesh = BoxMesh.new()
	module.position = Vector3(0.0, 0.0, -1.1)
	layer.add_child(lcore)
	layer.add_child(lpod)
	lpod.add_child(lring)
	lring.add_child(module)
	for n in [lcore, lpod, lring, module]:
		n.owner = layer
	var packed := PackedScene.new()
	packed.pack(layer)
	layer.free()
	var hook := HeroAssets.new()
	hook.shell_assets = {"ring_fixture": NEUTRAL_SHELL, "ring_fixture_c2": "fixture://ring_layer"}
	hook._scenes["fixture://ring_layer"] = packed
	root.add_child(hook)
	var ball := Node3D.new()
	root.add_child(ball)
	var rec: Dictionary = hook.fit_shell_into(ball, "pylon_engineer", "ring_fixture", 2, {})
	var pod: Node3D = rec.get("pod")
	var ring: Node3D = pod.get_node_or_null("WeaponRing") if pod != null else null
	var carried: Node3D = ball.find_child("RingModule", true, false) as Node3D
	_report("layer ring fitted", ring != null and carried != null, "the fixture's RingModule is in the fitted shell")
	if ring != null and carried != null:
		var want := deg_to_rad(30.0)
		hook.steer_weapon_ring(pod, Vector3(-sin(want), 0.0, -cos(want)), 10.0)
		var rz := ring.global_basis.z
		var mz := carried.global_basis.z
		var ring_yaw := atan2(rz.x, rz.z)
		var module_yaw := atan2(mz.x, mz.z)
		_report("layer ring yaws with the aim", ring.is_ancestor_of(carried) and absf(angle_difference(ring_yaw, want)) < 0.01
			and absf(angle_difference(module_yaw, ring_yaw)) < 0.01,
			"base ring %.3f rad, module %.3f rad, aim %.3f rad" % [ring_yaw, module_yaw, want])
		var shown := carried.is_visible_in_tree()
		hook.set_heft_class(rec, 1, false)
		var hidden := not carried.is_visible_in_tree()
		hook.set_heft_class(rec, 2, false)
		_report("layer ring follows its class", shown and hidden and carried.is_visible_in_tree(), "shown at II %s, hidden at I %s, shown again %s" % [shown, hidden, carried.is_visible_in_tree()])
	ball.free()
	hook.free()


# --- the hook in a running game --------------------------------------------------------

func _check_game() -> void:
	var hook = _game.presentation.hero_assets
	var player = _game.player
	var rec: Dictionary = hook.shell_of(player)
	_report("game shell", rec.get("class") == "runner_gunner" and player.roll_node().get_parent().layers == 0,
		"the chosen class wears Rivet's shell and the greybox ball is hidden")
	var chunks := []
	for c in _game.build.accretion.get_children():
		if c is MeshInstance3D:
			chunks.append(c)
	var dressed := chunks.filter(func(c): return c.has_node("HeroChunk") and c.layers == 0)
	_report("game chunks", not chunks.is_empty() and dressed.size() == chunks.size(),
		"%d of %d accretion chunks dressed" % [dressed.size(), chunks.size()])
	var gates: Array = _game.build.gates.get_children()
	_report("game gates open", gates.size() == _gate_ids.size(), "%d gates for %d offers" % [gates.size(), _gate_ids.size()])
	for i in gates.size():
		var gate: Node3D = gates[i]
		var offer: Dictionary = _game.build.gates.offers[i]
		var arch := gate.get_node_or_null("HeroArch") as MeshInstance3D
		var topper := gate.get_node_or_null("Topper/HeroTopper") as MeshInstance3D
		var hidden := true
		for c in gate.get_children():
			if c is MeshInstance3D and not String(c.name).begins_with("Hero"):
				hidden = hidden and c.layers == 0
		var glyphs := gate.get_children().filter(func(c): return c is Sprite3D).size()
		var plates := gate.get_children().filter(func(c): return String(c.name).begins_with("HeroPlate")).size()
		var tint := Color.BLACK
		if arch != null:
			for s in arch.mesh.get_surface_count():
				if HeroAssets.slot_of(arch.mesh, s) == "rarity":
					tint = (arch.get_surface_override_material(s) as StandardMaterial3D).albedo_color
		_report("game gate %d" % i, arch != null and topper != null and hidden and plates == glyphs
			and tint.is_equal_approx(RewardGates.rarity_color(offer["rarity"])),
			"%s arch, topper and %d glyph plates dressed, placeholders hidden, rarity tint from rarity_color" % [offer["rarity"], plates])
