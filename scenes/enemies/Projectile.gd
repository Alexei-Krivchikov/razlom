class_name Projectile
extends Area2D

signal impacted

var data: ProjectileData
var direction := Vector2.RIGHT


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 16
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if GameState.hitstop > 0:
		return
	position += direction * data.speed * delta
	if not Arena.RECT.grow(20).has_point(position):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.take_damage(data.damage, global_position)
	impacted.emit()
	queue_free()
