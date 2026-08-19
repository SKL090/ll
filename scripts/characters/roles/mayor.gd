## Роль Мэра
class_name MayorRole
extends Role

# Мэр работает в ратуше
@export var town_hall_position: Vector2 = Vector2(500, 300)

func _init():
	role_type = "mayor"
	work_start_hour = 8.0
	work_end_hour = 18.0
	sleep_start_hour = 22.0
	sleep_end_hour = 6.0

func initialize(npc: BaseNPC) -> void:
	super.initialize(npc)
	work_position = town_hall_position
	home_position = Vector2(600, 250)  # Дом мэра (большой, красивый)

func update(delta: float) -> void:
	super.update(delta)
	
	# Мэр получает пассивный доход от налогов
	GameManager.city_treasury += delta * 0.5  # Немного каждую секунду

func get_current_behavior() -> String:
	var time = TimeSystem.current_time
	
	# Приоритет потребностей
	var priority_need = owner_npc.need_system.get_priority_need()
	if priority_need != "":
		return priority_need
	
	# Утро: подготовка
	if time >= 6.0 and time < 8.0:
		return "morning_routine"
	# Рабочий день
	elif time >= 8.0 and time < 12.0:
		return "office_work"
	# Обед
	elif time >= 12.0 and time < 14.0:
		return "lunch"
	# Послеобеденная работа
	elif time >= 14.0 and time < 18.0:
		return "office_work"
	# Вечерние мероприятия
	elif time >= 18.0 and time < 22.0:
		return "social_event"
	# Ночь
	else:
		return "sleep"

func get_target_position() -> Vector2:
	match get_current_behavior():
		"morning_routine":
			return home_position  # Собирается дома
		"office_work":
			return town_hall_position  # Работает в ратуше
		"lunch":
			return Vector2(550, 320)  # Обед в центре
		"social_event":
			return _get_social_location()
		"sleep":
			return home_position
	return home_position

func _get_social_location() -> Vector2:
	# Мэр ходит по городу, показывая себя
	var locations = [
		Vector2(400, 300),
		Vector2(600, 400),
		Vector2(500, 250),
	]
	return locations[randi() % locations.size()]

func get_description() -> String:
	return "Мэр города. Контролирует городской бюджет. Его любят и ненавидят."
