extends Node

# godot --headless --path . --fixed-fps 60 res://tests/BossTest.tscn
# The hero is moved between near and far spots and kept alive. The boss must use all three attacks,
# each must be able to hurt the hero, the roar must trigger at half health and the boss must die
# to sustained hits.

const PLAYER := preload("res://scenes/Player.tscn")
const BOSS := preload("res://scenes/enemies/Boss.tscn")
const MAX_FRAMES := 60 * 120

var _frame := 0
var _player: Player
var _boss: Enemy
var _damage := {}
var _roared := false
var _dead := false
var _attacks := PackedStringArray()


func _ready() -> void:
	GameState.reset()
	add_child(preload("res://scenes/Arena.tscn").instantiate())
	_player = PLAYER.instantiate()
	_player.position = Arena.RECT.get_center() + Vector2(0, 60)
	add_child(_player)
	_boss = BOSS.instantiate()
	_boss.position = Arena.RECT.get_center() + Vector2(0, -80)
	add_child(_boss)
	Events.player_damaged.connect(func(a): _damage[a] = true)
	Events.boss_died.connect(func(): _dead = true)


func _physics_process(_delta: float) -> void:
	if GameState.hitstop > 0:
		GameState.hitstop -= 1
	_frame += 1
	_player.health = _player.max_health
	if is_instance_valid(_boss):
		_roared = _roared or _boss.s == _boss.S.ROAR
		if _frame % 200 == 0:
			var near := (_frame / 200) % 2 == 0
			var offset := Vector2.from_angle(randf() * TAU) * (50.0 if near else 260.0)
			_player.position = Arena.clamp_inside(_boss.global_position + offset, 20.0)
		if _frame > 60 * 50 and _frame % 15 == 0:
			_boss.take_hit(20.0, Vector2.RIGHT, false)
	if is_instance_valid(_boss):
		_attacks = _boss.attack_log
	if _dead or _frame >= MAX_FRAMES:
		var used_all := _attacks.has("slam") and _attacks.has("charge") and _attacks.has("volley")
		var hurt_by_all := _damage.has(15) and _damage.has(20) and _damage.has(8)
		var ok := _dead and _roared and used_all and hurt_by_all
		print("%s | dead=%s roared=%s damage=%s frame=%d | %s" % [
			"PASS" if ok else "FAIL", _dead, _roared, _damage.keys(), _frame, " ".join(_attacks)])
		get_tree().quit(0 if ok else 1)
		set_physics_process(false)
