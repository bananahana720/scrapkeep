extends RefCounted

const FlashGuard := preload("res://src/presentation/flash_guard.gd")

# Every mark an active draws through combat.effects (blast rings, impact sparks, lance beams, the
# torch beam and its heat rings, rocket trails, chain arcs, the tells' cracks and edges) passes its
# colour through peak(), so Reduce flashes dims it like the other information flashes
# (FlashGuard.INFO_SHARE, the share threat grammar gives a telegraph's flash): the shape, colour
# and timing stay, so a tell keeps its read; only the brightness drops. combat.effects draws each
# mark at its colour's alpha. tests/active_flashes_test.gd fails on any effects call or chain
# colour in this folder that skips it.


static func peak(color: Color) -> Color:
	return Color(color, FlashGuard.info(color.a))
