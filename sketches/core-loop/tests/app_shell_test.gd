extends SceneTree

const AppShell := preload("res://src/core/app_shell.gd")

# The launch shell: the log line reads the live project settings, a headless run never calls
# set_icon, and the configured icon loads as a texture with pixels so an export can set it.
# headless() is the game's one headless question: it answers what the display server says, and
# no other file under src/ spells the display server's name.

const OWNER := "res://src/core/app_shell.gd"
const PATTERN := "\\bDisplayServer\\s*\\.\\s*get_name\\s*\\("

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
	_t.eq("headless answers the display server", AppShell.headless(), DisplayServer.get_name() == "headless")
	var re := RegEx.create_from_string(PATTERN)
	_t.check("scan self-check: a planted inline check is caught", re.search("\tif DisplayServer.get_name() != \"headless\":\n") != null, "planted line")
	_t.check("scan self-check: the helper call passes", re.search("\tif not AppShell.headless():\n") == null, "the call")
	var files := 0
	var strays: Array = []
	for file in _gd_files("res://src"):
		files += 1
		if file == OWNER:
			continue
		var number := 0
		for text in FileAccess.get_file_as_string(file).split("\n"):
			number += 1
			if not text.strip_edges().begins_with("#") and re.search(text) != null:
				strays.append("%s:%d" % [file, number])
	_t.check("src asks AppShell.headless(), never the display server's name", strays.is_empty(), "strays %s" % [strays])
	_t.check("the scan saw files", files > 200, "%d files" % files)
	quit(_t.verdict())


func _gd_files(dir: String) -> Array:
	var out: Array = []
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(sub)))
	return out
