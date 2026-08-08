extends CanvasLayer

@onready var timer_label: Label = $MarginContainer/HBoxContainer/TimerLabel
@onready var level_label: Label = $MarginContainer/HBoxContainer/LevelLabel
@onready var steps_label: Label = $MarginContainer/HBoxContainer/StepsLabel
@onready var score_label: Label = $MarginContainer/HBoxContainer/ScoreLabel
@onready var dash_label: Label = $MarginContainer/HBoxContainer/DashLabel

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
