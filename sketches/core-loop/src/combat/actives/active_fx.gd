extends RefCounted

const FlashGuard := preload("res://src/presentation/flash_guard.gd")


static func peak(color: Color) -> Color:
	return Color(color, FlashGuard.info(color.a))
