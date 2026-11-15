extends Node

var run: RunData = load("res://data/run.tres")

var wave := 0
var upgrades := {}
var hitstop := 0
var run_time := 0.0
# Both survive reload_current_scene, so a restart skips the title and repeats the same mode.
var skip_title := false
var boss_rush := false


func _ready() -> void:
	reset()


func reset() -> void:
	wave = 0
	upgrades = {}
	for u in run.upgrades:
		upgrades[u.id] = 0
	hitstop = 0
	run_time = 0.0


func level(u: UpgradeData) -> int:
	return upgrades.get(u.id, 0)


func add_level(u: UpgradeData) -> void:
	upgrades[u.id] = level(u) + 1


func roll_upgrades(count: int) -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = []
	pool.assign(run.upgrades.filter(func(u: UpgradeData): return level(u) < u.max_level))
	pool.shuffle()
	return pool.slice(0, count)


func damage_mult() -> float:
	var m := 1.0
	for u in run.upgrades:
		m += u.damage_bonus * level(u)
	return m


func dash_cooldown_mult() -> float:
	var m := 1.0
	for u in run.upgrades:
		m *= pow(u.dash_cooldown_factor, level(u))
	return m


func dash_invuln_bonus() -> int:
	var b := 0
	for u in run.upgrades:
		b += u.dash_invuln_bonus * level(u)
	return b


func shockwave_level() -> int:
	var n := 0
	for u in run.upgrades:
		if u.shockwave:
			n += level(u)
	return n


func shockwave_radius_mult() -> float:
	var m := 1.0
	for u in run.upgrades:
		if u.shockwave and level(u) > 1:
			m += u.shockwave_radius_bonus * (level(u) - 1)
	return m


func freeze(frames: int) -> void:
	hitstop = maxi(hitstop, frames)
