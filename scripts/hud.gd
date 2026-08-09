extends CanvasLayer

@onready var timer_label: Label = $MarginContainer/HBoxContainer/TimerLabel
@onready var level_label: Label = $MarginContainer/HBoxContainer/LevelLabel
@onready var steps_label: Label = $MarginContainer/HBoxContainer/StepsLabel
@onready var score_label: Label = $MarginContainer/HBoxContainer/ScoreLabel
@onready var dash_label: Label = $MarginContainer/HBoxContainer/DashLabel
@onready var powerup_label: Label = $MarginContainer/HBoxContainer/PowerUpLabel
@onready var key_label: Label = $MarginContainer/HBoxContainer/KeyLabel
@onready var shop_btn: Button = $MarginContainer/HBoxContainer/ShopButton

func _ready() -> void:
	if shop_btn:
		shop_btn.pressed.connect(_on_shop_pressed)

func _on_shop_pressed() -> void:
	var shop_ui = get_node_or_null("../ShopUI")
	if shop_ui and shop_ui.has_method("show_shop"):
		shop_ui.show_shop()

func update_timer(seconds: float) -> void:
	if timer_label:
		timer_label.text = "TIME: %.1fs" % seconds

func update_level(lvl: int) -> void:
	if level_label:
		level_label.text = "LEVEL: %d" % lvl

func update_steps(steps: int) -> void:
	if steps_label:
		steps_label.text = "STEPS: %d" % steps

func update_score(score: int) -> void:
	if score_label:
		score_label.text = "SCORE: %d" % score

func update_dash_cooldown(current: float, _max_val: float) -> void:
	if dash_label:
		if current <= 0.0:
			dash_label.text = "DASH: READY [E]"
			dash_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.7))
		else:
			dash_label.text = "DASH: %.1fs" % current
			dash_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.4))

func update_powerup_status(type_name: String, remaining: float) -> void:
	if not powerup_label:
		return
	if remaining <= 0.0:
		powerup_label.text = ""
	else:
		match type_name:
			"SPEED":
				powerup_label.text = "⚡ SPEED: %.1fs" % remaining
				powerup_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
			"MAGNET":
				powerup_label.text = "🧲 MAGNET: %.1fs" % remaining
				powerup_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
			"FREEZE":
				powerup_label.text = "⏱️ FREEZE: %.1fs" % remaining
				powerup_label.add_theme_color_override("font_color", Color(0.9, 0.4, 1.0))

func update_key_status(has_key: bool) -> void:
	if not key_label:
		return
	if has_key:
		key_label.text = "KEY: 🔑 ACQUIRED"
		key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		key_label.text = "KEY: 🔒 NEEDED"
		key_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
