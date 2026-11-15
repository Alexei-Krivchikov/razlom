extends EnemyView

@onready var boss := enemy as Boss


func _ready() -> void:
	super()
	boss.charge_impact.connect(_on_charge_impact)
	boss.slammed.connect(_on_slammed)
	boss.roared.connect(_on_roared)


func _on_charge_impact() -> void:
	Events.shake_requested.emit(6.0)
	Sfx.play("hit")
	Fx.burst(boss.get_parent(), boss.global_position + boss.charge_dir * boss.d.radius, Palette.SAND, 16, 180.0, 3.0)


func _on_slammed() -> void:
	Events.shake_requested.emit(6.0)
	Sfx.play("hit")
	Fx.burst(boss.get_parent(), boss.global_position, Palette.MAGENTA, 30, 240.0, 4.0)


func _on_roared() -> void:
	Events.shake_requested.emit(8.0)
	Fx.burst(boss.get_parent(), boss.global_position, Palette.CYAN, 40, 260.0, 4.0)


func _on_died() -> void:
	Fx.burst(boss.get_parent(), boss.global_position, Palette.CYAN, 50, 300.0, 5.0)
	super()


func _draw() -> void:
	var d := boss.d
	var r := d.radius
	var col := Palette.MAGENTA
	var timer := boss.timer
	match boss.s:
		Boss.S.CHARGE_TELL:
			var p := boss.tell_progress()
			var far := boss.charge_dir * 700.0
			draw_line(Vector2.ZERO, far, Color(Palette.MAGENTA, 0.15 + 0.35 * p), r * 2.0 * p)
			draw_line(Vector2.ZERO, far, Color(Palette.SAND, 0.6 * p), 1.0)
			draw_circle(Vector2.ZERO, r + 6 + 4 * p, Color(Palette.MAGENTA, 0.25 + 0.3 * p))
			if timer % 4 < 2:
				col = Palette.SAND
		Boss.S.CHARGE:
			draw_circle(-boss.charge_dir * 14.0, r, Color(Palette.MAGENTA, 0.3))
		Boss.S.SLAM_TELL:
			var p := boss.tell_progress()
			draw_circle(Vector2.ZERO, d.slam_radius, Color(Palette.MAGENTA, 0.08 + 0.17 * p))
			draw_arc(Vector2.ZERO, d.slam_radius, 0, TAU, 48, Color(Palette.MAGENTA, 0.5 + 0.5 * p), 2.0)
			draw_arc(Vector2.ZERO, d.slam_radius * p, 0, TAU, 48, Color(Palette.SAND, 0.8), 2.0)
			if timer < 8 and timer % 2 == 0:
				col = Palette.SAND
		Boss.S.SLAM_RECOVER:
			col = Palette.MAGENTA.darkened(0.35)
		Boss.S.VOLLEY_TELL:
			var p := boss.tell_progress()
			var pl := boss.player()
			if pl:
				for dir in boss.volley_dirs((pl.global_position - boss.global_position).normalized()):
					draw_line(Vector2.ZERO, dir * (40.0 + 60.0 * p), Color(Palette.MAGENTA, 0.5 * p), 1.0)
			draw_circle(Vector2.ZERO, 6.0 + 6.0 * p, Color(Palette.SAND, p))
		Boss.S.ROAR:
			var p := boss.tell_progress()
			draw_arc(Vector2.ZERO, r + 10 + 80 * p, 0, TAU, 40, Color(Palette.CYAN, 1.0 - p), 3.0)
			col = Palette.CYAN
		Boss.S.STUNNED:
			col = Palette.MAGENTA.darkened(0.55)
			draw_arc(Vector2.ZERO, r + 5, 0, TAU, 24, Color(Palette.CYAN, 0.6 + 0.4 * sin(timer * 0.5)), 2.0)
			var t := Time.get_ticks_msec() / 150.0
			for i in 3:
				var a := t + i * TAU / 3
				draw_circle(Vector2(cos(a) * 14, -r - 6 + sin(a) * 3), 2.0, Palette.CYAN)
	var hex := PackedVector2Array()
	var hex_in := PackedVector2Array()
	for i in 6:
		var a := i * TAU / 6 + PI / 6
		hex.append(Vector2.from_angle(a) * (r + 2))
		hex_in.append(Vector2.from_angle(a) * r)
	draw_colored_polygon(hex, Palette.BG)
	draw_colored_polygon(hex_in, body_color(col))
	var core := Palette.CYAN if boss.phase2 else Palette.BG
	draw_circle(Vector2.ZERO, 6.0, Palette.SAND if flash > 0 else core)
	draw_line(Vector2(-10, -4), Vector2(-3, 2), Palette.BG, 2.0)
	draw_line(Vector2(10, -4), Vector2(3, 2), Palette.BG, 2.0)
