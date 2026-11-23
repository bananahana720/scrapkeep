extends SceneTree

# PE-0 (design-v3/PILOT-CLIPS.md sections 1.1, 3, 5 and 8): the clip router's policy on
# synthetic clips, and the mecha motion code on a fixture cockpit.
#
# Routing: the test first strips Sable's animator to the seven kept clips, so it does not depend
# on whether Sable has shipped all 18. The eleven new names are then copies of drop_land cut to
# Sable's end frames (tests/support/pilot_clip_trigger.gd), the way the policy fixture in
# pilot_reactions_test duplicates drop_land. It proves the stop-and-reset fallback with
# one warning, the base hand-off, the ride base, the chain priorities, the one-slot queue, the
# miss cut-in, the argument filter and a five-argument signal reaching react.
#
# Mecha motion: a fixture Pod with the cockpit control empties shows each control's throw at
# the contact time and its return, the trigger's rate limit, the pedal kick, the lap bar haul,
# the Cannon's lattice fold, one machinery node per fact kind, one SKIP line per missing node,
# and no light or material_override anywhere under the Pod.
#
# Expected checks: EXPECTED below; any other count fails, so an empty run cannot pass.

const Game := preload("res://src/game.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Reactions := preload("res://src/presentation/pilot_reactions.gd")
const Trigger := preload("res://tests/support/pilot_clip_trigger.gd")
const T := preload("res://tests/support/t.gd")
const MECHA_PATH := "res://src/presentation/mecha_motion.gd"

const CLASS_ID := "pylon_engineer"
const EXPECTED := 91

var _t := T.new("pilot_clips_policy_test")
var _phase := "idle"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	await process_frame
	var hero = game.presentation.hero_assets
	var player = game.player
	player.fit_class(ClassDef.by_id(CLASS_ID))
	hero._process(0.0)
	var rec: Dictionary = hero.shell_of(player)
	if not _t.check("the pilot is fitted with an animator", rec.has("animator") and is_instance_valid(rec.get("animator"))):
		_done(game)
		return
	player.set_piece_phase = func() -> String: return _phase
	Trigger.strip_to_kept(rec.animator)
	_fallback(hero, player, rec)
	Trigger.add_synthetic_clips(rec.animator, CLASS_ID)
	hero._process(20.0)
	_base(hero, player, rec, game.events)
	_ride(hero, player, rec, game.events)
	_chain(hero, player, rec, game.events)
	_queue(hero, player, rec, game.events)
	_filter(hero, player, rec, game.events)
	_mecha()
	_done(game)


func _done(game) -> void:
	_t.eq("stated check count", _t.checks + 1, EXPECTED)
	game.queue_free()
	quit(_t.verdict())


func _playing(rec: Dictionary, clip: String) -> bool:
	var animator: AnimationPlayer = rec.animator
	return animator.is_playing() and animator.current_animation == clip


# The stripped GLB has no idle_loop: a clip end stops and resets, and warns once for the pilot.
func _fallback(hero, player, rec: Dictionary) -> void:
	var animator: AnimationPlayer = rec.animator
	_t.check("the stripped GLB lacks idle_loop", not animator.has_animation("idle_loop"))
	_t.check("a clip the GLB lacks (smash) is refused", not hero.react(player, "slammed", [Vector3.ZERO, 30.0, 1.0]))
	_t.check("near_miss plays phew", hero.react(player, "near_miss"))
	Trigger.finish(rec)
	# The clip end now eases to rest over BASE_BLEND through the runtime rest clip, then stops.
	_t.check("without idle_loop the clip end eases to the rest clip", _playing(rec, "runtime/rest_pose") and rec.reaction == "")
	Trigger.finish(rec)
	_t.check("without idle_loop the clip end stops the animator", not animator.is_playing() and rec.reaction == "")
	_t.check("without idle_loop the bones are reset to rest", Trigger.bones_at_rest(rec.pilot))
	hero._process(20.0)
	hero.react(player, "player_hit")
	Trigger.finish(rec)
	var keys: Array = hero._warned.keys().filter(func(k): return String(k).begins_with("pilot_base:"))
	_t.eq("one fallback warning for the pilot after two clip ends", keys, ["pilot_base:" + CLASS_ID])


func _base(hero, player, rec: Dictionary, events) -> void:
	hero._to_base(rec)
	_t.check("the base is idle_loop after the synthetic clips", _playing(rec, "idle_loop"))
	_t.eq("the idle base sits at priority -1", int(rec.priority), -1)
	_t.check("idle_loop loops", rec.animator.get_animation("idle_loop").loop_mode != Animation.LOOP_NONE)
	events.near_miss.emit("chaser", Vector3.ZERO)
	_t.check("near_miss cuts into the idle base", _playing(rec, "phew") and rec.reaction == "phew")
	_t.near("phew eases in over 0.08 s", float(rec.blend), 0.08)
	Trigger.finish(rec)
	_t.check("a one-shot hands back to idle_loop", _playing(rec, "idle_loop") and rec.reaction == "")
	_t.near("the hand-off blends over 0.1 s", float(rec.blend), Reactions.BASE_BLEND)
	events.player_hit.emit(1.0, "test")
	_t.check("player_hit plays wince", _playing(rec, "wince"))
	_t.near("wince cuts in with no blend", float(rec.blend), 0.0)
	Trigger.finish(rec)
	hero._process(20.0)


func _ride(hero, player, rec: Dictionary, events) -> void:
	_phase = "windup"
	events.ultimate_started.emit("ult_default", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)
	_t.check("five-argument ultimate_started reaches react (ult_windup)", _playing(rec, "ult_windup") and rec.reaction == "ult_windup")
	_t.eq("ult_windup at priority 70", int(rec.priority), 70)
	Trigger.finish(rec)
	_t.check("ult_windup ends on the ride base", _playing(rec, "ult_ride_loop") and rec.reaction == "")
	_t.eq("the ride base sits at priority 64", int(rec.priority), 64)
	_phase = "flight"
	events.player_hit.emit(1.0, "test")
	_t.check("a hit cannot break the ride", _playing(rec, "ult_ride_loop"))
	events.harpoon_smashed.emit(null, Vector3.ZERO, 30.0)
	_t.check("a harpoon smash cannot break the ride", _playing(rec, "ult_ride_loop"))
	events.ultimate_peak.emit("ult_default", Vector3.ZERO)
	_t.check("ultimate_peak plays ult_strike over the ride", _playing(rec, "ult_strike"))
	_t.near("ult_strike blends in over 0.05 s", float(rec.blend), 0.05)
	Trigger.finish(rec)
	_t.check("ult_strike in flight returns to the ride", _playing(rec, "ult_ride_loop"))
	events.ultimate_landed.emit("ult_default", Vector3.ZERO, 2, 40.0)
	_t.check("ultimate_landed plays ult_recover", _playing(rec, "ult_recover"))
	_phase = "idle"
	Trigger.finish(rec)
	_t.check("ult_recover hands back to idle_loop", _playing(rec, "idle_loop") and int(rec.priority) == -1)
	# A strike that ends after the set piece went idle hands off to ult_recover, never to idle.
	_phase = "flight"
	events.ultimate_peak.emit("ult_default", Vector3.ZERO)
	_t.check("a second strike plays", _playing(rec, "ult_strike"))
	_phase = "idle"
	Trigger.finish(rec)
	_t.check("a ride-anchored end with the set piece idle hands off to ult_recover", _playing(rec, "ult_recover"))
	Trigger.finish(rec)
	_t.check("then idle_loop", _playing(rec, "idle_loop"))
	hero._process(20.0)


func _chain(hero, player, rec: Dictionary, events) -> void:
	_phase = "flight"
	events.ultimate_peak.emit("ult_default", Vector3.ZERO)
	_t.check("strike playing (68)", _playing(rec, "ult_strike"))
	events.ultimate_landed.emit("ult_default", Vector3.ZERO, 1, 10.0)
	_t.check("ultimate_landed (69) beats a playing ult_strike (68)", _playing(rec, "ult_recover"))
	_t.eq("ult_recover from the landing at 69", int(rec.priority), 69)
	_phase = "idle"
	Trigger.finish(rec)
	_phase = "windup"
	events.ultimate_started.emit("ult_default", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)
	_t.check("wind-up playing (70)", _playing(rec, "ult_windup"))
	_phase = "idle"
	events.ultimate_cancelled.emit("ult_default", "recall", true)
	_t.check("ultimate_cancelled (72) beats the wind-up (70)", _playing(rec, "ult_recover"))
	_t.eq("ult_recover from the cancel at 72", int(rec.priority), 72)
	Trigger.finish(rec)
	_t.check("the cancelled chain ends on idle_loop", _playing(rec, "idle_loop"))
	hero._process(20.0)
	events.slot_cast.emit("special", "arc_discharge", Vector3.ZERO)
	_t.check("slot_cast special plays cast_special (30)", _playing(rec, "cast_special"))
	events.ultimate_ready.emit("ult_default")
	_t.check("ult_ready (28) does not cut the cast", _playing(rec, "cast_special"))
	_t.eq("ult_ready waits in the queue slot", String(rec.queued.get("clip", "")), "ult_ready")
	Trigger.finish(rec)
	_t.check("ult_ready plays when the cast ends", _playing(rec, "ult_ready") and rec.reaction == "ult_ready")
	_t.near("ult_ready eases in over 0.08 s", float(rec.blend), 0.08)
	_t.check("the queue slot is empty after it plays", rec.queued.is_empty())
	Trigger.finish(rec)
	_t.check("ult_ready hands back to idle_loop", _playing(rec, "idle_loop"))
	hero._process(20.0)


func _queue(hero, player, rec: Dictionary, events) -> void:
	events.slammed.emit(Vector3.ZERO, 30.0, 1.0)
	_t.check("slammed plays smash (36)", _playing(rec, "smash"))
	events.drop_landed.emit(1)
	_t.check("a hit's drop_land (30) does not cut the smash", _playing(rec, "smash"))
	_t.eq("drop_land waits in the queue slot", String(rec.queued.get("clip", "")), "drop_land")
	Trigger.finish(rec)
	_t.check("drop_land plays when the smash ends", _playing(rec, "drop_land"))
	Trigger.finish(rec)
	_t.check("drop_land hands back to idle_loop", _playing(rec, "idle_loop"))
	hero._process(20.0)
	# One slot: a second queued clip replaces the first.
	events.slammed.emit(Vector3.ZERO, 30.0, 1.0)
	events.ultimate_ready.emit("ult_default")
	_t.eq("ult_ready queues behind the smash", String(rec.queued.get("clip", "")), "ult_ready")
	events.drop_landed.emit(2)
	_t.eq("a second queued clip replaces the first", String(rec.queued.get("clip", "")), "drop_land")
	Trigger.finish(rec)
	_t.check("the replacing clip plays", _playing(rec, "drop_land"))
	Trigger.finish(rec)
	hero._process(20.0)
	# The miss reads loud: wince (40) cuts the smash at once.
	events.slammed.emit(Vector3.ZERO, 30.0, 1.0)
	events.missed_drop.emit()
	_t.check("a miss cuts the smash with wince", _playing(rec, "wince"))
	_t.check("the miss queues nothing", rec.queued.is_empty())
	Trigger.finish(rec)
	hero._process(20.0)
	# The queue only takes a clip that would wait at most its row's seconds.
	events.slot_cast.emit("special", "arc_discharge", Vector3.ZERO)
	events.ultimate_ready.emit("ult_default")
	_t.check("ult_ready queues on a short cast", rec.queued.get("clip", "") == "ult_ready")
	Trigger.finish(rec)
	Trigger.finish(rec)
	hero._process(20.0)
	events.heft_class_changed.emit(2, 10.0)
	_t.check("heft_class_changed plays class_up", _playing(rec, "class_up"))
	Trigger.finish(rec)
	events.heft_class_dropped.emit(1, 5.0)
	_t.check("heft_class_dropped plays nothing", _playing(rec, "idle_loop"))
	hero._process(20.0)


func _filter(hero, player, rec: Dictionary, events) -> void:
	events.slot_cast.emit("special", "arc_discharge", Vector3.ZERO)
	_t.check("slot_cast slot 2 (special) selects cast_special", _playing(rec, "cast_special"))
	Trigger.finish(rec)
	hero._process(20.0)
	# PILOT-CLIPS 7.2 item 2: pressing the line slot only loads the skill, so it plays nothing;
	# cast_line plays on the bite, line_skill_fired, so the pilot's motion lands with the hit.
	events.slot_cast.emit("line", "bank_shot", Vector3.ZERO)
	_t.check("slot_cast slot 3 (line) plays nothing", _playing(rec, "idle_loop") and rec.reaction == "")
	events.line_skill_fired.emit("bank_shot", null, Vector3.ZERO, "enemy")
	_t.check("line_skill_fired selects cast_line", _playing(rec, "cast_line"))
	Trigger.finish(rec)
	hero._process(20.0)
	events.slot_cast.emit("weapon", "arc_caster", Vector3.ZERO)
	_t.check("slot_cast with another slot plays nothing", _playing(rec, "idle_loop") and rec.reaction == "")
	var log: Dictionary = game_run(hero).get_meta("pilot_clips", {})
	_t.check("the run carries pilot_clips plays", int(log.get("played", {}).get("cast_special", 0)) >= 1)
	_t.check("the run counts refused missing clips", int(log.get("missing", -1)) >= 1)


func game_run(hero):
	return hero.ctx.run


# --- mecha motion on a fixture cockpit ---------------------------------------------------

const STEP := 0.005


func _run_for(motion, seconds: float, facts := {}) -> void:
	for i in roundi(seconds / STEP):
		motion.step(STEP, facts)


func _mecha() -> void:
	if not ResourceLoader.exists(MECHA_PATH):
		_t.check("mecha_motion.gd exists", false)
		return
	var Mecha = load(MECHA_PATH)
	var pod := Trigger.fixture_pod()
	root.add_child(pod.get_parent())
	var motion = Mecha.new(pod, pod.get_parent().get_node("Core"), "pylon_engineer", [])
	var lever: Node3D = pod.get_node("Control_Lever")
	motion.cast("cast_special", "Lever", 0.2)
	_run_for(motion, 0.19)
	_t.near("the lever holds until the contact time", lever.rotation_degrees.x, 0.0, 0.01)
	_run_for(motion, 0.01 + 0.08)
	_t.near("the lever throws 35 degrees in 0.08 s", lever.rotation_degrees.x, Mecha.LEVER_DEG, 0.5)
	_run_for(motion, 0.25)
	_t.near("the lever returns in 0.25 s", lever.rotation_degrees.x, 0.0, 0.01)
	var crank: Node3D = pod.get_node("Control_Crank")
	motion.cast("cast_special", "Crank", 0.0)
	_run_for(motion, 0.08)
	_t.near("the crank turns half a turn", crank.rotation_degrees.x, 180.0, 1.0)
	_run_for(motion, 0.26)
	_t.near("the crank returns", crank.rotation_degrees.x, 0.0, 0.01)
	var plunger: Node3D = pod.get_node("Control_Plunger")
	motion.cast("cast_line", "Plunger", 0.0)
	_run_for(motion, 0.08)
	_t.near("the plunger presses 0.06 m", plunger.position.y, -0.06, 0.001)
	_run_for(motion, 0.26)
	_t.near("the plunger returns", plunger.position.y, 0.0, 0.0001)
	var trigger: Node3D = pod.get_node("Control_Trigger")
	_t.check("a shot squeezes the trigger", motion.shot())
	_t.check("a second shot inside 0.12 s does not", not motion.shot())
	_run_for(motion, 0.06)
	_t.near("the trigger squeezes 12 degrees in 0.06 s", trigger.rotation_degrees.x, 12.0, 0.5)
	_run_for(motion, 0.07)
	_t.check("a shot after 0.12 s squeezes again", motion.shot())
	_run_for(motion, 0.2)
	_t.near("the trigger returns", trigger.rotation_degrees.x, 0.0, 0.01)
	motion.kick()
	_run_for(motion, 0.06)
	_t.near("the left pedal kicks 20 degrees", pod.get_node("Control_Pedal_L").rotation_degrees.x, 20.0, 0.5)
	_t.near("the right pedal kicks 20 degrees", pod.get_node("Control_Pedal_R").rotation_degrees.x, 20.0, 0.5)
	_run_for(motion, 0.3)
	_t.near("the pedals return", pod.get_node("Control_Pedal_L").rotation_degrees.x, 0.0, 0.01)
	var lap: Node3D = pod.get_node("Control_LapBar")
	motion.ultimate_started()
	_run_for(motion, 1.0)
	_t.near("the lap bar hauls 25 degrees back through the ultimate", lap.rotation_degrees.x, -25.0, 0.5)
	motion.ultimate_ended()
	_run_for(motion, 0.26)
	_t.near("the lap bar returns at the landing", lap.rotation_degrees.x, 0.0, 0.01)
	_t.near("the Sable lattice does not fold", pod.get_parent().get_node("Core").scale.x, 1.0, 0.0001)
	pod.get_parent().free()
	_cannon_fold(Mecha)
	_machinery(Mecha)


func _cannon_fold(Mecha) -> void:
	var pod := Trigger.fixture_pod()
	root.add_child(pod.get_parent())
	var core: Node3D = pod.get_parent().get_node("Core")
	var motion = Mecha.new(pod, core, "remembered_cannon", [])
	motion.ultimate_started()
	_run_for(motion, 0.2)
	_t.near("the Cannon's lattice folds to 0.85 for Fire Mission", core.scale.x, 0.85, 0.001)
	motion.ultimate_ended()
	_run_for(motion, 0.12)
	_t.near("and springs back in 0.12 s", core.scale.x, 1.0, 0.001)
	_t.check("the shared landing fold stays off", not Mecha.LANDING_FOLD)
	pod.get_parent().free()


func _machinery(Mecha) -> void:
	var facts := {"meter_fill": 0.0, "selected_slot": "weapon", "slot_ready": {"special": false}, "pressure": 0.0,
		"gliding": false, "cloaked": false, "line_load": 0.0, "set_piece_phase": "idle", "heft_class": 1,
		"aim": Vector3(0, 0, -1), "reloading": false, "gauge_fill": 0.0, "idle_still": false}
	var rows := [
		{"node": "MeterBand", "fact": "meter_fill", "motion": "turn", "start": {"axis": "y", "deg": 90.0}},
		{"node": "SlotLamp", "fact": "selected_slot", "motion": "slide", "start": {"slot": 2, "axis": "y", "m": 0.05}},
		{"node": "ReadyFlag", "fact": "slot_ready", "motion": "show", "start": {"slot": "special"}},
		{"node": "DrumWindow", "fact": "pressure", "motion": "turn", "start": {"axis": "z", "deg": 60.0, "max": 1.0}},
		{"node": "GlideFin", "fact": "gliding", "motion": "turn", "start": {"axis": "x", "deg": 45.0}},
		{"node": "CloakVeil", "fact": "cloaked", "motion": "grow", "start": {"scale": 1.5}},
		{"node": "WinchSpool", "fact": "line_load", "motion": "spin", "start": {"axis": "y", "deg_s": 360.0}},
		{"node": "WrenchRack", "fact": "set_piece_phase", "motion": "turn", "start": {"axis": "y", "deg": 90.0, "phases": ["windup", "flight"]}},
		{"node": "HeftGauge", "fact": "heft_class", "motion": "slide", "start": {"axis": "z", "m": 0.08}},
		{"node": "MuzzleFlap", "fact": "shot_fired", "motion": "throw", "start": {"axis": "x", "deg": 30.0}},
		{"node": "AimVane", "fact": "aim", "motion": "aim", "start": {"rate": 1000.0}},
		{"node": "Crane", "fact": "reloading", "motion": "turn", "start": {"axis": "y", "deg": 80.0}},
		{"node": "ChargeLever", "fact": "gauge_fill", "motion": "turn", "start": {"axis": "x", "deg": 35.0}},
		{"node": "IdleDrum", "fact": "idle_still", "motion": "spin", "start": {"axis": "y", "deg_s": 900.0, "for_s": 0.4}},
		{"node": "Control.Nope", "fact": "meter_fill", "motion": "turn", "start": {"axis": "x", "deg": 10.0}},
	]
	var names: Array = []
	for row in rows:
		if row.node != "Control.Nope":
			names.append(row.node)
	var pod := Trigger.fixture_pod(names)
	root.add_child(pod.get_parent())
	# The planted missing node's line stays off stdout; the harness reads the SKIP token as a skip.
	Mecha.echo = false
	var motion = Mecha.new(pod, pod.get_parent().get_node("Core"), "pylon_engineer", rows)
	_run_for(motion, 0.2, facts)
	var before := {}
	for node_name in names:
		var node: Node3D = pod.get_node(node_name)
		before[node_name] = [node.transform, node.visible]
	facts = {"meter_fill": 1.0, "selected_slot": "special", "slot_ready": {"special": true}, "pressure": 1.0,
		"gliding": true, "cloaked": true, "line_load": 1.0, "set_piece_phase": "flight", "heft_class": 5,
		"aim": Vector3(1, 0, 0), "reloading": true, "gauge_fill": 1.0, "idle_still": true}
	motion.pulse("shot_fired")
	_run_for(motion, 0.05, facts)
	var moved: Array = []
	for node_name in names:
		var node: Node3D = pod.get_node(node_name)
		if node.transform != before[node_name][0] or node.visible != before[node_name][1]:
			moved.append(node_name)
	_t.eq("one machinery node moves per fact kind (14 kinds)", moved, names)
	_t.eq("facts covered", Mecha.FACTS.size(), 14)
	_run_for(motion, 1.0, facts)
	# Fix round 2026-10-11: the label and the printed values no longer carry the SKIP token, which
	# made the smoke count this test as skipped. Same check, same count.
	var want_line := "S" + "KIP control Nope"
	_t.check("a missing node records one skip-control line naming it", motion.skip_lines == [want_line], "%d line(s)" % motion.skip_lines.size())
	Mecha.echo = true
	var lights := pod.get_parent().find_children("*", "Light3D", true, false)
	_t.eq("no Light3D under the cockpit", lights.size(), 0)
	var overrides := 0
	for node in pod.get_parent().find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).material_override != null:
			overrides += 1
	_t.eq("no material_override under the cockpit", overrides, 0)
	pod.get_parent().free()
