extends RefCounted

# The launch shell the engine owns: the window icon and the boot splash. Godot loads the
# configured icon from the raw SVG, which an exported pck does not carry, so the window can
# ship without _NET_WM_ICON. apply() sets it from the imported texture, which is exported,
# and prints one line that reads the live project settings so the shell is observable in a log.


static func headless() -> bool:
	return DisplayServer.get_name() == "headless"


# Sets the window icon and returns "icon WxH", "icon missing" or "icon skipped (headless)".
static func apply() -> String:
	var status := set_window_icon(not headless())
	print(shell_line(status))
	return status


static func set_window_icon(do_set: bool) -> String:
	if not do_set:
		return "icon skipped (headless)"
	var path := str(ProjectSettings.get_setting("application/config/icon", ""))
	if path == "" or not ResourceLoader.exists(path):
		return "icon missing"
	var tex := load(path) as Texture2D
	var img := tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		return "icon missing"
	if img.is_compressed():
		img.decompress()
	DisplayServer.set_icon(img)
	return "icon %dx%d" % [img.get_width(), img.get_height()]


static func shell_line(icon_status: String) -> String:
	var bg := ProjectSettings.get_setting("application/boot_splash/bg_color", Color.BLACK) as Color
	return "SCRAPKEEP_SHELL name=%s splash_bg=#%s splash=%s icon=%s" % [
		ProjectSettings.get_setting("application/config/name", ""), bg.to_html(false),
		ProjectSettings.get_setting("application/boot_splash/image", ""), icon_status]
