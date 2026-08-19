## Роль Казначея
class_name TreasurerRole
extends Role

# Казна
@export var treasury_position: Vector2 = Vector2(480, 250)

# Статус
var is_corrupt: bool = false  # Ворует ли казначей
var stolen_amount: float = 0.0
var corruption_level: float = 0.0  # Уровень коррупции

# Настройки
const CORRUPTION_CHANCE: float = 0.3  # 30% шанс быть коррумпированным
const STEAL_PERCENTAGE: float = 0.1  # Ворует 10% от казны

func _init():
	role_type = "treasurer"
	work_start_hour = 8.0
	work_end_hour = 18.0
	sleep_start_hour = 22.0
	sleep_end_hour = 7.0

func initialize(npc: BaseNPC) -> void:
	super.initialize(npc)
	work_position = treasury_position
	home_position = Vector2(460, 270)
	
	# Определяем уровень коррупции
	if randf() < CORRUPTION_CHANCE:
		is_corrupt = true
		corruption_level = randf_range(20.0, 60.0)
		print("💰 Казначей %s коррумпирован! (%.0f%%)" % [npc.npc_name, corruption_level])

func update(delta: float) -> void:
	super.update(delta)
	
	# Казначей работает с деньгами
	if is_corrupt:
		_try_steal(delta)

func _try_steal(delta: float) -> void:
	# Ворует понемногу каждый день
	var steal_amount = GameManager.city_treasury * STEAL_PERCENTAGE * delta * 0.1
	
	if steal_amount > 0.5:
		GameManager.city_treasury -= steal_amount
		owner_npc.wealth += steal_amount
		stolen_amount += steal_amount
		
		# Шанс быть пойманным
		if randf() < 0.01:  # 1% шанс в секунду
			_caught_stealing()

func _caught_stealing() -> void:
	print("💰💰💰 Казначей %s пойман на воровстве!" % owner_npc.npc_name)
	
	# Отношения с бароном резко падают
	var baron = _get_baron()
	if baron:
		owner_npc.relationship_graph.modify_relationship(
			owner_npc.npc_id,
			baron.npc_id,
			trust_delta: -100.0,
			hate_delta: 50.0
		)
		
		# Барон наказывает
		baron.role.assign_punishment(owner_npc, "imprisonment") if baron.role else None

func _get_baron() -> BaseNPC:
	for npc in GameManager.npcs:
		if npc.role is BaronRole:
			return npc
	return null

func get_current_behavior() -> String:
	var time = TimeSystem.current_time
	
	var priority_need = owner_npc.need_system.get_priority_need()
	if priority_need != "":
		return priority_need
	
	# Работа в казне
	if time >= 8.0 and time < 12.0:
		return "count_money"
	elif time >= 12.0 and time < 14.0:
		return "lunch"
	elif time >= 14.0 and time < 18.0:
		return "distribute_funds"
	elif time >= 18.0 and time < 22.0:
		return "evening_work"
	
	return "sleep"

func get_target_position() -> Vector2:
	match get_current_behavior():
		"count_money", "distribute_funds", "evening_work":
			return treasury_position
		"lunch":
			return home_position
		"meet_baron":
			var baron = _get_baron()
			if baron:
				return baron.global_position
		"sleep":
			return home_position
	return home_position

## Распределить средства жителям
func distribute_funds_to_residents() -> void:
	# Каждому жителю - поровну
	var total_to_distribute = GameManager.city_treasury * 0.1  # 10% казны
	
	var residents: Array[BaseNPC] = []
	for npc in GameManager.npcs:
		if npc.role is ResidentRole:
			residents.append(npc)
	
	if residents.size() == 0:
		return
	
	var per_resident = total_to_distribute / float(residents.size())
	
	for resident in residents:
		resident.wealth += per_resident
	
	GameManager.city_treasury -= total_to_distribute
	
	print("💰 Казначей распределил %.0f между %d жителями" % [total_to_distribute, residents.size()])

## Собрать налоги
func collect_taxes() -> void:
	var baron = _get_baron()
	var tax_rate = 0.2  # 20% по умолчанию
	
	if baron and baron.role is BaronRole:
		tax_rate = baron.role.taxation_rate
	
	for npc in GameManager.npcs:
		if npc == owner_npc:
			continue
		
		var tax = npc.wealth * tax_rate
		if tax > 0:
			npc.wealth -= tax
			GameManager.city_treasury += tax
	
	print("💰 Налоги собраны! Казна: %.0f" % GameManager.city_treasury)

## Получить отчёт о казне
func get_treasury_report() -> String:
	var report = "💰 ОТЧЁТ КАЗНЫ:\n"
	report += "Баланс: %.0f\n" % GameManager.city_treasury
	report += "Всего NPC: %d\n" % GameManager.npcs.size()
	report += "Среднее богатство: %.1f\n" % _get_average_wealth()
	
	if is_corrupt:
		report += "⚠️ ВНИМАНИЕ: Казначей подозревается в коррупции!\n"
		report += "Украдено: %.0f\n" % stolen_amount
	
	return report

func _get_average_wealth() -> float:
	if GameManager.npcs.size() == 0:
		return 0.0
	
	var total: float = 0.0
	for npc in GameManager.npcs:
		total += npc.wealth
	
	return total / float(GameManager.npcs.size())

func get_description() -> String:
	var corrupt_text = ""
	if is_corrupt:
		corrupt_text = " [КОРРУПЦИЯ: %.0f%%]" % corruption_level
	return "Казначей. Управляет деньгами.%s" % corrupt_text
