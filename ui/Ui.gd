class_name Ui


static func plate(ci: CanvasItem, rect: Rect2, color: Color, skew := 8.0) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(skew, 0),
		Vector2(rect.end.x, rect.position.y),
		rect.end - Vector2(skew, 0),
		Vector2(rect.position.x, rect.end.y),
	]), color)


static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0) -> void:
	var font := Palette.heavy()
	if outline > 0:
		ci.draw_string_outline(font, pos, s, align, width, size, outline, Palette.BG)
	ci.draw_string(font, pos, s, align, width, size, color)


static func lines(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, spacing := 1.25) -> void:
	var y := pos.y
	for line in s.split("\n"):
		text(ci, Vector2(pos.x, y), line, size, color, align, width)
		y += size * spacing


static func ease_in(frames_since: int, duration: int) -> float:
	var t := clampf(float(frames_since) / duration, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


static func full_rect_control(parent: Node) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c
