extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Interactables := preload("res://src/world/interactables.gd")

# The FIRST-TIMER probe (alpha-status ambition map, unit 8). One headless bot run on a fresh
# profile records the first tick each teaching surface is on screen and the first tick each
# mechanic is needed or used. It judges nothing: scripts/first-timer.mjs holds the mechanic
# table and fails a mechanic that is needed before it is taught.
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/first_timer.gd \
#     -- --out=<file.json> [--seed=1] [--pilot=<class id>] [--stages=2] [--scrap-at=<seconds>] [--table=park]
#
# --stages=2 ends the run as it leaves world 1 (both Spillway stages and Brindle). --scrap-at
# scraps the ball (a chaser's hit, twice past the full-hull guard) that many stage seconds into
# stage 1, so a run that would not die still reaches RUN OVER and the retry row. Test mode
# gives every process its own data folder, so the key prompts start from an empty profile.
#
# Teach ids, with the tick they first show (tick -1 is before play):
#   prompt:<verb>     a key prompt drew (events.prompt_shown: ui/key_glyphs.gd, ui/first_steps.gd)
#   objective:<id>    the objective plate's row (hud.objective_reading, core/objectives.gd)
#   prompt:tip_<id>   a first-meet field tip told (ui/field_tips.gd: grip, jam, cast, radio, stake,
#                     companion, active, dunk), emitted as prompt_shown once its toast has been on
#                     screen MIN_SHOWN
#   screen:run_over   RUN OVER after a death, naming what scrapped you, with its Run again key
#                     (no free retry: a death with no earned save ends the run)
#   card:<slot>       a key on the chosen pilot's class card (ui/class_kit.gd card_keys)
# Need ids: the first tick of the bus fact or flow state that names them (NEEDS below).

const NEEDS := {
	"stage_entered": "first stage dropped in",
	"warden_engaged": "first Warden engaged",
	"warden_staggered": "first Warden stagger (core open)",
	"reward_offered": "first reward gates",
	"dead": "first death (player_died)",
	"boss_arena_entered": "Brindle's arena",
	"boss_staggered": "first boss stagger",
	"harpoon_used": "first harpoon latch",
	"grapple_used": "first line on the world",
	"slam_used": "first slam",
	"bay_entered": "first time in Moss's bay",
	"scrap_collected": "first scrap",
	"grip_used": "first wall carved at the fast tier",
	"jam_hit": "first jam from a field's pulse",
	"cast_started": "first slot cast with a cast time",
	"radio_live": "pilot radio dial first on screen",
	"relay_met": "first relay stake post within reach",
	"companion_full": "SPIL-9's halo gauge first full",
	"active_racked": "first active racked on F",
}
# How near a relay's stake post counts as met: E's lock reach, the first place E can take the stake.
# The post's tip (field_tips.gd) goes up from 30 m and counts once on screen MIN_SHOWN, so a slow
# approach is taught first and a fast one may reach the post first (the audit says late).
const RELAY_MET := Interactables.LOCK_REACH

var _settings := {}
var _game
var _driver
var _tick := 0
var _jams := 0
var _stage := 0
var _taught := {}
var _needed := {}
var _pilot := ""
var _card: Array = []
var _out := ""
var _done := false
var _scrapped := false


func _initialize() -> void:
	SimClock.ticks = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			_settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if not _settings.has("out"):
		printerr("first_timer: usage: -- --out=<file.json> [--seed=1] [--pilot=<class id>] [--stages=2]")
		quit(2)
		return
	_out = _settings["out"]
	var run_seed := int(_settings.get("seed", "1"))
	seed(run_seed)
	_game = Game.new()
	_game.test_mode = true
	_game.run_store_path = _out.get_base_dir().path_join("first-timer-entrance-%d.json" % OS.get_process_id())
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		_start()
		return false
	_tick += 1
	_scrap_if_due()
	_watch()
	var over: bool = _driver.tick(delta)
	if not over and _game.run.stage > int(_settings.get("stages", "2")):
		over = true
	if over:
		_finish(String(_driver.outcome) if "outcome" in _driver else "")
	return false


func _start() -> void:
	var run_seed := int(_settings.get("seed", "1"))
	var events = _game.events
	events.run_started.connect(_on_run_started)
	events.prompt_shown.connect(func(verb: String): _teach("prompt:" + verb))
	events.stage_entered.connect(func(stage: int, _retry: bool):
		_stage = stage
		_need("stage_entered"))
	events.player_died.connect(func(): _need("dead"))
	events.warden_engaged.connect(func(_stage_n: int): _need("warden_engaged"))
	events.posture_changed.connect(_on_posture)
	events.reward_offered.connect(func(_offers: Array): _need("reward_offered"))
	events.boss_arena_entered.connect(func(): _need("boss_arena_entered"))
	events.line_state_changed.connect(func(state: String, _target, _at: Vector3, _cause: String):
		if state in ["latched_world", "latched_body"]:
			_need("harpoon_used")
		if state == "latched_world":
			_need("grapple_used"))
	events.slammed.connect(func(_at: Vector3, _strength: float, _flatness: float): _need("slam_used"))
	events.bay_entered.connect(func(_banked: float): _need("bay_entered"))
	events.scrap_collected.connect(func(_amount: int, _at: Vector3, _total: int): _need("scrap_collected"))
	if _game.get("combat") != null:
		_game.combat.companion_assist_full.connect(func(): _need("companion_full"))
	_driver = BotDriver.new(_game, String(_settings.get("policy", "skipper")), run_seed)
	if _settings.has("pilot"):
		_driver.class_index = BotDriver.class_index_for(run_seed, String(_settings["pilot"]))
	_game.presentation.audio.bake_now()
	_game.run.run_seed_override = run_seed
	_driver.start(false)


func _on_run_started(class_id: String) -> void:
	_pilot = class_id
	var def = ClassDef.by_id(class_id)
	_card = []
	for record in ClassKit.card_keys(def):
		_card.append({"slot": record["slot"], "ability": record["ability"], "key": record["key"], "words": record["words"]})
		_taught["card:" + String(record["slot"])] = {"tick": -1, "stage": 0}


# A Warden's or Brindle's posture bar reaching a stagger.
func _on_posture(_enemy, _posture: float, staggered: bool) -> void:
	if not staggered:
		return
	_need("boss_staggered" if _game.flow.state_name() == "boss" else "warden_staggered")


# --scrap-at: the run's one death, in stage 1, from a chaser so RUN OVER has a cause to name.
func _scrap_if_due() -> void:
	if _scrapped or not _settings.has("scrap-at") or _game.run.stage != 1 or not _game.flow.in_play():
		return
	if _game.run.stage_time < float(_settings["scrap-at"]):
		return
	_scrapped = true
	for i in 3:
		if _game.run.alive():
			_game.run.damage(1.0e6, "chaser")


func _watch() -> void:
	# The lesson after a death is RUN OVER itself: the line naming what scrapped you and Run again.
	var screens = _game.get("screens")
	if _game.flow.state_name() == "summary" and not _game.flow.run_won and screens != null \
			and _game.flow.death_cause != "" and screens.button_for("again") != null:
		_teach("screen:run_over")
	if _game.hud != null and _game.flow.in_play():
		var id: String = _game.hud.objective_reading()["id"]
		if id != "":
			_teach("objective:" + id)
		_watch_fields()


# The field-rule needs, read off the live state a tick at a time (not off field_tips.gd's own rules).
func _watch_fields() -> void:
	var player = _game.player
	if player.state.carving:
		_need("grip_used")
	if player.abilities.jams > _jams:
		_need("jam_hit")
	_jams = player.abilities.jams
	if player.abilities.casting != "":
		_need("cast_started")
	var deck = _game.get("radio_deck")
	if deck != null and deck.dial != null and deck.dial.is_visible_in_tree():
		_need("radio_live")
	var interact = _game.ctx.root.get_node_or_null("Interact")
	if interact != null:
		for device in interact.devices:
			if is_instance_valid(device) and device.has_method("terms") and "relay" in device and device.relay != null \
					and device.reach_point().distance_to(player.ball_position()) <= RELAY_MET:
				_need("relay_met")
	var rack = _game.combat.get("actives") if _game.get("combat") != null else null
	if rack != null and rack.active_id != "":
		_need("active_racked")


func _teach(id: String) -> void:
	if not _taught.has(id):
		_taught[id] = {"tick": _tick, "stage": _stage}


func _need(id: String) -> void:
	if not _needed.has(id):
		_needed[id] = {"tick": _tick, "stage": _stage, "what": NEEDS[id]}


func _finish(outcome: String) -> void:
	_done = true
	var report := {
		"tool": "first_timer", "seed": int(_settings.get("seed", "1")), "pilot": _pilot,
		"stages": int(_settings.get("stages", "2")), "ticks": _tick, "tick_hz": Engine.physics_ticks_per_second,
		"stage_reached": _game.run.stage, "outcome": outcome, "card": _card, "taught": _taught, "needed": _needed,
	}
	var file := FileAccess.open(_out, FileAccess.WRITE)
	if file == null:
		printerr("first_timer: cannot write %s" % _out)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	DirAccess.remove_absolute(_game.run_store_path)
	print("first_timer: %s seed %d -> stage %d, %d ticks, %s" % [_pilot, report["seed"], report["stage_reached"], _tick, _out])
	quit(0)
