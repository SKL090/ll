## Система памяти NPC
class_name MemorySystem
extends Node

signal memory_added(memory: MemoryEvent)
signal important_memory(memory: MemoryEvent)

# Типы событий
enum EventType {
	THEFT,
	MURDER,
	ARREST,
	SOCIAL,
	WORK,
	SLEEP,
	HELP,
	INSULT,
	MEETING,
	SUSPICIOUS,
}

class MemoryEvent:
	var event_type: EventType
	var target_id: int
	var timestamp: float
	var witnessed: bool
	var importance: float  # 0.0 - 1.0
	var description: String
	
	func _init(p_event_type: EventType, p_target_id: int, p_description: String = ""):
		event_type = p_event_type
		target_id = p_target_id
		timestamp = Time.get_ticks_msec() / 1000.0
		witnessed = false
		importance = 0.5
		description = p_description

# Максимальное количество воспоминаний
const MAX_MEMORIES: int = 20

# Список воспоминаний
var memories: Array[MemoryEvent] = []

# NPC владелец
var owner_id: int = -1

func _init(p_owner_id: int = -1):
	owner_id = p_owner_id

## Добавить воспоминание
func add_memory(event_type: EventType, target_id: int, description: String = "", witnessed: bool = false) -> MemoryEvent:
	var memory = MemoryEvent.new(event_type, target_id, description)
	memory.witnessed = witnessed
	memory.importance = _calculate_importance(event_type, witnessed)
	
	# Добавляем в начало (новые воспоминания важнее)
	memories.insert(0, memory)
	
	# Удаляем старые воспоминания если превысили лимит
	while memories.size() > MAX_MEMORIES:
		memories.pop_back()
	
	emit_signal("memory_added", memory)
	
	if memory.importance > 0.7:
		emit_signal("important_memory", memory)
	
	return memory

## Вычислить важность события
func _calculate_importance(event_type: EventType, witnessed: bool) -> float:
	var base_importance: float
	
	match event_type:
		EventType.MURDER:
			base_importance = 1.0
		EventType.ARREST:
			base_importance = 0.9
		EventType.THEFT:
			base_importance = 0.7
		EventType.INSULT:
			base_importance = 0.5
		EventType.SUSPICIOUS:
			base_importance = 0.6
		EventType.HELP:
			base_importance = 0.4
		EventType.SOCIAL:
			base_importance = 0.2
		_:
			base_importance = 0.3
	
	if witnessed:
		base_importance += 0.2
	
	return clamp(base_importance, 0.0, 1.0)

## Получить воспоминания о конкретном NPC
func get_memories_about(target_id: int) -> Array[MemoryEvent]:
	var result: Array[MemoryEvent] = []
	for memory in memories:
		if memory.target_id == target_id:
			result.append(memory)
	return result

## Получить воспоминания определённого типа
func get_memories_of_type(event_type: EventType) -> Array[MemoryEvent]:
	var result: Array[MemoryEvent] = []
	for memory in memories:
		if memory.event_type == event_type:
			result.append(memory)
	return result

## Проверить, помнит ли NPC событие
func remembers_event(event_type: EventType, target_id: int) -> bool:
	for memory in memories:
		if memory.event_type == event_type and memory.target_id == target_id:
			return true
	return false

## Получить самое важное недавнее воспоминание
func get_most_important_memory() -> MemoryEvent:
	if memories.is_empty():
		return null
	
	var most_important = memories[0]
	for memory in memories:
		if memory.importance > most_important.importance:
			most_important = memory
	return most_important

## Забыть старые воспоминания (с течением времени)
func forget_old_memories(age_threshold: float = 300.0) -> void:  # 5 минут
	var current_time = Time.get_ticks_msec() / 1000.0
	var to_remove: Array[int] = []
	
	for i in range(memories.size()):
		var age = current_time - memories[i].timestamp
		# Вероятность забыть зависит от возраста и важности
		if age > age_threshold:
			var forget_chance = (age - age_threshold) / age_threshold * 0.5
			forget_chance *= (1.0 - memories[i].importance)  # Важные забываются медленнее
			if randf() < forget_chance:
				to_remove.append(i)
	
	# Удаляем в обратном порядке
	for i in range(to_remove.size() - 1, -1, -1):
		memories.remove_at(to_remove[i])

## Проверить подозрительную активность
func has_suspicious_memories_about(target_id: int) -> bool:
	for memory in memories:
		if memory.target_id == target_id:
			if memory.event_type == EventType.THEFT or memory.event_type == EventType.SUSPICIOUS:
				return true
	return false

## Получить строковое описание типа события
static func get_event_name(event_type: EventType) -> String:
	match event_type:
		EventType.THEFT:
			return "кража"
		EventType.MURDER:
			return "убийство"
		EventType.ARREST:
			return "арест"
		EventType.SOCIAL:
			return "общение"
		EventType.WORK:
			return "работа"
		EventType.SLEEP:
			return "сон"
		EventType.HELP:
			return "помощь"
		EventType.INSULT:
			return "оскорбление"
		EventType.MEETING:
			return "встреча"
		EventType.SUSPICIOUS:
			return "подозрительное поведение"
	return "неизвестно"
