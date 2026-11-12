extends SceneTree

# PF-22 (w37 player's-eye film, pictures 042-046, 074-079): the reward gates' names sit in the
# prompts band far below the gates, and no reader could tell which gate gives which part. A gate's
# prompt now draws a leader from its name up to its gate. This checks the leader's geometry; the
# real gates are checked in int_screen_layout_test.

const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("prompt_leader_test")


func _initialize() -> void:
	var p := WorldPrompt.new()
	p.set_parts("Impact Driver", "+6 punch")
	p.position = Vector2(400.0, 460.0)
	p.aim = Vector2(520.0, 300.0)
	_t.eq("planted: a prompt that is not a gate's offer draws no leader", p.leader_end(), Vector2.INF)
	p.leader = true
	_t.eq("a gate's name leads up to where its gate projects", p.position + p.leader_end(), p.aim)
	p.aim = Vector2(460.0, 520.0)
	_t.eq("no leader to an anchor below the name", p.leader_end(), Vector2.INF)
	p.aim = p.position + Vector2(p.shown_extent().x * 0.5, -10.0)
	_t.eq("no leader shorter than LEADER_MIN", p.leader_end(), Vector2.INF)
	p.aim = Vector2.INF
	_t.eq("no leader before the HUD has placed it", p.leader_end(), Vector2.INF)
	p.free()
	quit(_t.verdict())
