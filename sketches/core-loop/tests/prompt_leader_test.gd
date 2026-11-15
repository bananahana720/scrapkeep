extends SceneTree

# PF-22 (w37 player's-eye film, pictures 042-046, 074-079): the reward gates' names sat in the
# prompts band far below the gates, and no reader could tell which gate gives which part. A gate's
# prompt is now a sign: it hangs from its own gate's crossbar in the sign room, a type step larger,
# and when it has to stand aside it draws a leader up to its gate. This checks where a sign wants
# to hang and the leader's geometry; the real gates are checked in int_screen_layout_test.

const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("prompt_leader_test")


func _initialize() -> void:
	var p := WorldPrompt.new()
	p.set_parts("Impact Driver", "+6 punch")
	p.position = Vector2(400.0, 460.0)
	p.aim = Vector2(520.0, 300.0)
	_t.eq("planted: a prompt that is not a gate's offer draws no leader", p.leader_end(), Vector2.INF)
	p.on_anchor = true
	_t.eq("a gate's name leads up to where its gate projects", p.position + p.leader_end(), p.aim)
	p.aim = Vector2(460.0, 520.0)
	_t.eq("no leader to an anchor below the name", p.leader_end(), Vector2.INF)
	p.aim = p.position + Vector2(p.shown_extent().x * 0.5, -10.0)
	_t.eq("no leader shorter than LEADER_MIN", p.leader_end(), Vector2.INF)
	p.aim = Vector2.INF
	_t.eq("no leader before the HUD has placed it", p.leader_end(), Vector2.INF)
	# The gate's sign above the play view: the line stops at the view's top edge, with no dot.
	var room := Rect2(0.0, 261.0, 1600.0, 297.0)
	p.aim_at(Vector2(520.0, 40.0), room)
	_t.check("planted: a sign above the view cuts the line at the view's top edge", p.aim_cut and is_equal_approx((p.position + p.leader_end()).y, room.position.y),
		"%s cut %s" % [p.position + p.leader_end(), p.aim_cut])
	p.aim_at(Vector2(520.0, 300.0), room)
	_t.check("a sign inside the view keeps the whole line and its dot", not p.aim_cut and p.position + p.leader_end() == Vector2(520.0, 300.0))
	# Where a sign hangs: on its anchor's column, its top just under the anchor, inside the sign room.
	var size := Vector2(1600.0, 900.0)
	var signs := ScreenRegions.sign_room(size)
	var hung := ScreenRegions.clamp_sign(Vector2(800.0, 400.0), Vector2(200.0, 60.0), size)
	_t.check("a sign hangs centred under its anchor", hung == Vector2(700.0, 400.0 + ScreenRegions.SIGN_DROP), "%s" % hung)
	var high := ScreenRegions.clamp_sign(Vector2(800.0, 20.0), Vector2(200.0, 60.0), size)
	_t.check("an anchor above the view keeps the sign under the toasts band", is_equal_approx(high.y, signs.position.y)
		and signs.position.y >= ScreenRegions.rect("toasts", size).end.y, "%s room %s" % [high, signs])
	var low := ScreenRegions.clamp_sign(Vector2(800.0, 880.0), Vector2(200.0, 60.0), size)
	_t.check("an anchor in the bottom band keeps the sign above it", low.y + 60.0 <= ScreenRegions.rect("bottom", size).position.y, "%s" % low)
	var Hud := load("res://src/ui/hud.gd")
	var sign_prompt := WorldPrompt.new()
	sign_prompt.set_parts("Impact Driver", "+6 punch")
	var band_size := sign_prompt.shown_extent()
	sign_prompt.on_anchor = true
	_t.check("a sign reads a type step larger than a band prompt", sign_prompt.shown_extent().x > band_size.x and sign_prompt.title_size() > WorldPrompt.TITLE_SIZE)
	# A sign short of the minimum leader length draws none: the column inside it says whose it is.
	sign_prompt.position = Vector2(700.0, 406.0)
	sign_prompt.aim_at(Vector2(800.0, 400.0), signs)
	_t.eq("a leader shorter than the minimum is not drawn", sign_prompt.leader_end(), Vector2.INF)
	# Planted: a sign standing at the room's very top, its gate above the view, draws nothing up into the
	# toast and objective bands (CONTRACTS.md, UI regions): the cut leaves a line of no length.
	sign_prompt.position = Vector2(700.0, signs.position.y)
	sign_prompt.aim_at(Vector2(800.0, 40.0), signs)
	_t.check("a sign at the room's top draws no leader", sign_prompt.leader_end() == Vector2.INF and sign_prompt.aim_cut, "%s cut %s" % [sign_prompt.leader_end(), sign_prompt.aim_cut])
	# A sign pushed below the reticle's ring, its gate above the ring: the leader ends at the ring's
	# edge rather than running through it.
	var ring := Rect2(Vector2(740.0, 380.0), Vector2(120.0, 120.0))
	sign_prompt.position = Vector2(620.0, 520.0)
	sign_prompt.size = sign_prompt.shown_extent()
	Hud.aim_sign(sign_prompt, Vector2(800.0, 300.0), size, ring)
	var tip: Vector2 = sign_prompt.position + sign_prompt.leader_end()
	_t.check("a leader that would cross the ring ends at its edge", sign_prompt.aim_cut and ring.grow(1.0).has_point(tip) and not ring.grow(-1.0).has_point(tip), "%s" % tip)
	var open_ring := Rect2(Vector2(100.0, 380.0), Vector2(120.0, 120.0))
	Hud.aim_sign(sign_prompt, Vector2(800.0, 300.0), size, open_ring)
	_t.check("a ring off the line leaves the leader whole", not sign_prompt.aim_cut and sign_prompt.position + sign_prompt.leader_end() == Vector2(800.0, 300.0))
	# A sign pushed past the ball's square and the reticle's ring is placed beside them, not dropped.
	var ball_square := Rect2(Vector2(740.0, 420.0), Vector2(120.0, 120.0))
	var pushed: Rect2 = Hud.prompt_spot(sign_prompt, Vector2(800.0, 400.0), size, [ball_square] as Array[Rect2])
	_t.check("a sign over the ball is moved clear and kept", pushed.size != Vector2.ZERO and not pushed.intersects(ball_square)
		and signs.grow(0.5).encloses(pushed), "%s" % pushed)
	# Another prompt's place does not move: the band prompt ignores what only a sign keeps off, and its
	# spot is the one the band gave before signs (clamp_prompt, then free_spot in the band).
	var band_prompt := WorldPrompt.new()
	band_prompt.set_parts("Fabricating...", "3 cogs")
	var band := ScreenRegions.rect("prompts", size)
	var at := Vector2(800.0, 1000.0)
	var old_way: Rect2 = Hud.free_spot(Rect2(ScreenRegions.clamp_prompt(at, band_prompt.shown_extent(), size), band_prompt.shown_extent()), [] as Array[Rect2], band)
	var now: Rect2 = Hud.prompt_spot(band_prompt, at, size, [] as Array[Rect2])
	_t.check("a band prompt lands where it did before signs", old_way.size != Vector2.ZERO and now == old_way, "%s vs %s" % [now, old_way])
	var sample_extent := band_prompt.shown_extent()
	_t.check("a band prompt keeps its type size", not band_prompt.on_anchor and band_prompt.title_size() == WorldPrompt.TITLE_SIZE and band_prompt.detail_size() == WorldPrompt.DETAIL_SIZE and sample_extent.x > 0.0)
	band_prompt.free()
	sign_prompt.free()
	p.free()
	quit(_t.verdict())
