## Расширенная Криминальная Система
## Поджоги, похищения, восстания
class_name CrimeSystem
extends Node

signal crime_committed(crime_type: String, criminal: BaseNPC, target)
signal crime_prevented(crime_type: String, criminal: BaseNPC)
signal riot_started()
signal building_burned(building_name: String)

# Активные поджоги
var active_arson_attempts: Dictionary = {}

# Активные похищения
var active_kidnappings: Dictionary = {}

# Константы
const ARSON_CHANCE: float = 0.15        # Шанс поджога при высокой ненависти
const KIDNAP_CHANCE: float = 0.08        # Шанс похищения
const RIOT_THRESHOLD: float = 20.0       # Порог бунта
const ARSON_DAMAGE_TIME: float = 10.0    # Время до срабатывания поджога
const KIDNAP_RANSOM: float = 100.0      # Выкуп за похищенного

func _ready():
	print("🔥 Криминальная система инициализирована")

## Проверить все преступления (вызывается периодически)
func update_crimes(delta: float) -> void:
	_check_arson_attempts(delta)
	_check_kidnappings(delta)
	_check_for_riot()

## Проверить поджоги
func _check_arson_attempts(delta: float) -> void:
	var to_remove: Array = []
	
	for criminal_id in active_arson_attempts.keys():
		var attempt = active_arson_attempts[criminal_id]
		attempt["timer"] -= delta
		
		if attempt["timer"] <= 0:
			# Поджог срабатывает!
			_execute_arson(criminal_id, attempt)
			to_remove.append(criminal_id)
	
	for id in to_remove:
		active_arson_attempts.erase(id)

## Выполнить поджог
func _execute_arson(criminal_id: int, attempt: Dictionary) -> void:
	var criminal = GameManager.get_npc_by_id(criminal_id)
	if not criminal or not criminal.is_alive:
		return
	
	var target = attempt["target"]  # Building или NPC
	
	if target is Node2D:
		# Поджог здания
		var building_name = attempt["building_name"]
		emit_signal("building_burned", building_name)
		print("🔥🔥🔥 ЗДАНИЕ ГОРИТ: %s!" % building_name)
		
		# Создаём панику
		_trigger_panic(50.0)
		
		# Урон репутации
		for npc in GameManager.npcs:
			if npc != criminal:
				npc.relationship_graph.modify_relationship(
					npc.npc_id,
					criminal_id,
					trust_delta = -30.0,
					hate_delta = 40.0
				)
				npc.memory_system.add_memory(
					MemorySystem.EventType.SUSPICIOUS,
					criminal_id,
					"Поджёг здание!"
				)
	
	emit_signal("crime_committed", "arson", criminal, target)

## Проверить похищения
func _check_kidnappings(delta: float) -> void:
	var to_remove: Array = []
	
	for victim_id in active_kidnappings.keys():
		var kidnapping = active_kidnappings[victim_id]
		kidnapping["timer"] -= delta
		
		if kidnapping["timer"] <= 0:
			# Время вышло - отпускаем или убиваем
			_resolve_kidnapping(victim_id, kidnapping)
			to_remove.append(victim_id)
	
	for id in to_remove:
		active_kidnappings.erase(id)

## Разрешить похищение
func _resolve_kidnapping(victim_id: int, kidnapping: Dictionary) -> void:
	var victim = GameManager.get_npc_by_id(victim_id)
	var criminal = GameManager.get_npc_by_id(kidnapping["criminal_id"])
	
	if not victim or not victim.is_alive:
		return
	
	var outcome = kidnapping["outcome"]
	
	match outcome:
		"released":
			# Отпущен без последствий
			print("🤝 %s отпущен без выкупа" % victim.npc_name)
		"ransom_paid":
			# Выкуп уплачен
			var mayor = _get_mayor()
			if mayor and mayor.wealth >= KIDNAP_RANSOM:
				mayor.wealth -= KIDNAP_RANSOM
				criminal.wealth += KIDNAP_RANSOM
				print("💰 Выкуп уплачен: %.0f" % KIDNAP_RANSOM)
		"killed":
			victim.die(criminal)
			print("💀 %s убит похитителями" % victim.npc_name)

## Проверить восстание
func _check_for_riot() -> void:
	if GameManager.event_system and GameManager.event_system.public_order < RIOT_THRESHOLD:
		if not GameManager.event_system._has_event_type(GameManager.event_system.EventType.RIOT):
			_start_riot()

## Начать восстание
func _start_riot() -> void:
	emit_signal("riot_started")
	
	# Все NPC получают импульс к агрессии
	for npc in GameManager.npcs:
		for other in GameManager.npcs:
			if npc.npc_id == other.npc_id:
				continue
			# Случайное увеличение ненависти
			if randf() < 0.3:
				npc.relationship_graph.modify_relationship(
					npc.npc_id,
					other.npc_id,
					hate_delta = randf_range(5.0, 15.0)
				)
	
	print("🔥🔥 ВОССТАНИЕ НАЧАЛОСЬ! 🔥🔥")

## Вызвать панику
func _trigger_panic(intensity: float) -> void:
	for npc in GameManager.npcs:
		npc.need_system.safety -= intensity
		npc.relationship_graph.modify_relationship(
			npc.npc_id,
			npc.npc_id,  # К городу в целом
			trust_delta = -10.0
		)

## Попытка поджога
func attempt_arson(criminal: BaseNPC, target: Node2D, building_name: String = "Неизвестно") -> bool:
	var gs: GURPSSystem = GameManager.gurps_system
	var success := false
	if gs:
		var mod := 2 if TimeSystem.is_nighttime() else -2
		var roll = gs.dx_check(criminal, mod, "Поджог: " + criminal.npc_name)
		print("🔥 ", gs.describe_result(roll))
		success = roll.success
	else:
		var crime_chance = ARSON_CHANCE
		if criminal.relationship_graph.get_enemies(criminal.npc_id).size() > 0:
			crime_chance += 0.1
		if TimeSystem.is_nighttime():
			crime_chance += 0.1
		success = randf() <= crime_chance
	if not success:
		return false
	
	# Успех! Начинаем поджог
	active_arson_attempts[criminal.npc_id] = {
		"target": target,
		"building_name": building_name,
		"timer": ARSON_DAMAGE_TIME,
		"day": GameManager.current_day
	}
	
	print("🔥 %s готовится поджечь %s..." % [criminal.npc_name, building_name])
	
	# Увеличиваем риск быть пойманным
	if GameManager.murder_system:
		GameManager.murder_system.add_trigger_event(criminal.npc_id, 20.0)
	
	return true

## Попытка похищения
func attempt_kidnapping(criminal: BaseNPC, target: BaseNPC) -> bool:
	# Проверяем условия
	if not target or not target.is_alive:
		return false
	if target.role is MayorRole or target.role is BaronRole or target.role is SheriffRole or target.role is InquisitionRole:
		return false  # Слишком опасно
	
	var gs: GURPSSystem = GameManager.gurps_system
	if gs:
		var contest = gs.quick_contest(
			criminal.gurps.strength if criminal.gurps else 10,
			target.gurps.strength if target.gurps else 10,
			"Похищение ST: " + criminal.npc_name,
			"Сопротивление ST: " + target.npc_name
		)
		if contest.winner != 1:
			print("👤 %s не смог похитить %s" % [criminal.npc_name, target.npc_name])
			return false
	else:
		var crime_chance = KIDNAP_CHANCE
		if criminal.wealth < target.wealth * 0.5:
			crime_chance += 0.1
		if randf() > crime_chance:
			return false
	
	# Успех! Похищение!
	var outcome = "released"
	
	# Определяем исход
	var roll = randf()
	if roll < 0.3:
		outcome = "killed"
	elif roll < 0.6:
		outcome = "ransom_paid"
	# else: released
	
	active_kidnappings[target.npc_id] = {
		"criminal_id": criminal.npc_id,
		"target_name": target.npc_name,
		"timer": randf_range(30.0, 60.0),  # 30-60 секунд
		"outcome": outcome
	}
	
	# NPC исчезает
	target.visible = false
	target.set_physics_process(false)
	
	print("👤💨 %s похищен!" % target.npc_name)
	
	emit_signal("crime_committed", "kidnapping", criminal, target)
	
	# Увеличиваем риск
	if GameManager.murder_system:
		GameManager.murder_system.add_trigger_event(criminal.npc_id, 25.0)
	
	return true

## Проверить, похищен ли NPC
func is_kidnapped(npc_id: int) -> bool:
	return active_kidnappings.has(npc_id)

## Освободить похищенного (если заплатили выкуп)
func rescue_kidnapped(victim_id: int) -> void:
	if active_kidnappings.has(victim_id):
		var kidnapping = active_kidnappings[victim_id]
		active_kidnappings.erase(victim_id)
		
		var victim = GameManager.get_npc_by_id(victim_id)
		if victim:
			victim.visible = true
			victim.set_physics_process(true)
			if victim.role:
				victim.global_position = victim.role.home_position
			
			print("🎉 %s освобождён!" % victim.npc_name)

func _get_mayor() -> BaseNPC:
	return GameManager.get_ruler()
