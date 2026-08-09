extends Node2D

@export var base_maze_width: int = 17
@export var base_maze_height: int = 13
@export var base_seed: int = 42
@export var auto_generate_on_start: bool = true

@onready var floor_layer: TileMapLayer = $FloorLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var player: CharacterBody2D = $Player
@onready var exit_area: Area2D = $ExitArea
@onready var exit_sprite: Sprite2D = $ExitArea/Sprite2D
@onready var victory_ui: CanvasLayer = $VictoryUI
@onready var hud_ui: CanvasLayer = $HUD
@onready var shop_ui: CanvasLayer = $ShopUI
@onready var glitch_ui: CanvasLayer = $GlitchUI
@onready var win_particles: CPUParticles2D = $WinParticles

var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
var samurai_scene: PackedScene = preload("res://scenes/samurai_enemy.tscn")
var boss_scene: PackedScene = preload("res://scenes/boss_enemy.tscn")
var coin_scene: PackedScene = preload("res://scenes/coin.tscn")
var powerup_scene: PackedScene = preload("res://scenes/powerup.tscn")
var spike_trap_scene: PackedScene = preload("res://scenes/spike_trap.tscn")
var key_scene: PackedScene = preload("res://scenes/key.tscn")

var spawned_enemies: Array = []
var spawned_coins: Array = []
var spawned_powerups: Array = []
var spawned_traps: Array = []
var spawned_key: Node2D = null

var current_level: int = 1
var current_seed: int = 42
var grid: Array = []
var is_game_active: bool = false
var is_exit_unlocked: bool = false
var elapsed_time: float = 0.0
var total_score: int = 0
var time_freeze_timer: float = 0.0

func _ready() -> void:
	add_to_group("maze")
	if player.has_signal("step_taken"):
		player.step_taken.connect(_on_player_step_taken)
	if player.has_signal("dash_cooldown_updated"):
		player.dash_cooldown_updated.connect(hud_ui.update_dash_cooldown)
	if player.has_signal("powerup_status_updated"):
		player.powerup_status_updated.connect(hud_ui.update_powerup_status)
	if player.has_signal("key_status_changed"):
		player.key_status_changed.connect(hud_ui.update_key_status)
	
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		var dims = gs.get_maze_dimensions()
		base_maze_width = dims.x
		base_maze_height = dims.y
		if gs.is_resuming:
			current_level = gs.resume_level
			total_score = gs.resume_score
			gs.is_resuming = false
		
	current_seed = base_seed
	if auto_generate_on_start:
		generate_level(current_level)

func trigger_time_freeze(duration: float) -> void:
	time_freeze_timer = duration
	for enemy in spawned_enemies:
		if is_instance_valid(enemy) and enemy.has_method("stun"):
			enemy.stun(duration)

func unlock_exit_portal() -> void:
	is_exit_unlocked = true
	if exit_sprite:
		var tween = create_tween()
		tween.tween_property(exit_sprite, "modulate", Color(2.0, 1.5, 0.4, 1.0), 0.2)
		tween.tween_property(exit_sprite, "modulate", Color(1.0, 0.85, 0.2, 0.95), 0.2)
	if win_particles:
		win_particles.emitting = true
		get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(win_particles) and not victory_ui.panel.visible:
				win_particles.emitting = false
		)

func _process(delta: float) -> void:
	if time_freeze_timer > 0.0:
		time_freeze_timer = max(0.0, time_freeze_timer - delta)
		if hud_ui:
			hud_ui.update_powerup_status("FREEZE", time_freeze_timer)

	if is_game_active:
		elapsed_time += delta
		hud_ui.update_timer(elapsed_time)

func _on_player_step_taken() -> void:
	hud_ui.update_steps(player.steps_count)

func _on_coin_collected(amount: int) -> void:
	total_score += amount
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.total_coins += amount
	hud_ui.update_score(total_score)

func generate_level(level_num: int) -> void:
	get_tree().paused = false
	current_level = level_num
	
	var w = base_maze_width + (level_num - 1) * 2
	var h = base_maze_height + (level_num - 1) * 2
	
	w = min(w, 39)
	h = min(h, 27)
	
	if w % 2 == 0: w += 1
	if h % 2 == 0: h += 1
	
	current_seed = base_seed + (level_num - 1) * 1337
	_build_maze(w, h, current_seed)
	_setup_camera(w, h)
	_spawn_enemies_for_level(w, h, current_seed)
	_spawn_coins_for_level(w, h, current_seed)
	_spawn_powerups_for_level(w, h, current_seed)
	_spawn_traps_for_level(w, h, current_seed)
	_spawn_key_for_level(w, h, current_seed)
	
	elapsed_time = 0.0
	time_freeze_timer = 0.0
	is_game_active = true
	is_exit_unlocked = false
	if exit_sprite:
		exit_sprite.modulate = Color(0.4, 0.2, 0.4, 0.6)
		
	player.reset_stats()
	player.is_active = true
	victory_ui.hide_victory()
	hud_ui.update_level(current_level)
	hud_ui.update_steps(0)
	hud_ui.update_timer(0.0)
	hud_ui.update_score(total_score)
	hud_ui.update_dash_cooldown(0.0, 1.5)
	hud_ui.update_key_status(false)

func _build_maze(w: int, h: int, seed_val: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	grid = []
	for x in range(w):
		var column = []
		for y in range(h):
			column.append(1)
		grid.append(column)

	var stack = []
	var start_x = 1
	var start_y = 1
	grid[start_x][start_y] = 0
	stack.append(Vector2i(start_x, start_y))

	var directions = [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]

	while stack.size() > 0:
		var current = stack[stack.size() - 1]
		var neighbors = []

		for d in directions:
			var nx = current.x + d.x
			var ny = current.y + d.y
			if nx > 0 and nx < w - 1 and ny > 0 and ny < h - 1:
				if grid[nx][ny] == 1:
					neighbors.append(d)

		if neighbors.size() > 0:
			var chosen_dir = neighbors[rng.randi() % neighbors.size()]
			var wall_x = current.x + chosen_dir.x / 2
			var wall_y = current.y + chosen_dir.y / 2
			var next_x = current.x + chosen_dir.x
			var next_y = current.y + chosen_dir.y

			grid[wall_x][wall_y] = 0
			grid[next_x][next_y] = 0
			stack.append(Vector2i(next_x, next_y))
		else:
			stack.pop_back()

	grid[0][1] = 0
	grid[w - 1][h - 2] = 0

	floor_layer.clear()
	wall_layer.clear()

	for x in range(w):
		for y in range(h):
			floor_layer.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))
			if grid[x][y] == 1:
				wall_layer.set_cell(Vector2i(x, y), 0, Vector2i(1, 15))

	var start_pos = Vector2(0 * 16 + 8, 1 * 16 + 8)
	player.global_position = start_pos

	var exit_pos = Vector2((w - 1) * 16 + 8, (h - 2) * 16 + 8)
	exit_area.global_position = exit_pos
	win_particles.global_position = exit_pos

func _spawn_enemies_for_level(w: int, h: int, seed_val: int) -> void:
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()

	var candidate_cells: Array[Vector2i] = []
	for x in range(4, w - 1):
		for y in range(1, h - 1):
			if grid[x][y] == 0:
				candidate_cells.append(Vector2i(x, y))

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val + 777
	candidate_cells.shuffle()

	# Check for Level 5 Boss Encounter
	if current_level % 5 == 0:
		if candidate_cells.size() > 0:
			var boss_cell = candidate_cells[0]
			var boss_inst = boss_scene.instantiate()
			boss_inst.global_position = Vector2(boss_cell.x * 16 + 8, boss_cell.y * 16 + 8)
			boss_inst.player_caught.connect(_on_player_caught)
			boss_inst.boss_defeated.connect(func():
				_on_coin_collected(1000)
				unlock_exit_portal()
			)
			add_child(boss_inst)
			spawned_enemies.append(boss_inst)
		return

	# Regular Enemies & Samurai Tanks
	var enemy_count = 1
	if w >= 33:
		enemy_count = 4
	elif w >= 25:
		enemy_count = 2

	for i in range(min(enemy_count, candidate_cells.size())):
		var cell = candidate_cells[i]
		var sc = samurai_scene if (current_level >= 3 and i % 2 == 1) else enemy_scene
		var enemy_instance = sc.instantiate()
		enemy_instance.global_position = Vector2(cell.x * 16 + 8, cell.y * 16 + 8)
		enemy_instance.player_caught.connect(_on_player_caught)
		add_child(enemy_instance)
		spawned_enemies.append(enemy_instance)

func _spawn_coins_for_level(w: int, h: int, seed_val: int) -> void:
	for coin in spawned_coins:
		if is_instance_valid(coin):
			coin.queue_free()
	spawned_coins.clear()

	var coin_count = clamp(int(w * h * 0.05), 8, 25)

	var candidate_cells: Array[Vector2i] = []
	for x in range(2, w - 1):
		for y in range(1, h - 1):
			if grid[x][y] == 0:
				candidate_cells.append(Vector2i(x, y))

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val + 1234
	candidate_cells.shuffle()

	for i in range(min(coin_count, candidate_cells.size())):
		var cell = candidate_cells[i]
		var coin_instance = coin_scene.instantiate()
		coin_instance.global_position = Vector2(cell.x * 16 + 8, cell.y * 16 + 8)
		coin_instance.collected.connect(_on_coin_collected)
		add_child(coin_instance)
		spawned_coins.append(coin_instance)

func _spawn_powerups_for_level(w: int, h: int, seed_val: int) -> void:
	for pup in spawned_powerups:
		if is_instance_valid(pup):
			pup.queue_free()
	spawned_powerups.clear()

	var pup_count = clamp(int(w * 0.1), 1, 3)
	var candidate_cells: Array[Vector2i] = []
	for x in range(3, w - 2):
		for y in range(2, h - 2):
			if grid[x][y] == 0:
				candidate_cells.append(Vector2i(x, y))

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val + 555
	candidate_cells.shuffle()

	var p_types = [0, 1, 2] # SPEED_BOOTS, COIN_MAGNET, TIME_FREEZE

	for i in range(min(pup_count, candidate_cells.size())):
		var cell = candidate_cells[i]
		var pup_instance = powerup_scene.instantiate()
		pup_instance.powerup_type = p_types[i % p_types.size()]
		pup_instance.global_position = Vector2(cell.x * 16 + 8, cell.y * 16 + 8)
		add_child(pup_instance)
		spawned_powerups.append(pup_instance)

func _spawn_traps_for_level(w: int, h: int, seed_val: int) -> void:
	for trap in spawned_traps:
		if is_instance_valid(trap):
			trap.queue_free()
	spawned_traps.clear()

	if current_level < 2:
		return

	var trap_count = clamp(current_level - 1, 1, 4)
	var candidate_cells: Array[Vector2i] = []
	for x in range(4, w - 3):
		for y in range(2, h - 2):
			if grid[x][y] == 0:
				candidate_cells.append(Vector2i(x, y))

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val + 999
	candidate_cells.shuffle()

	for i in range(min(trap_count, candidate_cells.size())):
		var cell = candidate_cells[i]
		var trap_instance = spike_trap_scene.instantiate()
		trap_instance.global_position = Vector2(cell.x * 16 + 8, cell.y * 16 + 8)
		add_child(trap_instance)
		spawned_traps.append(trap_instance)

func _spawn_key_for_level(w: int, h: int, seed_val: int) -> void:
	if is_instance_valid(spawned_key):
		spawned_key.queue_free()
		spawned_key = null

	var candidate_cells: Array[Vector2i] = []
	for x in range(w / 2, w - 2):
		for y in range(1, h - 2):
			if grid[x][y] == 0 and not (x == w - 1 and y == h - 2):
				candidate_cells.append(Vector2i(x, y))

	if candidate_cells.size() > 0:
		var rng = RandomNumberGenerator.new()
		rng.seed = seed_val + 4321
		var chosen_cell = candidate_cells[rng.randi() % candidate_cells.size()]
		var key_inst = key_scene.instantiate()
		key_inst.global_position = Vector2(chosen_cell.x * 16 + 8, chosen_cell.y * 16 + 8)
		add_child(key_inst)
		spawned_key = key_inst

func _setup_camera(w: int, h: int) -> void:
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera:
		camera.zoom = Vector2(4.5, 4.5)
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = int(w * 16.0)
		camera.limit_bottom = int(h * 16.0)

func _on_player_caught() -> void:
	if not is_game_active:
		return
		
	if player and player.has_method("try_extra_life_rescue") and player.try_extra_life_rescue():
		return

	is_game_active = false
	player.is_active = false
	
	if glitch_ui and glitch_ui.has_method("trigger_glitch"):
		glitch_ui.trigger_glitch(func():
			var start_pos = Vector2(0 * 16 + 8, 1 * 16 + 8)
			player.global_position = start_pos
			player.is_active = true
			is_game_active = true
			_spawn_enemies_for_level(grid.size(), grid[0].size(), current_seed)
		)
	else:
		var start_pos = Vector2(0 * 16 + 8, 1 * 16 + 8)
		player.global_position = start_pos
		player.is_active = true
		is_game_active = true

func _on_exit_area_body_entered(body: Node2D) -> void:
	if body == player and is_game_active:
		if not is_exit_unlocked and not player.has_key:
			if exit_sprite:
				var tween = create_tween()
				tween.tween_property(exit_sprite, "modulate", Color(1.0, 0.2, 0.2, 0.9), 0.1)
				tween.tween_property(exit_sprite, "modulate", Color(0.4, 0.2, 0.4, 0.6), 0.15)
			return

		is_game_active = false
		player.is_active = false
		win_particles.emitting = true
		
		var gs = get_node_or_null("/root/GameSettings")
		if gs:
			gs.save_game(current_level + 1, total_score)
			
		victory_ui.show_victory(current_level, elapsed_time, player.steps_count, total_score)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		generate_level(current_level)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_N:
		generate_level(current_level + 1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if shop_ui and shop_ui.has_method("toggle_shop"):
			shop_ui.toggle_shop()
