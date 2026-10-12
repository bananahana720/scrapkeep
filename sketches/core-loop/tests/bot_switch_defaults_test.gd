extends SceneTree

const Options := preload("res://tools/bot_options.gd")
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
	var music := Music.new()
	t.eq("normal music engine samples remain enabled", music.bot_skip_samples, false)
	quit(t.verdict())
