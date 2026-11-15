class_name Player
extends CharacterBody2D

signal attack_started(attack: AttackData)
signal shockwave_fired
signal hit_landed(strong: bool)
signal hurt
signal died

enum State { FREE, ATTACK, DASH, DEAD }

@export var data: HeroData
@export var player_index := 1

var input: PlayerInput

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
var dash_cooldown_total := 1

var invuln := 0
var _shove := Vector2.ZERO
var _shove_left := 0

var _attack_buffer := 0
var _dash_buffer := 0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 16
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.radius
	shape.shape = circle
	add_child(shape)
	max_health = data.max_health
	health = max_health
	dash_cooldown_total = data.dash_cooldown
	if input == null:
		input = PlayerInput.new(player_index)


func attack() -> AttackData:
	return data.combo[combo_index]


func _physics_process(_delta: float) -> void:
	var cmd := input.read()
	if cmd.attack:
		_attack_buffer = data.input_buffer
	if cmd.dash:
		_dash_buffer = data.input_buffer
	if GameState.hitstop > 0 or state == State.DEAD:
		return

	invuln = maxi(invuln - 1, 0)
	dash_cooldown = maxi(dash_cooldown - 1, 0)
	if combo_window > 0:
		combo_window -= 1
		if combo_window == 0:
			combo_index = 0

	var dir := cmd.move
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
				velocity = dir * data.speed
				move_and_slide()
		State.ATTACK:
			_attack_step(dir)
		State.DASH:
			_dash_step()

	# A shove rides on top of whatever the hero is doing, except a dash, which outruns it.
	if _shove_left > 0 and state != State.DASH:
		velocity = _shove * (float(_shove_left) / data.shove_frames)
		move_and_slide()
		_shove_left -= 1

	_attack_buffer = maxi(_attack_buffer - 1, 0)
	_dash_buffer = maxi(_dash_buffer - 1, 0)


func _start_attack() -> void:
	state = State.ATTACK
	attack_frame = 0
	combo_window = 0
	_attack_buffer = 0
	_hit_ids.clear()
	attack_started.emit(attack())


func _attack_step(dir: Vector2) -> void:
	var c := attack()
	attack_frame += 1
	velocity = Vector2.ZERO
	if attack_frame <= data.turn_frames and dir != Vector2.ZERO:
		facing = dir.normalized()

	var active_start := c.windup + 1
	var active_end := c.windup + c.active
	var lunge_start := active_start - data.lunge_lead
	if attack_frame >= lunge_start and attack_frame <= active_end and not _enemy_in_face():
		var n := active_end - lunge_start + 1
		var peak := c.lunge * Engine.physics_ticks_per_second * 2.0 / (n + 1)
		velocity = facing * peak * float(active_end - attack_frame + 1) / n
	if attack_frame >= active_start and attack_frame <= active_end:
		if attack_frame == active_start and c.strong and GameState.shockwave_level() > 0:
			shockwave_fired.emit()
		_hit_enemies(c)
	move_and_slide()

	if attack_frame > active_end and _dash_buffer > 0 and dash_cooldown == 0:
		_start_dash(dir)
		return

	if c.chain_window > 0 and attack_frame >= active_end + data.chain_after and _attack_buffer > 0:
		combo_index += 1
		_start_attack()
		return

	if attack_frame >= active_end + c.recovery:
		state = State.FREE
		if c.chain_window > 0:
			combo_index += 1
			combo_window = c.chain_window
		else:
			combo_index = 0


# The hero doesn't collide with enemies, so without this the lunge would carry him through them.
func _enemy_in_face() -> bool:
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var to := e.global_position - global_position
		if to.length() <= data.radius + e.data.radius + 6.0 and facing.dot(to) > 0.0:
			return true
	return false


func attack_half_angle() -> float:
	return deg_to_rad(data.attack_half_angle_deg)


func shockwave_radius() -> float:
	return data.shockwave_radius * GameState.shockwave_radius_mult()


func _hit_enemies(c: AttackData) -> void:
	var shock := c.strong and GameState.shockwave_level() > 0
	var damage := c.damage * GameState.damage_mult()
	var hit_any := false
	var killed := false
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var id := e.get_instance_id()
		if _hit_ids.has(id):
			continue
		var to := e.global_position - global_position
		var dist := to.length()
		var r := e.data.radius
		var in_sector := dist <= data.attack_radius + r and absf(facing.angle_to(to)) <= attack_half_angle()
		var touching := dist <= data.radius + r + 4.0
		var in_shock := shock and dist <= shockwave_radius() + r
		if not (in_sector or touching or in_shock):
			continue
		_hit_ids[id] = true
		hit_any = true
		var push := to.normalized() if dist > 0.1 else facing
		if e.take_hit(damage, push, c.strong):
			killed = true
	if hit_any:
		GameState.freeze(data.hitstop_heavy if c.strong or killed else data.hitstop_light)
		hit_landed.emit(c.strong)


func _start_dash(dir: Vector2) -> void:
	dash_dir = dir.normalized() if dir != Vector2.ZERO else facing
	facing = dash_dir
	state = State.DASH
	dash_frame = 0
	_dash_buffer = 0
	_attack_buffer = 0
	combo_index = 0
	combo_window = 0
	dash_cooldown_total = roundi(data.dash_cooldown * GameState.dash_cooldown_mult())
	dash_cooldown = dash_cooldown_total
	invuln = maxi(invuln, data.dash_invuln + GameState.dash_invuln_bonus())
	_dash_step()


func _dash_step() -> void:
	dash_frame += 1
	var t0 := _ease_out(float(dash_frame - 1) / data.dash_frames)
	var t1 := _ease_out(float(dash_frame) / data.dash_frames)
	velocity = dash_dir * data.dash_distance * (t1 - t0) * Engine.physics_ticks_per_second
	move_and_slide()
	if dash_frame >= data.dash_frames:
		state = State.FREE


func _ease_out(t: float) -> float:
	return sin(t * PI * 0.5)


func shove(v: Vector2) -> void:
	_shove = v
	_shove_left = data.shove_frames


func take_damage(amount: int, _from: Vector2) -> void:
	if state == State.DEAD or invuln > 0:
		return
	health = maxi(health - amount, 0)
	invuln = data.hurt_invuln
	GameState.freeze(data.hurt_hitstop)
	hurt.emit()
	Events.player_damaged.emit(amount)
	if health == 0:
		state = State.DEAD
		died.emit()
		Events.player_died.emit()


func add_max_health(amount: int, heal: bool) -> void:
	max_health += amount
	if heal:
		health = max_health
