extends RefCounted

const FlashGuard := preload("res://src/presentation/flash_guard.gd")

# Every active's flash and bloom peaks (a blast ring, an impact spark, a lance beam, the torch's
# heat ring) pass their colour through peak() before combat.effects draws them, so Reduce
# flashes dims them like the other information flashes (FlashGuard.INFO_SHARE): the shape,
# colour and timing stay, only the brightness drops. Lines that trace a path or a warning
# (rocket trails, crack rings, the torch beam) are not peaks and stay as drawn.
# tests/active_flashes_test.gd fails on any effects.ring, spark or beam call in this folder that
# skips it.


static func peak(color: Color) -> Color:
	return Color(color, FlashGuard.info(color.a))
