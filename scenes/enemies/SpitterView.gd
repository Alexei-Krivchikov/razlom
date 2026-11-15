extends EnemyView


func _draw() -> void:
	var spitter := enemy as Spitter
	var r := spitter.d.radius
	var aim := spitter.aim
	if spitter.windup > 0:
		var p := 1.0 - float(spitter.windup) / spitter.d.windup
		draw_line(Vector2.ZERO, aim * 40.0, Color(Palette.MAGENTA, 0.5 * p), 1.0)
		draw_circle(aim * (r + 2), 2.0 + 3.0 * p, Color(Palette.SAND, p))
	var pts := PackedVector2Array()
	for i in 4:
		pts.append(Vector2.from_angle(aim.angle() + i * TAU / 4) * (r + 2))
	draw_colored_polygon(pts, Palette.BG)
	pts.clear()
	for i in 4:
		pts.append(Vector2.from_angle(aim.angle() + i * TAU / 4) * r)
	draw_colored_polygon(pts, body_color(Palette.MAGENTA))
	draw_circle(Vector2.ZERO, 3.0, Palette.CYAN if flash == 0 else Palette.SAND)
