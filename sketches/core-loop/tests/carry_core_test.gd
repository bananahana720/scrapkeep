extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Shop := preload("res://src/build/shop.gd")
const ShopCounter := preload("res://src/ui/shop_counter.gd")
const Companion := preload("res://src/core/companion.gd")
const CompanionPanel := preload("res://src/ui/companion_panel.gd")

# Carry a core in SPIL-9 (docs/systems-audit/feature-fit.md, new mechanic 3; Andrew 11 Nov 2026
# 19:24Z: one carried core, only into SPIL-9), in the running game as Rivet in calm:
#   - flag off: no plate on Moss's counter, the verb is shut, and the entrance doc has no key;
#   - flag on: the plate shows the piece it unseats, stows one of this stage's cores, a full
#     SPIL-9 gives up its last piece (still owned), and a second stow is refused;
#   - the ride is run state, never the companion doc: the panel cannot refill the held socket and
#     its save keeps the ride, a found piece keeps it, and the profile gets the whole companion;
#   - a retry's rewind returns the core and reseats the piece;
#   - the next stage entry turns the ride into one of that stage's cores (the gate counts it)
#     and reseats the piece; that core cannot ride again, a Continue to that stage's entrance
#     keeps it, and the stage after drops it.

const RIVET := 1

var _game
var _failures := 0
var _ticks := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.player.source = Intent.Scripted.new()
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(RIVET)
	elif _ticks == 30:
		_run_checks()
		print("carry_core_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
		quit(0 if _failures == 0 else 1)
		return true
	return false


func _run_checks() -> void:
	var run = _game.run
	var shop = _game.ctx.build.shop
	var tuning = _game.tuning
	var model := Companion.new()
	model.acquire("primer_coil")
	model.acquire("escape_vent")
	model.acquire("ram_prow")
	model.assemble(["primer_coil", "escape_vent"])
	run.companion = model.to_dict()
	var whole: Dictionary = run.companion.duplicate(true)
	run.add_core("test", Vector3.ZERO)
	run.add_core("test", Vector3.ZERO)
	var stage: int = run.stage
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)

	var counter := ShopCounter.new()
	counter.setup(_game)
	_game.hud.add_child(counter)
	shop.enter()
	counter.open(shop, 0.0)
	_check("off", counter.tile_for("stow") == null and shop.stow_core()["reason"] == Shop.LOCKED and not run.to_entrance_doc().has("arrived_core"),
		"flag off: no plate, verb locked, no doc key")

	tuning.apply_args(PackedStringArray(["--carry-core=on"]), "launch")
	counter.refresh()
	var plate = counter.tile_for("stow")
	_check("plate", plate != null and plate.state() == "ok" and String(plate.rec.get("seat_icon", "")) == CompanionPanel.PIECE_ICONS["escape_vent"],
		"stow plate %s" % (plate.rec if plate != null else {}))
	if plate != null:
		counter.press(plate)
	var seated: Array = run.companion.get("sockets", [])
	_check("stowed", run.carried_core == 1 and run.bonus_cores == 1 and seated == ["primer_coil"] and run.core_seat == "escape_vent"
		and (run.companion.get("owned", []) as Array).size() == 3 and run.companion.keys() == whole.keys(),
		"carried %d, cores %d, sockets %s, unseated %s, doc keys %s" % [run.carried_core, run.bonus_cores, seated, run.core_seat, run.companion.keys()])
	counter.refresh()
	var again: Dictionary = shop.stow_core()
	_check("one only", not bool(again["ok"]) and again["reason"] == Shop.CAPPED and counter.tile_for("stow").state() == "spent",
		"second stow: %s" % again["reason"])

	# The companion panel during the ride: the held socket shows the core, a piece cannot fill it,
	# and the panel's save leaves the ride as it was.
	var panel := CompanionPanel.new()
	panel.setup(_game)
	_game.hud.add_child(panel)
	panel.open()
	panel.pick(panel.model.owned.find("ram_prow"))
	panel.close()
	_check("panel", panel.socket_icons()[1] == "res_core" and run.companion.get("sockets", []) == ["primer_coil"] and run.carried_core == 1 and run.core_seat == "escape_vent",
		"after a panel pick: sockets %s, carried %d, icons %s" % [run.companion.get("sockets"), run.carried_core, panel.socket_icons()])
	# A found piece rewrites the doc (activities.gd _pay_piece); the ride is untouched.
	run.companion = Companion.with_piece(run.companion, "primer_mesh")
	_check("found piece", run.carried_core == 1 and run.core_seat == "escape_vent", "carried %d, seat %s" % [run.carried_core, run.core_seat])
	# The profile keeps the whole companion, never the ride.
	_game.flow._persist_companion()
	var kept: Dictionary = _game.ctx.profile.companion() if _game.ctx.profile != null else {}
	_check("profile whole", (kept.get("sockets", []) as Array) == ["primer_coil", "escape_vent"],
		"profile sockets %s" % [kept.get("sockets")])

	# A retry rewinds the stow.
	run.restore()
	_check("retry rewinds", run.carried_core == 0 and run.bonus_cores == 2 and run.core_seat == ""
		and (run.companion.get("sockets", []) as Array) == ["primer_coil", "escape_vent"],
		"after restore: carried %d, cores %d, sockets %s" % [run.carried_core, run.bonus_cores, run.companion.get("sockets")])

	# Stow again and cross into the next stage.
	shop.enter()
	shop.stow_core()
	run.enter_stage(stage + 1)
	_check("arrives", run.carried_core == 0 and run.bonus_cores == 1 and run.arrived_core == 1 and run.gate_tier_bonus() == 1
		and (run.companion.get("sockets", []) as Array) == ["primer_coil", "escape_vent"],
		"stage %d: cores %d, gate bonus %d, sockets %s" % [run.stage, run.bonus_cores, run.gate_tier_bonus(), run.companion.get("sockets")])
	counter.refresh()
	_check("rides once", not run.can_stow_core() and shop.stow_core()["reason"] == Shop.CANT_AFFORD and counter.tile_for("stow").state() == "poor",
		"the arrived core: %s" % shop.stow_core()["reason"])
	run.add_core("test", Vector3.ZERO)
	_check("own core rides", run.can_stow_core(), "a core of this stage can still ride")

	# A Continue to this stage's entrance keeps the arrived core.
	run.bonus_cores = 1
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	var doc: Dictionary = JSON.parse_string(JSON.stringify(run.to_entrance_doc()))
	run.bonus_cores = 0
	run.arrived_core = 0
	var loaded: bool = run.from_entrance_doc(doc)
	run.enter_stage(run.stage)
	_check("continue keeps", loaded and run.validate_entrance_doc(doc) == "" and int(doc.get("arrived_core", 0)) == 1 and run.bonus_cores == 1 and run.arrived_core == 1,
		"loaded %s: doc arrived %s, cores %d" % [loaded, doc.get("arrived_core"), run.bonus_cores])

	# The stage after, with nothing riding, starts with no core.
	run.enter_stage(run.stage + 1)
	_check("stage after", run.bonus_cores == 0 and run.arrived_core == 0, "stage %d: cores %d" % [run.stage, run.bonus_cores])
	shop.leave()
	counter.close()
