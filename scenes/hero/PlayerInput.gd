class_name PlayerInput
extends RefCounted


class Command:
	var move := Vector2.ZERO
	var attack := false
	var dash := false


var _actions := {}


func _init(player_index := 1) -> void:
	for a in ["up", "down", "left", "right", "attack", "dash"]:
		_actions[a] = "p%d_%s" % [player_index, a]


func read() -> Command:
	var c := Command.new()
	c.move = Input.get_vector(_actions.left, _actions.right, _actions.up, _actions.down)
	c.attack = Input.is_action_just_pressed(_actions.attack)
	c.dash = Input.is_action_just_pressed(_actions.dash)
	return c
