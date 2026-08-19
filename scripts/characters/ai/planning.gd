## Система планирования NPC
## Управляет долгосрочными планами, включая планирование убийств
class_name PlanningSystem
extends Node

signal plan_created(plan: MurderPlan)
signal plan_ready(plan: MurderPlan)
signal plan_executed(plan: MurderPlan)
signal plan_aborted(plan: MurderPlan, reason: String)

class MurderPlan:
	var planner_id: int
	var target_id: int
	var hatred_level: float      # Накопленная ненависть
	var evidence_risk: float      # Риск быть пойманным
	var readiness: float         # Готовность к действию (0-100)
	var planning_days: int       # Сколько дней планирует
	var preferred_location: Vector2
	var created_at: int
	
	# Пороги
	const HATRED_THRESHOLD: float = 80.0
	const TRUST_THRESHOLD: float = -50.0
	const READINESS_THRESHOLD: float = 70.0
	
	func can_execute() -> bool:
		return hatred_level >= HATRED_THRESHOLD and readiness >= READINESS_THRESHOLD
	
	func calculate_evidence() -> float:
		var evidence = evidence_risk
		# Шанс быть пойманным увеличивается с течением времени
		evidence += planning_days * 5.0
		return clamp(evidence, 0.0, 100.0)

# Планы убийства: ключ = planner_id, значение = MurderPlan
var murder_plans: Dictionary = {}

# NPC владелец
var owner_id: int = -1
var owner_relationships: RelationshipGraph
var owner_memory: MemorySystem

func _init(p_owner_id: int = -1):
	owner_id = p_owner_id

## Установить ссылки на другие системы
func set_references(relationships: RelationshipGraph, memory: MemorySystem) -> void:
	owner_relationships = relationships
	owner_memory = memory

## Начать планировать убийство
func start_planning(target_id: int) -> MurderPlan:
	# Проверяем, не планирует ли уже
	if murder_plans.has(owner_id):
		return murder_plans[owner_id]
	
	var plan = MurderPlan.new()
	plan.planner_id = owner_id
	plan.target_id = target_id
	plan.hatred_level = 50.0  # Начальный уровень
	plan.evidence_risk = 30.0
	plan.readiness = 0.0
	plan.planning_days = 0
	plan.created_at = Time.get_ticks_msec()
	
	murder_plans[owner_id] = plan
	emit_signal("plan_created", plan)
	
	print("🗡️ ", owner_id, " начал планировать убийство ", target_id)
	
	return plan

## Обновить план (вызывается каждый игровой день)
func update_plan() -> void:
	if not murder_plans.has(owner_id):
		return
	
	var plan = murder_plans[owner_id]
	plan.planning_days += 1
	
	# Увеличиваем готовность
	plan.readiness = clamp(plan.readiness + randf_range(5.0, 15.0), 0.0, 100.0)
	
	# Увеличиваем риск улик
	plan.evidence_risk = plan.calculate_evidence()
	
	# Проверяем, достиг ли порога
	if plan.can_execute():
		emit_signal("plan_ready", plan)
	
	# Проверяем, не слишком ли рискованно
	if plan.evidence_risk > 95.0:
		abort_plan("Слишком высокий риск быть пойманным")
	
	# Проверяем, изменились ли отношения
	if not is_instance_valid(owner_relationships):
		return
	
	var rel = owner_relationships.get_relationship(owner_id, plan.target_id)
	if rel.trust > 20.0:
		abort_plan("Отношения улучшились")

## Попытка выполнить план убийства
func attempt_murder() -> bool:
	if not murder_plans.has(owner_id):
		return false
	
	var plan = murder_plans[owner_id]
	
	if not plan.can_execute():
		return false
	
	# Проверяем ночь ли
	if not TimeSystem.is_nighttime():
		return false  # Убийство только ночью
	
	# Проверяем случайность
	var success_chance = 100.0 - plan.evidence_risk
	if randf() * 100.0 > success_chance:
		# Попытка не удалась,可能被抓住
		plan.readiness -= 30.0
		return false
	
	# Успешное убийство!
	emit_signal("plan_executed", plan)
	
	# Очищаем план
	murder_plans.erase(owner_id)
	
	return true

## Отменить план
func abort_plan(reason: String = "") -> void:
	if not murder_plans.has(owner_id):
		return
	
	var plan = murder_plans[owner_id]
	emit_signal("plan_aborted", plan, reason)
	murder_plans.erase(owner_id)
	
	print("❌ План убийства отменён: ", reason)

## Проверить, планирует ли кто-то убийство данного NPC
func is_being_planned(target_id: int) -> bool:
	for planner_id in murder_plans.keys():
		var plan: MurderPlan = murder_plans[planner_id]
		if plan.target_id == target_id:
			return true
	return false

## Получить план против конкретной цели
func get_plan_against(planner_id: int) -> MurderPlan:
	if murder_plans.has(planner_id):
		return murder_plans[planner_id]
	return null

## Добавить ненависть к плану
func add_hatred(amount: float) -> void:
	if not murder_plans.has(owner_id):
		return
	
	var plan = murder_plans[owner_id]
	plan.hatred_level = clamp(plan.hatred_level + amount, 0.0, 100.0)

## Решить, стоит ли начинать планировать убийство
func should_start_planning(target_id: int) -> bool:
	if not is_instance_valid(owner_relationships):
		return false
	
	var rel = owner_relationships.get_relationship(owner_id, target_id)
	
	# Условия для начала планирования
	return rel.hate > 60.0 and rel.trust < -30.0 and not murder_plans.has(owner_id)
