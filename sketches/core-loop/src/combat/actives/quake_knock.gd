extends RefCounted

const ActiveFx := preload("res://src/combat/actives/active_fx.gd")
const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

# Quake Knock (Waking-made): a bore tooth struck against the ground, and the floor carries the
# blow outward. The press commits one ring around the ball; for the 0.5 s wind-up the ring of
# cracks draws itself (the committed telegraph fills while cracks run out from the centre), then
# the ring hits. Only machines the telegraph's contains() takes are struck, so damage lands only
# inside the warning shown. The blow is kinetic: it shatters ice slabs inside the ring through
# build.apply_element.
#
# It stacks into a strong build: weapon damage mods and punch scale the knock, each Cross Split
# level adds an aftershock ring further out (shown the moment the first ring hits), each Chain
# Arc level jumps every struck machine's hit to another machine inside the same ring, and a full
# ultimate meter's overflow widens the ring and hits harder (the rack's bonus).

const BASE_DAMAGE := 30.0
const RADIUS := 7.0
# Metres of ring per banked overflow piece, and the share of damage each piece adds.
const BONUS_RADIUS := 0.75
const BONUS_DAMAGE := 0.15
# Height above the ground the knock reaches: a machine in the air rides over it.
const REACH_UP := 2.5
const KNOCK := 12.0
# Aftershocks (Cross Split): each ring sits AFTERSHOCK_GROW further out than the last, is
# shown when the ring before it hits and lands AFTERSHOCK_WARN later at AFTERSHOCK_SCALE damage.
const AFTERSHOCK_GROW := 3.0
const AFTERSHOCK_WARN := 0.3
const AFTERSHOCK_SCALE := 0.6
const CHAIN_FALLOFF := 0.7
# How long a ring that has hit stays on the ground before it clears.
const LINGER := 0.2
const CRACKS := 7
const CRACK_EVERY := 0.06
const COLOR := Palette.AMBER
const KIND := "quake"
const SOURCE := "special"
const ELEMENT := "kinetic"
# The knock lands like a slam: the heavy stop and the launch reaction.
const IMPACT := "slam"

var ctx
var combat
# Rings still to hit: {"ring": telegraph, "left": seconds, "warn": seconds, "damage": float,
# "rack": true for the wind-up's ring, which the rack's fire() hits, false for an aftershock}.
var pending: Array = []
# Rings that hit and are lingering: [telegraph, seconds left].
var spent: Array = []
var knocks := 0
var _crack_clock := 0.0


func setup(context, owner_combat) -> void:
	ctx = context
	combat = owner_combat


func clear() -> void:
	for entry in pending:
		_free(entry["ring"])
	for entry in spent:
		_free(entry[0])
	pending.clear()
	spent.clear()


# A Jam during the wind-up drops the wind-up's ring; aftershocks already shown still land.
func cancel() -> void:
	_drop_rack_ring()


func _drop_rack_ring() -> void:
	var kept: Array = []
	for entry in pending:
		if entry["rack"]:
			_free(entry["ring"])
		else:
			kept.append(entry)
	pending = kept


func radius_for(bonus: int) -> float:
	return RADIUS + BONUS_RADIUS * bonus


func damage(bonus := 0) -> float:
	var punch := 0.0
	if ctx.build != null and ctx.build.has_method("punch_bonus"):
		punch = float(ctx.build.punch_bonus())
	return (BASE_DAMAGE + punch) * (1.0 + BONUS_DAMAGE * bonus) * ctx.tuning.mod("weapon_damage")


# The wind-up's tell: commit the ring the fire will hit with, at the ball, sized by the
# overflow banked at the press.
func begin(rack, row: Dictionary) -> void:
	_drop_rack_ring()
	var bonus := int(rack.bonus)
	var warn := float(row["windup"])
	pending.append({"ring": _commit(ctx.player.ball_position(), radius_for(bonus)), "left": warn, "warn": warn,
		"damage": damage(bonus), "rack": true})
	_crack_clock = 0.0


# The wind-up ended: the first ring hits now; any aftershocks are committed and land later.
# Returns the rings this fire will hit with. A rack row with no wind-up commits and hits at once.
func fire(rack, row: Dictionary, bonus: int) -> int:
	var heads := pending.filter(func(entry): return entry["rack"] and is_instance_valid(entry["ring"]))
	if heads.is_empty():
		# A wind-up whose ring is gone hits nothing: there is no warning to land inside.
		if float(row["windup"]) > 0.0:
			return 0
		begin(rack, row)
		heads = pending.filter(func(entry): return entry["rack"])
	var first: Dictionary = heads[0]
	pending.erase(first)
	var ring: Node3D = first["ring"]
	var rings := 1
	# The ring's size was committed at the press; overflow banked since then still hits harder.
	var dmg := maxf(float(first["damage"]), damage(bonus))
	var hit := dmg
	var radius: float = ring.radius
	for level in _pattern("cross_split"):
		radius += AFTERSHOCK_GROW
		dmg *= AFTERSHOCK_SCALE
		var warn := AFTERSHOCK_WARN * (level + 1)
		pending.append({"ring": _commit(ring.center, radius), "left": warn, "warn": warn, "damage": dmg, "rack": false})
		rings += 1
	_strike(ring, hit)
	return rings


func step(delta: float) -> void:
	var lingering: Array = []
	for entry in spent:
		entry[1] -= delta
		if entry[1] > 0.0:
			lingering.append(entry)
		else:
			_free(entry[0])
	spent = lingering
	if pending.is_empty():
		return
	_crack_clock -= delta
	var draw := _crack_clock <= 0.0
	if draw:
		_crack_clock = CRACK_EVERY
	var waiting: Array = []
	for entry in pending:
		var ring: Node3D = entry["ring"]
		if not is_instance_valid(ring):
			continue
		entry["left"] = float(entry["left"]) - delta
		var progress := 1.0 - maxf(0.0, float(entry["left"])) / maxf(float(entry["warn"]), 0.001)
		ring.set_progress(progress)
		if draw:
			_cracks(ring, progress)
		# The rack hits the wind-up's ring when the wind-up ends; aftershocks hit on their own clock.
		if float(entry["left"]) <= 0.0 and not entry["rack"]:
			_strike(ring, float(entry["damage"]))
		else:
			waiting.append(entry)
	pending = waiting


func _commit(at: Vector3, radius: float) -> Node3D:
	var ring: Node3D = Telegraph.ring(ctx.root, combat.ground, Threat.Type.INSTANT, at, radius, REACH_UP, COLOR)
	ring.set_progress(0.0)
	return ring


# One ring hits: every live machine its committed geometry contains, then the kinetic blow on
# any ice inside it.
func _strike(ring: Node3D, dmg: float) -> void:
	knocks += 1
	ring.set_progress(1.0)
	combat.effects.ring(ring.center, ring.radius, ActiveFx.peak(COLOR))
	ctx.break_props(ring.center, ring.radius, "quake_knock")
	var struck: Array = []
	for enemy in combat.get_tree().get_nodes_in_group("enemy"):
		if not enemy.is_dead() and ring.contains(enemy.global_position):
			struck.append(enemy)
	for enemy in struck:
		if is_instance_valid(enemy) and not enemy.is_dead():
			combat._hit(enemy, KIND, dmg, enemy.global_position - ring.center, KNOCK, "", SOURCE, IMPACT)
	_chain(struck, dmg)
	_shatter(ring)
	spent.append([ring, LINGER])


# Chain Arc: each level jumps every struck machine's hit to the nearest other machine inside the
# same ring, losing CHAIN_FALLOFF a jump. It never reaches past the ring.
func _chain(struck: Array, dmg: float) -> void:
	var jumps := _pattern("chain_arc")
	if jumps < 1 or struck.size() < 2:
		return
	for from in struck:
		var visited := [from]
		var at: Vector3 = from.global_position
		var hit := dmg
		for jump in jumps:
			hit *= CHAIN_FALLOFF
			var next: Node3D = null
			var best := INF
			for other in struck:
				if other in visited or not is_instance_valid(other) or other.is_dead():
					continue
				var d: float = other.global_position.distance_to(at)
				if d < best:
					best = d
					next = other
			if next == null:
				break
			visited.append(next)
			combat.effects.arc(at, next.global_position, ActiveFx.peak(COLOR))
			combat._hit(next, KIND, hit, next.global_position - at, KNOCK * 0.5, "", SOURCE, IMPACT)
			at = next.global_position


# The kinetic blow: the element applied once on each ice slab whose centre lies inside the ring,
# like a slam landing on it. A slab an earlier blow already broke is skipped.
func _shatter(ring: Node3D) -> void:
	var build = ctx.build
	if build == null or not build.has_method("apply_element") or build.get("field") == null:
		return
	var inside: Array = []
	for slab in build.field.slabs():
		var at: Vector3 = slab["at"]
		if Vector2(at.x - ring.center.x, at.z - ring.center.z).length() <= ring.radius:
			inside.append(slab)
	for slab in inside:
		if build.field.slabs().has(slab):
			build.apply_element(ELEMENT, Vector3(slab["at"].x, float(slab["top"]) + 0.3, slab["at"].z), "active")


# The tell's cracks: jagged lines running out from the centre to the ring's edge as it fills,
# and the rim cracking around as it closes.
func _cracks(ring: Node3D, progress: float) -> void:
	var center: Vector3 = ring.center + Vector3.UP * 0.15
	var reach: float = ring.radius * clampf(progress * 1.15, 0.1, 1.0)
	var seed := float(knocks) * 2.39996
	for i in CRACKS:
		var a := seed + TAU * i / CRACKS
		combat.effects.arc(center, center + Vector3(cos(a), 0.0, sin(a)) * reach, ActiveFx.peak(COLOR))
	var rim := ceili(CRACKS * 2 * progress)
	for i in rim:
		var a0 := seed + TAU * i / (CRACKS * 2)
		var a1 := seed + TAU * (i + 1) / (CRACKS * 2)
		combat.effects.arc(center + Vector3(cos(a0), 0.0, sin(a0)) * ring.radius,
			center + Vector3(cos(a1), 0.0, sin(a1)) * ring.radius, ActiveFx.peak(COLOR))


func _free(ring) -> void:
	if is_instance_valid(ring):
		ring.queue_free()


func _pattern(id: String) -> int:
	if ctx.build != null and ctx.build.has_method("pattern_level"):
		return int(ctx.build.pattern_level(id))
	return ctx.run.parts.count(id) if ctx.run != null else 0
