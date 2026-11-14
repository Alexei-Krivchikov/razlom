class_name Rift
extends Node2D

const FRAMES := 30

var scene: PackedScene
var frames := FRAMES
var _left := FRAMES
var _cracks: Array[PackedVector2Array] = []


func _ready() -> void:
	add_to_group("rifts")
	_left = frames
	for i in 5:
		var pts := PackedVector2Array([Vector2.ZERO])
		var dir := Vector2.from_angle(randf() * TAU)
		var p := Vector2.ZERO
		for j in 3:
			p += dir.rotated(randf_range(-0.6, 0.6)) * randf_range(5, 9)
			pts.append(p)
		_cracks.append(pts)


func _physics_process(_delta: float) -> void:
	_left -= 1
	if _left <= 0:
		var e := scene.instantiate() as Node2D
		e.position = position
		get_parent().add_child(e)
		Fx.burst(get_parent(), position, Palette.RIFT, 14, 160.0, 3.0)
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := 1.0 - float(_left) / frames
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.0 * t
	draw_circle(Vector2.ZERO, 6 + 14 * t, Color(Palette.RIFT, 0.25 * t))
	for pts in _cracks:
		var scaled := PackedVector2Array()
		for p in pts:
			scaled.append(p * (0.4 + t) + jitter)
		draw_polyline(scaled, Color(Palette.RIFT, 0.4 + 0.6 * t), 2.0)
		draw_polyline(scaled, Color(Palette.MAGENTA, 0.5 * t), 1.0)
	draw_circle(jitter * -1.0, 2 + 3 * t, Color(Palette.SAND, t))
