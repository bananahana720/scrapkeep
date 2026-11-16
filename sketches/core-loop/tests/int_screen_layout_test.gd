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
#   - a reward gate's name is a plate on its own gate (tests/reward_gate_nameplate_test.gd holds its
#     rules), and a prompt whose anchor stands high above the camera is placed inside the prompts band;
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
	# Three more band prompts in view, so the cap (MAX_PROMPTS) is reached with one left waiting.
	for i in 3:
		var anchor := Node3D.new()
		_game.ctx.root.add_child(anchor)
		anchor.global_position = cam.global_position - cam.global_basis.z * (24.0 + 4.0 * i) + cam.global_basis.x * (float(i) - 1.0) * 5.0 - Vector3.UP * 2.0
		var extra := WorldPrompt.new()
		extra.text = "band prompt %d\n3 cogs" % i
		extra.attach(anchor, Vector3.ZERO, 200.0)
		anchor.add_child(extra)


func _check_prompts() -> void:
	var size: Vector2 = _hud._screen_size()
	var band := ScreenRegions.rect("prompts", size)
	var rects: Array = _hud.prompt_rects.values()
	var gates: Node3D = _game.ctx.build.gates
	# A reward gate's name is its own prompt, placed by its gate (reward_gates.gd): the HUD places none of them.
	var gate_prompts: Array = _hud.prompt_rects.keys().filter(func(p): return gates.is_ancestor_of(p))
	var names: Array = gates.find_children("Name", "Label", true, false)
	var high: Array = _hud.prompt_rects.keys().filter(func(p): return p.get_parent() == _high)
	var inside := rects.all(func(r): return band.grow(0.5).encloses(r))
	var apart := true
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			apart = apart and not (rects[i] as Rect2).intersects(rects[j])
	var clear_of_bands := rects.all(func(r): return ["top", "toasts", "bottom"].all(func(b): return not (r as Rect2).intersects(ScreenRegions.rect(b, size))))
	_report("prompts in place", gates.is_open() and rects.size() == ScreenRegions.MAX_PROMPTS and inside and apart and clear_of_bands,
		"gates open %s; %d prompts placed (cap %d) at %s in the prompts band %s: %s, apart %s, clear of the top, toast and bottom bands %s"
			% [gates.is_open(), rects.size(), ScreenRegions.MAX_PROMPTS, rects, band, inside, apart, clear_of_bands])
	_report("each gate wears its own name prompt, placed by the gate", gate_prompts.is_empty() and names.size() == gates.offers.size() and names.all(func(p): return p.owner_placed),
		"%d gate prompts placed by the HUD, %d name prompts for %d offers" % [gate_prompts.size(), names.size(), gates.offers.size()])
	_report("the high prompt keeps the short range", high.all(func(p): return not p.near and is_equal_approx(p.detail_range, WorldPrompt.DETAIL_RANGE)),
		"near %s" % [high.map(func(p): return p.near)])
