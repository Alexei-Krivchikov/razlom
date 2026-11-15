class_name BossData
extends EnemyData

@export var projectile: ProjectileData
@export var minion: EnemyData

@export_group("Texts")
@export var banner_title := ""
@export var banner_sub := ""
@export var hud_name := ""

@export_group("Phases")
@export var phase2_at := 0.5
@export var phase2_speed := 1.25
# Armour outside openings rewards reading the patterns over trading blows.
@export var armoured_mult := 0.6
@export var exposed_mult := 1.5

@export_group("Stalk")
# Fairness: the boss always walks this long between attacks, so a hit is never instantly followed.
@export var stalk_min := 50
@export var stalk_max := 110
# If the player keeps out of reach of the planned attack this long, fall back to the volley.
@export var stalk_give_up := 150

@export_group("Charge")
@export var charge_tell := 40
@export var charge_retell := 40
@export var aim_lock := 10
# 1120 crosses the 560 px arena in 30 frames.
@export var charge_speed := 1120.0
@export var charge_damage := 20
@export var charge_timeout := 90
@export var stun := 110

@export_group("Slam")
@export var slam_tell := 34
@export var slam_radius := 70.0
@export var slam_damage := 15
@export var slam_shove := 420.0
@export var slam_recover := 34

@export_group("Volley")
@export var volley_tell := 30
@export var volley_shots := 5
@export var volley_spread_deg := 50.0
@export var ring_shots := 10

@export_group("Roar")
@export var roar := 70
@export var roar_shove := 520.0

@export_group("Summon")
@export var summon_first := 240
@export var summon_cooldown := 720
@export var summon_cooldown_p2 := 480
@export var summon_count := 3
@export var summon_cap := 3
