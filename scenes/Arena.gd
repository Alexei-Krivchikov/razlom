class_name Arena
extends Node2D

const RECT := Rect2(40, 44, 560, 300)
const WALL := 40.0
const SPAWN_INSET := 26.0


static func spawn_points() -> Array[Vector2]:
	var r := RECT.grow(-SPAWN_INSET)
	return [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]


static func clamp_inside(p: Vector2, margin := 20.0) -> Vector2:
	var r := RECT.grow(-margin)
	return p.clamp(r.position, r.end)


func _ready() -> void:
	z_index = -10
	var body := StaticBody2D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	add_child(body)
	var r := RECT
	var walls := [
		Rect2(r.position.x - WALL, r.position.y - WALL, r.size.x + WALL * 2, WALL),
		Rect2(r.position.x - WALL, r.end.y, r.size.x + WALL * 2, WALL),
		Rect2(r.position.x - WALL, r.position.y, WALL, r.size.y),
		Rect2(r.end.x, r.position.y, WALL, r.size.y),
	]
	for w: Rect2 in walls:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = w.size
		shape.shape = rect
		shape.position = w.get_center()
		body.add_child(shape)


func _draw() -> void:
	var r := RECT
	draw_rect(r, Palette.FLOOR)
	var grid := Color(Palette.SAND, 0.035)
	var x := r.position.x
	while x <= r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), grid)
		x += 20.0
	var y := r.position.y
	while y <= r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), grid)
		y += 20.0

	var mark := Color(Palette.SAND, 0.09)
	var cx := r.get_center().x
	for i in 7:
		draw_rect(Rect2(cx - 70 + i * 22, r.position.y + 18, 12, 40), mark)
		draw_rect(Rect2(cx - 70 + i * 22, r.end.y - 58, 12, 40), mark)
	var dash_y := r.get_center().y
	var dx := r.position.x + 20
	while dx < r.end.x - 20:
		if absf(dx - cx) > 60:
			draw_rect(Rect2(dx, dash_y - 1, 14, 2), mark)
		dx += 28

	var crack := Color(Palette.RIFT, 0.25)
	var c := r.get_center()
	draw_polyline(PackedVector2Array([c + Vector2(-30, -6), c + Vector2(-10, 4), c + Vector2(4, -3), c + Vector2(22, 8), c + Vector2(36, 2)]), crack, 2.0)
	draw_polyline(PackedVector2Array([c + Vector2(4, -3), c + Vector2(8, -16), c + Vector2(18, -22)]), crack, 1.0)

	for p in spawn_points():
		draw_circle(p, 14, Color(Palette.RIFT, 0.08))
		draw_arc(p, 14, 0, TAU, 20, Color(Palette.RIFT, 0.3), 1.0)

	_draw_barrier(Rect2(r.position.x - 6, r.position.y - 6, r.size.x + 12, 6))
	_draw_barrier(Rect2(r.position.x - 6, r.end.y, r.size.x + 12, 6))
	_draw_barrier(Rect2(r.position.x - 6, r.position.y, 6, r.size.y))
	_draw_barrier(Rect2(r.end.x, r.position.y, 6, r.size.y))

	var font := Palette.heavy()
	draw_string(font, Vector2(r.position.x, r.end.y + 15), "ПЛОЩАДЬ РАЗЛОМА · СЕКТОР 7", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(Palette.CYAN, 0.45))
	draw_string(font, Vector2(r.end.x - 200, r.end.y + 15), "ОПАСНАЯ ЗОНА — ПРОХОД ЗАКРЫТ", HORIZONTAL_ALIGNMENT_RIGHT, 200, 8, Color(Palette.MAGENTA, 0.55))


func _draw_barrier(rect: Rect2) -> void:
	draw_rect(rect, Color(Palette.SAND, 0.18))
	var horizontal := rect.size.x > rect.size.y
	var length := rect.size.x if horizontal else rect.size.y
	var i := 0.0
	while i < length:
		var stripe := Rect2(rect.position + Vector2(i, 0), Vector2(8, rect.size.y)) if horizontal \
			else Rect2(rect.position + Vector2(0, i), Vector2(rect.size.x, 8))
		draw_rect(stripe.intersection(rect), Color(Palette.MAGENTA, 0.7))
		i += 16.0
