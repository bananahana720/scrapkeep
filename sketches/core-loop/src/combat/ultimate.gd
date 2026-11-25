extends Node

const UltimateMeter := preload("res://src/core/ultimate_meter.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Augments := preload("res://src/movement/augments.gd")
const RideRail := preload("res://src/world/ride_rail.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Palette := preload("res://src/core/palette.gd")
const Stakes := preload("res://src/combat/stakes.gd")

# The set piece on Q (design-v3/SKILL-BAR.md section 4). The meter's one writer: it listens
# to the bus for the sources of section 4 and pays them into `meter`, which the ability
# record carries for the HUD and bots (AbilityState.meter, AbilityState.ultimate()).
#
# A Q at a full meter plans the path once (plan), commits it (start) and rides it on the
# physics tick: wind-up WINDUP s, the flight on a RideRail carrier, a landing strike, then
# RECOVER s. Q in the wind-up recalls with a full refund; Space in flight bails (spent, no
# landing); a stage change, a death or a run end aborts (spent; a retry restores the meter
# with the rest of the stage-entry state). The router (player_ball.gd) swallows every key
# but the roll, Space and Q while phase() is not idle.
#
# Each ultimate is a row in _ult_rows: {tech: Callable(beat, ball, aim, heft_mult) -> int
# (hits), peak: Callable(at), landing: Callable(at, heft_mult, chain_mult) -> Array [hits,
# damage]}, plus the optional target: Callable(ball, aim) -> Dictionary of section 12, item 2.
# combat.gd registers the shared ult_default row; wave P-C fills one marked block per pilot.

const IDLE := "idle"
const WINDUP := "windup"
const FLIGHT := "flight"
const RECOVER := "recover"

const WINDUP_SECONDS := 0.35
# A planting wind-up (a row's `plant`) brakes the ball's planar speed to a stop within this long.
const PLANT_STOP_SECONDS := 0.15

var _plant_from := 0.0
const RECOVER_SECONDS := 0.25
const FLIGHT_SPEED := 18.0
const FLIGHT_MIN := 1.6
const FLIGHT_MAX := 3.2
const FLIGHT_NO_MUSIC := 2.4
# With the music off the flight still keeps a beat for its volleys: this many to 2.4 s.
const NO_MUSIC_BEATS := 7
const RAIL_SEARCH := 12.0
const HOP_HEIGHT := 8.0
const HOP_SECONDS := 1.6
const CORRIDOR := 3.0
const STEER_SPEED := 6.0
const VOLLEY_TARGETS := 3
const VOLLEY_RADIUS := 10.0
const VOLLEY_DAMAGE := 12.0
const VOLLEY_BIAS_DEG := 25.0
const LANDING_DAMAGE := 60.0
const LANDING_KNOCK := 26.0
const ENCORE_REACH := 30.0
# Heft class I to V.
const HEFT_MULT := [1.0, 1.15, 1.30, 1.45, 1.60]
const ARC_REACH := [40.0, 47.0, 55.0, 62.0, 70.0]
const LANDING_RADIUS := [6.0, 7.0, 8.0, 9.0, 10.0]
const DAMAGE_TAKEN := 0.2
# On a closed Warden guard one set piece adds at most this much posture, volleys and landing
# together (section 12, item 7); 70 since Andrew's tap "Lift the ceiling" (17 Oct 22:04Z),
# was 45. Volleys on a Warden deal half damage; a boss takes half.
const WARDEN_POSTURE_CAP := 70.0
# The lift is for monster builds (DECISIONS section 5: "Monster builds stagger Wardens faster ...
# Ordinary pilots still take 45-70 s"): for any other pilot the cap is the old 45 (warden_cap).
const WARDEN_POSTURE_CAP_ORDINARY := 45.0
const WARDEN_VOLLEY := 0.5
const BOSS_MULT := 0.5
const CONTACT_GAP := 0.5
# The ball strays this far from the drawn point when something on the path stopped it: the
# flight ends there as a landing.
const BLOCKED := 2.5
const GRAVITY := 26.0

var ctx
var combat
var meter := UltimateMeter.new()
# Seconds per beat of the music playing, 0 with none; audio wires it.
var beat_seconds := Callable()
# A world rail entry near a point: Callable(point) -> {entry, to} or {}; the world wires it
# when it has rails. Unwired, no rail path is offered.
var rail_query := Callable()
# ultimate_id -> row (see the header). P-C fills its own marked block.
var _ult_rows := {
	# --- P-C Sable ultimate ---
	"cable_run": {"tech": _sable_tech, "peak": _sable_peak, "landing": _sable_landing, "release": _sable_release},
	"ball_lightning": {"tech": _lightning_tech, "peak": _lightning_peak, "landing": _lightning_landing, "release": _sable_release},
	"outpost": {"tech": _sable_tech, "peak": _sable_peak, "landing": _outpost_landing, "release": _sable_release},
	# --- end Sable ---
	# --- P-C Rivet ultimate ---
	# Rows are installed from RivetKit.SHAPE_DISPATCH in setup.
	# --- end Rivet ---
	# --- P-C Kest ultimate ---
	# --- end Kest ---
	# --- P-C Tarn ultimate ---
	"redjaw_rend": {"tech": func(beat, ball, aim, mult): return combat.get_node("TarnClaw").tech("redjaw_rend", beat, ball, aim, mult),
		"peak": func(at): combat.get_node("TarnClaw").peak("redjaw_rend", at),
		"landing": func(at, heft, chain): return combat.get_node("TarnClaw").landing("redjaw_rend", at, heft, chain)},
	"rake_run": {"tech": func(beat, ball, aim, mult): return combat.get_node("TarnClaw").tech("rake_run", beat, ball, aim, mult),
		"peak": func(at): combat.get_node("TarnClaw").peak("rake_run", at),
		"landing": func(at, heft, chain): return combat.get_node("TarnClaw").landing("rake_run", at, heft, chain)},
	"vice_leap": {"tech": func(beat, ball, aim, mult): return combat.get_node("TarnClaw").tech("vice_leap", beat, ball, aim, mult),
		"peak": func(at): combat.get_node("TarnClaw").peak("vice_leap", at),
		"landing": func(at, heft, chain): return combat.get_node("TarnClaw").landing("vice_leap", at, heft, chain)},
	# --- end Tarn ---
	# --- P-C Tally ultimate ---
	# pilots/tally.md section 3; combat.gd's Tally block holds the rows' code and the
	# tally_books_balanced detection (the landing counts its settles there).
	"plate_return": {"target": func(ball, aim): return combat.tally_target("plate_return", ball, aim),
		"tech": func(beat, ball, aim, mult): return combat.tally_tech("plate_return", beat, ball, aim, mult),
		"peak": func(at): combat.tally_peak("plate_return", at),
		"landing": func(at, heft, chain): return combat.tally_landing("plate_return", at, heft, chain)},
	"plate_audit": {"target": func(ball, aim): return combat.tally_target("plate_audit", ball, aim),
		"tech": func(beat, ball, aim, mult): return combat.tally_tech("plate_audit", beat, ball, aim, mult),
		"peak": func(at): combat.tally_peak("plate_audit", at),
		"landing": func(at, heft, chain): return combat.tally_landing("plate_audit", at, heft, chain)},
	"plate_flywheel": {"target": func(ball, aim): return combat.tally_target("plate_flywheel", ball, aim),
		"tech": func(beat, ball, aim, mult): return combat.tally_tech("plate_flywheel", beat, ball, aim, mult),
		"peak": func(at): combat.tally_peak("plate_flywheel", at),
		"landing": func(at, heft, chain): return combat.tally_landing("plate_flywheel", at, heft, chain)},
	# --- end Tally ---
	# --- P-C Cannon ultimate ---
	"cannon_fire_mission": {"tech": _cannon_tech, "peak": _cannon_peak, "landing": _cannon_landing},
	"cannon_creeping_barrage": {"tech": _cannon_tech, "peak": _cannon_peak, "landing": _cannon_landing},
	"cannon_plate_mortar": {"target": _cannon_mortar_target, "tech": _cannon_tech, "peak": _cannon_peak, "landing": _cannon_landing},
	# --- end Cannon ---
}
# The last plan started, as drawn. Read only outside.
var last_plan := {}

var _phase := IDLE
var _left := 0.0
var _plan := {}
var _id := ""
var _leg := 0
var _ride
var _leg_time := 0.0
var _beat_len := 0.0
var _beat_clock := 0.0
var _beat := 0
var _beats := 0
var _peaked := false
var _offset := 0.0
var _expected := Vector3.ZERO
var _posture_spent := {}
var _record := {}
var _clock := 0.0
var _contact_at := {}
var _staggered := {}
var _chunks := {}
var _was_full := false
var _fill_since := 0.0
# Seconds from the last empty meter to the last full one, for the run log's fill_seconds.
var _record_fill := 0.0


func setup(ctx_ref, combat_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref
	# --- P-C Rivet ultimate ---
	var rivet = load("res://src/combat/rivet_kit.gd")
	for id in rivet.SHAPE_DISPATCH:
		_ult_rows[id] = rivet.ultimate_row(combat, id)
	# --- end Rivet ---
	stakes = Stakes.new()
	ctx.root.add_child(stakes)
	stakes.setup(ctx, combat, self)
	ctx.events.run_started.connect(func(_class_id: String): _sable_runs = 0)
	ctx.events.dismounted.connect(_outpost_depart)
	name = "Ultimate"
	ctx.player.abilities.meter = meter
	ctx.player.set_piece_phase = Callable(self, "phase")
	# The defence runs inside RunState.damage, the one choke point every hit passes (a boss's
	# slag, charge and the Mind's attacks call it directly).
	ctx.run.defend_hook = Callable(self, "defend")
	ctx.run.ride_hook = Callable(self, "active")
	var ev = ctx.events
	ev.ultimate_started.connect(_cannon_started)
	ev.enemy_struck.connect(_on_struck)
	ev.harpoon_smashed.connect(func(_enemy: Node3D, _at: Vector3, _speed: float): _feed("smash", ctx.player.chain.multiplier()))
	ev.line_state_changed.connect(func(state: String, target: Node3D, _at: Vector3, _cause: String):
		if state == "chain_link":
			_feed_link(target))
	ev.near_miss.connect(func(_kind: String, _at: Vector3): _feed("near_miss"))
	ev.enemy_killed.connect(func(_kind: String, _at: Vector3, _scrap: int): _feed("kill"))
	ev.posture_changed.connect(_on_posture)
	ev.boss_reeled.connect(func(_at: Vector3, _scrap: int): _feed("reel"))
	ev.run_started.connect(func(_class_id: String):
		_abort("stage")
		meter.reset()
		_was_full = false
		_fill_since = _clock
		_contact_at = {}
		_staggered = {}
		_chunks = {}
		_record = {}
		ctx.run.set_meta("ultimate_record", {}))
	ev.stage_entered.connect(_on_stage_entered)
	ev.boss_arena_entered.connect(_pour_brew)
	ev.stage_content_cleared.connect(func(_reason: String): _abort("stage"))
	ev.player_died.connect(func(): _abort("death"))
	ev.run_ended.connect(func(_won: bool): _abort("stage"))


# Registers a row (combat.gd's ult_default; a pilot unit uses its own marked block instead).
func register(id: String, row: Dictionary) -> void:
	_ult_rows[id] = row


func phase() -> String:
	return _phase


func active() -> bool:
	return _phase != IDLE


func _on_stage_entered(_stage: int, retry: bool) -> void:
	_outpost_encore = false
	_abort("stage")
	if retry:
		meter.restore_entry()
		_was_full = meter.full()
	else:
		meter.mark_entry()


# Moss's last-call kettle (shop.gd brew, W1-73): the cogs fed at the world's last till arrive
# in the boss fight as a head start on the meter, at every arrival in that arena.
func _pour_brew() -> void:
	var shop = ctx.build.get("shop") if ctx.build != null else null
	var points: float = shop.pour_brew() if shop != null else 0.0
	if points > 0.0:
		meter.refund(points)
		_check_full()


# --- The meter --------------------------------------------------------------------------

func _feed(source: String, amount := 1.0) -> void:
	if not _fills():
		return
	if meter.add(source, amount) > 0.0:
		_check_full()


# A harpoon link beyond a chain's first pays once per enemy per UltimateMeter.CHAIN_LINK_GAP
# (UltimateMeter.chain_link).
func _feed_link(target: Node3D) -> void:
	var id := target.get_instance_id() if is_instance_valid(target) else 0
	if meter.chain_link(id, int(ctx.player.chain.combo), _fills()) > 0.0:
		_check_full()


# The meter fills in play only: not in the bay, not between screens (a ceremony pauses the
# tree), and never during a set piece (the meter is locked then).
func _fills() -> bool:
	if ctx.flow == null or not ctx.flow.in_play():
		return false
	return ctx.terrain == null or not ctx.terrain.has_method("in_bay") or not ctx.terrain.in_bay(ctx.player.ball_position())


func _check_full() -> void:
	var full := meter.full()
	if full and not _was_full:
		_record_fill = _clock - _fill_since
		ctx.events.ultimate_ready.emit(_ult_id())
	_was_full = full


func _on_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if kind in ["stomp", "ram", "slam"]:
		var id := enemy.get_instance_id() if is_instance_valid(enemy) else 0
		if _clock - float(_contact_at.get(id, -INF)) < CONTACT_GAP:
			return
		_contact_at[id] = _clock
		_feed("contact")
	elif Weapons.BASE.has(kind):
		_feed("weapon")


func _on_posture(enemy: Node3D, _posture: float, staggered: bool) -> void:
	if not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if staggered and not bool(_staggered.get(id, false)):
		_feed("stagger")
	_staggered[id] = staggered
	if enemy.has_method("chunks_left"):
		var left: int = enemy.chunks_left()
		if _chunks.has(id) and left < int(_chunks[id]):
			_feed("shatter")
		_chunks[id] = left


func _ult_id() -> String:
	return String(ctx.player.abilities.ultimate_id)


# --- Q ----------------------------------------------------------------------------------

# Why a Q press would be refused now: "" (it would start), "busy" or "uncharged".
func can_start() -> String:
	if active() or ctx.flow == null or not ctx.flow.in_play() or ctx.flow.state_name() == "launch" or ctx.player.frozen():
		return "busy"
	if ctx.terrain != null and ctx.terrain.has_method("in_bay") and ctx.terrain.in_bay(ctx.player.ball_position()):
		return "busy"
	if not meter.full():
		return "uncharged"
	return ""


# A Q press with this aim ({origin, forward}, optionally harpoon: the lock record). Recalls in
# the wind-up; otherwise starts, or is refused with its verb_failed reason, which it returns.
func press(aim := {}) -> String:
	if _phase == WINDUP:
		recall()
		return ""
	var refusal := can_start()
	if refusal != "":
		ctx.events.verb_failed.emit("ultimate", refusal, ctx.player.ball_position())
		return refusal
	if aim.is_empty():
		aim = _live_aim()
	start(plan(ctx.player.ball_position(), aim))
	return ""


func _live_aim() -> Dictionary:
	return {"origin": ctx.aim_origin(), "forward": ctx.aim_forward(), "harpoon": ctx.player.kit.aim}


func _heft_index() -> int:
	var c := 1
	if ctx.run != null and ctx.run.has_method("heft_class"):
		c = int(ctx.run.heft_class())
	return clampi(c - 1, 0, HEFT_MULT.size() - 1)


func _row() -> Dictionary:
	return AbilityState.ABILITIES.get(_ult_id(), {})


func _knob(knob: String, fallback):
	if UpgradeTree.KNOBS.has(knob):
		return ctx.player.tree.knob(knob)
	return fallback


# The path, planned once with the harpoon's own target query, in the row's `paths` order
# (default line, rail, arc), then the hop. Returns {path, from, to, target, beats, seconds,
# flight, legs}; seconds is the wind-up plus the flight.
func plan(ball: Vector3, aim: Dictionary, paths: Array = []) -> Dictionary:
	var row := _row()
	var heft := _heft_index()
	var reach: float = ARC_REACH[heft] + (10.0 if _ult_id() == "ball_lightning" else 0.0)
	var kit = ctx.player.kit
	var found := {}
	var custom: Dictionary = _ult_rows.get(_ult_id(), {})
	if custom.has("target"):
		found = (custom["target"] as Callable).call(ball, aim)
	# The row's own order (ult_default: line then arc); `paths` overrides it for a caller that
	# plans another row's order (a variant preview, a test).
	var order: Array = paths if not paths.is_empty() else row.get("paths", ["line", "rail", "arc"])
	var harpoon: Dictionary = aim.get("harpoon", kit.aim)
	var point = _aim_point(aim, reach + RAIL_SEARCH)
	# The row's order decides: a row that lists arc before line takes the arc even with a
	# line standing (section 4, "unless the pilot's sheet reorders paths").
	for path in order:
		if not found.is_empty():
			break
		if path == "line":
			if kit.hooked:
				found = {"path": "line", "to": kit.anchor, "target": kit.anchor_body if kit.on_body else null}
			elif harpoon.get("state", Augments.AIM_NONE) != Augments.AIM_NONE and harpoon.has("point") \
					and ball.distance_to(harpoon["point"]) <= ctx.player.grapple_range():
				found = {"path": "line", "to": harpoon["point"], "target": harpoon.get("body")}
		elif path == "rail" and rail_query.is_valid() and point != null:
			var rail: Dictionary = rail_query.call(point)
			if not rail.is_empty() and (rail["entry"] as Vector3).distance_to(point) <= RAIL_SEARCH:
				found = {"path": "rail", "to": rail.get("to", rail["entry"]), "entry": rail["entry"]}
		elif path == "arc" and point != null and _ground_hit(aim, reach) != null:
			found = {"path": "arc", "to": _ground_hit(aim, reach)}
	if found.is_empty():
		found = {"path": "hop", "to": ball}
	var mode: String = found["path"]
	var to: Vector3 = found["to"]
	var length := ball.distance_to(to)
	var beat := _beat_now()
	var flight := HOP_SECONDS if mode == "hop" else round_flight(length, beat)
	var fixed := int(row.get("beats", 0))
	var beats := _beats_in(flight, beat)
	if fixed > 0 and mode != "hop":
		beats = fixed
		flight = fixed * (beat if beat > 0.0 else FLIGHT_NO_MUSIC / NO_MUSIC_BEATS)
	var extra := int(_knob("ult_beats", 0))
	if extra > 0:
		var each := flight / maxi(beats, 1)
		beats += extra
		flight += extra * each
	# One leg by default (section 12, item 1). A rail is two: a short arc onto the entry, then
	# the rail itself; only the last leg ends in a landing strike.
	var legs := [{"mode": mode, "to": to, "beats": beats, "seconds": flight, "strike": true}]
	if mode == "rail":
		var first := maxi(1, beats / 3)
		var each := flight / maxi(beats, 1)
		legs = [{"mode": "arc", "to": found["entry"], "beats": first, "seconds": first * each, "strike": false},
			{"mode": "line", "to": to, "beats": beats - first, "seconds": (beats - first) * each, "strike": true}]
	return {"path": mode, "from": ball, "to": to, "target": found.get("target"), "beats": beats,
		"flight": flight, "seconds": windup_seconds() + flight, "legs": legs}


# The flight seconds for a path length: length / 18 m/s clamped to 1.6 to 3.2 s, then whole
# beats of the music so the landing falls on a beat, kept inside the clamp. 2.4 s with none.
static func round_flight(length: float, beat: float) -> float:
	if beat <= 0.0:
		return FLIGHT_NO_MUSIC
	var raw := clampf(length / FLIGHT_SPEED, FLIGHT_MIN, FLIGHT_MAX)
	var beats := maxi(1, roundi(raw / beat))
	if beats * beat < FLIGHT_MIN - 0.0001:
		beats += 1
	if beats * beat > FLIGHT_MAX + 0.0001:
		beats -= 1
	return beats * beat


static func _beats_in(flight: float, beat: float) -> int:
	if beat <= 0.0:
		return NO_MUSIC_BEATS
	return maxi(1, roundi(flight / beat))


func _beat_now() -> float:
	return maxf(0.0, float(beat_seconds.call())) if beat_seconds.is_valid() else 0.0


func _aim_point(aim: Dictionary, reach: float):
	if not aim.has("origin") or not aim.has("forward"):
		return null
	var space := _space()
	if space == null:
		return null
	var from: Vector3 = aim["origin"]
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + (aim["forward"] as Vector3).normalized() * reach, Augments.WORLD_MASK))
	return hit["position"] if not hit.is_empty() else from + (aim["forward"] as Vector3).normalized() * reach


# Ground (a walkable face) at the aim point within reach of the ball, or null.
func _ground_hit(aim: Dictionary, reach: float):
	var space := _space()
	if space == null or not aim.has("origin"):
		return null
	var from: Vector3 = aim["origin"]
	var dir: Vector3 = (aim["forward"] as Vector3).normalized()
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * (reach + 10.0), Augments.WORLD_MASK))
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		return null
	var at: Vector3 = hit["position"]
	if at.distance_to(ctx.player.ball_position()) > reach:
		return null
	return at


func _space() -> PhysicsDirectSpaceState3D:
	if ctx == null or ctx.root == null or not ctx.root.is_inside_tree():
		return null
	return ctx.root.get_world_3d().direct_space_state


# Commits a plan: spends the meter, breaks every hold, cuts the line without a "broke",
# draws the path and starts the wind-up.
func start(p: Dictionary) -> void:
	if p.is_empty() or not meter.spend():
		return
	_id = _ult_id()
	if _sable():
		stakes.begin()
		# Breaking the mount also breaks a slingshot held on it: a gauge left charging would
		# keep _charging() true and turn every harpoon press into a cancel.
		ctx.player.kit.mounted = false
		ctx.player.kit.slingshot.cancel()
		_lightning_peaks = 0
		_outpost_encore = false
		_outpost_second = false
	_plan = p
	last_plan = p
	meter.locked = true
	_was_full = false
	_phase = WINDUP
	_left = windup_seconds()
	_plant_from = ctx.player.planar_velocity().length()
	_leg = 0
	_ride = null
	_posture_spent = {}
	_peaked = false
	_offset = 0.0
	# The line goes with the cause "ultimate", which publishes nothing, as a landing does; the
	# set piece draws its own cable to B.
	if ctx.player.kit.hooked:
		ctx.player.cut_line("ultimate")
	# The breakout row: the holds node breaks every hold on ultimate_started, below.
	if ctx.spawner != null and ctx.spawner.fleet.holds.holding():
		combat._discover("set_piece_breakout", ctx.player.ball_position())
	_record = {"id": _id, "path": p["path"], "seconds": snappedf(float(p["seconds"]), 0.001), "heft_class": _heft_index() + 1,
		"volley_hits": 0, "landing_hits": 0, "damage": 0.0, "bailed": false, "recalled": false,
		"fill_seconds": snappedf(_record_fill, 0.01)}
	if _sable():
		_record["stakes"] = 0
		_record["stakes_hooked"] = 0
	ctx.run.set_meta("ultimate_record", _record)
	_fill_since = _clock
	ctx.events.ultimate_started.emit(_id, String(p["path"]), p["from"], p["to"], float(p["seconds"]))
	_draw_path(p)


func _draw_path(p: Dictionary) -> void:
	if combat == null or combat.effects == null:
		return
	var from: Vector3 = p["from"]
	for leg in p["legs"]:
		combat.effects.arc(from + Vector3.UP * 0.5, (leg["to"] as Vector3) + Vector3.UP * 0.5, Palette.ARC)
		from = leg["to"]


# The wind-up is Q's cast (design-v3/FIELDS-AND-CASTS.md section 4, Andrew's "Big ones only"
# 2026-10-17 19:56:59Z): a row's `cast` when it names one (the stronger depth-3 variants),
# else WINDUP_SECONDS.
func windup_seconds() -> float:
	return float(AbilityState.ABILITIES.get(_ult_id(), {}).get("cast", WINDUP_SECONDS))


func winding_up() -> bool:
	return _phase == WINDUP


# Whether this Q's wind-up plants the pilot (Tarn's and the Cannon's variants).
func plants() -> bool:
	return bool(AbilityState.ABILITIES.get(_ult_id(), {}).get("plant", false))


# The plant is the pilot's own heavy stance, the one cast that stops the ball, and only while
# its wind-up runs. The planar speed brakes linearly from the speed at the press to zero over
# PLANT_STOP_SECONDS and is held there, the pilot's drive included; the fall stays as it is.
# The line was already cut at the start, so the cause "ultimate" cuts nothing new.
func _plant() -> void:
	var v: Vector3 = ctx.player.state.velocity
	var flat := Vector3(v.x, 0.0, v.z)
	var into := windup_seconds() - _left
	var cap := _plant_from * maxf(0.0, 1.0 - into / PLANT_STOP_SECONDS)
	if flat.length() <= cap + 0.001:
		return
	flat = flat.normalized() * cap if cap > 0.0 else Vector3.ZERO
	ctx.player.set_velocity_now(Vector3(flat.x, v.y, flat.z), "ultimate")


# Q in the wind-up: cancel with a full refund. A field's jolt calls it too (jolt_layer.gd).
func recall() -> void:
	if _phase != WINDUP:
		return
	meter.locked = false
	meter.refund(UltimateMeter.CAP)
	_was_full = true
	_record["recalled"] = true
	_end("recall", true)


# Space in flight: leave the path now with the current velocity. Spent, no landing strike.
func bail() -> void:
	if _phase != FLIGHT:
		return
	_record["bailed"] = true
	if _sable():
		stakes.arm()
	_end("bail", false)


func _abort(reason: String) -> void:
	_outpost_encore = false
	if _phase == IDLE:
		return
	# Already landed: the recovery just ends; there is nothing left to cancel.
	if _phase == RECOVER:
		_phase = IDLE
		meter.locked = false
		return
	_end(reason, false)


func _end(reason: String, refunded: bool) -> void:
	_phase = IDLE
	_ride = null
	meter.locked = false
	ctx.run.set_meta("ultimate_record", _record)
	ctx.events.ultimate_cancelled.emit(_id, reason, refunded)


# --- The ride ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if ctx == null or ctx.run.class_def == null:
		return
	step(delta)


func step(delta: float) -> void:
	_clock += delta
	var player = ctx.player
	var intent = player.intent
	if _phase == IDLE:
		if _fills():
			meter.tick(delta, player.speed_tier())
			_check_full()
		if intent.ultimate_pressed:
			press()
		return
	if intent.ultimate_pressed:
		if _phase == WINDUP:
			recall()
			return
		ctx.events.verb_failed.emit("ultimate", "busy", player.ball_position())
	match _phase:
		WINDUP:
			_left -= delta
			if plants():
				_plant()
			if _left <= 0.0:
				_begin_flight()
		FLIGHT:
			if intent.jump_pressed:
				bail()
				return
			_fly(delta)
		RECOVER:
			_left -= delta
			if _left <= 0.0:
				_phase = IDLE
				meter.locked = false


func _begin_flight() -> void:
	_phase = FLIGHT
	var leg: Dictionary = _plan["legs"][_leg]
	_beats = int(leg["beats"])
	_beat_len = float(leg["seconds"]) / maxi(_beats, 1)
	_beat = 0
	_beat_clock = 0.0
	_ride = _carrier(ctx.player.ball_position(), leg)
	_leg_time = 0.0
	_expected = ctx.player.ball_position()
	ctx.player.set_velocity_now(_ride.velocity_at(0.0), "ultimate")


# A RideRail held to exactly the drawn leg over its seconds: a straight line, an arc, or the
# hop straight up HOP_HEIGHT and down on the same spot.
func _carrier(from: Vector3, leg: Dictionary):
	var to: Vector3 = leg["to"]
	var seconds: float = maxf(0.2, float(leg["seconds"]))
	var ride = RideRail.new()
	ride.kind = "ultimate"
	ride.origin = from
	ride.target = to
	ride.flight = seconds
	ride.active = true
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	ride.heading = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	ride.release_speed = ctx.player.planar_velocity().length()
	if String(leg["mode"]) == "line":
		ride.mode = RideRail.LINE
		ride.velocity = (to - from) / seconds
	else:
		ride.mode = RideRail.ARC
		var g := GRAVITY
		if String(leg["mode"]) == "hop":
			g = 8.0 * HOP_HEIGHT / (seconds * seconds)
		if _id.begins_with("cannon_"):
			g = minf(g, 8.0 * Weapons.APEX_CAP / (seconds * seconds))
		ride.gravity = g
		ride.velocity = flat / seconds + Vector3.UP * ((to.y - from.y + 0.5 * g * seconds * seconds) / seconds)
	return ride


func _fly(delta: float) -> void:
	var player = ctx.player
	var ball: Vector3 = player.ball_position()
	# Something on the path stopped the ball: the flight ends there as a landing.
	if _leg_time > 0.1 and ball.distance_to(_expected) > BLOCKED:
		_land(ball)
		return
	_leg_time += delta
	_beat_clock += delta
	var beat_tolerance := 0.00001 if _sable() else 0.0
	while _beat_clock + beat_tolerance >= _beat_len and _beat < _beats:
		_beat_clock -= _beat_len
		_beat += 1
		_volley()
		if not _peaked and _beat >= ceili(_beats / 2.0):
			_peaked = true
			_peak(player.ball_position())
	var v = null
	if _sable() or _id.begins_with("cannon_"):
		# RideRail normally releases 40 ms early; a stake route holds until its final beat.
		_ride.time += delta
		if _ride.time < _ride.flight:
			v = _ride.velocity_at(_ride.time)
	else:
		v = _ride.step(delta)
	if v == null:
		_land(_ride.target)
		return
	# Steering: up to CORRIDOR either side of the drawn path.
	var side := Vector3(-_ride.heading.z, 0.0, _ride.heading.x)
	var want: float = clampf(_offset + float(player.intent.move.x) * STEER_SPEED * delta, -CORRIDOR, CORRIDOR)
	var steer: float = (want - _offset) / delta if delta > 0.0 else 0.0
	_offset = want
	_expected = _ride.point_at(_ride.time) + side * _offset
	player.set_velocity_now(v + side * steer, "ultimate")


func _peak(at: Vector3) -> void:
	var row: Dictionary = _ult_rows.get(_id, {})
	if row.has("peak"):
		(row["peak"] as Callable).call(at)
	ctx.events.ultimate_peak.emit(_id, at)


func _volley() -> void:
	var row: Dictionary = _ult_rows.get(_id, {})
	if not row.has("tech"):
		return
	var hits: int = int((row["tech"] as Callable).call(_beat, ctx.player.ball_position(), ctx.aim_forward(), HEFT_MULT[_heft_index()]))
	_record["volley_hits"] = int(_record.get("volley_hits", 0)) + hits


func _land(at: Vector3) -> void:
	var legs: Array = _plan["legs"]
	var leg: Dictionary = legs[_leg]
	_leg += 1
	# ult_encore: a second leg if a target sits within 30 m of the landing.
	if _leg == legs.size() and _knob("ult_encore", false) and (not _sable() or (_leg == 1 and _id != "outpost")) and not (_id.begins_with("cannon_") and _cannon_encore):
		var next = _encore_target(at)
		if next != null:
			legs.append({"mode": "arc", "to": next, "beats": 2 if _sable() else _beats, "seconds": (2 if _sable() else _beats) * _beat_len, "strike": true})
	if bool(leg.get("strike", true)):
		_strike(at)
	if _leg < legs.size():
		_begin_flight()
		return
	var release: Vector3 = _ride.release_velocity() if _ride != null else Vector3.ZERO
	var row: Dictionary = _ult_rows.get(_id, {})
	if row.has("release"):
		release = row["release"].call(at, release)
	_ride = null
	ctx.player.set_velocity_now(release, "ultimate")
	_phase = RECOVER
	_left = RECOVER_SECONDS
	ctx.run.set_meta("ultimate_record", _record)


# The landing strike: it pays the chain multiplier and ends the chain as a paid smash does.
func _strike(at: Vector3) -> void:
	var chain_links: int = ctx.player.chain.combo
	var mult: float = ctx.player.pay_chain(at)
	var row: Dictionary = _ult_rows.get(_id, {})
	var result: Array = [0, 0.0]
	if row.has("landing"):
		result = (row["landing"] as Callable).call(at, HEFT_MULT[_heft_index()], mult)
	# A third entry means the row hits later and reports then (Rivet's late carve).
	if result.size() < 3:
		report_landing(_record, _id, at, result)
	if _id == "cable_run" and _leg >= (_plan.get("legs", []) as Array).size():
		_sable_runs += 1
		if ctx.codex != null and ctx.codex.known("set_piece"):
			combat._discover("cable_run", at)
		if _sable_runs >= 3:
			combat._discover("sable_cable_runs", at)
	combat._discover("set_piece", at)
	if chain_links >= 3:
		combat._discover("set_piece_cash_in", at)


# A landing's [hits, damage] into its own set piece's record, and the landed event.
func report_landing(record: Dictionary, id: String, at: Vector3, result: Array) -> void:
	record["landing_hits"] = int(record.get("landing_hits", 0)) + int(result[0])
	record["damage"] = snappedf(float(record.get("damage", 0.0)) + float(result[1]), 0.01)
	if float(result[1]) > 0.0:
		preload("res://src/build/consumables.gd").echo_ultimate(ctx, combat, float(result[1]), at, landing_radius())
	ctx.events.ultimate_landed.emit(id, at, int(result[0]), float(result[1]))


func _encore_target(at: Vector3):
	var best = null
	var gap := ENCORE_REACH
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var d: float = enemy.global_position.distance_to(at)
		if d > 1.0 and d <= gap:
			gap = d
			best = enemy.global_position
	return best


# --- Helpers the rows share ---------------------------------------------------------------

# The landing radius for this heft class, with ult_radius.
func landing_radius() -> float:
	return LANDING_RADIUS[_heft_index()] + float(_knob("ult_radius", 0.0))


func volley_targets() -> int:
	return VOLLEY_TARGETS + int(_knob("ult_volley", 0))


# Damage taken during the set piece: x0.2 and never below 1 health. The amount to take.
func defend(amount: float, hp: float) -> float:
	if not active():
		return amount
	return clampf(amount * DAMAGE_TAKEN, 0.0, maxf(0.0, hp - 1.0))


# The most one set piece adds on a closed Warden guard: 70 for a monster build (heft above the
# fight's library top-bucket maximum, coordinator ruling (B) on #222, 21 Oct), else 45.
static func warden_cap(monster: bool) -> float:
	return WARDEN_POSTURE_CAP if monster else WARDEN_POSTURE_CAP_ORDINARY


# warden_cap for a Warden node; one that cannot say reads as no monster, so 45.
static func cap_for_warden(warden: Node) -> float:
	return warden_cap(warden.monster_build() if warden.has_method("monster_build") else false)


# Posture a hit on a closed Warden guard may still add in this set piece: the cap counts
# volleys and landing together. Applies `result` (the Warden's own judge) with its gain cut
# to what is left.
func warden_posture(warden: Node3D, result: Dictionary) -> void:
	var id := warden.get_instance_id()
	var spent := float(_posture_spent.get(id, 0.0))
	var gain := minf(float(result.get("gain", 0.0)), maxf(0.0, cap_for_warden(warden) - spent))
	result["gain"] = gain
	result["shatter"] = false
	result["crack"] = false
	_posture_spent[id] = spent + gain
	warden.apply_posture_hit(result)


# --- PC-SABLE: cable route, arc rain and a mounted outpost -----------------------------
var stakes
var _sable_runs := 0
var _lightning_peaks := 0
var _outpost_encore := false
var _outpost_at := Vector3.ZERO
var _outpost_second := false
var _outpost_until := 0.0


func _sable() -> bool:
	return _id in ["cable_run", "ball_lightning", "outpost"]


func _sable_tech(beat: int, ball: Vector3, _aim: Vector3, heft_mult: float) -> int:
	return stakes.beat(beat, ball, heft_mult)


func _sable_peak(_at: Vector3) -> void:
	_record["volley_hits"] = int(_record.get("volley_hits", 0)) + stakes.relay()


func _sable_damage(at: Vector3, radius: float, damage: float, limit := 64, landing := true) -> Array:
	combat.effects.ring(at, radius, Palette.ARC)
	var hits := 0
	var dealt := 0.0
	for enemy in combat._nearest_list(at, radius, limit):
		dealt += combat._ult_hit(enemy, "arc", damage, at, landing)
		hits += 1
	return [hits, dealt]


# A Q landing's ring: the props it reaches break (+1 class) and the machines in it take the damage, both from the
# one radius the caller resolved.
func _landing_damage(at: Vector3, radius: float, damage: float) -> Array:
	ctx.break_props(at, radius, "ultimate")
	return _sable_damage(at, radius, damage)


func _sable_landing(at: Vector3, heft_mult: float, chain_mult: float) -> Array:
	stakes.plant(at)
	stakes.arm()
	return _landing_damage(at, landing_radius(), LANDING_DAMAGE * heft_mult * chain_mult * (0.5 if _leg > 1 else 1.0))


func _lightning_tech(beat: int, ball: Vector3, _aim: Vector3, heft_mult: float) -> int:
	var space := _space()
	if space == null:
		return 0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ball, ball + Vector3.DOWN * 40.0, Augments.WORLD_MASK))
	if hit.is_empty():
		return 0
	stakes._note("rain", beat)
	return int(_sable_damage(hit["position"], 6.0, 12.0 * heft_mult, volley_targets(), false)[0])


func _lightning_peak(at: Vector3) -> void:
	_lightning_peaks += 1
	var burst := Weapons.burst(20.0)
	var result := _sable_damage(at, float(burst["radius"]) + float(_knob("ult_radius", 0.0)),
		float(burst["damage"]) * HEFT_MULT[_heft_index()], int(burst["targets"]) + int(_knob("ult_volley", 0)), false)
	_record["volley_hits"] = int(_record.get("volley_hits", 0)) + int(result[0])


func _lightning_landing(at: Vector3, heft_mult: float, chain_mult: float) -> Array:
	ctx.player._tag_faces(at)
	ctx.player.state.air_actions = 1
	return _landing_damage(at, landing_radius() + 3.0, LANDING_DAMAGE * heft_mult * chain_mult * (0.5 if _leg > 1 else 1.0))


func _outpost_landing(at: Vector3, heft_mult: float, chain_mult: float) -> Array:
	if _outpost_second:
		return _landing_damage(at, landing_radius(), LANDING_DAMAGE * heft_mult * chain_mult * 0.5)
	stakes.plant(at)
	stakes.arm()
	stakes.start_sentries(_beat_len, heft_mult)
	var speed := _sable_flight_speed()
	var burst := Weapons.burst(speed)
	var result := _sable_damage(at, float(burst["radius"]) + float(_knob("ult_radius", 0.0)),
		float(burst["damage"]) * heft_mult * chain_mult, int(burst["targets"]))
	combat.last_burst = burst.duplicate()
	combat.last_burst["at"] = at
	combat.last_burst["hit"] = int(result[0])
	combat.last_burst["kind"] = "turret"
	ctx.events.special_used.emit("detonation_gauge", at)
	_outpost_at = at
	_outpost_until = _clock + Stakes.SENTRY_SECONDS
	_outpost_encore = bool(_knob("ult_encore", false))
	return result


func _sable_normal(at: Vector3) -> Vector3:
	var space := _space()
	if space != null:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 3.0, Augments.WORLD_MASK))
		if not hit.is_empty():
			return hit["normal"]
		var from: Vector3 = _plan.get("from", at + Vector3.UP)
		var direction := (at - from).normalized()
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(at - direction * 2.0, at + direction * 2.0, Augments.WORLD_MASK))
		if not hit.is_empty():
			return hit["normal"]
	return Vector3.UP


func _sable_flight_speed() -> float:
	return _ride.velocity.length() if _ride != null else FLIGHT_SPEED


func _sable_release(at: Vector3, release: Vector3) -> Vector3:
	var player = ctx.player
	if _id == "ball_lightning":
		return Vector3(release.x, 8.0, release.z)
	var normal := _sable_normal(at)
	var speed := _sable_flight_speed()
	if _id == "outpost" and not _outpost_second:
		Augments.mount_outpost(player.kit, player.state, at, normal, speed)
		ctx.events.mounted.emit(at, speed)
		return Vector3.ZERO
	var blazing: float = player.tuning.f("cruise") * 1.9 + 0.5
	var exit := clampf((speed * 0.85 + 6.0) * 1.3, blazing, 45.0)
	exit += Augments.mass_spend(player.kit, exit)
	var launch := Augments.mount_exit_direction(normal, player.drive_basis) * exit
	ctx.events.dismounted.emit(launch)
	return launch


func _outpost_depart(velocity: Vector3) -> void:
	if not _outpost_encore or _clock > _outpost_until or velocity.length() < 0.1:
		return
	# The encore is a second flight from rest only: never over a live wind-up or flight, and
	# never out of play or with the ball frozen (the same doors can_start keeps).
	if _phase != IDLE and _phase != RECOVER:
		return
	if ctx.flow == null or not ctx.flow.in_play() or ctx.player.frozen():
		return
	_outpost_encore = false
	var target = _encore_target(_outpost_at)
	if target == null:
		return
	_outpost_second = true
	_id = "outpost"
	meter.locked = true
	_leg = 0
	_peaked = true
	_offset = 0.0
	var seconds := 2.0 * _beat_len
	_plan = {"from": ctx.player.ball_position(), "to": target, "path": "arc",
		"legs": [{"mode": "arc", "to": target, "beats": 2, "seconds": seconds, "strike": true}]}
	_draw_path(_plan)
	_begin_flight()


# --- PC-CANNON: calls keep their original clock even after a bail or collision ----------
var _cannon_id := ""
var _cannon_due := -1.0
var _cannon_calls := 0
var _cannon_cursor := 0
var _cannon_budget := {}
var _cannon_peak_done := false
var _cannon_encore := false
var _cannon_record := {}


func _cannon_started(id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float) -> void:
	if not id.begins_with("cannon_"):
		return
	_cannon_id = id
	_cannon_due = -1.0
	_cannon_calls = 0
	_cannon_cursor = 0
	_cannon_budget = _posture_spent
	_cannon_peak_done = false
	_cannon_encore = false
	_cannon_record = _record
	_cannon_record["zones"] = 0
	_cannon_record["zone_hits"] = 0


func _cannon_mortar_target(_ball: Vector3, aim: Dictionary) -> Dictionary:
	var ground = _ground_hit(aim, ARC_REACH[_heft_index()] * Weapons.MORTAR_REACH)
	return {"path": "arc", "to": ground} if ground != null else {"path": "hop", "to": ctx.player.ball_position()}


# Subtract the carrier's deliberate arc height before probing the floor: twelve metres
# means a missing island below the flight's ground path, rather than the lob's own apex.
func _cannon_projection(ball: Vector3) -> Vector3:
	if _ride != null and _ride.mode == RideRail.ARC:
		var t := clampf(_ride.time, 0.0, _ride.flight)
		ball.y -= 0.5 * _ride.gravity * t * (_ride.flight - t)
	return ball


func _cannon_target(centre: Vector3, aim: Vector3, reach: float) -> Vector3:
	var found := centre + Vector3(aim.x, 0.0, aim.z).normalized() * 8.0
	var best := reach
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var to: Vector3 = enemy.global_position - centre
		var flat := Vector3(to.x, 0.0, to.z)
		var sight: Vector3 = enemy.global_position - ctx.player.ball_position()
		if flat.length() <= best and (aim.length() < 0.01 or sight.length() < 0.01 or aim.angle_to(sight) <= deg_to_rad(VOLLEY_BIAS_DEG)):
			best = flat.length()
			found = enemy.global_position
	return found


func _cannon_call(family: String, at: Vector3, target: Vector3, due: float, heft: float, options := {}) -> bool:
	var cap := Weapons.CALL_CAP if _cannon_peak_done else Weapons.CALL_CAP - 4
	if _cannon_calls >= cap:
		return false
	var floor = combat._cannon_floor(at)
	if floor == null:
		return false
	var overrides := {"warn": maxf(0.0, due - combat._clock), "live_at": due,
		"budget": _cannon_budget, "record": _cannon_record}
	overrides.merge(options, true)
	combat._commit_cannon(family, target, floor, Weapons.ZONE_REACH, Weapons.ZONE_DAMAGE * heft,
		"special", family == "plate", overrides)
	_cannon_calls += 1
	_cannon_record["zones"] = int(_cannon_record.get("zones", 0)) + 1
	var audio = combat._cannon_audio()
	if audio != null:
		audio.cannon_family(family, false, "cannon_call")
	return true


func _cannon_tech(beat: int, ball: Vector3, aim: Vector3, heft: float) -> int:
	if beat >= _beats:
		return 0
	if _cannon_due < 0.0:
		_cannon_due = combat._clock + maxf(0.0, float(_plan["legs"][_leg]["seconds"]) - _leg_time)
	var centre := _cannon_projection(ball)
	var middle := ceili(_beats / 2.0)
	if _cannon_id == "cannon_fire_mission":
		if beat == middle:
			return 0
		var family: String = preload("res://src/boss/mind_attacks.gd").FAMILIES[_cannon_cursor % 4]
		_cannon_cursor += 1
		_cannon_call(family, centre, _cannon_target(centre, aim, Weapons.ZONE_REACH), _cannon_due, heft)
	elif _cannon_id == "cannon_creeping_barrage":
		var velocity: Vector3 = _ride.velocity_at(_ride.time) if _ride != null else ctx.player.planar_velocity()
		velocity.y = 0.0
		var ahead := centre + velocity * Weapons.CREEP_AHEAD_BEATS * _beat_len
		var side := Vector3.UP.cross(velocity.normalized())
		if side.length() < 0.01:
			side = Vector3.RIGHT
		for i in 1 + int(_knob("ult_volley", 0)):
			var at := ahead + velocity.normalized() * 6.0 * i
			_cannon_call("lane", at - side * 12.2, at + side * 12.2, combat._clock + _beat_len, heft)
	else:
		for i in 1 + int(_knob("ult_volley", 0)):
			var target := _cannon_target(centre, aim, 16.0)
			if i > 0:
				target = centre * 2.0 - target
			_cannon_call("plate", centre, target, combat._clock + _beat_len, heft)
	return 0


func _cannon_peak(_at: Vector3) -> void:
	_cannon_peak_done = true
	var heft: float = HEFT_MULT[_heft_index()]
	var at: Vector3 = _plan["legs"][_leg]["to"]
	if _cannon_id == "cannon_fire_mission":
		for family in preload("res://src/boss/mind_attacks.gd").FAMILIES:
			_cannon_call(family, at, _cannon_target(at, ctx.aim_forward(), Weapons.ZONE_REACH), _cannon_due, heft)
	elif _cannon_id == "cannon_creeping_barrage":
		var ball := _cannon_projection(ctx.player.ball_position())
		_cannon_call("split_lane", ball, ball + _ride.heading * 10.0, combat._clock + _beat_len, heft)
	else:
		var target := _cannon_target(at, ctx.aim_forward(), 16.0)
		var radius := Vector2(target.x - at.x, target.z - at.z).length()
		var half := preload("res://src/boss/mind_attacks.gd").RUSH_HALF_BAND + float(_knob("ult_radius", 0.0))
		_cannon_call("rush", at, target, _cannon_due, heft, {"band": Vector2(maxf(0.0, radius - half), minf(Weapons.ZONE_REACH, radius + half))})


func _cannon_landing(at: Vector3, heft: float, chain: float) -> Array:
	combat._step_cannon(0.0)
	var mortar := _cannon_id == "cannon_plate_mortar"
	var hits := 0
	var damage := 0.0
	var scale := 0.5 if _cannon_encore else 1.0
	combat.effects.ring(at, landing_radius(), Palette.ANCIENT)
	ctx.break_props(at, landing_radius(), "ultimate")
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()) or enemy.global_position.distance_to(at) > landing_radius():
			continue
		damage += combat._cannon_set_piece_hit(enemy, LANDING_DAMAGE * heft * chain * scale, at, true, mortar, _cannon_budget)
		hits += 1
	var discovery := _cannon_id
	# B6's framework card gets the first landing. The pilot card waits for a later one.
	if ctx.codex != null and ctx.codex.known("set_piece"):
		match discovery:
			"cannon_fire_mission":
				combat._discover("cannon_fire_mission", at)
			"cannon_creeping_barrage":
				combat._discover("cannon_creeping_barrage", at)
			"cannon_plate_mortar":
				combat._discover("cannon_plate_mortar", at)
	if _cannon_id == "cannon_fire_mission" and hits >= 8:
		combat._discover("cannon_time_on_target", at)
	if _cannon_id == "cannon_creeping_barrage":
		var heading: Vector3 = _ride.heading if _ride != null else Vector3.FORWARD
		_cannon_call("lane", at, at + heading * 24.4, combat._clock + _beat_len, heft)
	# The framework appended the encore before calling landing. Its second leg is four
	# beats, carries this variant's tech and lands at half damage; never append a third.
	if _leg < _plan["legs"].size():
		var leg: Dictionary = _plan["legs"][_leg]
		leg["mode"] = "line" if _cannon_id == "cannon_creeping_barrage" else "arc"
		leg["beats"] = 4
		leg["seconds"] = 4.0 * _beat_len
		_cannon_encore = true
		_cannon_due = -1.0
		_cannon_calls = 0
		_cannon_peak_done = false
		_peaked = false
	return [hits, damage]
