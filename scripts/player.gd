extends CharacterBody2D

signal step_taken
signal dash_cooldown_updated(current: float, max_val: float)
signal powerup_status_updated(type_name: String, remaining: float)
signal key_status_changed(has_key: bool)

@export var speed: float = 100.0
@export var acceleration: float = 1600.0
@export var friction: float = 1800.0
@export var corner_nudge_distance: float = 4.0
@export var corner_nudge_speed: float = 50.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D

var camera: Camera2D = null
var camera_shake_intensity: float = 0.0
var camera_shake_timer: float = 0.0

var total_distance: float = 0.0
var steps_count: int = 0
var input_vector: Vector2 = Vector2.ZERO
var is_active: bool = true
var is_attacking: bool = false
var combo_index: int = 1
var combo_reset_timer: float = 0.0

# Ability Variables
var is_shielding: bool = false
var is_dashing: bool = false
var is_invincible: bool = false
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var ghost_trail_timer: float = 0.0
const DASH_DURATION: float = 0.35
const DASH_COOLDOWN_TIME: float = 1.5
const DASH_SPEED_MULTIPLIER: float = 2.5

# Power-Up & Key Variables
var speed_boost_timer: float = 0.0
var magnet_timer: float = 0.0
var has_key: bool = false

func _ready() -> void:
	camera = get_node_or_null("Camera2D")
	apply_character_settings()
	if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

func trigger_camera_shake(intensity: float = 4.0, duration: float = 0.2) -> void:
	camera_shake_intensity = intensity
	camera_shake_timer = duration

func apply_character_settings() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if not gs:
		return
	
	speed = gs.get_character_speed()
	var attack_scale = gs.get_character_attack_scale()
	if attack_area:
		attack_area.scale = Vector2(attack_scale, attack_scale)
		
	var folder = gs.get_character_folder()
	var new_frames = SpriteFrames.new()
	
	_add_anim_from_sheet(new_frames, "idle", folder + "Idle.png", 8.0, true)
	_add_anim_from_sheet(new_frames, "run", folder + "Run.png", 12.0, true)
	_add_anim_from_sheet(new_frames, "attack1", folder + "Attack_1.png", 12.0, false)
	_add_anim_from_sheet(new_frames, "attack2", folder + "Attack_2.png", 12.0, false)
	_add_anim_from_sheet(new_frames, "attack3", folder + "Attack_3.png", 12.0, false)
	_add_anim_from_sheet(new_frames, "shield", folder + "Shield.png", 8.0, true)
	_add_anim_from_sheet(new_frames, "dash", folder + "Jump.png", 14.0, false)
	
	if sprite:
		sprite.sprite_frames = new_frames
		sprite.play("idle")

func try_extra_life_rescue() -> bool:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.relic_extra_life and not gs.has_extra_life_used:
		gs.has_extra_life_used = true
		is_invincible = true
		trigger_camera_shake(8.0, 0.4)
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(0.4, 2.0, 0.6, 1.0), 0.15)
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
		get_tree().create_timer(1.5).timeout.connect(func():
			is_invincible = false
		)
		return true
	return false

func _add_anim_from_sheet(sf: SpriteFrames, anim_name: String, path: String, fps: float, loop: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var tex = load(path) as Texture2D
	if not tex:
		return
		
	var frame_h = tex.get_height()
	if frame_h <= 0:
		return
	var frame_w = frame_h
	var frame_count = int(tex.get_width() / frame_h)
	if frame_count <= 0:
		return

	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	
	for i in range(frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		sf.add_frame(anim_name, atlas)

func collect_key() -> void:
	has_key = true
	trigger_camera_shake(5.0, 0.3)
	key_status_changed.emit(true)
	var maze_node = get_tree().get_first_node_in_group("maze")
	if not maze_node:
		maze_node = get_parent()
	if maze_node and maze_node.has_method("unlock_exit_portal"):
		maze_node.unlock_exit_portal()

func apply_powerup(type_name: String, duration: float) -> void:
	trigger_camera_shake(3.0, 0.15)
	if type_name == "SPEED":
		speed_boost_timer = duration
		powerup_status_updated.emit("SPEED", duration)
	elif type_name == "MAGNET":
		magnet_timer = duration
		powerup_status_updated.emit("MAGNET", duration)
	elif type_name == "FREEZE":
		var maze_node = get_tree().get_first_node_in_group("maze")
		if not maze_node:
			maze_node = get_parent()
		if maze_node and maze_node.has_method("trigger_time_freeze"):
			maze_node.trigger_time_freeze(duration)

func is_invincible_now() -> bool:
	return is_dashing or is_invincible

func is_shielding_now() -> bool:
	return is_shielding and not is_dashing and not is_attacking

func _process(delta: float) -> void:
	if camera_shake_timer > 0.0:
		camera_shake_timer -= delta
		if camera:
			camera.offset = Vector2(
				randf_range(-camera_shake_intensity, camera_shake_intensity),
				randf_range(-camera_shake_intensity, camera_shake_intensity)
			)
		if camera_shake_timer <= 0.0 and camera:
			camera.offset = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_index = 1

	if dash_cooldown > 0.0:
		dash_cooldown = max(0.0, dash_cooldown - delta)
		dash_cooldown_updated.emit(dash_cooldown, DASH_COOLDOWN_TIME)

	# Power-up Timers
	if speed_boost_timer > 0.0:
		speed_boost_timer = max(0.0, speed_boost_timer - delta)
		powerup_status_updated.emit("SPEED", speed_boost_timer)

	if magnet_timer > 0.0:
		magnet_timer = max(0.0, magnet_timer - delta)
		powerup_status_updated.emit("MAGNET", magnet_timer)

	if not is_active:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		_update_visuals()
		return

	# Dash Execution with Ghost Trail
	if is_dashing:
		dash_timer -= delta
		ghost_trail_timer -= delta
		if ghost_trail_timer <= 0.0:
			ghost_trail_timer = 0.05
			_spawn_ghost_trail()
			
		var dash_spd_boost = 1.4 if speed_boost_timer > 0.0 else 1.0
		velocity = dash_direction * (speed * DASH_SPEED_MULTIPLIER * dash_spd_boost)
		if dash_timer <= 0.0:
			is_dashing = false
			is_invincible = false
		move_and_slide()
		_update_visuals()
		return

	# Trigger Shadow Dash (E key)
	if Input.is_key_pressed(KEY_E) and dash_cooldown <= 0.0 and not is_attacking:
		_trigger_dash()
		return

	# Trigger Attack
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_perform_attack()
		return

	# Shield Stance (Shift / Right Click / K)
	is_shielding = (Input.is_key_pressed(KEY_SHIFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_K)) and not is_attacking

	if not is_attacking:
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		
		var spd_multiplier = (0.5 if is_shielding else 1.0) * (1.4 if speed_boost_timer > 0.0 else 1.0)
		var effective_speed = speed * spd_multiplier
		
		if input_vector != Vector2.ZERO:
			var target_velocity = input_vector.normalized() * effective_speed
			
			if is_equal_approx(abs(input_vector.x), 1.0) and input_vector.y == 0.0:
				var nudge = _get_corner_nudge(input_vector, Vector2.UP, Vector2.DOWN)
				target_velocity.y += nudge * corner_nudge_speed
			elif is_equal_approx(abs(input_vector.y), 1.0) and input_vector.x == 0.0:
				var nudge = _get_corner_nudge(input_vector, Vector2.LEFT, Vector2.RIGHT)
				target_velocity.x += nudge * corner_nudge_speed
				
			velocity = velocity.move_toward(target_velocity, acceleration * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	var prev_pos = global_position
	move_and_slide()
	
	var moved = global_position.distance_to(prev_pos)
	if moved > 0.01:
		total_distance += moved
		if total_distance >= 16.0:
			steps_count += 1
			total_distance -= 16.0
			step_taken.emit()
	
	_update_visuals()

func _spawn_ghost_trail() -> void:
	if not sprite:
		return
	var ghost = Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.global_position = sprite.global_position
	ghost.scale = sprite.scale
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(0.3, 0.7, 1.0, 0.6)
	get_parent().add_child(ghost)
	
	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)

func _trigger_dash() -> void:
	is_dashing = true
	is_invincible = true
	dash_timer = DASH_DURATION
	dash_cooldown = DASH_COOLDOWN_TIME
	ghost_trail_timer = 0.0
	trigger_camera_shake(2.5, 0.15)
	
	if input_vector != Vector2.ZERO:
		dash_direction = input_vector.normalized()
	elif sprite.flip_h:
		dash_direction = Vector2.LEFT
	else:
		dash_direction = Vector2.RIGHT
		
	if sprite.sprite_frames.has_animation("dash"):
		sprite.play("dash")

func _perform_attack() -> void:
	is_attacking = true
	combo_reset_timer = 1.0
	trigger_camera_shake(2.0, 0.1)
	
	var anim_name = "attack" + str(combo_index)
	combo_index = (combo_index % 3) + 1
	
	var dir_offset = Vector2(-10, 0) if sprite.flip_h else Vector2(10, 0)
	attack_shape.position = dir_offset
	attack_shape.disabled = false
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	
	get_tree().create_timer(0.08).timeout.connect(func():
		if attack_area:
			for body in attack_area.get_overlapping_bodies():
				if body.has_method("defeat"):
					trigger_camera_shake(6.0, 0.25)
					body.defeat()
	)

func _on_animation_finished() -> void:
	if sprite and sprite.animation.begins_with("attack"):
		is_attacking = false
		attack_shape.disabled = true
		_update_visuals()

func _get_corner_nudge(main_dir: Vector2, perp_pos: Vector2, perp_neg: Vector2) -> float:
	var test_transform = global_transform
	var check_dist = 2.0
	if not test_move(test_transform, main_dir * check_dist):
		return 0.0

	for offset in range(1, int(corner_nudge_distance) + 1):
		var pos_transform = test_transform
		pos_transform.origin += perp_pos * float(offset)
		if not test_move(pos_transform, main_dir * check_dist):
			if not test_move(test_transform, perp_pos * float(offset)):
				return float(offset) / corner_nudge_distance

		var neg_transform = test_transform
		neg_transform.origin += perp_neg * float(offset)
		if not test_move(neg_transform, main_dir * check_dist):
			if not test_move(test_transform, perp_neg * float(offset)):
				return -float(offset) / corner_nudge_distance

	return 0.0

func _update_visuals() -> void:
	if not sprite or is_attacking:
		return
		
	if speed_boost_timer > 0.0:
		sprite.modulate = Color(1.2, 1.2, 0.4)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0)
		
	if is_dashing:
		if sprite.animation != "dash" and sprite.sprite_frames.has_animation("dash"):
			sprite.play("dash")
		sprite.flip_h = dash_direction.x < 0
		return

	if is_shielding:
		if sprite.animation != "shield" and sprite.sprite_frames.has_animation("shield"):
			sprite.play("shield")
		return
		
	if velocity.length() > 5.0:
		if sprite.animation != "run" and sprite.sprite_frames.has_animation("run"):
			sprite.play("run")
		if velocity.x < -1.0:
			sprite.flip_h = true
		elif velocity.x > 1.0:
			sprite.flip_h = false
	else:
		if sprite.animation != "idle" and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

func reset_stats() -> void:
	total_distance = 0.0
	steps_count = 0
	is_active = true
	is_attacking = false
	is_shielding = false
	is_dashing = false
	is_invincible = false
	has_key = false
	dash_timer = 0.0
	dash_cooldown = 0.0
	speed_boost_timer = 0.0
	magnet_timer = 0.0
	combo_index = 1
	combo_reset_timer = 0.0
	key_status_changed.emit(false)
	if attack_shape:
		attack_shape.disabled = true
	apply_character_settings()
