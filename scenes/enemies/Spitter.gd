extends Enemy

const KEEP_DIST := 250.0
# Between RETREAT_DIST and KEEP_DIST the spitter stands still, so it can be cornered and caught.
const RETREAT_DIST := 150.0
const RETREAT_SPEED := 55.0
const ACCEL := 240.0
const FIRE_INTERVAL := 150
const WINDUP := 20
const REST_AFTER_SHOT := 40
const HIT_STUN := 20

var _fire_timer := 0
var _windup := 0
var _rest := 0
var _move := Vector2.ZERO
var _aim := Vector2.RIGHT


func _init() -> void:
	max_health = 20.0
	speed = 90.0
	radius = 8.0


func _ready() -> void:
	super()
	_fire_timer = randi_range(60, FIRE_INTERVAL)


func _physics_process(_delta: float) -> void:
	if frozen():
		return
	tick_common()
	var p := player()
	var v := Vector2.ZERO
	if p:
		var to := p.global_position - global_position
		_aim = to.normalized()
		if _windup > 0:
			_windup -= 1
			if _windup == 0:
				_shoot()
				_rest = REST_AFTER_SHOT
		elif _rest > 0:
			_rest -= 1
		else:
			var dist := to.length()
			if dist < RETREAT_DIST:
				v = -_aim * RETREAT_SPEED
			elif dist > KEEP_DIST:
				v = _aim * speed
			_fire_timer -= 1
			if _fire_timer <= 0:
				_windup = WINDUP
				_fire_timer = FIRE_INTERVAL
	_move = _move.move_toward(v, ACCEL / Engine.physics_ticks_per_second)
	velocity = _move + knockback_velocity()
	move_and_slide()


func _on_hit(_strong: bool) -> void:
	_move = Vector2.ZERO
	_rest = maxi(_rest, HIT_STUN)


func _shoot() -> void:
	var proj := preload("res://scenes/enemies/Projectile.tscn").instantiate()
	proj.position = global_position + _aim * (radius + 4)
	proj.direction = _aim
	get_parent().add_child(proj)


func _draw() -> void:
	var col := Palette.MAGENTA
	if _windup > 0:
		var p := 1.0 - float(_windup) / WINDUP
		draw_line(Vector2.ZERO, _aim * 40.0, Color(Palette.MAGENTA, 0.5 * p), 1.0)
		draw_circle(_aim * (radius + 2), 2.0 + 3.0 * p, Color(Palette.SAND, p))
	var pts := PackedVector2Array()
	for i in 4:
		pts.append(Vector2.from_angle(_aim.angle() + i * TAU / 4) * (radius + 2))
	draw_colored_polygon(pts, Palette.BG)
	pts.clear()
	for i in 4:
		pts.append(Vector2.from_angle(_aim.angle() + i * TAU / 4) * radius)
	draw_colored_polygon(pts, body_color(col))
	draw_circle(Vector2.ZERO, 3.0, Palette.CYAN if flash == 0 else Palette.SAND)
