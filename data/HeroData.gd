class_name HeroData
extends Resource

@export var max_health := 100
@export var speed := 220.0
@export var radius := 8.0

@export_group("Attack")
@export var combo: Array[AttackData] = []
@export var attack_radius := 48.0
@export var attack_half_angle_deg := 50.0
# The lunge starts this many frames before the active frames so the step reads as part of the swing.
@export var lunge_lead := 2
# Combo hits may chain into the next hit this many frames into recovery; mashing skips the rest of it.
@export var chain_after := 3
@export var turn_frames := 4
@export var hitstop_light := 4
@export var hitstop_heavy := 8
@export var shockwave_radius := 96.0

@export_group("Dash")
@export var dash_distance := 180.0
# At 12 frames the hero covered ~30 px per frame and the sprite read as a teleport, not a dash.
@export var dash_frames := 18
@export var dash_invuln := 14
@export var dash_cooldown := 40

@export_group("Damage")
@export var hurt_invuln := 40
@export var hurt_hitstop := 5
@export var shove_frames := 12

@export_group("Input")
# Presses are remembered this long so input during hitstop or recovery isn't swallowed.
@export var input_buffer := 10
