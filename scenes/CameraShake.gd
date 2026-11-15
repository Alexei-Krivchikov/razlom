extends Camera2D

const SHAKE_FRAMES := 8

var _amp := 0.0
var _left := 0


func _ready() -> void:
	Events.shake_requested.connect(_on_shake)


func _on_shake(amplitude: float) -> void:
	_amp = maxf(_amp if _left > 0 else 0.0, amplitude)
	_left = SHAKE_FRAMES


func _physics_process(_delta: float) -> void:
	if _left <= 0:
		offset = Vector2.ZERO
		return
	var k := float(_left) / SHAKE_FRAMES
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * _amp * k
	_left -= 1
