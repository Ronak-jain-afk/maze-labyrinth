extends Area2D

signal trap_triggered

@export var cycle_time: float = 2.4
@export var active_duration: float = 1.2

@onready var color_rect: ColorRect = $ColorRect
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_active: bool = false
var timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_set_active_state(false)

func _process(delta: float) -> void:
	timer += delta
	var current_cycle = fmod(timer, cycle_time)
	
	if current_cycle < active_duration:
		if not is_active:
			_set_active_state(true)
	else:
		if is_active:
			_set_active_state(false)

func _set_active_state(active: bool) -> void:
	is_active = active
	if color_rect:
		if is_active:
			color_rect.color = Color(0.9, 0.2, 0.2, 0.85)
		else:
			color_rect.color = Color(0.3, 0.3, 0.35, 0.35)
	if label:
		label.text = "▲" if is_active else "·"
		label.modulate = Color(1.0, 0.3, 0.3) if is_active else Color(0.6, 0.6, 0.6)

	if is_active:
		# Check overlapping bodies when activated
		for body in get_overlapping_bodies():
			_check_player_hit(body)

func _on_body_entered(body: Node2D) -> void:
	if is_active:
		_check_player_hit(body)

func _check_player_hit(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		if body.has_method("is_invincible_now") and body.is_invincible_now():
			# Player is dashing with i-frames - safe from spikes!
			return
		
		# Spikes hit player! Trigger caught/glitch death
		var maze_node = get_tree().get_first_node_in_group("maze")
		if not maze_node:
			maze_node = get_parent()
		if maze_node and maze_node.has_method("_on_player_caught"):
			maze_node._on_player_caught()
