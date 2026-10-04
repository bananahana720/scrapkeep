extends SceneTree

const Game := preload("res://src/game.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const MISSING := "res://assets/models/c1_missing_shell.glb"
const MISSING_PILOT := "res://assets/models/c1_missing_pilot.glb"
const MISSING_PREVIEW := "res://assets/models/c1_missing_preview.glb"

# Rule: an unavailable GLB warns once per path on the loader, returns null without
# script errors, and leaves the primitive player, pilot and live preview visible.
# Repeated requests and frame steps must add no warning. Switching from a dressed
# class to an unavailable shell must restore the original primitive's render state.


class CapturedLog:
	extends Logger
	var warnings: Array[String] = []
	var script_errors: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings.append(code + rationale)
		elif error_type == Logger.ERROR_TYPE_SCRIPT:
			script_errors.append(code + rationale)

	func warnings_for(path: String) -> int:
		return warnings.filter(func(text): return path in text).size()


class MissingAssets:
	extends HeroAssets
	var replace_path: String = SHELLS[DEFAULT_CLASS]
	var missing_path := MISSING

	func _scene(path: String) -> Node:
		return super._scene(missing_path if path == replace_path else path)


class MissingPreview:
	extends ClassPreview

	func _build_shell() -> void:
		_painter = MissingAssets.new()
		_painter.replace_path = HeroAssets.SHELLS[def.id]
		_painter.missing_path = MISSING_PREVIEW
		super._build_shell()


class StubPlayer:
	extends Node3D
	var class_def: Resource = ClassDef.all()[0]
	var state := {"velocity": Vector3(10.0, 0.0, 0.0)}
	var kit := {"gliding": true}
	var rolling := MeshInstance3D.new()
	var roll := Node3D.new()
	var juice := Node3D.new()

	func _init() -> void:
		add_child(juice)
		juice.add_child(rolling)
		rolling.mesh = SphereMesh.new()
		rolling.layers = 5
		rolling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		rolling.add_child(roll)

	func roll_node() -> Node3D:
		return roll

	func juice_node() -> Node3D:
		return juice

	func class_color() -> Color:
		return class_def.color


var _game
var _log := CapturedLog.new()
var _failures := 0
var _done := false


func _initialize() -> void:
	OS.add_logger(_log)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _check_missing_shell() -> void:
	var hook := MissingAssets.new()
	root.add_child(hook)
	_report("missing fixture", not FileAccess.file_exists(MISSING), MISSING + " does not exist")
	_report("null scene", hook._scene(MISSING) == null, "unavailable GLB returns null")
	_report("one warning", _log.warnings_for(MISSING) == 1, "one actual engine warning names the path")
	hook._scene(MISSING)
	hook.mesh_named(MISSING, "Core")
	_report("repeat request", _log.warnings_for(MISSING) == 1, "second scene and mesh requests add zero warnings")
	var player := StubPlayer.new()
	root.add_child(player)
	hook.attach_player(player)
	var rec: Dictionary = hook.shell_of(player)
	_report("player fallback", rec.core == null and rec.pod == null and player.rolling.mesh is SphereMesh
			and player.rolling.layers == 5 and player.rolling.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"primitive sphere keeps its render layers and shadow")
	for i in 10:
		hook._process(1.0 / 90.0)
	_report("frame requests", _log.warnings_for(MISSING) == 1, "ten frame steps add zero warnings")
	player.class_def = ClassDef.all()[1]
	hook._process(1.0 / 90.0)
	_report("dressed control", rec.core != null and rec.pod != null and player.rolling.layers == 0,
		"available class hides the primitive and fits its hero shell")
	player.class_def = ClassDef.all()[0]
	hook._process(1.0 / 90.0)
	_report("restore fallback", rec.core == null and rec.pod == null and player.rolling.layers == 5
			and player.rolling.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"changing back to an unavailable shell restores the primitive")
	player.free()
	hook.free()


func _check_missing_pilot() -> void:
	var hook := MissingAssets.new()
	hook.replace_path = HeroAssets.PILOTS[HeroAssets.DEFAULT_CLASS]
	hook.missing_path = MISSING_PILOT
	root.add_child(hook)
	var player := StubPlayer.new()
	root.add_child(player)
	hook.attach_player(player)
	var rec: Dictionary = hook.shell_of(player)
	var pilot := rec.pod.find_child("Pilot", true, false) as GeometryInstance3D if rec.pod != null else null
	_report("pilot fallback", rec.core != null and pilot != null and pilot.layers != 0
			and _log.warnings_for(MISSING_PILOT) == 1,
		"missing animated pilot leaves the shell's original seated pilot visible and warns once")
	hook._scene(MISSING_PILOT)
	_report("pilot repeat", _log.warnings_for(MISSING_PILOT) == 1, "repeated pilot path adds zero warnings")
	player.free()
	hook.free()


func _check_missing_preview() -> void:
	var preview := MissingPreview.new(ClassDef.all()[2])
	root.add_child(preview)
	var core := preview.ball.get_node_or_null("Core") as MeshInstance3D if preview.ball != null else null
	_report("preview fallback", core != null and core.mesh is SphereMesh and core.layers != 0
			and preview.ball.has_node("Pod") and _log.warnings_for(MISSING_PREVIEW) == 1,
		"missing preview GLB retains a visible sphere and upright Pod, with one warning")
	preview.paint_id = ""
	preview._process(1.0 / 90.0)
	preview.open = 1.0
	for i in 20:
		preview._process(0.1)
	preview._painter._scene(MISSING_PREVIEW)
	_report("preview repeat", _log.warnings_for(MISSING_PREVIEW) == 1,
		"resting and open Kest preview frames and second request add zero warnings")
	preview.free()


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	_done = true
	_check_missing_shell()
	_check_missing_pilot()
	_check_missing_preview()
	_game.free()
	_report("no script errors", _log.script_errors.is_empty(), "%d captured script errors" % _log.script_errors.size())
	OS.remove_logger(_log)
	print("hero_assets_missing_glb_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
