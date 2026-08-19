## Роль Барона (заменяет Мэра)
class_name BaronRole
extends Role

# Замок
@export var castle_position: Vector2 = Vector2(560, 200)
@export var throne_room: Vector2 = Vector2(540, 220)

# Подчинённые
var garrison_leader: BaseNPC = null
var treasurer: BaseNPC = null

# Влияние
var authority: float = 100.0  # Авторитет барона
var taxation_rate: float = 0.2  # 20% налог

func _init():
	role_type = "baron"
	work_start_hour = 7.0
	work_end_hour = 19.0
	sleep_start_hour = 22.0
	sleep_end_hour = 6.0

func initialize(npc: BaseNPC) -> void:
	super.initialize(npc)
	work_position = throne_room
	home_position = castle_position
	
	# Находим подчинённых
	_find_subordinates()

func _find_subordinates() -> void:
	for npc in GameManager.npcs:
		if npc.role is GarrisonSoldierRole:
			garrison_leader = npc
		elif npc.role is TreasurerRole:
			treasurer = npc

func update(delta: float) -> void:
	super.update(delta)
	
	# Барон получает пассивный доход
	GameManager.city_treasury += delta * 0.8
	
	# Проверяем угрозы авторитету
	_check_authority()

func _check_authority() -> void:
	# Каждый день проверяем уровень порядка
	if GameManager.event_system:
		var order = GameManager.event_system.public_order
		if order < 30:
			authority = clamp(authority - 5.0, 0.0, 100.0)
			# Приказ гарнизону
			_order_garrison("patrol_aggressive")

func _order_garrison(order_type: String) -> void:
	if garrison_leader:
		match order_type:
			"patrol_aggressive":
				print("⚔️ Барон приказал усилить патрулирование")
			"arrest_rioters":
				print("⚔️ Барон приказал арестовать бунтовщиков")

func get_current_behavior() -> String:
	var time = TimeSystem.current_time
	
	var priority_need = owner_npc.need_system.get_priority_need()
	if priority_need != "":
		return priority_need
	
	# Утро - подготовка
	if time >= 6.0 and time < 8.0:
		return "morning_preparation"
	# Утренняя аудиенция
	elif time >= 8.0 and time < 10.0:
		return "audience"
	# Работа с казначеем
	elif time >= 10.0 and time < 12.0:
		return "meet_treasurer"
	# Обед
	elif time >= 12.0 and time < 14.0:
		return "lunch"
	# Послеобеденные дела
	elif time >= 14.0 and time < 18.0:
		return "admin_work"
	# Вечерние мероприятия
	elif time >= 18.0 and time < 22.0:
		return "evening_entertainment"
	
	return "sleep"

func get_target_position() -> Vector2:
	match get_current_behavior():
		"morning_preparation":
			return castle_position
		"audience":
			return throne_room
		"meet_treasurer":
			return Vector2(520, 250)  # Рядом с казначеем
		"lunch":
			return castle_position
		"admin_work":
			return throne_room
		"evening_entertainment":
			return _get_entertainment_location()
		"sleep":
			return castle_position
	return castle_position

func _get_entertainment_location() -> Vector2:
	var locations = [
		Vector2(500, 350),
		Vector2(550, 400),
		Vector2(480, 380),
	]
	return locations[randi() % locations.size()]

## Издать указ
func issue_decree(decree_type: String) -> void:
	match decree_type:
		"tax_increase":
			taxation_rate = clamp(taxation_rate + 0.05, 0.0, 0.5)
			print("📜 Барон издал указ о повышении налогов!")
		"tax_decrease":
			taxation_rate = clamp(taxation_rate - 0.05, 0.0, 0.5)
			print("📜 Барон издал указ о снижении налогов!")
		"hunt_cultists":
			# Приказ инквизиции
			print("📜 Барон объявил охоту на еретиков!")
			authority = clamp(authority - 10.0, 0.0, 100.0)  # Недовольны
		"festival":
			EventSystem.increase_order(20.0) if EventSystem else None
			print("📜 Барон объявил праздник!")

## Назначить наказание
func assign_punishment(criminal: BaseNPC, punishment: String) -> void:
	match punishment:
		"execution":
			criminal.die(owner_npc)
			authority = clamp(authority + 5.0, 0.0, 100.0)  # Уважают
		"imprisonment":
			if GameManager.prison_system:
				GameManager.prison_system.send_to_prison(criminal, 10, "Государственное преступление")
		"fine":
			var fine_amount = criminal.wealth * 0.3
			criminal.wealth -= fine_amount
			GameManager.city_treasury += fine_amount

func get_description() -> String:
	var status = "Властвует"
	if authority < 50:
		status = "Под угрозой"
	if authority < 25:
		status = "Слаб"
	return "Барон. Владыка города. Авторитет: %.0f%%. Налог: %.0f%%" % [authority, taxation_rate * 100]
