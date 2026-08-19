## Система Убийств
## Управляет планированием и исполнением убийств
class_name MurderSystem
extends Node

signal murder_planned(planner: BaseNPC, target: BaseNPC)
signal murder_attempted(planner: BaseNPC, target: BaseNPC, success: bool)
signal murder_committed(planner: BaseNPC, target: BaseNPC)
signal murder_prevented(planner: BaseNPC, target: BaseNPC, reason: String)

# Убийства в процессе планирования
var murder_plans: Dictionary = {}  # planner_id -> MurderPlan

# Настройки
const BASE_HATRED_THRESHOLD: float = 60.0    # Порог ненависти для начала планирования
const TRUST_THRESHOLD: float = -30.0         # Порог доверия
const READINESS_GROWTH_RATE: float = 8.0     # Скорость роста готовности в день
const EVIDENCE_RISK_PER_DAY: float = 5.0     # Рост риска улик в день
const NIGHT_ONLY_PROBABILITY: float = 0.8    # 80% убийств ночью
const WITNESS_DETECTION_CHANCE: float = 0.35  # 35% шанс что свидетель заметит

class MurderPlan:
	var planner_id: int
	var target_id: int
	var hatred: float           # Текущий уровень ненависти
	var readiness: float        # Готовность 0-100
	var evidence_risk: float     # Риск улик 0-100
	var days_planning: int       # Дней с начала планирования
	var trigger_events: int      # Количество триггерных событий
	var created_day: int
	
	# Визуальные данные
	var planner_name: String = ""
	var target_name: String = ""
	
	const HATRED_THRESHOLD: float = 70.0     # Для осуществления
	const READINESS_THRESHOLD: float = 65.0  # Готовность для попытки
	const EVIDENCE_DEATH_THRESHOLD: float = 95.0  # Слишком опасно
	
	func can_attempt() -> bool:
		return hatred >= HATRED_THRESHOLD and readiness >= READINESS_THRESHOLD and evidence_risk < EVIDENCE_DEATH_THRESHOLD
	
	func is_too_dangerous() -> bool:
		return evidence_risk >= EVIDENCE_DEATH_THRESHOLD

func _ready() -> void:
	# Подключаемся к системе времени
	TimeSystem.connect("phase_changed", _on_phase_changed)

## Проверить и обновить все планы (вызывается ежедневно)
func update_all_plans() -> void:
	var to_remove: Array[int] = []
	
	for planner_id in murder_plans.keys():
		var plan: MurderPlan = murder_plans[planner_id]
		
		# Обновляем план
		_update_plan(plan)
		
		# Проверяем, не стало ли слишком опасно
		if plan.is_too_dangerous():
			abort_plan(plan, "Слишком высокий риск быть пойманным")
			to_remove.append(planner_id)
			continue
		
		# Проверяем, жив ли планировщик и цель
		var planner = GameManager.get_npc_by_id(planner_id)
		var target = GameManager.get_npc_by_id(plan.target_id)
		
		if not planner or not planner.is_alive:
			to_remove.append(planner_id)
		elif not target or not target.is_alive:
			to_remove.append(planner_id)
			print("❌ План убийства %s отменён: цель мертва" % plan.target_name)
	
	# Удаляем неактуальные планы
	for id in to_remove:
		murder_plans.erase(id)

## Обновить отдельный план
func _update_plan(plan: MurderPlan) -> void:
	plan.days_planning += 1
	
	# Рост готовности
	plan.readiness = clamp(plan.readiness + randf_range(3.0, READINESS_GROWTH_RATE), 0.0, 100.0)
	
	# Рост риска улик
	plan.evidence_risk = clamp(plan.evidence_risk + EVIDENCE_RISK_PER_DAY, 0.0, 100.0)

## Попытка убийства (вызывается из NPC)
func attempt_murder(planner: BaseNPC, target: BaseNPC) -> bool:
	var plan = _get_or_create_plan(planner, target)
	
	# Проверяем условия
	if not plan.can_attempt():
		return false
	
	# Проверяем ночь (80% шанс)
	if randf() > NIGHT_ONLY_PROBABILITY and not TimeSystem.is_nighttime():
		return false
	
	# Вычисляем шанс успеха
	var success_chance = _calculate_success_chance(plan)
	
	emit_signal("murder_attempted", planner, target, success_chance > randf() * 100)
	
	if success_chance > randf() * 100:
		# Успех!
		_execute_murder(planner, target, plan)
		return true
	else:
		# Попытка не удалась
		plan.readiness -= 20.0
		plan.evidence_risk += 20.0  # Увеличиваем риск
		
		# Возможно, заметили
		if randf() < WITNESS_DETECTION_CHANCE:
			_notify_sheriff_about_attempt(planner, target)
		
		return false

## Вычислить шанс успеха
func _calculate_success_chance(plan: MurderPlan) -> float:
	var base_chance = 70.0
	
	# Модификаторы
	base_chance -= plan.evidence_risk * 0.3  # Больше улик = меньше шанс
	base_chance += (plan.readiness - 50) * 0.2  # Выше готовность = лучше подготовка
	
	# Ночь даёт бонус
	if TimeSystem.is_nighttime():
		base_chance += 15.0
	
	# Мэр - сложная цель
	var target = GameManager.get_npc_by_id(plan.target_id)
	if target and target.role is MayorRole:
		base_chance -= 20.0  # Мэра сложнее убить
	
	return clamp(base_chance, 10.0, 95.0)

## Выполнить убийство
func _execute_murder(planner: BaseNPC, target: BaseNPC, plan: MurderPlan) -> void:
	print("🗡️💀 %s убил %s!" % [planner.npc_name, target.npc_name])
	
	emit_signal("murder_committed", planner, target)
	
	# Убиваем цель
	target.die(planner)
	
	# Обновляем отношения
	_update_relationships_after_murder(planner, target)
	
	# Создаём память у свидетелей
	_create_witness_memories(planner, target)
	
	# Очищаем план
	murder_plans.erase(planner.npc_id)

## Обновить отношения после убийства
func _update_relationships_after_murder(killer: BaseNPC, victim: BaseNPC) -> void:
	# Друзья жертвы ненавидят убийцу
	for npc in GameManager.npcs:
		if npc.npc_id == victim.npc_id or npc.npc_id == killer.npc_id:
			continue
		
		var rel_to_victim = npc.relationship_graph.get_relationship(npc.npc_id, victim.npc_id)
		
		# Если были друзьями
		if rel_to_victim.love > 30:
			npc.relationship_graph.modify_relationship(
				npc.npc_id,
				killer.npc_id,
				trust_delta: -40.0,
				hate_delta: 50.0
			)
			# Могут планировать месть
			_react_to_murder(npc, killer)

## Реакция NPC на убийство
func _react_to_murder(npc: BaseNPC, killer: BaseNPC) -> void:
	var rel = npc.relationship_graph.get_relationship(npc.npc_id, killer.npc_id)
	
	# Если очень ненавидит - может начать планировать месть
	if rel.hate > 70 and randf() < 0.3:
		start_planning_murder(npc, killer)
		print("🔥 %s планирует месть против %s" % [npc.npc_name, killer.npc_name])

## Создать воспоминания у свидетелей
func _create_witness_memories(killer: BaseNPC, victim: BaseNPC) -> void:
	var witnesses: Array[BaseNPC] = []
	
	for npc in GameManager.npcs:
		if npc.npc_id == killer.npc_id or npc.npc_id == victim.npc_id:
			continue
		
		# Свидетель, если был рядом
		var dist = npc.global_position.distance_to(victim.global_position)
		if dist < 200 and TimeSystem.is_nighttime():
			if randf() < WITNESS_DETECTION_CHANCE:
				witnesses.append(npc)
	
	for witness in witnesses:
		witness.memory_system.add_memory(
			MemorySystem.EventType.MURDER,
			killer.npc_id,
			"Став свидетелем убийства %s" % victim.npc_name,
			true  # witnessed = true
		)
		
		# Отношения резко падают
		witness.relationship_graph.modify_relationship(
			witness.npc_id,
			killer.npc_id,
			trust_delta: -50.0,
			hate_delta: 40.0
		)

## Уведомить шерифа о попытке убийства
func _notify_sheriff_about_attempt(planner: BaseNPC, target: BaseNPC) -> void:
	for npc in GameManager.npcs:
		if npc.role is SheriffRole:
			npc.memory_system.add_memory(
				MemorySystem.EventType.SUSPICIOUS,
				planner.npc_id,
				"%s был замечен рядом с %s ночью" % [planner.npc_name, target.npc_name]
			)
			print("🔍 Шериф заподозрил %s в намерениях" % planner.npc_name)

## Начать планирование убийства
func start_planning_murder(planner: BaseNPC, target: BaseNPC) -> MurderPlan:
	# Проверяем, не планирует ли уже
	if murder_plans.has(planner.npc_id):
		return murder_plans[planner.npc_id]
	
	var rel = planner.relationship_graph.get_relationship(planner.npc_id, target.npc_id)
	
	# Проверяем условия
	if rel.hate < BASE_HATRED_THRESHOLD or rel.trust > TRUST_THRESHOLD:
		return null
	
	var plan = MurderPlan.new()
	plan.planner_id = planner.npc_id
	plan.target_id = target.npc_id
	plan.hatred = rel.hate
	plan.readiness = 0.0
	plan.evidence_risk = 20.0  # Начальный риск
	plan.days_planning = 0
	plan.trigger_events = 1
	plan.created_day = GameManager.current_day
	plan.planner_name = planner.npc_name
	plan.target_name = target.npc_name
	
	murder_plans[planner.npc_id] = plan
	
	emit_signal("murder_planned", planner, target)
	print("🗡️ %s начал планировать убийство %s (ненависть: %.0f)" % [planner.npc_name, target.npc_name, rel.hate])
	
	return plan

## Получить или создать план
func _get_or_create_plan(planner: BaseNPC, target: BaseNPC) -> MurderPlan:
	if murder_plans.has(planner.npc_id):
		return murder_plans[planner.npc_id]
	return start_planning_murder(planner, target)

## Отменить план
func abort_plan(plan: MurderPlan, reason: String) -> void:
	var planner = GameManager.get_npc_by_id(plan.planner_id)
	var target = GameManager.get_npc_by_id(plan.target_id)
	
	emit_signal("murder_prevented", planner, target, reason)
	print("❌ План убийства %s отменён: %s" % [plan.target_name, reason])
	
	murder_plans.erase(plan.planner_id)

## Добавить триггерное событие (оскорбление, кража и т.д.)
func add_trigger_event(planner_id: int, hatred_increase: float) -> void:
	if not murder_plans.has(planner_id):
		return
	
	var plan: MurderPlan = murder_plans[planner_id]
	plan.hatred = clamp(plan.hatred + hatred_increase, 0.0, 100.0)
	plan.trigger_events += 1
	
	# Увеличиваем готовность пропорционально
	plan.readiness = clamp(plan.readiness + hatred_increase * 0.5, 0.0, 100.0)
	
	# Если ненависть слишком высока, возможно убийство
	if plan.hatred >= 90 and plan.readiness >= 50:
		# Форсированная попытка (редко)
		if randf() < 0.1:
			var planner = GameManager.get_npc_by_id(planner_id)
			var target = GameManager.get_npc_by_id(plan.target_id)
			if planner and target:
				attempt_murder(planner, target)

## Проверить, планируется ли убийство кого-то
func is_being_targeted(npc_id: int) -> bool:
	for plan in murder_plans.values():
		if plan.target_id == npc_id:
			return true
	return false

## Получить план против конкретного NPC
func get_plan_against(target_id: int) -> MurderPlan:
	for plan in murder_plans.values():
		if plan.target_id == target_id:
			return plan
	return null

## Обработка смены фазы дня
func _on_phase_changed(phase: TimeSystem.TimePhase) -> void:
	if phase == TimeSystem.TimePhase.NIGHT:
		# Ночью увеличиваем шанс попытки убийства
		pass
	elif phase == TimeSystem.TimePhase.DAY:
		# Днём сбрасываем часть риска (никто не заметил)
		for plan in murder_plans.values():
			plan.evidence_risk = clamp(plan.evidence_risk - 5.0, 0.0, 100.0)

## Получить статус плана
func get_plan_status(planner_id: int) -> String:
	if not murder_plans.has(planner_id):
		return "Нет активного плана"
	
	var plan: MurderPlan = murder_plans[planner_id]
	return "Планирует: %.0f%% готовность, %.0f%% риск, %d дней" % [
		plan.readiness, plan.evidence_risk, plan.days_planning
	]
