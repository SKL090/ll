## Система отношений между NPC
class_name RelationshipGraph
extends Node

signal relationship_changed(npc_id: int, target_id: int, relationship: Dictionary)
signal enemy_created(npc_id: int, target_id: int)
signal friend_created(npc_id: int, target_id: int)

# Отношения: ключ = "npc_id_target_id", значение = RelationshipData
var relationships: Dictionary = {}

class RelationshipData:
	var trust: float = 0.0       # -100 to 100 (доверие)
	var love: float = 0.0         # 0 to 100 (любовь)
	var hate: float = 0.0         # 0 to 100 (ненависть)
	var interactions: int = 0    # Количество взаимодействий
	
	func get_relationship_type() -> String:
		if hate > 50:
			return "enemy"
		elif love > 50:
			return "friend"
		elif trust > 30:
			return "acquaintance"
		elif trust < -30:
			return "untrusted"
		return "neutral"
	
	func is_enemy() -> bool:
		return hate > 50
	
	func is_friend() -> bool:
		return love > 50

## Получить отношение между двумя NPC
func get_relationship(npc_id: int, target_id: int) -> RelationshipData:
	var key = _make_key(npc_id, target_id)
	if not relationships.has(key):
		relationships[key] = RelationshipData.new()
	return relationships[key]

## Изменить отношение
func modify_relationship(npc_id: int, target_id: int, trust_delta: float = 0.0, love_delta: float = 0.0, hate_delta: float = 0.0) -> void:
	var rel = get_relationship(npc_id, target_id)
	var old_type = rel.get_relationship_type()
	
	rel.trust = clamp(rel.trust + trust_delta, -100.0, 100.0)
	rel.love = clamp(rel.love + love_delta, 0.0, 100.0)
	rel.hate = clamp(rel.hate + hate_delta, 0.0, 100.0)
	rel.interactions += 1
	
	var new_type = rel.get_relationship_type()
	
	# Проверяем изменения статуса
	if old_type != "enemy" and new_type == "enemy":
		emit_signal("enemy_created", npc_id, target_id)
	elif old_type != "friend" and new_type == "friend":
		emit_signal("friend_created", npc_id, target_id)
	
	emit_signal("relationship_changed", npc_id, target_id, {
		"trust": rel.trust,
		"love": rel.love,
		"hate": rel.hate
	})

## Помочь другому NPC
func help(npc_id: int, target_id: int) -> void:
	modify_relationship(npc_id, target_id, trust_delta: 10.0, love_delta: 5.0)
	# Обратная связь
	modify_relationship(target_id, npc_id, trust_delta: 5.0, love_delta: 3.0)

## Оскорбить другого NPC
func insult(npc_id: int, target_id: int) -> void:
	modify_relationship(npc_id, target_id, trust_delta: -15.0, hate_delta: 15.0)
	# Обратная связь
	modify_relationship(target_id, npc_id, trust_delta: -20.0, hate_delta: 20.0)
	
	# Триггер для системы убийств
	_notify_murder_system(npc_id, target_id, 15.0)

## Украсть у другого NPC
func steal_from(npc_id: int, target_id: int) -> void:
	modify_relationship(npc_id, target_id, trust_delta: -30.0, hate_delta: 20.0)
	modify_relationship(target_id, npc_id, trust_delta: -40.0, hate_delta: 35.0)
	
	# Триггер для системы убийств - кража сильнее влияет
	_notify_murder_system(npc_id, target_id, 25.0)

## Убить другого NPC (перед убийством)
func prepare_for_murder(npc_id: int, target_id: int) -> void:
	modify_relationship(npc_id, target_id, trust_delta: -50.0, hate_delta: 30.0)

## Стать свидетелем преступления
func witness_crime(npc_id: int, criminal_id: int, crime_type: String) -> void:
	match crime_type:
		"theft":
			modify_relationship(npc_id, criminal_id, trust_delta: -25.0, hate_delta: 15.0)
		"murder":
			modify_relationship(npc_id, criminal_id, trust_delta: -60.0, hate_delta: 50.0)

## Уведомить систему убийств о триггерном событии
func _notify_murder_system(npc_id: int, target_id: int, hatred_increase: float) -> void:
	if GameManager.murder_system:
		GameManager.murder_system.add_trigger_event(npc_id, hatred_increase)

## Получить всех врагов NPC
func get_enemies(npc_id: int) -> Array[int]:
	var enemies: Array[int] = []
	for key in relationships.keys():
		var parts = key.split("_")
		if parts.size() >= 2 and int(parts[0]) == npc_id:
			var rel = relationships[key]
			if rel.is_enemy():
				enemies.append(int(parts[1]))
	return enemies

## Получить всех друзей NPC
func get_friends(npc_id: int) -> Array[int]:
	var friends: Array[int] = []
	for key in relationships.keys():
		var parts = key.split("_")
		if parts.size() >= 2 and int(parts[0]) == npc_id:
			var rel = relationships[key]
			if rel.is_friend():
				friends.append(int(parts[1]))
	return friends

## Проверить, является ли врагом
func is_enemy_of(npc_id: int, target_id: int) -> bool:
	var rel = get_relationship(npc_id, target_id)
	return rel.is_enemy()

## Проверить, является ли другом
func is_friend_of(npc_id: int, target_id: int) -> bool:
	var rel = get_relationship(npc_id, target_id)
	return rel.is_friend()

## Генерация начальных отношений
func generate_initial_relationships(npc_id: int, all_npc_ids: Array[int]) -> void:
	for other_id in all_npc_ids:
		if other_id != npc_id:
			# Случайные начальные отношения
			var trust = randf_range(-20.0, 30.0)
			var love = randf_range(0.0, 30.0) if randf() > 0.3 else 0.0
			modify_relationship(npc_id, other_id, trust, love, 0.0)

## Утилита для создания ключа
func _make_key(id1: int, id2: int) -> String:
	return str(min(id1, id2)) + "_" + str(max(id1, id2))
