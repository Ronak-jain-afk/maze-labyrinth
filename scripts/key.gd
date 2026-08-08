extends Area2D

signal key_picked_up

@onready var sprite: Label = $Label
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
		position.y = base_y + sin(bob_time) * 3.0

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body.name == "Player" or body.is_in_group("player") or body.has_method("collect_key"):
		is_collected = true
		if body.has_method("collect_key"):
			body.collect_key()
			
		key_picked_up.emit()
		_play_key_sound()
		
		# Popup scale tween
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
		var freq = 659.25 if t < 0.3 else (880.0 if t < 0.6 else 1046.50) # E5 -> A5 -> C6 fanfair
		var val = int(sin(2.0 * PI * freq * (float(i) / sample_rate)) * (1.0 - t) * 100.0)
		data.append(clamp(val, -128, 127))
		
	stream.data = data
	audio_player.stream = stream
	audio_player.play()
