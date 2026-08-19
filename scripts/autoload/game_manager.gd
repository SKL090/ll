## Глобальный менеджер игры
## Управляет игровым состоянием, NPC и событиями
class_name GameManager
extends Node

# Сигналы
signal day_changed(day: int)
signal night_started()
signal day_started()
signal npc_died(npc: BaseNPC, killer: BaseNPC)
signal crime_committed(crime_type: String, criminal: BaseNPC, victim: BaseNPC)
signal npc_created(npc: BaseNPC)

# Системы
var investigation_system: InvestigationSystem
var murder_system: MurderSystem
var event_system: EventSystem
var anarchy_system: AnarchySystem
var save_system: SaveSystem
var crime_system: CrimeSystem
var prison_system: PrisonSystem
var weather_system: WeatherSystem
var cult_system: CultSystem
var denunciation_system: DenunciationSystem

# Игровое состояние
var current_day: int = 1
var is_paused: bool = false
var game_speed: float = 1.0

# NPC
var npcs: Array[BaseNPC] = []

# Финансы
var city_treasury: float = 1000.0

# Метрики
var crime_rate: float = 0.0
var unsolved_murders: int = 0

func _ready():
	print("🎮 GameManager инициализирован")
	
	investigation_system = InvestigationSystem.new()
	murder_system = MurderSystem.new()
	event_system = EventSystem.new()
	anarchy_system = AnarchySystem.new()
	save_system = SaveSystem.new()
	crime_system = CrimeSystem.new()
	prison_system = PrisonSystem.new()
	weather_system = WeatherSystem.new()
	cult_system = CultSystem.new()
	denunciation_system = DenunciationSystem.new()
	
	add_child(investigation_system)
	add_child(murder_system)
	add_child(event_system)
	add_child(anarchy_system)
	add_child(save_system)
	add_child(crime_system)
	add_child(prison_system)
	add_child(weather_system)
	add_child(cult_system)
	add_child(denunciation_system)

func _process(delta: float):
	if not is_paused:
		anarchy_system.check_for_anarchy()

func register_npc(npc: BaseNPC) -> void:
	npcs.append(npc)
	emit_signal("npc_created", npc)

func unregister_npc(npc: BaseNPC) -> void:
	npcs.erase(npc)
	print("💀 ", npc.npc_name, " погиб")
	
	# Проверяем барона
	if npc.role is BaronRole:
		print("👑 БАРОН УБИТ! Анархия неизбежна...")

func get_npc_by_id(id: int) -> BaseNPC:
	for npc in npcs:
		if npc.npc_id == id:
			return npc
	return null

func get_npcs_by_role(role_type: String) -> Array[BaseNPC]:
	var result: Array[BaseNPC] = []
	for npc in npcs:
		if npc.role and npc.role.role_type == role_type:
			result.append(npc)
	return result

func commit_crime(crime_type: String, criminal: BaseNPC, victim: BaseNPC) -> void:
	emit_signal("crime_committed", crime_type, criminal, victim)
	
	match crime_type:
		"theft":
			print("🚨 %s украл у %s" % [criminal.npc_name, victim.npc_name])
		"murder":
			print("🩸 %s убил %s" % [criminal.npc_name, victim.npc_name])
			emit_signal("npc_died", victim, criminal)

func advance_day() -> void:
	current_day += 1
	
	event_system.check_for_events()
	event_system.update_events()
	anarchy_system.update()
	denunciation_system.cleanup_old_denouncements()
	
	if not anarchy_system.is_active():
		event_system.increase_order(2.0)
	
	emit_signal("day_changed", current_day)
	print("📅 День ", current_day)

func toggle_pause() -> void:
	is_paused = !is_paused
	print("⏸️ Пауза: ", is_paused)

func new_game() -> void:
	for npc in npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	npcs.clear()
	
	current_day = 1
	city_treasury = 1000.0
	crime_rate = 0.0
	unsolved_murders = 0
	is_paused = false
	
	if anarchy_system:
		anarchy_system.is_anarchy_active = false
		anarchy_system.days_in_anarchy = 0
	
	print("🔄 Новая игра!")

func save_game() -> bool:
	return save_system.save_game()

func load_game() -> bool:
	return save_system.load_game()

func get_city_stats() -> Dictionary:
	return {
		"population": npcs.size(),
		"alive": npcs.filter(func(n): return n.is_alive).size(),
		"dead": npcs.filter(func(n): return not n.is_alive).size(),
		"treasury": city_treasury,
		"crime_rate": crime_rate,
		"unsolved_murders": unsolved_murders,
		"is_anarchy": anarchy_system.is_active() if anarchy_system else false,
		"city_order": EventSystem.public_order if EventSystem else 100.0,
		"cult_power": cult_system.get_cult_power() if cult_system else 0.0,
	}
