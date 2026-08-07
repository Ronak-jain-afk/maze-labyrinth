extends CanvasLayer

signal glitch_midpoint_reached

@onready var color_rect: ColorRect = $Control/ColorRect
@onready var label: Label = $Control/GlitchLabel
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var control: Control = $Control

var is_glitching: bool = false

func _ready() -> void:
	control.visible = false

func trigger_glitch(callback: Callable) -> void:
	if is_glitching:
		return
	is_glitching = true
	control.visible = true
	
	_play_glitch_sound()
	
	var tween = create_tween()
	
	for i in range(12):
		var col = Color(randf(), randf(), randf(), 0.7 + randf() * 0.3)
		var offset_x = (randf() - 0.5) * 32.0
		var offset_y = (randf() - 0.5) * 18.0
		tween.tween_callback(func():
			color_rect.color = col
			control.position = Vector2(offset_x, offset_y)
			label.visible = (i % 2 == 0)
		)
		tween.tween_interval(0.035)

	tween.tween_callback(func():
		if callback.is_valid():
			callback.call()
		glitch_midpoint_reached.emit()
	)

	tween.tween_interval(0.2)
	tween.tween_callback(func():
		control.visible = false
		control.position = Vector2.ZERO
		is_glitching = false
	)

func _play_glitch_sound() -> void:
	if not audio_player:
		return
	var sample_rate = 22050
	var duration = 0.35
	var num_samples = int(sample_rate * duration)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	
	var data = PackedByteArray()
	for i in range(num_samples):
		var noise = (randi() % 255) - 128
		var freq_sweep = sin(i * 0.8) * 100.0
		var val = int(clamp(noise + freq_sweep, -128, 127))
		data.append(val)
		
	stream.data = data
	audio_player.stream = stream
	audio_player.play()
