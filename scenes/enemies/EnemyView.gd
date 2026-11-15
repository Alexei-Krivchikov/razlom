class_name EnemyView
extends Node2D

var flash := 0

@onready var enemy: Enemy = get_parent()


func _ready() -> void:
	enemy.hit.connect(func(_strong): flash = 2)
	enemy.died.connect(_on_died)


func _on_died() -> void:
	var world := enemy.get_parent()
	Fx.burst(world, enemy.global_position, Palette.MAGENTA, 18, 160.0, 3.0)
	Fx.burst(world, enemy.global_position, Palette.RIFT, 10, 240.0, 5.0)
	Sfx.play("death")


func _physics_process(_delta: float) -> void:
	if GameState.hitstop == 0:
		flash = maxi(flash - 1, 0)


func _process(_delta: float) -> void:
	queue_redraw()


func body_color(base: Color) -> Color:
	return Palette.SAND if flash > 0 else base
