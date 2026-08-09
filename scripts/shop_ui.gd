extends CanvasLayer

signal shop_closed

@onready var panel: Control = $Control
@onready var coins_label: Label = $Control/PanelContainer/VBoxContainer/HeaderContainer/CoinsLabel
@onready var close_btn: Button = $Control/PanelContainer/VBoxContainer/CloseButton

# Relic Buttons & Status
@onready var sharp_btn: Button = $Control/PanelContainer/VBoxContainer/RelicList/SharpBladeItem/BuyButton
@onready var parry_btn: Button = $Control/PanelContainer/VBoxContainer/RelicList/ParryMasterItem/BuyButton
@onready var hermes_btn: Button = $Control/PanelContainer/VBoxContainer/RelicList/HermesBootsItem/BuyButton
@onready var life_btn: Button = $Control/PanelContainer/VBoxContainer/RelicList/ExtraLifeItem/BuyButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.hide()
	close_btn.pressed.connect(hide_shop)
	sharp_btn.pressed.connect(_buy_sharp_blade)
	parry_btn.pressed.connect(_buy_parry_master)
	hermes_btn.pressed.connect(_buy_hermes_boots)
	life_btn.pressed.connect(_buy_extra_life)

func show_shop() -> void:
	_update_ui()
	panel.show()
	get_tree().paused = true

func hide_shop() -> void:
	panel.hide()
	get_tree().paused = false
	shop_closed.emit()

func toggle_shop() -> void:
	if panel.visible:
		hide_shop()
	else:
		show_shop()

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F or event.keycode == KEY_ESCAPE:
			hide_shop()
			get_viewport().set_input_as_handled()

func _update_ui() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if not gs:
		return
		
	coins_label.text = "COINS: 🪙 %d" % gs.total_coins
	
	_update_btn(sharp_btn, gs.relic_sharp_blade, 150, gs.total_coins)
	_update_btn(parry_btn, gs.relic_parry_master, 250, gs.total_coins)
	_update_btn(hermes_btn, gs.relic_boots_hermes, 200, gs.total_coins)
	_update_btn(life_btn, gs.relic_extra_life, 350, gs.total_coins)

func _update_btn(btn: Button, is_owned: bool, cost: int, player_coins: int) -> void:
	if not btn:
		return
	if is_owned:
		btn.text = "OWNED"
		btn.disabled = true
	else:
		btn.text = "BUY (%d 🪙)" % cost
		btn.disabled = player_coins < cost

func _buy_sharp_blade() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and not gs.relic_sharp_blade and gs.total_coins >= 150:
		gs.total_coins -= 150
		gs.relic_sharp_blade = true
		_update_ui()

func _buy_parry_master() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and not gs.relic_parry_master and gs.total_coins >= 250:
		gs.total_coins -= 250
		gs.relic_parry_master = true
		_update_ui()

func _buy_hermes_boots() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and not gs.relic_boots_hermes and gs.total_coins >= 200:
		gs.total_coins -= 200
		gs.relic_boots_hermes = true
		_update_ui()

func _buy_extra_life() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and not gs.relic_extra_life and gs.total_coins >= 350:
		gs.total_coins -= 350
		gs.relic_extra_life = true
		_update_ui()
