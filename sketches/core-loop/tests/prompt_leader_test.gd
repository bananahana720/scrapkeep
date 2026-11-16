extends SceneTree

# The 2D sign mode of WorldPrompt (leader geometry, slots, how a sign fits its slot). The reward gates
# no longer use it: their names are plates on the gates (reward_gates.gd, reward_gate_nameplate_test).
# The mode stays while this test and ui_contract_test drive it, and goes with them.

const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const Hud := preload("res://src/ui/hud.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("prompt_leader_test")


func _initialize() -> void:
	var p := WorldPrompt.new()
	p.set_parts("Impact Driver", "+6 punch")
	p.position = Vector2(400.0, 460.0)
	p.aim = Vector2(520.0, 300.0)
	_t.eq("planted: a prompt that is not a gate's offer draws no leader", p.leader_end(), Vector2.INF)
	p.on_anchor = true
	_t.eq("a gate's name leads up to where its gate projects", p.position + p.leader_end(), p.aim)
	p.aim = Vector2(460.0, 520.0)
	_t.eq("no leader to an anchor below the name", p.leader_end(), Vector2.INF)
	p.aim = p.position + Vector2(p.shown_extent().x * 0.5, -10.0)
	_t.eq("no leader shorter than LEADER_MIN", p.leader_end(), Vector2.INF)
	p.aim = Vector2.INF
	_t.eq("no leader before the HUD has placed it", p.leader_end(), Vector2.INF)
	# The gate's sign above the play view: the line stops at the view's top edge, with no dot.
	var room := Rect2(0.0, 261.0, 1600.0, 297.0)
	p.aim_at(Vector2(520.0, 40.0), room)
	_t.check("planted: a sign above the view cuts the line at the view's top edge", p.aim_cut and is_equal_approx((p.position + p.leader_end()).y, room.position.y),
		"%s cut %s" % [p.position + p.leader_end(), p.aim_cut])
	p.aim_at(Vector2(520.0, 300.0), room)
	_t.check("a sign inside the view keeps the whole line and its dot", not p.aim_cut and p.position + p.leader_end() == Vector2(520.0, 300.0))
	var size := Vector2(1600.0, 900.0)
	var signs := ScreenRegions.sign_room(size)
	# Planted: a sign standing at the room's very top, its gate above the view, draws nothing up into the
	# toast and objective bands (CONTRACTS.md, UI regions): the cut leaves a line of no length.
	p.position = Vector2(700.0, signs.position.y)
	p.aim_at(Vector2(800.0, 40.0), signs)
	_t.check("a sign at the room's top draws no leader", p.leader_end() == Vector2.INF and p.aim_cut, "%s cut %s" % [p.leader_end(), p.aim_cut])
	# A sign pushed below the reticle's ring, its gate above the ring: the leader ends at the ring's edge
	# rather than running through it, and still draws although the stub is short.
	var ring := Rect2(Vector2(740.0, 380.0), Vector2(120.0, 120.0))
	p.position = Vector2(620.0, 512.0)
	p.aim_at(Vector2(800.0, 300.0), signs, ring)
	var tip: Vector2 = p.position + p.leader_end()
	_t.check("a leader that would cross the ring ends at its edge", p.aim_cut and p.leader_end().is_finite() and ring.grow(1.0).has_point(tip) and not ring.grow(-1.0).has_point(tip), "%s" % tip)
	p.aim_at(Vector2(800.0, 300.0), signs, Rect2(Vector2(100.0, 380.0), Vector2(120.0, 120.0)))
	_t.check("a ring off the line leaves the leader whole", not p.aim_cut and p.position + p.leader_end() == Vector2(800.0, 300.0))
	# Slots: each gate owns the room between the midpoints to its neighbours, inset by half the gap.
	var columns: Array[float] = [300.0, 500.0, 900.0]
	var slots: Array[Rect2] = []
	for i in columns.size():
		slots.append(ScreenRegions.sign_slot(columns, i, size))
	_t.check("each slot holds its own column", slots.all(func(r): return r.has_area()) and columns.size() == 3 and slots[0].has_point(Vector2(300.0, 300.0)) and slots[1].has_point(Vector2(500.0, 300.0)) and slots[2].has_point(Vector2(900.0, 300.0)), "%s" % [slots])
	_t.check("slots never overlap and keep the gap", not slots[0].intersects(slots[1]) and not slots[1].intersects(slots[2]) and is_equal_approx(slots[1].position.x - slots[0].end.x, ScreenRegions.PROMPT_GAP), "%s" % [slots])
	_t.check("the outermost slots run to the room's sides", is_equal_approx(slots[0].position.x, signs.position.x) and is_equal_approx(slots[2].end.x, signs.end.x))
	var off: Array[float] = [50.0, 250.0]
	_t.check("planted: a gate off the room's side has no slot, so no sign", not ScreenRegions.sign_slot(off, 0, size).has_area() and ScreenRegions.sign_slot(off, 1, size).has_area())
	var twin: Array[float] = [700.0, 700.0]
	_t.check("two gates on one column have no slot", not ScreenRegions.sign_slot(twin, 0, size).has_area() and not ScreenRegions.sign_slot(twin, 1, size).has_area())
	# A sign fits its slot's width: detail wrapped to at most two lines, then the name alone, then the floor.
	var g := WorldPrompt.new()
	g.set_parts("Rime Rounds", "+1 special charge. Kills refill it, 12s apart.")
	g.on_anchor = true
	g.near = true
	var need0 := g.sign_need(0)
	var need1 := g.sign_need(1)
	var need2 := g.sign_need(2)
	_t.check("the levels need less width one after another", need1 < need0 and need2 < need1 and need2 > 0.0, "%s %s %s" % [need0, need1, need2])
	_t.eq("a wide slot shows the detail", g.fit_sign(360.0), 0)
	_t.check("the detail is at most two lines and inside its rectangle", g.shown_lines().size() <= 3 and g.text_width() <= g.shown_extent().x + 0.01, "%s %s" % [g.shown_lines(), g.text_width()])
	_t.eq("a slot narrower than the detail shows the name", g.fit_sign((need0 + need1) * 0.5), 1)
	_t.check("the name alone has one line", g.shown_lines().size() == 1 and g.text_width() <= g.shown_extent().x + 0.01)
	_t.eq("a slot narrower than the name shows it at the floor size", g.fit_sign(need1 - 4.0), 2)
	_t.check("the floor size is the band prompts' name size", g.title_size() == WorldPrompt.SIGN_FLOOR_SIZE and g.title_size() == WorldPrompt.TITLE_SIZE)
	_t.eq("a slot narrower than the floor shows nothing", g.fit_sign(need2 - 1.0), WorldPrompt.SIGN_LEVELS)
	# Hysteresis: it keeps what it shows until the slot is narrower than the level's need, and takes a
	# better level only when the slot is wider than the need plus two margins.
	g.fit_sign(need1 + 1.0)
	_t.eq("a name takes the detail only when the slot is a margin wider", g.fit_sign(need0 + 2.0 * WorldPrompt.SIGN_HYSTERESIS - 1.0), 1)
	_t.eq("and takes it once the slot is wider than that", g.fit_sign(need0 + 2.0 * WorldPrompt.SIGN_HYSTERESIS + 1.0), 0)
	_t.eq("a sign showing detail keeps it down to its need", g.fit_sign(need0 + 1.0), 0)
	_t.eq("and loses it below", g.fit_sign(need0 - 1.0), 1)
	g.near = false
	_t.eq("a ball away from the gate shows the name alone", g.fit_sign(360.0), 1)
	g.set_parts("Rime Rounds", "+1 special charge. Kills refill it, 12s apart.\n* completes Tesla Pylon *")
	g.near = true
	_t.check("a detail that needs more than two lines (with its mark) shows the name alone", g.sign_need(0) == INF and g.fit_sign(360.0) == 1)
	g.free()
	# Another prompt's place does not move: a band prompt lands where the band gave it before signs
	# (clamp_prompt, then free_spot in the band) and keeps its type size.
	var band_prompt := WorldPrompt.new()
	band_prompt.set_parts("Fabricating...", "3 cogs")
	var band := ScreenRegions.rect("prompts", size)
	var at := Vector2(800.0, 1000.0)
	var old_way: Rect2 = Hud.free_spot(Rect2(ScreenRegions.clamp_prompt(at, band_prompt.shown_extent(), size), band_prompt.shown_extent()), [] as Array[Rect2], band)
	var now: Rect2 = Hud.prompt_spot(band_prompt, at, size, [] as Array[Rect2])
	_t.check("a band prompt lands where it did before signs", old_way.size != Vector2.ZERO and now == old_way, "%s vs %s" % [now, old_way])
	_t.check("a band prompt keeps its type size", not band_prompt.on_anchor and band_prompt.title_size() == WorldPrompt.TITLE_SIZE and band_prompt.detail_size() == WorldPrompt.DETAIL_SIZE)
	band_prompt.free()
	p.free()
	quit(_t.verdict())
