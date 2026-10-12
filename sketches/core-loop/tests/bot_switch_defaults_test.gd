extends SceneTree

const Options := preload("res://tools/bot_options.gd")
const Sweep := preload("res://tools/posture_sweep.gd")
const Music := preload("res://src/presentation/music_engine.gd")
const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	var t := T.new("bot_switch_defaults_test")
	var normal := {}
	Options.configure(normal)
	var disabled := {"gate": "0"}
	Options.configure(disabled)
	for key in Options.FAST_FLAGS:
		t.eq("%s defaults off without a bot gate" % key, normal.get(key, "0"), "0")
		t.eq("%s defaults off with gate disabled" % key, disabled.get(key, "0"), "0")
	var gate := {"gate": "1"}
	Options.configure(gate)
	for key in Options.FAST_FLAGS:
		t.eq("%s defaults on in the bot gate" % key, gate.get(key), "1")
	var explicit := {"gate": "1"}
	for key in Options.FAST_FLAGS:
		explicit[key] = "0"
	Options.configure(explicit)
	for key in Options.FAST_FLAGS:
		t.eq("%s can be disabled for a replay baseline" % key, explicit[key], "0")
	var job := {"arm": "small", "seed": 2}
	var cell := {"plating": 90, "curve": 2.0, "ram_shatters": false}
	var off_args := Sweep.child_args(explicit, job, cell, 120.0, "user://launch-check")
	t.check("sweep retains the bot gate", off_args.has("--gate=1"))
	for arg in ["--bot-no-mix=0", "--bot-no-visuals=0", "--bot-no-pilot-tracks=0"]:
		t.check("sweep forwards explicit off " + arg, off_args.has(arg))
	var single_args := Sweep.child_args({"bot-no-visuals": "1"}, job, cell, 120.0, "user://launch-check")
	t.check("sweep forwards one switch without a gate", single_args.has("--bot-no-visuals=1"))
	t.check("sweep does not add a gate or other switches", not single_args.has("--gate=1")
		and not single_args.has("--bot-no-mix=1") and not single_args.has("--bot-no-pilot-tracks=1"))
	t.check("sweep retains child cap and gameplay arguments", single_args.has("--cap=120.0")
		and single_args.has("--run-seed=2") and single_args.has("--plating=90")
		and single_args.has("--curve=2.0") and single_args.has("--shatter=false"))
	var music := Music.new()
	t.eq("normal music engine samples remain enabled", music.bot_skip_samples, false)
	quit(t.verdict())
