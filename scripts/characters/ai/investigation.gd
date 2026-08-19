## Система Расследования Убийств
class_name InvestigationSystem
extends Node

signal investigation_started(investigation: Investigation)
signal evidence_found(investigation: Investigation, evidence_type: String)
signal suspect_interrogated(investigation: Investigation, suspect_id: int)
signal investigation_solved(investigation: Investigation, culprit_id: int)
signal investigation_failed(reason: String)

class Investigation:
	var id: int
	var victim_id: int
	var victim_name: String
	var culprit_id: int = -1  # Установлен позже
	var day_of_murder: int
	
	# Улики
	var evidence: float = 0.0
	var clues: Array[String] = []
	var suspects: Array[int] = []
	var interrogated: Array[int] = []
	
	# Статус
	var is_active: bool = true
	var is_solved: bool = false
	var time_limit: int = 10  # Дней на расследование
	
	func _init(p_id: int, p_victim_id: int, p_victim_name: String, p_day: int):
		id = p_id
		victim_id = p_victim_id
		victim_name = p_victim_name
		day_of_murder = p_day

# Активные расследования
var active_investigations: Array[Investigation] = []
var next_investigation_id: int = 1

# Прогресс расследования
const EVIDENCE_THRESHOLD_ARREST: float = 60.0    # Для ареста
const EVIDENCE_THRESHOLD_CONVICT: float = 85.0   # Для обвинения
const EVIDENCE_PER_CLUE: float = 15.0
const EVIDENCE_PER_INTERROGATION: float = 10.0

func _ready() -> void:
	# Подключаемся к GameManager для событий убийств
	GameManager.connect("npc_died", _on_npc_died)

## Начать расследование убийства
func start_investigation(victim: BaseNPC, killer: BaseNPC = null) -> Investigation:
	var investigation = Investigation.new(
		next_investigation_id,
		victim.npc_id,
		victim.npc_name,
		GameManager.current_day
	)
	
	# Если убийца известен (из памяти)
	if killer:
		investigation.culprit_id = killer.npc_id
	
	# Добавляем подозреваемых на основе отношений
	_add_initial_suspects(investigation, victim)
	
	# Добавляем первые улики
	_add_initial_evidence(investigation, victim)
	
	active_investigations.append(investigation)
	next_investigation_id += 1
	
	emit_signal("investigation_started", investigation)
	print("🔍 Расследование #%d убийства %s начато!" % [investigation.id, victim.npc_name])
	
	return investigation

## Добавить начальных подозреваемых
func _add_initial_suspects(investigation: Investigation, victim: BaseNPC) -> void:
	# Добавляем всех, кто имел плохие отношения с жертвой
	for npc in GameManager.npcs:
		if npc.npc_id == victim.npc_id:
			continue
		
		var rel = npc.relationship_graph.get_relationship(npc.npc_id, victim.npc_id)
		if rel.hate > 30 or rel.trust < -20:
			investigation.suspects.append(npc.npc_id)

## Добавить начальные улики
func _add_initial_evidence(investigation: Investigation, victim: BaseNPC) -> void:
	# Проверяем память убийцы
	var potential_killer = _find_murderer(victim)
	
	if potential_killer:
		investigation.culprit_id = potential_killer.npc_id
		investigation.evidence += 20.0  # Базовые улики
		
		investigation.clues.append("%s был замечен рядом с местом преступления" % potential_killer.npc_name)
		investigation.suspects.append(potential_killer.npc_id)
	
	# Проверяем свидетелей
	var witnesses = _find_witnesses(victim)
	if witnesses.size() > 0:
		investigation.evidence += float(witnesses.size()) * EVIDENCE_PER_INTERROGATION
		investigation.clues.append("Есть %d свидетелей" % witnesses.size())
	
	investigation.evidence = clamp(investigation.evidence, 0.0, 100.0)

## Найти убийцу по памяти
func _find_murderer(victim: BaseNPC) -> BaseNPC:
	for npc in GameManager.npcs:
		var memories = npc.memory_system.get_memories_about(victim.npc_id)
		for memory in memories:
			if memory.event_type == MemorySystem.EventType.MURDER:
				return npc
	return null

## Найти свидетелей
func _find_witnesses(victim: BaseNPC) -> Array[BaseNPC]:
	var witnesses: Array[BaseNPC] = []
	for npc in GameManager.npcs:
		if npc.npc_id == victim.npc_id:
			continue
		# Свидетель - если был рядом во время убийства
		var dist = npc.global_position.distance_to(victim.global_position)
		if dist < 150:  # В радиусе 150 пикселей
			var memories = npc.memory_system.get_memories_of_type(MemorySystem.EventType.SUSPICIOUS)
			if memories.size() > 0:
				witnesses.append(npc)
	return witnesses

## Обновление расследования (вызывается каждый день)
func update_investigations() -> void:
	var to_remove: Array[int] = []
	
	for investigation in active_investigations:
		if not investigation.is_active:
			continue
		
		# Проверяем время
		var days_elapsed = GameManager.current_day - investigation.day_of_murder
		if days_elapsed >= investigation.time_limit:
			_fail_investigation(investigation, "Время расследования истекло")
			to_remove.append(investigation.id)
			continue
		
		# Шериф проводит расследование
		_perform_daily_investigation(investigation)
	
	# Удаляем завершённые
	for id in to_remove:
		for i in range(active_investigations.size() - 1, -1, -1):
			if active_investigations[i].id == id:
				active_investigations.remove_at(i)

## Ежедневное расследование
func _perform_daily_investigation(investigation: Investigation) -> void:
	# Находим шерифа
	var sheriff = _get_active_sheriff()
	if not sheriff:
		return
	
	var daily_evidence := 4.0
	var gs: GURPSSystem = GameManager.gurps_system
	if gs:
		var roll = gs.iq_check(sheriff, 0, "Расследование: " + sheriff.npc_name)
		print("🔍 ", gs.describe_result(roll))
		if roll.critical:
			daily_evidence = 20.0
		elif roll.success:
			daily_evidence = 8.0 + float(roll.margin)
		elif roll.fumble:
			daily_evidence = 0.0
		else:
			daily_evidence = 3.0
	else:
		daily_evidence = randf_range(5.0, 15.0)
	investigation.evidence = clamp(investigation.evidence + daily_evidence, 0.0, 100.0)
	
	# Проверяем подозреваемых
	if investigation.evidence >= EVIDENCE_THRESHOLD_ARREST and investigation.culprit_id != -1:
		_arrest_suspect(investigation)

## Получить активного шерифа
func _get_active_sheriff() -> BaseNPC:
	var fallback: BaseNPC = null
	for npc in GameManager.npcs:
		if not is_instance_valid(npc) or not npc.is_alive or npc.role == null:
			continue
		if npc.role is SheriffRole:
			return npc
		if npc.role is InquisitionRole:
			fallback = npc
		elif fallback == null and npc.role is GarrisonSoldierRole:
			fallback = npc
	return fallback

## Арестовать подозреваемого
func _arrest_suspect(investigation: Investigation) -> void:
	if investigation.culprit_id == -1:
		return
	
	var suspect = GameManager.get_npc_by_id(investigation.culprit_id)
	if not suspect or not suspect.is_alive:
		return
	
	# Проверяем уровень улик
	if investigation.evidence >= EVIDENCE_THRESHOLD_CONVICT:
		# Полное раскрытие дела!
		investigation.is_solved = true
		investigation.is_active = false
		_solve_investigation(investigation, suspect)
	elif investigation.evidence >= EVIDENCE_THRESHOLD_ARREST:
		# Арест без полного доказательства
		_perform_arrest(investigation, suspect)

## Раскрыть дело
func _solve_investigation(investigation: Investigation, culprit: BaseNPC) -> void:
	investigation.is_solved = true
	GameManager.unsolved_murders = max(GameManager.unsolved_murders - 1, 0)
	
	emit_signal("investigation_solved", investigation, culprit.npc_id)
	
	# Наказание убийцы
	_apply_justice(culprit, true)
	
	print("✅ Дело #%d раскрыто! Убийца: %s" % [investigation.id, culprit.npc_name])

## Арест (без полного доказательства)
func _perform_arrest(investigation: Investigation, suspect: BaseNPC) -> void:
	print("🚔 Арестован подозреваемый: %s" % suspect.npc_name)
	
	# Арестованный не может действовать нормально
	if suspect.role is SheriffRole:
		return  # Шериф не может арестовать сам себя
	
	# Варианты наказания
	var evidence_level = investigation.evidence
	
	if evidence_level >= 90:
		# Прямое доказательство - казнь
		suspect.die(suspect)  # Самоубийство или казнь
		print("⚖️ %s приговорён к смерти за убийство %s" % [suspect.npc_name, investigation.victim_name])
	elif evidence_level >= 75:
		# Тюрьма на время
		_send_to_prison(suspect, 5)  # 5 дней
		print("⛓️ %s отправлен в тюрьму за убийство %s" % [suspect.npc_name, investigation.victim_name])
	else:
		# Подозрение - допрос
		interrogate_suspect(investigation, suspect.npc_id)
		print("❓ %s задержан для допроса по делу %s" % [suspect.npc_name, investigation.victim_name])

## Применить правосудие
func _apply_justice(culprit: BaseNPC, is_solved: bool) -> void:
	if not is_instance_valid(culprit):
		return
	
	# Эффект на репутацию
	for npc in GameManager.npcs:
		npc.relationship_graph.modify_relationship(npc.npc_id, culprit.npc_id, -50.0, 0.0, 30.0)
	
	if is_solved:
		# Убийца несёт наказание
		if culprit.role is SheriffRole:
			# Шериф-убийца - особый случай
			culprit.die(culprit)
		else:
			# Обычный убийца
			culprit.die(culprit)

## Отправить в тюрьму
func _send_to_prison(npc: BaseNPC, days: int) -> void:
	if GameManager.prison_system:
		GameManager.prison_system.send_to_prison(npc, days, "убийство")
	else:
		print("⛓️ %s в тюрьме на %d дней" % [npc.npc_name, days])

## Провал расследования
func _fail_investigation(investigation: Investigation, reason: String) -> void:
	investigation.is_active = false
	investigation.is_solved = false

	emit_signal("investigation_failed", reason)
	print("❌ Расследование #%d провалено: %s" % [investigation.id, reason])

## Допросить подозреваемого
func interrogate_suspect(investigation: Investigation, suspect_id: int) -> void:
	if suspect_id in investigation.interrogated:
		return
	
	investigation.interrogated.append(suspect_id)

	var suspect = GameManager.get_npc_by_id(suspect_id)
	var gained := EVIDENCE_PER_INTERROGATION
	var investigator = _get_active_sheriff()
	var gs: GURPSSystem = GameManager.gurps_system
	if gs and investigator and suspect:
		var contest = gs.quick_contest(
			investigator.gurps.intelligence if investigator.gurps else 10,
			suspect.gurps.current_will if suspect.gurps else 10,
			"Допрос: " + investigator.npc_name,
			"Воля: " + suspect.npc_name
		)
		if contest.winner == 1:
			gained = 10.0 + float(contest.margin)
			print("🗣️ %s раскололся на допросе" % suspect.npc_name)
		elif contest.winner == 2:
			gained = 3.0
			print("🗣️ %s держится на допросе" % suspect.npc_name)
	investigation.evidence = clamp(investigation.evidence + gained, 0.0, 100.0)
	if suspect:
		investigation.clues.append("Допрослен: %s" % suspect.npc_name)
	
	emit_signal("suspect_interrogated", investigation, suspect_id)
	
	# После допроса - проверка на решение дела
	if investigation.evidence >= EVIDENCE_THRESHOLD_CONVICT and investigation.culprit_id != -1:
		_solve_investigation(investigation, GameManager.get_npc_by_id(investigation.culprit_id))

## Обработка события убийства
func _on_npc_died(victim: BaseNPC, killer: BaseNPC) -> void:
	if killer == null or killer == victim:
		return
	start_investigation(victim, killer)

## Получить активное расследование для NPC
func get_investigation_about(npc_id: int) -> Investigation:
	for investigation in active_investigations:
		if investigation.victim_id == npc_id or investigation.culprit_id == npc_id:
			return investigation
	return null

## NPC под подозрением?
func is_under_investigation(npc_id: int) -> bool:
	return get_investigation_about(npc_id) != null

## Собрать улику
func add_evidence(investigation: Investigation, evidence_type: String, amount: float) -> void:
	investigation.evidence = clamp(investigation.evidence + amount, 0.0, 100.0)
	investigation.clues.append(evidence_type)
	
	emit_signal("evidence_found", investigation, evidence_type)
	print("🔎 Найдена улика: %s (+%.0f%%)" % [evidence_type, amount])
