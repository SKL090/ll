## Роль Культиста
class_name CultistRole
extends Role

# Скрытый статус
var is_hidden_cultist: bool = true  # Скрытый от других
var cult_rank: int = 1  # Ранг в культе (1-5)

# Места встреч
var ritual_location: Vector2 = Vector2(850, 550)  # Тёмное место
var hideout_position: Vector2 = Vector2(900, 500)

# Состояние
var ritual_progress: float = 0.0  # Прогресс ритуала
var is_performing_ritual: bool = false

# Настройки
const RITUAL_DURATION: float = 30.0  # Длительность ритуала
const RITUALS_TO_RANK_UP: int = 3  # Ритуалов до повышения

func _init():
	role_type = "cultist"
	work_start_hour = 8.0
	work_end_hour = 18.0
	sleep_start_hour = 22.0
	sleep_end_hour = 6.0

func initialize(npc: BaseNPC) -> void:
	super.initialize(npc)
	
	# Культист работает как обычный житель днём
	work_position = Vector2(460, 410)  # Магазин - прикрытие
	home_position = Vector2(850, 480)

func update(delta: float) -> void:
	super.update(delta)
	
	if is_performing_ritual:
		ritual_progress += delta
		
		if ritual_progress >= RITUAL_DURATION:
			_complete_ritual()

func _complete_ritual() -> void:
	is_performing_ritual = false
	ritual_progress = 0.0
	
	# Эффекты ритуала
	print("🔮 Ритуал завершён!")
	
	# Случайный эффект
	var effect = randi() % 5
	
	match effect:
		0:  # Проклятие случайному NPC
			_cast_curse_on_random()
		1:  # Призыв нового cultist
			_attempt_recruit()
		2:  # Усиление культа
			_empower_cult()
		3:  # Случайное убийство
			_sacrifice_random_victim()
		4:  # Ритуал красоты/силы
			_grant_blessing()

func _cast_curse_on_random() -> void:
	var targets: Array[BaseNPC] = []
	
	for npc in GameManager.npcs:
		if npc.role is CultistRole:
			continue
		targets.append(npc)
	
	if targets.size() == 0:
		return
	
	var victim = targets[randi() % targets.size()]
	
	victim.need_system.energy -= 30
	victim.need_system.social -= 20
	
	victim.memory_system.add_memory(
		MemorySystem.EventType.SUSPICIOUS,
		owner_npc.npc_id,
		"Почувствовал проклятие..."
	)
	
	print("🔮 %s проклят культом!" % victim.npc_name)

func _attempt_recruit() -> void:
	# Пытаемся завербовать нового cultist
	var candidates: Array[BaseNPC] = []
	
	for npc in GameManager.npcs:
		if npc.role is CultistRole or npc.role is BaronRole or npc.role is InquisitionRole:
			continue
		if npc.wealth < 20:  # Бедные более восприимчивы
			candidates.append(npc)
	
	if candidates.size() == 0:
		return
	
	var recruit = candidates[randi() % candidates.size()]
	
	var gs: GURPSSystem = GameManager.gurps_system
	var recruited := false
	if gs:
		var will_mod := -2 if recruit.need_system.social < 40 else 0
		var resist = gs.will_check(recruit, will_mod, "Вербовка культа: " + recruit.npc_name)
		recruited = not resist.success
		print("🔮 ", gs.describe_result(resist))
	else:
		var recruit_chance = 20.0 - recruit.need_system.social * 0.2
		recruited = randf() * 100.0 < recruit_chance
	if recruited and GameManager.cult_system:
		GameManager.cult_system.add_cultist(recruit)
		print("🔮 %s завербован в культ!" % recruit.npc_name)

func _empower_cult() -> void:
	# Усиление культа - больше cultists появляется
	if GameManager.cult_system:
		GameManager.cult_system.cult_power += 10.0
	print("🔮 Культ усилился!")

func _sacrifice_random_victim() -> void:
	# Жертвоприношение
	var targets: Array[BaseNPC] = []
	
	for npc in GameManager.npcs:
		if npc.role is CultistRole:
			continue
		if npc.role is BaronRole:
			continue  # Слишком сложно
		targets.append(npc)
	
	if targets.size() == 0:
		return
	
	var victim = targets[randi() % targets.size()]
	
	# Предупреждение для игрока
	victim.memory_system.add_memory(
		MemorySystem.EventType.SUSPICIOUS,
		owner_npc.npc_id,
		"Был замечен с группой в капюшонах..."
	)
	
	# Убийство!
	victim.die(owner_npc)
	
	print("🔮💀 Жертвоприношение: %s убит!" % victim.npc_name)

func _grant_blessing() -> void:
	# Благословение cultist - усиление
	owner_npc.need_system.energy += 20
	owner_npc.need_system.hunger += 10
	print("🔮 %s получил благословение культа!" % owner_npc.npc_name)

func get_current_behavior() -> String:
	var time = TimeSystem.current_time
	var is_night = TimeSystem.is_nighttime()
	
	var priority_need = owner_npc.need_system.get_priority_need()
	if priority_need != "":
		return priority_need
	
	# Ночью - ритуал!
	if is_night and time >= 23.0:
		return "perform_ritual"
	
	# Днём работает как обычный человек
	if time >= 8.0 and time < 18.0:
		return "work"  # Прикрытие
	
	# Вечер - подготовка
	if time >= 18.0 and time < 22.0:
		return "prepare_ritual"
	
	return "sleep"

func get_target_position() -> Vector2:
	match get_current_behavior():
		"work":
			return work_position  # Прикрытие - работа
		"prepare_ritual":
			return hideout_position  # Сбор перед ритуалом
		"perform_ritual":
			return ritual_location  # Место ритуала
		"sleep":
			return home_position
	return home_position

## Начать ритуал
func start_ritual() -> void:
	if not is_performing_ritual:
		is_performing_ritual = true
		ritual_progress = 0.0
		print("🔮 %s начал ритуал..." % owner_npc.npc_name)

## Повысить ранг
func promote_rank() -> void:
	if cult_rank < 5:
		cult_rank += 1
		print("🔮 %s повышен до ранга %d в культе!" % [owner_npc.npc_name, cult_rank])

func get_description() -> String:
	var hidden = "[СКРЫТ]" if is_hidden_cultist else ""
	return "Культист %s. Ранг: %d. Прогресс ритуала: %.0f%%" % [hidden, cult_rank, ritual_progress / RITUAL_DURATION * 100]
