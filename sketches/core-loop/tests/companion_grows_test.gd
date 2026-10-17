extends SceneTree

# COMPANION-GROWS (Andrew's taps 16:36Z "Grow SPIL-9", "Clearly mightier" and 16:44Z "Next
# ram", 17 Oct 2026). Rules:
# - One seated piece is a legal companion; two need different families, as before.
# - Each heft class is a mark: scale 1.0 to 1.4 and one more add-on, cumulative.
# - Every family set calls one named assist; class 5 is 2x the area and 2x the knockback of
#   class 1, with 2 sound layers growing to 4.
# - Landed hits fill the gauge (a hull hit faster); with it full, the next ram calls the
#   assist at the struck foe, empties the gauge, and the assist's own damage never refills it.
# - The body shows the bare chassis, one seated piece, and the grown mark and kit.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const T := preload("res://tests/support/t.gd")

const RAM := 20.0

var _t := T.new("companion_grows_test")
var _game
var _ticks := 0
var _spawned: Array = []
var _assisted: Array = []
var _full := 0


func _initialize() -> void:
	_check_model()
	_check_marks()
	_check_assists()
	_check_charge()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check_model() -> void:
	var c := Companion.new()
	for id in ["primer_coil", "primer_mesh", "ram_prow"]:
		c.acquire(id)
	_t.eq("one piece seats", c.assemble(["ram_prow"]), "")
	_t.eq("one piece socket set", c.sockets, ["ram_prow"] as Array[String])
	var round_trip := Companion.new()
	_t.check("one seated piece round-trips", round_trip.from_dict(c.to_dict()) and round_trip.sockets == c.sockets)
	_t.check("empty set refused", c.assemble([]) != "")
	_t.check("same family pair still refused", c.assemble(["primer_coil", "primer_mesh"]) != "")
	_t.check("unowned single refused", c.assemble(["escape_vent"]) != "")
	var bad := c.to_dict()
	bad["sockets"] = ["primer_coil", "primer_mesh"]
	_t.check("same family pair doc refused", not Companion.new().from_dict(bad))


func _check_marks() -> void:
	var scales := []
	for heft in range(1, 6):
		scales.append(float(Companion.mark_of(heft)["scale"]))
	_t.eq("mark scales", scales, [1.0, 1.1, 1.2, 1.3, 1.4])
	_t.eq("mark clamps low", int(Companion.mark_of(0)["mark"]), 1)
	_t.eq("mark clamps high", int(Companion.mark_of(9)["mark"]), 5)
	_t.eq("mk I adds nothing", Companion.adds_of(1), [])
	_t.eq("mk V adds all four", Companion.adds_of(5), ["fins", "double_halo", "exhaust", "core_crest"])


func _check_assists() -> void:
	var ids := {}
	var sets := [[], ["primer_coil"], ["ram_spring"], ["escape_rail"], ["primer_mesh", "ram_prow"],
		["primer_coil", "escape_vent"], ["ram_prow", "escape_rail"]]
	for s in sets:
		var row := Companion.assist_of(s)
		ids[row["id"]] = true
		_t.check("assist %s has a cue row" % row["id"], Companion.CUES.has(row["cue"]))
		_t.check("assist %s has a word" % row["id"], String(row["word"]).ends_with("!"))
	_t.eq("seven distinct assists", ids.size(), 7)
	_t.eq("pair order does not matter", Companion.assist_of(["ram_prow", "primer_coil"])["id"], "anvil")
	var low := Companion.assist_power(1)
	var high := Companion.assist_power(5)
	_t.near("class 5 is 2x the area", float(high["area"]) / float(low["area"]), 2.0)
	_t.near("class 5 radius matches the area", pow(float(high["radius"]) / float(low["radius"]), 2.0), 2.0, 0.001)
	_t.near("class 5 is 2x the knockback", float(high["knock"]) / float(low["knock"]), 2.0)
	var layers := []
	for heft in range(1, 6):
		layers.append(int(Companion.assist_power(heft)["layers"]))
	_t.eq("sound layers grow to twice", layers, [2, 2, 3, 3, 4])


func _check_charge() -> void:
	var g := 0.0
	g = Companion.assist_charge(g, "weapon")
	_t.near("a shot adds one", g, Companion.ASSIST_PER_HIT)
	g = Companion.assist_charge(g, "ram")
	_t.near("a contact adds more", g, Companion.ASSIST_PER_HIT + Companion.ASSIST_PER_CONTACT)
	g = Companion.assist_charge(g, "hull")
	_t.near("a hull hit adds the most", g, Companion.ASSIST_PER_HIT + Companion.ASSIST_PER_CONTACT + Companion.ASSIST_PER_HULL_HIT)
	_t.near("the gauge caps", Companion.assist_charge(Companion.ASSIST_FULL - 0.5, "hull"), Companion.ASSIST_FULL)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_setup()
		return false
	if _ticks < 12:
		return false
	if _ticks == 12:
		_check_combat()
		return false
	if _ticks < 20:
		return false
	if _ticks == 20:
		_check_body()
		_seat(["ram_prow"])
		return false
	if _ticks < 24:
		return false
	if _ticks == 24:
		_check_single()
		_seat([])
		return false
	if _ticks < 28:
		return false
	_check_bare()
	_clear()
	quit(_t.verdict())
	return true


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	var spawn: Vector3 = ctx.terrain.spawn_point(1)
	var anchor := Vector3(spawn.x, ctx.terrain.height(spawn.x, spawn.z) + 1.05, spawn.z)
	_game.player.reset_to(anchor)
	_game.player.body().global_position = anchor
	_combat().companion_assisted.connect(func(a: Dictionary): _assisted.append(a))
	_combat().companion_assist_full.connect(func(): _full += 1)


func _combat():
	return _game.ctx.spawner


func _spawn(offset: Vector3) -> Node3D:
	var spot: Vector3 = _game.player.ball_position() + offset
	var e: Node3D = _combat().spawn_enemy("chaser", _game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))
	_spawned.append(e)
	e.hp = 99999.0
	e.max_hp = 99999.0
	return e


func _clear() -> void:
	for e in _spawned:
		if is_instance_valid(e):
			e.remove_from_group("enemy")
			e.queue_free()
	_spawned.clear()


func _seat(pieces: Array) -> void:
	var c := Companion.new()
	for id in pieces:
		c.acquire(id)
	if not pieces.is_empty():
		c.assemble(pieces)
	_game.ctx.run.companion = c.to_dict()


func _check_combat() -> void:
	var combat = _combat()
	var shown = _game.presentation.get_node_or_null("CompanionBody")
	if shown != null:
		_step(shown)
	_seat(["primer_coil", "ram_prow"])
	combat.assist_charge = 0.0
	var target := _spawn(Vector3(0, 0, -4))
	var near := _spawn(Vector3(1.5, 0, -4))
	var far := _spawn(Vector3(30, 0, 0))
	var shots := 0
	while not combat.assist_ready() and shots < 100:
		combat.strike(target, "pin", RAM)
		shots += 1
	_t.check("shots fill the gauge", combat.assist_ready(), "%d shots, charge %.1f" % [shots, combat.assist_charge])
	_t.eq("full fires once", _full, 1)
	_t.eq("no assist before a ram", _assisted.size(), 0)
	combat.strike(target, "pin", RAM)
	_t.eq("a shot does not call it", _assisted.size(), 0)
	var near_hp: float = near.hp
	var near_knocks: int = near.knocks
	combat.strike(target, "ram", RAM)
	_t.eq("the next ram calls it", _assisted.size(), 1)
	if _assisted.is_empty():
		return
	var a: Dictionary = _assisted[0]
	_t.eq("thunder anvil for coil and prow", a["id"], "anvil")
	_t.eq("its word", a["word"], "KRA-KOOM!")
	_t.near("gauge empties", combat.assist_charge, 0.0)
	_t.check("a neighbour in the ring is hit", near.hp < near_hp, "%.1f -> %.1f" % [near_hp, near.hp])
	_t.check("a neighbour is shoved", near.knocks > near_knocks)
	_t.check("a neighbour is primed", combat.primed(near))
	_t.eq("a far foe is untouched", far.hp, 99999.0)
	_t.check("hits counted", int(a["hits"]) >= 2, str(a["hits"]))
	_t.eq("class 1 radius", a["radius"], Companion.ASSIST_RADIUS)
	_t.eq("one assist this run", combat.assists, 1)

	# A grown run: class 5 rings 2x the area, and the same ram on an empty gauge only charges.
	combat.strike(target, "ram", RAM)
	_t.eq("an empty gauge does not call it", _assisted.size(), 1)
	_t.near("that ram charged instead", combat.assist_charge, Companion.ASSIST_PER_CONTACT)
	_game.run.mass = (Companion.MARKS.size() + 2) * 450.0 * 2.0
	_t.eq("guard: heft class 5", _game.run.heft_class(), 5)
	combat.assist_charge = Companion.ASSIST_FULL
	combat.strike(target, "ram", RAM)
	_t.eq("grown ram calls it", _assisted.size(), 2)
	if _assisted.size() >= 2:
		_t.near("grown area is 2x", pow(float(_assisted[1]["radius"]) / Companion.ASSIST_RADIUS, 2.0), 2.0, 0.001)
		_t.eq("grown mark", _assisted[1]["mark"], 5)
		_t.eq("grown layers", _assisted[1]["layers"], 4)

	# Bare: Bonk hits only the nearest foe. A slick assist leaves a live escape lane alone.
	_seat([])
	var before := _assisted.size()
	combat.assist_charge = Companion.ASSIST_FULL
	combat.strike(target, "ram", RAM)
	_t.eq("bare calls bonk", _assisted.back()["id"] if _assisted.size() > before else "", "bonk")
	_t.eq("bonk hits one", int(_assisted.back()["hits"]) if _assisted.size() > before else -1, 1)
	_seat(["escape_rail"])
	var live := {"from": Vector3.ZERO, "dir": Vector3.FORWARD, "length": 6.0, "half_width": 1.5, "friction": 0.2, "hold": 7.0, "until": combat._clock + 5.0}
	combat.escape_lane = live.duplicate()
	combat.assist_charge = Companion.ASSIST_FULL
	combat.strike(target, "ram", RAM)
	_t.eq("escape alone calls slipstream", _assisted.back()["id"], "slip")
	_t.eq("a live corridor lane is kept", combat.escape_lane, live)
	_t.near("the assist's own hits leave the gauge empty", combat.assist_charge, 0.0)
	combat.escape_lane = {}

	# A hull hit charges; a new attempt clears the gauge.
	combat.assist_charge = 0.0
	combat._charge_assist("hull")
	_t.near("hull hit charges", combat.assist_charge, Companion.ASSIST_PER_HULL_HIT)
	combat._start_attempt()
	_t.near("attempt clears the gauge", combat.assist_charge, 0.0)

	# No companion, no gauge.
	_game.ctx.run.companion = {}
	combat.strike(target, "pin", RAM)
	_t.near("no companion, no charge", combat.assist_charge, 0.0)
	_seat(["primer_coil", "ram_prow"])


func _check_body() -> void:
	var body = _game.presentation.get_node_or_null("CompanionBody")
	_t.check("body exists", body != null)
	if body == null:
		return
	_step(body)
	_t.eq("every assist shown with its word", body.assists_shown, _assisted.size())
	_t.eq("grown body is mark 5", body.mark(), 5)
	_t.near("grown body scale", body.grown(), 1.4)
	_t.eq("mk V kit", body.kit_parts().size(), 7)
	_t.check("key of bare", body.key_of([]) == "bare" and body.key_of([], false) == "")
	_t.eq("key of one", body.key_of(["ram_prow"]), "ram_prow")


# Physics ticks can outrun process frames on a loaded runner, so the body takes one frame
# step of its own before it is read.
func _step(body) -> void:
	body._process(0.0)


func _check_single() -> void:
	var body = _game.presentation.get_node_or_null("CompanionBody")
	_step(body)
	_t.check("one seated piece shows the real chassis", body.is_real() and body.visible)
	_t.eq("one seated piece is bolted on", body.find_children("SeatedPart", "", true, false).size(), 1)
	_t.eq("still one child", body.get_child_count(), 1)


func _check_bare() -> void:
	var body = _game.presentation.get_node_or_null("CompanionBody")
	_step(body)
	_t.check("bare chassis shows", body.is_real() and body.visible)
	_t.eq("bare has no seated part", body.find_children("SeatedPart", "", true, false).size(), 0)
	_t.eq("bare keeps the grown mark", body.mark(), 5)
