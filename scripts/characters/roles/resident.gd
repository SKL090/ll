## Роль Жителя
class_name ResidentRole
extends Role

# Подтип жителя
enum ResidentType {
	WORKER,    # Обычный работяга
	THIEF,     # Вор (крадёт ночью)
	LAZY,      # Ленивый (не работает)
}

@export var resident_type: ResidentType = ResidentType.WORKER

# Места работы
@export var shop_position: Vector2 = Vector2(450, 400)
@export var farm_position: Vector2 = Vector2(150, 200)

# Вероятность быть вором
const THIEF_CHANCE: float = 0.3

func _init():
	role_type = "resident"
	work_start_hour = 8.0
	work_end_hour = 18.0
	sleep_start_hour = 22.0
	sleep_end_hour = 6.0

func initialize(npc: BaseNPC) -> void:
	super.initialize(npc)
	
	# Определяем тип жителя случайно
	if randf() < THIEF_CHANCE:
		resident_type = ResidentType.THIEF
	else:
		resident_type = ResidentType.WORKER
	
	# Устанавливаем место работы
	if resident_type == ResidentType.THIEF:
		work_position = shop_position  # Воры работают в магазине днём (прикрытие)
	else:
		# Случайная работа
		work_position = shop_position if randf() > 0.5 else farm_position

func update(delta: float) -> void:
	super.update(delta)
	
	# Ленивые жители не работают
	if resident_type == ResidentType.LAZY:
		# Они просто существуют и消耗 ресурсы
		pass

func get_current_behavior() -> String:
	var time = TimeSystem.current_time
	var is_night = TimeSystem.is_nighttime()
	
	# Приоритет потребностей
	var priority_need = owner_npc.need_system.get_priority_need()
	if priority_need != "":
		return priority_need
	
	# Вор крадёт ночью
	if is_night and resident_type == ResidentType.THIEF:
		if time >= 23.0 and time < 4.0:
			return "steal"
	
	# Ленивый житель
	if resident_type == ResidentType.LAZY:
		return _get_lazy_behavior(time)
	
	# Обычное расписание
	if time >= 6.0 and time < 8.0:
		return "morning"
	elif time >= 8.0 and time < 12.0:
		return "work"
	elif time >= 12.0 and time < 14.0:
		return "lunch"
	elif time >= 14.0 and time < 18.0:
		return "work"
	elif time >= 18.0 and time < 20.0:
		return "dinner"
	elif time >= 20.0 and time < 22.0:
		return "evening"
	else:
		return "sleep"

func _get_lazy_behavior(time: float) -> String:
	if time >= 10.0 and time < 14.0:
		return "wander"  # Бродит без дела
	elif time >= 14.0 and time < 18.0:
		return "wander"
	return "sleep"

func get_target_position() -> Vector2:
	match get_current_behavior():
		"morning":
			return home_position  # Завтрак дома
		"work":
			return work_position
		"lunch":
			return home_position
		"dinner":
			return home_position
		"evening":
			return _get_social_location()
		"sleep":
			return home_position
		"steal":
			return _get_theft_target()
		"wander":
			return _get_wander_location()
	return home_position

func _get_theft_target() -> Vector2:
	# Находим подходящую цель для кражи
	var potential_targets: Array[BaseNPC] = []
	
	for npc in GameManager.npcs:
		if npc == owner_npc:
			continue
		if npc.role.role_type == "resident":
			potential_targets.append(npc)
	
	if potential_targets.is_empty():
		return home_position
	
	# Выбираем случайного жителя
	var target = potential_targets[randi() % potential_targets.size()]
	return target.global_position

func _get_social_location() -> Vector2:
	# Жители общаются в центре или у магазина
	var locations = [
		Vector2(500, 350),
		Vector2(450, 380),
		Vector2(550, 370),
	]
	return locations[randi() % locations.size()]

func _get_wander_location() -> Vector2:
	return Vector2(randf_range(100, 700), randf_range(150, 450))

## Попытка кражи
func attempt_theft() -> bool:
	if resident_type != ResidentType.THIEF:
		return false
	
	# Находим цель
	var target = _find_theft_target()
	if target == null:
		return false
	
	# Проверяем шанс успеха (40%)
	var success = randf() < 0.4
	
	if success:
		# Кража удалась!
		var stolen_amount = randf_range(5.0, 15.0)
		target.wealth -= stolen_amount
		owner_npc.wealth += stolen_amount
		
		# Отношения ухудшаются
		owner_npc.relationship_graph.steal_from(owner_npc.npc_id, target.npc_id)
		
		# Добавляем память
		owner_npc.memory_system.add_memory(
			MemorySystem.EventType.THEFT, 
			target.npc_id, 
			"Украл деньги у " + target.npc_name
		)
		
		print("💰 ", owner_npc.npc_name, " украл ", stolen_amount, " у ", target.npc_name)
		return true
	else:
		# Попытка не удалась, возможно заметили
		if randf() < 0.5:  # 50% шанс что заметили
			# Добавляем подозрительную память свидетелям
			_add_suspicion(target)
		
		return false

func _find_theft_target() -> BaseNPC:
	var best_target: BaseNPC = null
	var lowest_safety: float = 100.0
	
	for npc in GameManager.npcs:
		if npc == owner_npc:
			continue
		if npc.role.role_type == "resident":
			# Жители с низкой безопасностью - лучшие цели
			var safety = npc.need_system.safety
			if safety < lowest_safety:
				lowest_safety = safety
				best_target = npc
	
	return best_target

func _add_suspicion(witness: BaseNPC) -> void:
	witness.memory_system.add_memory(
		MemorySystem.EventType.SUSPICIOUS,
		owner_npc.npc_id,
		"Заметил подозрительное поведение " + owner_npc.npc_name
	)

func get_type_name() -> String:
	match resident_type:
		ResidentType.WORKER:
			return "Работяга"
		ResidentType.THIEF:
			return "Вор"
		ResidentType.LAZY:
			return "Бездельник"
	return "Житель"

func get_description() -> String:
	var desc = "Житель города. "
	match resident_type:
		ResidentType.WORKER:
			desc += "Честно работает."
		ResidentType.THIEF:
			desc += "Днём работает, ночью крадёт."
		ResidentType.LAZY:
			desc += "Ничего не делает."
	return desc
