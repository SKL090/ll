## Управление городом и спавн NPC
class_name City
extends Node2D

# Ссылки на узлы
@onready var npcs_container: Node2D = $NPCs
@onready var time_label: Label = $TimeLabel
@onready var phase_label: Label = $PhaseLabel
@onready var treasury_label: Label = $TreasuryLabel

# Префаб NPC
const NPC_SCENE = preload("res://scenes/characters/npc.tscn")

# Цвета для NPC
const NPC_COLORS = {
	"baron": Color(0.788, 0.635, 0.153),      # Золотой - Baron
	"inquisition": Color(0.5, 0.0, 0.0),       # Тёмно-красный - Инквизиция
	"bishop": Color(0.8, 0.8, 0.9),            # Светло-серый - Епископ
	"treasurer": Color(0.6, 0.6, 0.2),        # Грязно-жёлтый - Казначей
	"garrison": Color(0.3, 0.3, 0.5),         # Тёмно-синий - Солдат
	"resident": Color(0.8, 0.6, 0.4),         # Бежевый
}

# NPC ID счётчик
var next_npc_id: int = 1

func _ready() -> void:
	TimeSystem.connect("time_changed", _on_time_changed)
	TimeSystem.connect("phase_changed", _on_phase_changed)
	GameManager.connect("npc_died", _on_npc_died)
	GameManager.connect("crime_committed", _on_crime_committed)
	
	await get_tree().process_frame
	
	spawn_all_npcs()
	
	# Инициализируем культ через несколько секунд
	await get_tree().create_timer(2.0).timeout
	if GameManager.cult_system:
		GameManager.cult_system.initialize_cult()
	
	print("🏘️ Город инициализирован!")

func _process(_delta: float) -> void:
	treasury_label.text = "💰 %.0f" % GameManager.city_treasury

## Создание всех NPC
func spawn_all_npcs() -> void:
	# 👑 БАРОН (главный)
	spawn_npc("baron", Vector2(570, 210), "Барон Генрих")
	
	# ⛪ ЕПИСКОП
	spawn_npc("bishop", Vector2(540, 410), "Епископ Франциск")
	
	# 🔥 ИНКВИЗИТОР  
	spawn_npc("inquisition", Vector2(300, 350), "Инквизитор Торквемада")
	
	# 💰 КАЗНАЧЕЙ
	spawn_npc("treasurer", Vector2(500, 250), "Казначей Годфрид")
	
	# ⚔️ СОЛДАТЫ ГАРНИЗОНА (3)
	spawn_npc("garrison", Vector2(200, 320), "Капрал Маркус")
	spawn_npc("garrison", Vector2(180, 340), "Рядовой Петер")
	spawn_npc("garrison", Vector2(220, 340), "Рядовой Дитрих")
	
	# 👤 ЖИТЕЛИ (6)
	spawn_npc("resident", Vector2(685, 410), "Анна")
	spawn_npc("resident", Vector2(785, 410), "Борис")
	spawn_npc("resident", Vector2(685, 510), "Вера")
	spawn_npc("resident", Vector2(785, 510), "Григорий")
	spawn_npc("resident", Vector2(885, 410), "Дарья")
	spawn_npc("resident", Vector2(885, 510), "Егор")

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

	# Устанавливаем позиции для ролей
	if npc.role:
		match role_type:
			"baron":
				npc.role.home_position = Vector2(560, 200)
				npc.role.work_position = Vector2(540, 220)
			"bishop":
				npc.role.home_position = Vector2(540, 420)
				npc.role.work_position = Vector2(550, 410)
			"inquisition":
				npc.role.home_position = Vector2(280, 380)
				npc.role.work_position = Vector2(300, 350)
			"treasurer":
				npc.role.home_position = Vector2(460, 270)
				npc.role.work_position = Vector2(480, 250)
			"garrison":
				npc.role.home_position = Vector2(180, 320)
				npc.role.work_position = Vector2(200, 300)
				if custom_name == "Капрал Маркус":
					npc.role.assigned_zone = Vector2(400, 350)
				elif custom_name == "Рядовой Петер":
					npc.role.assigned_zone = Vector2(200, 350)
				else:
					npc.role.assigned_zone = Vector2(600, 280)
			"resident":
				_setup_resident_positions(npc, custom_name)

	print("👤 %s (%s) создан" % [npc_name, role_type])
	
	return npc

func _setup_resident_positions(npc: BaseNPC, name: String) -> void:
	match name:
		"Анна":
			npc.role.home_position = Vector2(685, 410)
			npc.role.work_position = Vector2(460, 410)
		"Борис":
			npc.role.home_position = Vector2(785, 410)
			npc.role.work_position = Vector2(460, 410)
		"Вера":
			npc.role.home_position = Vector2(685, 510)
			npc.role.work_position = Vector2(150, 175)
		"Григорий":
			npc.role.home_position = Vector2(785, 510)
			npc.role.work_position = Vector2(150, 175)
		"Дарья":
			npc.role.home_position = Vector2(885, 410)
			npc.role.work_position = Vector2(460, 410)
		"Егор":
			npc.role.home_position = Vector2(885, 510)
			npc.role.work_position = Vector2(150, 175)

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
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_bodies = true
	query.collision_mask = 2

	var results = space.intersect_point(query, 10)
	
	for result in results:
		var collider = result["collider"]
		if collider is BaseNPC:
			return collider
	
	return null

func restart_game() -> void:
	for child in npcs_container.get_children():
		child.queue_free()
	
	GameManager.new_game()
	
	await get_tree().process_frame
	next_npc_id = 1
	spawn_all_npcs()
	await get_tree().create_timer(0.4).timeout
	if GameManager.cult_system:
		GameManager.cult_system.initialize_cult()
