extends Control

@onready var bg_texture: TextureRect = %BackgroundTexture
@onready var title_label: Label = %TitleLabel
@onready var resume_button: Button = %ResumeButton
@onready var play_button: Button = %PlayButton
@onready var difficulty_button: Button = %DifficultyButton
@onready var how_to_play_button: Button = %HowToPlayButton
@onready var quit_button: Button = %QuitButton
@onready var modal: PanelContainer = %HowToPlayModal
@onready var close_modal_button: Button = %CloseModalButton
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

@onready var char_sprite: AnimatedSprite2D = %CharSprite
@onready var prev_char_btn: Button = %PrevCharBtn
@onready var next_char_btn: Button = %NextCharBtn
@onready var char_name_label: Label = %CharNameLabel
@onready var speed_val_label: Label = %SpeedValLabel
@onready var power_val_label: Label = %PowerValLabel
@onready var trait_label: Label = %TraitLabel
@onready var equip_button: Button = %EquipButton

var preview_char_index: int = 0

func _ready() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		preview_char_index = int(gs.selected_character)
		
	_update_difficulty_button_text()
	_check_save_game()
	_update_character_display()
	
	resume_button.pressed.connect(_on_resume_pressed)
	play_button.pressed.connect(_on_play_pressed)
	difficulty_button.pressed.connect(_on_difficulty_pressed)
	how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	close_modal_button.pressed.connect(_on_close_modal_pressed)
	
	prev_char_btn.pressed.connect(_on_prev_char_pressed)
	next_char_btn.pressed.connect(_on_next_char_pressed)
	equip_button.pressed.connect(_on_equip_pressed)
	
	_setup_hover_effects(resume_button)
	_setup_hover_effects(play_button)
	_setup_hover_effects(difficulty_button)
	_setup_hover_effects(how_to_play_button)
	_setup_hover_effects(quit_button)
	_setup_hover_effects(close_modal_button)
	_setup_hover_effects(prev_char_btn)
	_setup_hover_effects(next_char_btn)
	_setup_hover_effects(equip_button)
	
	_animate_title()

func _check_save_game() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_save_file():
		gs.load_save_data()
		preview_char_index = int(gs.selected_character)
		resume_button.visible = true
		resume_button.text = "RESUME GAME (Lvl %d)" % gs.resume_level
		play_button.text = "NEW GAME"
	else:
		resume_button.visible = false
		play_button.text = "PLAY GAME"

func _animate_title() -> void:
	if title_label:
		var tween = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(title_label, "modulate", Color(1.1, 1.1, 1.2, 1.0), 1.5)
		tween.tween_property(title_label, "modulate", Color(0.85, 0.95, 1.0, 0.9), 1.5)

func _on_prev_char_pressed() -> void:
	_play_click_sound(500.0)
	preview_char_index = (preview_char_index - 1 + 3) % 3
	_update_character_display()

func _on_next_char_pressed() -> void:
	_play_click_sound(500.0)
	preview_char_index = (preview_char_index + 1) % 3
	_update_character_display()

func _on_equip_pressed() -> void:
	_play_click_sound(750.0)
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.selected_character = preview_char_index as GameSettings.CharacterType
		gs.save_settings()
		_update_character_display()

func _update_character_display() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if not gs:
		return
		
	var char_type = preview_char_index as GameSettings.CharacterType
	char_name_label.text = gs.get_character_name(char_type)
	
	var spd_rating = gs.get_character_speed_rating(char_type)
	var pwr_rating = gs.get_character_power_rating(char_type)
	
	var spd_bar = ""
	for i in range(5): spd_bar += "█" if i < spd_rating else "░"
	speed_val_label.text = "[%s] %.0f px/s" % [spd_bar, gs.get_character_speed(char_type)]
	
	var pwr_bar = ""
	for i in range(5): pwr_bar += "█" if i < pwr_rating else "░"
	power_val_label.text = "[%s] %s" % [pwr_bar, "HEAVY" if pwr_rating >= 5 else ("FAST" if spd_rating >= 5 else "BALANCED")]
	
	trait_label.text = gs.get_character_trait(char_type)
	
	if char_type == gs.selected_character:
		equip_button.text = "EQUIPPED"
		equip_button.modulate = Color(0.4, 1.0, 0.8)
	else:
		equip_button.text = "EQUIP HERO"
		equip_button.modulate = Color(1.0, 1.0, 1.0)
		
	_load_preview_sprite(gs.get_character_folder(char_type))

func _load_preview_sprite(folder_path: String) -> void:
	if not char_sprite:
		return
		
	var idle_path = folder_path + "Idle.png"
	if not ResourceLoader.exists(idle_path):
		return
		
	var tex = load(idle_path) as Texture2D
	if not tex:
		return
		
	var frame_h = tex.get_height()
	if frame_h <= 0:
		return
	var frame_w = frame_h
	var frame_count = int(tex.get_width() / frame_h)
	if frame_count <= 0:
		return

	var sf = SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 8.0)
	sf.set_animation_loop("idle", true)
	
	for i in range(frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		sf.add_frame("idle", atlas)
		
	char_sprite.sprite_frames = sf
	char_sprite.play("idle")

func _setup_hover_effects(btn: Button) -> void:
	if not btn:
		return
	btn.mouse_entered.connect(func():
		_play_click_sound(600.0)
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
	)
	btn.mouse_exited.connect(func():
		var tween = create_tween().set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)

func _on_resume_pressed() -> void:
	_play_click_sound(800.0)
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.is_resuming = true
	get_tree().change_scene_to_file("res://game.tscn")

func _on_play_pressed() -> void:
	_play_click_sound(800.0)
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.clear_save()
	get_tree().change_scene_to_file("res://game.tscn")

func _on_difficulty_pressed() -> void:
	_play_click_sound(500.0)
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		var current = gs.current_difficulty
		gs.current_difficulty = ((current + 1) % 3) as GameSettings.Difficulty
		_update_difficulty_button_text()

func _update_difficulty_button_text() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and difficulty_button:
		difficulty_button.text = "Difficulty: " + gs.get_difficulty_name()

func _on_how_to_play_pressed() -> void:
	_play_click_sound(450.0)
	modal.visible = true
	modal.scale = Vector2(0.8, 0.8)
	modal.modulate.a = 0.0
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(modal, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(modal, "modulate:a", 1.0, 0.2)

func _on_close_modal_pressed() -> void:
	_play_click_sound(350.0)
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(modal, "scale", Vector2(0.85, 0.85), 0.15)
	tween.parallel().tween_property(modal, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): modal.visible = false)

func _on_quit_pressed() -> void:
	_play_click_sound(300.0)
	get_tree().quit()

func _play_click_sound(freq: float) -> void:
	if not audio_player:
		return
	var sample_rate = 22050
	var duration = 0.05
	var num_samples = int(sample_rate * duration)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	
	var data = PackedByteArray()
	for i in range(num_samples):
		var t = float(i) / num_samples
		var val = int(sin(2.0 * PI * freq * (float(i) / sample_rate)) * (1.0 - t) * 80.0)
		data.append(clamp(val, -128, 127))
		
	stream.data = data
	audio_player.stream = stream
	audio_player.play()
