extends Node

const WAVES := [
	{"shark": 4, "spitter": 0},
	{"shark": 6, "spitter": 0},
	{"shark": 4, "spitter": 2},
	{"shark": 8, "spitter": 2},
	{"shark": 6, "spitter": 4},
]
const MAX_STACK := 3
const UPGRADES := {
	"steel": {"title": "БОЛЬШЕ СТАЛИ", "desc": "Урон всех ударов\n+25%"},
	"breath": {"title": "ВТОРОЕ ДЫХАНИЕ", "desc": "Макс. здоровье +25\nи полное лечение"},
	"phase": {"title": "ФАЗОВЫЙ ШАГ", "desc": "Кулдаун рывка −30%\nнеуязвимость +2 кадра"},
	"shockwave": {"title": "УДАРНАЯ ВОЛНА", "desc": "Третий удар серии\nбьёт по кругу"},
}

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
	for id in UPGRADES:
		upgrades[id] = 0
	hitstop = 0
	run_time = 0.0


func level(id: String) -> int:
	return upgrades.get(id, 0)


func damage_mult() -> float:
	return 1.0 + 0.25 * level("steel")


func roll_upgrades(count := 3) -> Array:
	var pool := UPGRADES.keys().filter(func(id): return level(id) < MAX_STACK)
	pool.shuffle()
	return pool.slice(0, count)


func freeze(frames: int) -> void:
	hitstop = maxi(hitstop, frames)
