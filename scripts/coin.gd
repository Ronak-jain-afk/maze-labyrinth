extends Area2D

signal collected(amount: int)

@export var coin_value: int = 100

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

var base_y: float = 0.0
var is_collected: bool = false
var player_ref: Node2D = null

func _ready() -> void:
	base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
		
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			player_ref = get_parent().get_node_or_null("Player")
			
	if player_ref and is_instance_valid(player_ref) and player_ref.get("magnet_timer") != null:
		if float(player_ref.get("magnet_timer")) > 0.0:
			var dist = global_position.distance_to(player_ref.global_position)
			if dist < 140.0:
				global_position = global_position.move_toward(player_ref.global_position, 160.0 * delta)

	if sprite:
		# Floating bob animation
		var float_offset = sin(Time.get_ticks_msec() * 0.006) * 2.5
		sprite.position.y = float_offset

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body.name == "Player" or body.is_in_group("player") or body.has_signal("step_taken"):
		is_collected = true
		collected.emit(coin_value)
		_play_pickup_sound()
		
		# Pickup scale pop & fade animation
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.08)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.1)
		tween.tween_callback(queue_free)

func _play_pickup_sound() -> void:
	if not audio_player:
		return
	var sample_rate = 22050
	var duration = 0.12
	var num_samples = int(sample_rate * duration)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	
	var data = PackedByteArray()
	for i in range(num_samples):
		var t = float(i) / num_samples
		var freq = 587.33 if t < 0.5 else 880.0 # Two-tone retro pickup chime (D5 -> A5)
		var val = int(sin(2.0 * PI * freq * (float(i) / sample_rate)) * (1.0 - t) * 90.0)
		data.append(clamp(val, -128, 127))
		
	stream.data = data
	audio_player.stream = stream
	audio_player.play()
