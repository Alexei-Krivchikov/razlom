extends Enemy

# Hierarchical FSM: ROAR and STUNNED are shared exits checked before the current state; inside
# STALK the next attack is picked by utility scoring, so the boss answers where the player stands
# (hug him and he slams, keep away and he charges or fires) instead of looping one pattern.

const PROJECTILE := preload("res://scenes/enemies/Projectile.tscn")

enum S { STALK, CHARGE_TELL, CHARGE, SLAM_TELL, SLAM_RECOVER, VOLLEY_TELL, ROAR, STUNNED }

# Fairness: the boss always walks this long between attacks, so a hit is never instantly followed.
const STALK_MIN := 50
const STALK_MAX := 110
# If the player keeps out of reach of the planned attack this long, fall back to the volley.
const STALK_GIVE_UP := 150

const CHARGE_TELL := 40
const CHARGE_RETELL := 40
const AIM_LOCK := 10
# Crosses the 560 px arena in 30 frames.
const CHARGE_SPEED := 1120.0
const CHARGE_DAMAGE := 20
const CHARGE_TIMEOUT := 90
const STUN := 110

const SLAM_TELL := 34
const SLAM_RADIUS := 70.0
const SLAM_DAMAGE := 15
const SLAM_SHOVE := 420.0
const SLAM_RECOVER := 34

const VOLLEY_TELL := 30
const VOLLEY_SHOTS := 5
const VOLLEY_SPREAD := deg_to_rad(50.0)
const RING_SHOTS := 10

const ROAR := 70
const ROAR_SHOVE := 520.0

const SUMMON_COOLDOWN := 720
const SUMMON_COOLDOWN_P2 := 480
const SUMMON_COUNT := 3
const SUMMON_CAP := 3

# Armour outside openings rewards reading the patterns over trading blows.
const ARMOURED_MULT := 0.6
const EXPOSED_MULT := 1.5

var s := S.STALK
var timer := STALK_MIN
var phase2 := false
var charge_dir := Vector2.DOWN
var charges_left := 0
var intent := "volley"
var _history: PackedStringArray = []
var attack_log: PackedStringArray = []
var _dealt := false
var _tell_total := 1
var _cooldowns := {"summon": 240}


func _init() -> void:
	max_health = 400.0
	speed = 95.0
	radius = 18.0
	knockback_scale = 0.0


func _ready() -> void:
	super()
	add_to_group("boss")
	collision_mask = 16
	_to_stalk()


func damage_taken_mult() -> float:
	match s:
		S.STUNNED:
			return EXPOSED_MULT
		S.SLAM_RECOVER:
			return 1.0
		S.ROAR:
			return 0.0
	return ARMOURED_MULT


func _mult() -> float:
	return 1.25 if phase2 else 1.0


func _physics_process(_delta: float) -> void:
	if frozen():
		return
	tick_common()
	for k in _cooldowns:
		_cooldowns[k] = maxi(_cooldowns[k] - 1, 0)

	if not phase2 and health < max_health * 0.5:
		phase2 = true
		_enter(S.ROAR, ROAR)

	var p := player()
	var v := Vector2.ZERO
	timer -= 1
	match s:
		S.STALK:
			if p:
				v = _stalk_velocity(p)
				if timer <= 0 and _in_range(p):
					_execute(intent)
				elif timer < -STALK_GIVE_UP:
					intent = "volley"
					_execute(intent)
		S.CHARGE_TELL:
			if p and timer > AIM_LOCK:
				charge_dir = (p.global_position - global_position).normalized()
			if timer <= 0:
				_dealt = false
				_enter(S.CHARGE, CHARGE_TIMEOUT)
		S.CHARGE:
			_charge_step(p)
			return
		S.SLAM_TELL:
			if timer <= 0:
				_slam(p)
		S.SLAM_RECOVER:
			if timer <= 0:
				_to_stalk()
		S.VOLLEY_TELL:
			if timer <= 0:
				_volley(p)
				_to_stalk()
		S.ROAR:
			if timer == ROAR - 20 and p:
				var away := (p.global_position - global_position).normalized()
				p.shove(away * ROAR_SHOVE)
				Events.shake_requested.emit(8.0)
				Fx.burst(get_parent(), global_position, Palette.CYAN, 40, 260.0, 4.0)
				_fire_ring()
			if timer <= 0:
				_to_stalk()
		S.STUNNED:
			if timer <= 0:
				_to_stalk()
	velocity = v + knockback_velocity()
	move_and_slide()


func _enter(next: S, frames: int) -> void:
	s = next
	timer = frames
	_tell_total = maxi(frames, 1)


func _to_stalk() -> void:
	_enter(S.STALK, roundi(randi_range(STALK_MIN, STALK_MAX) / _mult()))
	var p := player()
	intent = _pick_intent(p) if p else "volley"


# Decide first, then walk to the range that attack needs: deciding at the last moment always
# found the player in slam range, because stalking means walking at him.
func _pick_intent(p: Player) -> String:
	var dist := global_position.distance_to(p.global_position)
	var near := clampf(inverse_lerp(200.0, 60.0, dist), 0.0, 1.0)
	var far := clampf(inverse_lerp(120.0, 300.0, dist), 0.0, 1.0)
	var adds := get_tree().get_nodes_in_group("enemies").size() - 1
	var scores := {
		"slam": 0.35 + 0.4 * near,
		"charge": 0.35 + 0.4 * far,
		"volley": 0.4,
		"summon": 0.8 if adds < SUMMON_CAP and _cooldowns["summon"] == 0 else 0.0,
	}
	var best := "volley"
	var best_score := 0.0
	for id: String in scores:
		var score: float = scores[id]
		if _history.size() >= 2 and _history[-1] == id and _history[-2] == id:
			continue
		if not _history.is_empty() and _history[-1] == id:
			score *= 0.5
		score *= randf_range(0.8, 1.2)
		if score > best_score:
			best = id
			best_score = score
	return best


func _stalk_velocity(p: Player) -> Vector2:
	var to := p.global_position - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var want_min := 0.0
	var want_max := 0.0
	match intent:
		"slam":
			want_max = SLAM_RADIUS * 0.6
		"charge":
			want_min = 170.0
			want_max = 1000.0
		_:
			want_min = 110.0
			want_max = 230.0
	if dist > want_max:
		return dir * speed * _mult()
	if dist < want_min:
		return -dir * speed * _mult()
	return dir.orthogonal() * speed * 0.4 * _mult()


func _in_range(p: Player) -> bool:
	var dist := global_position.distance_to(p.global_position)
	match intent:
		"slam":
			return dist <= SLAM_RADIUS * 0.8
		"charge":
			return dist >= 150.0
	return true


func _execute(id: String) -> void:
	_history.append(id)
	attack_log.append(id)
	match id:
		"slam":
			_enter(S.SLAM_TELL, roundi(SLAM_TELL / _mult()))
		"charge":
			charges_left = 2 if phase2 else 1
			_enter(S.CHARGE_TELL, roundi(CHARGE_TELL / _mult()))
		"volley":
			_enter(S.VOLLEY_TELL, roundi(VOLLEY_TELL / _mult()))
		"summon":
			_cooldowns["summon"] = SUMMON_COOLDOWN_P2 if phase2 else SUMMON_COOLDOWN
			Events.summon_requested.emit(global_position, SUMMON_COUNT)
			_to_stalk()


func _charge_step(p: Player) -> void:
	velocity = charge_dir * CHARGE_SPEED
	move_and_slide()
	if not _dealt and p and global_position.distance_to(p.global_position) <= radius + Player.RADIUS + 4.0:
		p.take_damage(CHARGE_DAMAGE, global_position)
		_dealt = true
	if get_slide_collision_count() > 0:
		Events.shake_requested.emit(6.0)
		Sfx.play("hit")
		Fx.burst(get_parent(), global_position + charge_dir * radius, Palette.SAND, 16, 180.0, 3.0)
		charges_left -= 1
		if charges_left > 0:
			_enter(S.CHARGE_TELL, CHARGE_RETELL)
		else:
			_enter(S.STUNNED, STUN)
	elif timer <= 0:
		_to_stalk()


func _slam(p: Player) -> void:
	Events.shake_requested.emit(6.0)
	Sfx.play("hit")
	Fx.burst(get_parent(), global_position, Palette.MAGENTA, 30, 240.0, 4.0)
	if p:
		var to := p.global_position - global_position
		if to.length() <= SLAM_RADIUS + Player.RADIUS:
			p.take_damage(SLAM_DAMAGE, global_position)
			p.shove(to.normalized() * SLAM_SHOVE)
	if phase2:
		_fire_ring()
	_enter(S.SLAM_RECOVER, SLAM_RECOVER)


func _volley(p: Player) -> void:
	if p == null:
		return
	var aim := (p.global_position - global_position).normalized()
	for i in VOLLEY_SHOTS:
		var t := float(i) / (VOLLEY_SHOTS - 1) - 0.5
		_shoot(aim.rotated(t * VOLLEY_SPREAD))


func _fire_ring() -> void:
	var offset := randf() * TAU
	for i in RING_SHOTS:
		_shoot(Vector2.from_angle(offset + TAU * i / RING_SHOTS))


func _shoot(dir: Vector2) -> void:
	var proj := PROJECTILE.instantiate()
	proj.position = global_position + dir * (radius + 6)
	proj.direction = dir
	get_parent().add_child(proj)


func die() -> void:
	Events.boss_died.emit()
	Fx.burst(get_parent(), global_position, Palette.CYAN, 50, 300.0, 5.0)
	super()


func _tell_progress() -> float:
	return clampf(1.0 - float(timer) / _tell_total, 0.0, 1.0)


func _draw() -> void:
	var col := Palette.MAGENTA
	match s:
		S.CHARGE_TELL:
			var p := _tell_progress()
			var far := charge_dir * 700.0
			draw_line(Vector2.ZERO, far, Color(Palette.MAGENTA, 0.15 + 0.35 * p), radius * 2.0 * p)
			draw_line(Vector2.ZERO, far, Color(Palette.SAND, 0.6 * p), 1.0)
			draw_circle(Vector2.ZERO, radius + 6 + 4 * p, Color(Palette.MAGENTA, 0.25 + 0.3 * p))
			if timer % 4 < 2:
				col = Palette.SAND
		S.CHARGE:
			draw_circle(-charge_dir * 14.0, radius, Color(Palette.MAGENTA, 0.3))
		S.SLAM_TELL:
			var p := _tell_progress()
			draw_circle(Vector2.ZERO, SLAM_RADIUS, Color(Palette.MAGENTA, 0.08 + 0.17 * p))
			draw_arc(Vector2.ZERO, SLAM_RADIUS, 0, TAU, 48, Color(Palette.MAGENTA, 0.5 + 0.5 * p), 2.0)
			draw_arc(Vector2.ZERO, SLAM_RADIUS * p, 0, TAU, 48, Color(Palette.SAND, 0.8), 2.0)
			if timer < 8 and timer % 2 == 0:
				col = Palette.SAND
		S.SLAM_RECOVER:
			col = Palette.MAGENTA.darkened(0.35)
		S.VOLLEY_TELL:
			var p := _tell_progress()
			var pl := player()
			if pl:
				var aim := (pl.global_position - global_position).normalized()
				for i in VOLLEY_SHOTS:
					var t := float(i) / (VOLLEY_SHOTS - 1) - 0.5
					draw_line(Vector2.ZERO, aim.rotated(t * VOLLEY_SPREAD) * (40.0 + 60.0 * p), Color(Palette.MAGENTA, 0.5 * p), 1.0)
			draw_circle(Vector2.ZERO, 6.0 + 6.0 * p, Color(Palette.SAND, p))
		S.ROAR:
			var p := _tell_progress()
			draw_arc(Vector2.ZERO, radius + 10 + 80 * p, 0, TAU, 40, Color(Palette.CYAN, 1.0 - p), 3.0)
			col = Palette.CYAN
		S.STUNNED:
			col = Palette.MAGENTA.darkened(0.55)
			draw_arc(Vector2.ZERO, radius + 5, 0, TAU, 24, Color(Palette.CYAN, 0.6 + 0.4 * sin(timer * 0.5)), 2.0)
			var t := Time.get_ticks_msec() / 150.0
			for i in 3:
				var a := t + i * TAU / 3
				draw_circle(Vector2(cos(a) * 14, -radius - 6 + sin(a) * 3), 2.0, Palette.CYAN)
	var hex := PackedVector2Array()
	var hex_in := PackedVector2Array()
	for i in 6:
		var a := i * TAU / 6 + PI / 6
		hex.append(Vector2.from_angle(a) * (radius + 2))
		hex_in.append(Vector2.from_angle(a) * radius)
	draw_colored_polygon(hex, Palette.BG)
	draw_colored_polygon(hex_in, body_color(col))
	var core := Palette.CYAN if phase2 else Palette.BG
	draw_circle(Vector2.ZERO, 6.0, Palette.SAND if flash > 0 else core)
	draw_line(Vector2(-10, -4), Vector2(-3, 2), Palette.BG, 2.0)
	draw_line(Vector2(10, -4), Vector2(3, 2), Palette.BG, 2.0)
