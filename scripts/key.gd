extends Area2D

signal key_picked_up

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

var base_y: float = 0.0
var is_collected: bool = false
var bob_time: float = 0.0

func _ready() -> void:
	base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if not is_collected:
		bob_time += delta * 5.0
		position.y = base_y + sin(bob_time) * 2.5
		queue_redraw()

func _draw() -> void:
	if is_collected:
		return
		
	# Draw golden aura glow
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.85, 0.2, 0.25))
	
	# Golden key outline
	var outline_color = Color(0.25, 0.15, 0.05, 1.0)
	var gold_color = Color(1.0, 0.85, 0.2, 1.0)
	var highlight = Color(1.0, 0.98, 0.6, 1.0)
	
	# Key head (ring)
	draw_circle(Vector2(0, -3), 3.5, outline_color)
	draw_circle(Vector2(0, -3), 2.5, gold_color)
	draw_circle(Vector2(0, -3), 1.0, outline_color)
	
	# Shaft
	draw_line(Vector2(0, -0.5), Vector2(0, 4.5), outline_color, 2.5)
	draw_line(Vector2(0, -0.5), Vector2(0, 4.5), gold_color, 1.2)
	
	# Teeth
	draw_line(Vector2(0, 2), Vector2(2.5, 2), outline_color, 2.0)
	draw_line(Vector2(0, 2), Vector2(2.5, 2), gold_color, 1.0)
	draw_line(Vector2(0, 4), Vector2(2.5, 4), outline_color, 2.0)
	draw_line(Vector2(0, 4), Vector2(2.5, 4), gold_color, 1.0)
	
	# Shine dot
	draw_circle(Vector2(-1, -4), 0.6, highlight)

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body.name == "Player" or body.is_in_group("player") or body.has_method("collect_key"):
		is_collected = true
		if body.has_method("collect_key"):
			body.collect_key()
			
		key_picked_up.emit()
		_play_key_sound()
		
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.1)
		tween.tween_property(self, "modulate:a", 0.0, 0.12)
		tween.tween_callback(queue_free)

func _play_key_sound() -> void:
	if not audio_player:
		return
	var sample_rate = 22050
	var duration = 0.25
	var num_samples = int(sample_rate * duration)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	
	var data = PackedByteArray()
	for i in range(num_samples):
		var t = float(i) / num_samples
		var freq = 659.25 if t < 0.3 else (880.0 if t < 0.6 else 1046.50)
		var val = int(sin(2.0 * PI * freq * (float(i) / sample_rate)) * (1.0 - t) * 100.0)
		data.append(clamp(val, -128, 127))
		
	stream.data = data
	audio_player.stream = stream
	audio_player.play()
