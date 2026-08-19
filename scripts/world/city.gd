## Управление городом и спавн NPC
class_name City
extends Node2D

# Ссылки на узлы
@onready var npcs_container: Node2D = $NPCs
@onready var time_label: Label = $HUDTop/TimeLabel
@onready var phase_label: Label = $HUDTop/PhaseLabel
@onready var treasury_label: Label = $HUDTop/TreasuryLabel

# Префаб NPC
const NPC_SCENE = preload("res://scenes/characters/npc.tscn")

# Цвета для NPC (куклы: цвет — туника)
const NPC_COLORS = {
	"baron": Color(0.788, 0.635, 0.153),      # Золотой
	"inquisition": Color(0.5, 0.0, 0.0),       # Тёмно-красный
	"bishop": Color(0.8, 0.8, 0.9),            # Светло-серый
	"treasurer": Color(0.6, 0.6, 0.2),         # Грязно-жёлтый
	"garrison": Color(0.3, 0.3, 0.5),          # Тёмно-синий
	"merchant": Color(0.9, 0.6, 0.2),          # Оранжевый
	"resident": Color(0.35, 0.55, 0.75),       # Синий
}

# NPC ID счётчик
var next_npc_id: int = 1


func _ready() -> void:
	GameManager.world_map = $WorldMap

	TimeSystem.connect("time_changed", _on_time_changed)
	TimeSystem.connect("phase_changed", _on_phase_changed)
	GameManager.connect("npc_died", _on_npc_died)
	GameManager.connect("crime_committed", _on_crime_committed)

	await get_tree().process_frame

	spawn_all_npcs()
	_assign_beds()

	# Инициализируем культ через пару секунд
	await get_tree().create_timer(2.0).timeout
	if GameManager.cult_system:
		GameManager.cult_system.initialize_cult()

	print("🏘️ Город инициализирован!")


func _process(_delta: float) -> void:
	treasury_label.text = "💰 %.0f" % GameManager.city_treasury


## Создание всех NPC
func spawn_all_npcs() -> void:
	# 👑 БАРОН (в замке)
	spawn_npc("baron", _cw(16, 7), "Барон Генрих")

	# 💰 КАЗНАЧЕЙ (в замке)
	spawn_npc("treasurer", _cw(17, 7), "Казначей Годфрид")

	# ⛪ ЕПИСКОП (в соборе)
	spawn_npc("bishop", _cw(41, 7), "Епископ Франциск")

	# 🔥 ИНКВИЗИТОР
	spawn_npc("inquisition", _cw(42, 16), "Инквизитор Торквемада")

	# ⚔️ СОЛДАТЫ ГАРНИЗОНА (в казарме)
	spawn_npc("garrison", _cw(4, 15), "Капрал Маркус")
	spawn_npc("garrison", _cw(7, 15), "Рядовой Петер")
	spawn_npc("garrison", _cw(5, 17), "Рядовой Дитрих")

	# 🛒 ТОРГОВЕЦ (в лавке)
	spawn_npc("merchant", _cw(40, 28), "Торговец Мориц")

	# 👤 ЖИТЕЛИ (по домам)
	spawn_npc("resident", _cw(12, 28), "Анна")
	spawn_npc("resident", _cw(14, 28), "Егор")
	spawn_npc("resident", _cw(50, 28), "Борис")
	spawn_npc("resident", _cw(52, 28), "Дарья")
	spawn_npc("resident", _cw(40, 35), "Вера")
	spawn_npc("resident", _cw(48, 35), "Григорий")


## Центр клетки в мировых координатах
func _cw(x: int, y: int) -> Vector2:
	if GameManager.world_map:
		return GameManager.world_map.cell_center_world(Vector2i(x, y))
	return Vector2(x * 64 + 32, y * 64 + 32)


## Спавн одного NPC
func spawn_npc(role_type: String, position: Vector2, custom_name: String = "") -> BaseNPC:
	var npc = NPC_SCENE.instantiate() as BaseNPC

	var npc_id = next_npc_id
	next_npc_id += 1

	var npc_name = custom_name if custom_name != "" else "NPC"
	var color = NPC_COLORS.get(role_type, Color.WHITE)

	npc.position = position
	npcs_container.add_child(npc)
	npc.initialize(npc_id, npc_name, color, role_type)

	# «Отбираем еду» — все начинают голодными, без запасов
	npc.food = 0.0
	npc.need_system.hunger = randf_range(12.0, 28.0)
	# стартовые деньги, чтобы было на что покупать еду
	match role_type:
		"resident":
			npc.wealth = randf_range(30.0, 60.0)
		"merchant":
			npc.wealth = 200.0
		"baron":
			npc.wealth = 300.0
		_:
			npc.wealth = 60.0

	# Устанавливаем позиции для ролей (тайловые координаты)
	if npc.role:
		match role_type:
			"baron":
				npc.role.home_position = _cw(16, 7)
				npc.role.work_position = _cw(17, 8)
			"treasurer":
				npc.role.home_position = _cw(17, 7)
				npc.role.work_position = _cw(19, 9)
			"bishop":
				npc.role.home_position = _cw(41, 7)
				npc.role.work_position = _cw(44, 8)
			"inquisition":
				npc.role.home_position = _cw(42, 16)
				npc.role.work_position = _cw(44, 17)
			"garrison":
				npc.role.home_position = position
				npc.role.work_position = _cw(5, 16)
				if custom_name == "Капрал Маркус":
					npc.role.assigned_zone = _cw(31, 20)
				elif custom_name == "Рядовой Петер":
					npc.role.assigned_zone = _cw(5, 16)
				else:
					npc.role.assigned_zone = _cw(44, 8)
			"merchant":
				npc.role.home_position = _cw(40, 28)
				npc.role.work_position = _cw(42, 29)
			"resident":
				_setup_resident_positions(npc, custom_name)

	print("👤 %s (%s) создан" % [npc_name, role_type])

	return npc


## Раздаём кровати: каждый NPC получает ближайшую к дому свободную кровать
func _assign_beds() -> void:
	if GameManager.world_map == null:
		return
	# сортируем NPC по близости к кроватям не нужно — просто забираем ближайшую к дому
	for npc in GameManager.npcs:
		if not is_instance_valid(npc) or not npc.is_alive:
			continue
		var home: Vector2 = npc.role.home_position if npc.role else npc.global_position
		var bed: Vector2 = GameManager.world_map.claim_bed_near(home)
		if bed != Vector2.ZERO:
			npc.bed_position = bed
			print("🛏️ %s спит в кровати %s" % [npc.npc_name, str(bed)])


func _setup_resident_positions(npc: BaseNPC, name: String) -> void:
	var farm1 := _cw(5, 6)
	var farm2 := _cw(4, 7)
	var market := _cw(31, 20)
	match name:
		"Анна":
			npc.role.home_position = _cw(12, 28)
			npc.role.work_position = farm1
		"Егор":
			npc.role.home_position = _cw(14, 28)
			npc.role.work_position = farm2
		"Борис":
			npc.role.home_position = _cw(50, 28)
			npc.role.work_position = farm1
		"Дарья":
			npc.role.home_position = _cw(52, 28)
			npc.role.work_position = market
		"Вера":
			npc.role.home_position = _cw(40, 35)
			npc.role.work_position = farm2
		"Григорий":
			npc.role.home_position = _cw(48, 35)
			npc.role.work_position = farm1


func _on_time_changed(game_time: float) -> void:
	time_label.text = "День %d | %s" % [GameManager.current_day, TimeSystem.get_time_string()]


func _on_phase_changed(phase: TimeSystem.TimePhase) -> void:
	phase_label.text = TimeSystem.get_phase_description()


func _on_npc_died(npc: BaseNPC, killer: BaseNPC) -> void:
	var killer_name = killer.npc_name if killer else "неизвестным"
	print("💀 %s был убит %s" % [npc.npc_name, killer_name])


func _on_crime_committed(crime_type: String, criminal: BaseNPC, victim: BaseNPC) -> void:
	match crime_type:
		"theft":
			print("🚨 %s украл у %s" % [criminal.npc_name, victim.npc_name])
		"murder":
			print("🩸 %s убил %s" % [criminal.npc_name, victim.npc_name])
		"heresy":
			print("🔥 %s обвинён в ереси!" % victim.npc_name)


func get_npc_at_position(pos: Vector2) -> BaseNPC:
	var radius := 32.0
	if GameManager.world_map:
		radius = GameManager.world_map.get_tile_size() * 0.55

	var best: BaseNPC = null
	var best_d: float = radius

	for npc in GameManager.npcs:
		if not is_instance_valid(npc) or not npc.is_alive:
			continue
		# проверяем расстояние до тела (ноги) и до головы куклы
		var d_feet: float = pos.distance_to(npc.global_position)
		var d_head: float = pos.distance_to(npc.global_position + Vector2(0, -radius * 1.6))
		var d: float = min(d_feet, d_head)
		if d < best_d:
			best_d = d
			best = npc

	return best


func restart_game() -> void:
	for child in npcs_container.get_children():
		child.queue_free()

	GameManager.new_game()
	if GameManager.world_map:
		GameManager.world_map.rebuild()

	await get_tree().process_frame
	next_npc_id = 1
	spawn_all_npcs()
	await get_tree().create_timer(0.4).timeout
	if GameManager.cult_system:
		GameManager.cult_system.initialize_cult()
