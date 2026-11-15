class_name ProjectileData
extends Resource

@export var scene: PackedScene
@export var speed := 200.0
@export var damage := 8
@export var radius := 4.0


func spawn(pos: Vector2, dir: Vector2) -> Projectile:
	var p := scene.instantiate() as Projectile
	p.data = self
	p.position = pos
	p.direction = dir
	return p
