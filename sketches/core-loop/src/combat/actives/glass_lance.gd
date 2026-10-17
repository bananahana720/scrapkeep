extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# The Glass Lance (Mind-glass): a shard of the Mind that wants to be thrown. A fire commits a
# straight band along the aim, REACH long and HALF_WIDTH either side, skimming the ground at the
# ball's own ride height (sampled every SAMPLE metres on the press, so it climbs a slope to
# the machines on it), and draws it in pale uranium-glass green (the tell: the band's centre
# and both edges, held until the shard has passed). The shard leaves on the same press and runs the band at SPEED, piercing every
# machine whose body touches it, once each, with no cap. The band drawn is the band that hits:
# a machine outside it, or one that steps in behind the shard, is never struck.
#
# It stacks into a strong build: weapon damage mods and punch scale every lance, Cross Split
# fans one more lance per level, Chain Arc makes each pierced machine jump, and a full ultimate
# meter's overflow arrives as extra lances (the rack's bonus).

const BASE_DAMAGE := 34.0
const REACH := 40.0
const HALF_WIDTH := 0.9
# Metres above or below the band's height a machine's body may reach past and still be pierced.
const HEIGHT := 1.5
# Metres between the band's height samples, and the most it may climb above or dive below the
# ball over a ledge or a drop.
const SAMPLE := 2.5
const CLIMB := 12.0
const DIVE := 6.0
# The ride height the band keeps over the ground: the ball's own at the press, held in this
# range so a press in the air dips to the ground and one under a deck never sinks into it.
const RIDE_MIN := 0.4
const RIDE_MAX := 1.6
const SPEED := 120.0
# Degrees between fanned lances.
const FAN_DEG := 7.0
# Seconds the tell stays up after the shard reaches the far end.
const TELL_HOLD := 0.12
const DRAW_LIFT := 0.3
const KNOCK := 8.0
const CHAIN_RANGE := 8.0
const CHAIN_FALLOFF := 0.7
const COLOR := Color(0.78, 1.0, 0.62)
const SHARD_COLOR := Color(0.94, 1.0, 0.9)
const KIND := "lance"
# The proc row's quick cut: a hit stop and a stagger, no launch.
const IMPACT := "proc"
const SOURCE := "special"

var ctx
var combat
var lances: Array = []
var pierced := 0


func setup(context, owner_combat) -> void:
	ctx = context
	combat = owner_combat


func clear() -> void:
	lances.clear()


func count_for(bonus: int) -> int:
	return 1 + bonus + _pattern("cross_split")


func damage() -> float:
	var punch := 0.0
	if ctx.build != null and ctx.build.has_method("punch_bonus"):
		punch = float(ctx.build.punch_bonus())
	return (BASE_DAMAGE + punch) * ctx.tuning.mod("weapon_damage")


func fire(_rack, _row: Dictionary, bonus: int) -> int:
	var count := count_for(bonus)
	var forward: Vector3 = ctx.aim_forward()
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var from: Vector3 = ctx.player.ball_position()
	var dmg := damage()
	for i in count:
		var dir := forward.rotated(Vector3.UP, deg_to_rad(FAN_DEG * (float(i) - float(count - 1) * 0.5)))
		var lance := {"from": from, "dir": dir, "s": 0.0, "hit": {}, "damage": dmg, "heights": _skim(from, dir)}
		_tell(lance)
		lances.append(lance)
	return count


# The band's height at each sample: the ground plus the ball's ride height, held within CLIMB
# and DIVE of the ball. Flat at the ball's height with no terrain.
func _skim(from: Vector3, dir: Vector3) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	var terrain = ctx.terrain
	var flat: bool = terrain == null or not terrain.has_method("height")
	var ride: float = 0.0 if flat else clampf(from.y - float(terrain.height(from.x, from.z)), RIDE_MIN, RIDE_MAX)
	for k in int(ceil(REACH / SAMPLE)) + 1:
		var at := from + dir * minf(REACH, k * SAMPLE)
		var y: float = from.y if flat or k == 0 else float(terrain.height(at.x, at.z)) + ride
		heights.append(clampf(y, from.y - DIVE, from.y + CLIMB))
	return heights


# The band's height `along` metres out, between its samples.
static func band_y(lance: Dictionary, along: float) -> float:
	var heights: PackedFloat32Array = lance["heights"]
	var at := clampf(along / SAMPLE, 0.0, float(heights.size() - 1))
	var k := mini(int(at), heights.size() - 2)
	return lerpf(heights[k], heights[k + 1], at - k)


func _point(lance: Dictionary, along: float) -> Vector3:
	var at: Vector3 = lance["from"] + lance["dir"] * along
	return Vector3(at.x, band_y(lance, along) + DRAW_LIFT, at.z)


# The committed band, centre bright and edges faint, up for the whole flight.
func _tell(lance: Dictionary) -> void:
	var life := REACH / SPEED + TELL_HOLD
	var side: Vector3 = lance["dir"].cross(Vector3.UP).normalized() * HALF_WIDTH
	var heights: PackedFloat32Array = lance["heights"]
	for k in heights.size() - 1:
		var a := _point(lance, k * SAMPLE)
		var b := _point(lance, minf(REACH, (k + 1) * SAMPLE))
		combat.effects.beam(a, b, COLOR, life)
		for edge in [side, -side]:
			combat.effects.beam(a + edge, b + edge, Color(COLOR, 0.45), life)


func step(delta: float) -> void:
	if lances.is_empty():
		return
	var flying: Array = []
	for lance in lances:
		if not _fly(lance, delta):
			flying.append(lance)
	lances = flying


# One lance's tick: the shard runs its band from s to s + SPEED * delta and pierces what it
# crosses. True when it has reached the far end.
func _fly(lance: Dictionary, delta: float) -> bool:
	var before: float = lance["s"]
	var after := minf(REACH, before + SPEED * delta)
	lance["s"] = after
	var from: Vector3 = lance["from"]
	var dir: Vector3 = lance["dir"]
	combat.effects.beam(_point(lance, before), _point(lance, after), SHARD_COLOR, 0.08)
	for enemy in combat.get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead() or lance["hit"].has(enemy.get_instance_id()):
			continue
		var girth := _girth(enemy)
		var rel: Vector3 = enemy.global_position - from
		var along := rel.dot(dir)
		if along < 0.0 or along > REACH or along > after or along < before - girth - 0.5:
			continue
		var lateral := Vector3(rel.x, 0.0, rel.z) - dir * along
		if lateral.length() > HALF_WIDTH + girth or absf(enemy.global_position.y - band_y(lance, along)) > HEIGHT + girth:
			continue
		lance["hit"][enemy.get_instance_id()] = true
		_pierce(enemy, lance)
	return after >= REACH


func _pierce(enemy: Node3D, lance: Dictionary) -> void:
	pierced += 1
	var dmg: float = lance["damage"]
	combat.effects.spark(enemy.global_position + Vector3.UP, SHARD_COLOR)
	combat._hit(enemy, KIND, dmg, lance["dir"], KNOCK, "", SOURCE, IMPACT)
	var jumps := _pattern("chain_arc")
	if jumps > 0:
		combat._chain(enemy, enemy.global_position, {"damage": dmg, "chain_jumps": jumps, "chain_range": CHAIN_RANGE,
			"chain_falloff": CHAIN_FALLOFF, "color": COLOR, "kind": KIND, "knock": KNOCK, "source": SOURCE})


func _girth(enemy: Node3D) -> float:
	return float(enemy.get("radius")) if enemy.get("radius") != null else 0.6


func _pattern(id: String) -> int:
	if ctx.build != null and ctx.build.has_method("pattern_level"):
		return int(ctx.build.pattern_level(id))
	return ctx.run.parts.count(id) if ctx.run != null else 0
