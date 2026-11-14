extends CanvasLayer

signal restart_requested

@export var victory := false

var _t := 0
var _canvas: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Ui.full_rect_control(self)
	_canvas.draw.connect(_on_draw)
	hide()


func open() -> void:
	_t = 0
	show()


func _process(_delta: float) -> void:
	if not visible:
		return
	_t += 1
	_canvas.queue_redraw()
	if _t < 40:
		return
	if Input.is_action_just_pressed("menu_confirm"):
		restart_requested.emit()
	elif Input.is_action_just_pressed("menu_quit"):
		get_tree().quit()


func _on_draw() -> void:
	var c := _canvas
	c.draw_rect(Rect2(0, 0, 640, 360), Color(Palette.BG, 0.85 * Ui.ease_in(_t, 20)))
	var a := Ui.ease_in(_t - 8, 14)
	var accent := Palette.CYAN if victory else Palette.MAGENTA
	var title := "ПАСТЫРЬ ПАЛ" if victory else "ТЫ ПАЛ"
	var sub := "Разлом затягивается. Город переживёт эту ночь." if victory \
		else "Разлом поглотил площадь на волне %d." % GameState.wave
	Ui.plate(c, Rect2(-460 + 560 * a, 90, 440, 66), accent, 26)
	Ui.text(c, Vector2(-460 + 560 * a, 140), title, 44, Palette.BG, HORIZONTAL_ALIGNMENT_CENTER, 440)
	Ui.text(c, Vector2(0, 186), sub, 11, Palette.SAND, HORIZONTAL_ALIGNMENT_CENTER, 640)

	var secs := int(GameState.run_time)
	Ui.text(c, Vector2(0, 212), "Время забега  %d:%02d" % [secs / 60, secs % 60], 10, Color(Palette.SAND, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 640)
	var taken := PackedStringArray()
	for id in GameState.UPGRADES:
		var lvl := GameState.level(id)
		if lvl > 0:
			taken.append("%s ×%d" % [GameState.UPGRADES[id].title, lvl])
	if not taken.is_empty():
		Ui.text(c, Vector2(0, 230), " · ".join(taken), 9, Color(Palette.CYAN, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 640)

	if _t >= 40 and (_t / 30) % 2 == 0:
		Ui.text(c, Vector2(0, 292), "J / ENTER — ЕЩЁ РАЗ", 16, accent, HORIZONTAL_ALIGNMENT_CENTER, 640, 4)
	Ui.text(c, Vector2(0, 320), "Esc — выход", 9, Color(Palette.SAND, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 640)
