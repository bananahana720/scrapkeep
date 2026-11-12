extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")

# Integration I2, the screen layout from the first windowed visual QA pass:
#   - the four bands (top, toasts, prompts, bottom) never overlap at 1600x900 or
#     1280x720, and every HUD piece sits inside its own band at both sizes;
#   - three identical toasts show once, and the band holds one (v2: the newest wins);
#   - reward-gate prompts and a prompt whose anchor stands high above the camera are
#     placed inside the prompts band, apart from one another;
#   - the field notes legend shows each shape's glyph, not its key word;
#   - the two zones carry the world's map titles.

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
	var rects: Array = _hud.prompt_rects.values()
	var inside := rects.all(func(r): return band.grow(0.5).encloses(r))
	var apart := true
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			apart = apart and not (rects[i] as Rect2).intersects(rects[j])
	var gates_open: bool = _game.ctx.build.gates.is_open()
	var clear_of_toasts := rects.all(func(r): return not (r as Rect2).intersects(ScreenRegions.rect("toasts", size)) and not (r as Rect2).intersects(ScreenRegions.rect("top", size)))
	_report("prompts in band", gates_open and rects.size() == ScreenRegions.MAX_PROMPTS and inside and apart and clear_of_toasts,
		"gates open %s; %d prompts placed at %s inside the prompts band %s, apart %s, clear of the top and toast bands %s"
			% [gates_open, rects.size(), rects, band, apart, clear_of_toasts])
	# A gate is chosen by steering at it from across the yard, so its prompt says what it gives
	# (the verb, the effect) at that range, not only beside it; any other prompt keeps the short range.
	var ball: Vector3 = _game.player.shown_position()
	var gate_prompts: Array = _hud.prompt_rects.keys().filter(func(p): return p.get_parent() != _high)
	var far: Array = gate_prompts.filter(func(p): return ball.distance_to(p.anchor_point()) > WorldPrompt.DETAIL_RANGE)
	var high: Array = _hud.prompt_rects.keys().filter(func(p): return p.get_parent() == _high)
	_report("gate prompts say what they give from range", not far.is_empty() and far.all(func(p): return p.near and p.shown_lines().size() >= 2 and String(p.shown_lines()[1]).strip_edges() != "")
			and high.all(func(p): return not p.near and is_equal_approx(p.detail_range, WorldPrompt.DETAIL_RANGE)),
		"%d gate prompts, %d beyond %d m, their lines %s; the other prompt near %s"
			% [gate_prompts.size(), far.size(), int(WorldPrompt.DETAIL_RANGE), far.map(func(p): return p.shown_lines()), high.map(func(p): return p.near)])
	# PF-22: each gate's name aims its leader at its own gate (the leader draws when the gate stands
	# above the name, prompt_leader_test); a prompt that is not a gate's offer has none.
	var cam: Camera3D = _game.camera.cam
	var room := Rect2(0.0, ScreenRegions.rect("toasts", size).end.y, size.x, ScreenRegions.rect("prompts", size).position.y - ScreenRegions.rect("toasts", size).end.y)
	var own := true
	for p in gate_prompts:
		var aimed: bool = not p.aim.is_finite() or p.aim_cut or p.aim.distance_to(cam.unproject_position(p.anchor_point())) < 1.0
		var in_view: bool = not p.leader_end().is_finite() or (p.position + p.leader_end()).y >= room.position.y - 0.5
		own = own and p.leader and aimed and in_view
	_report("gate names aim at their own gates", not gate_prompts.is_empty() and own and high.all(func(p): return not p.leader and not p.leader_end().is_finite()),
		"%d gate prompts aiming at their own gates %s; the other prompt has a leader %s" % [gate_prompts.size(), own, high.map(func(p): return p.leader)])
