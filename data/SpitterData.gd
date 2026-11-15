class_name SpitterData
extends EnemyData

@export var projectile: ProjectileData
@export var keep_dist := 250.0
# Between retreat_dist and keep_dist the spitter stands still, so it can be cornered and caught.
@export var retreat_dist := 150.0
@export var retreat_speed := 55.0
@export var accel := 240.0
@export var fire_interval := 150
@export var first_shot_min := 60
@export var windup := 20
@export var rest_after_shot := 40
@export var hit_stun := 20
