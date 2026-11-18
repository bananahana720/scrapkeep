extends RefCounted

# The launcher selects the embedded display before Godot initializes its main window.
# A script cannot move a normal Cocoa window in time to prevent the startup flash.
static func apply(root_window: Window) -> void:
	if OS.get_environment("SCRAPKEEP_OFFSCREEN") != "1":
		return
	var driver := DisplayServer.get_name().to_lower()
	if driver != "embedded":
		printerr("offscreen_window: expected the Mac embedded display, got ", driver)
		root_window.get_tree().quit(1)
		return
	print("OFFSCREEN_WINDOW ", OS.get_process_id(), " ", driver)
