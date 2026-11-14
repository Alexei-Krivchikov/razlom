extends Area2D

const SPEED := 200.0
const DAMAGE := 8

var direction := Vector2.RIGHT


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 16
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if GameState.hitstop > 0:
		return
	position += direction * SPEED * delta
	if not Arena.RECT.grow(20).has_point(position):
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.take_damage(DAMAGE, global_position)
	Fx.burst(get_parent(), global_position, Palette.MAGENTA, 6, 80.0, 2.0)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(Palette.MAGENTA, 0.35))
	draw_circle(Vector2.ZERO, 3.5, Palette.MAGENTA)
	draw_circle(Vector2.ZERO, 1.5, Palette.SAND)
	draw_line(Vector2.ZERO, -direction * 10.0, Color(Palette.MAGENTA, 0.4), 2.0)
