extends CanvasLayer

signal chosen(id: String)

const CARD_SIZE := Vector2(170, 150)
const GAP := 18.0
# Ignores input for a moment so attack-mashing from the last fight doesn't pick a card blindly.
const INPUT_DELAY := 30

var options: Array = []
var selected := 0
var _t := 0
var _canvas: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Ui.full_rect_control(self)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_on_draw)
	_canvas.gui_input.connect(_on_gui_input)
	hide()


func open(ids: Array) -> void:
	options = ids
	selected = 0
	_t = 0
	show()


func accepting() -> bool:
	return visible and _t >= INPUT_DELAY


func choose(index: int) -> void:
	if not visible or index < 0 or index >= options.size():
		return
	hide()
	Sfx.play("upgrade")
	chosen.emit(options[index])


func _process(_delta: float) -> void:
	if not visible:
		return
	_t += 1
	_canvas.queue_redraw()
	if not accepting():
		return
	if Input.is_action_just_pressed("p1_left"):
		selected = wrapi(selected - 1, 0, options.size())
	elif Input.is_action_just_pressed("p1_right"):
		selected = wrapi(selected + 1, 0, options.size())
	elif Input.is_action_just_pressed("menu_confirm"):
		choose(selected)


func _unhandled_key_input(event: InputEvent) -> void:
	if not accepting() or not (event is InputEventKey) or not event.pressed:
		return
	var k: int = event.physical_keycode
	if k >= KEY_1 and k <= KEY_3:
		choose(k - KEY_1)


func _card_rect(i: int) -> Rect2:
	var total := options.size() * CARD_SIZE.x + (options.size() - 1) * GAP
	var x := 320.0 - total / 2 + i * (CARD_SIZE.x + GAP)
	var slide := (1.0 - Ui.ease_in(_t - i * 4, 14)) * 260.0
	var lift := -8.0 if i == selected else 0.0
	return Rect2(x, 120 + slide + lift, CARD_SIZE.x, CARD_SIZE.y)


func _on_gui_input(event: InputEvent) -> void:
	if not accepting():
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		for i in options.size():
			if _card_rect(i).has_point(event.position):
				selected = i
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					choose(i)


func _on_draw() -> void:
	var c := _canvas
	c.draw_rect(Rect2(0, 0, 640, 360), Color(Palette.BG, 0.82))
	var head := Ui.ease_in(_t, 10)
	Ui.plate(c, Rect2(-300 + 400 * head, 44, 420, 40), Palette.MAGENTA, 18)
	Ui.text(c, Vector2(-300 + 400 * head, 74), "ВЫБЕРИ УСИЛЕНИЕ", 24, Palette.BG, HORIZONTAL_ALIGNMENT_CENTER, 420)
	Ui.text(c, Vector2(0, 104), "Волна %d зачищена. Здоровье не восстанавливается." % GameState.wave, 10, Palette.SAND, HORIZONTAL_ALIGNMENT_CENTER, 640)

	for i in options.size():
		var id: String = options[i]
		var info: Dictionary = GameState.UPGRADES[id]
		var r := _card_rect(i)
		var sel := i == selected
		Ui.plate(c, r.grow(2), Palette.MAGENTA if sel else Color(Palette.SAND, 0.25), 14)
		Ui.plate(c, r, Palette.BG, 14)
		Ui.text(c, r.position + Vector2(14, 22), str(i + 1), 12, Palette.MAGENTA if sel else Color(Palette.SAND, 0.4))
		Ui.text(c, r.position + Vector2(0, 52), info.title, 14, Palette.CYAN if sel else Palette.SAND, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		Ui.lines(c, r.position + Vector2(0, 78), info.desc, 10, Color(Palette.SAND, 0.85), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var lvl := GameState.level(id)
		for j in GameState.MAX_STACK:
			var pip := Rect2(r.get_center().x - 26 + j * 20, r.end.y - 24, 12, 6)
			if j < lvl:
				c.draw_rect(pip, Palette.CYAN)
			elif j == lvl:
				c.draw_rect(pip, Palette.MAGENTA if sel else Color(Palette.MAGENTA, 0.5))
			else:
				c.draw_rect(pip, Color(Palette.SAND, 0.15))

	if accepting():
		Ui.text(c, Vector2(0, 340), "A / D — выбор    J / Enter — взять    1–3 — сразу", 10, Color(Palette.SAND, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 640)
