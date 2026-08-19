## Роль Инквизитора
class_name InquisitionRole
extends Role

# Штаб-квартира
@export var inquisition_office: Vector2 = Vector2(300, 350)

# Состояние
var current_investigation: String = ""  # Тип расследования
var suspects: Array[int] = []
var evidence_against_heresy: float = 0.0

# Настройки
const HERESY_CHECK_INTERVAL: float = 30.0  # Проверка каждые 30 сек
var heresy_check_timer: float = 0.0

func _init():
	role_type = "inquisitor"
	work_start_hour = 8.0
	work_end_hour = 20.0
	sleep_start_hour = 22.0
	sleep_end_hour = 5.0

func initialize(npc: BaseNPC) -> void:
	super.initialize(npc)
	work_position = inquisition_office
	home_position = Vector2(280, 380)

func update(delta: float) -> void:
	super.update(delta)
	
	# Периодическая проверка ереси
	heresy_check_timer += delta
	if heresy_check_timer >= HERESY_CHECK_INTERVAL:
		heresy_check_timer = 0.0
		_check_for_heresy()

func _check_for_heresy() -> void:
	# Проверяем культистов иDenunciations
	for npc in GameManager.npcs:
		if npc == owner_npc:
			continue
		
		# Проверяем память о подозрительных действиях
		var suspicious_memories = npc.memory_system.get_memories_of_type(MemorySystem.EventType.SUSPICIOUS)
		if suspicious_memories.size() > 2:
			# Добавляем в список подозреваемых
			if not npc.npc_id in suspects:
				suspects.append(npc.npc_id)

func get_current_behavior() -> String:
	var time = TimeSystem.current_time
	var is_night = TimeSystem.is_nighttime()
	
	var priority_need = owner_npc.need_system.get_priority_need()
	if priority_need != "":
		return priority_need
	
	# Ночью - охота на еретиков
	if is_night and suspects.size() > 0:
		return "hunt_heretics"
	
	# Рабочий день
	if time >= 8.0 and time < 12.0:
		return "office_work"
	elif time >= 12.0 and time < 14.0:
		return "patrol"
	elif time >= 14.0 and time < 18.0:
		return "interrogate"
	elif time >= 18.0 and time < 20.0:
		return "review_denouncements"
	
	return "rest"

func get_target_position() -> Vector2:
	match get_current_behavior():
		"office_work", "interrogate":
			return inquisition_office
		"patrol":
			return _get_patrol_point()
		"hunt_heretics":
			return _get_suspect_location()
		"review_denouncements":
			return inquisition_office
		"rest":
			return home_position
	return home_position

func _get_patrol_point() -> Vector2:
	var points = [
		Vector2(500, 350),  # Центр
		Vector2(600, 300),  # Барон
		Vector2(550, 400),  # Церковь
		Vector2(700, 450),  # Окраина
	]
	return points[randi() % points.size()]

func _get_suspect_location() -> Vector2:
	if suspects.size() == 0:
		return inquisition_office
	
	var suspect_id = suspects[randi() % suspects.size()]
	var suspect = GameManager.get_npc_by_id(suspect_id)
	if suspect:
		return suspect.global_position
	
	return inquisition_office

## Провести допрос
func interrogate(target_id: int) -> void:
	var target = GameManager.get_npc_by_id(target_id)
	if not target:
		return
	
	# Проверяем еретические связи
	var heretical_actions = 0
	
	var memories = target.memory_system.get_memories_of_type(MemorySystem.EventType.SUSPICIOUS)
	heretical_actions += memories.size()
	
	# Проверяем связи с cultists
	if GameManager.cult_system:
		if GameManager.cult_system.is_cultist(target_id):
			heretical_actions += 5
	
	# На основе действий - решение
	if heretical_actions >= 5:
		# Обвинение в ереси
		_accuse_of_heresy(target)
	elif heretical_actions >= 2:
		# Допрос
		evidence_against_heresy += 10.0
	else:
		# Невиновен
		if target_id in suspects:
			suspects.erase(target_id)

## Обвинить в ереси
func _accuse_of_heresy(target: BaseNPC) -> void:
	print("🔥 ИНКВИЗИЦИЯ: %s обвинён в ереси!" % target.npc_name)
	
	# Шанс сожжения зависит от улик
	var burn_chance = evidence_against_heresy + 30.0
	
	if randf() * 100.0 < burn_chance:
		# Сожжение на костре!
		_burn_heretic(target)
	else:
		# Тюрьма
		_send_to_inquisition_prison(target)

## Сжечь еретика
func _burn_heretic(target: BaseNPC) -> void:
	print("🔥🔥🔥 %s сожжён как еретик!" % target.npc_name)
	
	# Создаём Memory у всех
	for npc in GameManager.npcs:
		npc.memory_system.add_memory(
			MemorySystem.EventType.MURDER,
			target.npc_id,
			"Сожжён инквизицией за ересь"
		)
		
		# Отношения
		npc.relationship_graph.modify_relationship(
			npc.npc_id,
			owner_npc.npc_id,
			trust_delta: 10.0,
			hate_delta: -5.0
		)
	
	# Удаляем из подозреваемых
	if target.npc_id in suspects:
		suspects.erase(target.npc_id)
	
	# NPC умирает
	target.die(owner_npc)
	
	# Увеличиваем влияние церкви
	church_influence = clamp(church_influence + 10.0, 0.0, 100.0)

## Отправить в тюрьму инквизиции
func _send_to_inquisition_prison(target: BaseNPC) -> void:
	if GameManager.prison_system:
		GameManager.prison_system.send_to_prison(target, 10, "Ересь")
	
	if target.npc_id in suspects:
		suspects.erase(target.npc_id)

## Получить список подозреваемых
func get_suspects() -> Array[int]:
	return suspects

## Добавить донос
func receive_denouncement(denouncer_id: int, accused_id: int, reason: String) -> void:
	if not accused_id in suspects:
		suspects.append(accused_id)
	
	evidence_against_heresy += 15.0
	
	var denouncer = GameManager.get_npc_by_id(denouncer_id)
	var accused = GameManager.get_npc_by_id(accused_id)
	
	print("📜 ДОНОС: %s написал на %s за '%s'" % [denouncer.npc_name, accused.npc_name, reason])

func get_description() -> String:
	return "Инквизитор. Охотится на еретиков. Подозреваемых: %d" % suspects.size()
