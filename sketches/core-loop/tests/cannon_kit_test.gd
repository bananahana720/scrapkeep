extends SceneTree
# 2026-10-11 (PC-CANNON): preserve steps a-j and exercise Lane Charge through the slot router.
# 2026-10-12 (PC-CANNON): a loaded line sounds once at the bite, never while loading.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Augments := preload("res://src/movement/augments.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

# The remembered cannon through the real game (calm, stage 1): the class row and the
# unlock, the kit, then each slot committing one of the Mind's own families through
# MindAttacks (lane, split lane, plate, rush), hits only where the Hazard's contains()
# holds while it is live, the plate's exposure, the reset and the world's phase.
# Targets are held in place by disabling their processing after the spawn: they stay in
# the enemy group and take damage, but never walk or slide out of a band.

var _t := T.new("cannon_kit_test")
var _game
var _combat
var _player
var _source := Intent.Scripted.new()
var _steps := []
var _index := 0
var _ticks := 0
var _booted := false
var _record := {}
var _struck: Array = []
var _shots: Array = []
var _dashed := 0
var _fails: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _booted:
		_boot()
		return false
	if _index >= _steps.size():
		quit(_t.verdict())
		return true
	var step: Array = _steps[_index]
	if _ticks == 0:
		(step[0] as Callable).call()
	_ticks += 1
	if step[2] == _line_charge_check and _combat._clock - float(_record["at"]) < 0.15:
		return false
	if _ticks >= int(step[1]):
		(step[2] as Callable).call()
		_index += 1
		_ticks = 0
	return false


func _boot() -> void:
	_booted = true
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_player = _game.player
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float): _struck.append([enemy.get_instance_id(), kind, force]))
	_game.events.shot_fired.connect(func(weapon_id: String, _from: Vector3, _to: Vector3): _shots.append(weapon_id))
	_game.events.dashed.connect(func(_dir: Vector3): _dashed += 1)
	_game.events.verb_failed.connect(func(verb: String, reason: String, _at: Vector3): _fails.append([verb, reason]))
	var tps := Engine.physics_ticks_per_second
	_steps = [
		[_noop, 1, _check_row],
		[_noop, 1, _check_kit],
		[_lane_start, int(0.35 * tps), _lane_release],
		[_noop, 2, _check_lane_shape],
		[_noop, int(1.0 * tps), _check_lane_warn],
		[_noop, int(1.4 * tps), _check_lane_landed],
		[_recoil_start, 1, _recoil_press],
		[_noop, 2, _check_recoil],
		[_noop, 2, _check_recoil_cooling],
		[_plate_start, int(1.0 * tps), _plate_release],
		[_noop, 2, _check_plate_shape],
		[_noop, int(3.0 * tps), _check_plate_landed],
		[_noop, 1, _check_exposure],
		[_rush_start, 1, _rush_slam],
		[_noop, int(2.3 * tps), _check_rush],
		[_noop, 1, _check_shift_burst],
		[_reset_start, 2, _check_reset],
		[_phase_start, 2, _check_phase],
		[_line_charge_start, 8, _line_charge_check],
		[_noop, 1, _line_world_checks],
	]


func _noop() -> void:
	pass


func _as_class(id: String) -> void:
	var def: Resource = ClassDef.by_id(id)
	_game.run.class_def = def
	_player.fit_class(def)
	_clear_enemies()
	_source.hold = {}
	_source.press = {}
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at
	_player.abilities.refill()
	_combat._cooldown = 0.0
	_combat._free_cannon()
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_game.camera.pitch = 0.0
	_game.camera._process(0.0)


func _clear_enemies() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()


# A tough chaser held in place on the ground at a flat point.
func _target(flat: Vector3) -> Node3D:
	var ground: float = _game.ctx.terrain.height(flat.x, flat.z)
	var enemy: Node3D = _combat.spawn_enemy("chaser", Vector3(flat.x, ground + 1.5, flat.z))
	enemy.max_hp = 100000.0
	enemy.hp = 100000.0
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	return enemy


func _ball_flat() -> Vector3:
	var b: Vector3 = _player.ball_position()
	return Vector3(b.x, 0.0, b.z)


func _aim_flat() -> Vector3:
	var dir: Vector3 = _game.ctx.aim_forward()
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD


func _planar(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _struck_by(id: int, kind: String, from := 0) -> Array:
	return _struck.slice(from).filter(func(s): return s[0] == id and s[1] == kind)


func _hazards(family: String) -> Array:
	var out := []
	for entry in _combat._cannon:
		if entry["family"] == family:
			for h in entry["hazards"]:
				if is_instance_valid(h):
					out.append(h)
	return out


func _entry(family: String) -> Dictionary:
	for entry in _combat._cannon:
		if entry["family"] == family:
			return entry
	return {}


func _cannon_nodes() -> Array:
	var out := []
	for node in _game.get_tree().root.find_children("Hazard_cannon_*", "", true, false):
		if node.is_inside_tree():
			out.append(node)
	return out


# --- a. the row and the unlock -------------------------------------------------------------

func _check_row() -> void:
	var def: Resource = ClassDef.by_id("remembered_cannon")
	_t.check("the cannon has a class row", def != null, "no remembered_cannon row")
	if def == null:
		return
	_t.eq("display name", def.display_name, "Cannon")
	_t.eq("species", def.species, "rebuilt ancient")
	_t.eq("colour is ancient", def.color, Palette.ANCIENT)
	var ids := [def.weapon_id, def.movement_id, def.special_id, def.smash_id]
	_t.eq("cannon ability ids", ids, ["cannon_lane", "cannon_recoil", "cannon_plate", "cannon_rush"])
	_t.check("not a starter", not def.starter, "starter true")
	var says := ""
	for field in ["id", "display_name", "role", "species", "pitch", "bible_home", "motif", "sound", "shape"]:
		says += " " + str(def.get(field))
	says += " " + str(def.synergy_hooks)
	_t.check("no field says placeholder", not says.to_lower().contains("placeholder"), says)
	var families := []
	for id in ids:
		_t.check("%s has an ability row" % id, AbilityState.ABILITIES.has(id), "missing row")
		families.append(AbilityState.ABILITIES.get(id, {}).get("family", ""))
	_t.eq("families in slot order", families, ["lane", "split_lane", "plate", "rush"])
	var sorted_families := families.duplicate()
	sorted_families.sort()
	var shared: Array = MindAttacks.FAMILIES.duplicate()
	shared.sort()
	_t.eq("the four families are the Mind's", sorted_families, shared)
	_t.eq("mind_quieted pays the cannon", Achievements.reward_of("mind_quieted"), {"pilot": "remembered_cannon"})
	_t.check("the cannon is not pending", not Achievements.PENDING_PILOTS.has("remembered_cannon"), str(Achievements.PENDING_PILOTS))
	var pilots := ClassDef.all().map(func(d): return d.id)
	_t.eq("the real tables validate", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), pilots, Cosmetics.ids()), [])


# --- b. the kit --------------------------------------------------------------------------

func _check_kit() -> void:
	var kit := AugmentKit.new()
	kit.fit("cannon_recoil", "cannon_rush")
	var on := []
	for spec in Augments.SPECS:
		if kit.on(spec["key"]):
			on.append(spec["key"])
	on.sort()
	_t.eq("recoil, slam and grapple are on", on, ["grapple", "recoil", "slam"])
	_t.eq("smash flavour", kit.smash_flavour, "rush")


# --- c, d. the lane ----------------------------------------------------------------------

func _lane_start() -> void:
	# Re-cut E2-02 (PILOT-CADENCE.md §3.6): Cannon paints on press and commits a Rail on release
	# inside [0.30, 0.46] s (26 m reach, 1.0x MindAttacks.LANE_HALF width, bone shot).
	_as_class("remembered_cannon")
	var aim := _aim_flat()
	var side := aim.cross(Vector3.UP).normalized()
	var a := _target(_ball_flat() + aim * 10.0)
	var b := _target(_ball_flat() + aim * 10.0 + side * 4.0)
	_record = {"a": a, "a_id": a.get_instance_id(), "a_hp": a.hp, "b": b, "b_id": b.get_instance_id(), "b_hp": b.hp,
		"from": _struck.size(), "shots": _shots.size(), "aim": aim}
	_source.press = {"fire_pressed": true}
	_source.hold = {"fire_held": true}


func _lane_release() -> void:
	_source.hold = {}
	_source.press = {"fire_released": true}


func _check_lane_shape() -> void:
	var lanes := _hazards("lane")
	_t.eq("one lock release commits one lane", lanes.size(), 1)
	if lanes.size() != 1:
		return
	var h = lanes[0]
	var entry := _entry("lane")
	var reach: float = Weapons.CANNON_LANE_REACH * _game.ctx.tuning.mod("weapon_range")
	_t.eq("lane shape", h.shape, Hazard.Shape.LANE)
	_t.eq("lane half width is the Mind's", h.half_width, MindAttacks.LANE_HALF)
	_t.check("lane length is reach - LANE_HALF", is_equal_approx(h.length, reach - MindAttacks.LANE_HALF), "length %.3f reach %.3f" % [h.length, reach])
	_t.check("lane warn is the Mind's at phase 1", is_equal_approx(h.warn_seconds, MindAttacks.LANE_WARN), "warn %.3f" % h.warn_seconds)
	_t.check("lane heads down the aim", h.heading.dot(_record["aim"]) > 0.99, "dot %.3f" % h.heading.dot(_record["aim"]))
	_t.eq("rail lane draws in bone (Palette.SAND)", h.color, Palette.SAND)
	_t.check("lane is not a threat", not h.is_in_group(Threat.GROUP), "in Threat.GROUP")
	_t.check("lane id is the cannon's", h.attack_id.begins_with("cannon_lane"), h.attack_id)
	var d: Dictionary = MindAttacks.lane(entry["seed"], entry["target"], entry["centre"], entry["phase"], entry["radius"])[0]
	var same: bool = h.centre == d["from"] and h.heading == Vector3(d["dir"].x, 0.0, d["dir"].z).normalized() \
			and h.back == d["behind"] and h.length == d["ahead"] and h.half_width == d["half"] and h.reach == d["height"] \
			and h.warn_seconds == maxf(Hazard.MIN_WARN, d["warn"]) and h.live_seconds == d["live"] and h.type == d["type"]
	_t.check("the lane equals MindAttacks.lane rebuilt from its seed", same, "hazard %s vs descriptor %s" % [
		[h.centre, h.heading, h.back, h.length, h.half_width, h.reach, h.warn_seconds, h.live_seconds, h.type], d])


func _check_lane_warn() -> void:
	_t.eq("A untouched during the warn", _record["a"].hp, _record["a_hp"])


func _check_lane_landed() -> void:
	_t.eq("A struck once by the cannon", _struck_by(_record["a_id"], "cannon", _record["from"]).size(), 1)
	_t.check("A lost HP", _record["a"].hp < _record["a_hp"], "hp %.1f" % _record["a"].hp)
	_t.eq("B beside the lane is untouched", _record["b"].hp, _record["b_hp"])
	_t.eq("B was never struck", _struck.slice(_record["from"]).filter(func(s): return s[0] == _record["b_id"]).size(), 0)
	_t.eq("shot_fired named the lane once", _shots.slice(_record["shots"]), ["cannon_lane"])


# --- e. the recoil -----------------------------------------------------------------------

func _recoil_start() -> void:
	_as_class("remembered_cannon")


func _recoil_press() -> void:
	_dashed = 0
	_record = {"aim": _aim_flat()}
	_source.press = {"movement_pressed": true}


func _check_recoil() -> void:
	var floor_speed: float = _game.ctx.tuning.f("dash_impulse") * Augments.RECOIL_SCALE
	var along := _planar(_player.state.velocity).dot(_record["aim"])
	_t.check("recoil kicks along the aim", along >= floor_speed * 0.95, "along %.1f, floor %.1f" % [along, floor_speed])
	_t.check("recoil spends the movement slot", not _player.abilities.ready(AbilityState.MOVEMENT), "movement still ready")
	_t.eq("recoil publishes dashed once", _dashed, 1)
	var lanes := _hazards("split_lane")
	_t.eq("recoil commits two split lanes", lanes.size(), 2)
	if lanes.size() == 2:
		var aim: Vector3 = _record["aim"]
		_t.check("both lanes point behind", lanes[0].heading.dot(aim) < -0.5 and lanes[1].heading.dot(aim) < -0.5,
			"dots %.2f %.2f" % [lanes[0].heading.dot(aim), lanes[1].heading.dot(aim)])
		var angle: float = lanes[0].heading.angle_to(lanes[1].heading)
		_t.check("the split is the Mind's offset", angle >= MindAttacks.SPLIT_OFF.x - 0.001 and angle <= MindAttacks.SPLIT_OFF.y + 0.001,
			"angle %.3f" % angle)
	_record["count"] = _combat._cannon_count
	_source.press = {"movement_pressed": true}


func _check_recoil_cooling() -> void:
	_t.eq("a press while cooling commits nothing", _combat._cannon_count, _record["count"])


# --- f, g. the plate and its exposure -----------------------------------------------------

func _plate_start() -> void:
	_as_class("remembered_cannon")
	var aim := _aim_flat()
	var ahead := _target(_ball_flat() + aim * 4.0)
	var behind := _target(_ball_flat() - aim * 4.0)
	_record = {"ahead": ahead, "ahead_id": ahead.get_instance_id(), "behind": behind, "behind_hp": behind.hp,
		"from": _struck.size()}
	_source.press = {"special_pressed": true}
	_source.hold = {"special_held": true}


func _plate_release() -> void:
	_source.hold = {}


func _check_plate_shape() -> void:
	var plates := _hazards("plate")
	_t.eq("the release commits one plate", plates.size(), 1)
	if plates.size() != 1:
		return
	var h = plates[0]
	_t.eq("plate is a WAVE sector", [h.shape, h.type], [Hazard.Shape.SECTOR, Threat.Type.WAVE])
	_t.check("plate band reaches 2 * PLATE_HALF_BAND", is_equal_approx(h.r_out, 2.0 * MindAttacks.PLATE_HALF_BAND), "r_out %.3f" % h.r_out)
	_t.check("plate span is 2 * PLATE_HALF_SPAN", is_equal_approx(absf(h.a_to - h.a_from), 2.0 * MindAttacks.PLATE_HALF_SPAN),
		"span %.3f" % absf(h.a_to - h.a_from))
	_t.check("plate warn is the Mind's", is_equal_approx(h.warn_seconds, MindAttacks.PLATE_WARN), "warn %.3f" % h.warn_seconds)
	var shape: Dictionary = _combat.last_committed.get("geometry", {})
	_t.check("the gauge drew the same band as a cone", shape.get("kind", "") == "cone"
			and is_equal_approx(float(shape.get("length", 0.0)), h.r_out) and is_equal_approx(float(shape.get("half_angle", 0.0)),
				absf(h.a_to - h.a_from) * 0.5), str(shape))


func _check_plate_landed() -> void:
	_t.check("the plate strikes the target ahead", not _struck_by(_record["ahead_id"], "cannon", _record["from"]).is_empty(),
		"no cannon strike")
	_t.check("the struck target is exposed", _combat._exposed.has(_record["ahead_id"]), str(_combat._exposed))
	_t.eq("the target behind is untouched", _record["behind"].hp, _record["behind_hp"])


func _check_exposure() -> void:
	var exposed: Node3D = _record["ahead"]
	var fresh := _target(_ball_flat() + _aim_flat().cross(Vector3.UP).normalized() * 12.0)
	var force := 40.0
	# A ram's part (and so its multiplier) depends on where the ball sits, so the unexposed
	# reading is taken on the same target with its exposure set aside for one strike.
	var id := exposed.get_instance_id()
	var held: Dictionary = _combat._exposed.get(id, {})
	_combat._exposed.erase(id)
	var hp := float(exposed.hp)
	_combat.strike(exposed, "ram", force)
	var unexposed := hp - float(exposed.hp)
	_combat._exposed[id] = held
	hp = float(exposed.hp)
	_combat.strike(exposed, "ram", force)
	var braced := hp - float(exposed.hp)
	var ratio := braced / maxf(unexposed, 0.001)
	_t.check("an exposed target takes BRACE_MULT from a ram", absf(ratio - MindAttacks.BRACE_MULT) <= 0.05,
		"unexposed %.2f exposed %.2f ratio %.3f" % [unexposed, braced, ratio])
	hp = float(fresh.hp)
	_combat.strike(fresh, "cannon", force)
	var plain := hp - float(fresh.hp)
	hp = float(exposed.hp)
	_combat.strike(exposed, "cannon", force)
	var cannon_on_exposed := hp - float(exposed.hp)
	_t.check("a cannon strike on an exposed target is not multiplied", is_equal_approx(cannon_on_exposed, plain),
		"plain %.2f exposed %.2f" % [plain, cannon_on_exposed])


# --- h. the rush -------------------------------------------------------------------------

func _rush_start() -> void:
	_as_class("remembered_cannon")
	var aim := _aim_flat()
	var side := aim.cross(Vector3.UP).normalized()
	var near := _target(_ball_flat() + aim * 4.0)
	var mid := _target(_ball_flat() + side * 9.0)
	var far := _target(_ball_flat() - side * 13.0)
	_record = {"near_id": near.get_instance_id(), "mid": mid, "far": far, "far_hp": far.hp, "from": _struck.size()}


func _rush_slam() -> void:
	_t.eq("cannon smash flavour", _player.kit.smash_flavour, "rush")
	var at: Vector3 = _player.ball_position()
	_record["at"] = at
	_player._on_slammed(at, 30.0, 1.0)
	var rings := _hazards("rush")
	_t.eq("the slam commits one rush ring", rings.size(), 1)
	if rings.size() != 1:
		return
	var h = rings[0]
	_t.eq("rush is an annulus", h.shape, Hazard.Shape.ANNULUS)
	_t.check("rush centres on the landing", _planar(h.centre - at).length() < 0.01, "centre %s at %s" % [h.centre, at])
	var near := instance_from_id(_record["near_id"]) as Node3D
	var r: float = _planar(near.global_position - h.centre).length()
	_t.check("the band holds the nearest enemy", r >= h.r_in and r <= h.r_out
			and is_equal_approx(h.r_in, maxf(0.0, r - MindAttacks.RUSH_HALF_BAND)), "r %.2f band %.2f..%.2f" % [r, h.r_in, h.r_out])


func _check_rush() -> void:
	_t.check("after the warn the 4 m target is struck", not _struck_by(_record["near_id"], "cannon", _record["from"]).is_empty(),
		"no cannon strike")
	_t.eq("the 13 m target is untouched", _record["far"].hp, _record["far_hp"])


# --- Shift from the keyboard path ----------------------------------------------------------

func _check_shift_burst() -> void:
	_as_class("remembered_cannon")
	_fails.clear()
	_player.intent.clear()
	_player.intent.shift_pressed = true
	_player._read_shift()
	_t.check("cannon: Shift sets movement_pressed", _player.intent.movement_pressed, "movement_pressed false")
	_t.check("cannon: Shift plays no fail cue", _fails.is_empty(), str(_fails))
	_player.intent.clear()


# --- i. reset ----------------------------------------------------------------------------

func _reset_start() -> void:
	_as_class("remembered_cannon")
	_source.press = {"fire_pressed": true}


func _check_reset() -> void:
	_t.check("a lane stands before the reset", not _combat._cannon.is_empty() and not _cannon_nodes().is_empty(), "nothing committed")
	_combat._exposed[123] = {"until": _combat._clock + 5.0, "verb": "ram"}
	_game.events.run_started.emit("remembered_cannon")
	_t.check("no cannon hazard remains in the tree", _cannon_nodes().is_empty(), str(_cannon_nodes()))
	_t.check("_cannon and _exposed are empty", _combat._cannon.is_empty() and _combat._exposed.is_empty(),
		"%d %d" % [_combat._cannon.size(), _combat._exposed.size()])


# --- j. phase ----------------------------------------------------------------------------

func _phase_start() -> void:
	_as_class("remembered_cannon")
	var stage := 1
	while stage < 40 and _game.ctx.stages.world_of(stage) != 3:
		stage += 1
	_record = {"stage": _game.run.stage, "world_three": stage}
	_game.run.stage = stage
	_source.press = {"fire_pressed": true}


func _check_phase() -> void:
	var lanes := _hazards("lane")
	_game.run.stage = _record["stage"]
	_t.check("a world 3 stage exists", _game.ctx.stages.world_of(_record["world_three"]) == 3, "stage %d" % _record["world_three"])
	_t.check("a world 3 lane warns LANE_WARN - 0.2", lanes.size() == 1 and is_equal_approx(lanes[0].warn_seconds, MindAttacks.LANE_WARN - 0.2),
		"lanes %d warn %s" % [lanes.size(), lanes[0].warn_seconds if not lanes.is_empty() else "none"])


func _line_charge_start() -> void:
	_as_class("remembered_cannon")
	var aim := _aim_flat()
	var target := _target(_ball_flat() + aim * 10.0)
	target.global_position.y += 8.0
	var other := _target(_ball_flat() + aim * 16.0)
	var at: Vector3 = _player.ball_position() + Vector3.UP * 6.0
	_player.reset_to(at)
	_player.body().global_position = at
	_player.grapple_to(target.global_position, Vector3.UP, target)
	_record = {"a": target, "b": other, "from": _struck.size(), "combo": _player.chain.combo,
		"mult": _player.chain.multiplier(), "aim": aim, "at": _combat._clock}
	_source.press = {"slot_pick": 2, "fire_pressed": true, "fire_held": true}


func _line_charge_check() -> void:
	var entry: Dictionary = _entry("lane")
	_t.eq("slot 3 is Lane Charge", _player.abilities.id_of(AbilityState.LINE), "cannon_lane_charge")
	_t.eq("line cast snaps home", _player.abilities.selected, AbilityState.WEAPON)
	_t.eq("Lane Charge adds no chain link", _player.chain.combo, _record["combo"])
	_t.check("Lane Charge never grounds the ball", not _player.state.grounded)
	if not _t.check("Lane Charge committed", not entry.is_empty()):
		return
	var h = entry["hazards"][0]
	_t.near("cable lane warns for one tenth of a second", h.warn_seconds, 0.1)
	_t.check("cable lane is live within one tick", h.is_live() and float(entry.get("live_clock", INF)) - float(entry["born"]) <= 0.1 + 1.0 / Engine.physics_ticks_per_second, str(entry.get("live_clock")))
	_t.near("cable lane reaches twelve metres past the bite", h.length, 22.0, 0.05)
	for target in [_record["a"], _record["b"]]:
		var strikes := _struck_by(target.get_instance_id(), "cannon", _record["from"])
		_t.eq("cable target struck once", strikes.size(), 1)
		if not strikes.is_empty():
			_t.near("cable damage pays the chain", strikes[0][2], 28.0 * float(_record["mult"]))


func _line_world_checks() -> void:
	_as_class("remembered_cannon")
	var kit = _player.kit
	kit.hooked = true
	kit.on_body = false
	kit.anchor = _player.ball_position() + _aim_flat() * 5.0 + Vector3.UP * 2.0
	kit.anchor_normal = Vector3.RIGHT
	var before: Vector3 = _player.body().linear_velocity
	_combat._cannon_line_world(kit.anchor, 1.0, 1.0)
	var h = _combat._cannon.back()["hazards"][0]
	_t.near("wall Lane Charge follows the normal", h.heading.dot(Vector3.RIGHT), 1.0)
	_t.eq("wall Lane Charge never applies reel burst", _player.body().linear_velocity, before)
	kit.anchor_normal = Vector3.UP
	_combat._cannon_line_world(kit.anchor, 1.0, 1.0)
	h = _combat._cannon.back()["hazards"][0]
	_t.near("post Lane Charge follows flat aim", h.heading.dot(_aim_flat()), 1.0)
	_t.eq("post Lane Charge never applies reel burst", _player.body().linear_velocity, before)
	kit.drop_line()
	_player.abilities.refill()
	var audio = _game.presentation.audio
	audio.cannon_log.clear()
	_combat._cast_line("cannon_lane_charge", 1.0)
	_t.eq("no line loads Lane Charge", _combat.line_load()["id"], "cannon_lane_charge")
	_t.eq("loaded Lane Charge has no line cue before the bite", audio.cannon_log.filter(func(row): return row["kind"] == "cannon_line").size(), 0)
	var target := _target(_ball_flat() + _aim_flat() * 8.0)
	_player.grapple_to(target.global_position, Vector3.UP, target)
	_combat._step_line(_player.intent, 0.0)
	_t.check("a loaded bite fires Lane Charge", _combat.line_load().is_empty() and not _combat._cannon.is_empty())
	_t.eq("loaded Lane Charge has exactly one line cue after the bite", audio.cannon_log.filter(func(row): return row["kind"] == "cannon_line").size(), 1)
