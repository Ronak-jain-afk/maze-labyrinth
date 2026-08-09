extends Node

enum Difficulty { EASY, MEDIUM, HARD }
enum CharacterType { FIGHTER, SHINOBI, SAMURAI }

var current_difficulty: Difficulty = Difficulty.MEDIUM
var selected_character: CharacterType = CharacterType.FIGHTER
var sound_enabled: bool = true

var is_resuming: bool = false
var resume_level: int = 1
var resume_score: int = 0
var total_coins: int = 0

# Passive Relics
var relic_sharp_blade: bool = false
var relic_parry_master: bool = false
var relic_boots_hermes: bool = false
var relic_extra_life: bool = false
var has_extra_life_used: bool = false

const SAVE_PATH = "user://savegame.cfg"

func _ready() -> void:
	load_settings()

func get_character_name(char_type: CharacterType = selected_character) -> String:
	match char_type:
		CharacterType.FIGHTER:
			return "FIGHTER"
		CharacterType.SHINOBI:
			return "SHINOBI"
		CharacterType.SAMURAI:
			return "SAMURAI"
		_:
			return "FIGHTER"

func get_character_speed(char_type: CharacterType = selected_character) -> float:
	var base_spd = 100.0
	match char_type:
		CharacterType.FIGHTER:
			base_spd = 100.0
		CharacterType.SHINOBI:
			base_spd = 125.0
		CharacterType.SAMURAI:
			base_spd = 85.0
		_:
			base_spd = 100.0
			
	if relic_boots_hermes:
		base_spd *= 1.15
	return base_spd

func get_character_attack_scale(char_type: CharacterType = selected_character) -> float:
	var base_scale = 1.0
	match char_type:
		CharacterType.FIGHTER:
			base_scale = 1.0
		CharacterType.SHINOBI:
			base_scale = 0.85
		CharacterType.SAMURAI:
			base_scale = 1.45
		_:
			base_scale = 1.0
			
	if relic_sharp_blade:
		base_scale *= 1.25
	return base_scale

func get_character_trait(char_type: CharacterType = selected_character) -> String:
	match char_type:
		CharacterType.FIGHTER:
			return "Master Duelist — Balanced Speed & Precision Combos"
		CharacterType.SHINOBI:
			return "Shadow Runner — +25% Speed for Swift Navigation"
		CharacterType.SAMURAI:
			return "Blade Master — Massive Heavy Slashes & Wide Hitbox"
		_:
			return "Balanced Warrior"

func get_character_speed_rating(char_type: CharacterType = selected_character) -> int:
	match char_type:
		CharacterType.FIGHTER: return 3
		CharacterType.SHINOBI: return 5
		CharacterType.SAMURAI: return 2
		_: return 3

func get_character_power_rating(char_type: CharacterType = selected_character) -> int:
	match char_type:
		CharacterType.FIGHTER: return 4
		CharacterType.SHINOBI: return 3
		CharacterType.SAMURAI: return 5
		_: return 4

func get_character_folder(char_type: CharacterType = selected_character) -> String:
	match char_type:
		CharacterType.FIGHTER:
			return "res://assets/Fighter/"
		CharacterType.SHINOBI:
			return "res://assets/Shinobi/"
		CharacterType.SAMURAI:
			return "res://assets/Samurai/"
		_:
			return "res://assets/Fighter/"

func get_maze_dimensions() -> Vector2i:
	match current_difficulty:
		Difficulty.EASY:
			return Vector2i(17, 13)
		Difficulty.MEDIUM:
			return Vector2i(25, 17)
		Difficulty.HARD:
			return Vector2i(33, 23)
		_:
			return Vector2i(25, 17)

func get_difficulty_name() -> String:
	match current_difficulty:
		Difficulty.EASY:
			return "Easy (17x13)"
		Difficulty.MEDIUM:
			return "Medium (25x17)"
		Difficulty.HARD:
			return "Hard (33x23)"
		_:
			return "Medium"

func save_game(level: int, score: int) -> void:
	var config = ConfigFile.new()
	config.set_value("game", "level", level)
	config.set_value("game", "score", score)
	config.set_value("game", "coins", total_coins)
	config.set_value("game", "difficulty", int(current_difficulty))
	config.set_value("game", "character", int(selected_character))
	config.set_value("relics", "sharp_blade", relic_sharp_blade)
	config.set_value("relics", "parry_master", relic_parry_master)
	config.set_value("relics", "boots_hermes", relic_boots_hermes)
	config.set_value("relics", "extra_life", relic_extra_life)
	config.save(SAVE_PATH)

func has_save_file() -> bool:
	var config = ConfigFile.new()
	return config.load(SAVE_PATH) == OK

func load_save_data() -> bool:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		resume_level = config.get_value("game", "level", 1)
		resume_score = config.get_value("game", "score", 0)
		total_coins = config.get_value("game", "coins", 0)
		current_difficulty = config.get_value("game", "difficulty", int(Difficulty.MEDIUM)) as Difficulty
		selected_character = config.get_value("game", "character", int(CharacterType.FIGHTER)) as CharacterType
		relic_sharp_blade = config.get_value("relics", "sharp_blade", false)
		relic_parry_master = config.get_value("relics", "parry_master", false)
		relic_boots_hermes = config.get_value("relics", "boots_hermes", false)
		relic_extra_life = config.get_value("relics", "extra_life", false)
		is_resuming = true
		return true
	return false

func clear_save() -> void:
	is_resuming = false
	resume_level = 1
	resume_score = 0
	total_coins = 0
	relic_sharp_blade = false
	relic_parry_master = false
	relic_boots_hermes = false
	relic_extra_life = false
	has_extra_life_used = false
	if DirAccess.remove_absolute(SAVE_PATH) != OK:
		pass

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("settings", "difficulty", int(current_difficulty))
	config.set_value("settings", "character", int(selected_character))
	config.set_value("settings", "sound", sound_enabled)
	config.save("user://settings.cfg")

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		current_difficulty = config.get_value("settings", "difficulty", int(Difficulty.MEDIUM)) as Difficulty
		selected_character = config.get_value("settings", "character", int(CharacterType.FIGHTER)) as CharacterType
		sound_enabled = config.get_value("settings", "sound", true)
