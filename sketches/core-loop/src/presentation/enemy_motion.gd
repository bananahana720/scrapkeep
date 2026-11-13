extends Node3D

const AppShell := preload("res://src/core/app_shell.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const Roster := preload("res://src/combat/roster.gd")

# An enemy's life between attacks and its break-up on death, read from its WindupRows row
# (idle, death, and the swarm remnant's wind-up pose). The idle moves the model's pivot
# only, never a collider, and stops for the wind-up so it is never read as a telegraph.
# This script is also the detached node a death scatter lives in: it outlasts the enemy,
# whose died signal and queue_free keep their tick, and frees itself.

const IDLE_STYLES := ["bob", "sway", "breathe", "hover", "tick"]
const DEATH_STYLES := ["scatter", "collapse", "spin_down", "pop"]
const AMPLITUDE_MIN := 0.02
const AMPLITUDE_MAX := 0.08
const PARTS_MIN := 3
const PARTS_MAX := 8
const SECONDS_MIN := 0.4
const SECONDS_MAX := 0.7
# The clock a kind with no attack (the vault) idles against.
const REST_CLOCK := 1.0
const LOW_PART_CAP := 4
const GRAVITY := 18.0
# The last share of a piece's life it spends shrinking to nothing. A piece leaves by size and
# never by fading: a fade through the instance's transparency moves an opaque surface to the
# blended pass, and the first piece of each look to go there made the renderer build that
# pass's pipelines while the frame waited (43 to 48 ms on the 4080 the frame after the dam's
# first kill, 10 November 2026). A shrinking piece of the model keeps the pipelines the living
# machine drew with; a box piece keeps the ones its look was first drawn with (BakeWarm.death_warm
# draws the dam pack kinds' box looks at stage entry).
const SHRINK := 0.5
# The smallest a piece is drawn, so its last frame still has a basis that can be inverted.
const SPECK := 0.01
const TICK_STEPS := [0.0, 0.5, 1.0, 0.5]

# Reduced motion sets 0: no idle at all. The death scatter still runs and frees on time.
static var motion_scale := 1.0
# A headless run (tests, seeded bots) shows nothing, so the idle stays off there unless a
# test opts in; the rest poses the older headless tests pin stay exact.
static var headless_idle := false

var seconds := 0.5
var style := "scatter"
var t := 0.0
var _pieces: Array = []
# A grounded body's pieces land (W1-86): each bounces on the ground under it (the terrain,
# read through `ground`), rests there, then shrinks away. No ground is the old flight, for a
# body that died in the air or rang out, under reduced motion and in a headless run.
var ground := Callable()
var rest := 0.0
# How a landing piece meets the floor: the kicked props' numbers (prop_kicks.gd), so a death
# and a kicked prop land alike.
const BOUNCE := 0.3
const SKID := 0.55
const SETTLE_SPEED := 0.8
const LAND_REST := 0.9


static func active() -> bool:
	return headless_idle or not AppShell.headless()


static func valid_idle(idle: Dictionary) -> bool:
	return String(idle.get("style", "")) in IDLE_STYLES and _number(idle, "amplitude") \
		and float(idle.amplitude) >= AMPLITUDE_MIN and float(idle.amplitude) <= AMPLITUDE_MAX \
		and _number(idle, "beats") and float(idle.beats) > 0.0


static func valid_death(death: Dictionary) -> bool:
	return String(death.get("style", "")) in DEATH_STYLES and death.get("parts") is int \
		and int(death.parts) >= PARTS_MIN and int(death.parts) <= PARTS_MAX \
		and _number(death, "seconds") and float(death.seconds) >= SECONDS_MIN and float(death.seconds) <= SECONDS_MAX


static func _number(row: Dictionary, field: String) -> bool:
	return row.get(field) is float or row.get(field) is int


# The kind's own attack clock: its first attack's lead, read from the enemy's real timing.
static func attack_clock(kind: String, enemy: Object) -> float:
	var spec: Dictionary = WindupRows.ROWS.get(kind, {})
	if spec.is_empty() or spec.attacks.is_empty():
		return REST_CLOCK
	var lead := float(WindupRows.row(kind, enemy, String(spec.attacks.keys()[0])).get("lead_seconds", 0.0))
	return lead if lead > 0.0 else REST_CLOCK


# The model's local offset at `clock` seconds of sim time; never longer than the amplitude.
static func idle_offset(idle: Dictionary, clock: float, period: float) -> Vector3:
	var amp := float(idle.get("amplitude", 0.0)) * motion_scale
	if amp <= 0.0 or period <= 0.0:
		return Vector3.ZERO
	var turn := fposmod(clock / period, 1.0)
	var wave := sin(TAU * turn)
	match String(idle.get("style", "")):
		"bob":
			return Vector3(0.0, amp * wave, 0.0)
		"sway":
			return Vector3(amp * wave, 0.0, 0.0)
		"breathe":
			return Vector3(0.0, amp * wave * wave, 0.0)
		"hover":
			return Vector3(amp * 0.6 * cos(TAU * turn), amp * 0.8 * wave, 0.0)
		"tick":
			return Vector3(0.0, amp * float(TICK_STEPS[int(turn * TICK_STEPS.size()) % TICK_STEPS.size()]), 0.0)
	return Vector3.ZERO


# The wind-up body pose a row names (the swarm remnant's dip); identity for every other row.
static func pose_basis(spec: Dictionary) -> Basis:
	var pose: Dictionary = spec.get("pose", {})
	if pose.is_empty():
		return Basis.IDENTITY
	return Basis(Vector3.RIGHT, -deg_to_rad(float(pose.get("degrees", 0.0))))


# A part thrown a second time is this much of its size, so the repeats read as smaller pieces of
# the same machine.
const REPEAT_SCALE := 0.6


static func part_count(death: Dictionary) -> int:
	var parts := int(death.get("parts", PARTS_MIN))
	return mini(parts, LOW_PART_CAP) if GraphicsPreset.current == "low" else parts


# Breaks the dying enemy's look into its row's pieces, thrown along `direction`. Pieces reuse
# the model's meshes and materials, each part again smaller and turned once the parts run out;
# with fewer than two meshes they are boxes in its material. The spread is a hash of the death point, so seeded runs replay it.
# `land` is the ground height at (x, z) for a body that died standing (W1-86); empty for the old flight.
static func scatter(enemy: Node3D, kind: String, direction: Vector3, land := Callable()) -> Node3D:
	var death: Dictionary = WindupRows.ROWS.get(kind, {}).get("death", {})
	var parent := enemy.get_parent()
	if death.is_empty() or parent == null:
		return null
	var sources := _parts_of(enemy)
	var node: Node3D = (load("res://src/presentation/enemy_motion.gd") as GDScript).new()
	node.name = "DeathScatter"
	node.style = String(death.style)
	node.seconds = float(death.seconds)
	parent.add_child(node)
	var at := enemy.global_position
	node.global_transform = Transform3D(Basis.IDENTITY, at)
	if land.is_valid() and motion_scale > 0.0 and active() and Roster.CHASSIS.get(kind, {}).get("move_class", "") != "airborne":
		node.ground = land
		node.rest = LAND_REST
	var material: Material = null
	if not sources.is_empty():
		material = sources[0]["material"]
	var throw := Vector3(direction.x, 0.0, direction.z)
	throw = throw.normalized() if throw.length_squared() > 0.0001 else Vector3.ZERO
	var count := part_count(death)
	var seed_hash := absi(hash(Vector3i(at.round())))
	for i in count:
		var piece := MeshInstance3D.new()
		var angle := TAU * (float(i) + float((seed_hash >> (i % 16)) % 7) / 14.0) / float(count)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		node.add_child(piece)
		if sources.size() >= 2:
			# The body's own parts. Past one each, a part is thrown again smaller and turned,
			# so a death never fills with plain boxes (technicals counted half of each death's
			# pieces as boxes, 10 Nov 2026).
			var src: Dictionary = sources[i % sources.size()]
			piece.mesh = src["mesh"]
			piece.material_override = src["override"]
			var overrides: Array = src["surfaces"]
			for surface in overrides.size():
				piece.set_surface_override_material(surface, overrides[surface])
			piece.global_transform = src["xform"]
			var again := i / sources.size()
			if again > 0:
				var turn := Basis(out.cross(Vector3.UP).normalized(), PI * 0.5 * float(again) + float(seed_hash % 5) * 0.3)
				var xform: Transform3D = src["xform"]
				piece.basis = turn * xform.basis * REPEAT_SCALE
				piece.global_position = xform.origin + out * 0.3 * float(again)
		else:
			var box := BoxMesh.new()
			box.size = Vector3.ONE * (0.45 - 0.03 * float(i % 4))
			piece.mesh = box
			piece.material_override = BakeLook.unbaked(material)
			piece.position = out * 0.4 + Vector3.UP * 0.6
		node._pieces.append({"node": piece, "velocity": _throw(node.style, out, throw), "spin": out.cross(Vector3.UP) * 6.0, "turn": piece.basis})
	return node


# The visible parts of a body as death pieces: {mesh, override, surfaces, material, xform}. A
# multimesh without instance colours (the reactor relic's vent stacks) gives one part per instance.
static func _parts_of(enemy: Node3D) -> Array:
	var parts := []
	for found in enemy.find_children("*", "GeometryInstance3D", true, false):
		if not (found as Node3D).is_visible_in_tree():
			continue
		if found is MeshInstance3D and (found as MeshInstance3D).mesh != null:
			var mi := found as MeshInstance3D
			var surfaces := []
			for i in mi.get_surface_override_material_count():
				surfaces.append(mi.get_surface_override_material(i))
			parts.append({"mesh": mi.mesh, "override": mi.material_override, "surfaces": surfaces,
				"material": mi.material_override if mi.material_override != null else mi.get_active_material(0), "xform": mi.global_transform})
		elif found is MultiMeshInstance3D:
			var mmi := found as MultiMeshInstance3D
			var mm := mmi.multimesh
			# Instance colours do not carry to a single mesh, so a tinted multimesh (the boom
			# tender's lamps) stays out.
			if mm == null or mm.mesh == null or mm.transform_format != MultiMesh.TRANSFORM_3D or mm.use_colors:
				continue
			for i in mini(mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count, mm.instance_count):
				parts.append({"mesh": mm.mesh, "override": mmi.material_override, "surfaces": [],
					"material": mmi.material_override if mmi.material_override != null or mm.mesh.get_surface_count() == 0 else mm.mesh.surface_get_material(0),
					"xform": mmi.global_transform * mm.get_instance_transform(i)})
	return parts


static func _throw(death_style: String, out: Vector3, throw: Vector3) -> Vector3:
	match death_style:
		"collapse":
			return out * 1.2 + throw + Vector3.UP * 0.5
		"spin_down":
			return out * 1.5 + throw * 2.0 + Vector3.UP * 2.0
		"pop":
			return out * 6.0 + throw * 2.0 + Vector3.UP * 3.0
	return out * 3.0 + throw * 4.0 + Vector3.UP * 4.0


# The local height a piece's origin rests at: the ground under it, raised by how far the piece's
# lowest point sits under its origin as it is turned now, so it rests on the ground, not in it.
func floor_at(piece: MeshInstance3D) -> float:
	if not ground.is_valid():
		return -INF
	var at := global_transform * piece.position
	var low := 0.0
	if piece.mesh != null:
		low = maxf(0.0, -(Transform3D(piece.basis, Vector3.ZERO) * piece.mesh.get_aabb()).position.y)
	return float(ground.call(at.x, at.z)) - global_position.y + low


# The scatter's whole life: the row's seconds, plus the rest on the ground when it lands.
func life() -> float:
	return seconds + rest


func _physics_process(delta: float) -> void:
	t += delta
	var size := clampf((1.0 - t / life()) / SHRINK, SPECK, 1.0) if rest == 0.0 \
		else clampf((life() - t) / (seconds * SHRINK), SPECK, 1.0)
	for piece in _pieces:
		var mi: MeshInstance3D = piece.node
		var spin: Vector3 = piece.spin * (3.0 if style == "spin_down" else 1.0)
		# The turn is kept at full size and the drawn basis is that turn at this tick's size.
		var turn: Basis = piece.turn
		if spin.length_squared() > 0.0:
			turn = turn.rotated(spin.normalized(), spin.length() * delta)
			piece.turn = turn
		mi.basis = turn * size
		var v: Vector3 = piece.velocity
		v.y -= GRAVITY * delta
		mi.position += v * delta
		var floor_y := floor_at(mi)
		# Only a falling piece meets the ground; one still rising from under it keeps rising.
		if mi.position.y < floor_y and v.y <= 0.0:
			mi.position.y = floor_y
			v.y = -v.y * BOUNCE if v.y < -SETTLE_SPEED else 0.0
			v.x *= SKID
			v.z *= SKID
			piece.spin = piece.spin * SKID
		piece.velocity = v
	if t >= life():
		queue_free()
