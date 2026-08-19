## Система Тюрьмы
class_name PrisonSystem
extends Node

signal prisoner_released(prisoner_id: int)
signal prisoner_sentenced(criminal_id: int, days: int)

# Активные заключённые
var prisoners: Dictionary = {}  # npc_id -> {days_remaining: int, crime: String, cell: int}

# Константы
const PRISON_LOCATION: Vector2 = Vector2(260, 350)  # Рядом с участком
const ESCAPE_CHANCE: float = 0.05  # Шанс побега в день
const RELEASE_EARLY_CHANCE: float = 0.1  # Шанс досрочного освобождения

# Максимум заключённых
const MAX_PRISONERS: int = 3

func _ready():
	print("⛓️ Система тюрьмы инициализирована")

## Отправить в тюрьму
func send_to_prison(criminal: BaseNPC, days: int, crime: String = "unknown") -> bool:
	if prisoners.size() >= MAX_PRISONERS:
		print("⛓️ Тюрьма переполнена!")
		return false
	
	if prisoners.has(criminal.npc_id):
		# Уже в тюрьме
		prisoners[criminal.npc_id]["days_remaining"] += days
		return true
	
	# Добавляем заключённого
	prisoners[criminal.npc_id] = {
		"days_remaining": days,
		"crime": crime,
		"cell": prisoners.size() + 1,
		"name": criminal.npc_name
	}
	
	# Перемещаем NPC в тюрьму
	criminal.global_position = _get_cell_position(prisoners[criminal.npc_id]["cell"])
	criminal.is_alive = true  # Жив, но в заключении
	
	# NPC перестаёт действовать
	criminal.set_physics_process(false)
	
	emit_signal("prisoner_sentenced", criminal.npc_id, days)
	print("⛓️ %s отправлен в тюрьму на %d дней за %s" % [criminal.npc_name, days, crime])
	
	return true

## Освободить из тюрьмы
func release_from_prison(npc_id: int) -> void:
	if not prisoners.has(npc_id):
		return
	
	var prisoner_name = prisoners[npc_id]["name"]
	prisoners.erase(npc_id)
	
	# Возвращаем NPC
	var npc = GameManager.get_npc_by_id(npc_id)
	if npc:
		# Возвращаем домой
		if npc.role:
			npc.global_position = npc.role.home_position
		npc.set_physics_process(true)
		
		# Отношения с полицией ухудшаются
		for other in GameManager.npcs:
			if other.role is SheriffRole:
				npc.relationship_graph.modify_relationship(
					npc_id,
					other.npc_id,
					trust_delta: -10.0
				)
	
	emit_signal("prisoner_released", npc_id)
	print("🎉 %s освобождён!" % prisoner_name)

## Обновить (вызывается каждый день)
func update_daily() -> void:
	var to_release: Array = []
	var to_escape: Array = []
	
	for npc_id in prisoners.keys():
		var prisoner = prisoners[npc_id]
		
		# Уменьшаем срок
		prisoner["days_remaining"] -= 1
		
		# Проверяем досрочное освобождение
		if randf() < RELEASE_EARLY_CHANCE and prisoner["days_remaining"] > 2:
			to_release.append(npc_id)
			continue
		
		# Проверяем побег
		if randf() < ESCAPE_CHANCE:
			to_escape.append(npc_id)
			continue
		
		# Срок истёк
		if prisoner["days_remaining"] <= 0:
			to_release.append(npc_id)
	
	# Освобождаем
	for npc_id in to_release:
		release_from_prison(npc_id)
	
	# Побег
	for npc_id in to_escape:
		escape_prison(npc_id)

## Совершить побег
func escape_prison(npc_id: int) -> void:
	if not prisoners.has(npc_id):
		return
	
	var prisoner_name = prisoners[npc_id]["name"]
	prisoners.erase(npc_id)
	
	var npc = GameManager.get_npc_by_id(npc_id)
	if npc:
		# Убегает на окраину
		npc.global_position = Vector2(900, 500)
		npc.set_physics_process(true)
		
		# Все относятся хуже
		for other in GameManager.npcs:
			npc.relationship_graph.modify_relationship(
				npc.npc_id,
				other.npc_id,
				trust_delta: -15.0
			)
		
		# Шериф начинает охоту
		for other in GameManager.npcs:
			if other.role is SheriffRole:
				other.memory_system.add_memory(
					MemorySystem.EventType.SUSPICIOUS,
					npc.npc_id,
					"Сбежал из тюрьмы!"
				)
	
	print("🏃💨 %s сбежал из тюрьмы!" % prisoner_name)

## Получить позицию камеры
func _get_cell_position(cell_number: int) -> Vector2:
	# Размещаем камеры в здании тюрьмы
	return Vector2(240 + (cell_number - 1) * 25, 340)

## Проверить, в тюрьме ли NPC
func is_in_prison(npc_id: int) -> bool:
	return prisoners.has(npc_id)

## Получить количество заключённых
func get_prisoner_count() -> int:
	return prisoners.size()

## Получить информацию о заключённом
func get_prisoner_info(npc_id: int) -> Dictionary:
	if prisoners.has(npc_id):
		return prisoners[npc_id]
	return {}

## Получить всех заключённых
func get_all_prisoners() -> Array:
	var result: Array = []
	for npc_id in prisoners.keys():
		result.append({
			"id": npc_id,
			"name": prisoners[npc_id]["name"],
			"days": prisoners[npc_id]["days_remaining"],
			"crime": prisoners[npc_id]["crime"]
		})
	return result
