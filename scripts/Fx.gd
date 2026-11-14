class_name Fx


static func sector(radius: float, dir: Vector2, half_angle: float, steps := 12) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	var base := dir.angle()
	for i in steps + 1:
		var a := base - half_angle + 2.0 * half_angle * i / steps
		pts.append(Vector2.from_angle(a) * radius)
	return pts


static func burst(parent: Node, pos: Vector2, color: Color, amount: int, speed: float, size := 3.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.6
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.2
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.angle_min = 0.0
	p.angle_max = 360.0
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)
