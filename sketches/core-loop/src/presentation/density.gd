extends RefCounted

const THREAT_WEIGHT := 0.35
const THREAT_SCALE := 6.0
const FX_WEIGHT := 0.35
const FX_SCALE := 40.0
const ENEMY_WEIGHT := 0.3
const ENEMY_SCALE := 12.0
const RISE_SECONDS := 0.25
const FALL_SECONDS := 0.6
const SAMPLE_HZ := 10.0

const FILL_FROM := 0.4
const FILL_FLOOR := 0.35
const FILL_GLOBAL := "threat_fill_scale"

const BANDS := [
	{"max": 0.4, "alpha": 0.9, "size": 1.0, "lifetime": 1.0, "coalesce_ms": 0, "coalesce_m": 0.0},
	{"max": 0.7, "alpha": 0.6, "size": 0.85, "lifetime": 0.7, "coalesce_ms": 120, "coalesce_m": 4.0},
	{"max": 1.01, "alpha": 0.35, "size": 0.7, "lifetime": 0.5, "coalesce_ms": 200, "coalesce_m": 6.0},
]
const HYSTERESIS := 0.02

const KILL_POPS_PER_WINDOW := 3
const KILL_POP_WINDOW := 0.25
const POP_SCALE_PER_EXTRA := 1.2
const POP_SCALE_CAP := 2.5

const SHED_ORDER := ["bolt_tails"]
const SHED_ENTER := 0.42
const SHED_LEAVE := 0.36
const SHED_STREAK_SCALE := 0.5

const CLASS_OF_ROLE := {
	"area": "P6", "fill": "P6", "swept": "P6", "run": "P6",
	"edge": "P1", "front": "P1", "chevrons": "P1", "outline": "P1",
	"trace": "P1", "band": "P1", "band_top": "P1", "owner": "P1", "solid": "P1",
}
const CLASS_OF_KIND := {
	"near_miss": "P2", "redline_blast": "P2", "interact_armed": "P2", "interact_fired": "P2",
	"part_gained": "P4", "milestone_won": "P4", "core_gained": "P4", "reward_rare": "P4",
	"reward_payoff": "P4", "beacon_unsealed": "P4", "bet_resolved": "P4", "ambush_ended": "P4", "interaction_found": "P4",
}
const GOVERNED_CLASSES := ["P5", "P6", "P7"]

static var _live: Governor


static func live() -> Governor:
	if _live == null:
		_live = Governor.new()
	return _live


static func raw(threats_in_view: int, fx_alive: int, enemies_in_view: int) -> float:
	return clampf(THREAT_WEIGHT * threats_in_view / THREAT_SCALE + FX_WEIGHT * fx_alive / FX_SCALE
		+ ENEMY_WEIGHT * enemies_in_view / ENEMY_SCALE, 0.0, 1.0)


static func is_shed_exempt(priority_class: String) -> bool:
	return not priority_class in GOVERNED_CLASSES


static func class_of_role(role: String) -> String:
	return CLASS_OF_ROLE.get(role.trim_suffix("_under"), "P1")


static func class_of_kind(kind: String) -> String:
	return CLASS_OF_KIND.get(kind, "P5")


# Godot headless Dummy renderer stores no shader globals for readback.
static var last_published := 1.0


static func publish_fill_scale(value: float) -> void:
	last_published = value
	RenderingServer.global_shader_parameter_set(FILL_GLOBAL, value)


static func reset_for_tests() -> void:
	if _live != null:
		_live.reset()
	publish_fill_scale(1.0)


static func fill_scale(density: float) -> float:
	return lerpf(1.0, FILL_FLOOR, clampf((density - FILL_FROM) / (1.0 - FILL_FROM), 0.0, 1.0))


static func pop_scale(kills: int) -> float:
	return minf(pow(POP_SCALE_PER_EXTRA, kills - 1), POP_SCALE_CAP)


static func in_view(camera: Camera3D, at: Vector3, reach := 200.0) -> bool:
	if camera == null or camera.is_position_behind(at) or camera.global_position.distance_to(at) > reach:
		return false
	var viewport := camera.get_viewport()
	return viewport != null and viewport.get_visible_rect().has_point(camera.unproject_position(at))


static func count_in_view(camera: Camera3D, nodes: Array) -> int:
	var count := 0
	for node in nodes:
		if node is Node3D and in_view(camera, (node as Node3D).global_position):
			count += 1
	return count


class Governor:
	extends RefCounted

	var value := 0.0
	var hold := false
	var _band := 0
	var _shedding := false

	func update(delta: float, target: float) -> float:
		if not hold:
			var seconds: float = RISE_SECONDS if target > value else FALL_SECONDS
			value = move_toward(value, target, delta / seconds)
		while _band < BANDS.size() - 1 and value >= float(BANDS[_band]["max"]) + HYSTERESIS:
			_band += 1
		while _band > 0 and value < float(BANDS[_band - 1]["max"]) - HYSTERESIS:
			_band -= 1
		if value >= SHED_ENTER:
			_shedding = true
		elif value < SHED_LEAVE:
			_shedding = false
		return value

	func force(density: float) -> void:
		value = density
		hold = true
		update(0.0, density)

	func reset() -> void:
		value = 0.0
		hold = false
		_band = 0
		_shedding = false

	func band() -> Dictionary:
		return BANDS[_band]

	func shed_step() -> int:
		if not _shedding:
			return 0
		return clampi(ceili(clampf((value - 0.4) / 0.6, 0.0, 1.0) * SHED_ORDER.size()), 1, SHED_ORDER.size())

	func sheds(step: String) -> bool:
		var at := SHED_ORDER.find(step)
		return at >= 0 and at < shed_step()

	func apply(priority_class: String, alpha: float, size: float, life: float) -> Vector3:
		if priority_class == "P4" or not priority_class in GOVERNED_CLASSES:
			return Vector3(alpha, size, life)
		var b := band()
		return Vector3(minf(alpha, float(b["alpha"])), size * float(b["size"]), life * float(b["lifetime"]))

	func coalesce_seconds() -> float:
		return float(band()["coalesce_ms"]) / 1000.0

	func coalesce_metres() -> float:
		return float(band()["coalesce_m"])
