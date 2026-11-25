extends RefCounted

const FLOOR_NORMAL_Y := 0.9


static func on_floor(state) -> bool:
	return state.grounded and state.contact_normal.y >= FLOOR_NORMAL_Y and state.get("carving") != true
