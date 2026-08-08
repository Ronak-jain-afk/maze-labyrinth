extends Area2D

signal powerup_collected(type_name: String, duration: float)

enum Type { SPEED_BOOTS, COIN_MAGNET, TIME_FREEZE }

@export var powerup_type: Type = Type.SPEED_BOOTS
@export var duration: float = 8.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

var initial_y: float = 0.0
var bob_time: float = 0.0

func _ready() -> void:
	initial_y = position.y
	body_entered.connect(_on_body_entered)
	_setup_visuals()

func _setup_visuals() -> void:
	if not label:
		return
	match powerup_type:
		Type.SPEED_BOOTS:
			label.text = "⚡"
			label.modulate = Color(1.0, 0.9, 0.2)
			duration = 8.0
		Type.COIN_MAGNET:
			label.text = "🧲"
			label.modulate = Color(0.3, 0.8, 1.0)
			duration = 10.0
		Type.TIME_FREEZE:
			label.text = "⏱️"
			label.modulate = Color(0.9, 0.4, 1.0)
			duration = 5.0

func _process(delta: float) -> void:
	bob_time += delta * 4.0
	position.y = initial_y + sin(bob_time) * 3.0

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player") or body.has_method("apply_powerup"):
		var type_name = "SPEED"
		if powerup_type == Type.COIN_MAGNET:
			type_name = "MAGNET"
		elif powerup_type == Type.TIME_FREEZE:
			type_name = "FREEZE"
			
		if body.has_method("apply_powerup"):
			body.apply_powerup(type_name, duration)
			
		powerup_collected.emit(type_name, duration)
		
		# Popup scale tween
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(self, "modulate:a", 0.0, 0.1)
		tween.tween_callback(queue_free)
