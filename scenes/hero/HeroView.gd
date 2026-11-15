class_name HeroView
extends Node2D

# Canvas pixel of every hero frame that sits on the feet; must match ANCHOR in tools/sprites/build_hero.py.
const SPRITE_ANCHOR := Vector2(56, 56)
const ANIMS := ["idle", "walk", "punch0", "punch1", "punch2", "dash", "hurt", "dead"]
# Wan renders 16 fps, so four 60 Hz frames per clip frame keep its timing.
const CLIP_STEP := 4
# The recoil plays for this many frames after a hit, then the invulnerability blink continues on the normal pose.
const HURT_POSE := 16
# Afterimages kept behind the hero; gaps between them are filled with in-between ghosts.
const TRAIL_LENGTH := 8
const SHOCK_FRAMES := 12

static var _frames := {}

var _sprite: Sprite2D
var _trail: Array[Vector2] = []
var _anim_t := 0
var _dead_t := 0
var _hurt_blink := 0
var _flash := 0
var _shock_anim := 0

@onready var hero: Player = get_parent()


func _ready() -> void:
	_load_frames()
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.position = Vector2(0, hero.data.radius * 0.5)
	add_child(_sprite)
	hero.attack_started.connect(func(_a): Sfx.play("swing"))
	hero.shockwave_fired.connect(func(): _shock_anim = SHOCK_FRAMES)
	hero.hit_landed.connect(_on_hit_landed)
	hero.hurt.connect(_on_hurt)
	hero.died.connect(_on_died)


func _on_hit_landed(strong: bool) -> void:
	Events.shake_requested.emit(6.0 if strong else 3.0)
	Sfx.play("hit")


func _on_hurt() -> void:
	_hurt_blink = hero.data.hurt_invuln
	_flash = 4
	Events.shake_requested.emit(4.0)
	Sfx.play("hurt")


func _on_died() -> void:
	Fx.burst(hero.get_parent(), hero.global_position, Palette.CYAN, 40, 200.0, 4.0)


func _physics_process(_delta: float) -> void:
	if GameState.hitstop > 0 or hero.state == Player.State.DEAD:
		return
	_hurt_blink = maxi(_hurt_blink - 1, 0)
	_flash = maxi(_flash - 1, 0)
	_shock_anim = maxi(_shock_anim - 1, 0)


func _process(_delta: float) -> void:
	if hero.state == Player.State.DASH:
		_trail.push_front(hero.global_position)
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
	var d := hero.data
	var frames: Array = _frames.idle
	var i := (_anim_t / (CLIP_STEP * 2)) % frames.size()
	match hero.state:
		Player.State.FREE:
			if _hurt_blink > d.hurt_invuln - HURT_POSE:
				frames = _frames.hurt
				i = _progress(1.0 - float(_hurt_blink - (d.hurt_invuln - HURT_POSE)) / HURT_POSE, frames.size())
			elif hero.velocity.length() > 1.0:
				frames = _frames.walk
				i = (_anim_t / CLIP_STEP) % frames.size()
		Player.State.ATTACK:
			var c := hero.attack()
			frames = _frames[c.anim]
			var peak := c.anim_peak
			if hero.attack_frame <= c.windup:
				i = _progress(float(hero.attack_frame) / (c.windup + 1), peak + 1)
			else:
				var rest := c.active + c.recovery
				i = peak + _progress(float(hero.attack_frame - c.windup - 1) / rest, frames.size() - peak)
		Player.State.DASH:
			frames = _frames.dash
			i = _progress(float(hero.dash_frame) / d.dash_frames, frames.size())
		Player.State.DEAD:
			frames = _frames.dead
			_dead_t += 1
			i = mini(_dead_t / CLIP_STEP, frames.size() - 1)
	_sprite.texture = frames[i]
	if absf(hero.facing.x) > 0.1:
		_sprite.flip_h = hero.facing.x < 0.0
	var w := float(_sprite.texture.get_width())
	var ax := w - SPRITE_ANCHOR.x if _sprite.flip_h else SPRITE_ANCHOR.x
	_sprite.offset = Vector2(-ax, -SPRITE_ANCHOR.y)
	var blinking := hero.state != Player.State.DEAD and _hurt_blink > 0 and _hurt_blink <= d.hurt_invuln - HURT_POSE
	_sprite.visible = not (blinking and (_hurt_blink / 3) % 2 == 1)
	_sprite.modulate = Color(2.5, 2.5, 2.5) if _flash > 0 else Color.WHITE


static func _progress(t: float, count: int) -> int:
	return clampi(int(t * count), 0, count - 1)


func _draw() -> void:
	var mirror := -1.0 if _sprite.flip_h else 1.0
	for i in _trail.size():
		var a := 0.45 * (1.0 - float(i) / _trail.size())
		var from := to_local(_trail[i]) + _sprite.position
		var gap := hero.global_position.distance_to(_trail[i]) if i == 0 else _trail[i - 1].distance_to(_trail[i])
		var steps := clampi(int(gap / 6.0), 1, 4)
		for k in steps:
			var to := to_local(_trail[i - 1]) + _sprite.position if i > 0 else _sprite.position
			draw_set_transform(from.lerp(to, float(k) / steps), 0.0, Vector2(mirror, 1.0))
			draw_texture(_sprite.texture, -SPRITE_ANCHOR, Color(Palette.CYAN, a * (1.0 - 0.15 * k)))
	draw_set_transform(Vector2.ZERO)

	if hero.state == Player.State.DEAD:
		return

	var d := hero.data
	draw_set_transform(Vector2(0, d.radius * 0.5), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.45))
	if hero.dash_cooldown == 0 and hero.state != Player.State.DASH:
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 24, Color(Palette.CYAN, 0.35), 2.0)
	draw_set_transform(Vector2.ZERO)

	if _shock_anim > 0:
		var t := 1.0 - float(_shock_anim) / SHOCK_FRAMES
		draw_arc(Vector2.ZERO, hero.shockwave_radius() * t, 0, TAU, 40, Color(Palette.CYAN, 1.0 - t), 3.0)

	if hero.state == Player.State.ATTACK:
		var c := hero.attack()
		var facing := hero.facing
		if hero.attack_frame <= c.windup:
			var p := float(hero.attack_frame) / c.windup
			draw_arc(Vector2.ZERO, d.radius + 3, facing.angle() - 1.0, facing.angle() + 1.0, 8, Color(Palette.SAND, p), 2.0)
		elif hero.attack_frame <= c.windup + c.active:
			var col := Palette.SAND if not c.strong else Palette.CYAN
			var sector := Fx.sector(d.attack_radius, facing, hero.attack_half_angle())
			draw_colored_polygon(sector, Color(col, 0.55))
			draw_polyline(sector.slice(1), col, 2.0)
