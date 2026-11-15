class_name EnemyData
extends Resource

@export var scene: PackedScene
@export var max_health := 30.0
@export var speed := 100.0
@export var radius := 9.0
@export var knockback_scale := 1.0
@export var knockback_light := 120.0
@export var knockback_strong := 260.0
@export var knockback_frames := 10

@export_group("Names")
@export var name_one := ""
@export var name_few := ""
@export var name_many := ""


func spawn() -> Enemy:
	var e := scene.instantiate() as Enemy
	e.data = self
	return e


func count_text(n: int) -> String:
	var word := name_many
	if n % 10 == 1 and n % 100 != 11:
		word = name_one
	elif n % 10 in [2, 3, 4] and not (n % 100 in [12, 13, 14]):
		word = name_few
	return "%d %s" % [n, word]
