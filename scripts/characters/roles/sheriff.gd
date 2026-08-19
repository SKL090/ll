## Роль Шерифа
class_name SheriffRole
extends Role

# Локации шерифа
@export var police_station_position: Vector2 = Vector2(300, 350)
@export var patrol_route: Array[Vector2] = []

# Состояние расследования
var investigating: bool = false
var investigation_target: int = -1

# Настройки
const SUSPICION_CHECK_RANGE: float = 150.0
const EVIDENCE_GAIN_PER_PATROL: float = 3.0

func _init():
	role_type = "sheriff"
	work_start_hour = 9.0
	work_end_hour = 18.0
	sleep_start_hour = 22.0
	sleep_end_hour = 6.0
	
	patrol_route = [
		Vector2(300, 350),
		Vector2(500, 350),
		Vector2(600, 300),
		Vector2(400, 400),
		Vector2(300, 400),
	]

func initialize(npc: BaseNPC) -> void:
	super.initialize(npc)
	work_position = police_station_position
	home_position = Vector2(250, 380)
	
	# Подключаемся к сигналам расследования
	if GameManager.investigation_system:
		GameManager.investigation_system.connect("investigation_started", _on_investigation_started)
		GameManager.investigation_system.connect("evidence_found", _on_evidence_found)
		GameManager.investigation_system.connect("investigation_solved", _on_investigation_solved)

func update(delta: float) -> void:
	super.update(delta)
	
	# Проверяем подозрительную активность ночью
	if TimeSystem.is_nighttime():
		_check_for_suspicious_activity()

func _check_for_suspicious_activity() -> void:
	for npc in GameManager.npcs:
		if npc == owner_npc:
			continue
		if not npc.is_alive:
			continue
		
		var dist = owner_npc.global_position.distance_to(npc.global_position)
		if dist > SUSPICION_CHECK_RANGE:
			continue
		
		var memories = npc.memory_system.get_memories_of_type(MemorySystem.EventType.SUSPICIOUS)
		if memories.size() > 0:
			var suspicion = memories[0]
			var suspect = GameManager.get_npc_by_id(suspicion.target_id)
			if suspect:
				owner_npc.memory_system.add_memory(
					MemorySystem.EventType.SUSPICIOUS,
					suspect.npc_id,
					"%s вёл себя подозрительно ночью" % suspect.npc_name
				)
				
				if GameManager.investigation_system:
					var inv = GameManager.investigation_system.get_investigation_about(suspicion.target_id)
					if inv:
						GameManager.investigation_system.add_evidence(
							inv,
							"%s видел подозрительное поведение %s" % [owner_npc.npc_name, suspect.npc_name],
							EVIDENCE_GAIN_PER_PATROL * 3
						)

func get_current_behavior() -> String:
	var time = TimeSystem.current_time
	var is_night = TimeSystem.is_nighttime()
	
	var priority_need = owner_npc.need_system.get_priority_need()
	if priority_need != "":
		return priority_need
	
	# Ночное патрулирование
	if is_night and (time >= 22.0 or time < 4.0):
		return "night_patrol"
	
	# Активные расследования
	if GameManager.investigation_system and GameManager.investigation_system.active_investigations.size() > 0:
		return "investigate"
	
	# Рабочее время
	if time >= 9.0 and time < 12.0:
		return "office_work"
	elif time >= 12.0 and time < 14.0:
		return "patrol_day"
	elif time >= 14.0 and time < 18.0:
		return "receive_complaints"
	elif time >= 18.0 and time < 22.0:
		return "patrol_evening"
	elif time >= 20.0 and time < 22.0:
		return "prepare_patrol"
	
	return "sleep"

func get_target_position() -> Vector2:
	match get_current_behavior():
		"office_work":
			return police_station_position
		"patrol_day":
			return _get_patrol_point()
		"patrol_evening":
			return _get_patrol_point()
		"night_patrol":
			return _get_suspicious_location()
		"investigate":
			return _get_investigation_target_position()
		"receive_complaints":
			return police_station_position
		"prepare_patrol":
			return police_station_position
		"sleep":
			return home_position
	return home_position

func _get_patrol_point() -> Vector2:
	if patrol_route.is_empty():
		return Vector2(500, 350)
	return patrol_route[randi() % patrol_route.size()]

func _get_suspicious_location() -> Vector2:
	var suspicious_places = [
		Vector2(700, 450),
		Vector2(100, 450),
		Vector2(500, 100),
		Vector2(800, 300),
		Vector2(900, 500),
		Vector2(150, 500),
	]
	return suspicious_places[randi() % suspicious_places.size()]

func _get_investigation_target_position() -> Vector2:
	if GameManager.investigation_system:
		for inv in GameManager.investigation_system.active_investigations:
			if inv.is_active and inv.culprit_id != -1:
				var target = GameManager.get_npc_by_id(inv.culprit_id)
				if target:
					return target.global_position
	return police_station_position

func start_investigation(target_id: int) -> void:
	investigating = true
	investigation_target = target_id
	print("🔍 Шериф начал расследование против ", target_id)

func finish_investigation(success: bool) -> void:
	investigating = false
	investigation_target = -1
	
	if success:
		print("✅ Расследование завершено успешно!")
	else:
		print("❌ Расследование провалено!")

func has_enough_evidence() -> bool:
	if GameManager.investigation_system:
		for inv in GameManager.investigation_system.active_investigations:
			if inv.is_active:
				return inv.evidence >= 60.0
	return false

func _on_investigation_started(investigation: InvestigationSystem.Investigation) -> void:
	print("🚨 Шериф приступил к расследованию убийства %s" % investigation.victim_name)

func _on_evidence_found(investigation: InvestigationSystem.Investigation, evidence_type: String) -> void:
	print("📋 Шериф собрал улику: %s (всего: %.0f%%)" % [evidence_type, investigation.evidence])

func _on_investigation_solved(investigation: InvestigationSystem.Investigation, culprit_id: int) -> void:
	var culprit = GameManager.get_npc_by_id(culprit_id)
	if culprit:
		print("⚖️ ДЕЛО РАСКРЫТО! %s признан виновным в убийстве %s" % [culprit.npc_name, investigation.victim_name])

func get_description() -> String:
	var active_inv = 0
	if GameManager.investigation_system:
		active_inv = GameManager.investigation_system.active_investigations.size()
	return "Шериф. Защищает город, патрулирует ночью. Расследований: %d" % active_inv
