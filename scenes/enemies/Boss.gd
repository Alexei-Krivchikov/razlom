class_name Boss
extends Enemy

# Hierarchical FSM: ROAR and STUNNED are shared exits checked before the current state; inside
# STALK the next attack is picked by utility scoring, so the boss answers where the player stands
# (hug him and he slams, keep away and he charges or fires) instead of looping one pattern.

signal charge_impact
signal slammed
signal roared

enum S { STALK, CHARGE_TELL, CHARGE, SLAM_TELL, SLAM_RECOVER, VOLLEY_TELL, ROAR, STUNNED }

var s := S.STALK
var timer := 0
var tell_total := 1
var phase2 := false
var charge_dir := Vector2.DOWN
var charges_left := 0
var intent := "volley"
var attack_log: PackedStringArray = []
var _history: PackedStringArray = []
var _dealt := false
var _cooldowns := {}

@onready var d := data as BossData


func _ready() -> void:
	super()
	add_to_group("boss")
	collision_mask = 16
	_cooldowns["summon"] = d.summon_first
	_to_stalk()


func damage_taken_mult() -> float:
	match s:
		S.STUNNED:
			return d.exposed_mult
		S.SLAM_RECOVER:
			return 1.0
		S.ROAR:
			return 0.0
	return d.armoured_mult


func _mult() -> float:
	return d.phase2_speed if phase2 else 1.0


func volley_spread() -> float:
	return deg_to_rad(d.volley_spread_deg)


func _physics_process(_delta: float) -> void:
	if frozen():
		return
	for k in _cooldowns:
		_cooldowns[k] = maxi(_cooldowns[k] - 1, 0)

	if not phase2 and health < d.max_health * d.phase2_at:
		phase2 = true
		_enter(S.ROAR, d.roar)

	var p := player()
	var v := Vector2.ZERO
	timer -= 1
	match s:
		S.STALK:
			if p:
				v = _stalk_velocity(p)
				if timer <= 0 and _in_range(p):
					_execute(intent)
				elif timer < -d.stalk_give_up:
					intent = "volley"
					_execute(intent)
		S.CHARGE_TELL:
			if p and timer > d.aim_lock:
				charge_dir = (p.global_position - global_position).normalized()
			if timer <= 0:
				_dealt = false
				_enter(S.CHARGE, d.charge_timeout)
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
			if timer == d.roar - 20 and p:
				var away := (p.global_position - global_position).normalized()
				p.shove(away * d.roar_shove)
				roared.emit()
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
	tell_total = maxi(frames, 1)


func _to_stalk() -> void:
	_enter(S.STALK, roundi(randi_range(d.stalk_min, d.stalk_max) / _mult()))
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
		"summon": 0.8 if adds < d.summon_cap and _cooldowns["summon"] == 0 else 0.0,
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
			want_max = d.slam_radius * 0.6
		"charge":
			want_min = 170.0
			want_max = 1000.0
		_:
			want_min = 110.0
			want_max = 230.0
	if dist > want_max:
		return dir * d.speed * _mult()
	if dist < want_min:
		return -dir * d.speed * _mult()
	return dir.orthogonal() * d.speed * 0.4 * _mult()


func _in_range(p: Player) -> bool:
	var dist := global_position.distance_to(p.global_position)
	match intent:
		"slam":
			return dist <= d.slam_radius * 0.8
		"charge":
			return dist >= 150.0
	return true


func _execute(id: String) -> void:
	_history.append(id)
	attack_log.append(id)
	match id:
		"slam":
			_enter(S.SLAM_TELL, roundi(d.slam_tell / _mult()))
		"charge":
			charges_left = 2 if phase2 else 1
			_enter(S.CHARGE_TELL, roundi(d.charge_tell / _mult()))
		"volley":
			_enter(S.VOLLEY_TELL, roundi(d.volley_tell / _mult()))
		"summon":
			_cooldowns["summon"] = d.summon_cooldown_p2 if phase2 else d.summon_cooldown
			Events.summon_requested.emit(global_position, d.minion, d.summon_count)
			_to_stalk()


func _charge_step(p: Player) -> void:
	velocity = charge_dir * d.charge_speed
	move_and_slide()
	if not _dealt and p and global_position.distance_to(p.global_position) <= d.radius + p.data.radius + 4.0:
		p.take_damage(d.charge_damage, global_position)
		_dealt = true
	if get_slide_collision_count() > 0:
		charge_impact.emit()
		charges_left -= 1
		if charges_left > 0:
			_enter(S.CHARGE_TELL, d.charge_retell)
		else:
			_enter(S.STUNNED, d.stun)
	elif timer <= 0:
		_to_stalk()


func _slam(p: Player) -> void:
	slammed.emit()
	if p:
		var to := p.global_position - global_position
		if to.length() <= d.slam_radius + p.data.radius:
			p.take_damage(d.slam_damage, global_position)
			p.shove(to.normalized() * d.slam_shove)
	if phase2:
		_fire_ring()
	_enter(S.SLAM_RECOVER, d.slam_recover)


func volley_dirs(aim: Vector2) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	for i in d.volley_shots:
		var t := float(i) / (d.volley_shots - 1) - 0.5
		dirs.append(aim.rotated(t * volley_spread()))
	return dirs


func _volley(p: Player) -> void:
	if p == null:
		return
	for dir in volley_dirs((p.global_position - global_position).normalized()):
		_shoot(dir)


func _fire_ring() -> void:
	var offset := randf() * TAU
	for i in d.ring_shots:
		_shoot(Vector2.from_angle(offset + TAU * i / d.ring_shots))


func _shoot(dir: Vector2) -> void:
	get_parent().add_child(d.projectile.spawn(global_position + dir * (d.radius + 6), dir))


func die() -> void:
	Events.boss_died.emit()
	super()


func tell_progress() -> float:
	return clampf(1.0 - float(timer) / tell_total, 0.0, 1.0)
