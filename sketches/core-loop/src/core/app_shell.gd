extends RefCounted

# Godot loads the configured icon from the raw SVG, which an exported .pck omits; apply() sets it from the imported texture.


# Godot's headless dummy renderer has non-thread-safe mesh RIDs, so callers check headless() to keep mesh loads on the main thread.
static func headless() -> bool:
	return DisplayServer.get_name() == "headless"


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
