extends CharacterBody2D

signal step_taken

@export var speed: float = 100.0
@export var acceleration: float = 1600.0
@export var friction: float = 1800.0
@export var corner_nudge_distance: float = 4.0
@export var corner_nudge_speed: float = 50.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D

var total_distance: float = 0.0
var steps_count: int = 0
var input_vector: Vector2 = Vector2.ZERO
var is_active: bool = true
var is_attacking: bool = false
var combo_index: int = 1
var combo_reset_timer: float = 0.0

func _ready() -> void:
	apply_character_settings()
	if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

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
	
	if sprite:
		sprite.sprite_frames = new_frames
		sprite.play("idle")

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

func _physics_process(delta: float) -> void:
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_index = 1

	if not is_active:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		_update_visuals()
		return

	if Input.is_action_just_pressed("attack") and not is_attacking:
		_perform_attack()
		return

	if not is_attacking:
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		
		if input_vector != Vector2.ZERO:
			var target_velocity = input_vector.normalized() * speed
			
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

func _perform_attack() -> void:
	is_attacking = true
	combo_reset_timer = 1.0
	
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
	combo_index = 1
	combo_reset_timer = 0.0
	if attack_shape:
		attack_shape.disabled = true
	apply_character_settings()
