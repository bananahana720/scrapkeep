extends SceneTree

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const T := preload("res://tests/support/t.gd")

class ErrorLog extends Logger:
	var errors := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors += 1

var t := T.new("teardown_material_test")
var error_log := ErrorLog.new()


func _initialize() -> void:
	OS.add_logger(error_log)
	_run.call_deferred()


func _run() -> void:
	for body in [false, true]:
		var label := "Warden" if body else "Customize preview"
		var slot := "ancient_light" if body else "pilot"
		var mesh := BoxMesh.new()
		var authored := StandardMaterial3D.new()
		authored.resource_name = slot
		mesh.material = authored
		var parent := Node3D.new()
		var view := MeshInstance3D.new()
		view.mesh = mesh
		parent.add_child(view)
		root.add_child(parent)
		var painter := HeroAssets.new()
		var rec := {"materials": {}}
		if body:
			painter._paint_body(parent, rec)
		else:
			painter.paint(parent, {"class": Color.CORAL})
		var material := view.get_surface_override_material(0)
		var lifetime: WeakRef = weakref(material)
		var rid := material.get_rid()
		var color: Color = material.albedo_color
		t.check(label + " installs its surface override", material != authored)
		material = null
		painter.free()
		rec.clear()
		t.eq(label + " keeps the same material after its owner is freed", view.get_surface_override_material(0).get_rid(), rid)
		t.eq(label + " keeps its live colour", view.get_surface_override_material(0).albedo_color, color)
		for i in 3:
			await process_frame
		var before := error_log.errors
		parent.free()
		t.eq(label + " frees with no engine error", error_log.errors, before)
		t.check(label + " releases the material after its instance", lifetime.get_ref() == null)
	OS.remove_logger(error_log)
	quit(t.verdict())
