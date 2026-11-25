extends Control

const Keycap := preload("res://src/ui/keycap.gd")


var key := ""
var color := Color.WHITE
var height := 24.0


func _init(key_name := "", tint := Color.WHITE, cap_height := 24.0) -> void:
	key = key_name
	color = tint
	height = cap_height
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Keycap.size_of(key, height)


func drawn_words() -> PackedStringArray:
	return Keycap.words(key)


func _draw() -> void:
	Keycap.draw(self, size * 0.5, key, color, height)
