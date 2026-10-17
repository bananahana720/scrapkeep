extends SceneTree
# src/presentation/special_rig.gd: a special's body plays the clip its special_tell moment
# names from age 0 on the frame the signal fires (the frame its sound and machine_fx burst
# start), goes back to its loop after a tell, and holds a break's last pose.

const T := preload("res://tests/support/t.gd")
const SpecialRig := preload("res://src/presentation/special_rig.gd")
const MODELS := {
	"foreman": "res://assets/models/world_one/enemy_foreman.glb",
	"dispatcher": "res://assets/models/world_one/enemy_dispatcher.glb",
	"splitter": "res://assets/models/world_one/enemy_splitter.glb",
	"linker": "res://assets/models/world_one/enemy_linker.glb",
	"splitter_piece": "res://assets/models/world_one/enemy_splitter_piece.glb",
}

var t := T.new("special_rig_test")


func _initialize() -> void:
	_run.call_deferred()


func _body(kind: String) -> Array:
	var enemy := Node3D.new()
	enemy.add_user_signal("special_tell", [{"name": "moment", "type": TYPE_STRING}])
	root.add_child(enemy)
	var model := (load(MODELS[kind]) as PackedScene).instantiate()
	enemy.add_child(model)
	return [enemy, SpecialRig.attach(enemy, model, kind)]


func _run() -> void:
	for kind in MODELS:
		var made := _body(kind)
		var enemy: Node3D = made[0]
		var rig = made[1]
		t.check(kind + " seats a driver", rig != null)
		if rig == null:
			continue
		var row: Dictionary = SpecialRig.CLIPS[kind]
		var player: AnimationPlayer = rig.player
		t.eq(kind + " starts on its loop", String(player.current_animation), row["loop"])
		var first := "spawn" if row.has("spawn") else "tell"
		enemy.emit_signal("special_tell", first)
		t.eq(kind + " " + first + " plays its clip", String(player.current_animation), row[first])
		t.near(kind + " " + first + " starts at age 0 on the signal's frame", player.current_animation_position, 0.0, 0.0001)
		# Run the clip out: a tell or spawn hands back to the loop (the Linker to its brace hold).
		player.advance(player.get_animation(row[first]).length + 0.05)
		t.eq(kind + " returns after " + first, String(player.current_animation), row.get("after_tell", row["loop"]) if first == "tell" else row["loop"])
		enemy.emit_signal("special_tell", "not_a_moment")
		t.check(kind + " ignores unknown moments", String(player.current_animation) != "not_a_moment")
		for death in ["break", "break_clean"]:
			if not row.has(death):
				continue
			enemy.emit_signal("special_tell", death)
			t.eq(kind + " " + death + " plays", String(player.current_animation), row[death])
			player.advance(player.get_animation(row[death]).length + 0.5)
			enemy.emit_signal("special_tell", "tell")
			t.check(kind + " holds the " + death + " pose", not player.is_playing() or String(player.current_animation) == row[death],
				String(player.current_animation))
			break
		enemy.queue_free()
	quit(t.verdict())
