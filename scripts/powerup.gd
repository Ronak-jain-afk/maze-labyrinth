extends Area2D

signal powerup_collected(type_name: String, duration: float)

enum Type { SPEED_BOOTS, COIN_MAGNET, TIME_FREEZE }

@export var powerup_type: Type = Type.SPEED_BOOTS
@export var duration: float = 8.0

var initial_y: float = 0.0
var bob_time: float = 0.0

func _ready() -> void:
	initial_y = position.y
	body_entered.connect(_on_body_entered)
	match powerup_type:
		Type.SPEED_BOOTS:
			duration = 8.0
		Type.COIN_MAGNET:
			duration = 10.0
		Type.TIME_FREEZE:
			duration = 5.0

func _process(delta: float) -> void:
	bob_time += delta * 4.0
	position.y = initial_y + sin(bob_time) * 2.5
	queue_redraw()

func _draw() -> void:
	match powerup_type:
		Type.SPEED_BOOTS:
			_draw_speed_boots()
		Type.COIN_MAGNET:
			_draw_coin_magnet()
		Type.TIME_FREEZE:
			_draw_time_freeze()

func _draw_speed_boots() -> void:
	# Yellow speed boots / winged bolt icon
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.9, 0.2, 0.25))
	
	# Lightning bolt shape
	var pts = PackedVector2Array([
		Vector2(1.0, -4.5),
		Vector2(-3.0, 0.5),
		Vector2(-0.5, 0.5),
		Vector2(-2.0, 4.5),
		Vector2(3.0, -0.5),
		Vector2(0.5, -0.5)
	])
	draw_polygon(pts, PackedColorArray([Color(1.0, 0.9, 0.2), Color(1.0, 0.9, 0.2), Color(1.0, 0.9, 0.2), Color(1.0, 0.9, 0.2), Color(1.0, 0.9, 0.2), Color(1.0, 0.9, 0.2)]))
	draw_polyline(pts, Color(0.3, 0.2, 0.0), 1.0, true)

func _draw_coin_magnet() -> void:
	# Magnet aura
	draw_circle(Vector2.ZERO, 6.0, Color(0.3, 0.8, 1.0, 0.25))
	
	# Red U-shaped magnet body
	var red_col = Color(0.9, 0.2, 0.2)
	var silver_col = Color(0.9, 0.9, 0.95)
	var border_col = Color(0.2, 0.05, 0.05)
	
	# Left pole
	draw_rect(Rect2(-3.5, -3.5, 2.0, 5.0), red_col)
	draw_rect(Rect2(-3.5, 1.5, 2.0, 2.0), silver_col)
	
	# Right pole
	draw_rect(Rect2(1.5, -3.5, 2.0, 5.0), red_col)
	draw_rect(Rect2(1.5, 1.5, 2.0, 2.0), silver_col)
	
	# Bottom arch connecting poles
	draw_rect(Rect2(-3.5, -4.5, 7.0, 2.0), red_col)
	
	# Outlines
	draw_rect(Rect2(-3.5, -4.5, 7.0, 8.0), border_col, false, 0.8)
	
	# Magnetic field arcs
	draw_arc(Vector2(-2.5, 4.5), 1.5, 0, PI * 0.5, 4, Color(0.3, 0.8, 1.0, 0.8), 1.0)
	draw_arc(Vector2(2.5, 4.5), 1.5, PI * 0.5, PI, 4, Color(0.3, 0.8, 1.0, 0.8), 1.0)

func _draw_time_freeze() -> void:
	# Purple time freeze aura
	draw_circle(Vector2.ZERO, 6.0, Color(0.8, 0.4, 1.0, 0.25))
	
	var clock_border = Color(0.25, 0.1, 0.3)
	var clock_face = Color(0.9, 0.6, 1.0)
	var hand_col = Color(0.3, 0.0, 0.4)
	
	draw_circle(Vector2.ZERO, 4.5, clock_border)
	draw_circle(Vector2.ZERO, 3.5, clock_face)
	
	# Clock hands
	draw_line(Vector2.ZERO, Vector2(0, -2.5), hand_col, 1.0)
	draw_line(Vector2.ZERO, Vector2(1.5, 0), hand_col, 1.0)
	draw_line(Vector2(0, -4.5), Vector2(0, -5.5), clock_border, 1.2) # Top button

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
		
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(self, "modulate:a", 0.0, 0.1)
		tween.tween_callback(queue_free)
