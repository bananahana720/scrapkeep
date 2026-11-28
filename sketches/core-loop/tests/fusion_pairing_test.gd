extends SceneTree

# SG2 fusion rows (comps/W13-INTEGRATION-3.md unit SG2; comps/gunfire/elements-and-fusion.md:85,
# the fusion pairing lab measure). A second status on an enemy that already holds one fuses once
# into one effect, read from a row of the element table (elements.gd FUSIONS), the same in either
# order. Proves on the real paths (an arc strike, a slam strike, frost applied by the field),
# against frozen dummies:
# 1. the table: one row per pair of today's elements, keyed the same in either order, admissible;
# 2. both orders of each pair give the identical effect type, area and damage;
# 3. the committed preview exists at least 12 frames before damage and equals the damage area:
#    a probe just inside the drawn ring is hit and a probe just outside is not;
# 4. a pair resolves once: the statuses are spent, and a repeat second hit fuses nothing;
# 5. an elite dummy takes no control effect and at most 10% of the normal dummy's sustained
#    damage; the immunity text on the codex card equals the data row;
# 6. every defence bar class reads its multiplier from LAYER_MULT (150 / 100 / 75 shape) and
#    defence_bars.gd carries no private multiplier;
# 7. review round 1: a fusion strike procs no item; the cards name no order and repeat no
#    element card's opening; each fusion draws in the mix of its own elements' colours; and
#    the director carries the elite flag to every member of its elite pack.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Elements := preload("res://src/build/elements.gd")
const DefenceBars := preload("res://tests/support/defence_bars.gd")
const Triggers := preload("res://src/build/triggers.gd")
const Director := preload("res://src/world/director.gd")
const ElementField := preload("res://src/build/element_field.gd")
const T := preload("res://tests/support/t.gd")

const BIG := 1.0e9
const TOL := 1.0e-3
const MIN_LEAD := 12
const ELITE_SHARE_MAX := 0.10
# How far a probe sits inside or outside the committed ring.
const EDGE := 0.4
const SPACING := 26.0
const EXPECTED_CHECKS := 70

var _t := T.new("fusion_pairing_test")
var _game
var _ticks := 0
var _combat
var _field
var _spawned: Array = []
# One cluster per fused dummy: {key, order, elite, centre, inside, outside, result, base hp...}.
var _clusters: Array = []
var _fused: Array = []
var _frames := 0
var _last_frame := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


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
		_combat = _game.ctx.spawner
		_field = _game.build.field
		_table_checks()
		_layer_checks()
		_review_checks()
		if not _field.has_signal("fused") or not _field.has_method("status_of"):
			_t.check("the field fuses statuses", false, "no fused signal or status_of on element_field.gd")
			_t.eq("every check ran", _t.checks + 1, EXPECTED_CHECKS)
			quit(_t.verdict())
			return true
		_field.fused.connect(func(result: Dictionary): _fused.append(result))
		_commit_all()
		return false
	return _watch_frame()


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
	ctx.run.companion = {}


func _consts() -> Dictionary:
	return (Elements as Script).get_script_constant_map()


# --- 1: the table ---------------------------------------------------------------------

func _table_checks() -> void:
	var fusions: Dictionary = _consts().get("FUSIONS", {})
	var pairs := []
	for i in Elements.ELEMENTS.size():
		for j in range(i + 1, Elements.ELEMENTS.size()):
			pairs.append([Elements.ELEMENTS[i], Elements.ELEMENTS[j]])
	_t.eq("one fusion row per pair of today's elements", fusions.size(), pairs.size())
	var keyed := true
	for pair in pairs:
		if Elements.fusion_key(pair[0], pair[1]) != Elements.fusion_key(pair[1], pair[0]) \
				or not fusions.has(Elements.fusion_key(pair[0], pair[1])):
			keyed = false
	_t.check("a pair keys the same row in either order", keyed, "%s" % [fusions.keys()])
	_t.check("an element with itself fuses nothing", Elements.fuse("arc", "arc").is_empty(), "")
	_t.eq("the table is admissible (problems() is empty)", Elements.problems(), [] as Array[String])
	_t.check("the preview lead is at least 12 frames", int(_consts().get("FUSION_LEAD_FRAMES", 0)) >= MIN_LEAD, "")
	var kinds := {}
	for key in fusions:
		kinds[String(fusions[key].get("kind", ""))] = true
	_t.check("the rows cover a control, a burst and a sustained fusion", kinds.has("control") and kinds.has("burst") and kinds.has("sustained"), "%s" % [kinds.keys()])


func _review_checks() -> void:
	_t.check("a fusion strike procs no item (an explicit 0.0 row, like synergy)",
		Triggers.STRIKE_PROC.has(Elements.FUSION_STRIKE) and Triggers.strike_proc(Elements.FUSION_STRIKE) == 0.0, "")
	var fusions: Dictionary = _consts().get("FUSIONS", {})
	var openings := []
	for row_key in Elements.ROWS:
		openings.append(" ".join(String(Elements.ROWS[row_key]["found"]).split(" ").slice(0, 3)))
	var worded := true
	var colours := []
	for key in fusions:
		var found := String(fusions[key]["found"])
		if found.contains(" then ") or found.contains(", then") or " ".join(found.split(" ").slice(0, 3)) in openings:
			worded = false
		var colour: Color = ElementField.fusion_colour(key)
		var pair: PackedStringArray = String(key).split("+")
		if not colour.is_equal_approx(ElementField.ELEMENT_COLOURS[pair[0]].lerp(ElementField.ELEMENT_COLOURS[pair[1]], 0.5)):
			colours.append(null)
		colours.append(colour)
	_t.check("no fusion card names an order or repeats an element card's opening", worded, "%s" % [openings])
	_t.check("each fusion's colour is its own elements' mix, and no two match", not colours.has(null)
		and colours.size() == 3 and not colours[0].is_equal_approx(colours[1]) and not colours[1].is_equal_approx(colours[2])
		and not colours[0].is_equal_approx(colours[2]), "%s" % [colours])
	var d := Director.new(71)
	d.set_run_tier_reader(func(): return 0)
	d._place_pack(Vector2(30.0, 0.0), ["chaser", "chaser"], Vector2.ZERO, true)
	d._place_pack(Vector2(-30.0, 0.0), ["chaser"], Vector2.ZERO, false)
	var marks := []
	for arrival in d.arrivals:
		marks.append(arrival.get("elite", false))
	var delivered := []
	for step in 40:
		for spawn in d.advance(0.5, 0):
			delivered.append(spawn.get("elite", false))
	_t.eq("every elite-pack arrival carries the elite flag, and no other", marks, [true, true, false])
	_t.check("the director hands the flag on with each elite spawn", delivered.count(true) == 2 and delivered.count(false) >= 1, "%s" % [delivered])


func _layer_checks() -> void:
	var consts: Dictionary = _consts()
	var table: Dictionary = consts.get("LAYER_MULT", {})
	_t.eq("LAYER_MULT has one row per defence bar class", table.keys().size(), DefenceBars.CLASS_IDS.size())
	var weak := {}
	for id in DefenceBars.CLASS_IDS:
		var row: Dictionary = table.get(id, {})
		var shape := []
		for element in Elements.ELEMENTS:
			shape.append(float(row.get(element, -1.0)))
			if is_equal_approx(float(row.get(element, -1.0)), 1.5):
				weak[id] = element
		shape.sort()
		_t.eq("%s reads the 150 / 100 / 75 shape" % id, shape, [0.75, 1.0, 1.5])
		var ok := true
		for element in Elements.ELEMENTS:
			var pool = DefenceBars.Pool.new(id, 1000.0)
			pool.hit(10.0, element)
			if absf((1000.0 - pool.value) - 10.0 * float(row.get(element, 0.0))) > TOL:
				ok = false
		var plain = DefenceBars.Pool.new(id, 1000.0)
		plain.hit(10.0)
		_t.check("a %s bar takes each element at its LAYER_MULT and an unnamed hit at 100%%" % id, ok and is_equal_approx(plain.value, 990.0), "")
	_t.eq("the 150% element differs per layer", weak.values().size() == 3 and weak.values()[0] != weak.values()[1]
		and weak.values()[1] != weak.values()[2] and weak.values()[0] != weak.values()[2], true)
	var code := []
	for line in FileAccess.get_file_as_string("res://tests/support/defence_bars.gd").split("\n"):
		if not line.strip_edges().begins_with("#"):
			code.append(line)
	var private := RegEx.create_from_string("\\b(1\\.5|0\\.75|150)\\b")
	var joined := "\n".join(code)
	_t.check("defence_bars.gd has no private multiplier and reads LAYER_MULT", joined.contains("Elements.layer_mult")
		and private.search(joined) == null, "")


# --- 2 to 5: the clusters -------------------------------------------------------------

func _commit_all() -> void:
	var fusions: Dictionary = _consts().get("FUSIONS", {})
	var slot := 0
	for key in fusions:
		var pair: PackedStringArray = String(key).split("+")
		for order in [[pair[0], pair[1]], [pair[1], pair[0]]]:
			_clusters.append(_cluster(key, order, false, slot))
			slot += 1
		_clusters.append(_cluster(key, [pair[0], pair[1]], true, slot))
		slot += 1
	for c in _clusters:
		var before := _fused.size()
		_give(c["centre"], c["order"][0])
		c["first_status"] = _field.status_of(c["centre"])
		c["fused_on_first"] = _fused.size() - before
		_give(c["centre"], c["order"][1])
		c["fusions"] = _fused.size() - before
		c["result"] = _fused[-1] if _fused.size() > before else {}
		c["status_after"] = _field.status_of(c["centre"])
		for part in ["centre", "inside", "outside"]:
			c["hp_" + part] = float(c[part].hp)
		c["preview_from"] = -1
		c["hit_at"] = -1
		c["held_seen"] = false
	_frames = 0


func _cluster(key: String, order: Array, elite: bool, slot: int) -> Dictionary:
	var row: Dictionary = Elements.fuse(order[0], order[1])
	var radius: float = float(row.get("radius", 4.0))
	var centre_offset := Vector3((slot % 3 - 1) * SPACING, 0.0, (slot / 3 + 1) * SPACING)
	var c := {"key": key, "order": order, "elite": elite, "row": row}
	c["centre"] = _dummy(centre_offset, elite)
	var at: Vector3 = c["centre"].global_position
	c["inside"] = _dummy_at(at + Vector3(radius - EDGE, 0.0, 0.0))
	c["outside"] = _dummy_at(at + Vector3(-(radius + EDGE), 0.0, 0.0))
	return c


func _give(enemy: Node3D, element: String) -> void:
	match element:
		"arc":
			_combat.strike(enemy, "arc", 5.0)
		"kinetic":
			_combat.strike(enemy, "slam", 5.0)
		"frost":
			_field.apply("frost", enemy.global_position, "test")


func _watch_frame() -> bool:
	_frames += 1
	var done := true
	for c in _clusters:
		var result: Dictionary = c["result"]
		if result.is_empty():
			continue
		var preview = result.get("preview")
		var drawn: bool = is_instance_valid(preview) and preview.is_visible_in_tree()
		if drawn and not c.has("drawn_colour"):
			c["drawn_colour"] = preview.material_override.albedo_color
		if drawn and c["preview_from"] < 0:
			c["preview_from"] = _frames
			var gs: Vector3 = preview.global_basis.get_scale()
			c["drawn_radius"] = gs.x
			c["drawn_round"] = absf(gs.x - gs.z) < TOL
			c["drawn_at"] = preview.global_position
		if c["hit_at"] < 0 and float(c["centre"].hp) < float(c["hp_centre"]) - TOL:
			c["hit_at"] = _frames
		if _field.is_held(c["centre"]):
			c["held_seen"] = true
		if _field.has_method("active_count") and _field.active_count() > 0:
			done = false
	if not done and _frames < 600:
		return false
	_finish()
	return true


func _finish() -> void:
	var by_key := {}
	for c in _clusters:
		by_key[c["key"] + ("|elite" if c["elite"] else "|" + "+".join(c["order"]))] = c
	var fusions: Dictionary = _consts().get("FUSIONS", {})
	var card_found: Dictionary = _game.build._found
	for key in fusions:
		var row: Dictionary = fusions[key]
		var pair: PackedStringArray = String(key).split("+")
		var a: Dictionary = by_key.get(key + "|" + pair[0] + "+" + pair[1], {})
		var b: Dictionary = by_key.get(key + "|" + pair[1] + "+" + pair[0], {})
		var e: Dictionary = by_key.get(key + "|elite", {})
		var ra: Dictionary = a.get("result", {})
		var rb: Dictionary = b.get("result", {})
		# 2: both orders.
		_t.check("%s: each order fuses exactly once, on the second status" % key,
			a["fusions"] == 1 and b["fusions"] == 1 and a["fused_on_first"] == 0 and b["fused_on_first"] == 0
				and a["first_status"] == pair[0] and b["first_status"] == pair[1],
			"fusions %s/%s first %s/%s" % [a["fusions"], b["fusions"], a["first_status"], b["first_status"]])
		_t.check("%s: both orders give the identical effect type and area" % key,
			not ra.is_empty() and ra.get("behaviour") == rb.get("behaviour") and ra.get("kind") == rb.get("kind")
				and is_equal_approx(float(ra.get("radius", -1.0)), float(rb.get("radius", -2.0)))
				and is_equal_approx(float(ra.get("seconds", -1.0)), float(rb.get("seconds", -2.0))),
			"%s / %s" % [_brief(ra), _brief(rb)])
		var da: float = float(a["hp_centre"]) - float(a["centre"].hp)
		var db: float = float(b["hp_centre"]) - float(b["centre"].hp)
		_t.check("%s: both orders deal the identical damage" % key, da > 0.0 and absf(da - db) <= TOL * da,
			"%.4f / %.4f" % [da, db])
		_t.check("%s: the effect is the row's" % key, ra.get("behaviour") == row.get("behaviour")
			and is_equal_approx(float(ra.get("radius", -1.0)), float(row.get("radius", -2.0))), "%s" % [_brief(ra)])
		# 3: preview lead and preview area.
		for c in [a, b]:
			var lead: int = int(c["hit_at"]) - int(c["preview_from"])
			_t.check("%s (%s): the preview is drawn at least %d frames before damage" % [key, "+".join(c["order"]), MIN_LEAD],
				c["preview_from"] >= 0 and c["hit_at"] >= 0 and lead >= MIN_LEAD and c["preview_from"] <= 1,
				"preview frame %s damage frame %s" % [c["preview_from"], c["hit_at"]])
		_t.check("%s: the drawn ring is the committed area" % key,
			a.has("drawn_radius") and absf(float(a["drawn_radius"]) - float(ra.get("radius", 0.0))) < TOL and a["drawn_round"]
				and Vector2(a["drawn_at"].x - ra["at"].x, a["drawn_at"].z - ra["at"].z).length() < TOL,
			"drawn %s committed %s" % [a.get("drawn_radius"), ra.get("radius")])
		var want: Color = ElementField.fusion_colour(key)
		_t.check("%s: the drawn ring wears the fusion's colour" % key, a.has("drawn_colour")
			and Color(a["drawn_colour"].r, a["drawn_colour"].g, a["drawn_colour"].b).is_equal_approx(want), "%s" % [a.get("drawn_colour")])
		_t.check("%s: a probe just inside the ring is hit" % key, float(a["inside"].hp) < float(a["hp_inside"]) - TOL, "")
		_t.eq("%s: a probe just outside the ring is untouched" % key, float(a["outside"].hp), float(a["hp_outside"]))
		# 4: resolved once.
		_t.check("%s: the fusion spends both statuses" % key, a["status_after"] == "" and b["status_after"] == "",
			"%s / %s" % [a["status_after"], b["status_after"]])
		var before := _fused.size()
		_give(a["centre"], pair[1])
		_t.check("%s: a repeat second hit fuses nothing (one status again)" % key,
			_fused.size() == before and _field.status_of(a["centre"]) == pair[1], "status %s" % [_field.status_of(a["centre"])])
		# 5: elite rules.
		var de: float = float(e["hp_centre"]) - float(e["centre"].hp)
		match String(row.get("kind", "")):
			"control":
				_t.check("%s: a normal dummy is held" % key, a["held_seen"] and b["held_seen"], "")
				_t.check("%s: an elite dummy takes no control effect" % key, not e["held_seen"] and not e.get("result", {}).is_empty(), "")
			"sustained":
				_t.check("%s: an elite takes at most 10%% of the normal sustained damage" % key,
					da > 0.0 and de > 0.0 and de <= ELITE_SHARE_MAX * da + TOL, "elite %.4f normal %.4f" % [de, da])
				_t.check("%s: no hold from a sustained fusion" % key, not a["held_seen"], "")
			_:
				_t.check("%s: a burst holds nothing" % key, not a["held_seen"] and not e["held_seen"], "")
				_t.check("%s: a burst hits an elite like any dummy" % key, absf(de - da) <= TOL * da, "elite %.4f normal %.4f" % [de, da])
		var card: String = card_found.get("fusion:" + key, "")
		_t.eq("%s: the codex card is the row's card text" % key, card, Elements.card_text(row))
		_t.check("%s: the immunity text on the card equals the data row" % key,
			String(row.get("immunity", "")) != "" and card.contains(String(row.get("immunity", ""))), "card '%s'" % card)
	_t.check("nothing is still held after the windows", _clusters.all(func(c): return not _field.is_held(c["centre"])), "")
	_clear()
	_t.eq("every check ran", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


func _brief(r: Dictionary) -> String:
	return "%s/%s r%.2f s%.2f" % [r.get("behaviour", "?"), r.get("kind", "?"), float(r.get("radius", -1.0)), float(r.get("seconds", -1.0))]


# A frozen, unplated chaser with a bottomless pool, away from the ball so nothing touches it.
func _dummy(offset: Vector3, elite := false) -> Node3D:
	var e := _dummy_at(_game.player.ball_position() + offset)
	if elite:
		e.set_meta("elite_pack", true)
	return e


func _dummy_at(spot: Vector3) -> Node3D:
	var e: Node3D = _combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(spot.x, spot.z, 2.4))
	_spawned.append(e)
	e.hp = BIG
	e.max_hp = BIG
	e.plating = 0.0
	e.set_physics_process(false)
	e.set_process(false)
	return e


func _clear() -> void:
	for e in _spawned:
		if is_instance_valid(e):
			e.remove_from_group("enemy")
			e.queue_free()
	_spawned.clear()
