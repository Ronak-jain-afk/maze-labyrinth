extends CanvasLayer

signal next_level_requested
signal main_menu_requested

@onready var panel: Control = $Control
@onready var title_label: Label = $Control/PanelContainer/VBoxContainer/TitleLabel
@onready var stats_label: Label = $Control/PanelContainer/VBoxContainer/StatsLabel
@onready var next_button: Button = $Control/PanelContainer/VBoxContainer/ButtonContainer/NextButton
@onready var shop_button: Button = $Control/PanelContainer/VBoxContainer/ButtonContainer/ShopButton
@onready var main_menu_button: Button = $Control/PanelContainer/VBoxContainer/ButtonContainer/MainMenuButton

func _ready() -> void:
	panel.visible = false
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if shop_button:
		shop_button.pressed.connect(_on_shop_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

func show_victory(level: int, time_seconds: float, steps: int, score: int = 0) -> void:
	panel.visible = true
	if title_label:
		title_label.text = "MAZE CLEARED!"
	if stats_label:
		stats_label.text = "Level: %d\nTime: %.2f seconds\nSteps: %d\nScore: %d pts" % [level, time_seconds, steps, score]

func hide_victory() -> void:
	panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			_on_main_menu_pressed()
		elif event.keycode == KEY_N:
			_on_next_pressed()
		elif event.keycode == KEY_F:
			_on_shop_pressed()

func _on_shop_pressed() -> void:
	var shop_ui = get_node_or_null("../ShopUI")
	if shop_ui and shop_ui.has_method("show_shop"):
		shop_ui.show_shop()

func _on_next_pressed() -> void:
	hide_victory()
	get_parent().generate_level(get_parent().current_level + 1)

func _on_main_menu_pressed() -> void:
	hide_victory()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
