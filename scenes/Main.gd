extends Node2D

enum Phase { TITLE, WAVE, INTERMISSION, UPGRADE, BOSS, OVER }

const PLAYER := preload("res://scenes/hero/Player.tscn")

var phase := Phase.TITLE
var player: Player

var _phase_timer := 0

@onready var run := GameState.run
@onready var world: Node2D = $World
@onready var spawner: WaveSpawner = $WaveSpawner
@onready var hud := $HUD
@onready var title_screen := $TitleScreen
@onready var upgrade_screen := $UpgradeScreen
@onready var game_over := $GameOver
@onready var victory := $Victory


func _ready() -> void:
	player = PLAYER.instantiate()
	player.position = Arena.RECT.get_center()
	world.add_child(player)
	hud.player = player

	Events.player_died.connect(_on_player_died)
	Events.boss_died.connect(_on_boss_died)
	spawner.reinforcing.connect(func(): hud.show_banner("ПОДКРЕПЛЕНИЕ", "разлом снова открывается"))
	spawner.cleared.connect(_on_wave_cleared)
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


# Practice mode: straight to the boss with one random upgrade per wave, as if the waves were already won.
func _start_boss_rush() -> void:
	GameState.boss_rush = true
	get_tree().paused = false
	GameState.reset()
	Sfx.start_music()
	for i in run.waves.size():
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
	var wave := run.waves[n - 1]
	spawner.start(wave)
	var parts := PackedStringArray()
	for entry in wave.entries:
		if entry.count > 0:
			parts.append(entry.enemy.count_text(entry.count))
	hud.show_banner("ВОЛНА %d" % n, " + ".join(parts))


func _start_boss() -> void:
	GameState.wave = run.waves.size() + 1
	phase = Phase.BOSS
	hud.show_banner(run.boss.banner_title, run.boss.banner_sub)
	spawner.open_rift(run.boss, Vector2(Arena.RECT.get_center().x, Arena.RECT.position.y + 50), run.boss_rift_frames)


func _physics_process(_delta: float) -> void:
	if GameState.hitstop > 0:
		GameState.hitstop -= 1

	if phase in [Phase.WAVE, Phase.INTERMISSION, Phase.BOSS]:
		GameState.run_time += 1.0 / Engine.physics_ticks_per_second

	match phase:
		Phase.INTERMISSION:
			_phase_timer -= 1
			if _phase_timer <= 0:
				phase = Phase.UPGRADE
				get_tree().paused = true
				upgrade_screen.open(GameState.roll_upgrades(run.upgrade_choices))
		Phase.BOSS:
			if hud.boss == null:
				hud.boss = get_tree().get_first_node_in_group("boss")


func _on_wave_cleared() -> void:
	phase = Phase.INTERMISSION
	_phase_timer = run.intermission
	Events.wave_cleared.emit(GameState.wave)


func _apply_upgrade(u: UpgradeData) -> void:
	GameState.add_level(u)
	if u.max_health_bonus > 0 or u.heal_on_pick:
		player.add_max_health(u.max_health_bonus, u.heal_on_pick)


func _on_upgrade_chosen(u: UpgradeData) -> void:
	_apply_upgrade(u)
	get_tree().paused = false
	if GameState.wave < run.waves.size():
		_start_wave(GameState.wave + 1)
	else:
		_start_boss()


func _on_player_died() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	await get_tree().create_timer(run.end_delay / 60.0).timeout
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
	await get_tree().create_timer(run.end_delay / 60.0).timeout
	victory.open()
