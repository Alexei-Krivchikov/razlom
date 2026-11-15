class_name UpgradeData
extends Resource

@export var id := ""
@export var title := ""
@export_multiline var description := ""
@export var max_level := 3

@export_group("Per level")
@export var damage_bonus := 0.0
@export var max_health_bonus := 0
@export var heal_on_pick := false
@export var dash_cooldown_factor := 1.0
@export var dash_invuln_bonus := 0
# The first level unlocks the shockwave on strong hits; each further level widens it by this share.
@export var shockwave := false
@export var shockwave_radius_bonus := 0.0
