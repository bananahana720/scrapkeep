extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Hud := preload("res://src/ui/hud.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")

# Integration I2, the screen layout from the first windowed visual QA pass:
#   - the four bands (top, toasts, prompts, bottom) never overlap at 1600x900 or
#     1280x720, and every HUD piece sits inside its own band at both sizes;
#   - three identical toasts show once, and the band holds one (v2: the newest wins);
#   - a reward gate's name hangs from its own gate in the sign room, clear of the ball and the
#     reticle's ring, and a prompt whose anchor stands high above the camera is placed inside
#     the prompts band, apart from one another;
#   - the field notes legend shows each shape's glyph, not its key word;
#   - the two zones carry the world's map titles.

const Parts := preload("res://src/build/parts.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const SIZES := [Vector2(1600.0, 900.0), Vector2(1280.0, 720.0)]
const KEY_WORDS := ["star", "chevron", "cross", "diamond", "wave", "core", "burst", "arrow", "ring", "square", "bar"]

var _game
var _hud
var _failures := 0
var _ticks := 0
var _phase := "boot"
var _wait := 0
var _high: Node3D


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	_wait += 1
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_hud = _game.get_node("Hud")
			_phase = "static"
			_wait = 0
		"static":
			if _wait == 10:
				_check_regions()
				_check_pieces()
				_check_toasts()
				_check_legend()
				_check_names()
				_open_prompts()
				_phase = "prompts"
				_wait = 0
		"prompts":
			if _wait == 6:
				_check_prompts()
				print("int_screen_layout_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


func _check_regions() -> void:
	for size in SIZES:
		var rects: Array[Rect2] = []
		for region in ScreenRegions.ORDER:
			rects.append(ScreenRegions.rect(region, size))
		var clash := []
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				if rects[i].intersects(rects[j]):
					clash.append([ScreenRegions.ORDER[i], ScreenRegions.ORDER[j]])
		var ordered := true
		for i in range(1, rects.size()):
			ordered = ordered and rects[i].position.y >= rects[i - 1].end.y
		_report("regions %dx%d" % [size.x, size.y], clash.is_empty() and ordered and Rect2(Vector2.ZERO, size).encloses(rects[-1]),
			"top %s, toasts %s, prompts %s, bottom %s; overlaps %s" % [_span(rects[0]), _span(rects[1]), _span(rects[2]), _span(rects[3]), clash])


static func _span(r: Rect2) -> String:
	return "%d-%d" % [int(r.position.y), int(r.end.y)]


# Worst case per band: the stage card over the toast row, then a long toast, each with
# the restart meter under it; the objective with its punch and plating bars and three
# cores; every bottom gauge beside the full ability bar.
func _check_pieces() -> void:
	_hud.toast("Warden broken: gates open")
	_hud._process(0.0)
	for i in 3:
		_game.run.add_core("event", Vector3.ZERO)
	for card in [true, false]:
		if card:
			_hud.launch_card.show_card("obj_beacon", "Spillway: the top shelf", Color.WHITE)
		else:
			_hud.launch_card.visible = false
		_hud._process(0.0)
		_hud._restart.set_fraction(1.0)
		_hud._restart.visible = true
		for size in SIZES:
			_hud.layout(size)
			var outside := []
			var pieces: Dictionary = _hud.piece_rects()
			for region in pieces:
				var band := ScreenRegions.rect(region, size)
				for r in pieces[region]:
					if not band.grow(0.5).encloses(r):
						outside.append("%s %s in %s" % [region, r, band])
			_report("hud pieces %dx%d%s" % [size.x, size.y, " with the stage card" if card else ""], outside.is_empty(),
				"every HUD piece inside its band; outside: %s" % [outside])
	_hud._restart.set_fraction(0.0)
	_hud.layout(_hud._screen_size())


func _check_toasts() -> void:
	for i in 3:
		_hud.toast("Reward gates ahead")
	var once: int = _hud.toast_texts().count("Reward gates ahead")
	_hud.toast("Stage 1")
	_hud.toast("Launch!")
	var shown: Array = _hud.toast_texts()
	_report("toast dedupe", once == 1 and shown.size() == ScreenRegions.TOAST_ROWS and shown == ["Launch!"],
		"three identical toasts showed %d row; after two more the band shows %s (cap %d)" % [once, shown, ScreenRegions.TOAST_ROWS])


func _check_legend() -> void:
	var legend := FieldNotes.legend_bbcode()
	var keyed := []
	for line in legend.split("\n"):
		var body := line.substr(line.find("]") + 1) if line.begins_with("[color") else ""
		for word in KEY_WORDS:
			if body.begins_with(word + " "):
				keyed.append(body)
	var glyphs := ["★", "›", "×", "◆", "≈"].filter(func(g): return legend.contains(g))
	_report("legend glyphs", keyed.is_empty() and glyphs.size() == 5,
		"legend shows %s and %d lines that start with a key word %s" % [glyphs, keyed.size(), keyed.slice(0, 2)])


func _check_names() -> void:
	var terrain = _game.ctx.terrain
	var names := []
	var ok := true
	var compared := 0
	for stage in StageDefs.COUNT:
		var shown: String = StageDefs.of(stage + 1)["name"]
		names.append(shown)
		if not shown.contains("placeholder"):
			compared += 1
			ok = ok and shown == terrain.map_for(stage + 1).title
	_report("stage names", ok and compared == StageDefs.COUNT and not names[1].begins_with("Spillway"),
		"stage names %s: %d non-placeholder rows match the world's map titles" % [names, compared])


# The real gates, opened by flow's gates state, and one prompt whose anchor stands
# 40 m above the camera's line, which would draw at the very top of the screen.
func _open_prompts() -> void:
	_game.events.flow_changed.emit("gates")
	var cam: Camera3D = _game.camera.cam
	_high = Node3D.new()
	_game.ctx.root.add_child(_high)
	_high.global_position = cam.global_position - cam.global_basis.z * 20.0 + Vector3.UP * 40.0
	var prompt := WorldPrompt.new()
	prompt.text = "a prompt anchored high above the view"
	prompt.attach(_high, Vector3.ZERO, 200.0)
	_high.add_child(prompt)


func _check_prompts() -> void:
	var size: Vector2 = _hud._screen_size()
	var band := ScreenRegions.rect("prompts", size)
	var signs := ScreenRegions.sign_room(size)
	var ball: Vector3 = _game.player.shown_position()
	var gate_prompts: Array = _hud.prompt_rects.keys().filter(func(p): return p.get_parent() != _high)
	var high: Array = _hud.prompt_rects.keys().filter(func(p): return p.get_parent() == _high)
	var rects: Array = _hud.prompt_rects.values()
	var inside := gate_prompts.all(func(p): return signs.grow(0.5).encloses(_hud.prompt_rects[p])) \
		and high.all(func(p): return band.grow(0.5).encloses(_hud.prompt_rects[p]))
	var apart := true
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			apart = apart and not (rects[i] as Rect2).intersects(rects[j])
	# A gate's sign keeps off the ball and the reticle's ring; the band prompt keeps its old rule.
	var keep_clear: Array = _hud._sign_keep_clear() if _hud.has_method("_sign_keep_clear") else []
	var clear := gate_prompts.all(func(p): return not keep_clear.any(func(k): return (k as Rect2).intersects(_hud.prompt_rects[p])))
	var gates_open: bool = _game.ctx.build.gates.is_open()
	var clear_of_bands := rects.all(func(r): return ["top", "toasts", "bottom"].all(func(b): return not (r as Rect2).intersects(ScreenRegions.rect(b, size))))
	_report("prompts in place", gates_open and rects.size() == ScreenRegions.MAX_PROMPTS and not gate_prompts.is_empty() and inside and apart and clear and clear_of_bands,
		"gates open %s; %d prompts placed at %s; gates in the sign room %s and the other in the prompts band %s: %s, apart %s, gate signs clear of the ball and reticle %s, clear of the top, toast and bottom bands %s"
			% [gates_open, rects.size(), rects, signs, band, inside, apart, clear, clear_of_bands])
	# A gate is chosen by steering at it from across the yard, so the ball is "near" every gate from range,
	# and a sign shows what it gives (the verb, the effect) wherever its slot is wide enough for it; any
	# other prompt keeps the short range.
	var far: Array = gate_prompts.filter(func(p): return ball.distance_to(p.anchor_point()) > WorldPrompt.DETAIL_RANGE)
	_report("gate prompts say what they give from range", not far.is_empty() and far.all(func(p): return p.near and p.sign_level() >= 0 and p.sign_level() <= 1 and (p.sign_level() > 0 or p.shown_lines().size() >= 2))
			and high.all(func(p): return not p.near and is_equal_approx(p.detail_range, WorldPrompt.DETAIL_RANGE)),
		"%d gate prompts, %d beyond %d m, their lines %s and levels %s; the other prompt near %s"
			% [gate_prompts.size(), far.size(), int(WorldPrompt.DETAIL_RANGE), far.map(func(p): return p.shown_lines()), far.map(func(p): return p.sign_level()), high.map(func(p): return p.near)])
	# PF-22: each gate wears its own name (_wears_own_name), and the other prompt draws no leader.
	var cam: Camera3D = _game.camera.cam
	var columns: Array = gate_prompts.map(func(p): return cam.unproject_position(p.anchor_point()))
	var own := true
	var notes: Array = []
	for i in gate_prompts.size():
		var p = gate_prompts[i]
		var wears := _wears_own_name(p, _hud.prompt_rects[p], columns[i], columns, signs, _hud.part_name.avoid)
		own = own and wears
		notes.append("%s at %s, sign %s: wears it %s" % [p.parts()["title"], columns[i], _hud.prompt_rects[p], wears])
	_report("each gate wears its own name", not gate_prompts.is_empty() and own and high.all(func(p): return not p.leader_end().is_finite()),
		"%d gate prompts: %s; the other prompt draws a leader %s" % [gate_prompts.size(), notes, high.map(func(p): return p.leader_end().is_finite())])
	_sweeps()


# Whether a placed sign wears its own gate's name: its rectangle holds its own column and no other
# gate's, the column's own is the one nearest its middle, it stands at its crossbar point or below
# (never above it), and it either hangs where the point puts it (6 px under it, kept in the sign room)
# or draws a leader that ends on its gate, at the ring's edge when the ring is in the way, or at the
# room's top when the gate is above it. `at` is the gate's point on screen.
func _wears_own_name(p, r: Rect2, at: Vector2, columns: Array, signs: Rect2, ring: Rect2) -> bool:
	var mid := r.get_center().x
	var nearest := columns.all(func(c): return absf(c.x - mid) >= absf(at.x - mid) - 0.5)
	var holds := at.x >= r.position.x and at.x <= r.end.x and columns.all(func(c): return c == at or c.x < r.position.x or c.x > r.end.x)
	var below := r.position.y >= at.y - 0.01
	var hangs := absf(r.position.y - maxf(at.y + ScreenRegions.SIGN_DROP, signs.position.y)) < 1.0
	var end: Vector2 = p.position + p.leader_end() if p.leader_end().is_finite() else Vector2.INF
	var leads: bool = end.is_finite() and (end.distance_to(at) < 1.0 or (p.aim_cut and ((ring.has_area() and ring.grow(1.0).has_point(end)) or absf(end.y - signs.position.y) < 1.0)))
	return holds and nearest and below and (hangs or leads)


var _sweep_texts := [["Rime Rounds", "+6 punch. Shots freeze water."], ["Spare Cell", "+1 special charge. Kills refill it, 12s apart."],
	["Breaker Drive", "+8 punch, +35% weapon damage. From Wrecking Ball."], ["Storm Mast", "+6 punch, +20% fire rate. From Tesla Pylon."]]
var _opening := {}
var _sweep_stats := {"cases": 0, "signs": 0, "none_s3": 0, "none_s4": 0, "none_s5": 0, "bad": [], "name_at_1280_close": 0, "detail_at_1280_close": 0}


# Real WorldPrompt gates, anchored in the world at chosen screen points, placed by the HUD's own
# place_prompts: T1 sweeps 2, 3 and 4 gates over spacings, positions and the steered gate at the reticle
# at both sizes; T3 slides three gates across the view; T4 stands four.
func _sweeps() -> void:
	for node in get_nodes_in_group(ScreenRegions.PROMPT_GROUP):
		node.remove_from_group(ScreenRegions.PROMPT_GROUP)
		node.visible = false
	_add_widest_real_gate()
	var original: Vector2i = root.content_scale_size
	for size in SIZES:
		root.content_scale_size = Vector2i(size)
		var screen: Vector2 = _hud._screen_size()
		var room := ScreenRegions.sign_room(screen)
		var rows := [screen.y * 0.25, screen.y * 0.47, screen.y * 0.78]
		var case_index := 0
		for n in [2, 3, 4]:
			for spacing in range(0, 401, 20):
				var lefts: Array = range(-200, int(screen.x) + 1, 40)
				for k in n:
					lefts.append(int(screen.x * 0.5) - k * spacing)
				for left in lefts:
					var xs: Array = []
					for k in n:
						xs.append(float(left + k * spacing))
					_sweep_case(xs, rows[case_index % 3], screen, room)
					case_index += 1
	root.content_scale_size = original
	var s := _sweep_stats
	_report("sweep: every shown sign wears its own name, every missing one has its reason", s["cases"] > 0 and s["signs"] > 0 and s["bad"].is_empty(),
		"%d cases, %d signs checked, %d gates with no sign (outside the room or no slot %d, too narrow %d, no row %d); first failures %s" % [s["cases"], s["signs"], s["none_s3"] + s["none_s4"] + s["none_s5"], s["none_s3"], s["none_s4"], s["none_s5"], s["bad"].slice(0, 4)])
	_report("sweep: gates 160 to 220 px apart at 1280x720 show", s["detail_at_1280_close"] + s["name_at_1280_close"] > 0, "three gates 160 to 220 px apart: %d signs with detail, %d with the name alone" % [s["detail_at_1280_close"], s["name_at_1280_close"]])
	var keys := _opening.keys()
	keys.sort()
	for key in keys:
		var row: Dictionary = _opening[key]
		print("[opening spacing 160 to 280 px] %s: %d visible gates in the sign area, %d with no sign (%d too near a neighbour or off the room's sides, %d slot too narrow, %d no row free)" % [key, row["visible"], row["unnamed"], row["near"], row["narrow"], row["row"]])
	_hysteresis_sweep()
	_slide_sweep()
	_four_gates()


# The real gate prompt whose name is widest at the floor size joins the sweep's names, so the widest
# real sign is placed beside the short ones.
func _add_widest_real_gate() -> void:
	var widest := 0.0
	var pick: Array = []
	for id in Parts.ids():
		var d: Resource = Parts.offer_def(id, [])
		if d == null:
			continue
		var parts: Dictionary = RewardGates.prompt_parts({"name": Parts.display_name(id), "verb": d.verb, "punch": d.punch, "text": d.text, "mark": ""})
		var probe := WorldPrompt.new()
		probe.set_parts(parts["title"], parts["detail"], parts["icon"])
		probe.on_anchor = true
		probe.near = true
		var need := maxf(probe.sign_need(2), probe.sign_need(0) if probe.sign_need(0) != INF else 0.0)
		if need > widest:
			widest = need
			pick = [parts["title"], parts["detail"]]
		probe.free()
	_sweep_texts.append(pick)


func _gate_set(xs: Array, y: float, texts_from: int = 0) -> Array:
	var cam: Camera3D = _game.camera.cam
	var out: Array = []
	for i in xs.size():
		var anchor := Node3D.new()
		_game.ctx.root.add_child(anchor)
		anchor.global_position = cam.project_position(Vector2(xs[i], y), 38.0)
		var prompt := WorldPrompt.new()
		var text: Array = _sweep_texts[(i + texts_from) % _sweep_texts.size()]
		prompt.set_parts(text[0], text[1])
		prompt.on_anchor = true
		prompt.attach(anchor, Vector3.ZERO, 500.0)
		prompt.detail_range = 500.0
		anchor.add_child(prompt)
		out.append(prompt)
	return out


func _free_gates(gates: Array) -> void:
	for prompt in gates:
		prompt.get_parent().free()


func _sweep_case(xs: Array, y: float, screen: Vector2, room: Rect2) -> void:
	var gates := _gate_set(xs, y, int(xs[0]) % 3)
	_hud.place_prompts(screen, true)
	var cam: Camera3D = _game.camera.cam
	var columns: Array = gates.map(func(g): return cam.unproject_position(g.anchor_point()))
	var keep: Array = _hud._sign_keep_clear()
	var ring: Rect2 = _hud.part_name.avoid
	var s := _sweep_stats
	s["cases"] += 1
	for i in gates.size():
		var g = gates[i]
		var at: Vector2 = columns[i]
		var lo := room.position.x
		var hi := room.end.x
		for j in gates.size():
			if j != i:
				var mid: float = (columns[j].x + at.x) * 0.5
				if columns[j].x < at.x or (columns[j].x == at.x and j < i):
					lo = maxf(lo, mid + ScreenRegions.PROMPT_GAP * 0.5)
				else:
					hi = minf(hi, mid - ScreenRegions.PROMPT_GAP * 0.5)
		var why := ""
		var tag := "%dx%d %d gates at %s y %d, gate %d" % [int(screen.x), int(screen.y), gates.size(), xs, int(y), i]
		if _hud.prompt_rects.has(g):
			var r: Rect2 = _hud.prompt_rects[g]
			s["signs"] += 1
			var problems: Array = []
			if not (at.x >= lo and at.x <= hi): problems.append("column outside its slot")
			if r.position.x < lo - 0.5 or r.end.x > hi + 0.5 or not room.grow(0.5).encloses(r): problems.append("outside slot or room %s" % [Rect2(lo, room.position.y, hi - lo, room.size.y)])
			if not _wears_own_name(g, r, at, columns, room, ring): problems.append("does not wear its own name")
			if g.text_width() > r.size.x + 0.01: problems.append("text %.1f wider than its rectangle" % g.text_width())
			var rows: Array = g.drawn_rows()
			if g.text_width() <= 0.0 or g.text_width() < float(rows[0]["width"]) - 0.01: problems.append("text_width %.1f is less than the title row the draw lays out" % g.text_width())
			if keep.any(func(k): return (k as Rect2).intersects(r)): problems.append("on the ring or the ball")
			for other in gates:
				if other != g and _hud.prompt_rects.has(other) and (_hud.prompt_rects[other] as Rect2).intersects(r): problems.append("overlaps another sign")
			var drop := r.position.y - maxf(at.y, room.position.y)
			if g.leader_end().is_finite() != (drop >= WorldPrompt.LEADER_MIN): problems.append("leader %s with a drop of %.1f" % [g.leader_end().is_finite(), drop])
			if not problems.is_empty():
				s["bad"].append("%s: %s" % [tag, problems])
			if int(screen.x) == 1280 and gates.size() == 3 and absf(xs[1] - xs[0]) >= 160.0 and absf(xs[1] - xs[0]) <= 220.0:
				if g.sign_level() == 0:
					s["detail_at_1280_close"] += 1
				else:
					s["name_at_1280_close"] += 1
		else:
			if at.x < room.position.x or at.x > room.end.x or at.x < lo or at.x > hi:
				s["none_s3"] += 1
				why = "near" if at.x >= room.position.x and at.x <= room.end.x else ""
			elif hi - lo < g.sign_need(2) - 0.001:
				s["none_s4"] += 1
				why = "narrow"
			elif _no_row_below(g, at, lo, hi, room, keep):
				s["none_s5"] += 1
				why = "row"
			else:
				s["bad"].append("%s: no sign though the slot is %.0f wide and a row is free" % [tag, hi - lo])
		# A gate in sight inside the sign area, at the spacing a real opening has, that still has no sign.
		var spacing: float = absf(xs[1] - xs[0])
		if gates.size() >= 3 and spacing >= 160.0 and spacing <= 280.0 and at.x >= room.position.x and at.x <= room.end.x:
			var key := "%dx%d, %d gates" % [int(screen.x), int(screen.y), gates.size()]
			var row: Dictionary = _opening.get(key, {"visible": 0, "unnamed": 0, "near": 0, "narrow": 0, "row": 0})
			row["visible"] += 1
			if why != "":
				row["unnamed"] += 1
				row[why] += 1
			elif not _hud.prompt_rects.has(g):
				row["unnamed"] += 1
			_opening[key] = row
	_free_gates(gates)


# Whether no row at or below the crossbar point holds the sign at any level its slot is wide enough for.
func _no_row_below(g, at: Vector2, lo: float, hi: float, room: Rect2, keep: Array) -> bool:
	for level in range(0, WorldPrompt.SIGN_LEVELS):
		if level == 0 and not g.near:
			continue
		if not g.apply_level(level, hi - lo):
			continue
		var extent: Vector2 = g.shown_extent()
		var x := clampf(at.x - extent.x * 0.5, lo, hi - extent.x)
		var y := maxf(at.y + ScreenRegions.SIGN_DROP, room.position.y)
		while y + extent.y <= room.end.y + 0.5:
			if not keep.any(func(k): return (k as Rect2).intersects(Rect2(x, y, extent.x, extent.y))):
				return false
			y += 2.0
	return true


# T3: three gates 220 px apart, the middle one's column moved 1 px per frame across the whole view.
# Each sign changes its fit level at most twice and never moves sideways by more than the column did.
func _slide_sweep() -> void:
	var screen: Vector2 = _hud._screen_size()
	var cam: Camera3D = _game.camera.cam
	var gates := _gate_set([0.0, 220.0, 440.0], screen.y * 0.3)
	var levels := [[], [], []]
	var centres := [[], [], []]
	var worst := 0.0
	var m := -300
	while m <= int(screen.x) + 300:
		for i in 3:
			gates[i].anchor.global_position = cam.project_position(Vector2(m + (i - 1) * 220.0, screen.y * 0.3), 38.0)
		_hud.place_prompts(screen, true)
		for i in 3:
			if _hud.prompt_rects.has(gates[i]):
				var level: int = gates[i].sign_level()
				var centre: float = (_hud.prompt_rects[gates[i]] as Rect2).get_center().x
				if not levels[i].is_empty() and levels[i][-1] == level and centres[i].size() > 0 and centres[i][-1][0] == m - 1:
					worst = maxf(worst, absf(centre - centres[i][-1][1]))
				levels[i].append(level)
				centres[i].append([m, centre])
			else:
				levels[i].append(-1)
				centres[i].append([m, 0.0])
		m += 1
	var changes: Array = levels.map(func(l): return _fit_changes(l))
	_free_gates(gates)
	_report("sweep: a column crossing the view changes each sign's fit at most twice and moves it no faster than the column", changes.all(func(c): return c <= 2) and worst <= 1.01,
		"fit changes per gate %s, the largest step of a sign's middle in a frame %.2f px over %d frames" % [changes, worst, levels[0].size()])


# Two gates, the left one's slot width moved a few pixels back and forth inside the hysteresis margin
# above where its detail starts to fit: a sign showing the name keeps it, and a sign showing detail
# keeps it, through every frame.
func _hysteresis_sweep() -> void:
	var screen: Vector2 = _hud._screen_size()
	var cam: Camera3D = _game.camera.cam
	var room := ScreenRegions.sign_room(screen)
	var y := screen.y * 0.25
	var a_x := room.position.x + 20.0
	var gates := _gate_set([a_x, 500.0], y, 1)
	var need0: float = gates[0].sign_need(0)
	var changes := 0
	var levels_seen: Array = []
	for start in [need0 - 10.0, need0 + 40.0]:
		for g in gates:
			g.set_parts(g.parts()["title"], g.parts()["detail"])
			g._level = -1
		var held := -2
		for frame in 60:
			var width: float = start if frame == 0 else (need0 + 2.0 if frame % 2 == 0 else need0 + 30.0)
			var b_x: float = 2.0 * (room.position.x + width + ScreenRegions.PROMPT_GAP * 0.5) - a_x
			gates[1].anchor.global_position = cam.project_position(Vector2(b_x, y), 38.0)
			_hud.place_prompts(screen, true)
			var level: int = gates[0].sign_level()
			if frame > 0 and level != held:
				changes += 1
			held = level
			if frame == 0:
				levels_seen.append(level)
	_free_gates(gates)
	_report("sweep: a slot moving a few px inside the margin does not change a sign's level", changes == 0 and levels_seen == [1, 0],
		"the name held and the detail held through 59 frames each: %d changes; the first frames showed levels %s (want [1, 0])" % [changes, levels_seen])


# How many times the shown fit level changes along a run of frames (-1 is no sign, not a level).
func _fit_changes(levels: Array) -> int:
	var count := 0
	var last := -2
	for v in levels:
		if v < 0:
			continue
		if last >= 0 and v != last:
			count += 1
		last = v
	return count


# T4: four gates in view are all named.
func _four_gates() -> void:
	var screen: Vector2 = _hud._screen_size()
	var gates := _gate_set([320.0, 600.0, 880.0, 1160.0], screen.y * 0.3)
	_hud.place_prompts(screen, true)
	var named: int = gates.filter(func(g): return _hud.prompt_rects.has(g)).size()
	_free_gates(gates)
	_report("four gates in view are all named", named == 4, "%d of 4 gates have a sign" % named)
