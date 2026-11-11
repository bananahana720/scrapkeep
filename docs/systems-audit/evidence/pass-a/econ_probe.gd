extends "res://tools/bot_run.gd"

# Systems audit pass A probe (kept in docs/systems-audit/evidence/pass-a; run.sh copies it into tools/): wraps bot_run and writes a resource ledger per seed,
# econ-<seed>.ndjson in --out: every gain event, every tick-to-tick drop of cogs/scrap/hp, and a
# snapshot at each stage entry and at the end. It reads only; the run is bot_run's.

var _hooked: Object = null
var _ledger: FileAccess = null
var _last := {}


func _row(kind: String, extra := {}) -> void:
	if _ledger == null or _game == null:
		return
	var r: Dictionary = {"t": snappedf(_game.run.run_time, 0.01), "stage": _game.run.stage, "kind": kind,
		"cogs": _game.run.cogs, "scrap": _game.run.scrap, "mass": snappedf(_game.run.mass, 0.1),
		"hp": snappedf(_game.run.hp, 0.1), "cores": _game.run.bonus_cores, "parts": _game.run.parts.size(),
		"panels": _game.run.panels.size(), "tree": _game.run.tree_picks.size(), "relics": _game.run.relics.size()}
	r.merge(extra)
	_ledger.store_line(JSON.stringify(r))


func _physics_process(delta: float) -> bool:
	var over := super(delta)
	if _game != null and _game != _hooked and _game.events != null:
		_hooked = _game
		_last = {}
		_ledger = FileAccess.open(_out.path_join("econ-%d.ndjson" % _seeds[_index]), FileAccess.WRITE)
		var ev = _game.events
		ev.cogs_collected.connect(func(a, _t): _row("cogs+", {"amount": a}))
		ev.part_gained.connect(func(p, s): _row("part+", {"part": p, "source": s}))
		ev.core_gained.connect(func(s, _at, c): _row("core+", {"source": s, "count": c}))
		ev.panel_gained.connect(func(p, c, _at, j): _row("panel+", {"panel": p, "jackpot": j}))
		ev.scrap_lost.connect(func(a, _at, _t, c): _row("scrap-", {"amount": a, "cause": c}))
		ev.stage_entered.connect(func(i, retry): _row("stage", {"index": i, "retry": retry}))
	if _game != null and _game == _hooked and _game.run != null:
		var now := {"cogs": _game.run.cogs, "hp": _game.run.hp, "scrap": _game.run.scrap}
		if not _last.is_empty():
			if now["cogs"] < _last["cogs"]:
				_row("cogs-", {"amount": _last["cogs"] - now["cogs"]})
			if now["hp"] > _last["hp"] + 0.5:
				_row("heal", {"amount": snappedf(now["hp"] - _last["hp"], 0.1)})
		_last = now
	if over and _ledger != null:
		_row("end", {"outcome": _driver.outcome if _driver != null else ""})
		_ledger = null
	return over

