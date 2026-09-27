extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")

# Contextual key glyphs retire after three successful uses, and stay retired:
#   - a fresh profile shows the grapple glyph whenever the grapple is available;
#   - three hooks later it never shows again, while the untouched mount glyph still does;
#   - an E drop off the pylon is not a slingshot, a slingshot is;
#   - a new profile read from the same file keeps the count, so a restart remembers.

var _game
var _failures := 0
var _wait := 0
var _started := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	_wait += 1
	if _wait < 3:
		return false
	var glyphs = _game.hud.key_glyphs
	var fresh: Array = glyphs.shown({"grapple": true, "mount": true})
	for i in 3:
		_game.events.grapple_fired.emit(Vector3.ZERO)
	var after: Array = glyphs.shown({"grapple": true, "mount": true})
	_report("grapple retires", fresh == ["mount", "grapple"] and after == ["mount"] and glyphs.retired("grapple"),
		"fresh profile shows %s; after 3 hooks it shows %s" % [fresh, after])

	_game.events.dismounted.emit(Vector3.ZERO)
	var dropped: int = _game.hud.profile.uses("slingshot")
	_game.events.dismounted.emit(Vector3(0.0, 4.0, 9.0))
	var slung: int = _game.hud.profile.uses("slingshot")
	_report("slingshot counts only a slingshot", dropped == 0 and slung == 1,
		"an E drop counted %d, a slingshot then counted %d" % [dropped, slung])

	var reread := UiProfile.new(_game.storage_dir)
	_report("persisted", reread.uses("grapple") == 3 and reread.uses("mount") == 0 and reread.path.begins_with(_game.storage_dir),
		"a profile read back from %s holds grapple %d, mount %d" % [reread.path, reread.uses("grapple"), reread.uses("mount")])
	print("ui_key_glyph_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
