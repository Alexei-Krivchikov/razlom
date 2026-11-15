class_name ScriptedInput
extends PlayerInput

var move := Vector2.ZERO
var attack := false
var dash := false


func read() -> Command:
	var c := Command.new()
	c.move = move
	c.attack = attack
	c.dash = dash
	attack = false
	dash = false
	return c
