# 2026-10-12 (PC-SABLE round 5): Pin 89 checks including final audio levels and live-key pitch.
extends SceneTree
# PC-SABLE: real router, harpoon, combat, grants and immutable world-one fixtures.
# Expected check count is pinned below; missing cases fail.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const DamageFamilies := preload("res://src/combat/damage_families.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Sable := preload("res://src/core/trees/sable.gd")
const Cards := preload("res://src/core/trees/world_one_cards.gd")
const Relics := preload("res://src/build/relics.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Triggers := preload("res://src/build/triggers.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const Ultimate := preload("res://src/combat/ultimate.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Rows := preload("res://src/presentation/rows.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const T := preload("res://tests/support/t.gd")
const EXPECTED_CHECKS := 90
const DT := 1.0 / 60.0
var _t := T.new("sable_kit_test")
var _game
var _player
var _combat
var _lines: Array = []
var _loaded: Array = []
var _fired: Array = []
var _expired: Array = []
var _special: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _never() -> bool:
	return false


func _fresh(speed := 20.0) -> void:
	_player.kit.drop_line("reset")
	_player.kit.rewind_left = 0.0
	_player.kit.line_end = ""
	_player.chain.reset()
	_player.abilities.refill()
	_player.abilities.snap_back("test")
	_player._fire_latched = false
	_player.kit.mass_on = false
	_player.set_velocity_now(Vector3.RIGHT * speed)
	_player.drive_basis = Basis.looking_at(Vector3.FORWARD)
	_combat._line_load = {}
	_combat._bite_pending = false
	# 2026-10-15 SG1 merge: each check starts on an unmarked target, as every attempt does in play.
	_combat._exposed = {}
	_loaded.clear()
	_fired.clear()
	_expired.clear()
	_special.clear()
	_lines.clear()


func _tick(fields := {}, delta := DT) -> void:
	_player.intent.clear()
	for key in fields:
		_player.intent.set(key, fields[key])
	_player._route_slots(delta)
	_combat._step_special(_player.intent, delta)
	_combat._step_line(_player.intent, delta)


func _cast() -> void:
	_tick({"slot_pick": 2, "fire_pressed": true, "fire_held": true})
	_tick({"fire_released": true})


func _wall() -> Vector3:
	var anchor: Vector3 = _player.ball_position() + Vector3(8.0, 3.0, 0.0)
	_player.grapple_to(anchor, Vector3.LEFT)
	_player._publish_line(0.0)
	return anchor


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	for i in 36:
		await physics_frame
	_player.set_physics_process(false)
	_combat.set_physics_process(false)
	_combat.ultimate.set_physics_process(false)
	_combat.ultimate.stakes.set_physics_process(false)
	_game.events.line_state_changed.connect(func(state: String, _target: Node3D, _at: Vector3, cause: String): _lines.append([state, cause]))
	_game.events.line_skill_loaded.connect(func(id: String, _s: float): _loaded.append(id))
	_game.events.line_skill_fired.connect(func(id: String, _target: Node3D, _at: Vector3, _on: String): _fired.append(id))
	_game.events.line_skill_expired.connect(func(id: String): _expired.append(id))
	_game.events.special_used.connect(func(id: String, _at: Vector3): _special.append(id))
	_t.eq("Sable's real slots", [_player.abilities.id_of("line"), _player.abilities.ultimate_id], ["bank_shot", "cable_run"])
	_fresh()
	var anchor := _wall()
	var before: int = _player.chain.combo
	var shape: Dictionary = _player.bank_geometry()
	_cast()
	_t.near("world exit", _player.state.velocity.length(), 29.0, 0.5)
	_t.check("exit cone and cast share their direction", rad_to_deg(_player.state.velocity.angle_to(shape["dir"])) < 1.0)
	_t.check("the exit cone is an aim, not an area a hit lands in", shape.get("aim", false), str(shape))
	_t.check("exit follows eject_direction", rad_to_deg(_player.state.velocity.angle_to(Augments.eject_direction(_player.ball_position() - anchor, _player.drive_basis))) < 5.0)
	_t.eq("quiet release", [_player.kit.hooked, _player.kit.line_end], [false, "bank"])
	_player._publish_line(0.0)
	_t.eq("no broke event", _lines.filter(func(r): return r[0] == "broke"), [])
	_t.eq("chain unchanged", _player.chain.combo, before)
	_t.near("bank keeps the chain airtime grace", _player.chain.grace_left, 0.8)
	_t.near("Parting Shot timer resets", _combat._since_slingshot, 0.0)
	_t.near("run log keeps bank gain", _game.ctx.run_log._record["line_skill"].get("bank_gain_mps", -1), 9.0, 0.01)
	_fresh(40.0)
	_wall()
	_cast()
	_t.near("bank cap", _player.state.velocity.length(), 45.0, 0.01)
	_fresh(2.0)
	_wall()
	_cast()
	_t.near("bank floor", _player.state.velocity.length(), 20.25, 0.01)
	var slows := []
	for tick in 451:
		var speed := tick / 10.0
		var exit := Augments.bank_exit(speed, Vector3.LEFT, Basis.IDENTITY, _player.kit).length()
		if exit + 0.0001 < speed or exit > 45.0001:
			slows.append(speed)
	_t.eq("451-point 0 to 45 sweep never slows and respects cap", slows, [])
	_t.near("a faster arrival keeps its speed", Augments.bank_exit(60.0, Vector3.LEFT, Basis.IDENTITY, _player.kit).length(), 60.0, 0.001)
	_fresh()
	var enemy: Node3D = _combat.spawn_enemy("chaser", _player.ball_position() + Vector3(9.0, 1.0, 0.0))
	enemy.live = _never
	enemy.hp = 5000.0
	enemy.max_hp = 5000.0
	_player.grapple_to(enemy.global_position, Vector3.LEFT, enemy)
	_player.chain.combo = 3
	var hp: float = enemy.hp
	var mult: float = _player.chain.multiplier()
	enemy._knock = Vector3.ZERO
	var exit: Dictionary = _player.bank_geometry()
	_cast()
	# The chaser is a soaked Spillway crew (design-v3/SPILLWAY-ROSTER.md): arc lands at its wet multiplier.
	var soaked := DamageFamilies.mult(String(DamageFamilies.ARMOUR_OF.get("chaser", "")), "arc", "")
	_t.near("body pivot damage scales by chain", hp - enemy.hp, 10.0 * mult * soaked, 0.01)
	_t.near("body exit", _player.state.velocity.length(), 29.0, 0.01)
	var knock: Vector3 = Vector3(enemy._knock.x, 0.0, enemy._knock.z)
	var away: Vector3 = -(exit["dir"] as Vector3)
	away.y = 0.0
	_t.check("pivot knock points opposite the exit", knock.normalized().dot(away.normalized()) > 0.99)
	_t.near("pivot knock is twelve divided by enemy weight", knock.length(), 12.0 / enemy.weight * away.length(), 0.01)
	_fresh()
	_player.tree._knobs["grapple_fling"] = 10.0
	_wall()
	_cast()
	_t.near("Coil Hook never stacks", _player.state.velocity.length(), 29.0, 0.01)
	_player.tree._knobs.erase("grapple_fling")
	_fresh()
	_cast()
	_t.eq("no line loads", [_loaded, _fired], [["bank_shot"], []])
	_tick({}, 3.97)
	_t.check("load stands at 3.99", not _combat.line_load().is_empty())
	_wall()
	_tick({}, 0.0)
	_t.eq("bite carries the load", _fired, ["bank_shot"])
	_fresh()
	_cast()
	_tick({}, 3.99)
	_t.eq("load expires at 4.01", [_expired, _combat.line_load()], [["bank_shot"], {}])
	_fresh()
	_player.grapple_to(enemy.global_position, Vector3.LEFT, enemy)
	Augments.commit_smash(_player.kit, _player.tuning, _player.state.velocity)
	hp = enemy.hp
	_cast()
	_t.near("smash pivot arc is immediate", hp - enemy.hp, 10.0 * soaked, 0.01)
	_t.check("redirect waits for paid smash", not _player._bank_pending.is_empty() and _player.kit.line_state == Augments.LINE_SMASH)
	_t.near("smash keeps incoming velocity until contact", _player.state.velocity.length(), 20.0, 0.01)
	_player._begin_landing(enemy)
	_player._finish_landing(enemy, 20.0)
	_t.check("landing pays then redirects", _player._bank_pending.is_empty() and _player.state.velocity.length() >= 29.0 - 0.001)
	_fresh(0.0)
	_tick({"slot_pick": 1, "fire_pressed": true, "fire_held": true}, 0.0)
	_tick({"fire_held": true}, 1.0)
	_tick({"fire_released": true}, 0.0)
	# Ruling ek (E1-06): Static Discharge speed term 1.4 -> 0.8 per m/s (14 + 40 * 0.8 = 46.0 at full gauge).
	_t.eq("slot 2 full discharge", [_combat.last_burst["targets"], _combat.last_burst["radius"], _combat.last_burst["damage"]], [8, 30.0, 46.0])
	_t.eq("gauge returns home", _player.abilities.selected, "weapon")
	_fresh(30.0)
	_t.near("live tap discharge", _combat._discharge_speed(0.0), 22.5)
	_fresh()
	_wall()
	_player.kit.mounted = true
	_cast()
	_t.check("Bank Shot releases a mounted Sable", not _player.kit.mounted and _player.state.velocity.length() > 20.0)
	var charge: int = _player.abilities.slot("special").charges
	_game.events.mounted.emit(_player.ball_position(), 18.0)
	_t.eq("plant stays free", [_special, _player.abilities.slot("special").charges], [["detonation_gauge"], charge])
	_tree()
	_grants(enemy)
	_other_pilot_beats()
	_audio_levels()
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


func _other_pilot_beats() -> void:
	for id in ["ult_default", "plate_return"]:
		var ult := Ultimate.new()
		ult.ctx = _game.ctx
		# 2026-10-12, PC-TALLY merge 80634ba: plate_return now has Tally's volley row, which calls
		# into combat; wire the game's combat as the game does (ultimate.gd:152).
		ult.combat = _combat
		ult._id = id
		ult._beat_len = 1.0
		ult._beats = 4
		ult._beat_clock = 1.0 - 0.000005
		var at: Vector3 = _player.ball_position()
		ult._ride = ult._carrier(at, {"to": at + Vector3.FORWARD * 10.0, "seconds": 3.0, "mode": "line"})
		ult._fly(0.0)
		_t.eq("%s keeps its original beat boundary" % id, ult._beat, 0)
		ult._fly(0.000005)
		_t.eq("%s fires on its original beat boundary" % id, ult._beat, 1)
		ult.free()


func _tree() -> void:
	for i in range(6, 14):
		_t.check("depth 3 swap %d" % i, Sable.NODES[i].get("swap", {}).get("ultimate", "") in ["ball_lightning", "outpost"])
	var good := true
	for i in range(6, 14, 2):
		good = good and Sable.NODES[i]["swap"]["ultimate"] != Sable.NODES[i + 1]["swap"]["ultimate"]
	_t.check("all depth-3 siblings differ", good)
	_t.check("retained Face Runner pair differs", Sable.NODES[8]["swap"]["ultimate"] != Sable.NODES[6]["swap"]["ultimate"])
	good = true
	for i in range(14, 30):
		var knobs: Array = Sable.NODES[i].get("knob", {}).keys().filter(func(k): return String(k).begins_with("ult_"))
		good = good and knobs.size() == 1
		if i % 2 == 0:
			var other: Array = Sable.NODES[i + 1].get("knob", {}).keys().filter(func(k): return String(k).begins_with("ult_"))
			good = good and knobs != other
	_t.check("every depth-4 leaf has one distinct sibling knob", good)
	_t.eq("world-one ids", Sable.NODES_WORLD_ONE.slice(0, 6).map(func(n): return n["id"]), ["s_static_flutter", "s_rail_lance", "s_cannonball", "s_face_runner", "s_beachhead", "s_bulwark"])
	_t.eq("world-one cards read as the table writes them", [Cards.ROWS["s_cannonball"], Cards.ROWS["s_face_runner"]], ["Kick off a wall to zap what's near. Scrap makes you heavier. Heavier launches farther.", "Kick off a wall to jump again. Steer sharper after each kick."])
	_t.eq("one crater relic", Relics.ids().filter(func(id): return Relics.fits(id, "pylon_engineer") and Relics.swap_of(id) == "crater_slam"), ["crater_heart"])
	_t.eq("two Bank Shot relics", Relics.ids().filter(func(id): return Relics.fits(id, "pylon_engineer") and Relics.slot_of(id) == "line"), ["pit_coil", "storm_crater"])
	var movement_local := true
	var stack_rules := true
	var repeat_safe := true
	for n in Sable.NODES.slice(6):
		movement_local = movement_local and n.get("class_id", "") == "pylon_engineer"
		stack_rules = stack_rules and n.get("stack_rule", "") in PartDef.STACK_RULES
		for copies in range(1, 21):
			# Trees select each id once and relics hold one id per slot: capped at one copy.
			repeat_safe = repeat_safe and PartDef.Stacking.value(n["stack_rule"], 1.0, copies, 1.0) == 1.0
	_t.check("all changed movement rows are pilot-local", movement_local)
	_t.check("each changed node declares its stack rule", stack_rules)
	_t.check("1 to 20 stack sweep stays capped at one", repeat_safe)
	_t.check("existing proc graph never re-enters and depth is one", UpgradeTree._proc_loop("pylon_engineer", UpgradeTree.path_to("pylon_engineer", "s_bounce_battery")) == "" and Triggers.MAX_CHAIN_DEPTH == 1)


func _grants(enemy: Node3D) -> void:
	var pilots: Array = ClassDef.all().map(func(d): return d.id)
	_t.eq("grant table validates", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), pilots, Cosmetics.ids()), [])
	var rows := Achievements.ROWS.duplicate(true)
	rows["planted_11"] = {"name": "Too Many", "text": "This new count must fail.", "on": "enemy_killed", "count": 11, "reward": {}}
	_t.check("new count 11 fails validation", Achievements.validate(rows, Achievements.bus_signals(), pilots, Cosmetics.ids()).any(func(p): return "planted_11: new grants" in p))
	_t.eq("all grandfathered ids are explicit", Achievements.GRANDFATHERED.size(), 12)
	_t.check("every legacy count above ten is listed by id", Achievements.ROWS.keys().all(func(id): return int(Achievements.ROWS[id]["count"]) <= 10 or id in Achievements.GRANDFATHERED))
	var profile := Profile.new("user://sable-grants-%d.json" % OS.get_process_id())
	profile.load_profile()
	var listener := Progress.new()
	listener.rows = {}
	for id in ["ach_sable_cable_runs", "ach_sable_parting_shot", "ach_sable_switchback"]:
		listener.rows[id] = Achievements.row(id)
	listener.setup(_game.events, null, profile, func(): return 1.0)
	_combat._discover("loaded_line", Vector3.ZERO)
	_combat._discover("set_piece", Vector3.ZERO)
	_fresh()
	var stakes = _combat.ultimate.stakes
	var stake = stakes.plant(_player.ball_position() + Vector3.RIGHT * 10.0)
	_player.grapple_to(stake.global_position, Vector3.LEFT, stake)
	_cast()
	_t.check("stake Bank Shot detects Switchback", _game.ctx.codex.known("switchback"))
	enemy.hp = 1.0
	_combat.strike(enemy, "arc", 50.0, "", "special")
	_t.check("a kill after Bank Shot detects Parting Shot", _game.ctx.codex.known("parting_shot"))
	var ult = _combat.ultimate
	ult._id = "cable_run"
	ult._leg = 1
	ult._plan = {"from": _player.ball_position(), "legs": [{"strike": true}]}
	ult._record = {"id": "cable_run", "landing_hits": 0, "damage": 0.0}
	ult._plan["legs"].append({"strike": true})
	ult._leg = 1
	ult._strike(_player.ball_position() + Vector3.RIGHT * 100.0)
	_t.eq("an encore's first leg does not count a completed Cable Run", ult._sable_runs, 0)
	ult._plan["legs"].pop_back()
	ult._leg = 1
	for i in 3:
		ult._strike(_player.ball_position() + Vector3.RIGHT * 100.0)
	_t.check("three real landing callbacks detect Cable Runner", _game.ctx.codex.known("sable_cable_runs"))
	for id in ["ach_sable_cable_runs", "ach_sable_parting_shot", "ach_sable_switchback"]:
		_t.check("%s earns once" % id, profile.earned(id) and profile.has_cosmetic(Achievements.reward_of(id)["cosmetic"]))
	var reload := Profile.new(profile.path)
	reload.load_profile()
	_t.check("all three grants survive save", ["trail_sable_cable", "decal_sable_spool", "shell_sable_felt"].all(func(id): return reload.has_cosmetic(id)))
	# Re-pinned 2026-10-16 (COSMETICS-ART-BRIEFS port note 1): Felt Rig's art merged in wave 13 unit PD.
	_t.check("Felt Rig is live", not Cosmetics.is_pending("shell_sable_felt") and FileAccess.file_exists("res://assets/models/world_one/shell_sable_felt.glb"))
	listener.free()


func _audio_levels() -> void:
	var audio := Audio.new()
	audio.setup(_game.ctx)
	audio.bake_now()
	audio.engine.grid = null
	audio.engine.key = 5
	_player.set_velocity_now(Vector3.RIGHT * 22.5)
	_player.chain.combo = 3
	for mode in [MusicEngine.PLAY, MusicEngine.IDLE]:
		audio.engine.mode = mode
		audio._last_start.clear()
		audio.cue_log.clear()
		audio._sable_bank_sound()
		for sound in [Audio.SABLE_SOUNDS["sable_ratchet"], Audio.SABLE_SOUNDS["sable_bank"]]:
			var cues: Array = audio.cue_log.filter(func(c): return c[1] == sound and c[2] == "now")
			_t.eq("mode %d %s sounds once" % [mode, sound], cues.size(), 1)
			var cue: Array = cues[0] if not cues.is_empty() else ["", "", "", 0, 0.0, 0.0]
			_t.near("mode %d %s final row level" % [mode, sound], cue[5], SfxBank.trim_db(sound) + Audio.PRIORITY_DB[Rows.priority("line_skill_fired")])
			var shape := Harmony.ratio(12.0 * clampf(_player.state.velocity.length() / 45.0, 0.0, 1.0) + mini(5, maxi(0, _player.chain.combo - 1))) if sound == Audio.SABLE_SOUNDS["sable_bank"] else 1.0
			_t.near("mode %d %s final live-key pitch" % [mode, sound], cue[4], shape * Harmony.ratio(audio.live_key()))
		audio._last_start.clear()
		audio.cue_log.clear()
		audio.engine._actions.clear()
		audio.engine._voices.clear()
		var sound := SfxBank.cause_note_id(Audio.SABLE_NOTES[0])
		audio.sable_note("cable", 1)
		var level: float = SfxBank.trim_db(sound) + Audio.PRIORITY_DB[Rows.priority("ultimate_peak")]
		if mode == MusicEngine.PLAY:
			var actions: Array = audio.engine._actions.filter(func(a): return a.get("id", "") == sound)
			_t.eq("PLAY set-piece note schedules once", actions.size(), 1)
			audio.engine.clock = audio.engine.next_beat()
			audio.engine._run_due()
			var voices: Array = audio.engine._voices
			_t.near("PLAY set-piece note final row level", linear_to_db(voices[-1].gl) if not voices.is_empty() else 0.0, level)
			_t.check("PLAY note renders the live-key ratio into its samples", not voices.is_empty() and voices[-1].buf == SfxBank.samples_at(sound, audio.engine.step_len, audio.live_key(), audio.engine.theme) and voices[-1].buf != SfxBank.samples_at(sound, audio.engine.step_len, 0, audio.engine.theme))
		else:
			var cues: Array = audio.cue_log.filter(func(c): return c[1] == sound and c[2] == "now")
			_t.eq("non-PLAY set-piece note sounds once", cues.size(), 1)
			var cue: Array = cues[0] if not cues.is_empty() else ["", "", "", 0, 0.0, 0.0]
			_t.near("non-PLAY set-piece note final row level", cue[5], level)
			_t.near("non-PLAY set-piece note live-key pitch", cue[4], Harmony.ratio(audio.live_key()))
		audio.sound_ready = false
		var pending := audio.engine.pending_actions()
		var played: int = audio.cue_log_total
		audio.sable_note("cable", 2)
		_t.check("mode %d unready bank refuses the note" % mode, audio.engine.pending_actions() == pending and audio.cue_log_total == played)
		audio.sound_ready = true
	audio.free()
