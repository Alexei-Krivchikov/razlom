class_name Shark
extends Enemy

enum S { CHASE, WINDUP, ACTIVE, RECOVER }

var s := S.CHASE
var timer := 0
var attack_dir := Vector2.RIGHT
var _dealt := false
var _flank := Vector2.ZERO

@onready var d := data as SharkData


func _ready() -> void:
	super()
	_flank = Vector2.from_angle(randf() * TAU)


func hit_half_angle() -> float:
	return deg_to_rad(d.hit_half_angle_deg)


func _physics_process(_delta: float) -> void:
	if frozen():
		return
	var p := player()
	var v := Vector2.ZERO
	match s:
		S.CHASE:
			if p:
				var to := p.global_position - global_position
				if to.length() <= d.stop_dist:
					s = S.WINDUP
					timer = d.windup
					attack_dir = to.normalized()
				else:
					var goal := p.global_position + _flank * d.flank_dist if to.length() > d.stop_dist * 2.5 else p.global_position
					v = (goal - global_position).normalized() * d.speed
		S.WINDUP:
			timer -= 1
			if timer <= 0:
				s = S.ACTIVE
				timer = d.active
				_dealt = false
		S.ACTIVE:
			if not _dealt and p:
				var to := p.global_position - global_position
				if to.length() <= d.radius + d.hit_reach + p.data.radius and absf(attack_dir.angle_to(to)) <= hit_half_angle():
					p.take_damage(d.damage, global_position)
					_dealt = true
			timer -= 1
			if timer <= 0:
				s = S.RECOVER
				timer = d.recover
		S.RECOVER:
			timer -= 1
			if timer <= 0:
				s = S.CHASE
	velocity = v + knockback_velocity()
	move_and_slide()


func _on_hit(strong: bool) -> void:
	if s == S.WINDUP and not strong:
		return
	var stun := d.stagger_strong if strong else d.stagger
	if s != S.RECOVER or timer < stun:
		s = S.RECOVER
		timer = stun
