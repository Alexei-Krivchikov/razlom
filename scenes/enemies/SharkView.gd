extends EnemyView


func _draw() -> void:
	var shark := enemy as Shark
	var d := shark.d
	var reach := d.radius + d.hit_reach
	var col := Palette.MAGENTA
	match shark.s:
		Shark.S.WINDUP:
			var p := 1.0 - float(shark.timer) / d.windup
			draw_colored_polygon(Fx.sector(reach, shark.attack_dir, shark.hit_half_angle()), Color(Palette.MAGENTA, 0.12 + 0.18 * p))
			draw_arc(Vector2.ZERO, d.radius + 10 - 6 * p, 0, TAU, 20, Color(Palette.SAND, p), 2.0)
			if shark.timer < 8 and shark.timer % 2 == 0:
				col = Palette.SAND
		Shark.S.ACTIVE:
			draw_colored_polygon(Fx.sector(reach, shark.attack_dir, shark.hit_half_angle()), Color(Palette.MAGENTA, 0.7))
		Shark.S.RECOVER:
			col = Palette.MAGENTA.darkened(0.55)
	draw_circle(Vector2.ZERO, d.radius + 1, Palette.BG)
	draw_circle(Vector2.ZERO, d.radius, body_color(col))
	var look := shark.attack_dir if shark.s != Shark.S.CHASE else shark.velocity.normalized()
	draw_circle(look * 4 + look.orthogonal() * 3, 1.5, Palette.BG)
	draw_circle(look * 4 - look.orthogonal() * 3, 1.5, Palette.BG)
