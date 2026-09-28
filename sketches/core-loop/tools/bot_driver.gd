extends RefCounted

const Intent := preload("res://src/movement/intent.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const TelegraphScript := preload("res://src/combat/telegraph.gd")
const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const LoopMode := preload("res://src/core/loop_mode.gd")
const Features := preload("res://src/world/features.gd")

# One scripted player for the design feedback loop (DEMO-SPEC, "Bot runs"). It plays a
# real Game through the same doors a person uses: an Intent.Scripted source for the
# keys, camera.look() for the mouse and the flow's own title and class calls. It never
# calls a run mutator, strikes an enemy or moves the ball, so the run log and the codex
# log it leaves behind record play, not a test's shortcuts.
#
# What it may read is what a player could see: the ball, enemies in the `enemy` group,
# the committed telegraphs combat and the boss draw, the gates' offer records, the scrap
# lines, the vault, the stage events' rings and the boss's ship. Those reads go through
# the game's module nodes; the bot is a harness, not a module, so the CONTRACTS rule
# against reaching into another module's folder does not bind it, and it writes nothing
# there.
#
# Policies (DEMO-SPEC, three drivers):
#   skipper        beelines at the Warden from the drop, breaks it, takes the first gate.
#   completionist  rolls the scrap lines (and so the fabricator hoops on them), joins
#                  an armed event, cracks the vault, then breaks the Warden; prefers a
#                  gate that completes a synergy, then the higher tier.
#   random         a seeded wander biased toward the beacon, which commits to the
#                  Warden once close or late; random gate choice.
#   lapper         the v3 loop's skilled player (LOOP-REDESIGN section 4), mode-aware.
#                  Laps mode: rings the bell and laps the course ring by ring
#                  (laps_wanted, default the course's required), no loot, then fights.
#                  Drop mode: tight laps on the fast drop line, no loot, a drop on every
#                  window it can time off the published schedule, the gun on the open
#                  core. With no loop live it fights like the skipper.
#   lapper_blind   the drop-mode laps without reading the schedule: it never stops at
#                  the line's start, so every descent is a fast arrival on whatever the
#                  core is doing, and its misses measure the recovery. In laps mode it
#                  laps the course like the lapper.
# All of them fight Brindle the same way once a boss module exists (see _boss). In the
# drop mode the skipper is the section 4 camper: it beelines, holds fire and rams laps
# on the bowl floor, which is exactly what drop mode must not reward. In laps mode the
# skipper is the camper too: it rings the bell and rams the sleeping Warden without
# lapping, and the completionist laps once its loot is done.
#
# The hands every policy shares, so a measured cost is the game's and not a blind spot:
#   - Telegraph reading. A committed ring or lane (combat's telegraph.gd, the boss's
#     hazards) is seen REACTION seconds after it appears, a human's reaction time. From
#     then on, if the ball is inside it or will be within PREDICT seconds, the bot steers
#     to the nearest safe spot that keeps its line. Rings wider than FIELD_RADIUS (the
#     Warden's magnet reach) are fields, not dodgeable hits, and are ignored.
#   - Class kits. The pylon engineer plants on a steep face within PLANT_SEARCH of a
#     fight (the plant fires the opening burst), turrets for TURRET_SECONDS, then
#     slingshots off toward the target. Both classes fire their special into a crowd or
#     a close fight: overdrive for the runner, the discharge for the engineer.
#   - Weak points when punch is short. With punch below the lock's plating, a caps
#     Warden gets slams beside it (a slam within 2.6 m of a cap meets plating 0) and its
#     own pulse is taken for the height; a magnet Warden gets the gun on its magnet while
#     it tugs. With punch at or above plating the bot rams, as a player would.
#   - Upgrade-tree picks (tree_policy). "" leaves every offer untaken, so older runs
#     keep the untouched kit; "random" takes one of the two offered on each tree_offered
#     from its own seeded stream, so the rest of the bot's choices are unchanged.
#
# A run ends at stage-3 clear or a boss victory (outcome "won"), death ("died"), a
# "boss" flow state with no boss module ("boss"), or a stage or fight that runs past its
# limit ("stalled", "boss_stalled").

const POLICIES := ["skipper", "completionist", "random", "lapper", "lapper_blind"]
# The lapper: reach a line's start within LAP_REACHED, then leave when the Warden's
# published schedule says the core stands open LAP_SLACK either side of its arrival. The
# descent starts as a guess of LAP_DESCENT seconds and learns from every arrival within
# LAP_ARRIVED of the mast, landed or not; a miss (the core throws it back) or a descent
# not landed LAP_GIVE_UP after leaving the start sends the ball to the return.
const LAP_REACHED := 7.0
const LAP_WAYPOINT := 8.0
const LAP_SLACK := 0.35
# It leaves the start from nearly still, so one lap's descent predicts the next.
const LAP_BRAKED := 4.0
const LAP_ARRIVED := 5.0
const LAP_DESCENT := 3.6
const LAP_GIVE_UP := 9.0
const LAP_BOWL := 45.0
# Radians of camera yaw per second: a brisk mouse, not a snap.
const TURN_RATE := 5.0
const SENSITIVITY := 0.0022
# A stage longer than this is a stall: the bot could not break the Warden.
const STAGE_LIMIT := 240.0
const BOSS_LIMIT := 420.0
const STUCK_SPEED := 2.5
const STUCK_SECONDS := 2.0
const DETOUR_SECONDS := 1.4
# Walls on the way: probe this far along the heading and these turns off it.
const WALL_REACH := 4.0
const WALL_TILT := 0.5
const WALL_TURNS := [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]
const BOOST_GAP := 1.6
# The ram lap: charge until this close, then run up this far and charge again.
const CHARGE_CLOSE := 3.8
const RUNUP := 24.0
const RUNUP_SECONDS := 3.2
const AIM_REACH := 40.0
const WAYPOINT_REACHED := 9.0
const WAYPOINT_SECONDS := 14.0
const GATE_HOP_SECONDS := 6.0
const GATE_HOP_EVERY := 1.5
const VAULT_SECONDS := 45.0
const EVENT_PURSUIT_SECONDS := 40.0
const EVENT_LATEST := 150.0
const WANDER_GAP := Vector2(3.0, 6.0)
const WANDER_SPREAD := 1.0
const WANDER_COMMIT_DISTANCE := 45.0
const WANDER_COMMIT_TIME := 45.0
# Telegraph reading.
const REACTION := 0.25
const PREDICT := 0.35
const FIELD_RADIUS := 20.0
const ESCAPE_DIRECTIONS := 16
const ESCAPE_REACH := [5.0, 9.0, 13.0, 18.0]
# The caps loop: slam from this close to the Warden's centre.
const CAP_JUMP := 4.6
# Beside the body (Warden radius 2.8 + ball 1.0) and the approach point on a cap's line.
const CAP_INSIDE := 3.3
const CAP_BESIDE := 3.8
# Below this share of max HP the caps loop dodges the Warden's pulse instead of riding it.
const PULSE_HP_SHARE := 0.45
# Punch the bot knows it can bring: the best punch_now() it has seen, fading this fast,
# so "short of plating" is judged on a full-speed ram, not on the ball at rest.
const PUNCH_FADE := 4.0
# Engineer plants.
const PLANT_SEARCH := 22.0
const PLANT_RANGE := 45.0
const PLANT_REACH := 2.6
const PLANT_TIMEOUT := 5.0
const PLANT_EVERY := 10.0
const TURRET_SECONDS := 3.5
const FACE_TILT := 0.866
# Specials.
const CROWD := 2
const CROWD_RADIUS := 12.0
const CLOSE_FIGHT := 14.0
# The boss.
const BOSS_ORBIT := 32.0
const BAIT_RADIUS := 47.0
const RAMP_ANGLES := [0.0, 180.0]
const RAMP_BOTTOM := 46.0
const RAMP_PAST := 18.0
const RAMP_JUMP := 26.0
const RAMP_WINDOW := 0.5
const PICKUP_CHASE := 30.0
# Laps mode: within this of the return lift, with the shelf's ring next, roll for its mouth.
const LIFT_SEEK := 60.0
const CAP_ABOVE := 1.2
const CAP_REACH := 2.6

var game
var policy := "skipper"
var seed_value := 1
var class_index := 0
var rng := RandomNumberGenerator.new()
var source := Intent.Scripted.new()
# Set by the runner's --trace: prints the bot's goal and the ball every two seconds.
var trace := false
# "" or "random"; set before start(). tree_picks lists the node ids taken, in order.
var tree_policy := ""
var tree_picks: Array[String] = []
var _tree_rng := RandomNumberGenerator.new()
# Laps mode: how many laps the lapper runs before it fights; 0 means the course's own.
var laps_wanted := 0

# "", then won, died, stalled, boss or boss_stalled.
var outcome := ""
var ticks := 0
# One row per stage the bot entered: what it tried, for the sidecar log.
var stage_notes: Array[Dictionary] = []
# The Brindle fight, when there was one.
var boss_note := {}

var _offers: Array = []
var _gate_pick := -1
var _gate_time := 0.0
var _gate_hop := 0.0
var _stage := 0
var _fight_phase := "charge"
var _fight_target: Node3D = null
var _runup_point := Vector3.ZERO
var _runup_time := 0.0
var _slow_time := 0.0
var _detour_time := 0.0
var _detour := Vector3.ZERO
var _boost_clock := 0.0
var _waypoints: Array[Vector3] = []
var _waypoint_time := 0.0
var _vault_time := 0.0
var _vault_done := false
var _event_time := {}
var _event_skip := {}
var _wander_clock := 0.0
var _wander_heading := Vector3.FORWARD
var _committed := false
var _planned := false
var _note := {}
var _goal := ""
# Telegraph reading: instance id -> tick first seen; the ids evaded this stage.
var _seen := {}
var _evaded := {}
# The pulse ring the caps loop takes on purpose, by its centre.
var _welcome_ring_at := Vector3.INF
# Engineer plant cycle: idle, seek or mounted.
var _plant_state := "idle"
var _plant_clock := 0.0
var _plant_cool := 0.0
var _plant_face := Vector3.ZERO
var _plant_target: Node3D = null
var _boss_clock := 0.0
var _punch_seen := 0.0
var _warden_hp_at := -1.0
var _warden_kinds := {}
# The lapper's lap: climb (to the line's start), wait (for the window's timing), descend
# (down the line, off the lip, onto the core) or return (to the lift).
var _lap_phase := "climb"
var _lap_go := 0.0
var _lap_step := 0
var _lap_descent := LAP_DESCENT
# A landed drop's arrival speed, waiting LAP_SPEED_AFTER to be compared with the ball's.
var _drop_probe := {}
const LAP_SPEED_AFTER := 0.25
# The stage Warden's drop rules (warden_drop.gd), kept past the Warden's break so the
# note can read them, and its shortest telegraph seen.
var _drop_rec = null
var _min_telegraph = null
var _lap_aims := 0
var _lap_misses_at := 0
var _lap_ended_at := -1.0
var _lap_ended_kind := ""
var _lap_arrived := false
var _lap_lip := {}
var _lap_contact := {}


func _init(game_ref, policy_name: String, seed_number: int) -> void:
	game = game_ref
	policy = policy_name if policy_name in POLICIES else "skipper"
	seed_value = seed_number
	class_index = seed_number % ClassDef.all().size()
	rng.seed = hash([policy, seed_number])
	_tree_rng.seed = hash(["tree", seed_number])


# Call once the game's flow exists. Reseeding the run's stream makes each seed its own
# stage plan (events, scrap, spawns); the base seed alone would give every run of a
# policy the same map draw.
func start() -> void:
	game.ctx.rng.seed = 20260926 + seed_value * 7919
	game.player.source = source
	var events = game.events
	events.stage_entered.connect(_on_stage_entered)
	events.stage_cleared.connect(func(_s: int): _close_note())
	events.reward_offered.connect(_on_offers)
	events.reward_chosen.connect(func(_id: String): _offers = [])
	events.player_died.connect(func(): _end("died"))
	events.run_ended.connect(func(won: bool): _end("won" if won else "lost"))
	events.warden_engaged.connect(func(_s: int):
		_note_set("warden_engaged_s", snappedf(game.run.stage_time, 0.01))
		# The descent's speed is not a ram the fight can repeat; judge from here on.
		_punch_seen = float(game.flow.punch_now()))
	events.beacon_unsealed.connect(func(_s: int):
		_note_set("warden_broken_s", snappedf(game.run.stage_time, 0.01))
		if _warden_hp_at >= 0.0:
			_settle_warden_damage(0.0))
	events.event_started.connect(func(id: String): _note_add("events_joined", id))
	events.lap_bell_rung.connect(func(_at: Vector3): _note_set("bell_s", snappedf(game.run.stage_time, 0.01)))
	events.lap_completed.connect(func(lap: int, _required: int, seconds: float):
		_note_set("laps", lap)
		_note_add("lap_times", snappedf(seconds, 0.01)))
	_connect_optional("warden_drop_landed", _on_drop_landed)
	_connect_optional("warden_pulse_dodged", func(_at: Vector3, near: bool): _count("near_misses" if near else "safe_dodges"))
	events.core_gained.connect(func(source_id: String, _at: Vector3, _n: int): _note_add("cores", source_id))
	events.part_gained.connect(func(id: String, source_id: String): _note_add("parts", "%s:%s" % [source_id, id]))
	events.player_hit.connect(_on_player_hit)
	events.enemy_struck.connect(_on_enemy_struck)
	events.special_used.connect(func(_id: String, _at: Vector3): _count("specials"))
	events.mounted.connect(func(_at: Vector3, _banked: float): _count("plants"))
	events.dismounted.connect(func(v: Vector3):
		if v.length() > 0.5:
			_count("slingshots"))
	_connect_optional("boss_arena_entered", func(): _on_boss_entered())
	_connect_optional("boss_phase_changed", func(phase: int, phase_name: String): _on_boss_phase(phase, phase_name))
	_connect_optional("boss_weak_point_hit", func(point_id: String):
		if not boss_note.is_empty():
			var hits: Dictionary = boss_note["weak_point_hits"]
			hits[point_id] = int(hits.get(point_id, 0)) + 1)
	_connect_optional("boss_defeated", func(): _boss_set("defeated_s", snappedf(_boss_clock, 0.01)))
	events.scrap_lost.connect(func(amount: int, _at: Vector3, _total: int, cause: String):
		if cause == "crane":
			_boss_set("stolen", int(boss_note.get("stolen", 0)) + amount))
	if tree_policy == "random":
		_connect_optional("tree_offered", _on_tree_offered)
	game.flow.press_start()
	game.flow.choose_class(class_index)


func _on_tree_offered(_class_id: String, _depth: int, choices: Array) -> void:
	if choices.is_empty():
		return
	var choice: String = choices[_tree_rng.randi() % choices.size()]
	if game.player.tree.pick(choice):
		tree_picks.append(choice)


func _connect_optional(signal_name: String, handler: Callable) -> void:
	if game.events.has_signal(signal_name):
		game.events.connect(signal_name, handler)


func class_id() -> String:
	return game.run.class_id()


func _engineer() -> bool:
	return class_id() == "pylon_engineer"


# Kest's throw is hold-release: the bot lets go of LMB once the throw would reach its
# aim, as a player watching the landing ring would, instead of always throwing long.
func _throw_hold(aim) -> bool:
	var gauge = game.player.abilities.gauge(AbilityState.WEAPON)
	if gauge == null or not gauge.charging or not _aim_valid(aim):
		return true
	var reach: float = _flat(game.player.ball_position(), _aim_point(aim))
	var want := clampf((reach - Weapons.STICKY_THROW_MIN) / (Weapons.BASE[Weapons.STICKY_CHARGE]["range_m"] - Weapons.STICKY_THROW_MIN), 0.0, 1.0)
	return gauge.fraction() < want


# One physics tick. Returns true when the run is over.
func tick(delta: float) -> bool:
	if outcome != "":
		return true
	ticks += 1
	var flow = game.flow
	var state: String = flow.state_name()
	match state:
		"dead":
			_end("died")
			return true
		"summary":
			_end("won")
			return true
		"victory":
			source.hold = {}
			return false
		"boss":
			if _boss() == null:
				_end("boss")
				return true
	if not flow.in_play():
		source.hold = {}
		return false
	# Every stage state, the gates included: a gate the bot cannot reach (seed 5 random put
	# gate 1 behind a Spillway chute kerb) once ran a process forever, since only the
	# Warden fight had a limit. stall_state says which state ran out.
	if flow.in_stage() and game.run.stage_time > STAGE_LIMIT:
		_note_set("stall_state", state)
		_end("stalled")
		return true
	_boost_clock -= delta
	_plant_cool -= delta
	if not _drop_probe.is_empty():
		_drop_probe["wait"] -= delta
		if _drop_probe["wait"] <= 0.0:
			var ratio: float = game.player.state.velocity.length() / maxf(0.1, float(_drop_probe["speed_in"]))
			_note_add("drop_speed_ratios", snappedf(ratio, 0.01))
			_drop_probe = {}
	_punch_seen = maxf(float(flow.punch_now()), _punch_seen - PUNCH_FADE * delta)
	if trace and ticks % (Engine.physics_ticks_per_second * 2) == 0:
		var b: Vector3 = game.player.ball_position()
		print("  trace t=%.0f stage %d %s goal=%s ball=(%.0f, %.0f, %.0f) speed=%.1f hp=%.0f heft=%.2f punch=%.0f" % [game.run.stage_time,
			game.run.stage, state, _goal, b.x, b.y, b.z, game.player.planar_velocity().length(), game.run.hp, game.run.heft(), flow.punch_now()])
	if trace and state == "boss" and ticks % (Engine.physics_ticks_per_second * 2) == 0:
		var boss = _boss()
		if boss != null and is_instance_valid(boss.get("arena")) and boss.get("ship") != null:
			var b: Vector3 = game.player.ball_position()
			print("    boss phase %s %s hp %.0f; ball r %.1f above arena ground %.1f, grounded %s, body velocity %s" % [boss.phase,
				boss.state_name(), boss.hp, boss.arena.radius_of(b), b.y - boss.arena.ground(b), game.player.state.grounded,
				game.player.body().linear_velocity])
	match state:
		"stage", "beacon":
			_roam(delta)
		"gates":
			_to_gate(delta)
		"boss":
			_boss_clock += delta
			if _boss_clock > BOSS_LIMIT:
				_end("boss_stalled")
				return true
			_fight_boss(delta)
		_:
			source.hold = {}
	return outcome != ""


func _end(why: String) -> void:
	if outcome != "":
		return
	outcome = why
	_close_note()
	if not boss_note.is_empty():
		boss_note["outcome"] = why
		boss_note["seconds"] = snappedf(_boss_clock, 0.01)
		var boss = _boss()
		if boss != null:
			boss_note["phase_reached"] = boss.get("phase")
			boss_note["wall_stuns"] = boss.get("stuns")
			boss_note["clashes"] = boss.get("clashes")
	source.hold = {}


# --- bookkeeping -----------------------------------------------------------------------

func _on_stage_entered(stage: int, _retry: bool) -> void:
	_close_note()
	_stage = stage
	_offers = []
	_gate_pick = -1
	_fight_phase = "charge"
	_fight_target = null
	_slow_time = 0.0
	_detour_time = 0.0
	_waypoints = []
	_waypoint_time = 0.0
	_vault_time = 0.0
	_vault_done = false
	_event_time = {}
	_event_skip = {}
	_wander_clock = 0.0
	_committed = policy == "skipper"
	_planned = false
	_seen = {}
	_evaded = {}
	_plant_state = "idle"
	_plant_cool = 0.0
	_warden_hp_at = -1.0
	_warden_kinds = {}
	_note = {"stage": stage, "warden_engaged_s": null, "warden_fight_s": null, "warden_broken_s": null, "exit_s": null, "events_joined": [],
		"cores": [], "parts": [], "vault_tried": false, "waypoints": 0, "stuck_detours": 0, "hp_lost": 0.0, "hits": 0,
		"max_hp": game.run.max_hp, "evasions": 0, "cap_hits": 0, "magnet_stuns": 0, "plants": 0, "slingshots": 0,
		"specials": 0, "punch_short_s": 0.0, "bell_s": null, "laps": 0, "lap_times": []}
	_lap_phase = "climb"
	_lap_step = 0
	_lap_ended_at = -1.0
	_drop_probe = {}
	_drop_rec = null
	if LoopMode.mode(game.tuning) != "v2":
		_note.merge(LoopMode.tag(game.tuning))
		_note.merge({"drop_speeds": [], "drop_speed_ratios": [], "descents": [], "laps": 0, "near_misses": 0, "safe_dodges": 0, "miss_recovery_s": [], "turnaround_s": [], "bowl_ticks": 0, "stage_ticks": 0})


# A landed drop (warden_drop.gd): its arrival speed now, the ball's speed a moment later.
func _on_drop_landed(_at: Vector3, speed: float, _left: int, _segments: int) -> void:
	_note_add("drop_speeds", snappedf(speed, 0.1))
	_drop_probe = {"speed_in": speed, "wait": LAP_SPEED_AFTER}
	if policy.begins_with("lapper") and _lap_phase == "descend":
		_lap_end("land")
		_count("laps")
		if not _note.has("lands"):
			_note["lands"] = []
		_note["lands"].append({"t": snappedf(game.run.stage_time - _lap_go, 0.01), "lip": _lap_lip})
	_lap_phase = "return"


# The drop fight's own record, read off the Warden's drop rules at the stage's end.
func _note_drop() -> void:
	if _drop_rec == null or _note.is_empty():
		return
	var d: Dictionary = _drop_rec.damage
	var total: float = d["drop"] + d["gun"]
	_note["drop"] = {"windows": _drop_rec.windows, "drops_landed": _drop_rec.drops_landed, "staggers": _drop_rec.staggers,
		"core_misses": _drop_rec.misses, "gun_role": _drop_rec.gun_role, "damage_stagger_gun": snappedf(d["stagger_gun"], 0.1),
		"damage_drop": snappedf(d["drop"], 0.1), "damage_gun": snappedf(d["gun"], 0.1), "damage_outside": snappedf(d["outside"], 0.1),
		"drop_share": snappedf(d["drop"] / total, 0.001) if total > 0.0 else null,
		"min_telegraph_s": snappedf(float(_drop_rec.warden.min_pulse_telegraph), 0.01) if is_instance_valid(_drop_rec.warden) else _min_telegraph,
		"segments_left": _drop_rec.segments_left() if is_instance_valid(_drop_rec.warden) else 0}


func _note_set(key: String, value) -> void:
	if not _note.is_empty():
		_note[key] = value


func _note_add(key: String, value) -> void:
	if not _note.is_empty():
		(_note[key] as Array).append(value)


func _count(key: String, by: float = 1.0) -> void:
	var into: Dictionary = boss_note if _in_boss() else _note
	if into.is_empty():
		return
	into[key] = into.get(key, 0) + by


func _boss_set(key: String, value) -> void:
	if not boss_note.is_empty():
		boss_note[key] = value


func _boss_add(key: String, value) -> void:
	if not boss_note.is_empty():
		(boss_note[key] as Array).append(value)


func _in_boss() -> bool:
	return not boss_note.is_empty() and not boss_note.has("outcome")


func _on_player_hit(amount: float, source_id: String) -> void:
	_count("hp_lost", amount)
	_count("hits")
	var into: Dictionary = boss_note if _in_boss() else _note
	if not into.is_empty():
		if not into.has("hit_sources"):
			into["hit_sources"] = {}
		into["hit_sources"][source_id] = snappedf(float(into["hit_sources"].get(source_id, 0.0)) + amount, 0.1)


func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if _note.is_empty():
		return
	# Which strikes break the Warden: the HP it had at each strike is settled against
	# the HP it has on the next tick (or zero at its break), by the kinds that struck.
	if is_instance_valid(enemy) and enemy == game.flow.warden:
		if _warden_hp_at < 0.0:
			_warden_hp_at = float(enemy.get("hp"))
		_warden_kinds[kind] = true
	if not (kind == "slam" or kind == "stomp"):
		return
	if is_instance_valid(enemy) and enemy == game.flow.warden and enemy.has_method("contact_part") \
			and enemy.contact_part(game.player.ball_position(), kind) == "cap":
		_count("cap_hits")


func _settle_warden_damage(hp_now: float) -> void:
	var dealt := maxf(0.0, _warden_hp_at - hp_now)
	if dealt > 0.0 and not _note.is_empty() and not _warden_kinds.is_empty():
		if not _note.has("warden_damage"):
			_note["warden_damage"] = {}
		var by: Dictionary = _note["warden_damage"]
		for kind in _warden_kinds:
			by[kind] = snappedf(float(by.get(kind, 0.0)) + dealt / _warden_kinds.size(), 0.1)
	_warden_hp_at = -1.0
	_warden_kinds = {}


func _close_note() -> void:
	if _note.is_empty():
		return
	_note["exit_s"] = snappedf(game.run.stage_time, 0.01)
	_note_drop()
	_note["hp_lost"] = snappedf(float(_note["hp_lost"]), 0.1)
	_note["punch_short_s"] = snappedf(float(_note["punch_short_s"]), 0.01)
	stage_notes.append(_note)
	_note = {}


func _on_boss_entered() -> void:
	_close_note()
	_boss_clock = 0.0
	_seen = {}
	_evaded = {}
	_plant_state = "idle"
	_fight_phase = "charge"
	_fight_target = null
	boss_note = {"entered_run_s": snappedf(game.run.run_time, 0.01), "entry_heft": snappedf(game.run.heft(), 0.001),
		"entry_parts": game.run.parts.size(), "phases": [], "weak_point_hits": {}, "hp_lost": 0.0, "hits": 0,
		"evasions": 0, "plants": 0, "slingshots": 0, "specials": 0, "stolen": 0, "defeated_s": null}


func _on_boss_phase(phase: int, phase_name: String) -> void:
	_boss_add("phases", {"phase": phase, "name": phase_name, "at_s": snappedf(_boss_clock, 0.01),
		"heft": snappedf(game.run.heft(), 0.001), "hp": snappedf(game.run.hp, 0.1)})


# --- the completionist's route ----------------------------------------------------------

# Laid once the build has laid out the stage: every scrap line end to end, nearest to
# the drop first, so its hoops are rolled through too.
func _plan() -> void:
	_planned = true
	if policy != "completionist":
		return
	var terrain = game.ctx.terrain
	var spawn: Vector3 = terrain.spawn_point(_stage)
	var beacon: Vector3 = terrain.beacon_point(_stage)
	var axis := Vector2(beacon.x - spawn.x, beacon.z - spawn.z).normalized()
	var lines: Array = terrain.scrap_lines(_stage).duplicate()
	lines.sort_custom(func(a, b): return _along(a, spawn, axis) < _along(b, spawn, axis))
	var at := Vector2(spawn.x, spawn.z)
	for line in lines:
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		if at.distance_to(to) < at.distance_to(from):
			var swap := from
			from = to
			to = swap
		_waypoints.append(terrain.drop_point(from.x, from.y, 1.0))
		_waypoints.append(terrain.drop_point(to.x, to.y, 1.0))
		at = to
	_note["waypoints"] = _waypoints.size()


static func _along(line: Array, spawn: Vector3, axis: Vector2) -> float:
	var mid: Vector2 = ((line[0] as Vector2) + (line[1] as Vector2)) * 0.5
	return (mid - Vector2(spawn.x, spawn.z)).dot(axis)


# --- the roam: what to go for now ------------------------------------------------------

func _roam(delta: float) -> void:
	if not _planned:
		_plan()
	_welcome_ring_at = Vector3.INF
	var warden: Node3D = game.flow.warden if is_instance_valid(game.flow.warden) else null
	if warden != null and _warden_hp_at >= 0.0:
		_settle_warden_damage(float(warden.get("hp")))
	if warden != null:
		_note["magnet_stuns"] = maxi(int(_note.get("magnet_stuns", 0)), int(warden.get("magnet_stuns") if warden.get("magnet_stuns") != null else 0))
		if warden.get("drop") != null:
			_drop_rec = warden.drop
			if warden.min_pulse_telegraph < INF:
				_min_telegraph = snappedf(float(warden.min_pulse_telegraph), 0.01)
	if _note.has("stage_ticks"):
		_note["stage_ticks"] += 1
		var mast: Vector3 = game.ctx.terrain.beacon_point(_stage)
		if _flat(game.player.ball_position(), mast) <= Features.BOWL_OUT:
			_note["bowl_ticks"] += 1
	match policy:
		"skipper":
			_fight(warden, delta)
		"completionist":
			_completionist(warden, delta)
		"lapper", "lapper_blind":
			_lapper(warden, delta)
			var on_course: bool = game.world != null and game.world.course != null
			var phase := _goal.split(" ")[1] if _goal.begins_with("lap ") and not on_course else _goal
			if not _note.has("lap_seconds"):
				_note["lap_seconds"] = {}
			_note["lap_seconds"][phase] = snappedf(float(_note["lap_seconds"].get(phase, 0.0)) + delta, 0.01)
		_:
			_random(warden, delta)


# --- the lapper: the v3 loop's tight laps ------------------------------------------------

# Up to the fast line's start, a wait there for the window's timing, then down the line,
# off the lip and onto the core; the rebound and the lift bring it back. What it reads is
# what a player sees: the telegraph ring filling, the beam standing, the seconds since
# the last clang (the Warden's rhythm), and the ride it is on.
func _lapper(warden: Node3D, delta: float) -> void:
	# Laps mode (a course stands on this stage): the bell and the rings, then the fight.
	if game.world != null and game.world.course != null:
		_lap_or_fight(warden, delta)
		return
	var map = game.ctx.terrain.map()
	if warden == null or not map.loop_live or map.drop_lines.is_empty():
		_fight(warden, delta)
		return
	if game.world.ride != null:
		_goal = "lap ride"
		source.hold = {}
		return
	var line: Dictionary = map.drop_lines[0]
	var ball: Vector3 = game.player.ball_position()
	var mast: Vector3 = warden.global_position
	var aim = _lap_aim(warden)
	var in_bowl: bool = _flat(ball, mast) < LAP_BOWL
	match _lap_phase:
		"descend":
			var drop_rec = warden.get("drop")
			var missed: bool = drop_rec != null and int(drop_rec.misses) > _lap_misses_at
			if missed or game.run.stage_time - _lap_go > LAP_GIVE_UP:
				_lap_phase = "return"
				_count("lap_misses")
				_note_miss(warden)
				_lap_end("miss")
			else:
				_watch_lip(warden)
				_lap_descend(line, mast, aim, delta)
				return
		"climb", "wait":
			if in_bowl:
				_lap_phase = "return"
	if _lap_phase == "return":
		if not in_bowl and _flat(ball, mast) > LAP_BOWL + 10.0:
			_lap_phase = "climb"
		else:
			# No boost on the way back: a boost taken on the core's top scales the throw
			# past the lift (measured: x1.38, over the rim into the basin).
			_boost_clock = BOOST_GAP
			var drop_rec = warden.get("drop")
			if drop_rec != null and drop_rec.staggered:
				_goal = "lap gun"
				_act(ball + game.player.planar_velocity() * 0.2, warden, delta, null, false)
				if game.player.state.grounded:
					source.hold["brake_held"] = true
				return
			_goal = "lap return"
			var mouth: Vector2 = map.return_at
			_act(game.ctx.terrain.drop_point(mouth.x, mouth.y, 1.0), aim, delta, null, false)
			return
	var start: Vector2 = line["start"]
	var at: Vector3 = game.ctx.terrain.drop_point(start.x, start.y, 1.0)
	if _lap_phase == "climb" and _flat(ball, at) < LAP_REACHED:
		_lap_phase = "wait"
	if _lap_phase == "wait":
		_goal = "lap wait"
		var blind := policy == "lapper_blind"
		if blind or (game.player.planar_velocity().length() < LAP_BRAKED and _lap_ready(warden)):
			_lap_phase = "descend"
			_lap_go = game.run.stage_time
			_lap_step = 0
			_lap_aims = int(game.world.drop_aims)
			_lap_lip = {}
			_lap_arrived = false
			var drop = warden.get("drop")
			_lap_contact = drop.last_contact if drop != null else {}
			_lap_misses_at = int(drop.misses) if drop != null else 0
			if _lap_ended_at >= 0.0:
				_note_add("miss_recovery_s" if _lap_ended_kind == "miss" else "turnaround_s", snappedf(game.run.stage_time - _lap_ended_at, 0.01))
				_lap_ended_at = -1.0
			_lap_descend(line, mast, aim, delta)
			return
		_act(at, aim, delta, null, false)
		if game.player.state.grounded and _flat(ball, at) < LAP_REACHED:
			source.hold["brake_held"] = true
		return
	_goal = "lap climb"
	_act(at, aim, delta, null, false)


# The window as the ball leaves the lip, for the miss notes: seconds of window left, or
# the telegraph's share while it charges.
func _watch_lip(warden: Node3D) -> void:
	if not _lap_lip.is_empty() or int(game.world.drop_aims) == _lap_aims:
		return
	var drop = warden.get("drop")
	_lap_lip = {"t": snappedf(game.run.stage_time - _lap_go, 0.01), "speed": snappedf(game.player.state.velocity.length(), 0.1),
		"window_left": snappedf(drop.window_left(), 0.01) if drop != null else null,
		"charge": snappedf(warden.charge_fraction(), 0.01), "since_pulse": snappedf(warden.seconds_since_pulse(), 0.01)}


# Why a descent did not land: did the lip aim it, what it hit and when.
func _note_miss(warden: Node3D) -> void:
	var drop = warden.get("drop")
	var contact = drop.last_contact if drop != null and not is_same(drop.last_contact, _lap_contact) else null
	if not _note.has("misses"):
		_note["misses"] = []
	_note["misses"].append({"aimed": int(game.world.drop_aims) > _lap_aims, "lip": _lap_lip, "contact": contact})


# Down the line: its waypoints, the lip, then the mast, boosting whenever lined up.
func _lap_descend(line: Dictionary, mast: Vector3, aim, delta: float) -> void:
	var points: Array = (line["via"] as Array) + [line["at"], Vector2(mast.x, mast.z)]
	var ball: Vector3 = game.player.ball_position()
	if not _lap_arrived and _flat(ball, mast) < LAP_ARRIVED:
		_lap_arrived = true
		_lap_descent = lerpf(_lap_descent, game.run.stage_time - _lap_go, 0.6)
	while _lap_step < points.size() - 1:
		var p: Vector2 = points[_lap_step]
		var next: Vector2 = points[_lap_step + 1]
		var along: float = (Vector2(ball.x, ball.z) - p).dot((next - p).normalized())
		if Vector2(ball.x, ball.z).distance_to(p) < LAP_WAYPOINT or along > 0.0:
			_lap_step += 1
		else:
			break
	var target: Vector2 = points[_lap_step]
	_goal = "lap descend %d" % _lap_step
	_act(game.ctx.terrain.drop_point(target.x, target.y, 1.0), aim, delta, null, false)


# Leave the line's start when the Warden's published schedule (the dial over it) says
# the core will stand open for LAP_SLACK either side of the learned arrival.
func _lap_ready(warden: Node3D) -> bool:
	var drop = warden.get("drop")
	if drop == null:
		return true
	return drop.open_at(_lap_descent - LAP_SLACK) and drop.open_at(_lap_descent + LAP_SLACK)


func _lap_end(kind: String) -> void:
	_lap_ended_at = game.run.stage_time
	_lap_ended_kind = kind
	_note_add("descents", kind)


# The gun on the open core (it holds the door under `hold`), the whole Warden while it
# reels under `full`, else nothing in particular.
func _lap_aim(warden: Node3D):
	var drop = warden.get("drop")
	if drop != null and drop.staggered:
		return warden
	if warden.has_method("weak_points") and not (warden.weak_points() as Array).is_empty():
		return {"at": warden.weak_points()[0]["at"]}
	return _nearest_enemy()


func _completionist(warden: Node3D, delta: float) -> void:
	var event := _event_goal(delta)
	if not event.is_empty():
		_goal = event["goal"]
		_act(event["steer"], event.get("aim", null), delta)
		return
	if not _waypoints.is_empty():
		_waypoint_time += delta
		var ball: Vector3 = game.player.ball_position()
		if _flat(ball, _waypoints[0]) < WAYPOINT_REACHED or _waypoint_time > WAYPOINT_SECONDS:
			_waypoints.pop_front()
			_waypoint_time = 0.0
		if not _waypoints.is_empty():
			_goal = "waypoint %d" % _waypoints.size()
			_act(_waypoints[0], _nearest_enemy(), delta)
			return
	var vault: Node3D = _vault()
	if vault != null and not _vault_done:
		_note["vault_tried"] = true
		_vault_time += delta
		if _vault_time > VAULT_SECONDS:
			_vault_done = true
		else:
			_fight(vault, delta)
			return
	_lap_or_fight(warden, delta)


# Laps mode: the bell, then the course's next ring, until the laps wanted are in; then
# the fight. With no course (any other mode, or a later stage) it is the fight.
func _lap_or_fight(warden: Node3D, delta: float) -> void:
	var course = game.world.course if game.world != null else null
	var wanted: int = laps_wanted if laps_wanted > 0 else (course.required if course != null else 0)
	if course == null or not game.flow.sealed or course.laps >= wanted:
		_fight(warden, delta)
		return
	var ring: Vector3 = course.target()
	_goal = "lap %d ring %d" % [course.laps + 1, course.next_ring] if course.bell_rung else "bell"
	# The ring after the lift's approach is on the shelf: ride the lift to it, as a
	# player rolls on through the approach ring into the lift's mouth.
	var lift: Vector2 = game.ctx.terrain.map().return_at
	var ball: Vector3 = game.player.ball_position()
	if course.bell_rung and course.next_ring == 1 and Vector2(ball.x, ball.z).distance_to(lift) < LIFT_SEEK:
		ring = Vector3(lift.x, 0.0, lift.y)
		_goal = "lap %d lift" % (course.laps + 1)
	_act(game.ctx.terrain.drop_point(ring.x, ring.z, 1.0), _nearest_enemy(), delta)


func _random(warden: Node3D, delta: float) -> void:
	var ball: Vector3 = game.player.ball_position()
	if warden != null and not _committed:
		_committed = _flat(ball, warden.global_position) < WANDER_COMMIT_DISTANCE or game.run.stage_time > WANDER_COMMIT_TIME
	if _committed or warden == null:
		_fight(warden, delta)
		return
	_wander_clock -= delta
	if _wander_clock <= 0.0:
		_wander_clock = rng.randf_range(WANDER_GAP.x, WANDER_GAP.y)
		var to_beacon: Vector3 = game.ctx.terrain.beacon_point(_stage) - ball
		var base := atan2(to_beacon.x, to_beacon.z)
		var angle := base + rng.randfn(0.0, WANDER_SPREAD)
		_wander_heading = Vector3(sin(angle), 0.0, cos(angle))
		if rng.randf() < 0.3:
			source.press["jump_pressed"] = true
	_goal = "wander"
	_act(ball + _wander_heading * 30.0, _nearest_enemy(), delta)


# The stage's participatory event, when the completionist should be on it: its ring
# while armed, then the event's own target while live. Empty when there is none.
func _event_goal(delta: float) -> Dictionary:
	var world = game.world
	if world == null or world.events == null:
		return {}
	for offer in world.events.offers:
		var id: String = offer["id"]
		if _event_skip.has(id):
			continue
		var phase: int = offer["phase"]
		var model = offer["model"]
		if phase == EventDirector.LIVE:
			return {"goal": "live " + id, "steer": _live_target(id, model), "aim": _nearest_enemy()}
		if phase == EventDirector.ANNOUNCED or phase == EventDirector.ARMED:
			if game.run.stage_time > EVENT_LATEST:
				continue
			_event_time[id] = float(_event_time.get(id, 0.0)) + delta
			if _event_time[id] > EVENT_PURSUIT_SECONDS:
				_event_skip[id] = true
				continue
			var ring: Vector2 = model.ring
			return {"goal": "ring " + id, "steer": game.ctx.terrain.drop_point(ring.x, ring.y, 1.0), "aim": _nearest_enemy()}
		if phase == EventDirector.COOLDOWN:
			# One attempt each: a lost event is not chased round again.
			_event_skip[id] = true
	return {}


func _live_target(id: String, model) -> Vector3:
	var ball: Vector3 = game.player.ball_position()
	match id:
		"scrap_stampede":
			return model.hauler_position()
		"surge_run":
			var next: int = clampi(model.next_gate, 0, model.gates.size() - 1)
			var g: Vector2 = model.gates[next]
			return game.ctx.terrain.drop_point(g.x, g.y, 1.0)
		"hold_the_relay":
			var relay: Vector2 = model.relay
			var out := Vector2(ball.x - relay.x, ball.z - relay.y)
			if out.length() < 0.5:
				out = Vector2(1.0, 0.0)
			var around := out.normalized().rotated(0.7) * 12.0
			return game.ctx.terrain.drop_point(relay.x + around.x, relay.y + around.y, 1.0)
	var ring: Vector2 = model.ring
	return game.ctx.terrain.drop_point(ring.x, ring.y, 1.0)


# --- fighting a plated lock ------------------------------------------------------------

# Combat's plating_of first: it subtracts shred, so a stripped Warden reads as rammable.
func _plating(target: Node3D) -> float:
	var spawner = game.ctx.spawner
	if spawner != null and spawner.has_method("plating_of"):
		return float(spawner.plating_of(target))
	if target.has_method("plating_now"):
		return float(target.plating_now())
	return 0.0


# Ram laps with the gun on it when punch reaches the plating; the lock's weak point when
# it does not.
func _fight(target: Node3D, delta: float) -> void:
	_welcome_ring_at = Vector3.INF
	if target == null or not is_instance_valid(target):
		# No lock stands (an unsealed stage): roll into the beacon's ring.
		_goal = "beacon"
		_act(game.flow.beacon.global_position, _nearest_enemy(), delta)
		return
	if target != _fight_target:
		_fight_target = target
		_fight_phase = "charge"
	# The bot's own commitment to the Warden: a completionist or a wanderer can wake it
	# (warden_engaged) on the way past long before it turns to fight.
	if target == game.flow.warden and _note.get("warden_fight_s") == null:
		_note["warden_fight_s"] = snappedf(game.run.stage_time, 0.01)
	var short: bool = _punch_seen < _plating(target)
	if short:
		_note["punch_short_s"] = float(_note.get("punch_short_s", 0.0)) + delta
	_note_shred(target, delta)
	var caps: bool = target.has_method("cap_points") and not (target.cap_points() as Array).is_empty()
	if caps and short:
		_goal = "caps %s" % target.get("kind")
		_cap_loop(target, delta)
		return
	_goal = "fight %s %s%s" % [target.get("kind"), _fight_phase, " short" if short else ""]
	_ram_laps(target, _aim_node(target, short), delta)


# How far the fight stripped the Warden: the peak share of its plating shred away, and
# the seconds spent with at least half of it gone.
func _note_shred(target: Node3D, delta: float) -> void:
	var spawner = game.ctx.spawner
	if target != game.flow.warden or spawner == null or not spawner.has_method("shred_of"):
		return
	var plating: float = float(target.get("plating"))
	if plating <= 0.0:
		return
	var share: float = spawner.shred_of(target) / plating
	_note["shred_peak"] = snappedf(maxf(float(_note.get("shred_peak", 0.0)), share), 0.01)
	if share >= 0.5:
		_note["stripped_half_s"] = snappedf(float(_note.get("stripped_half_s", 0.0)) + delta, 0.01)


func _ram_laps(target: Node3D, aim, delta: float) -> void:
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = target.global_position
	var distance := _flat(ball, at)
	match _fight_phase:
		"charge":
			if distance < CHARGE_CLOSE:
				_fight_phase = "runup"
				_runup_time = 0.0
				var away := Vector3(ball.x - at.x, 0.0, ball.z - at.z)
				if away.length() < 0.5:
					away = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
				away = away.normalized().rotated(Vector3.UP, rng.randf_range(-0.7, 0.7))
				_runup_point = _ground_point(at.x + away.x * RUNUP, at.z + away.z * RUNUP)
		"runup":
			_runup_time += delta
			if _flat(ball, _runup_point) < 4.0 or _runup_time > RUNUP_SECONDS:
				_fight_phase = "charge"
	var steer: Vector3 = at if _fight_phase == "charge" else _runup_point
	_act(steer, aim, delta, target)


# Slams beside a caps Warden: a slam landing within 2.6 m of a cap meets plating 0.
# The bot rolls up the radial line of the cap nearest it, so it lands beside that cap,
# jumps when it touches, and slams only while beside the body: a ball resting on top of
# an enemy never reads grounded, so a slam begun there would not land. Hugging the
# Warden also takes its pulse for height, so its core ring is welcome while HP is
# above PULSE_HP_SHARE of max.
func _cap_loop(target: Node3D, delta: float) -> void:
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = target.global_position
	# The pulse costs 10 HP; a sensible player takes it for height only while healthy.
	_welcome_ring_at = at if game.run.hp > PULSE_HP_SHARE * game.run.max_hp else Vector3.INF
	var from_ball := Vector3(ball.x - at.x, 0.0, ball.z - at.z).normalized()
	var line := from_ball
	var best := -INF
	for cap in target.cap_points():
		var dir := Vector3(cap.x - at.x, 0.0, cap.z - at.z).normalized()
		if dir.dot(from_ball) > best:
			best = dir.dot(from_ball)
			line = dir
	var d := _flat(ball, at)
	# From outside, come in along the cap's line; beside it, press into the body.
	var steer: Vector3 = at + line * CAP_BESIDE if d > CAP_JUMP + 2.0 else at
	_act(steer, target, delta, target)
	var v: Vector3 = game.player.state.velocity
	if game.player.state.grounded:
		if d < CAP_JUMP:
			source.press["jump_pressed"] = true
	elif d > CAP_INSIDE and d < CAP_JUMP + 1.0 and v.y < 2.0:
		source.hold["brake_held"] = true


# What to point the gun at: the weak point when punch is short and one shows (the
# magnet while it tugs), else the body.
func _aim_node(target: Node3D, short: bool):
	if short and target.has_method("weak_points") and not (target.weak_points() as Array).is_empty():
		return {"at": target.weak_points()[0]["at"]}
	return target


# --- the boss: Brindle's Requisition in the Slag Bowl ----------------------------------

func _boss():
	var ctx = game.ctx
	var boss = ctx.get("boss") if "boss" in ctx else null
	if boss == null and ctx.has_meta("boss"):
		boss = ctx.get_meta("boss")
	if boss == null or not is_instance_valid(boss) or not boss.has_method("enter_arena"):
		return null
	return boss


# Phase 1: guns on the live crane magnets from the orbit, chasing any stolen scrap.
# Phase 2: up a ramp and slam a vent cap when punch is short of the hull, else ram.
# Phase 3: bait charges into the rim wall and ram the stunned ship; clash head-on when
# punch reaches the clash threshold. The chase: run the scooter down.
func _fight_boss(delta: float) -> void:
	var boss = _boss()
	if boss_note.is_empty():
		_on_boss_entered()
	var ship = boss.get("ship")
	var arena = boss.get("arena")
	if not boss.has_method("active") or not boss.active() or ship == null or not is_instance_valid(arena):
		_goal = "boss wait"
		_act(game.player.ball_position() + game.player.planar_velocity(), null, delta)
		return
	var ball: Vector3 = game.player.ball_position()
	var hull: Node3D = ship.hull
	var punch: float = _punch_seen
	var phase: int = int(boss.phase)
	var scooter = boss.get("scooter")
	if scooter != null and is_instance_valid(scooter):
		_goal = "boss scooter"
		var lead: Vector3 = scooter.global_position
		_act(lead, scooter, delta, scooter)
		return
	var pickup := _nearest_pickup(boss, ball)
	match phase:
		1:
			var magnet := _live_part(boss, ship.magnets, ball)
			if pickup != Vector3.INF:
				_goal = "boss pickup"
				_act(pickup, magnet if magnet != null else hull, delta)
			elif punch >= _plating(hull):
				_goal = "boss ram"
				_ram_laps(hull, magnet if magnet != null else hull, delta)
			else:
				_goal = "boss magnets"
				_act(_orbit_point(arena, ball, BOSS_ORBIT), magnet if magnet != null else hull, delta)
		2:
			if punch >= _plating(hull):
				_goal = "boss ram"
				_ram_laps(hull, hull, delta)
			else:
				_ramp_to_cap(boss, arena, ship, delta)
		_:
			if boss.has_method("stunned") and boss.stunned():
				_goal = "boss stunned"
				_ram_laps(hull, hull, delta)
			elif boss.has_method("charging") and boss.charging() and punch >= float(boss.get("clash_punch") if boss.get("clash_punch") != null else 150.0):
				_goal = "boss clash"
				_act(hull.global_position, hull, delta, hull, false)
			else:
				_goal = "boss bait"
				_act(arena.point_at(arena.angle_of(ball), BAIT_RADIUS), hull, delta, hull)


func _live_part(boss, parts: Array, ball: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for part in parts:
		if not is_instance_valid(part):
			continue
		if boss.has_method("target_live") and not boss.target_live(part):
			continue
		var d := ball.distance_to(part.global_position)
		if d < best_d:
			best_d = d
			best = part
	return best


func _nearest_pickup(boss, ball: Vector3) -> Vector3:
	if not boss.has_method("pickups_left"):
		return Vector3.INF
	var best := Vector3.INF
	var best_d := PICKUP_CHASE
	for p in boss.pickups_left():
		var at: Vector3 = p["at"]
		var d := _flat(ball, at)
		if d < best_d:
			best_d = d
			best = at
	return best


# A point on the circle of radius r, a little ahead of the ball in its travel.
func _orbit_point(arena, ball: Vector3, r: float) -> Vector3:
	return arena.point_at(arena.angle_of(ball) + 0.5, r)


# Up whichever ramp the ship is passing, a jump off its top, and a slam onto the cap
# under the ball. Waits at the ramp's foot, guns on the hull, while the ship is away.
func _ramp_to_cap(boss, arena, ship, delta: float) -> void:
	var ball: Vector3 = game.player.ball_position()
	var cap := _live_part(boss, ship.caps, ball)
	var hull: Node3D = ship.hull
	if cap != null and not game.player.state.grounded:
		var over := _flat(ball, cap.global_position) <= CAP_REACH and ball.y - cap.global_position.y >= CAP_ABOVE
		_goal = "boss cap air"
		_act(cap.global_position, cap, delta, cap)
		if over:
			source.hold["brake_held"] = true
		return
	var ship_angle: float = arena.angle_of(hull.global_position)
	var ramp := 0.0
	var gap := INF
	for a in RAMP_ANGLES:
		var g := absf(wrapf(ship_angle - deg_to_rad(a), -PI, PI))
		if g < gap:
			gap = g
			ramp = deg_to_rad(a)
	var r: float = arena.radius_of(ball)
	var on_ramp: bool = absf(wrapf(arena.angle_of(ball) - ramp, -PI, PI)) < 0.2
	if gap < RAMP_WINDOW and on_ramp and r < RAMP_BOTTOM + 3.0:
		_goal = "boss ramp climb"
		_act(arena.point_at(ramp, RAMP_PAST), cap if cap != null else hull, delta, hull)
		if r < RAMP_JUMP and game.player.state.grounded:
			source.press["jump_pressed"] = true
		return
	_goal = "boss ramp foot"
	_act(arena.point_at(ramp, RAMP_BOTTOM), hull, delta, hull)


# --- the gates -------------------------------------------------------------------------

func _on_offers(offers: Array) -> void:
	_offers = offers
	_gate_pick = _choose_gate(offers)
	_gate_time = 0.0
	_gate_hop = 0.0


func _choose_gate(offers: Array) -> int:
	if offers.is_empty():
		return -1
	match policy:
		"skipper", "lapper", "lapper_blind":
			return 0
		"completionist":
			var best := 0
			var best_score := -1.0
			for i in offers.size():
				var o: Dictionary = offers[i]
				var score := float(o.get("tier", 1)) + (10.0 if String(o.get("synergy", "")) != "" else 0.0) \
					+ (0.5 if String(o.get("mark", "")) != "" else 0.0)
				if score > best_score:
					best_score = score
					best = i
			return best
	return rng.randi_range(0, offers.size() - 1)


func _to_gate(delta: float) -> void:
	_goal = "gate %d" % _gate_pick
	if _offers.is_empty() or _gate_pick < 0:
		source.hold = {"move": Vector2(0.0, 1.0)}
		return
	var offer: Dictionary = _offers[mini(_gate_pick, _offers.size() - 1)]
	var at: Vector3 = offer["at"]
	var facing: Vector3 = offer["facing"]
	var rel: Vector3 = game.player.ball_position() - at
	var along := rel.dot(facing)
	var side := (rel - facing * along).length()
	# Lined up behind the arch: roll through it. Otherwise swing round behind it first.
	var target := at - facing * 9.0
	if side < 2.5 and along < 1.0:
		target = at + facing * 10.0
	# A gate still untaken after GATE_HOP_SECONDS has something on its line (a kerb, a
	# bench): hop while rolling at it, as a player clears a low lip.
	_gate_time += delta
	_gate_hop -= delta
	if _gate_time > GATE_HOP_SECONDS and _gate_hop <= 0.0 and game.player.state.grounded and along < 0.0 and along > -14.0:
		_gate_hop = GATE_HOP_EVERY
		source.press["jump_pressed"] = true
	if trace and ticks % (Engine.physics_ticks_per_second * 2) == 0:
		var ball: Vector3 = game.player.ball_position()
		print("    gate %d at=(%.1f, %.1f, %.1f) facing=(%.2f, %.2f, %.2f) ball=(%.1f, %.1f, %.1f) along=%.1f side=%.1f dy=%.1f ground=%.1f target=(%.1f, %.1f, %.1f)"
			% [_gate_pick, at.x, at.y, at.z, facing.x, facing.y, facing.z, ball.x, ball.y, ball.z, along, side, rel.y,
				game.ctx.terrain.height(ball.x, ball.z), target.x, target.y, target.z])
	_act(target, null, delta)


# --- acting: telegraphs first, then the class kit, then the stick --------------------

# steer is where the goal wants to go, aim what to look and shoot at (a Node3D, a
# {"at": Vector3} point or null), fight the lock this is about (for plants and
# specials). evade false rolls straight on, as a clash does.
func _act(steer: Vector3, aim, delta: float, fight: Node3D = null, evade := true) -> void:
	var player = game.player
	if player.kit.mounted:
		_turret(aim, delta)
		return
	if _plant_state == "mounted":
		_plant_state = "idle"
	var threats := _threats() if evade else []
	if not threats.is_empty():
		for h in threats:
			if not _evaded.has(h.get_instance_id()):
				_evaded[h.get_instance_id()] = true
				_count("evasions")
		var escape := _escape(threats, steer)
		_plant_state = "idle" if _plant_state == "seek" else _plant_state
		_specials(fight, true)
		_drive(escape, aim, delta)
		return
	if _engineer() and fight != null and is_instance_valid(fight):
		var planted := _plant(fight, delta)
		if planted != Vector3.INF:
			steer = planted
	_specials(fight, false)
	_drive(steer, aim, delta)


# Every committed telegraph the ball is in, or will be within PREDICT, among those seen
# for at least REACTION seconds.
func _threats() -> Array:
	var ball: Vector3 = game.player.ball_position()
	var ahead: Vector3 = ball + game.player.state.velocity * PREDICT
	var out: Array = []
	var live := {}
	for h in _hazards():
		var id: int = h.get_instance_id()
		live[id] = true
		if not _seen.has(id):
			_seen[id] = ticks
			continue
		if float(ticks - int(_seen[id])) / float(Engine.physics_ticks_per_second) < REACTION:
			continue
		if _welcome_ring_at != Vector3.INF and h.get("center") != null and _flat(h.center, _welcome_ring_at) < 1.0:
			continue
		if h.contains(ball) or h.contains(ahead):
			out.append(h)
	if _seen.size() > 64:
		for id in _seen.keys():
			if not live.has(id):
				_seen.erase(id)
	return out


# The telegraphs a player can see: combat's rings and lanes under the game root (not
# the player's own amber ones, not fields wider than FIELD_RADIUS) and the boss's hazards.
func _hazards() -> Array:
	var out: Array = []
	for child in game.get_children():
		if child.get_script() != TelegraphScript or child.is_queued_for_deletion():
			continue
		if child.color == Palette.AMBER:
			continue
		if child.shape == TelegraphScript.Shape.RING and child.radius > FIELD_RADIUS:
			continue
		out.append(child)
	var boss = _boss() if game.flow.state_name() == "boss" else null
	if boss != null and boss.has_method("active_hazards"):
		for h in boss.active_hazards():
			if is_instance_valid(h) and h.has_method("contains"):
				out.append(h)
	return out


# The nearest spot outside every threat, preferring the ball's line and the goal.
func _escape(threats: Array, steer: Vector3) -> Vector3:
	var ball: Vector3 = game.player.ball_position()
	var v: Vector3 = game.player.planar_velocity()
	var line := Vector3(v.x, 0.0, v.z).normalized() if v.length() > 1.0 else Vector3.ZERO
	var goal := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z).normalized()
	for reach in ESCAPE_REACH:
		var best := Vector3.INF
		var best_score := -INF
		for i in ESCAPE_DIRECTIONS:
			var angle := TAU * i / ESCAPE_DIRECTIONS
			var dir := Vector3(sin(angle), 0.0, cos(angle))
			var at := _ground_point(ball.x + dir.x * reach, ball.z + dir.z * reach)
			var safe := true
			for h in threats:
				if h.contains(at):
					safe = false
					break
			if not safe:
				continue
			var score := dir.dot(line) + 0.7 * dir.dot(goal)
			if score > best_score:
				best_score = score
				best = ball + dir * (reach + 6.0)
		if best != Vector3.INF:
			return best
	# Nowhere safe in reach: keep the line and jump, which clears a low ring's edge.
	source.press["jump_pressed"] = true
	return ball + (line if line != Vector3.ZERO else goal) * 12.0


func _ground_point(x: float, z: float) -> Vector3:
	var boss = _boss() if game.flow.state_name() == "boss" else null
	if boss != null and is_instance_valid(boss.get("arena")) and boss.arena.has_method("ground"):
		var p := Vector3(x, 0.0, z)
		return Vector3(x, boss.arena.ground(p) + 1.0, z)
	return game.ctx.terrain.drop_point(x, z, 1.0)


# The engineer's plant cycle. Returns the face to roll to while seeking, else INF.
func _plant(fight: Node3D, delta: float) -> Vector3:
	var ball: Vector3 = game.player.ball_position()
	match _plant_state:
		"idle":
			if _plant_cool > 0.0 or ball.distance_to(fight.global_position) > PLANT_RANGE:
				return Vector3.INF
			var face := _find_face(fight)
			if face == Vector3.INF:
				_plant_cool = 2.0
				return Vector3.INF
			_plant_face = face
			_plant_target = fight
			_plant_state = "seek"
			_plant_clock = 0.0
			return face
		"seek":
			_plant_clock += delta
			if _plant_clock > PLANT_TIMEOUT:
				_plant_state = "idle"
				_plant_cool = PLANT_EVERY
				return Vector3.INF
			if ball.distance_to(_plant_face) < PLANT_REACH:
				source.press["mount_pressed"] = true
			return _plant_face
	return Vector3.INF


# Mounted: turret on the aim, then slingshot off toward it.
func _turret(aim, delta: float) -> void:
	if _plant_state != "mounted":
		_plant_state = "mounted"
		_plant_clock = 0.0
	_plant_clock += delta
	var ball: Vector3 = game.player.ball_position()
	var look_at: Vector3 = _aim_point(aim) if _aim_valid(aim) else ball + game.camera.yaw_basis() * Vector3.FORWARD
	_look(ball, look_at, _aim_valid(aim), delta)
	source.hold = {"fire_held": true}
	var threatened := false
	for h in _threats():
		threatened = true
	if _plant_clock > TURRET_SECONDS or threatened or not _aim_valid(aim):
		source.press["jump_pressed"] = true
		_plant_state = "idle"
		_plant_cool = PLANT_EVERY


# A steep face (a pylon can bite: |normal.y| < FACE_TILT) within PLANT_SEARCH, the one
# closest to the ball's side of the fight.
func _find_face(fight: Node3D) -> Vector3:
	var space = game.get_world_3d().direct_space_state
	var ball: Vector3 = game.player.ball_position()
	var to_fight := Vector3(fight.global_position.x - ball.x, 0.0, fight.global_position.z - ball.z).normalized()
	var best := Vector3.INF
	var best_score := INF
	for i in 16:
		var angle := TAU * i / 16.0
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var from := ball + Vector3.UP * 0.3
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * PLANT_SEARCH, 1))
		if hit.is_empty():
			continue
		var n: Vector3 = hit["normal"]
		if absf(n.y) >= FACE_TILT:
			continue
		var score: float = ball.distance_to(hit["position"]) - 6.0 * dir.dot(to_fight)
		if score < best_score:
			best_score = score
			best = hit["position"]
	return best


func _specials(fight: Node3D, pressed_by_threat: bool) -> void:
	var ball: Vector3 = game.player.ball_position()
	var near := 0
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if node is Node3D and is_instance_valid(node) and ball.distance_to(node.global_position) < CROWD_RADIUS:
			if not (node.has_method("is_dead") and node.is_dead()):
				near += 1
	var close: bool = fight != null and is_instance_valid(fight) and ball.distance_to(fight.global_position) < CLOSE_FIGHT
	if near >= CROWD or close or (pressed_by_threat and near >= 1):
		source.press["special_pressed"] = true


# --- the hands: stick, mouse and buttons -----------------------------------------------

# Rolls toward steer and looks at aim (or along the way when there is nothing to aim
# at). The stick is set in the camera's frame, as a person's WASD is.
func _drive(steer: Vector3, aim, delta: float) -> void:
	var player = game.player
	var ball: Vector3 = player.ball_position()
	var speed: float = player.planar_velocity().length()
	if speed < STUCK_SPEED and player.state.grounded:
		_slow_time += delta
	else:
		_slow_time = 0.0
	if _slow_time > STUCK_SECONDS and _detour_time <= 0.0:
		_slow_time = 0.0
		_detour_time = DETOUR_SECONDS
		var to := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z).normalized()
		_detour = to.rotated(Vector3.UP, PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0))
		source.press["jump_pressed"] = true
		_count("stuck_detours")
	var heading := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z)
	if _detour_time > 0.0:
		_detour_time -= delta
		heading = _detour
	elif player.state.grounded:
		heading = _around_walls(ball, heading)
	var hold := {"fire_held": _throw_hold(aim)}
	var look_at: Vector3 = ball + heading
	var aiming := _aim_valid(aim)
	if aiming:
		look_at = _aim_point(aim)
	_look(ball, look_at, aiming, delta)
	var yaw: float = game.camera.yaw
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	if heading.length() > 0.3:
		var dir := heading.normalized()
		# Steer the velocity, not the ball: push toward the change that turns the current
		# velocity onto the target at the same speed, so a fast ball does not orbit it.
		var v: Vector3 = player.planar_velocity()
		v.y = 0.0
		var change := dir * maxf(v.length(), 12.0) - v
		var want := dir if change.length() < 0.5 else change.normalized()
		hold["move"] = Vector2(want.dot(right), want.dot(forward)).normalized()
		var lined: float = v.normalized().dot(dir) if v.length() > 0.5 else 1.0
		# No brake-carving: brake is also the slam key, and a carve held over a bump
		# becomes a slam that plants the ball (seen on the Slag Bowl's bank).
		if _boost_clock <= 0.0 and lined > 0.9 and player.state.grounded:
			_boost_clock = BOOST_GAP
			source.press["boost_pressed"] = true
	source.hold = hold


# A wall (a face steeper than WALL_TILT) within WALL_REACH on the way is rolled around:
# the heading turns to the nearest free bearing, as a player steers round a post.
func _around_walls(ball: Vector3, heading: Vector3) -> Vector3:
	if heading.length() < 0.3:
		return heading
	var space = game.get_world_3d().direct_space_state
	var dir := heading.normalized()
	var from := ball + Vector3.UP * 0.2
	for turn in WALL_TURNS:
		var probe := dir.rotated(Vector3.UP, turn)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + probe * WALL_REACH, 1))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) >= WALL_TILT:
			if turn != 0.0:
				_count("wall_turns", 1.0 / Engine.physics_ticks_per_second)
			return probe * heading.length()
	return heading


func _look(ball: Vector3, point: Vector3, pitch_to: bool, delta: float) -> void:
	var cam = game.camera
	var flat := Vector3(point.x - ball.x, 0.0, point.z - ball.z)
	var dyaw := 0.0
	if flat.length() > 0.3:
		var want := atan2(-flat.x, -flat.z)
		dyaw = clampf(wrapf(want - cam.yaw, -PI, PI), -TURN_RATE * delta, TURN_RATE * delta)
	var want_pitch := -0.30
	if pitch_to and flat.length() > 0.5:
		var pivot := ball + Vector3.UP * 0.8
		want_pitch = clampf(atan2(point.y - pivot.y, flat.length()), -1.2, 0.5)
	var dpitch := clampf(want_pitch - cam.pitch, -TURN_RATE * delta, TURN_RATE * delta)
	# camera.look takes mouse pixels: yaw -= x * s, pitch -= y * s.
	cam.look(Vector2(-dyaw / SENSITIVITY, -dpitch / SENSITIVITY))


static func _aim_valid(aim) -> bool:
	if aim is Dictionary:
		return aim.has("at")
	return aim != null and is_instance_valid(aim)


func _aim_point(aim) -> Vector3:
	if aim is Dictionary:
		return aim["at"]
	var target: Node3D = aim
	return target.global_position + Vector3.UP * 1.2


func _nearest_enemy() -> Node3D:
	var ball: Vector3 = game.player.ball_position()
	var best: Node3D = null
	var best_d := AIM_REACH
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		var d := ball.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _vault() -> Node3D:
	var world = game.world
	if world == null or world.vault == null or not is_instance_valid(world.vault):
		return null
	return world.vault


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# The sidecar record: who drove, what happened, how long it took.
func record(wall_seconds: float) -> Dictionary:
	return {
		"run_id": game.run.run_id, "policy": policy, "seed": seed_value, "class": class_id(),
		"outcome": outcome, "stage_reached": game.run.stage, "ticks": ticks,
		"game_seconds": snappedf(float(ticks) / float(Engine.physics_ticks_per_second), 0.01),
		"wall_seconds": snappedf(wall_seconds, 0.01), "stages": stage_notes,
		"boss": boss_note if not boss_note.is_empty() else null,
		"reaction_s": REACTION, "loop_mode": LoopMode.mode(game.tuning), "gun_role": LoopMode.gun_role(game.tuning),
	}
