## Базовый класс роли NPC
class_name Role
extends Node

# Тип роли
var role_type: String = "resident"

# Настройки роли
@export var work_start_hour: float = 8.0
@export var work_end_hour: float = 18.0
@export var sleep_start_hour: float = 22.0
@export var sleep_end_hour: float = 6.0

# Местоположения
var home_position: Vector2 = Vector2.ZERO
var work_position: Vector2 = Vector2.ZERO
var assigned_zone: Vector2 = Vector2.ZERO

# Владелец
var owner_npc: BaseNPC = null

signal role_updated()

func _init():
	pass

## Инициализация роли
func initialize(npc: BaseNPC) -> void:
	owner_npc = npc

## Обновление роли (вызывается каждый кадр)
func update(delta: float) -> void:
	# Базовое обновление
	pass

## Получить поведение в текущее время
func get_current_behavior() -> String:
	var time = TimeSystem.current_time
	
	# Проверяем критические потребности
	var priority_need = owner_npc.need_system.get_priority_need()
	if priority_need != "":
		return priority_need
	
	# Проверяем время суток
	if _is_sleep_time(time):
		return "sleep"
	elif _is_work_time(time):
		return "work"
	elif _is_social_time(time):
		return "social"
	
	return "wander"

## Проверка времени сна
func _is_sleep_time(time: float) -> bool:
	if sleep_start_hour > sleep_end_hour:
		# Ночной сон (например 22:00 - 6:00)
		return time >= sleep_start_hour or time < sleep_end_hour
	else:
		return time >= sleep_start_hour and time < sleep_end_hour

## Проверка рабочего времени
func _is_work_time(time: float) -> bool:
	return time >= work_start_hour and time < work_end_hour

## Проверка социального времени
func _is_social_time(time: float) -> bool:
	return time >= 18.0 and time < 22.0

## Получить целевую позицию для текущего поведения
func get_target_position() -> Vector2:
	match get_current_behavior():
		"sleep":
			return home_position
		"work":
			return work_position
		"social":
			return _get_social_location()
		"wander":
			return _get_wander_location()
	return home_position

## Получить локацию для социализации
func _get_social_location() -> Vector2:
	# Центр города или случайное место
	return Vector2(500, 350)

## Получить локацию для блуждания
func _get_wander_location() -> Vector2:
	# Случайная позиция в городе
	var city_bounds = Vector2(800, 500)
	return Vector2(randf_range(100, city_bounds.x), randf_range(100, city_bounds.y))

## Проверить, может ли выполнять действие
func can_perform_action(action: String) -> bool:
	return true

## Получить описание роли
func get_description() -> String:
	return role_type
