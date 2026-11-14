extends Enemy

const STOP_DIST := 40.0
const WINDUP := 24
const ACTIVE := 6
const RECOVER := 30
# Light hits flinch the shark only before it commits to a swing; once the windup starts, only the
# heavy third hit breaks it. Mashing can't erase every attack, the player has to read and dash.
const STAGGER := 16
const STAGGER_STRONG := 30
# Each shark closes in from its own side, so a crowd can't be lined up in one swing arc.
const FLANK_DIST := 34.0
const DAMAGE := 10
const HIT_REACH := 30.0
const HIT_HALF_ANGLE := deg_to_rad(60.0)

enum S { CHASE, WINDUP, ACTIVE, RECOVER }

var s := S.CHASE
var timer := 0
var attack_dir := Vector2.RIGHT
var _dealt := false
var _flank := Vector2.ZERO


func _init() -> void:
	max_health = 45.0
	speed = 140.0
	radius = 9.0


func _ready() -> void:
	super()
	_flank = Vector2.from_angle(randf() * TAU)


func _physics_process(_delta: float) -> void:
	if frozen():
		return
	tick_common()
	var p := player()
	var v := Vector2.ZERO
	match s:
		S.CHASE:
			if p:
				var to := p.global_position - global_position
				if to.length() <= STOP_DIST:
					s = S.WINDUP
					timer = WINDUP
					attack_dir = to.normalized()
				else:
					var goal := p.global_position + _flank * FLANK_DIST if to.length() > STOP_DIST * 2.5 else p.global_position
					v = (goal - global_position).normalized() * speed
		S.WINDUP:
			timer -= 1
			if timer <= 0:
				s = S.ACTIVE
				timer = ACTIVE
				_dealt = false
		S.ACTIVE:
			if not _dealt and p:
				var to := p.global_position - global_position
				if to.length() <= radius + HIT_REACH + Player.RADIUS and absf(attack_dir.angle_to(to)) <= HIT_HALF_ANGLE:
					p.take_damage(DAMAGE, global_position)
					_dealt = true
			timer -= 1
			if timer <= 0:
				s = S.RECOVER
				timer = RECOVER
		S.RECOVER:
			timer -= 1
			if timer <= 0:
				s = S.CHASE
	velocity = v + knockback_velocity()
	move_and_slide()


func _on_hit(strong: bool) -> void:
	if s == S.WINDUP and not strong:
		return
	var stun := STAGGER_STRONG if strong else STAGGER
	if s != S.RECOVER or timer < stun:
		s = S.RECOVER
		timer = stun


func _draw() -> void:
	var col := Palette.MAGENTA
	match s:
		S.WINDUP:
			var p := 1.0 - float(timer) / WINDUP
			draw_colored_polygon(Fx.sector(radius + HIT_REACH, attack_dir, HIT_HALF_ANGLE), Color(Palette.MAGENTA, 0.12 + 0.18 * p))
			draw_arc(Vector2.ZERO, radius + 10 - 6 * p, 0, TAU, 20, Color(Palette.SAND, p), 2.0)
			if timer < 8 and timer % 2 == 0:
				col = Palette.SAND
		S.ACTIVE:
			draw_colored_polygon(Fx.sector(radius + HIT_REACH, attack_dir, HIT_HALF_ANGLE), Color(Palette.MAGENTA, 0.7))
		S.RECOVER:
			col = Palette.MAGENTA.darkened(0.55)
	draw_circle(Vector2.ZERO, radius + 1, Palette.BG)
	draw_circle(Vector2.ZERO, radius, body_color(col))
	var look := attack_dir if s != S.CHASE else velocity.normalized()
	draw_circle(look * 4 + look.orthogonal() * 3, 1.5, Palette.BG)
	draw_circle(look * 4 - look.orthogonal() * 3, 1.5, Palette.BG)
