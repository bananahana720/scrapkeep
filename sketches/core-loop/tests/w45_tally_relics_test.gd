extends SceneTree

# W45-B2 U4 (design-v3/ABILITY-MUTATIONS.md sections 5 A and 8): Tally's two World 1 kit swaps.
# Ink Heart swaps the smash to stamp_ink: the stamp keeps flavour "stamp" (so base stamp pressure
# pay stays) and books every machine in its disc for 3.0 s with a ledger tick; a balance due
# strike on a booked machine takes the book and refills one pressure (the bank's cap of 3 holds),
# once per machine per stamp. Double Entry swaps the line to link_double: the same three-machine
# clip as link_clips, plus one jump of the clip, when the group settles, to the nearest
# unclipped machine within 9 m, once per cast and never again from the jumped machine. Each rule
# carries a planted control.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const Combat := preload("res://src/combat/combat.gd")
const Relics := preload("res://src/build/relics.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("w45_tally_relics_test")
var _game
var _combat
var _player
var _source := Intent.Scripted.new()
var _steps := []
var _index := 0
var _ticks := 0
var _booted := false
var _struck: Array = []
var _fired: Array = []


func _initialize() -> void:
	_check_table()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _booted:
		_boot()
		return false
	if _index >= _steps.size():
		quit(_t.verdict())
		return true
	var step: Array = _steps[_index]
	if _ticks == 0:
		(step[0] as Callable).call()
	_ticks += 1
	if _ticks >= int(step[1]):
		(step[2] as Callable).call()
		_index += 1
		_ticks = 0
	return false


func _boot() -> void:
	_booted = true
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_combat = _game.combat
	_player = _game.player
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, force: float): _struck.append([enemy.get_instance_id(), kind, force]))
	_game.events.line_skill_fired.connect(func(id: String, _target: Node3D, _at: Vector3, on: String): _fired.append([id, on]))
	_steps = [
		[_noop, 1, _check_ink_books],
		[_noop, 1, _check_ink_refill],
		[_noop, 1, _check_ink_expiry],
		[_noop, 1, _check_ink_clears],
		[_noop, 1, _check_double_clips],
		[_noop, 1, _check_double_jump],
		[_noop, 1, _check_double_far],
		[_noop, 1, _check_double_jam_and_audio],
	]


func _noop() -> void:
	pass


# --- the data: both relics, the words, the offer ---------------------------------------

func _check_table() -> void:
	_t.eq("the table validates", Relics.validate(), [])
	for id in ["ink_heart", "double_entry"]:
		var row := Relics.row(id)
		_t.check("%s is a World 1 Tally row" % id, int(row["world"]) == 1 and row["pilots"] == ["tally"],
			"world %s, pilots %s" % [row["world"], row["pilots"]])
		_t.check("%s name and text hold the caps" % id,
			String(row["name"]).split(" ", false).size() <= Relics.MAX_NAME_WORDS and String(row["text"]).split(" ", false).size() <= Relics.MAX_TEXT_WORDS,
			"%s / %s" % [row["name"], row["text"]])
		var swap := Relics.swap_of(id)
		_t.check("%s swaps to a row with a WORDS entry" % id, ClassKit.WORDS.has(swap) and AbilityState.ABILITIES.has(swap), swap)
		_t.eq("%s names its mutation after its swap" % id, AbilityState.ABILITIES[swap].get("mutation", ""), swap)
	_t.eq("ink heart is the smash swap", [Relics.slot_of("ink_heart"), Relics.swap_of("ink_heart"), Relics.row("ink_heart")["maker"], Relics.row("ink_heart")["name"]],
		[AbilityState.SMASH, "stamp_ink", "mind_glass", "Ink Heart"])
	_t.eq("double entry is the line swap", [Relics.slot_of("double_entry"), Relics.swap_of("double_entry"), Relics.row("double_entry")["maker"], Relics.row("double_entry")["name"]],
		[AbilityState.LINE, "link_double", "fleet_surplus", "Double Entry"])
	_t.eq("ink heart text", Relics.row("ink_heart")["text"], "Stamped machines refill pressure on balance due")
	_t.eq("double entry text", Relics.row("double_entry")["text"], "Settled clips jump to one fresh machine")
	_t.check("both texts say machines or clips, never bodies", not "bodies" in String(Relics.row("ink_heart")["text"]) and not "bodies" in String(Relics.row("double_entry")["text"]), "")
	_t.eq("the ink stamp keeps the stamp flavour and the smash icon", [AbilityState.ABILITIES["stamp_ink"]["flavour"], AbilityState.ABILITIES["stamp_ink"]["icon"]],
		["stamp", "ab_tally_smash"])
	_t.eq("the double clip keeps the line flag and the line icon", [AbilityState.ABILITIES["link_double"]["line"], AbilityState.ABILITIES["link_double"]["icon"]],
		[true, "ab_tally_line"])
	var tally := Relics.eligible("tally", {}, null, 1)
	_t.check("tally is offered both beside its cooldown relics",
		"ink_heart" in tally and "double_entry" in tally and "oiled_flywheel" in tally and "return_spring" in tally, str(tally))
	_t.check("no other pilot is offered them", not Relics.fits("ink_heart", "tarn") and not Relics.fits("double_entry", "remembered_cannon"), "")
	_t.check("a held smash relic hides only its own slot", "double_entry" in Relics.eligible("tally", {AbilityState.SMASH: "ink_heart"})
		and not "ink_heart" in Relics.eligible("tally", {AbilityState.SMASH: "ink_heart"}), "one relic per held slot")
	# Planted controls: each of these must be refused.
	var ultimate: Dictionary = Relics.ROWS.duplicate(true)
	ultimate["double_entry"]["slot"] = "ultimate"
	var wordy: Dictionary = Relics.ROWS.duplicate(true)
	wordy["ink_heart"]["text"] = "one two three four five six seven eight nine"
	var wrong_slot: Dictionary = Relics.ROWS.duplicate(true)
	wrong_slot["ink_heart"]["slot"] = AbilityState.WEAPON
	_t.check("planted ultimate relic is refused", not Relics.validate(ultimate).is_empty(), str(Relics.validate(ultimate)))
	_t.check("planted nine-word text is refused", not Relics.validate(wordy).is_empty(), str(Relics.validate(wordy)))
	_t.check("planted swap in the wrong slot is refused", not Relics.validate(wrong_slot).is_empty(), str(Relics.validate(wrong_slot)))


# --- helpers ---------------------------------------------------------------------------

func _as_tally() -> void:
	var def: Resource = ClassDef.by_id("tally")
	_game.run.class_def = def
	_player.fit_class(def)
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()
	_source.hold = {}
	_source.press = {}
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at
	_player.kit.drop_line("reset")
	_player.chain.reset()
	_player.abilities.refill()
	_combat._reset_cards()
	_combat._line_load = {}
	_combat._cooldown = 0.0
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_game.camera.pitch = 0.0
	_struck.clear()
	_fired.clear()


func _equip(slot: String, id: String) -> void:
	_player.abilities.swap(slot, id)
	_player.refit()


func _spawn(flat: Vector3) -> Node3D:
	var ground: float = _game.ctx.terrain.height(flat.x, flat.z)
	var enemy: Node3D = _combat.spawn_enemy("chaser", Vector3(flat.x, ground + 1.5, flat.z))
	enemy.max_hp = 100000.0
	enemy.hp = 100000.0
	enemy.set_physics_process(false)
	return enemy


func _ball_flat() -> Vector3:
	var b: Vector3 = _player.ball_position()
	return Vector3(b.x, 0.0, b.z)


func _aim_flat() -> Vector3:
	var dir: Vector3 = _game.ctx.aim_forward()
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD


func _charges() -> int:
	return _player.abilities.slot(AbilityState.WEAPON).charges


func _set_charges(n: int) -> void:
	_player.abilities.slot(AbilityState.WEAPON).charges = n


func _struck_by(id: int, kind: String) -> int:
	return _struck.filter(func(s): return s[0] == id and s[1] == kind).size()


func _ticks_on(enemy: Node3D) -> int:
	return enemy.get_children().filter(func(c): return c.name.begins_with("InkTick") and not c.is_queued_for_deletion()).size()


# Two machines inside the stamp disc and close together (inside one balance due ring), one far
# outside the disc.
func _ink_scene() -> Array:
	_as_tally()
	var aim := _aim_flat()
	var side := aim.cross(Vector3.UP).normalized()
	var near_a := _spawn(_ball_flat() + aim * 3.0)
	var near_b := _spawn(_ball_flat() + aim * 3.0 + side * 1.5)
	var far := _spawn(_ball_flat() - aim * (_player.slam_radius() + 6.0))
	return [near_a, near_b, far]


func _stamp() -> void:
	_player._on_slammed(_player.ball_position(), 30.0, 1.0)


# --- Ink Heart: the stamp books --------------------------------------------------------

func _check_ink_books() -> void:
	var row := _ink_scene()
	var a: Node3D = row[0]
	var b: Node3D = row[1]
	var far: Node3D = row[2]
	_equip(AbilityState.SMASH, "stamp_ink")
	_t.eq("stamp_ink keeps the stamp flavour", _player.kit.smash_flavour, "stamp")
	_t.check("the far machine lies outside the disc", far.global_position.distance_to(_player.ball_position()) > _player.slam_radius(), "")
	var velocity: Vector3 = _player.state.velocity
	_set_charges(0)
	_stamp()
	_t.eq("base stamp pressure pay stays: one point per stamped machine", _charges(), 2)
	_t.eq("both machines in the disc are booked, the far one is not", [_combat._ink.has(a.get_instance_id()), _combat._ink.has(b.get_instance_id()), _combat._ink.has(far.get_instance_id())],
		[true, true, false])
	_t.near("a book lasts 3.0 s", float(_combat._ink[a.get_instance_id()]["until"]) - _combat._clock, 3.0, 0.0001)
	_t.eq("each booked machine wears one ledger tick", [_ticks_on(a), _ticks_on(b), _ticks_on(far)], [1, 1, 0])
	_t.check("the ball's velocity is untouched", _player.state.velocity == velocity, "%s vs %s" % [_player.state.velocity, velocity])
	# Stamping again refreshes the book without a second tick.
	_combat._clock += 1.0
	_stamp()
	_t.near("a second stamp renews the book to 3.0 s", float(_combat._ink[a.get_instance_id()]["until"]) - _combat._clock, 3.0, 0.0001)
	_t.eq("a second stamp draws no second tick", _ticks_on(a), 1)
	# Planted control: the plain stamp_slam books nothing and draws nothing.
	_combat._clear_ink()
	_equip(AbilityState.SMASH, "stamp_slam")
	_set_charges(0)
	_stamp()
	_t.check("the plain stamp books nothing", _combat._ink.is_empty() and _ticks_on(a) == 0, str(_combat._ink.keys()))
	_t.eq("the plain stamp still pays its base pressure", _charges(), 2)


# --- Ink Heart: balance due refills once per machine ------------------------------------

func _check_ink_refill() -> void:
	var row := _ink_scene()
	var a: Node3D = row[0]
	var b: Node3D = row[1]
	_equip(AbilityState.SMASH, "stamp_ink")
	_stamp()
	_t.eq("two machines are booked", _combat._ink.size(), 2)
	_set_charges(1)
	var cast: bool = _combat._run_balance(a.global_position, true)
	_t.check("balance due casts", cast, "")
	_t.eq("it spent one and the two booked machines refilled two", _charges(), 2)
	_t.eq("each book was taken", _combat._ink.size(), 0)
	_t.eq("each tick is gone", [_ticks_on(a), _ticks_on(b)], [0, 0])
	_t.eq("the card records the refills", int(_combat.last_card.get("ink", 0)), 2)
	# Once per machine per stamp: a second strike on the same machines refills nothing.
	_set_charges(2)
	_combat._run_balance(a.global_position, true)
	_t.eq("a second balance due on the consumed books only spends", _charges(), 1)
	# The bank's own cap holds: two refills into a bank of 3 stop at 3.
	_stamp()
	_set_charges(3)
	_combat._run_balance(a.global_position, true)
	_t.eq("two refills never pass the bank of three", _charges(), 3)
	# A booked machine outside the ring is untouched.
	_stamp()
	_set_charges(2)
	_combat._run_balance(_ball_flat() + Vector3(0.0, 0.0, 0.0) - _aim_flat() * 20.0, true)
	_t.eq("a ring that strikes nothing refills nothing", _combat._ink.size(), 2)
	# Planted control: without the stamp's book (plain stamp_slam) balance due only spends.
	_combat._clear_ink()
	_equip(AbilityState.SMASH, "stamp_slam")
	_stamp()
	_set_charges(2)
	_combat._run_balance(a.global_position, true)
	_t.eq("the plain stamp's balance due refills nothing", _charges(), 1)


# --- Ink Heart: the book runs out after 3.0 s -------------------------------------------

func _check_ink_expiry() -> void:
	var row := _ink_scene()
	var a: Node3D = row[0]
	_equip(AbilityState.SMASH, "stamp_ink")
	_stamp()
	_combat._clock += 2.9
	_combat._step_ink()
	_t.check("at 2.9 s the book still stands", _combat._ink.has(a.get_instance_id()) and _ticks_on(a) == 1, str(_combat._ink.keys()))
	_combat._clock += 0.2
	_combat._step_ink()
	_t.check("past 3.0 s the book and its tick are gone", _combat._ink.is_empty() and _ticks_on(a) == 0, str(_combat._ink.keys()))
	_set_charges(2)
	_combat._run_balance(a.global_position, true)
	_t.eq("an expired book refills nothing", _charges(), 1)
	# An expired book that a step had not yet swept still refills nothing.
	_stamp()
	_combat._clock += 3.5
	_set_charges(2)
	_combat._run_balance(a.global_position, true)
	_t.eq("a lapsed, unswept book refills nothing and is consumed", [_charges(), _combat._ink.size()], [1, 0])
	# A dead machine drops its book.
	_stamp()
	_combat.strike(a, "ram", 1000000.0)
	_combat._step_ink()
	_t.check("a killed machine drops its book", not _combat._ink.has(a.get_instance_id()), str(_combat._ink.keys()))


func _check_ink_clears() -> void:
	var row := _ink_scene()
	var a: Node3D = row[0]
	_equip(AbilityState.SMASH, "stamp_ink")
	_stamp()
	_t.eq("booked", _combat._ink.size(), 2)
	_combat._reset_cards()
	_t.check("a stage or run reset clears every book and tick", _combat._ink.is_empty() and _ticks_on(a) == 0, str(_combat._ink.keys()))
	_stamp()
	_game.events.stage_content_cleared.emit("retry")
	_t.check("a cleared stage clears them too", _combat._ink.is_empty() and _ticks_on(a) == 0, str(_combat._ink.keys()))
	_stamp()
	_game.events.player_died.emit()
	_t.check("a death clears them too", _combat._ink.is_empty() and _ticks_on(a) == 0, str(_combat._ink.keys()))


# --- Double Entry -----------------------------------------------------------------------

# c0 is latched; c1 and c2 are its two nearest neighbours (2 m and 4 m); f1 is the nearest
# unclipped machine (5 m), f2 the next (8 m); g lies past 9 m (12 m).
func _double_scene() -> Dictionary:
	_as_tally()
	var aim := _aim_flat()
	var side := aim.cross(Vector3.UP).normalized()
	var base := _ball_flat() + aim * 10.0
	var scene := {
		"c0": _spawn(base), "c1": _spawn(base + aim * 2.0), "c2": _spawn(base + aim * 4.0),
		"f1": _spawn(base + side * 5.0), "f2": _spawn(base - side * 8.0), "g": _spawn(base + side * 12.0),
	}
	# Level them, so the 3D gaps are the flat gaps the layout names whatever the terrain does.
	var level: float = scene["c0"].global_position.y
	for key in scene:
		scene[key].global_position.y = level
	return scene


func _cast_on(id: String, target: Node3D) -> void:
	_player.kit.drop_line("reset")
	_player.grapple_to(target.global_position, Vector3.UP, target)
	_combat._fire_line_skill(id, 1.0)
	_player.release_grapple()


func _ids(scene: Dictionary, keys: Array) -> Array:
	return keys.map(func(k): return scene[k].get_instance_id())


func _check_double_clips() -> void:
	var s := _double_scene()
	_equip(AbilityState.LINE, "link_double")
	_t.eq("the swapped row keeps the line flag", _player.abilities.cap(AbilityState.LINE, "line", false), true)
	_cast_on("link_double", s["c0"])
	_t.eq("it fires as link_double on the body", _fired, [["link_double", "body"]])
	var ids: Array = _combat.link_group.get("ids", [])
	var want := _ids(s, ["c0", "c1", "c2"])
	ids = ids.duplicate()
	ids.sort()
	want.sort()
	_t.eq("it clips the latched machine and its two nearest neighbours", ids, want)
	_t.eq("the group is a double entry that has not jumped", [_combat.link_group["double"], _combat.link_group["jumped"]], [true, false])
	# The plain clip clips the same three.
	_equip(AbilityState.LINE, "link_clips")
	_cast_on("link_clips", s["c0"])
	var plain: Array = (_combat.link_group.get("ids", []) as Array).duplicate()
	plain.sort()
	_t.eq("the plain clip clips the same three", plain, want)
	_t.eq("and is not a double entry", _combat.link_group["double"], false)


func _check_double_jump() -> void:
	var s := _double_scene()
	_equip(AbilityState.LINE, "link_double")
	_cast_on("link_double", s["c0"])
	_struck.clear()
	_combat.strike(s["c0"], "ram", 30.0)
	var arcs := [_struck_by(s["c1"].get_instance_id(), "ledger"), _struck_by(s["c2"].get_instance_id(), "ledger")]
	_t.eq("the settle still arcs once to each other clip", arcs, [1, 1])
	_t.eq("the clip jumped once to the nearest unclipped machine within 9 m", _struck_by(s["f1"].get_instance_id(), "ledger"), 1)
	_t.eq("the jump target is recorded", int(_combat.link_group.get("jump_to", 0)), s["f1"].get_instance_id())
	_t.eq("the next machine is not touched", _struck_by(s["f2"].get_instance_id(), "ledger"), 0)
	_t.eq("a machine past 9 m is not touched", _struck_by(s["g"].get_instance_id(), "ledger"), 0)
	_t.check("the group has jumped and is spent", bool(_combat.link_group["jumped"]) and bool(_combat.link_group["spent"]), str(_combat.link_group))
	# Never recursive: the jumped machine, struck on its own, settles nothing and jumps nowhere.
	var before := _struck.size()
	_combat.strike(s["f1"], "ram", 30.0)
	var after: Array = _struck.slice(before).filter(func(e): return e[1] == "ledger")
	_t.eq("the jumped machine settling again arcs and jumps to nobody", after.size(), 0)
	_t.eq("one jump per cast: the whole settle struck exactly one fresh machine",
		_struck.filter(func(e): return e[1] == "ledger" and e[0] in _ids(s, ["f1", "f2", "g"])).size(), 1)
	var again := _struck.size()
	_combat.strike(s["c0"], "ram", 30.0)
	_t.eq("a spent group never settles or jumps twice", _struck.slice(again).filter(func(e): return e[1] == "ledger").size(), 0)
	# Planted control: were the jumped machine a clip and the flag clear, a second jump would
	# reach the next machine (g, 7 m from f1). The flag is what holds it; set, the same strike
	# jumps nowhere.
	_combat.link_group["ids"].append(s["f1"].get_instance_id())
	_combat.link_group["spent"] = false
	_combat.link_group["jumped"] = false
	var planted := _struck.size()
	_combat.strike(s["f1"], "ram", 30.0)
	_t.check("planted: a clear flag lets the clip jump again (the control fires)", _struck.slice(planted).any(func(e): return e[0] in _ids(s, ["f2", "g"]) and e[1] == "ledger"),
		str(_struck.slice(planted)))
	_combat.link_group["spent"] = false
	_combat.link_group["jumped"] = true
	var held := _struck.size()
	_combat.strike(s["f1"], "ram", 30.0)
	_t.eq("with the flag set the same strike jumps nowhere", _struck.slice(held).filter(func(e): return e[0] == s["g"].get_instance_id()).size(), 0)
	# Planted control: the plain clip never jumps.
	var c := _double_scene()
	_equip(AbilityState.LINE, "link_clips")
	_cast_on("link_clips", c["c0"])
	_struck.clear()
	_combat.strike(c["c0"], "ram", 30.0)
	_t.eq("the plain clip settles its clips", [_struck_by(c["c1"].get_instance_id(), "ledger"), _struck_by(c["c2"].get_instance_id(), "ledger")], [1, 1])
	_t.eq("the plain clip never jumps", [_struck_by(c["f1"].get_instance_id(), "ledger"), _struck_by(c["f2"].get_instance_id(), "ledger"), int(_combat.link_group.get("jump_to", 0))], [0, 0, 0])


func _check_double_far() -> void:
	var s := _double_scene()
	for key in ["f1", "f2"]:
		s[key].remove_from_group("enemy")
		s[key].global_position += Vector3(0.0, 0.0, 400.0)
	_equip(AbilityState.LINE, "link_double")
	_cast_on("link_double", s["c0"])
	_struck.clear()
	_combat.strike(s["c0"], "ram", 30.0)
	_t.eq("with only a machine 12 m off, nothing jumps", [_struck_by(s["g"].get_instance_id(), "ledger"), int(_combat.link_group.get("jump_to", 0))], [0, 0])
	_t.check("the group is still spent and flagged", bool(_combat.link_group["spent"]) and bool(_combat.link_group["jumped"]), str(_combat.link_group))
	# A clipped machine is never a jump target: with the three clips and no one else, nothing jumps.
	for key in ["g"]:
		s[key].remove_from_group("enemy")
	_cast_on("link_double", s["c0"])
	_struck.clear()
	_combat.strike(s["c1"], "ram", 30.0)
	_t.eq("a clipped machine is never a fresh target", int(_combat.link_group.get("jump_to", 0)), 0)


func _clip_cues(audio, from: int) -> int:
	return audio.cues_since(from).filter(func(n): return n[1] == "clip_tally").size()


func _check_double_jam_and_audio() -> void:
	var s := _double_scene()
	_equip(AbilityState.LINE, "link_double")
	_t.eq("a free line selects", _player.abilities.select(AbilityState.LINE), "")
	_player.abilities.jam(2.0)
	_t.check("a jam shuts the double clip like the plain one", _player.abilities.silenced(AbilityState.LINE) and _player.abilities.select(AbilityState.LINE) == "jammed", "")
	_t.eq("the jammed state is unavailable", _player.abilities.state_of(AbilityState.LINE), AbilityState.UNAVAILABLE)
	_equip(AbilityState.LINE, "link_clips")
	_t.eq("the plain clip is shut the same way", _player.abilities.state_of(AbilityState.LINE), AbilityState.UNAVAILABLE)
	_player.abilities.jam_left = 0.0
	# Audio: link_double plays the same clip cues as link_clips.
	var audio = _game.presentation.audio
	_equip(AbilityState.LINE, "link_clips")
	var from: int = audio.cue_log_total
	var notes_from: int = audio._tally_notes.size()
	_cast_on("link_clips", s["c0"])
	var plain: Array = [_clip_cues(audio, from), audio._tally_notes.size() - notes_from]
	_equip(AbilityState.LINE, "link_double")
	from = audio.cue_log_total
	notes_from = audio._tally_notes.size()
	_cast_on("link_double", s["c0"])
	var double: Array = [_clip_cues(audio, from), audio._tally_notes.size() - notes_from]
	_t.check("the double clip plays the same clip cues", double == plain and (double[0] + double[1]) > 0, "plain %s double %s" % [plain, double])
