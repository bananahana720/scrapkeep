extends Node3D

const WindupRows := preload("res://src/presentation/windup_rows.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")

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


static func active() -> bool:
	return headless_idle or DisplayServer.get_name() != "headless"


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


static func part_count(death: Dictionary) -> int:
	var parts := int(death.get("parts", PARTS_MIN))
	return mini(parts, LOW_PART_CAP) if GraphicsPreset.current == "low" else parts


# Breaks the dying enemy's look into its row's pieces, thrown along `direction`. Pieces reuse
# the model's meshes and materials; with fewer than two meshes they are boxes in its
# material. The spread is a hash of the death point, so seeded runs replay it.
static func scatter(enemy: Node3D, kind: String, direction: Vector3) -> Node3D:
	var death: Dictionary = WindupRows.ROWS.get(kind, {}).get("death", {})
	var parent := enemy.get_parent()
	if death.is_empty() or parent == null:
		return null
	var sources: Array[MeshInstance3D] = []
	for found in enemy.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.mesh != null and mi.is_visible_in_tree():
			sources.append(mi)
	var node: Node3D = (load("res://src/presentation/enemy_motion.gd") as GDScript).new()
	node.name = "DeathScatter"
	node.style = String(death.style)
	node.seconds = float(death.seconds)
	parent.add_child(node)
	var at := enemy.global_position
	node.global_transform = Transform3D(Basis.IDENTITY, at)
	var material: Material = null
	if not sources.is_empty():
		material = sources[0].material_override if sources[0].material_override != null else sources[0].get_active_material(0)
	var throw := Vector3(direction.x, 0.0, direction.z)
	throw = throw.normalized() if throw.length_squared() > 0.0001 else Vector3.ZERO
	var count := part_count(death)
	var seed_hash := absi(hash(Vector3i(at.round())))
	for i in count:
		var piece := MeshInstance3D.new()
		var angle := TAU * (float(i) + float((seed_hash >> (i % 16)) % 7) / 14.0) / float(count)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		node.add_child(piece)
		if sources.size() >= 2 and i < sources.size():
			var src := sources[i]
			piece.mesh = src.mesh
			piece.material_override = src.material_override
			for s in src.get_surface_override_material_count():
				piece.set_surface_override_material(s, src.get_surface_override_material(s))
			piece.global_transform = src.global_transform
		else:
			var box := BoxMesh.new()
			box.size = Vector3.ONE * (0.45 - 0.03 * float(i % 4))
			piece.mesh = box
			piece.material_override = BakeLook.unbaked(material)
			piece.position = out * 0.4 + Vector3.UP * 0.6
		node._pieces.append({"node": piece, "velocity": _throw(node.style, out, throw), "spin": out.cross(Vector3.UP) * 6.0})
	return node


static func _throw(death_style: String, out: Vector3, throw: Vector3) -> Vector3:
	match death_style:
		"collapse":
			return out * 1.2 + throw + Vector3.UP * 0.5
		"spin_down":
			return out * 1.5 + throw * 2.0 + Vector3.UP * 2.0
		"pop":
			return out * 6.0 + throw * 2.0 + Vector3.UP * 3.0
	return out * 3.0 + throw * 4.0 + Vector3.UP * 4.0


func _physics_process(delta: float) -> void:
	t += delta
	var fade := clampf(t / seconds, 0.0, 1.0)
	for piece in _pieces:
		var mi: MeshInstance3D = piece.node
		var v: Vector3 = piece.velocity
		v.y -= GRAVITY * delta
		piece.velocity = v
		mi.position += v * delta
		var spin: Vector3 = piece.spin * (3.0 if style == "spin_down" else 1.0)
		if spin.length_squared() > 0.0:
			mi.rotate(spin.normalized(), spin.length() * delta)
		mi.transparency = fade
	if t >= seconds:
		queue_free()
