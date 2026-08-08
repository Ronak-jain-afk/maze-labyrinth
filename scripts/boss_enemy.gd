extends CharacterBody2D

signal player_caught
signal boss_hp_changed(current: int, max_val: int)
signal boss_defeated

@export var max_hp: int = 10
@export var base_speed: float = 65.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $HitBox
@onready var hp_label: Label = $HPLabel

var current_hp: int = 10
var is_enraged: bool = false
var is_defeated: bool = false
var is_stunned: bool = false
var stun_timer: float = 0.0
var player_ref: Node2D = null
var shadow_dash_timer: float = 0.0

func _ready() -> void:
	current_hp = max_hp
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	boss_hp_changed.emit(current_hp, max_hp)

func defeat() -> void:
	if is_defeated:
		return
		
	current_hp -= 1
	boss_hp_changed.emit(current_hp, max_hp)
	_update_hp_text()
	
	if current_hp <= 5 and not is_enraged:
		is_enraged = true
		base_speed = 90.0
		if sprite:
			sprite.modulate = Color(1.8, 0.4, 0.4)
			
	if current_hp > 0:
		# Hit flash
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2.5, 0.5, 0.5, 1.0), 0.08)
		tween.tween_property(sprite, "modulate", Color(1.8, 0.4, 0.4) if is_enraged else Color(1.0, 1.0, 1.0), 0.08)
		return

	is_defeated = true
	boss_defeated.emit()
	set_physics_process(false)
	
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
		
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(3.0, 0.2, 0.2, 1.0), 0.15)
	tween.tween_property(sprite, "scale", Vector2(0.35, 0.05), 0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)

func stun(duration: float = 1.0, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_defeated:
		return
	is_stunned = true
	stun_timer = duration * 0.6 # Boss resists 40% of stun duration!
	if knockback_dir != Vector2.ZERO:
		global_position += knockback_dir * 8.0

func _physics_process(delta: float) -> void:
	if is_defeated:
		return
		
	if is_stunned:
		stun_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		if stun_timer <= 0.0:
			is_stunned = false
		return

	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			player_ref = get_parent().get_node_or_null("Player")

	if player_ref and is_instance_valid(player_ref):
		var dir = (player_ref.global_position - global_position).normalized()
		velocity = dir * base_speed
		move_and_slide()
		
		if sprite:
			sprite.flip_h = dir.x < 0

func _update_hp_text() -> void:
	if hp_label:
		hp_label.text = "BOSS HP: %d/%d" % [current_hp, max_hp]

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_defeated or is_stunned:
		return
	if body == player_ref or body.name == "Player" or body.has_signal("step_taken"):
		if body.has_method("is_invincible_now") and body.is_invincible_now():
			return
		if body.has_method("is_shielding_now") and body.is_shielding_now():
			var knockback = (global_position - body.global_position).normalized()
			stun(1.0, knockback)
			return
			
		player_caught.emit()
