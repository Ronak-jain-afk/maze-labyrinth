extends CanvasLayer

signal glitch_finished

@onready var glitch_overlay: ColorRect = $GlitchOverlay
@onready var error_label: Label = $ErrorLabel
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

var glitch_tween: Tween = null

func _ready() -> void:
	if glitch_overlay:
		glitch_overlay.visible = false
	if error_label:
		error_label.visible = false

func trigger_glitch(reboot_callback: Callable = Callable()) -> void:
	if glitch_overlay:
		glitch_overlay.visible = true
	if error_label:
		error_label.visible = true
		
	_play_glitch_sound()
	
	if glitch_tween and glitch_tween.is_running():
		glitch_tween.kill()
		
	glitch_tween = create_tween()
	
	# Rapid chromatic glitch steps
	for i in range(8):
		var r = randf_range(0.2, 1.0)
		var g = randf_range(0.0, 0.3)
		var b = randf_range(0.1, 0.8)
		var a = randf_range(0.4, 0.85)
		glitch_tween.tween_callback(func():
			if glitch_overlay:
				glitch_overlay.color = Color(r, g, b, a)
			if error_label:
				error_label.position = Vector2(randf_range(-10, 10), randf_range(-6, 6))
		)
		glitch_tween.tween_interval(0.04)
		
	# Execute reboot callback at peak burst
	glitch_tween.tween_callback(func():
		if reboot_callback.is_valid():
			reboot_callback.call()
	)
	
	glitch_tween.tween_interval(0.15)
	
	# Fade out glitch
	glitch_tween.tween_callback(func():
		if glitch_overlay:
			glitch_overlay.visible = false
		if error_label:
			error_label.visible = false
		glitch_finished.emit()
	)

func _play_glitch_sound() -> void:
	if not audio_player:
		return
	var sample_rate = 22050
	var duration = 0.4
	var num_samples = int(sample_rate * duration)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	
	var data = PackedByteArray()
	for i in range(num_samples):
		var t = float(i) / num_samples
		var noise = randf_range(-1.0, 1.0) * (1.0 - t) * 110.0
		data.append(clamp(int(noise), -128, 127))
		
	stream.data = data
	audio_player.stream = stream
	audio_player.play()
