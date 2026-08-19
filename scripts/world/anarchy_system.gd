## Система Анархии
## Что происходит когда мэр убит
class_name AnarchySystem
extends Node

signal anarchy_started()
signal anarchy_ended()
signal new_leader_elected(leader_id: int)

# Состояние
var is_anarchy_active: bool = false
var days_in_anarchy: int = 0
var anarchy_timer: float = 0.0

# Эффекты анархии
const ANARCHY_DURATION_DAYS: int = 7  # Дней до выборов/нового лидера
const CRIME_INCREASE_RATE: float = 0.3  # Рост преступности в день
const ORDER_DECAY_RATE: float = 15.0    # Падение порядка в день
const TAX_LOSS_RATE: float = 0.5       # Потеря дохода от налогов

# Новый лидер
var temp_leader_id: int = -1

func _ready():
	print("⚔️ Система анархии инициализирована")

## Проверить, можно ли начать анархию
func check_for_anarchy() -> void:
	var mayor = _get_mayor()
	
	if mayor == null or not mayor.is_alive:
		if not is_anarchy_active:
			start_anarchy()
	else:
		if is_anarchy_active:
			end_anarchy()

## Начать анархию
func start_anarchy() -> void:
	if is_anarchy_active:
		return
	
	is_anarchy_active = true
	days_in_anarchy = 0
	
	emit_signal("anarchy_started")
	
	print("⚔️⚔️⚔️ АНАРХИЯ НАЧАЛАСЬ! ⚔️⚔️⚔️")
	print("Мэр мёртв. Город без лидера!")
	
	# Сообщаем всем о смерти мэра
	_broadcast_mayor_death()
	
	# Выбираем временного лидера
	_elect_temp_leader()
	
	# Запускаем эффекты
	_apply_anarchy_effects()

## Завершить анархию
func end_anarchy() -> void:
	if not is_anarchy_active:
		return
	
	is_anarchy_active = false
	days_in_anarchy = 0
	
	# Восстанавливаем нормальное управление
	if temp_leader_id != -1:
		emit_signal("new_leader_elected", temp_leader_id)
	
	# Восстанавливаем порядок
	EventSystem.increase_order(30.0)
	
	print("✅ Анархия окончена. Новый лидер избран!")
	
	emit_signal("anarchy_ended")

## Сообщить всем о смерти мэра
func _broadcast_mayor_death() -> void:
	var mayor_death_message = "Мэр был убит! Кто следующий?"
	
	for npc in GameManager.npcs:
		# Резко падает доверие к системе
		for other in GameManager.npcs:
			if other.npc_id == npc.npc_id:
				continue
			npc.relationship_graph.modify_relationship(
				npc.npc_id,
				other.npc_id,
				trust_delta: -15.0,
				hate_delta: 10.0
			)
		
		# Добавляем память
		npc.memory_system.add_memory(
			MemorySystem.EventType.MURDER,
			-1,  # Мэр уже мёртв
			"Мэр убит - город в опасности"
		)

## Выбрать временного лидера
func _elect_temp_leader() -> void:
	# Самый доверенный NPC становится лидером
	var best_candidate: BaseNPC = null
	var highest_trust: float = -100.0
	
	for npc in GameManager.npcs:
		if npc.role is MayorRole:
			continue
		if not npc.is_alive:
			continue
		
		# Считаем среднее доверие к этому NPC
		var total_trust: float = 0.0
		var count: int = 0
		
		for other in GameManager.npcs:
			if other.npc_id == npc.npc_id:
				continue
			total_trust += npc.relationship_graph.get_relationship(npc.npc_id, other.npc_id).trust
			count += 1
		
		var avg_trust = total_trust / count if count > 0 else 0.0
		
		if avg_trust > highest_trust:
			highest_trust = avg_trust
			best_candidate = npc
	
	if best_candidate:
		temp_leader_id = best_candidate.npc_id
		print("👑 Временным лидером избран: %s" % best_candidate.npc_name)
	else:
		# Если никого не нашли - случайный житель
		var residents: Array[BaseNPC] = []
		for npc in GameManager.npcs:
			if npc.role is ResidentRole and npc.is_alive:
				residents.append(npc)
		
		if residents.size() > 0:
			temp_leader_id = residents[randi() % residents.size()].npc_id
			print("👑 Временным лидером назначен: %s" % GameManager.get_npc_by_id(temp_leader_id).npc_name)

## Обновление (вызывается ежедневно)
func update() -> void:
	if not is_anarchy_active:
		return
	
	days_in_anarchy += 1
	
	# Применяем эффекты анархии
	_apply_anarchy_effects()
	
	# Проверяем, пора ли结束
	if days_in_anarchy >= ANARCHY_DURATION_DAYS:
		# Проверяем, есть ли новый мэр
		var mayor = _get_mayor()
		if mayor and mayor.is_alive:
			end_anarchy()
		else:
			# Продолжаем анархию или выбираем нового
			_recheck_leadership()

## Применить эффекты анархии
func _apply_anarchy_effects() -> void:
	# Падение общественного порядка
	EventSystem.decrease_order(ORDER_DECAY_RATE)
	
	# Рост преступности
	GameManager.crime_rate += CRIME_INCREASE_RATE
	
	# NPC больше ненавидят друг друга
	for npc in GameManager.npcs:
		for other in GameManager.npcs:
			if npc.npc_id == other.npc_id:
				continue
			# Небольшое увеличение ненависти
			var rel = npc.relationship_graph.get_relationship(npc.npc_id, other.npc_id)
			rel.hate = clamp(rel.hate + 2.0, 0.0, 100.0)
	
	# Меньше налогов
	GameManager.city_treasury *= TAX_LOSS_RATE
	
	print("⚔️ День %d анархии: порядок падает, хаос растёт" % days_in_anarchy)

## Перепроверить лидерство
func _recheck_leadership() -> void:
	# Если прошло достаточно времени и нет мэра
	if days_in_anarchy >= ANARCHY_DURATION_DAYS:
		# Смотрим на население
		var alive_count = 0
		for npc in GameManager.npcs:
			if npc.is_alive:
				alive_count += 1
		
		if alive_count < 3:
			# Слишком мало людей - город вымирает
			print("🏚️ Город почти опустел...")
		else:
			# Выбираем нового лидера
			_elect_temp_leader()

func _get_mayor() -> BaseNPC:
	for npc in GameManager.npcs:
		if npc.role is MayorRole:
			return npc
	return null

## Активна ли анархия
func is_active() -> bool:
	return is_anarchy_active

## Получить временного лидера
func get_temp_leader() -> BaseNPC:
	if temp_leader_id == -1:
		return null
	return GameManager.get_npc_by_id(temp_leader_id)

## Дней в анархии
func get_days_in_anarchy() -> int:
	return days_in_anarchy
