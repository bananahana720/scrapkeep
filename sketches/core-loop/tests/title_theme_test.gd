extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")

# The title opening names its theme (title_intros.gd "A" or "B") and the title plays that
# theme's take from its next bar (audio.gd title_theme). A theme with no pack keeps the title.

class FakeCtx:
	extends RefCounted
	var events: Node

class Rig:
	extends Audio
	var named: Array = []
	func ace_wanted() -> bool:
		return true
	func _ace_named(id: String, at: int, _boss := false, _won := true) -> void:
		_on_title = false
		named.append([id, at])

var _t := T.new("title_theme_test")
var _nodes: Array = []


func _initialize() -> void:
	var on_disk := {"title-a": true, "title-b": true}
	var a := _rig(func(row): return on_disk.has(row))
	_t.eq("the plain title before any opening", a.title_row, "title")
	a.title_theme("A")
	_t.eq("an A opening picks title A", a.title_row, "title-a")
	_t.eq("off the title nothing restarts", a.named.size(), 0)
	a._on_title = true
	a.title_theme("B")
	_t.eq("a B opening picks title B", a.title_row, "title-b")
	_t.eq("on the title it restarts once", a.named.size(), 1)
	_t.eq("it restarts on title B", String(a.named[-1][0]) if not a.named.is_empty() else "", "title-b")
	_t.eq("on the next bar", int(a.named[-1][1]) if not a.named.is_empty() else -1, a.engine.next_bar())
	_t.check("still on the title after the restart", a._on_title)
	a.title_theme("B")
	_t.eq("the same theme again restarts nothing", a.named.size(), 1)
	a.title_theme("C")
	_t.eq("a theme with no pack keeps the plain title", a.title_row, "title")
	a.title_theme("Q")
	_t.eq("an unknown theme keeps the plain title", a.title_row, "title")
	var none := _rig(func(_row): return false)
	none.title_theme("A")
	_t.eq("no title packs on disk: the plain title", none.title_row, "title")
	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	quit(_t.verdict())


func _rig(avail: Callable) -> Rig:
	var events := GameEvents.new()
	var ctx := FakeCtx.new()
	ctx.events = events
	var audio := Rig.new()
	audio.setup(ctx)
	audio.bake_now()
	audio.title_available = avail
	_nodes.append_array([events, audio])
	return audio
