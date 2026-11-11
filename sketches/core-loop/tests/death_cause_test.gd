extends SceneTree

const Game := preload("res://src/game.gd")
const DeathCause := preload("res://src/core/death_cause.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# RUN OVER names what scrapped you (core/death_cause.gd; wave 27 first-timer red team, note 2).
#   (a) the line per source: a body's one attack row, a boss's row and phase, a rogue fleet
#       machine's landed attack under its name, sources with no row, and a stale attack id
#       from another body ignored.
#   (b) the game's path (a run store on, so a death goes straight to the summary): the rogue
#       crane's leaf drop scraps the ball; combat files E35 on its hit, flow keeps the line and
#       RUN OVER shows it under the pilot with Run again. A new run clears it.

const DIR := "user://death_cause_test/"
const PATH := DIR + "run.json"

var _t := T.new("death_cause_test")
var _game


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_run.call_deferred()


func _run() -> void:
	_lines()
	await _game_path()
	DirAccess.remove_absolute(PATH)
	quit(_t.verdict())


func _lines() -> void:
	_t.eq("a crew's one row", DeathCause.line("chaser"), "Scrapped by a chaser lunge.")
	_t.eq("an article before a vowel", DeathCause.line("anchor_crew"), "Scrapped by an anchor crew winch.")
	_t.eq("a boss row with its phase", DeathCause.line("brindle_charge", "", "phase 2"), "Scrapped by Brindle's scuttle charge, phase 2.")
	_t.eq("Brindle's slag", DeathCause.line("brindle_slag", "", "phase 3"), "Scrapped by Brindle's furnace slag, phase 3.")
	_t.eq("the Mind's hand", DeathCause.line("mind_hand"), "Scrapped by the Mind's hand strike.")
	_t.eq("a boss family with no row", DeathCause.line("waking_slam", "", "phase 1"), "Scrapped by the Waking's slam, phase 1.")
	_t.eq("a rogue's landed attack under its name", DeathCause.line("rogue_crane", "E35"), "Scrapped by Gate Crane No. 14's leaf drop.")
	_t.eq("a rogue with no attack named", DeathCause.line("rogue_crane"), "Scrapped by Gate Crane No. 14.")
	_t.eq("the miniboss names the attack that landed", DeathCause.line("miniboss", "E04"), "Scrapped by a drop hammer charge.")
	_t.eq("two rows and no attack name none", DeathCause.line("miniboss"), "Scrapped by a miniboss.")
	_t.eq("an attack from another body is ignored", DeathCause.line("chaser", "E35"), "Scrapped by a chaser lunge.")
	_t.eq("the Warden", DeathCause.line("warden"), "Scrapped by the Warden.")
	_t.eq("the Warden's counter", DeathCause.line("warden_counter"), "Scrapped by the Warden's counter-pulse.")
	_t.eq("a hazard", DeathCause.line("silt_boil"), "Scrapped by a silt boil.")
	_t.eq("a phase only follows a boss's own hit", DeathCause.line("chaser", "", "phase 2"), "Scrapped by a chaser lunge.")
	_t.eq("no source, no line", DeathCause.line(""), "")
	_t.eq("a body whose row is not every hit reads by name", DeathCause.line("plated_brute"), "Scrapped by a plated brute.")
	var brindle := preload("res://src/boss/boss.gd").new()
	brindle.phase = 2
	_t.eq("Brindle's phase off the module", DeathCause.phase_note(brindle), "phase 2")
	brindle.phase = brindle.CHASE_PHASE
	_t.eq("Brindle's scooter", DeathCause.phase_note(brindle), "in the chase")
	brindle.phase = 0
	_t.eq("no phase before the fight", DeathCause.phase_note(brindle), "")
	brindle.free()


func _game_path() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.run_store_path = PATH
	root.add_child(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	await _frames(2)
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(5)
	var crane = _game.combat.spawn_enemy("rogue_crane", _game.player.ball_position() + Vector3(0.0, 0.0, 12.0))
	await _frames(2)
	_game.run.hp = 1.0
	crane.attack = "drop"
	crane._land(Vector3.ZERO)
	_t.eq("combat files the landed attack", String(_game.combat.last_player_hit.get("attack", "")), "E35")
	await _frames(2)
	var screens = _game.screens
	var line := "Scrapped by Gate Crane No. 14's leaf drop."
	_t.eq("the run is over", _game.flow.state_name(), "summary")
	_t.eq("flow keeps the line", _game.flow.death_cause, line)
	_t.eq("RUN OVER", screens._title.text, "RUN OVER")
	var body: String = screens.body_text()
	_t.check("RUN OVER names it under the pilot", body.split("\n").size() > 1 and body.split("\n")[1] == line, body.replace("\n", " | "))
	_t.check("Run again is on the screen", screens.button_for("again") != null)
	_game.flow.new_run()
	await _frames(3)
	_t.eq("a new run clears it", _game.flow.death_cause, "")
	_game.free()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
