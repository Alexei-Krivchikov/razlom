class_name RunData
extends Resource

@export var waves: Array[WaveData] = []
@export var boss: BossData
@export var upgrades: Array[UpgradeData] = []
@export var upgrade_choices := 3

@export_group("Spawning")
@export var first_spawn_delay := 50
@export var spawn_gap := 20
@export var spawn_jitter := 8.0
@export var rift_frames := 30
@export var boss_rift_frames := 90
@export var summon_radius := 46.0
# A wave of at least reinforce_min_size arrives in two pushes: the second waits until the first is
# nearly down (or reinforce_timeout frames pass), so pressure rises in a sawtooth instead of one
# flat brawl.
@export var reinforce_min_size := 6
@export var reinforce_alive := 1
@export var reinforce_timeout := 480
@export var reinforce_delay := 30

@export_group("Pacing")
@export var intermission := 120
@export var end_delay := 75
