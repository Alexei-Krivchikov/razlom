extends Node2D

@onready var projectile: Projectile = get_parent()


func _ready() -> void:
	projectile.impacted.connect(_on_impacted)


func _on_impacted() -> void:
	Fx.burst(projectile.get_parent(), projectile.global_position, Palette.MAGENTA, 6, 80.0, 2.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(Palette.MAGENTA, 0.35))
	draw_circle(Vector2.ZERO, 3.5, Palette.MAGENTA)
	draw_circle(Vector2.ZERO, 1.5, Palette.SAND)
	draw_line(Vector2.ZERO, -projectile.direction * 10.0, Color(Palette.MAGENTA, 0.4), 2.0)
