class_name Spitter
extends Enemy

var windup := 0
var aim := Vector2.RIGHT
var _fire_timer := 0
var _rest := 0
var _move := Vector2.ZERO

@onready var d := data as SpitterData


func _ready() -> void:
	super()
	_fire_timer = randi_range(d.first_shot_min, d.fire_interval)


func _physics_process(_delta: float) -> void:
	if frozen():
		return
	var p := player()
	var v := Vector2.ZERO
	if p:
		var to := p.global_position - global_position
		aim = to.normalized()
		if windup > 0:
			windup -= 1
			if windup == 0:
				_shoot()
				_rest = d.rest_after_shot
		elif _rest > 0:
			_rest -= 1
		else:
			var dist := to.length()
			if dist < d.retreat_dist:
				v = -aim * d.retreat_speed
			elif dist > d.keep_dist:
				v = aim * d.speed
			_fire_timer -= 1
			if _fire_timer <= 0:
				windup = d.windup
				_fire_timer = d.fire_interval
	_move = _move.move_toward(v, d.accel / Engine.physics_ticks_per_second)
	velocity = _move + knockback_velocity()
	move_and_slide()


func _on_hit(_strong: bool) -> void:
	_move = Vector2.ZERO
	_rest = maxi(_rest, d.hit_stun)


func _shoot() -> void:
	get_parent().add_child(d.projectile.spawn(global_position + aim * (d.radius + 4), aim))
