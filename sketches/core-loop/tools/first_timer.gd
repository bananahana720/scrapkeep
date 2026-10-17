extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

# The FIRST-TIMER probe (alpha-status ambition map, unit 8). One headless bot run on a fresh
# profile records the first tick each teaching surface is on screen and the first tick each
# mechanic is needed or used. It judges nothing: scripts/first-timer.mjs holds the mechanic
# table and fails a mechanic that is needed before it is taught.
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/first_timer.gd \
#     -- --out=<file.json> [--seed=1] [--pilot=<class id>] [--stages=2]
#
# --stages=2 ends the run as it leaves world 1 (both Spillway stages and Brindle). Test mode
# gives every process its own data folder, so the key prompts start from an empty profile.
#
# Teach ids, with the tick they first show (tick -1 is before play):
#   prompt:<verb>     a key prompt drew (events.prompt_shown, ui/key_glyphs.gd)
#   objective:<id>    the objective plate's row (hud.objective_reading, core/objectives.gd)
#   screen:dead       the SCRAPPED screen and its Retry key
#   card:<slot>       a key on the chosen pilot's class card (ui/class_kit.gd card_keys)
# Need ids: the first tick of the bus fact or flow state that names them (NEEDS below).

const NEEDS := {
	"stage_entered": "first stage dropped in",
	"warden_engaged": "first Warden engaged",
	"warden_staggered": "first Warden stagger (core open)",
	"reward_offered": "first reward gates",
	"dead": "first death",
	"boss_arena_entered": "Brindle's arena",
	"boss_staggered": "first boss stagger",
	"harpoon_used": "first harpoon latch",
	"grapple_used": "first line on the world",
	"slam_used": "first slam",
	"bay_entered": "first time in Moss's bay",
	"scrap_collected": "first scrap",
}

var _settings := {}
var _game
var _driver
var _tick := 0
var _stage := 0
var _taught := {}
var _needed := {}
var _pilot := ""
var _card: Array = []
var _out := ""
var _done := false


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


func _watch() -> void:
	if _game.flow.state_name() == "dead":
		_need("dead")
		_teach("screen:dead")
	if _game.hud != null and _game.flow.in_play():
		var id: String = _game.hud.objective_reading()["id"]
		if id != "":
			_teach("objective:" + id)


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
