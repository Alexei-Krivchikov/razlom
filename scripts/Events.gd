extends Node

signal enemy_died(enemy: Node2D)
signal wave_cleared(wave: int)
signal player_damaged(amount: int)
signal player_died
signal boss_died
signal shake_requested(amplitude: float)
signal summon_requested(origin: Vector2, enemy: EnemyData, count: int)
