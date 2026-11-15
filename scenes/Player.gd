class_name Player
extends CharacterBody2D

const SPEED := 220.0
const RADIUS := 8.0
const ATTACK_RADIUS := 48.0
const ATTACK_HALF_ANGLE := deg_to_rad(50.0)
const COMBO := [
	{"windup": 6, "active": 4, "recovery": 10, "damage": 10.0, "strong": false, "window": 20, "lunge": 12.0},
	{"windup": 6, "active": 4, "recovery": 12, "damage": 12.0, "strong": false, "window": 20, "lunge": 12.0},
	{"windup": 10, "active": 6, "recovery": 22, "damage": 20.0, "strong": true, "window": 0, "lunge": 22.0},
]
# The lunge starts this many frames before the active frames so the step reads as part of the swing.
const LUNGE_LEAD := 2
# Hits 1-2 may chain into the next hit this many frames into recovery; mashing skips the rest of it.
const CHAIN_AFTER := 3
const TURN_FRAMES := 4
const DASH_DISTANCE := 180.0
# At 12 frames the hero covered ~30 px per frame and the sprite read as a teleport, not a dash.
const DASH_FRAMES := 18
const DASH_INVULN := 14
# Afterimages kept behind the hero; gaps between them are filled with in-between ghosts.
const TRAIL_LENGTH := 8
const DASH_COOLDOWN := 40
const HURT_INVULN := 40
const SHOVE_FRAMES := 12
const SHOCKWAVE_RADIUS := 96.0
# Presses are remembered this long so input during hitstop or recovery isn't swallowed.
const INPUT_BUFFER := 10
# Canvas pixel of every hero frame that sits on the feet; must match ANCHOR in tools/sprites/build_hero.py.
const SPRITE_ANCHOR := Vector2(56, 56)
const ANIMS := ["idle", "walk", "punch0", "punch1", "punch2", "dash", "hurt", "dead"]
# Clip frame where the arm is fully out; it is timed to land on the first active frame of the hit.
const PUNCH_PEAK := [6, 2, 13]
# Wan renders 16 fps, so four 60 Hz frames per clip frame keep its timing.
const CLIP_STEP := 4
# The recoil plays for this many frames after a hit, then the invulnerability blink continues on the normal pose.
const HURT_POSE := 16

static var _frames := {}

enum State { FREE, ATTACK, DASH, DEAD }

@export var player_index := 1

var max_health := 100
var health := 100
var facing := Vector2.RIGHT
var state := State.FREE

var combo_index := 0
var combo_window := 0
var attack_frame := 0
var _hit_ids := {}

var dash_frame := 0
var dash_dir := Vector2.RIGHT
var dash_cooldown := 0

var invuln := 0
var hurt_blink := 0
var flash := 0
var _shove := Vector2.ZERO
var _shove_left := 0
var shock_anim := 0

var _attack_buffer := 0
var _dash_buffer := 0
var _trail: Array[Vector2] = []
var _actions := {}
var _sprite: Sprite2D
var _anim_t := 0
var _dead_t := 0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 16
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	_load_frames()
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.position = Vector2(0, RADIUS * 0.5)
	add_child(_sprite)
	for a in ["up", "down", "left", "right", "attack", "dash"]:
		_actions[a] = "p%d_%s" % [player_index, a]


func input_dir() -> Vector2:
	return Input.get_vector(_actions["left"], _actions["right"], _actions["up"], _actions["down"])


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(_actions["attack"]):
		_attack_buffer = INPUT_BUFFER
	if Input.is_action_just_pressed(_actions["dash"]):
		_dash_buffer = INPUT_BUFFER
	if GameState.hitstop > 0 or state == State.DEAD:
		return

	invuln = maxi(invuln - 1, 0)
	hurt_blink = maxi(hurt_blink - 1, 0)
	flash = maxi(flash - 1, 0)
	shock_anim = maxi(shock_anim - 1, 0)
	dash_cooldown = maxi(dash_cooldown - 1, 0)
	if combo_window > 0:
		combo_window -= 1
		if combo_window == 0:
			combo_index = 0

	var dir := input_dir()
	match state:
		State.FREE:
			if _dash_buffer > 0 and dash_cooldown == 0:
				_start_dash(dir)
			elif _attack_buffer > 0:
				_start_attack()
				_attack_step(dir)
			else:
				if dir != Vector2.ZERO:
					facing = dir.normalized()
				velocity = dir * SPEED
				move_and_slide()
		State.ATTACK:
			_attack_step(dir)
		State.DASH:
			_dash_step()

	# A shove rides on top of whatever the hero is doing, except a dash, which outruns it.
	if _shove_left > 0 and state != State.DASH:
		velocity = _shove * (float(_shove_left) / SHOVE_FRAMES)
		move_and_slide()
		_shove_left -= 1

	_attack_buffer = maxi(_attack_buffer - 1, 0)
	_dash_buffer = maxi(_dash_buffer - 1, 0)


func _process(_delta: float) -> void:
	if state == State.DASH:
		_trail.push_front(global_position)
		if _trail.size() > TRAIL_LENGTH:
			_trail.pop_back()
	elif not _trail.is_empty():
		_trail.pop_back()
	_update_sprite()
	queue_redraw()


static func _load_frames() -> void:
	if not _frames.is_empty():
		return
	for anim: String in ANIMS:
		var list: Array[Texture2D] = []
		while ResourceLoader.exists("res://sprites/hero/%s_%d.png" % [anim, list.size()]):
			list.append(load("res://sprites/hero/%s_%d.png" % [anim, list.size()]))
		_frames[anim] = list


func _update_sprite() -> void:
	_anim_t += 1
	var frames: Array = _frames.idle
	var i := (_anim_t / (CLIP_STEP * 2)) % frames.size()
	match state:
		State.FREE:
			if hurt_blink > HURT_INVULN - HURT_POSE:
				frames = _frames.hurt
				i = _progress(1.0 - float(hurt_blink - (HURT_INVULN - HURT_POSE)) / HURT_POSE, frames.size())
			elif velocity.length() > 1.0:
				frames = _frames.walk
				i = (_anim_t / CLIP_STEP) % frames.size()
		State.ATTACK:
			frames = _frames["punch%d" % combo_index]
			var c: Dictionary = COMBO[combo_index]
			var peak: int = PUNCH_PEAK[combo_index]
			if attack_frame <= c.windup:
				i = _progress(float(attack_frame) / (c.windup + 1), peak + 1)
			else:
				var rest: int = c.active + c.recovery
				i = peak + _progress(float(attack_frame - c.windup - 1) / rest, frames.size() - peak)
		State.DASH:
			frames = _frames.dash
			i = _progress(float(dash_frame) / DASH_FRAMES, frames.size())
		State.DEAD:
			frames = _frames.dead
			_dead_t += 1
			i = mini(_dead_t / CLIP_STEP, frames.size() - 1)
	_sprite.texture = frames[i]
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	var w := float(_sprite.texture.get_width())
	var ax := w - SPRITE_ANCHOR.x if _sprite.flip_h else SPRITE_ANCHOR.x
	_sprite.offset = Vector2(-ax, -SPRITE_ANCHOR.y)
	var blinking := state != State.DEAD and hurt_blink > 0 and hurt_blink <= HURT_INVULN - HURT_POSE
	_sprite.visible = not (blinking and (hurt_blink / 3) % 2 == 1)
	_sprite.modulate = Color(2.5, 2.5, 2.5) if flash > 0 else Color.WHITE


static func _progress(t: float, count: int) -> int:
	return clampi(int(t * count), 0, count - 1)


func _start_attack() -> void:
	state = State.ATTACK
	attack_frame = 0
	combo_window = 0
	_attack_buffer = 0
	_hit_ids.clear()
	Sfx.play("swing")


func _attack_step(dir: Vector2) -> void:
	var c: Dictionary = COMBO[combo_index]
	attack_frame += 1
	velocity = Vector2.ZERO
	if attack_frame <= TURN_FRAMES and dir != Vector2.ZERO:
		facing = dir.normalized()

	var active_start: int = c.windup + 1
	var active_end: int = c.windup + c.active
	var lunge_start := active_start - LUNGE_LEAD
	if attack_frame >= lunge_start and attack_frame <= active_end and not _enemy_in_face():
		var n := active_end - lunge_start + 1
		var peak: float = c.lunge * Engine.physics_ticks_per_second * 2.0 / (n + 1)
		velocity = facing * peak * float(active_end - attack_frame + 1) / n
	if attack_frame >= active_start and attack_frame <= active_end:
		if attack_frame == active_start:
			if c.strong and GameState.level("shockwave") > 0:
				shock_anim = 12
		_hit_enemies(c)
	move_and_slide()

	if attack_frame > active_end and _dash_buffer > 0 and dash_cooldown == 0:
		_start_dash(dir)
		return

	if c.window > 0 and attack_frame >= active_end + CHAIN_AFTER and _attack_buffer > 0:
		combo_index += 1
		_start_attack()
		return

	if attack_frame >= active_end + c.recovery:
		state = State.FREE
		if c.window > 0:
			combo_index += 1
			combo_window = c.window
		else:
			combo_index = 0


# The hero doesn't collide with enemies, so without this the lunge would carry him through them.
func _enemy_in_face() -> bool:
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var to := e.global_position - global_position
		if to.length() <= RADIUS + e.radius + 6.0 and facing.dot(to) > 0.0:
			return true
	return false


func shockwave_radius() -> float:
	return SHOCKWAVE_RADIUS * (1.0 + 0.25 * (GameState.level("shockwave") - 1))


func _hit_enemies(c: Dictionary) -> void:
	var strong: bool = c.strong
	var shock := strong and GameState.level("shockwave") > 0
	var damage: float = c.damage * GameState.damage_mult()
	var hit_any := false
	var killed := false
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var id := e.get_instance_id()
		if _hit_ids.has(id):
			continue
		var to := e.global_position - global_position
		var dist := to.length()
		var in_sector := dist <= ATTACK_RADIUS + e.radius and absf(facing.angle_to(to)) <= ATTACK_HALF_ANGLE
		var touching := dist <= RADIUS + e.radius + 4.0
		var in_shock := shock and dist <= shockwave_radius() + e.radius
		if not (in_sector or touching or in_shock):
			continue
		_hit_ids[id] = true
		hit_any = true
		var push := to.normalized() if dist > 0.1 else facing
		if e.take_hit(damage, push, strong):
			killed = true
	if hit_any:
		GameState.freeze(8 if strong or killed else 4)
		Events.shake_requested.emit(6.0 if strong else 3.0)
		Sfx.play("hit")



func _start_dash(dir: Vector2) -> void:
	dash_dir = dir.normalized() if dir != Vector2.ZERO else facing
	facing = dash_dir
	state = State.DASH
	dash_frame = 0
	_dash_buffer = 0
	_attack_buffer = 0
	combo_index = 0
	combo_window = 0
	var phase := GameState.level("phase")
	dash_cooldown = roundi(DASH_COOLDOWN * pow(0.7, phase))
	invuln = maxi(invuln, DASH_INVULN + 2 * phase)
	_dash_step()


func _dash_step() -> void:
	dash_frame += 1
	var t0 := _ease_out(float(dash_frame - 1) / DASH_FRAMES)
	var t1 := _ease_out(float(dash_frame) / DASH_FRAMES)
	velocity = dash_dir * DASH_DISTANCE * (t1 - t0) * Engine.physics_ticks_per_second
	move_and_slide()
	if dash_frame >= DASH_FRAMES:
		state = State.FREE


func _ease_out(t: float) -> float:
	return sin(t * PI * 0.5)


func shove(v: Vector2) -> void:
	_shove = v
	_shove_left = SHOVE_FRAMES


func take_damage(amount: int, _from: Vector2) -> void:
	if state == State.DEAD or invuln > 0:
		return
	health = maxi(health - amount, 0)
	invuln = HURT_INVULN
	hurt_blink = HURT_INVULN
	flash = 4
	Events.player_damaged.emit(amount)
	Events.shake_requested.emit(4.0)
	GameState.freeze(5)
	Sfx.play("hurt")
	if health == 0:
		state = State.DEAD
		Fx.burst(get_parent(), global_position, Palette.CYAN, 40, 200.0, 4.0)
		Events.player_died.emit()


func heal_full() -> void:
	health = max_health


func _draw() -> void:
	var mirror := -1.0 if _sprite.flip_h else 1.0
	for i in _trail.size():
		var a := 0.45 * (1.0 - float(i) / _trail.size())
		var from := to_local(_trail[i]) + _sprite.position
		var gap := global_position.distance_to(_trail[i]) if i == 0 else _trail[i - 1].distance_to(_trail[i])
		var steps := clampi(int(gap / 6.0), 1, 4)
		for k in steps:
			var to := to_local(_trail[i - 1]) + _sprite.position if i > 0 else _sprite.position
			draw_set_transform(from.lerp(to, float(k) / steps), 0.0, Vector2(mirror, 1.0))
			draw_texture(_sprite.texture, -SPRITE_ANCHOR, Color(Palette.CYAN, a * (1.0 - 0.15 * k)))
	draw_set_transform(Vector2.ZERO)

	if state == State.DEAD:
		return

	draw_set_transform(Vector2(0, RADIUS * 0.5), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.45))
	if dash_cooldown == 0 and state != State.DASH:
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 24, Color(Palette.CYAN, 0.35), 2.0)
	draw_set_transform(Vector2.ZERO)

	if shock_anim > 0:
		var t := 1.0 - shock_anim / 12.0
		draw_arc(Vector2.ZERO, shockwave_radius() * t, 0, TAU, 40, Color(Palette.CYAN, 1.0 - t), 3.0)

	if state == State.ATTACK:
		var c: Dictionary = COMBO[combo_index]
		if attack_frame <= c.windup:
			var p: float = float(attack_frame) / c.windup
			draw_arc(Vector2.ZERO, RADIUS + 3, facing.angle() - 1.0, facing.angle() + 1.0, 8, Color(Palette.SAND, p), 2.0)
		elif attack_frame <= c.windup + c.active:
			var col := Palette.SAND if not c.strong else Palette.CYAN
			draw_colored_polygon(Fx.sector(ATTACK_RADIUS, facing, ATTACK_HALF_ANGLE), Color(col, 0.55))
			draw_polyline(Fx.sector(ATTACK_RADIUS, facing, ATTACK_HALF_ANGLE).slice(1), col, 2.0)
