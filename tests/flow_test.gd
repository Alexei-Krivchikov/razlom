extends Node

# godot --headless --path . --fixed-fps 60 res://tests/FlowTest.tscn -- victory|defeat
# victory: the hero is kept alive and enemies are chipped down, so the run must reach the boss and win.
# defeat: the hero stands still, so the enemies must be able to kill him.

const MAX_FRAMES := 60 * 60 * 8

var mode := "victory"
var main: Node
var frames := 0
var upgrades_seen := 0
var damage_taken := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		mode = args[0]
	GameState.skip_title = true
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	Events.boss_died.connect(func(): _finish("victory"))
	Events.player_died.connect(func(): _finish("defeat"))
	Events.player_damaged.connect(func(a): damage_taken += a)


func _physics_process(_delta: float) -> void:
	frames += 1
	if frames > MAX_FRAMES:
		_fail("timeout at wave %d" % GameState.wave)
		return
	if mode != "victory":
		return
	main.player.health = main.player.max_health
	if frames % 6 == 0:
		Input.action_press("p1_attack")
	elif frames % 6 == 1:
		Input.action_release("p1_attack")
	if frames % 90 == 0:
		Input.action_press("p1_dash")
	elif frames % 90 == 1:
		Input.action_release("p1_dash")
	if frames % 20 == 0:
		for e in get_tree().get_nodes_in_group("enemies"):
			e.take_hit(25.0, Vector2.RIGHT, false)
	if main.upgrade_screen.accepting():
		upgrades_seen += 1
		main.upgrade_screen.choose(upgrades_seen % 3)


func _finish(result: String) -> void:
	print("RESULT %s | wave %d | upgrades %d %s | damage taken %d | %.1f s game time" % [
		result, GameState.wave, upgrades_seen, GameState.upgrades, damage_taken, frames / 60.0])
	if result != mode:
		_fail("expected %s" % mode)
		return
	if mode == "victory" and upgrades_seen != GameState.WAVES.size():
		_fail("expected %d upgrade picks" % GameState.WAVES.size())
		return
	print("PASS")
	get_tree().quit(0)


func _fail(msg: String) -> void:
	print("FAIL: " + msg)
	get_tree().quit(1)
