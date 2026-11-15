class_name WaveSpawner
extends Node

signal reinforcing
signal cleared

const RIFT := preload("res://scenes/Rift.tscn")

@export var world: Node2D

var active := false
var _queue: Array[EnemyData] = []
var _cooldown := 0
var _spawn_index := 0
var _hold_at := -1
var _hold_timer := 0

@onready var run := GameState.run


func _ready() -> void:
	Events.summon_requested.connect(_on_summon)


func start(wave: WaveData) -> void:
	_queue.clear()
	for entry in wave.entries:
		for i in entry.count:
			_queue.append(entry.enemy)
	_queue.shuffle()
	_cooldown = run.first_spawn_delay
	_hold_at = _queue.size() / 2 if _queue.size() >= run.reinforce_min_size else -1
	_hold_timer = 0
	active = true


func open_rift(enemy: EnemyData, pos: Vector2, frames: int) -> Rift:
	var rift := RIFT.instantiate() as Rift
	rift.enemy = enemy
	rift.frames = frames
	rift.position = pos
	world.add_child(rift)
	return rift


func field_clear() -> bool:
	return get_tree().get_nodes_in_group("enemies").is_empty() \
		and get_tree().get_nodes_in_group("rifts").is_empty()


func _physics_process(_delta: float) -> void:
	if not active:
		return
	if _queue.size() == _hold_at:
		_hold_timer += 1
		var alive := get_tree().get_nodes_in_group("enemies").size() + get_tree().get_nodes_in_group("rifts").size()
		if alive <= run.reinforce_alive or _hold_timer >= run.reinforce_timeout:
			_hold_at = -1
			_cooldown = run.reinforce_delay
			reinforcing.emit()
	elif not _queue.is_empty():
		_cooldown -= 1
		if _cooldown <= 0:
			var points := Arena.spawn_points()
			var j := run.spawn_jitter
			var p := points[_spawn_index % points.size()] + Vector2(randf_range(-j, j), randf_range(-j, j))
			_spawn_index += 1
			open_rift(_queue.pop_front(), p, run.rift_frames)
			_cooldown = run.spawn_gap
	elif field_clear():
		active = false
		cleared.emit()


func _on_summon(origin: Vector2, enemy: EnemyData, count: int) -> void:
	for i in count:
		var offset := Vector2.from_angle(TAU * i / count + randf()) * run.summon_radius
		open_rift(enemy, Arena.clamp_inside(origin + offset, 24.0), run.rift_frames)
