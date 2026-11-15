class_name SharkData
extends EnemyData

@export var stop_dist := 40.0
@export var windup := 24
@export var active := 6
@export var recover := 30
# Light hits flinch the shark only before it commits to a swing; once the windup starts, only a
# strong hit breaks it. Mashing can't erase every attack, the player has to read and dash.
@export var stagger := 16
@export var stagger_strong := 30
# Each shark closes in from its own side, so a crowd can't be lined up in one swing arc.
@export var flank_dist := 34.0
@export var damage := 10
@export var hit_reach := 30.0
@export var hit_half_angle_deg := 60.0
