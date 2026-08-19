## Система Сохранения и Загрузки
class_name SaveSystem
extends Node

const SAVE_PATH = "user://save_game.json"

signal save_completed(success: bool)
signal load_completed(success: bool)

func _ready():
	print("💾 Система сохранения готова")

## Сохранить игру
func save_game() -> bool:
	var save_data = _create_save_data()
	
	var json_string = JSON.stringify(save_data, "\t")
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось открыть файл для сохранения!")
		emit_signal("save_completed", false)
		return false
	
	file.store_string(json_string)
	file.close()
	
	print("💾 Игра сохранена!")
	emit_signal("save_completed", true)
	return true

## Загрузить игру
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("Файл сохранения не найден!")
		emit_signal("load_completed", false)
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть файл для загрузки!")
		emit_signal("load_completed", false)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Ошибка парсинга JSON!")
		emit_signal("load_completed", false)
		return false
	
	var save_data = json.data as Dictionary
	_apply_save_data(save_data)
	
	print("📂 Игра загружена!")
	emit_signal("load_completed", true)
	return true

## Создать данные для сохранения
func _create_save_data() -> Dictionary:
	var save_data = {
		"version": "1.0",
		"timestamp": Time.get_datetime_string_from_system(),
		"game": {
			"current_day": GameManager.current_day,
			"city_treasury": GameManager.city_treasury,
			"crime_rate": GameManager.crime_rate,
			"unsolved_murders": GameManager.unsolved_murders,
		},
		"time": {
			"current_time": TimeSystem.current_time,
			"current_day_ts": TimeSystem.current_day,
		},
		"npcs": [],
		"relationships": {},
		"memories": {},
		"events": [],
	}
	
	# Сохраняем NPC
	for npc in GameManager.npcs:
		var npc_data = {
			"id": npc.npc_id,
			"name": npc.npc_name,
			"role_type": npc.role.role_type if npc.role else "unknown",
			"position": {"x": npc.global_position.x, "y": npc.global_position.y},
			"wealth": npc.wealth,
			"is_alive": npc.is_alive,
			"needs": {
				"hunger": npc.need_system.hunger,
				"energy": npc.need_system.energy,
				"social": npc.need_system.social,
			},
			"gurps": npc.gurps.get_data() if npc.gurps else {},
		}
		save_data["npcs"].append(npc_data)
		
		# Сохраняем отношения для этого NPC
		save_data["relationships"][str(npc.npc_id)] = _get_npc_relationships(npc)
		
		# Сохраняем память
		save_data["memories"][str(npc.npc_id)] = _get_npc_memories(npc)
	
	# Сохраняем активные события
	if GameManager.event_system:
		for event in GameManager.event_system.get_active_events():
			var event_data = {
				"type": event.type,
				"name": event.name,
				"current_day": event.current_day,
				"duration": event.duration_days,
			}
			save_data["events"].append(event_data)
	
	return save_data

## Получить отношения NPC
func _get_npc_relationships(npc: BaseNPC) -> Dictionary:
	var rels = {}
	
	# Собираем все ключи отношений
	var processed_keys = []
	
	for key in npc.relationship_graph.relationships.keys():
		# Не дублируем (отношения двусторонние)
		if key in processed_keys:
			continue
		
		var parts = key.split("_")
		if parts.size() >= 2:
			var id1 = int(parts[0])
			var id2 = int(parts[1])
			
			# Только если один из участников - наш NPC
			if id1 == npc.npc_id or id2 == npc.npc_id:
				var other_id = id1 if id2 == npc.npc_id else id2
				var rel = npc.relationship_graph.get_relationship(id1, id2)
				
				rels[str(other_id)] = {
					"trust": rel.trust,
					"love": rel.love,
					"hate": rel.hate,
				}
	
	return rels

## Получить память NPC
func _get_npc_memories(npc: BaseNPC) -> Array:
	var mems = []
	
	for memory in npc.memory_system.memories:
		var mem_data = {
			"type": memory.event_type,
			"target": memory.target_id,
			"description": memory.description,
			"importance": memory.importance,
		}
		mems.append(mem_data)
	
	return mems

## Применить данные сохранения
func _apply_save_data(data: Dictionary) -> void:
	# Восстанавливаем игровое состояние
	if data.has("game"):
		var game_data = data["game"]
		GameManager.current_day = game_data.get("current_day", 1)
		GameManager.city_treasury = game_data.get("city_treasury", 1000.0)
		GameManager.crime_rate = game_data.get("crime_rate", 0.0)
		GameManager.unsolved_murders = game_data.get("unsolved_murders", 0)
	
	# Восстанавливаем время
	if data.has("time"):
		var time_data = data["time"]
		TimeSystem.current_time = time_data.get("current_time", 6.0)
		TimeSystem.current_day = time_data.get("current_day_ts", 1)
	
	# Восстанавливаем NPC
	if data.has("npcs"):
		_restore_npcs(data["npcs"], data)
	
	# Восстанавливаем события
	if data.has("events") and GameManager.event_system:
		# Простые события восстанавливаются автоматически через check_for_events
		pass

## Восстановить NPC
func _restore_npcs(npc_data_list: Array, full_data: Dictionary) -> void:
	# Удаляем текущих NPC
	var city = _get_city_node()
	if city:
		city.restart_game()
	
	# Ждём один кадр
	await get_tree().process_frame
	
	# Восстанавливаем данные для каждого NPC
	# Примечание: в текущей реализации NPC пересоздаются в city.gd
	# Здесь мы обновляем их данные
	
	var relationships = full_data.get("relationships", {})
	var memories = full_data.get("memories", {})
	
	# Проходим по всем NPC в игре
	for npc in GameManager.npcs:
		var npc_id_str = str(npc.npc_id)
		
		# Восстанавливаем богатство
		if relationships.has(npc_id_str):
			# Отношения восстановятся автоматически при регенерации
			pass
		
		# Восстанавливаем позицию если есть сохранённые данные
		for npc_data in npc_data_list:
			if npc_data["id"] == npc.npc_id:
				if npc_data.has("position"):
					var pos = npc_data["position"]
					npc.global_position = Vector2(pos["x"], pos["y"])
				
				if npc_data.has("wealth"):
					npc.wealth = npc_data["wealth"]
				
				if npc_data.has("needs"):
					var needs = npc_data["needs"]
					npc.need_system.hunger = needs.get("hunger", 80.0)
					npc.need_system.energy = needs.get("energy", 100.0)
					npc.need_system.social = needs.get("social", 60.0)
				
				if npc_data.has("gurps") and npc.gurps:
					npc.gurps.apply_data(npc_data["gurps"])
					npc.apply_move_from_gurps()
				if npc_data.has("is_alive"):
					npc.is_alive = npc_data["is_alive"]
					if not npc.is_alive:
						npc.queue_free()

func _get_city_node() -> Node:
	# Ищем узел города
	var tree = get_tree()
	if tree and tree.current_scene:
		return tree.current_scene
	return null

## Удалить сохранение
func delete_save() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("save_game.json")
			print("🗑️ Сохранение удалено")
			return true
	return false

## Проверить, есть ли сохранение
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Получить информацию о сохранении
func get_save_info() -> Dictionary:
	if not has_save():
		return {}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return {}
	
	var data = json.data as Dictionary
	
	return {
		"version": data.get("version", "unknown"),
		"timestamp": data.get("timestamp", ""),
		"day": data.get("game", {}).get("current_day", 0),
		"treasury": data.get("game", {}).get("city_treasury", 0),
	}
