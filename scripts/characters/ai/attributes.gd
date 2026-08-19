## GURPS Атрибуты и характеристики NPC
class_name GURPSAttributes
extends Node

# ===== ОСНОВНЫЕ АТРИБУТЫ (GURPS) =====

# Базовые атрибуты (обычно 7-15 для людей)
var strength: int = 10        # ST - Сила
var dexterity: int = 10        # DX - Ловкость
var intelligence: int = 10    # IQ - Интеллект
var health: int = 10          # HT - Здоровье

# ===== ВЫЧИСЛЯЕМЫЕ ХАРАКТЕРИСТИКИ =====

# Очки здоровья (HP)
var max_hp: int = 10
var current_hp: int = 10

# Очки усталости (FP)
var max_fp: int = 10
var current_fp: int = 10

# Воля (Will) - обычно = IQ
var max_will: int = 10
var current_will: int = 10

# Восприятие (Perception) - обычно = IQ
var max_perception: int = 10
var current_perception: int = 10

# Базовая скорость (Basic Speed)
var basic_speed: float = 5.0

# Базовая скорость движения (Basic Move)
var basic_move: int = 5

# ===== КОНСТАНТЫ GURPS =====

const BASE_HP_PER_ST: int = 1       # +1 HP за каждую единицу ST
const BASE_FP_PER_HT: int = 1       # +1 FP за каждую единицу HT
const WILL_PER_IQ: int = 1          # Will = IQ
const PER_PER_IQ: int = 1           # Perception = IQ
const SPEED_FORMULA: float = (DEX + HT) / 4.0
const MOVE_FORMULA: int = 5         # Базовая формула

# Пороги состояния здоровья
const HEALTH_THRESHOLDS = {
	"dead": -1,           # < 0 HP = смерть
	"dying": 0,          # 0 HP = умирает
	"unconscious": 3,     # < 1/3 HP = без сознания
	"reeling": 5,        # < 1/2 HP = пошатывается
	"healthy": 999       # > 1/2 HP = здоров
}

func _init():
	recalculate_all()

## Пересчитать все характеристики
func recalculate_all() -> void:
	max_hp = strength * BASE_HP_PER_ST + health
	max_fp = health * BASE_FP_PER_HT
	max_will = intelligence * WILL_PER_IQ
	max_perception = intelligence * PER_PER_IQ
	basic_speed = float(dexterity + health) / 4.0
	basic_move = int(basic_speed)
	
	# Текущие значения не могут превышать максимальные
	current_hp = clamp(current_hp, -max_hp, max_hp)
	current_fp = clamp(current_fp, -max_fp, max_fp)

## Инициализация для роли
func initialize_for_role(role_type: String) -> void:
	match role_type:
		"baron":
			strength = 11
			dexterity = 10
			intelligence = 12
			health = 11
		"inquisition":
			strength = 12
			dexterity = 11
			intelligence = 11
			health = 12
		"garrison":
			strength = 12
			dexterity = 10
			intelligence = 9
			health = 12
		"bishop":
			strength = 8
			dexterity = 9
			intelligence = 13
			health = 10
		"treasurer":
			strength = 9
			dexterity = 10
			intelligence = 12
			health = 10
		"cultist":
			strength = 9
			dexterity = 11
			intelligence = 11
			health = 10
		_:
			# Случайные характеристики для жителей
			strength = randi() % 5 + 8   # 8-12
			dexterity = randi() % 5 + 8
			intelligence = randi() % 5 + 8
			health = randi() % 5 + 8
	
	recalculate_all()
	current_hp = max_hp
	current_fp = max_fp
	current_will = max_will
	current_perception = max_perception

## Получить состояние здоровья
func get_health_state() -> String:
	var hp_ratio = float(current_hp) / float(max_hp)
	
	if current_hp <= HEALTH_THRESHOLDS.dead:
		return "dead"
	elif current_hp <= HEALTH_THRESHOLDS.dying:
		return "dying"
	elif hp_ratio <= 0.33:
		return "unconscious"
	elif hp_ratio <= 0.5:
		return "reeling"
	else:
		return "healthy"

## Получить описание состояния
func get_health_description() -> String:
	var state = get_health_state()
	match state:
		"dead": return "💀 Мёртв"
		"dying": return "🩸 Умирает"
		"unconscious": return "😵 Без сознания"
		"reeling": return "🤕 Ранен"
		"healthy": return "💚 Здоров"
	return ""

## Наносить урон
func take_damage(amount: int, damage_type: String = "basic") -> Dictionary:
	var actual_damage = amount
	
	# Типы урона GURPS
	match damage_type:
		"burning":   # Ожог
			actual_damage = int(amount * 0.5)
		"crushing":  # Дробящий
			actual_damage = amount
		"cutting":   # Рубящий
			actual_damage = int(amount * 1.5)
		"impaling":  # Проникающий
			actual_damage = int(amount * 1.5)
		"toxic":     # Токсический
			current_fp -= amount
			return {"damage": 0, "fp_damage": amount, "killing_blow": false}
	
	current_hp -= actual_damage
	
	var killing_blow = current_hp <= HEALTH_THRESHOLDS.dead
	
	return {
		"damage": actual_damage,
		"fp_damage": 0,
		"killing_blow": killing_blow,
		"new_hp": current_hp,
		"state": get_health_state()
	}

## Лечить
func heal(amount: int) -> void:
	current_hp = clamp(current_hp + amount, -max_hp, max_hp)

## Восстановить усталость
func restore_fatigue(amount: int) -> void:
	current_fp = clamp(current_fp + amount, -max_fp, max_fp)

## Использовать усталость
func use_fatigue(amount: int) -> bool:
	if current_fp >= amount:
		current_fp -= amount
		return true
	return false

## Проверить смерть
func check_death() -> bool:
	return current_hp <= HEALTH_THRESHOLDS.dead

## Получить все данные для сохранения
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
