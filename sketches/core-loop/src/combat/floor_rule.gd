extends RefCounted

# The Dig's floor rule (design-v3/WORLD-ROSTERS.md, Andrew's "Commit" tap, 2026-10-17): the
# Dig's floor threats reach only a ball that is on the floor. A ball on a bank, a half-pipe
# wall, a ramp or in the air is off the floor and safe from them, so carving is the Dig's
# safe lane. When grip and carve lands, a ball gripping a wall is off the floor by the same test.

# Flatter than about 25 degrees.
const FLOOR_NORMAL_Y := 0.9


static func on_floor(state) -> bool:
	return state.grounded and state.contact_normal.y >= FLOOR_NORMAL_Y
