extends RefCounted

const MET_PREFIX := "met."


static func met_kinds(saved, kinds: Array) -> Array:
	var out: Array = []
	if saved == null:
		return out
	for kind in kinds:
		if saved.stat(MET_PREFIX + kind) > 0.0:
			out.append(kind)
	return out


static func met_of(game, kinds: Array) -> Array:
	return met_kinds(game.ctx.profile, kinds) if game != null and game.ctx != null else []


static func mark_met(saved, kind: String) -> bool:
	if saved == null or kind == "" or saved.stat(MET_PREFIX + kind) > 0.0:
		return false
	saved.set_stat(MET_PREFIX + kind, 1.0)
	saved.save_if_allowed()
	return true


static func watch(game) -> void:
	if game == null or game.events == null or game.has_meta("met_watch"):
		return
	game.set_meta("met_watch", true)
	game.events.enemy_spawned.connect(func(enemy: Node3D, kind: String):
		if not enemy.has_meta("sandbox_slot"):
			mark_met(game.ctx.profile, kind))
