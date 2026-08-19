## Система потребностей NPC
class_name NeedSystem
extends Node

signal need_changed(need_name: String, value: float)
signal critical_need(need_name: String)

# Потребности (все от 0 до 100)
var hunger: float = 80.0       # Голод (0 = голодный)
var energy: float = 100.0      # Энергия (0 = усталый)
var social: float = 60.0       # Социальность (0 = изолирован)
var safety: float = 100.0      # Безопасность (0 = в опасности)

# Пороги для критических потребностей
const CRITICAL_THRESHOLD: float = 20.0
const WARNING_THRESHOLD: float = 35.0

# Скорость изменения потребностей
const HUNGER_DECAY_RATE: float = 1.5      # в секунду
const ENERGY_DECAY_RATE_DAY: float = 0.8
const ENERGY_DECAY_RATE_NIGHT: float = 2.5
const SOCIAL_DECAY_RATE: float = 0.3

# Скорость восстановления
const EATING_RATE: float = 15.0          # в секунду
const SLEEPING_RATE: float = 25.0        # в секунду
const SOCIALIZING_RATE: float = 10.0     # в секунду

var _hunger_alerted: bool = false
var _energy_alerted: bool = false
var _social_alerted: bool = false

func _process(delta: float) -> void:
	if GameManager.is_paused:
		return

	var is_night = TimeSystem.is_nighttime()
	_update_hunger(delta)
	_update_energy(delta, is_night)
	_update_social(delta)

func _update_hunger(delta: float) -> void:
	hunger -= HUNGER_DECAY_RATE * delta
	hunger = clamp(hunger, 0.0, 100.0)
	
	if hunger <= CRITICAL_THRESHOLD:
		if not _hunger_alerted:
			_hunger_alerted = true
			emit_signal("critical_need", "hunger")
	else:
		_hunger_alerted = false

	emit_signal("need_changed", "hunger", hunger)

func _update_energy(delta: float, is_night: bool) -> void:
	var decay_rate = ENERGY_DECAY_RATE_DAY if not is_night else ENERGY_DECAY_RATE_NIGHT
	energy -= decay_rate * delta
	energy = clamp(energy, 0.0, 100.0)
	
	if energy <= CRITICAL_THRESHOLD:
		if not _energy_alerted:
			_energy_alerted = true
			emit_signal("critical_need", "energy")
	else:
		_energy_alerted = false

	emit_signal("need_changed", "energy", energy)

func _update_social(delta: float) -> void:
	social -= SOCIAL_DECAY_RATE * delta
	social = clamp(social, 0.0, 100.0)
	
	if social <= CRITICAL_THRESHOLD:
		if not _social_alerted:
			_social_alerted = true
			emit_signal("critical_need", "social")
	else:
		_social_alerted = false

	emit_signal("need_changed", "social", social)

## Есть
func eat(amount: float = EATING_RATE) -> void:
	hunger = clamp(hunger + amount, 0.0, 100.0)
	emit_signal("need_changed", "hunger", hunger)

## Спать
func sleep(amount: float = SLEEPING_RATE) -> void:
	energy = clamp(energy + amount, 0.0, 100.0)
	emit_signal("need_changed", "energy", energy)

## Общаться
func socialize(amount: float = SOCIALIZING_RATE) -> void:
	social = clamp(social + amount, 0.0, 100.0)
	emit_signal("need_changed", "social", social)

## Получить приоритетную потребность для действия
func get_priority_need() -> String:
	if hunger <= WARNING_THRESHOLD:
		return "hunger"
	elif energy <= WARNING_THRESHOLD:
		return "energy"
	elif social <= WARNING_THRESHOLD:
		return "social"
	return ""

## Проверить критическое состояние
func has_critical_need() -> bool:
	return hunger <= CRITICAL_THRESHOLD or energy <= CRITICAL_THRESHOLD

## Все потребности в норме
func is_fulfilled() -> bool:
	return hunger > WARNING_THRESHOLD and energy > WARNING_THRESHOLD and social > WARNING_THRESHOLD

## Сбросить потребности (для нового дня)
func daily_reset() -> void:
	hunger = clamp(hunger - 20.0, 30.0, 100.0)  # Просыпаются немного голодными
	energy = 100.0  # Полностью отдохнувшие
	social = clamp(social - 10.0, 0.0, 100.0)
