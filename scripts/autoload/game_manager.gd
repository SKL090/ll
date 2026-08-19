## Глобальный менеджер игры
## Управляет игровым состоянием, NPC и событиями
class_name GameManager
extends Node

signal day_changed(day: int)
signal night_started()
signal day_started()
signal npc_died(npc: BaseNPC, killer: BaseNPC)
signal crime_committed(crime_type: String, criminal: BaseNPC, victim: BaseNPC)
signal npc_created(npc: BaseNPC)

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
var gurps_system: GURPSSystem

var current_day: int = 1
var is_paused: bool = false
var game_speed: float = 1.0

var npcs: Array[BaseNPC] = []

var city_treasury: float = 1000.0

var crime_rate: float = 0.0
var unsolved_murders: int = 0


func _ready() -> void:
	print("🎮 GameManager инициализирован")

	gurps_system = GURPSSystem.new()
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

	add_child(gurps_system)
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


func _process(delta: float) -> void:
	if is_paused:
		return
	if anarchy_system:
		anarchy_system.check_for_anarchy()
	if crime_system:
		crime_system.update_crimes(delta)


func register_npc(npc: BaseNPC) -> void:
	if npc in npcs:
		return
	npcs.append(npc)
	emit_signal("npc_created", npc)


func unregister_npc(npc: BaseNPC) -> void:
	if npc == null:
		return
	npcs.erase(npc)
	print("💀 ", npc.npc_name, " погиб")

	if npc.role is BaronRole or npc.role is MayorRole:
		print("👑 Правитель убит! Анархия неизбежна...")


func get_npc_by_id(id: int) -> BaseNPC:
	for npc in npcs:
		if is_instance_valid(npc) and npc.npc_id == id:
			return npc
	return null


func get_npcs_by_role(role_type: String) -> Array[BaseNPC]:
	var result: Array[BaseNPC] = []
	for npc in npcs:
		if is_instance_valid(npc) and npc.role and npc.role.role_type == role_type:
			result.append(npc)
	return result


func get_ruler() -> BaseNPC:
	for npc in npcs:
		if not is_instance_valid(npc) or not npc.is_alive or npc.role == null:
			continue
		if npc.role is MayorRole or npc.role is BaronRole:
			return npc
	return null


func commit_crime(crime_type: String, criminal: BaseNPC, victim: BaseNPC) -> void:
	emit_signal("crime_committed", crime_type, criminal, victim)

	match crime_type:
		"theft":
			print("🚨 %s украл у %s" % [criminal.npc_name, victim.npc_name])
		"murder":
			print("🩸 %s убил %s" % [criminal.npc_name, victim.npc_name])
			unsolved_murders += 1
			emit_signal("npc_died", victim, criminal)


func advance_day() -> void:
	current_day = TimeSystem.current_day

	if murder_system:
		murder_system.update_all_plans()
	if investigation_system:
		investigation_system.update_investigations()
	if event_system:
		event_system.check_for_events()
		event_system.update_events()
	if anarchy_system:
		anarchy_system.update()
	if prison_system:
		prison_system.update_daily()
	if denunciation_system:
		denunciation_system.cleanup_old_denouncements()
		for npc in npcs:
			if is_instance_valid(npc) and npc.is_alive:
				denunciation_system.consider_denouncement(npc)

	for npc in npcs:
		if is_instance_valid(npc) and npc.is_alive and npc.need_system:
			npc.need_system.daily_reset()
		if is_instance_valid(npc) and npc.is_alive and npc.gurps:
			_daily_heal(npc)

	if event_system and anarchy_system and not anarchy_system.is_active():
		event_system.increase_order(2.0)

	emit_signal("day_changed", current_day)
	print("📅 День ", current_day)


func _daily_heal(npc: BaseNPC) -> void:
	if npc.gurps == null or gurps_system == null:
		return
	if npc.gurps.current_hp >= npc.gurps.max_hp:
		return
	var roll = gurps_system.ht_check(npc, 0, "Лечение: " + npc.npc_name)
	if roll.success:
		var amount = 2 if roll.critical else 1
		npc.gurps.heal(amount)
		print("💚 %s восстановил %d HP (%s)" % [npc.npc_name, amount, gurps_system.describe_result(roll)])


func toggle_pause() -> void:
	is_paused = not is_paused
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

	TimeSystem.current_time = 6.0
	TimeSystem.current_day = 1
	TimeSystem.is_night = false
	TimeSystem._daily_systems_ran_for_day = 0
	TimeSystem._previous_phase = TimeSystem.get_current_phase()

	if anarchy_system:
		anarchy_system.is_anarchy_active = false
		anarchy_system.days_in_anarchy = 0
		anarchy_system.temp_leader_id = -1
	if murder_system:
		murder_system.murder_plans.clear()
	if investigation_system:
		investigation_system.active_investigations.clear()
	if event_system:
		event_system.active_events.clear()
		event_system.public_order = 100.0
		event_system.city_status = "stable"
	if prison_system:
		prison_system.prisoners.clear()
	if cult_system:
		cult_system.cultists.clear()
		cult_system.cult_power = 0.0
		cult_system.cult_awareness = 0.0
		cult_system.cult_leader_id = -1
	if crime_system:
		crime_system.active_arson_attempts.clear()
		crime_system.active_kidnappings.clear()
	if denunciation_system:
		denunciation_system.denouncements.clear()

	print("🔄 Новая игра!")


func save_game() -> bool:
	return save_system.save_game()


func load_game() -> bool:
	return save_system.load_game()


func get_city_stats() -> Dictionary:
	var alive_count := 0
	var dead_count := 0
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		if npc.is_alive:
			alive_count += 1
		else:
			dead_count += 1

	return {
		"population": npcs.size(),
		"alive": alive_count,
		"dead": dead_count,
		"treasury": city_treasury,
		"crime_rate": crime_rate,
		"unsolved_murders": unsolved_murders,
		"is_anarchy": anarchy_system.is_active() if anarchy_system else false,
		"city_order": event_system.public_order if event_system else 100.0,
		"cult_power": cult_system.get_cult_power() if cult_system else 0.0,
	}
