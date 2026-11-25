extends RefCounted


const MIN_GAP := 0.2
const LAST_META := "attack_budget_last"
const VOLLEY_META := "attack_budget_volley"


static func gap_frames() -> int:
	return ceili(MIN_GAP * Engine.physics_ticks_per_second / Engine.time_scale - 0.0001)


static func open(tree: SceneTree) -> bool:
	if tree == null or not tree.root.has_meta(LAST_META):
		return true
	return Engine.get_physics_frames() - int(tree.root.get_meta(LAST_META)) >= gap_frames()


static func stamp(tree: SceneTree, source: Object) -> void:
	if tree == null:
		return
	tree.root.set_meta(LAST_META, Engine.get_physics_frames())
	tree.root.set_meta(VOLLEY_META, [-1, source.get_instance_id()])
