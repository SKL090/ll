## GURPS Система Проверок и Бросков
class_name GURPSSystem
extends Node

signal roll_made(result: Dictionary)
signal critical_success(roll: int, target: int)
signal critical_failure(roll: int, target: int)

# ===== КОНСТАНТЫ GURPS =====

# Сложность по умолчанию
const DIFFICULTY = {
	"trivial": 15,      # Тривиально (это могут все)
	"easy": 12,        # Легко
	"average": 10,     # Средне
	"hard": 8,         # Сложно
	"very_hard": 6,    # Очень сложно
	"荒谬": 4,          # Сверхъестественно
}

# ===== БРОСОК КУБИКОВ =====

## Бросок 3d6 (базовый бросок GURPS)
func roll_3d6(modifier: int = 0) -> int:
	var roll = randi() % 6 + 1 + randi() % 6 + 1 + randi() % 6 + 1
	return roll + modifier

## Полный бросок с результатом
func make_roll(base_value: int, modifier: int = 0, description: String = "") -> Dictionary:
	var roll = roll_3d6()
	var target = base_value - modifier  # Чем выше навык, тем легче
	var effective_target = target
	var result_roll = roll
	
	# В GURPS бросок СЫРОЙ vs ЦЕЛЬ
	# roll <= target = успех
	var success = roll <= effective_target
	var critical = false
	var fumble = false
	
	# Критический успех: бросок 3-4 при средней сложности
	if roll <= 4 and not success:
		critical = true
		success = true
	# Критический провал: бросок 17-18
	elif roll >= 17:
		fumble = true
		success = false
	
	var margin = abs(target - roll) if success else (roll - target)
	
	var result = {
		"roll": result_roll,
		"target": effective_target,
		"success": success,
		"critical": critical,
		"fumble": fumble,
		"margin": margin,
		"description": description,
		"base_value": base_value,
		"modifier": modifier,
		"effective_target": effective_target,
	}
	
	emit_signal("roll_made", result)
	
	if critical:
		emit_signal("critical_success", roll, effective_target)
	elif fumble:
		emit_signal("critical_failure", roll, effective_target)
	
	return result

## Проверка навыка (Skill Check)
func skill_check(skill_level: int, difficulty_modifier: int = 0, description: String = "") -> Dictionary:
	return make_roll(skill_level, difficulty_modifier, description)

## Проверка атрибута (Attribute Check)
func attribute_check(attribute_value: int, difficulty_modifier: int = 0, description: String = "") -> Dictionary:
	return make_roll(attribute_value, difficulty_modifier, description)

# ===== МОДИФИКАТОРЫ =====

## Модификатор обстоятельств (Circumstance Modifier)
enum CircumstanceMod {
	TERRIBLE = -5,      # Ужасно
	POOR = -3,          # Плохо
	FAIR = -1,          # Справедливо
	GOOD = +1,          # Хорошо
	EXCELLENT = +3,     # Отлично
	PERFECT = +5,       # Идеально
}

## Модификатор расстояния для атаки
func range_modifier(distance: float, optimal_range: float) -> int:
	var ratio = distance / optimal_range
	
	if ratio <= 0.5:
		return +2  # Очень близко
	elif ratio <= 1.0:
		return +0  # Оптимальная дистанция
	elif ratio <= 2.0:
		return -1  # Далеко
	elif ratio <= 3.0:
		return -2  # Очень далеко
	else:
		return -3  # Предельная дистанция

## Модификатор освещения
func lighting_modifier(lighting: String) -> int:
	match lighting:
		"bright": return +0
		"normal": return +0
		"dim": return -1
		"dark": return -3
		"pitch_black": return -5
	return +0

## Модификатор видимости
func visibility_modifier(target_visible: bool, partial: bool = false) -> int:
	if target_visible and not partial:
		return +0
	elif partial:
		return -2
	else:
		return -5

# ===== ОПИСАНИЕ РЕЗУЛЬТАТА =====

## Получить текстовое описание результата
func describe_result(result: Dictionary) -> String:
	var roll = result["roll"]
	var target = result["target"]
	var success = result["success"]
	var critical = result["critical"]
	var fumble = result["fumble"]
	
	var text = "Бросок: %d vs %d" % [roll, target]
	
	if critical:
		text += " 🎯 КРИТИЧЕСКИЙ УСПЕХ!"
	elif fumble:
		text += " 💀 КРИТИЧЕСКИЙ ПРОВАЛ!"
	elif success:
		text += " ✅ Успех (запас: %d)" % result["margin"]
	else:
		text += " ❌ Провал (превышение: %d)" % result["margin"]
	
	return text

# ===== ИНТЕГРАЦИЯ С NPC =====

## Проверка восприятия NPC
func perception_check(npc: BaseNPC, difficulty: int = 10) -> Dictionary:
	var gurps = npc.gurps if npc.has("gurps") else null
	var perception = gurps.current_perception if gurps else 10
	
	return make_roll(perception, 0, "Восприятие: " + npc.npc_name)

## Проверка воли NPC
func will_check(npc: BaseNPC, difficulty: int = 10) -> Dictionary:
	var gurps = npc.gurps if npc.has("gurps") else null
	var will = gurps.current_will if gurps else 10
	
	return make_roll(will, 0, "Воля: " + npc.npc_name)

## Проверка ловкости NPC (уклонение)
func dodge_check(npc: BaseNPC) -> Dictionary:
	var gurps = npc.gurps if npc.has("gurps") else null
	if gurps:
		var dodge = 8 + int(gurps.basic_speed)  # Базовый dodge
		return make_roll(dodge, 0, "Уклонение: " + npc.npc_name)
	return {"success": false, "roll": 18, "description": "Нет данных о NPC"}
