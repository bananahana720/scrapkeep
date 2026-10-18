extends Node

# --self-play (src/game.gd): a skipper bot plays the launched game from its title through stage 1
# into the stage swap, so `npm run sketch:frametime -- --self-play` can log the swap unattended
# (SWAP-HITCH-6). Only packs that carry tools/ have it: `npm run sketch:export -- --self-play`.
# It prints "self-play: stage 2 entered at <s> s" (seconds since launch), keeps playing for
# --self-play-hold=<s> (default 30) and until --self-play-min=<s> since launch, then quits 0.
# A run that ends before stage 2 quits 1. --self-play-seed=<n> (default 1) and
# --self-play-pilot=<id> pick the run.

const BotDriver := preload("res://tools/bot_driver.gd")

var game: Node
var _driver
var _swap_at := -1.0
var _hold := 30.0
var _min := 0.0
var _seed := 1
var _pilot := ""


func _ready() -> void:
	# Run before Game each tick, as bot_run does, so the bot's intent is read the same tick.
	process_physics_priority = -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--self-play-hold="):
			_hold = float(arg.trim_prefix("--self-play-hold="))
		elif arg.begins_with("--self-play-min="):
			_min = float(arg.trim_prefix("--self-play-min="))
		elif arg.begins_with("--self-play-seed="):
			_seed = int(arg.trim_prefix("--self-play-seed="))
		elif arg.begins_with("--self-play-pilot="):
			_pilot = arg.trim_prefix("--self-play-pilot=")


func _physics_process(delta: float) -> void:
	if game.flow == null:
		return
	if _driver == null:
		_driver = BotDriver.new(game, "skipper", _seed)
		if _pilot != "":
			_driver.class_index = BotDriver.class_index_for(_seed, _pilot)
		game.run.run_seed_override = _seed
		game.events.stage_entered.connect(_on_stage_entered)
		_driver.start(false)
		print("self-play: skipper seed %d started at %.2f s" % [_seed, _now()])
		return
	if _driver.tick(delta) and _swap_at < 0.0:
		print("self-play: run ended '%s' before stage 2 at %.2f s" % [_driver.outcome, _now()])
		get_tree().quit(1)
		return
	if _swap_at >= 0.0 and _now() >= maxf(_swap_at + _hold, _min):
		print("self-play: done at %.2f s" % _now())
		get_tree().quit(0)


func _on_stage_entered(stage: int, _retry := false) -> void:
	if stage == 2 and _swap_at < 0.0:
		_swap_at = _now()
		print("self-play: stage 2 entered at %.2f s" % _swap_at)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
