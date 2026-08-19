## Роль Епископа
class_name BishopRole
extends Role

# Церковь
@export var cathedral_position: Vector2 = Vector2(550, 400)

# Влияние на город
var church_influence: float = 50.0  # Влияние церкви
var faith_level: float = 100.0       # Вера жителей

# Бонусы от церкви
const MORALE_BONUS: float = 15.0
const FAITH_DECAY: float = 0.5

func _init():
	role_type = "bishop"
	work_start_hour = 5.0   # Ранняя служба
	work_end_hour = 21.0
	sleep_start_hour = 22.0
	sleep_end_hour = 4.0

func initialize(npc: BaseNPC) -> void:
	super.initialize(npc)
	work_position = cathedral_position
	home_position = Vector2(540, 420)

func update(delta: float) -> void:
	super.update(delta)
	
	# Вера постепенно угасает без служб
	faith_level = clamp(faith_level - FAITH_DECAY * delta, 0.0, 100.0)
	
	# Церковь увеличивает порядок
	if GameManager.event_system:
		GameManager.event_system.increase_order(MORALE_BONUS * delta * 0.1)

func get_current_behavior() -> String:
	var time = TimeSystem.current_time
	
	var priority_need = owner_npc.need_system.get_priority_need()
	if priority_need != "":
		return priority_need
	
	# Утренняя месса
	if time >= 5.0 and time < 7.0:
		return "morning_mass"
	# Дневные дела
	elif time >= 8.0 and time < 12.0:
		return "parish_duties"
	# Исповедь
	elif time >= 14.0 and time < 16.0:
		return "confession"
	# Вечерняя служба
	elif time >= 18.0 and time < 20.0:
		return "evening_service"
	# Ночью - молитва
	elif TimeSystem.is_nighttime():
		return "night_prayer"
	
	return "rest"

func get_target_position() -> Vector2:
	match get_current_behavior():
		"morning_mass", "evening_service":
			return cathedral_position
		"confession":
			return cathedral_position
		"parish_duties":
			return _get_random_house()
		"night_prayer":
			return cathedral_position
		"rest":
			return home_position
	return home_position

func _get_random_house() -> Vector2:
	var houses = [
		Vector2(685, 410), Vector2(785, 410),
		Vector2(685, 510), Vector2(785, 510),
		Vector2(885, 410), Vector2(885, 510),
	]
	return houses[randi() % houses.size()]

## Провести службу (повышает веру)
func conduct_mass() -> void:
	faith_level = clamp(faith_level + 20.0, 0.0, 100.0)
	
	for npc in GameManager.npcs:
		npc.need_system.social += 15
		npc.relationship_graph.modify_relationship(npc.npc_id, owner_npc.npc_id, 3.0)

## Снять проклятие с еретика (благословение)
func absolve_sinner(npc: BaseNPC) -> void:
	npc.relationship_graph.modify_relationship(npc.npc_id, owner_npc.npc_id, 30.0, 20.0)
	
	# Увеличиваем влияние церкви
	church_influence = clamp(church_influence + 5.0, 0.0, 100.0)

func get_description() -> String:
	return "Епископ. Глава церкви. Повышает мораль и веру города. Влияет на инквизицию."
