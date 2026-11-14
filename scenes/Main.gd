extends Node2D

enum Phase { TITLE, WAVE, INTERMISSION, UPGRADE, BOSS, OVER }

const SHARK := preload("res://scenes/enemies/Shark.tscn")
const SPITTER := preload("res://scenes/enemies/Spitter.tscn")
const BOSS := preload("res://scenes/enemies/Boss.tscn")
const PLAYER := preload("res://scenes/Player.tscn")

const SPAWN_GAP := 20
# A wave arrives in two pushes: the second waits until the first is nearly down (or this many
# frames pass), so pressure rises in a sawtooth instead of one flat brawl.
const REINFORCE_ALIVE := 1
const REINFORCE_TIMEOUT := 480
const INTERMISSION := 120
const END_DELAY := 75
const SHAKE_FRAMES := 8

var phase := Phase.TITLE
var player: Player
var world: Node2D

@onready var camera: Camera2D = $Camera
@onready var hud := $HUD
@onready var title_screen := $TitleScreen
@onready var upgrade_screen := $UpgradeScreen
@onready var game_over := $GameOver
@onready var victory := $Victory

var _spawn_queue: Array[PackedScene] = []
var _spawn_cooldown := 0
var _spawn_index := 0
var _hold_at := -1
var _hold_timer := 0
var _phase_timer := 0
var _shake_amp := 0.0
var _shake_left := 0


func _ready() -> void:
	world = $World
	player = PLAYER.instantiate()
	player.position = Arena.RECT.get_center()
	world.add_child(player)
	hud.player = player

	Events.shake_requested.connect(_on_shake)
	Events.player_died.connect(_on_player_died)
	Events.boss_died.connect(_on_boss_died)
	Events.summon_requested.connect(_on_summon)
	title_screen.start_requested.connect(_start_run)
	title_screen.boss_requested.connect(_start_boss_rush)
	upgrade_screen.chosen.connect(_on_upgrade_chosen)
	game_over.restart_requested.connect(_restart)
	victory.restart_requested.connect(_restart)

	if GameState.skip_title:
		title_screen.hide()
		if GameState.boss_rush:
			_start_boss_rush.call_deferred()
		else:
			_start_run.call_deferred()
	else:
		get_tree().paused = true


func _start_run() -> void:
	GameState.boss_rush = false
	get_tree().paused = false
	GameState.reset()
	Sfx.start_music()
	_start_wave(1)


# Practice mode: straight to the boss with five random upgrades, as if the waves were already won.
func _start_boss_rush() -> void:
	GameState.boss_rush = true
	get_tree().paused = false
	GameState.reset()
	Sfx.start_music()
	for i in GameState.WAVES.size():
		var picks := GameState.roll_upgrades(1)
		if not picks.is_empty():
			_apply_upgrade(picks[0])
	_start_boss()


func _restart() -> void:
	GameState.skip_title = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _start_wave(n: int) -> void:
	GameState.wave = n
	phase = Phase.WAVE
	var comp: Dictionary = GameState.WAVES[n - 1]
	_spawn_queue.clear()
	for i in comp.shark:
		_spawn_queue.append(SHARK)
	for i in comp.spitter:
		_spawn_queue.append(SPITTER)
	_spawn_queue.shuffle()
	_spawn_cooldown = 50
	_hold_at = _spawn_queue.size() / 2 if _spawn_queue.size() >= 6 else -1
	_hold_timer = 0
	var sub := _count(comp.shark, "шаркун", "шаркуна", "шаркунов")
	if comp.spitter > 0:
		sub += " + " + _count(comp.spitter, "плевун", "плевуна", "плевунов")
	hud.show_banner("ВОЛНА %d" % n, sub)


func _count(n: int, one: String, few: String, many: String) -> String:
	var word := many
	if n % 10 == 1 and n % 100 != 11:
		word = one
	elif n % 10 in [2, 3, 4] and not (n % 100 in [12, 13, 14]):
		word = few
	return "%d %s" % [n, word]


func _start_boss() -> void:
	GameState.wave = GameState.WAVES.size() + 1
	phase = Phase.BOSS
	hud.show_banner("ПАСТЫРЬ", "он ведёт их сквозь разлом")
	var rift := _open_rift(BOSS, Vector2(Arena.RECT.get_center().x, Arena.RECT.position.y + 50))
	rift.frames = 90


func _open_rift(scene: PackedScene, pos: Vector2) -> Rift:
	var rift := Rift.new()
	rift.scene = scene
	rift.position = pos
	world.add_child(rift)
	return rift


func _physics_process(_delta: float) -> void:
	if GameState.hitstop > 0:
		GameState.hitstop -= 1
	_update_shake()

	if phase in [Phase.WAVE, Phase.INTERMISSION, Phase.BOSS]:
		GameState.run_time += 1.0 / Engine.physics_ticks_per_second

	match phase:
		Phase.WAVE:
			if _spawn_queue.size() == _hold_at:
				_hold_timer += 1
				var alive := get_tree().get_nodes_in_group("enemies").size() + get_tree().get_nodes_in_group("rifts").size()
				if alive <= REINFORCE_ALIVE or _hold_timer >= REINFORCE_TIMEOUT:
					_hold_at = -1
					_spawn_cooldown = 30
					hud.show_banner("ПОДКРЕПЛЕНИЕ", "разлом снова открывается")
			elif not _spawn_queue.is_empty():
				_spawn_cooldown -= 1
				if _spawn_cooldown <= 0:
					var points := Arena.spawn_points()
					var p := points[_spawn_index % points.size()] + Vector2(randf_range(-8, 8), randf_range(-8, 8))
					_spawn_index += 1
					_open_rift(_spawn_queue.pop_front(), p)
					_spawn_cooldown = SPAWN_GAP
			elif _field_clear():
				phase = Phase.INTERMISSION
				_phase_timer = INTERMISSION
				Events.wave_cleared.emit(GameState.wave)
		Phase.INTERMISSION:
			_phase_timer -= 1
			if _phase_timer <= 0:
				phase = Phase.UPGRADE
				get_tree().paused = true
				upgrade_screen.open(GameState.roll_upgrades())
		Phase.BOSS:
			if hud.boss == null:
				hud.boss = _find_boss()



func _field_clear() -> bool:
	return get_tree().get_nodes_in_group("enemies").is_empty() \
		and get_tree().get_nodes_in_group("rifts").is_empty()


func _find_boss() -> Enemy:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_in_group("boss"):
			return e
	return null


func _apply_upgrade(id: String) -> void:
	GameState.upgrades[id] += 1
	if id == "breath":
		player.max_health += 25
		player.heal_full()


func _on_upgrade_chosen(id: String) -> void:
	_apply_upgrade(id)
	get_tree().paused = false
	if GameState.wave < GameState.WAVES.size():
		_start_wave(GameState.wave + 1)
	else:
		_start_boss()


func _on_summon(origin: Vector2, count: int) -> void:
	for i in count:
		var offset := Vector2.from_angle(TAU * i / count + randf()) * 46.0
		_open_rift(SHARK, Arena.clamp_inside(origin + offset, 24.0))


func _on_player_died() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	await get_tree().create_timer(END_DELAY / 60.0).timeout
	game_over.open()


func _on_boss_died() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	GameState.freeze(30)
	Events.shake_requested.emit(8.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_in_group("boss"):
			e.die.call_deferred()
	await get_tree().create_timer(END_DELAY / 60.0).timeout
	victory.open()


func _on_shake(amplitude: float) -> void:
	_shake_amp = maxf(_shake_amp if _shake_left > 0 else 0.0, amplitude)
	_shake_left = SHAKE_FRAMES


func _update_shake() -> void:
	if _shake_left <= 0:
		camera.offset = Vector2.ZERO
		return
	var k := float(_shake_left) / SHAKE_FRAMES
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * _shake_amp * k
	_shake_left -= 1
