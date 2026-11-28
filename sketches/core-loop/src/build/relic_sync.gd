extends RefCounted

const Relics := preload("res://src/build/relics.gd")
const AbilityState := preload("res://src/core/ability_state.gd")

var fx := {}


func reset() -> void:
	fx.clear()


func sync(build) -> void:
	var abilities = build.ctx.player.get("abilities") if build.ctx.player != null else null
	if abilities == null:
		return
	_adopt_saved(build)
	var held := Relics.held(build.ctx.run.parts)
	var touched := false
	for slot in AbilityState.SLOTS:
		var want: String = held.get(slot, "")
		if not Relics.has(want):
			want = ""
		var row_fx: Dictionary = fx.get(slot, {})
		if String(row_fx.get("relic", "")) == want:
			continue
		if not row_fx.is_empty():
			_undo(build, abilities, slot, row_fx)
			fx.erase(slot)
		if want != "":
			fx[slot] = _apply(abilities, slot, want)
		touched = true
	if touched and build.ctx.player.has_method("refit"):
		build.ctx.player.refit()


func _adopt_saved(build) -> void:
	if build.ctx.run.relics.is_empty():
		return
	for slot in build.ctx.run.relics:
		var part_id := Relics.part_of(String(build.ctx.run.relics[slot]))
		if part_id != "" and not part_id in build.ctx.run.parts:
			build.ctx.run.parts.append(part_id)
	build.ctx.run.relics.clear()
	build.recompute()


func _apply(abilities, slot: String, relic_id: String) -> Dictionary:
	var row := Relics.row(relic_id)
	var applied := {"relic": relic_id, "prev": abilities.id_of(slot), "swapped": false,
		"cooldown": float(row.get("cooldown", 1.0)), "charges": int(row.get("charges", 0))}
	if Relics.swap_of(relic_id) != "":
		abilities.swap(slot, Relics.swap_of(relic_id))
		applied["swapped"] = true
	var s = abilities.slot(slot)
	abilities.set_cooldown_scale(slot, s.cooldown_scale * applied["cooldown"])
	if applied["charges"] > 0:
		abilities.set_max_charges(slot, s.max_charges + applied["charges"])
		abilities.grant(slot, applied["charges"])
	return applied


func _undo(build, abilities, slot: String, row_fx: Dictionary) -> void:
	var s = abilities.slot(slot)
	if row_fx["charges"] > 0:
		abilities.set_max_charges(slot, s.max_charges - row_fx["charges"])
	abilities.set_cooldown_scale(slot, s.cooldown_scale / row_fx["cooldown"])
	var tree = build.ctx.player.tree if build.ctx.player != null else null
	var tree_owns: bool = tree != null and tree.gives_swap(slot, Relics.swap_of(row_fx["relic"]))
	if row_fx["swapped"] and abilities.id_of(slot) == Relics.swap_of(row_fx["relic"]) and not tree_owns:
		abilities.swap(slot, row_fx["prev"])
