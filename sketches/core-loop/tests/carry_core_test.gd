extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Shop := preload("res://src/build/shop.gd")
const ShopCounter := preload("res://src/ui/shop_counter.gd")
const Companion := preload("res://src/core/companion.gd")

# Carry a core in SPIL-9 (docs/systems-audit/feature-fit.md, new mechanic 3; Andrew 11 Nov 2026
# 19:24Z: one carried core, only into SPIL-9), in the running game as Rivet in calm:
#   - flag off: no plate on Moss's counter, the verb is shut, and the entrance doc has no key;
#   - flag on: the plate stows one of this stage's cores, a full SPIL-9 gives up its last piece
#     (still owned), and a second stow is refused;
#   - a retry's rewind returns the core and reseats the piece; the entrance doc carries a ride;
#   - the next stage entry turns the ride into one of that stage's cores (the gate counts it)
#     and reseats the piece.

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
	model.assemble(["primer_coil", "escape_vent"])
	run.companion = model.to_dict()
	run.add_core("test", Vector3.ZERO)
	run.add_core("test", Vector3.ZERO)
	var stage: int = run.stage
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)

	var counter := ShopCounter.new()
	counter.setup(_game)
	_game.hud.add_child(counter)
	shop.enter()
	counter.open(shop, 0.0)
	_check("off", counter.tile_for("stow") == null and shop.stow_core()["reason"] == Shop.LOCKED and not run.to_entrance_doc().has("carried_core"),
		"flag off: no plate, verb locked, no doc key")

	tuning.apply_args(PackedStringArray(["--carry-core=on"]), "launch")
	counter.refresh()
	var plate = counter.tile_for("stow")
	_check("plate", plate != null and plate.state() == "ok", "stow plate %s" % (plate.rec if plate != null else {}))
	if plate != null:
		counter.press(plate)
	var seated: Array = run.companion.get("sockets", [])
	_check("stowed", run.carried_core == 1 and run.bonus_cores == 1 and seated.size() == Companion.SOCKETS - 1
		and String(run.companion.get("core_seat", "")) != "" and (run.companion.get("owned", []) as Array).size() == 2,
		"carried %d, cores %d, sockets %s, unseated %s" % [run.carried_core, run.bonus_cores, seated, run.companion.get("core_seat", "")])
	counter.refresh()
	var again: Dictionary = shop.stow_core()
	_check("one only", not bool(again["ok"]) and again["reason"] == Shop.CAPPED and counter.tile_for("stow").state() == "spent",
		"second stow: %s" % again["reason"])

	var doc: Dictionary = run.to_entrance_doc()
	_check("doc", int(doc.get("carried_core", 0)) == 1 and run.validate_entrance_doc(doc) == "", "entrance doc carried_core %s" % doc.get("carried_core"))

	# A retry rewinds the stow.
	run.restore()
	_check("retry rewinds", run.carried_core == 0 and run.bonus_cores == 2 and (run.companion.get("sockets", []) as Array).size() == Companion.SOCKETS
		and not run.companion.has("core_seat"), "after restore: carried %d, cores %d, sockets %s" % [run.carried_core, run.bonus_cores, run.companion.get("sockets")])

	# Stow again and cross into the next stage.
	shop.enter()
	shop.stow_core()
	run.enter_stage(stage + 1)
	_check("arrives", run.carried_core == 0 and run.bonus_cores == 1 and run.gate_tier_bonus() == 1
		and (run.companion.get("sockets", []) as Array) == ["primer_coil", "escape_vent"] and not run.companion.has("core"),
		"stage %d: cores %d, gate bonus %d, sockets %s" % [run.stage, run.bonus_cores, run.gate_tier_bonus(), run.companion.get("sockets")])
	shop.leave()
	counter.close()
