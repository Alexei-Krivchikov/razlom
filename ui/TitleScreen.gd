extends CanvasLayer

signal start_requested
signal boss_requested

var _t := 0
var _canvas: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Ui.full_rect_control(self)
	_canvas.draw.connect(_on_draw)


func _process(_delta: float) -> void:
	if not visible:
		return
	_t += 1
	_canvas.queue_redraw()
	if _t < 15:
		return
	if Input.is_action_just_pressed("menu_confirm"):
		hide()
		start_requested.emit()
	elif Input.is_physical_key_pressed(KEY_B):
		hide()
		boss_requested.emit()
	elif Input.is_action_just_pressed("menu_quit"):
		get_tree().quit()


func _on_draw() -> void:
	var c := _canvas
	c.draw_rect(Rect2(0, 0, 640, 360), Color(Palette.BG, 0.88))
	var a := Ui.ease_in(_t, 14)
	var glitch := Vector2(randf_range(-2, 2), 0) if _t % 37 < 3 else Vector2.ZERO
	Ui.plate(c, Rect2(-400 + 500 * a, 70, 420, 76), Palette.MAGENTA, 28)
	Ui.text(c, Vector2(-400 + 500 * a, 128) + glitch + Vector2(2, 0), "РАЗЛОМ", 56, Palette.CYAN, HORIZONTAL_ALIGNMENT_CENTER, 420)
	Ui.text(c, Vector2(-400 + 500 * a, 128) + glitch, "РАЗЛОМ", 56, Palette.BG, HORIZONTAL_ALIGNMENT_CENTER, 420)
	Ui.plate(c, Rect2(740 - 500 * a, 142, 300, 18), Palette.CYAN, 10)
	Ui.text(c, Vector2(740 - 500 * a, 155), "ПЯТЬ ВОЛН · ОДИН ПАСТЫРЬ", 10, Palette.BG, HORIZONTAL_ALIGNMENT_CENTER, 300)

	Ui.lines(c, Vector2(0, 190),
		"Посреди города вскрылся разлом. Из него лезут твари.\nТы — последний, кто ещё стоит на площади.",
		11, Palette.SAND, HORIZONTAL_ALIGNMENT_CENTER, 640, 1.5)

	Ui.lines(c, Vector2(0, 244),
		"WASD / стрелки — движение\nJ / Z — удар (серия из трёх)\nK / X — рывок, неуязвим в начале",
		10, Color(Palette.SAND, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 640, 1.5)

	if (_t / 30) % 2 == 0:
		Ui.text(c, Vector2(0, 318), "J / ENTER — В БОЙ", 16, Palette.MAGENTA, HORIZONTAL_ALIGNMENT_CENTER, 640, 4)
	Ui.text(c, Vector2(0, 346), "B — сразу к Пастырю (тренировка)    Esc — выход", 9, Color(Palette.SAND, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 640)
