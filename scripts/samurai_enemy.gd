extends CharacterBody2D

signal player_caught

enum State { PATROL, CHASE, DEFEATED }

@export var max_hp: int = 3
@export var patrol_speed: float = 38.0
@export var chase_speed: float = 58.0
@export var detection_range: float = 170.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $HitBox
@onready var hp_label: Label = $HPLabel

var current_hp: int = 3
var current_state: State = State.PATROL
var current_dir: Vector2 = Vector2.RIGHT
var player_ref: Node2D = null
var last_seen_pos: Vector2 = Vector2.ZERO
var is_defeated: bool = false
var is_stunned: bool = false
var stun_timer: float = 0.0

func _ready() -> void:
	current_hp = max_hp
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_pick_random_direction()
	_update_hp_display()

func _update_hp_display() -> void:
	if hp_label:
		var pips = ""
		for i in range(current_hp):
			pips += "█"
		hp_label.text = pips
		hp_label.modulate = Color(1.0, 0.3, 0.3) if current_hp == 1 else Color(1.0, 0.8, 0.2)

func stun(duration: float = 1.5, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_defeated:
		return
	is_stunned = true
	stun_timer = duration
	current_state = State.PATROL
	if knockback_dir != Vector2.ZERO:
		global_position += knockback_dir * 14.0
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.3, 0.9, 1.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.1)
	tween.tween_property(sprite, "modulate", Color(0.3, 0.9, 1.0, 1.0), 0.1)

func defeat() -> void:
	if is_defeated:
		return
		
	current_hp -= 1
	_update_hp_display()
	
	if current_hp > 0:
		# Hit flash tween
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.08)
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
		return
		
	is_defeated = true
	current_state = State.DEFEATED
	set_physics_process(false)
	
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
		
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 0.2, 0.2, 1.0), 0.08)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.04), 0.12)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if is_defeated:
		return

	if is_stunned:
		stun_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		if stun_timer <= 0.0:
			is_stunned = false
			sprite.modulate = Color(1.0, 1.0, 1.0)
		return

	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			player_ref = get_parent().get_node_or_null("Player")

	_check_line_of_sight()

	var move_speed = patrol_speed
	if current_state == State.CHASE:
		move_speed = chase_speed

	velocity = current_dir * move_speed
	var prev_pos = global_position
	move_and_slide()

	if global_position.distance_to(prev_pos) < 0.2 * move_speed * delta or is_on_wall():
		if current_state == State.CHASE:
			current_state = State.PATROL
		_pick_new_direction()

	_update_visuals()

func _check_line_of_sight() -> void:
	if is_defeated or is_stunned or not player_ref or not is_instance_valid(player_ref):
		return

	var to_player = player_ref.global_position - global_position
	var dist = to_player.length()

	if dist > detection_range:
		if current_state == State.CHASE:
			current_state = State.PATROL
		return

	var in_h_corridor = abs(to_player.y) < 12.0
	var in_v_corridor = abs(to_player.x) < 12.0

	if in_h_corridor or in_v_corridor:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, player_ref.global_position)
		query.exclude = [self, hitbox]
		query.collision_mask = 1
		
		var result = space_state.intersect_ray(query)
		if result.is_empty():
			current_state = State.CHASE
			last_seen_pos = player_ref.global_position
			if in_h_corridor:
				current_dir = Vector2.RIGHT if to_player.x > 0 else Vector2.LEFT
			else:
				current_dir = Vector2.DOWN if to_player.y > 0 else Vector2.UP
			return

	if current_state == State.CHASE:
		if global_position.distance_to(last_seen_pos) < 12.0:
			current_state = State.PATROL

func _pick_random_direction() -> void:
	var dirs = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	dirs.shuffle()
	current_dir = dirs[0]

func _pick_new_direction() -> void:
	var dirs = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	dirs.shuffle()
	
	for d in dirs:
		if d != -current_dir and not test_move(global_transform, d * 4.0):
			current_dir = d
			return
			
	current_dir = -current_dir

func _update_visuals() -> void:
	if sprite and not is_defeated and not is_stunned:
		if current_state == State.CHASE:
			sprite.modulate = Color(1.0, 0.4, 0.2)
			sprite.speed_scale = 1.3
		else:
			sprite.modulate = Color(1.0, 1.0, 1.0)
			sprite.speed_scale = 1.0

		if current_dir.x < 0:
			sprite.flip_h = true
		elif current_dir.x > 0:
			sprite.flip_h = false

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_defeated or is_stunned:
		return
	if body == player_ref or body.name == "Player" or body.has_signal("step_taken"):
		if body.has_method("is_invincible_now") and body.is_invincible_now():
			return
		if body.has_method("is_shielding_now") and body.is_shielding_now():
			var knockback = (global_position - body.global_position).normalized()
			stun(1.5, knockback)
			return
			
		player_caught.emit()
