extends Node

# godot --headless --path . --fixed-fps 60 res://tests/ComboTest.tscn -- <start distance px>
# Starting out of reach, a mashed combo must reach the shark first and kill it without being hit, but
# one three-hit combo alone must not be enough. Starting inside its reach, the shark is already
# swinging and light hits can't cancel that, so mashing without a dash must get the hero hit.

const PLAYER := preload("res://scenes/hero/Player.tscn")
const SHARK := preload("res://data/enemies/shark.tres")
const MAX_FRAMES := 150

var _frame := 0
var _player: Player
var _input := ScriptedInput.new()
var _shark: Enemy
var _hits := PackedStringArray()
var _hurt := false
var _distance := 40.0
var _hp_steps := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var distance := float(args[0]) if not args.is_empty() else 40.0
	_distance = distance
	GameState.reset()
	add_child(preload("res://scenes/Arena.tscn").instantiate())
	_player = PLAYER.instantiate()
	_player.position = Vector2(200, 190)
	_player.input = _input
	add_child(_player)
	_shark = SHARK.spawn()
	_shark.position = _player.position + Vector2(distance, 0)
	add_child(_shark)
	Events.player_damaged.connect(func(_a): _hurt = true)
	_shark.hit.connect(_on_shark_hit)


func _on_shark_hit(_strong: bool) -> void:
	_hp_steps[_shark.health] = true
	_hits.append("f%d hp%.0f d%.0f" % [_frame, _shark.health, _shark.position.distance_to(_player.position)])


func _physics_process(_delta: float) -> void:
	if GameState.hitstop > 0:
		GameState.hitstop -= 1
	_frame += 1
	_player.facing = Vector2.RIGHT
	_input.attack = _frame % 6 == 0
	var dead := not is_instance_valid(_shark) or _shark.health <= 0.0
	if dead or _frame >= MAX_FRAMES:
		var expect_hurt := _distance <= 40.0
		var ok := dead and _hurt == expect_hurt and _hp_steps.size() >= 3
		print("%s | killed=%s hurt=%s frame=%d | %s" % ["PASS" if ok else "FAIL", dead, _hurt, _frame, ", ".join(_hits)])
		get_tree().quit(0 if ok else 1)
		set_physics_process(false)
