extends SceneTree

const AppShell := preload("res://src/core/app_shell.gd")

# The launch shell: the log line reads the live project settings, a headless run never calls
# set_icon, and the configured icon loads as a texture with pixels so an export can set it.

var _t := preload("res://tests/support/t.gd").new("app_shell_test")


func _initialize() -> void:
	var line: String = AppShell.shell_line("icon test")
	_t.check("line_name", line.contains("name=Scrapkeep"), line)
	_t.check("line_splash_bg", line.contains("splash_bg=#242a28"), line)
	_t.check("line_splash", line.contains("splash=res://assets/app/scrapkeep_splash.png"), line)
	_t.check("line_icon", line.ends_with("icon=icon test"), line)
	_t.eq("no_set_icon_when_off", AppShell.set_window_icon(false), "icon skipped (headless)")
	if AppShell.headless():
		_t.eq("headless_apply", AppShell.apply(), "icon skipped (headless)")
	var path := str(ProjectSettings.get_setting("application/config/icon"))
	var tex := load(path) as Texture2D
	_t.check("icon_texture", tex != null, path)
	var img: Image = tex.get_image() if tex != null else null
	_t.check("icon_image", img != null and not img.is_empty(), path)
	quit(_t.verdict())
