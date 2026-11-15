extends CanvasLayer

const BANNER_FRAMES := 100

var player: Player
var boss: Boss

var _canvas: Control
var _banner := ""
var _banner_sub := ""
var _banner_t := BANNER_FRAMES
var _shown_health := 100.0
var _damage_flash := 0


func _ready() -> void:
	layer = 10
	_canvas = Ui.full_rect_control(self)
	_canvas.draw.connect(_on_draw)
	Events.player_damaged.connect(func(_a): _damage_flash = 12)


func show_banner(title: String, sub := "") -> void:
	_banner = title
	_banner_sub = sub
	_banner_t = 0


func _process(_delta: float) -> void:
	_banner_t = mini(_banner_t + 1, BANNER_FRAMES)
	_damage_flash = maxi(_damage_flash - 1, 0)
	if player:
		_shown_health = move_toward(_shown_health, player.health, 0.6)
	_canvas.queue_redraw()


func _on_draw() -> void:
	var c := _canvas
	if player:
		var w := 150.0
		var ratio := float(player.health) / player.max_health
		var lag := _shown_health / player.max_health
		Ui.plate(c, Rect2(8, 8, w + 26, 26), Color(Palette.BG, 0.9))
		Ui.text(c, Vector2(18, 20), "БОЕЦ", 9, Palette.SAND)
		Ui.text(c, Vector2(w + 18 - 80, 20), "%d/%d" % [player.health, player.max_health], 9, Palette.SAND, HORIZONTAL_ALIGNMENT_RIGHT, 80)
		var bar := Rect2(18, 23, w, 6)
		c.draw_rect(bar, Color(Palette.SAND, 0.1))
		c.draw_rect(Rect2(bar.position, Vector2(w * lag, bar.size.y)), Palette.SAND)
		var col := Palette.SAND if _damage_flash > 0 and _damage_flash % 4 < 2 else Palette.CYAN
		c.draw_rect(Rect2(bar.position, Vector2(w * ratio, bar.size.y)), col)
		if player.dash_cooldown > 0:
			var k := float(player.dash_cooldown) / player.dash_cooldown_total
			c.draw_rect(Rect2(bar.position + Vector2(0, 8), Vector2(w * 0.3 * (1.0 - k), 2)), Color(Palette.CYAN, 0.5))
		else:
			c.draw_rect(Rect2(bar.position + Vector2(0, 8), Vector2(w * 0.3, 2)), Palette.CYAN)

	if GameState.wave > 0:
		var waves := GameState.run.waves.size()
		var label := "ВОЛНА %d/%d" % [GameState.wave, waves] if GameState.wave <= waves else "ФИНАЛ"
		Ui.plate(c, Rect2(632 - 120, 8, 120, 22), Palette.MAGENTA)
		Ui.text(c, Vector2(632 - 120, 24), label, 13, Palette.BG, HORIZONTAL_ALIGNMENT_CENTER, 120)

	if is_instance_valid(boss) and boss.health > 0:
		var bw := 240.0
		var x := 320.0 - bw / 2
		Ui.text(c, Vector2(x, 12 + 8), boss.d.hud_name, 10, Palette.MAGENTA, HORIZONTAL_ALIGNMENT_CENTER, bw, 3)
		c.draw_rect(Rect2(x, 24, bw, 5), Color(Palette.SAND, 0.12))
		c.draw_rect(Rect2(x, 24, bw * boss.health / boss.d.max_health, 5), Palette.MAGENTA)
		c.draw_rect(Rect2(x + bw * 0.5, 23, 1, 7), Palette.SAND)

	if _banner_t < BANNER_FRAMES:
		var t_in := Ui.ease_in(_banner_t, 10)
		var t_out := Ui.ease_in(_banner_t - (BANNER_FRAMES - 12), 12)
		var offset := (1.0 - t_in) * -700.0 + t_out * 700.0
		var y := 150.0
		Ui.plate(c, Rect2(offset + 120, y, 400, 46), Palette.MAGENTA, 20)
		Ui.plate(c, Rect2(-offset * 0.6 + 150, y + 42, 340, 18), Palette.CYAN, 10)
		Ui.text(c, Vector2(offset + 120, y + 36), _banner, 30, Palette.BG, HORIZONTAL_ALIGNMENT_CENTER, 400)
		Ui.text(c, Vector2(-offset * 0.6 + 150, y + 56), _banner_sub, 10, Palette.BG, HORIZONTAL_ALIGNMENT_CENTER, 340)
