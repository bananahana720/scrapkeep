extends Control

# Planted by menu_size_test: a control that handles mouse clicks by hand, as a custom-drawn click target does.


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()
