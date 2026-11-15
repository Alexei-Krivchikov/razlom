class_name Enemy
extends CharacterBody2D

signal hit(strong: bool)
signal died

var data: EnemyData
var health := 30.0

var _knockback := Vector2.ZERO
var _knockback_left := 0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 2 | 16
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.radius
	shape.shape = circle
	add_child(shape)
	health = data.max_health


func player() -> Player:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.state == Player.State.DEAD:
		return null
	return p


func take_hit(damage: float, dir: Vector2, strong: bool) -> bool:
	if health <= 0.0:
		return false
	health -= damage * damage_taken_mult()
	_knockback = dir * (data.knockback_strong if strong else data.knockback_light) * data.knockback_scale
	_knockback_left = data.knockback_frames
	_on_hit(strong)
	hit.emit(strong)
	if health <= 0.0:
		die()
		return true
	return false


func die() -> void:
	remove_from_group("enemies")
	died.emit()
	Events.enemy_died.emit(self)
	queue_free()


func damage_taken_mult() -> float:
	return 1.0


func _on_hit(_strong: bool) -> void:
	pass


func frozen() -> bool:
	return GameState.hitstop > 0


func knockback_velocity() -> Vector2:
	if _knockback_left <= 0:
		return Vector2.ZERO
	var v := _knockback * (float(_knockback_left) / data.knockback_frames)
	_knockback_left -= 1
	return v
