class_name Rift
extends Node2D

signal opened

var enemy: EnemyData
var frames := 30
var left := 30


func _ready() -> void:
	add_to_group("rifts")
	left = frames


func _physics_process(_delta: float) -> void:
	left -= 1
	if left <= 0:
		var e := enemy.spawn()
		e.position = position
		get_parent().add_child(e)
		opened.emit()
		queue_free()


func progress() -> float:
	return 1.0 - float(left) / frames
