extends Node

var player: AudioStreamPlayer

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	add_child(player)
	
	var stream: AudioStreamWAV = load("res://assets/bg_music.wav")
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.get_length() * stream.mix_rate
		player.stream = stream
		player.volume_db = -6.0
		player.play()

func toggle_music() -> void:
	if player:
		player.playing = not player.playing

func set_volume(db: float) -> void:
	if player:
		player.volume_db = db
