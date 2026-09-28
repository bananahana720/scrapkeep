extends SceneTree

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
const SHELL_TRIS := Vector2i(3000, 5000)
const PILOT_TRIS := Vector2i(400, 800)
const CHUNK_TRIS := {"small": Vector2i(60, 120), "medium": Vector2i(150, 300), "large": Vector2i(400, 800)}
const GATE_TRIS := Vector2i(1500, 2500)
const WARDEN_BASE_TRIS := Vector2i(4000, 6000)
const WARDEN_KIT_TRIS := Vector2i(800, 1500)
const ANCIENT_SLOTS := ["ancient_enamel", "ancient_light", "bare_metal", "rubber"]
const ENAMEL_CAP := 0.45
# The Warden's jaws export open by this much about Y (JawL negative); 0 is closed.
const JAW_OPEN := 0.45
const KIT_MOTION := {
	"reactor": ["Vent0", "Vent1", "Vent2"],
	"hive": ["Drone0", "Drone1", "Drone2", "Drone3", "Drone4", "Drone5", "Drone6", "Drone7"],
	"mind": ["ArmL", "ArmR", "Shutter0", "Shutter1", "Shutter2", "Shutter3", "Shutter4", "Shutter5"],
}


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


var _failures := 0
var _game
var _ticks := 0
var _gate_ids: Array = []


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_check_models()
	_check_stub()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
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
	var paint_set := [Palette.VERDIGRIS, Palette.RUST, Palette.SAND]
	for shell in ["sable", "rivet", "kest"]:
		var scene: Node = (load(MODELS + "shell_%s.glb" % shell) as PackedScene).instantiate()
		var all := meshes(scene)
		_slots_ok(shell, scene, slots)
		var pilot := scene.find_child("Pilot", true, false) as MeshInstance3D
		var pilot_tris := tri_sum(meshes(pilot)) if pilot != null else 0
		_band(shell + " shell", tri_sum(all) - pilot_tris, SHELL_TRIS)
		_band(shell + " pilot", pilot_tris, PILOT_TRIS)
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
	for rarity in ["common", "uncommon", "rare", "rare_plus"]:
		var top := gate.find_child("Topper_" + rarity, true, false) as MeshInstance3D
		_band("gate " + rarity, base + (tris(top.mesh) if top != null else 0), GATE_TRIS)
	gate.free()

	var warden: Node = (load(MODELS + "warden_clamp_base.glb") as PackedScene).instantiate()
	_slots_ok("warden base", warden, ANCIENT_SLOTS)
	_band("warden base", tri_sum(meshes(warden)), WARDEN_BASE_TRIS)
	var named := ["Housing", "Tower", "KitMount", "JawL", "JawR"].filter(func(n): return warden.find_child(n, true, false) == null)
	_report("warden nodes", named.is_empty(), "Housing, Tower > KitMount, JawL, JawR (missing %s)" % [named])
	_check_enamel("warden base", warden)
	var jaw_l := warden.find_child("JawL", true, false) as Node3D
	var jaw_r := warden.find_child("JawR", true, false) as Node3D
	_report("warden open pose", jaw_l != null and jaw_r != null and absf(jaw_l.rotation.y + JAW_OPEN) < 0.01
		and absf(jaw_r.rotation.y - JAW_OPEN) < 0.01,
		"jaws export open at -/+%.2f rad about Y; 0 is closed" % JAW_OPEN)
	warden.free()
	for fam in ["reactor", "hive", "mind"]:
		var kit: Node = (load(MODELS + "warden_kit_%s.glb" % fam) as PackedScene).instantiate()
		_slots_ok("kit " + fam, kit, ANCIENT_SLOTS)
		_band("kit " + fam, tri_sum(meshes(kit)), WARDEN_KIT_TRIS)
		var weak := kit.find_child("WeakPoint", true, false)
		var weak_slots := []
		if weak is MeshInstance3D:
			for i in weak.mesh.get_surface_count():
				weak_slots.append(HeroAssets.slot_of(weak.mesh, i))
		_report("kit " + fam + " weak point", "ancient_light" in weak_slots and "bare_metal" in weak_slots,
			"WeakPoint: a lit core framed by bare-metal shards %s" % [weak_slots])
		var missing: Array = KIT_MOTION[fam].filter(func(n): return kit.find_child(n, true, false) == null)
		_report("kit " + fam + " motion nodes", missing.is_empty(), "motion nodes present (missing %s)" % [missing])
		_check_enamel("kit " + fam, kit)
		kit.free()


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
	stub.state.velocity = Vector3(10.0, 0.0, 0.0)
	var animator = hook.shell_of(stub)["animator"]
	animator.step(1.0)
	var pod: Node3D = hook.shell_of(stub)["pod"]
	var forward := -pod.transform.basis.z
	_report("stub heading", forward.dot(Vector3.RIGHT) > 0.99, "pod faces the heading (%s)" % forward)
	stub.kit.gliding = true
	animator.step(1.0)
	var vane := pod.get_node_or_null("VaneL") as Node3D
	_report("stub vane", vane != null and absf(vane.rotation.z - PI * 0.5) < 0.05,
		"Kest's vane opens while gliding, fluttering in the airflow")
	stub.free()
	hook.free()


static func _accent_color(pod: Node) -> Color:
	for mi in meshes(pod):
		for i in mi.mesh.get_surface_count():
			if HeroAssets.slot_of(mi.mesh, i) == "class_accent":
				return (mi.get_surface_override_material(i) as StandardMaterial3D).albedo_color
	return Color.BLACK


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
