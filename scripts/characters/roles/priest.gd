## Роль Священника
class_name PriestRole
extends Role

# Церковь
@export var church_position: Vector2 = Vector2(550, 400)

# Влияние
var influence: float = 50.0  # Влияние на город
var piety_level: float = 100.0  # Набожность жителей

# Бонусы от церкви
const MORALE_BONUS: float = 10.0
const TRUST_BONUS: float = 5.0

func _init():
	role_type = "priest"
	work_start_hour = 6.0   # Рано встаёт для службы
	work_end_hour = 21.0
	sleep_start_hour = 22.0
	sleep_end_hour = 5.0

func initialize(npc: BaseNPC) -> void:
	super.initialize(npc)
	work_position = church_position
	home_position = Vector2(540, 420)

func update(delta: float) -> void:
	super.update(delta)
	
	# Священник увеличивает порядок в городе
	EventSystem.increase_order(MORALE_BONUS * delta * 0.1) if EventSystem else None

func get_current_behavior() -> String:
	var time = TimeSystem.current_time
	
	var priority_need = owner_npc.need_system.get_priority_need()
	if priority_need != "":
		return priority_need
	
	# Утренняя служба
	if time >= 6.0 and time < 8.0:
		return "morning_service"
	# Дневные дела
	elif time >= 8.0 and time < 12.0:
		return "parish_duties"
	# Общение с прихожанами
	elif time >= 14.0 and time < 18.0:
		return "counseling"
	# Вечерняя служба
	elif time >= 18.0 and time < 20.0:
		return "evening_service"
	
	return "rest"

func get_target_position() -> Vector2:
	match get_current_behavior():
		"morning_service", "evening_service":
			return church_position
		"parish_duties":
			return _get_random_house()
		"counseling":
			return church_position
		"rest":
			return home_position
	return home_position

func _get_random_house() -> Vector2:
	var houses = [
		Vector2(685, 410),
		Vector2(785, 410),
		Vector2(685, 510),
		Vector2(785, 510),
		Vector2(885, 410),
		Vector2(885, 510),
	]
	return houses[randi() % houses.size()]

## Провести обряд (улучшает отношения)
func conduct_ritual(target: BaseNPC) -> void:
	target.need_system.social += 20
	target.need_system.energy += 10
	
	owner_npc.relationship_graph.modify_relationship(
		target.npc_id,
		owner_npc.npc_id,
		trust_delta: TRUST_BONUS,
		love_delta: 5.0
	)
	
	# Увеличиваем влияние церкви
	influence = clamp(influence + 2.0, 0.0, 100.0)

## Проповедь (влияет на всех)
func preach() -> void:
	# Все NPC получают бонус
	for npc in GameManager.npcs:
		npc.need_system.social += 10
		npc.relationship_graph.modify_relationship(
			npc.npc_id,
			owner_npc.npc_id,
			trust_delta: 2.0
		)
	
	# Порядок немного растёт
	EventSystem.increase_order(5.0) if EventSystem else None

## Утешить скорбящего
func comfort_grieving(npc: BaseNPC) -> void:
	# NPC с высокой ненавистью успокаивается
	var rel = npc.relationship_graph.get_relationship(npc.npc_id, npc.npc_id)
	rel.hate = clamp(rel.hate - 10.0, 0.0, 100.0)
	
	# Могут отказаться от планов мести
	if GameManager.murder_system:
		var plan = GameManager.murder_system.murder_plans.get(npc.npc_id)
		if plan and randf() < 0.3:  # 30% шанс
			GameManager.murder_system.abort_plan(plan, "Священник помог отпустить ненависть")
			print("🕊️ %s отпустил ненависть благодаря священнику" % npc.npc_name)

func get_description() -> String:
	return "Священник. Влияет на мораль города. Может успокоить ненависть."
