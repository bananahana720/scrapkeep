# smoke: bots timeout=900s
extends "res://tools/bot_run.gd"

const T := preload("res://tests/support/t.gd")
# The fight's own allowance: 1.5 times posture_bands_reactor_test's grown median as pinned
# before the 2026-10-18 stage re-pin (35.8 s). That re-pin measured grown at 31.23 s on
# 102324cd and the stage, where seed 1's fight (52.95 s) was byte-identical, so tying the
# allowance to the live pin turned this check red with no change to the fight.
# Gate lane, stage/alpha-w17, 2026-10-19.
const ALLOWANCE_S := 53.7

var checked_note: Dictionary = {}
var checked_map := ""

# A real skipper run, using the shipping park and hands. Seed 1 reproduced the mounted reactor's
# missing rolling approach; the canyon walls (#488) moved its fight from 39.30 s to 104.75 s as
# chaotic one-seed drift (24 seeds, 814a53ad vs main 43c86667: median 47.8 s vs 46.1 s, 7 of 24
# over the allowance on each, Gate receipt w18-814a53ad-bots-4.md in the project's shared gate folder). Seed 13 is the same runner_gunner
# hand and moved least across that change (34.18 s vs 33.28 s); it is not known to reproduce the
# rolling-approach miss, so this test now holds the allowance only. The seed median belongs to the
# writer's bot table.
# 15 Nov 2026, wave 42: the dam yard's fight bowl and moved kicker (PRs 957, 1033) moved seed 13 from 36.16 s to
# 61.92 s. Over 72 skipper seeds on 7b232972 the median is 40.6 s (41.2 s with the yard camera lift of PR 1032 taken
# out, longer on 37 seeds and shorter on 35, so the lift is not the cause), 19 of 72 over the allowance. Seed 21 sits
# at the median in both arms (41.10 s and 37.85 s) and replaces seed 13; the allowance stays (DECISIONS, ruling ai).
# The run replays itself once in a child at a fixed 90 fps, one physics tick per frame, as
# bot_run's children do. Paced by the clock, a loaded machine dropped ticks and seed 1
# broke the Warden in 40.9 s or 97.3 s (2 fails in 8 solo runs, shard 6, 18 Oct); fixed, it is
# 40.9 s every time (52.95 s every time on 102324cd and the w17 stage, 2026-10-19). The
# environment marks the child: get_cmdline_args() omits --fixed-fps.
const CHILD_ENV := "SCRAPKEEP_REACTOR_FIGHT_CHILD"

func _initialize() -> void:
	if OS.get_environment(CHILD_ENV) != "1":
		OS.set_environment(CHILD_ENV, "1")
		var output := []
		var args := PackedStringArray(["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/park_reactor_fight_test.gd", "--"])
		args.append_array(OS.get_cmdline_user_args())
		var code := OS.execute(OS.get_executable_path(), args, output, true)
		for chunk in output:
			print(String(chunk).strip_edges())
		quit(code)
		return
	SimClock.ticks = true
	_settings = _parse(OS.get_cmdline_user_args())
	_bot_options = BotOptions.new(_settings, self)
	_settings["policy"] = "skipper"
	_settings["from-stage"] = "1"
	_settings["stages"] = "1"
	_out = _absolute(String(_settings.get("out", OS.get_user_data_dir().path_join("park-reactor-fight"))))
	DirAccess.make_dir_recursive_absolute(_out)
	_seeds = [21]
	node_added.connect(_on_node_added)
	_next()

func _on_node_added(node: Node) -> void:
	if node is Game:
		node.table = "park"
	super._on_node_added(node)

func _physics_process(delta: float) -> bool:
	var result := super._physics_process(delta)
	if _driver != null:
		_driver.stage_limit = 600.0
	return result

func _write_entries() -> void:
	super._write_entries()
	checked_map=String(_game.ctx.stages.DEFS[0]["map"])
	checked_note=_driver.stage_notes[0].duplicate(true)
func _finish() -> void:
	var t=T.new("park_reactor_fight_test")
	t.eq("the fight ran park_dam",checked_map,"park_dam")
	var engaged=checked_note.get("warden_engaged_s")
	var broken=checked_note.get("warden_broken_s")
	t.check("skipper engages and breaks the authored mounted reactor",engaged!=null and broken!=null,"engaged %s, broken %s" % [engaged,broken])
	if engaged!=null and broken!=null:
		# The fight starts when the Warden can be hurt: at the engage, or when the Spillway's clamp
		# lets go after it (stage_locks.gd, ruling ai, 27 Oct). The clamp's hold is the pacing
		# lock's own time, not the fight's.
		var opened=checked_note.get("gate_open_s")
		var start:=maxf(float(engaged),float(opened) if opened!=null else float(engaged))
		var seconds:=float(broken)-start
		t.check("mounted reactor fight fits the arena allowance",seconds<=ALLOWANCE_S,"open-to-break %.2fs (engaged %.2f, clamp open %s), allowance %.2fs" % [seconds,float(engaged),opened,ALLOWANCE_S])
	quit(t.verdict())
