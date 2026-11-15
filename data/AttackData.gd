class_name AttackData
extends Resource

@export var windup := 6
@export var active := 4
@export var recovery := 10
@export var damage := 10.0
# A strong hit breaks an enemy's windup, knocks back harder and triggers the shockwave upgrade.
@export var strong := false
# Frames after recovery during which the next attack still continues the combo; 0 ends the combo.
@export var chain_window := 20
@export var lunge := 12.0
@export_group("View")
@export var anim := "punch0"
# Clip frame where the arm is fully out; it is timed to land on the first active frame.
@export var anim_peak := 6
