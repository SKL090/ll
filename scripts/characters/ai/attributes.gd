## GURPS-атрибуты NPC: ST / DX / IQ / HT и производные
class_name GURPSAttributes
extends Node

var strength: int = 10
var dexterity: int = 10
var intelligence: int = 10
var health: int = 10

var max_hp: int = 10
var current_hp: int = 10
var max_fp: int = 10
var current_fp: int = 10
var max_will: int = 10
var current_will: int = 10
var max_perception: int = 10
var current_perception: int = 10
var basic_speed: float = 5.0
var basic_move: int = 5


func _init() -> void:
	recalculate_all()
	full_restore()


func recalculate_all() -> void:
	# GURPS: HP = ST, FP = HT, Will = IQ, Per = IQ, Speed = (DX+HT)/4
	max_hp = max(strength, 1)
	max_fp = max(health, 1)
	max_will = max(intelligence, 1)
	max_perception = max(intelligence, 1)
	basic_speed = float(dexterity + health) / 4.0
	basic_move = max(int(basic_speed), 1)
	current_hp = clamp(current_hp, -max_hp * 5, max_hp)
	current_fp = clamp(current_fp, -max_fp, max_fp)
	current_will = max_will
	current_perception = max_perception


func full_restore() -> void:
	current_hp = max_hp
	current_fp = max_fp
	current_will = max_will
	current_perception = max_perception


func get_dodge() -> int:
	return 3 + int(basic_speed)


func initialize_for_role(role_type: String) -> void:
	match role_type:
		"baron", "mayor":
			strength = 11
			dexterity = 10
			intelligence = 13
			health = 11
		"inquisition", "inquisitor":
			strength = 12
			dexterity = 11
			intelligence = 12
			health = 12
		"sheriff":
			strength = 12
			dexterity = 12
			intelligence = 11
			health = 12
		"garrison", "soldier":
			strength = 13
			dexterity = 11
			intelligence = 9
			health = 12
		"bishop", "priest":
			strength = 8
			dexterity = 9
			intelligence = 13
			health = 10
		"treasurer":
			strength = 9
			dexterity = 10
			intelligence = 13
			health = 10
		"merchant":
			strength = 9
			dexterity = 11
			intelligence = 12
			health = 10
		"cultist":
			strength = 9
			dexterity = 12
			intelligence = 12
			health = 10
		_:
			strength = randi() % 5 + 8
			dexterity = randi() % 5 + 8
			intelligence = randi() % 5 + 8
			health = randi() % 5 + 8
	recalculate_all()
	full_restore()


func get_health_state() -> String:
	if current_hp <= -max_hp:
		return "dead"
	if current_hp <= 0:
		return "dying"
	if float(current_hp) / float(max_hp) <= 0.33:
		return "unconscious"
	if float(current_hp) / float(max_hp) <= 0.5:
		return "reeling"
	return "healthy"


func get_health_description() -> String:
	match get_health_state():
		"dead":
			return "💀 Мёртв"
		"dying":
			return "🩸 Умирает"
		"unconscious":
			return "😵 Без сознания"
		"reeling":
			return "🤕 Ранен"
		_:
			return "💚 Здоров"


func take_damage(amount: int, damage_type: String = "crushing") -> Dictionary:
	var actual := amount
	var fp_damage := 0
	match damage_type:
		"burning":
			actual = max(int(amount * 0.5), 1)
		"crushing":
			actual = amount
		"cutting":
			actual = int(round(amount * 1.5))
		"impaling":
			actual = int(round(amount * 2.0))
		"toxic":
			fp_damage = amount
			current_fp -= amount
			return {
				"damage": 0,
				"fp_damage": fp_damage,
				"killing_blow": false,
				"new_hp": current_hp,
				"state": get_health_state(),
			}
	current_hp -= actual
	return {
		"damage": actual,
		"fp_damage": 0,
		"killing_blow": check_death(),
		"new_hp": current_hp,
		"state": get_health_state(),
	}


func heal(amount: int) -> void:
	current_hp = clamp(current_hp + amount, -max_hp * 5, max_hp)


func restore_fatigue(amount: int) -> void:
	current_fp = clamp(current_fp + amount, -max_fp, max_fp)


func use_fatigue(amount: int) -> bool:
	if current_fp >= amount:
		current_fp -= amount
		return true
	return false


func check_death() -> bool:
	return current_hp <= -max_hp


func get_summary() -> String:
	return "ST %d  DX %d  IQ %d  HT %d\nHP %d/%d  Воля %d  Воспр. %d  Укл. %d\n%s" % [
		strength, dexterity, intelligence, health,
		current_hp, max_hp, current_will, current_perception, get_dodge(),
		get_health_description(),
	]


func get_data() -> Dictionary:
	return {
		"strength": strength,
		"dexterity": dexterity,
		"intelligence": intelligence,
		"health": health,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"max_fp": max_fp,
		"current_fp": current_fp,
		"max_will": max_will,
		"current_will": current_will,
		"max_perception": max_perception,
		"current_perception": current_perception,
		"basic_speed": basic_speed,
		"basic_move": basic_move,
	}


func apply_data(data: Dictionary) -> void:
	strength = int(data.get("strength", 10))
	dexterity = int(data.get("dexterity", 10))
	intelligence = int(data.get("intelligence", 10))
	health = int(data.get("health", 10))
	recalculate_all()
	current_hp = int(data.get("current_hp", max_hp))
	current_fp = int(data.get("current_fp", max_fp))
	current_will = int(data.get("current_will", max_will))
	current_perception = int(data.get("current_perception", max_perception))
