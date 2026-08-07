extends CanvasLayer

@onready var timer_label: Label = $MarginContainer/HBoxContainer/TimerLabel
@onready var level_label: Label = $MarginContainer/HBoxContainer/LevelLabel
@onready var steps_label: Label = $MarginContainer/HBoxContainer/StepsLabel
@onready var score_label: Label = $MarginContainer/HBoxContainer/ScoreLabel

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
