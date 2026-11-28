extends SceneTree

const AppShell := preload("res://src/core/app_shell.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")

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
	_t.check("scan self-check: a planted inline check is caught", not SourceScan.search(_t, "\tif DisplayServer.get_name() != \"headless\":\n", PATTERN).is_empty(), "planted line")
	_t.check("scan self-check: the helper call passes", SourceScan.search(_t, "\tif not AppShell.headless():\n", PATTERN).is_empty(), "the call")
	var sources := SourceScan.sources(_t, ["res://src"])
	var strays: Array = []
	for file in sources:
		if file == OWNER:
			continue
		var number := 0
		for text in String(sources[file]).split("\n"):
			number += 1
			if not text.strip_edges().begins_with("#") and not SourceScan.search(_t, text, PATTERN).is_empty():
				strays.append("%s:%d" % [file, number])
	_t.check("src asks AppShell.headless(), never the display server's name", strays.is_empty(), "strays %s" % [strays])
	_t.check("the scan saw files", sources.size() > 200, "%d files" % sources.size())
	quit(_t.verdict())
