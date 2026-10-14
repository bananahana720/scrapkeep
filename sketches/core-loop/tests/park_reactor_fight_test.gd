# smoke: bots timeout=900s
extends "res://tools/bot_run.gd"

const T := preload("res://tests/support/t.gd")
const Arena := preload("res://tests/posture_bands_reactor_test.gd")

var checked_note: Dictionary = {}
var checked_map := ""

# A real skipper run, using the shipping park and hands. This seed reproduces the mounted
# reactor's missing rolling approach; the four-seed median belongs to the writer's bot table.
func _initialize() -> void:
	SimClock.ticks = true
	_settings = _parse(OS.get_cmdline_user_args())
	_bot_options = BotOptions.new(_settings, self)
	_settings["policy"] = "skipper"
	_settings["from-stage"] = "1"
	_settings["stages"] = "1"
	_out = _absolute(String(_settings.get("out", OS.get_user_data_dir().path_join("park-reactor-fight"))))
	DirAccess.make_dir_recursive_absolute(_out)
	_seeds = [1]
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
		var seconds:=float(broken)-float(engaged)
		t.check("mounted reactor fight fits the arena allowance",seconds<=1.5*Arena.EXPECT_GROWN_S,"engage-to-break %.2fs, allowance %.2fs" % [seconds,1.5*Arena.EXPECT_GROWN_S])
	quit(t.verdict())
