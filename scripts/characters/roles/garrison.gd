## Роль Солдата Гарнизона
class_name GarrisonSoldierRole
extends Role

# Казарма
@export var barracks_position: Vector2 = Vector2(200, 300)

# Статус
var is_on_duty: bool = true
var patrol_mode: String = "normal"  # normal, aggressive, alert

# Настройки
const PATROL_POINTS: Array[Vector2] = [
	Vector2(200, 350),
	Vector2(300, 350),
	Vector2(400, 300),
	Vector2(500, 350),
	Vector2(600, 280),  # Замок
	Vector2(450, 400),
	Vector2(300, 400),
]

func _init():
	role_type = "garrison"
	work_start_hour = 6.0
	work_end_hour = 22.0
	sleep_start_hour = 23.0
	sleep_end_hour = 5.0

func initialize(npc: BaseNPC) -> void:
	super.initialize(npc)
	work_position = barracks_position
	home_position = Vector2(180, 320)
	assigned_zone = _get_random_patrol_zone()

func _get_random_patrol_zone() -> Vector2:
	var zones = [
		Vector2(200, 350),
		Vector2(500, 350),
		Vector2(600, 280),
	]
	return zones[randi() % zones.size()]

func update(delta: float) -> void:
	super.update(delta)
	
	# Проверяем угрозы Baron
	_check_for_threats()

func _check_for_threats() -> void:
	# Проверяем Baron
	var baron = _get_baron()
	if baron and not baron.is_alive:
		# Барон мёртв - солдаты теряют смысл
		print("⚔️ Солдаты без лидера!")
		is_on_duty = false

func _get_baron() -> BaseNPC:
	for npc in GameManager.npcs:
		if npc.role is BaronRole:
			return npc
	return null

func get_current_behavior() -> String:
	var time = TimeSystem.current_time
	var is_night = TimeSystem.is_nighttime()
	
	var priority_need = owner_npc.need_system.get_priority_need()
	if priority_need != "":
		return priority_need
	
	if not is_on_duty:
		return "rest"
	
	# Ночью усиленный режим
	if is_night:
		if patrol_mode == "aggressive":
			return "night_patrol_aggressive"
		else:
			return "night_patrol"
	
	# Дневное патрулирование
	if time >= 6.0 and time < 8.0:
		return "morning_drill"
	elif time >= 8.0 and time < 18.0:
		return "patrol"
	elif time >= 18.0 and time < 22.0:
		return "evening_patrol"
	
	return "rest"

func get_target_position() -> Vector2:
	match get_current_behavior():
		"morning_drill":
			return barracks_position
		"patrol", "night_patrol", "night_patrol_aggressive":
			return _get_next_patrol_point()
		"evening_patrol":
			return _get_next_patrol_point()
		"guard_baron":
			var baron = _get_baron()
			if baron:
				return baron.global_position
		"rest":
			return home_position
	return home_position

func _get_next_patrol_point() -> Vector2:
	# Патрулируем зону или случайную точку
	var zone_range = 50.0
	
	if patrol_mode == "aggressive":
		# Агрессивный патруль - больше точек
		return PATROL_POINTS[randi() % PATROL_POINTS.size()]
	else:
		# Нормальный патруль - зона
		return assigned_zone + Vector2(
			randf_range(-zone_range, zone_range),
			randf_range(-zone_range, zone_range)
		)

## Охранять барона
func guard_baron() -> void:
	var baron = _get_baron()
	if baron:
		# Идём к барону
		owner_npc.state_machine.move_to_node(baron)

## Задержать подозрительного
func arrest_suspect(suspect: BaseNPC) -> void:
	if not suspect.is_alive:
		return
	
	print("⚔️ %s арестован гарнизоном!" % suspect.npc_name)
	
	# Проверяем есть ли инквизиция
	var inquisitor = _get_inquisitor()
	if inquisitor:
		# Передаём инквизиции
		var rel = suspect.relationship_graph.get_relationship(suspect.npc_id, inquisitor.npc_id)
		rel.hate += 20.0
	
	# Отправляем в тюрьму
	if GameManager.prison_system:
		GameManager.prison_system.send_to_prison(suspect, 5, "Нарушение порядка")

## Проверить подозрительную активность
func check_suspicious_activity() -> void:
	for npc in GameManager.npcs:
		if npc == owner_npc:
			continue
		
		# Проверяем память NPC
		var memories = npc.memory_system.get_memories_of_type(MemorySystem.EventType.SUSPICIOUS)
		if memories.size() > 0:
			# Есть подозрительные действия
			var dist = owner_npc.global_position.distance_to(npc.global_position)
			if dist < 100:  # Рядом
				if patrol_mode == "aggressive":
					_arrest_if_needed(npc)

func _arrest_if_needed(npc: BaseNPC) -> void:
	# Шанс ареста зависит от улик
	var memories = npc.memory_system.get_memories_of_type(MemorySystem.EventType.SUSPICIOUS)
	var arrest_chance = float(memories.size()) * 20.0
	
	if randf() * 100.0 < arrest_chance:
		arrest_suspect(npc)

func _get_inquisitor() -> BaseNPC:
	for npc in GameManager.npcs:
		if npc.role is InquisitionRole:
			return npc
	return null

## Сменить режим патруля
func set_patrol_mode(mode: String) -> void:
	patrol_mode = mode
	match mode:
		"aggressive":
			print("⚔️ %s перешёл в агрессивный режим!" % owner_npc.npc_name)
		"alert":
			print("⚔️ %s настороже!" % owner_npc.npc_name)
		"normal":
			print("⚔️ %s патрулирует нормально." % owner_npc.npc_name)

func get_description() -> String:
	var mode_icon = "🔵"
	if patrol_mode == "aggressive":
		mode_icon = "🔴"
	elif patrol_mode == "alert":
		mode_icon = "🟡"
	return "Солдат гарнизона. Режим: %s%s" % [mode_icon, patrol_mode]
