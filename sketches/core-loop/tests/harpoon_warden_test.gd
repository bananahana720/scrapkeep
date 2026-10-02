extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WardenDrop := preload("res://src/combat/warden_drop.gd")
const Augments := preload("res://src/movement/augments.gd")

# The harpoon at the Warden (--loop=drop --gun=hold, DESIGN-NOTES "Harpoon and
# winch"); warden.gd and warden_drop.gd are untouched, so this proves the drop rule reads a line
# smash like any other arrival:
#   camper      from the bowl floor the pilot latches the Warden and commits the haul across several
#               open windows. Every smash lands (the Warden is immovable, so the ball flies in), the
#               verdict is `floor`, the Warden takes 0 and the clank (strike_deflected) says why.
#   finisher    a ball that was beyond 50 m within 6 s, above the open core and line-smashed onto the top
#               cap at 20 m/s or more descending, gets the verdict `drop`: the harpoon is a drop
#               finisher, not a bypass and not a block.
# Evidence limit: contacts are real physics from placed starts and a fixed camera, not a player's
# run, and the camper is a script; the bots' camper is loop_camper_test's harpoon arm. Whether a
# shelf haul at 24 m/s is a fair drop is a play question.

const OUT := 58.0
const BOWL := 20.0
const CAMPER_ATTEMPTS := 4
const MIN_SMASHES := 3

var _game
var _player
var _warden
var _drop
var _source := Intent.Scripted.new()
var _failures := 0
var _counts := {"harpoon_smashed": 0, "strike_deflected": 0, "warden_drop_landed": 0, "slammed": 0}
var _landed_contact := {}


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


# The family cycle is parked so a natural pulse never lands in the middle of a case.
func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		if is_instance_valid(_warden):
			_warden._pulse_clock = 0.0
			_warden._charging = false
		await physics_frame


func _mast() -> Vector3:
	return _warden.global_position


func _top() -> Vector3:
	return _warden.global_position + Vector3.UP * _warden.HALF_HEIGHT


func _ground(out: float) -> Vector3:
	return _game.ctx.terrain.drop_point(_mast().x + out, _mast().z, 1.5)


func _cam(from: Vector3, to: Vector3) -> void:
	_game.camera.set_process(false)
	_game.camera.cam.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


# on_struck ledgers a contact before it lands the drop, so this is the contact that landed it.
# The smash's own shockwave strikes again in the same frame, so polling last_contact reads that.
func _on_drop_landed(_at: Vector3, _speed: float, _left: int, _n: int) -> void:
	_counts["warden_drop_landed"] += 1
	if _drop != null:
		_landed_contact = _drop.last_contact.duplicate()


func _open() -> void:
	if _warden._open_left <= 0.0:
		_warden._open(_warden.CORE_WINDOW)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_game.tuning.set_option("loop_mode", "drop")
	_game.tuning.set_option("gun_role", "hold")
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.events.harpoon_smashed.connect(func(_e: Node3D, _at: Vector3, _speed: float): _counts["harpoon_smashed"] += 1)
	_game.events.strike_deflected.connect(func(_e: Node3D, _kind: String, _punch: float, _plating: float): _counts["strike_deflected"] += 1)
	_game.events.warden_drop_landed.connect(_on_drop_landed)
	_game.events.slammed.connect(func(_at: Vector3, _strength: float, _flatness: float): _counts["slammed"] += 1)
	await _sim(0.4)
	_game.run.set_max_hp(99999.0)
	_game.ctx.spawner.heft_override = 1.0
	_warden = _game.flow.warden
	_drop = _warden.get("drop") if is_instance_valid(_warden) else null
	_report("drop rules", _drop != null and _player.kit.on(Augments.GRAPPLE), "stage 1 Warden carries warden_drop.gd and Rivet fits the harpoon (%s)" % _player.kit.on(Augments.GRAPPLE))
	if _drop == null:
		quit(1)
		return
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()

	await _camper()
	await _finisher()

	print("harpoon_warden_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


# Latches the Warden from where the ball stands and commits the haul; returns whether it landed.
func _smash_from(start: Vector3, eye_back: Vector3, velocity := Vector3.ZERO) -> bool:
	var landed_before: int = _counts["harpoon_smashed"]
	_player.reset_to(start, velocity)
	_cam(start + eye_back + Vector3(0, 0.8, 0), _mast())
	_source.hold = {"harpoon_held": true}
	_source.press = {"harpoon_pressed": true}
	await _sim(0.05)
	var latched: bool = _player.kit.hooked and _player.kit.anchor_body == _warden
	if not latched:
		return false
	_source.hold = {"harpoon_held": true, "brake_held": true}
	for tick in roundi(2.0 * Engine.physics_ticks_per_second):
		await physics_frame
		if _counts["harpoon_smashed"] > landed_before:
			break
	_source.hold = {}
	await _sim(0.4)
	return _counts["harpoon_smashed"] > landed_before


func _camper() -> void:
	_player.reset_to(_ground(BOWL))
	await _sim(WardenDrop.DROP_MEMORY + 0.3)
	var hp: float = _warden.hp
	var windows_before: int = _drop.windows
	var locked := 0
	for attempt in CAMPER_ATTEMPTS:
		_warden._open_left = 0.0
		_open()
		_drop._rearm = 0.0
		var away := (_ground(BOWL) - _mast()).normalized() * 4.0
		if await _smash_from(_ground(BOWL), away):
			locked += 1
	var d: Dictionary = _drop.damage
	_report("camper deals 0", _warden.hp == hp and _drop.drops_landed == 0 and _drop.staggers == 0 and d["drop"] == 0.0 and d["gun"] == 0.0,
		"%d harpoon smashes from the bowl floor over %d windows: Warden %.0f / %.0f HP, drops %d, staggers %d" % [locked, _drop.windows - windows_before, _warden.hp, _warden.max_hp, _drop.drops_landed, _drop.staggers])
	_report("camper is not vacuous", locked >= MIN_SMASHES and _drop.windows - windows_before >= MIN_SMASHES and _counts["harpoon_smashed"] >= MIN_SMASHES,
		"%d smashes landed on the Warden (need %d) across %d open windows" % [locked, MIN_SMASHES, _drop.windows - windows_before])
	_report("the clank says why", _counts["strike_deflected"] >= MIN_SMASHES and _drop.last_contact.get("verdict") == "floor",
		"%d strike_deflected, last contact verdict %s (from a line %s)" % [_counts["strike_deflected"], _drop.last_contact.get("verdict"), _drop.last_contact.get("from_line")])


func _finisher() -> void:
	_player.reset_to(_ground(OUT))
	await _sim(0.3)
	_warden._open_left = 0.0
	_open()
	_drop._rearm = 0.0
	_drop._dropped = false
	var hp: float = _warden.hp
	var drops_before: int = _counts["warden_drop_landed"]
	var smashed_before: int = _counts["harpoon_smashed"]
	_player.reset_to(_top() + Vector3(-6.0, 6.0, 0.0))
	var bite := _top()
	_player.grapple_to(bite, Vector3.UP, _warden)
	_source.hold = {"harpoon_held": true}
	await _sim(0.02)
	_source.hold = {"harpoon_held": true, "brake_held": true}
	var arrived := false
	_landed_contact = {}
	for tick in roundi(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if _counts["harpoon_smashed"] > smashed_before:
			arrived = true
			break
	_source.hold = {}
	await _sim(0.3)
	var c := _landed_contact
	_report("finisher gets the drop", arrived and c.get("verdict") == "drop" and _counts["warden_drop_landed"] == drops_before + 1 and _warden.hp < hp,
		"line smash from beyond %.0f m onto the top cap: verdict %s at %.1f m/s (min %.0f), Warden %.0f -> %.0f HP, drops landed %d"
			% [WardenDrop.LINE_REACH, c.get("verdict"), c.get("speed", 0.0), WardenDrop.DROP_MIN_SPEED, hp, _warden.hp, _counts["warden_drop_landed"] - drops_before])
