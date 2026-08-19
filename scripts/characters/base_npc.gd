## Базовый класс NPC
class_name BaseNPC
extends CharacterBody2D

# === СТАТИСТИКА ===
var npc_id: int
var npc_name: String = "NPC"
var base_color: Color = Color.WHITE

# === СИСТЕМЫ NPC ===
@onready var need_system: NeedSystem = NeedSystem.new()
@onready var relationship_graph: RelationshipGraph = RelationshipGraph.new()
@onready var memory_system: MemorySystem = MemorySystem.new()
@onready var planning_system: PlanningSystem = PlanningSystem.new()
@onready var state_machine: NPCStateMachine = NPCStateMachine.new()

# === РОЛЬ ===
var role: Role

# === ФИЗИКА ===
@export var move_speed: float = 80.0

# === СОСТОЯНИЕ ===
var wealth: float = 50.0
var is_alive: bool = true
var current_target: Node2D = null

# === ВИЗУАЛ ===
@onready var sprite: Sprite2D = $Sprite
@onready var label: Label = $Label
@onready var state_label: Label = $StateLabel
@onready var collision: CollisionShape2D = $CollisionShape2D

# Цвета эмоций
const EMOTION_COLORS = {
	"happy": Color(0.486, 0.702, 0.259),     # Зелёный
	"neutral": Color(0.992, 0.851, 0.208), # Жёлтый
	"angry": Color(0.898, 0.224, 0.208),  # Красный
	"sleepy": Color(0.361, 0.420, 0.737),  # Синий
	"hungry": Color(0.553, 0.431, 0.388),  # Коричневый
}

var current_emotion: String = "neutral"

func _ready() -> void:
	# Добавляем системы как дети
	add_child(need_system)
	add_child(relationship_graph)
	add_child(memory_system)
	add_child(planning_system)
	add_child(state_machine)
	
	# Настраиваем планирование
	planning_system.set_references(relationship_graph, memory_system)
	
	# Регистрируем в GameManager
	GameManager.register_npc(self)
	
	# Подключаем сигналы
	need_system.connect("critical_need", _on_critical_need)
	state_machine.connect("state_changed", _on_state_changed)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	
	# Обновляем системы
	need_system._process(delta)
	
	# AI поведение
	_update_ai(delta)
	
	# Обновляем визуал
	_update_visual()

func _process(delta: float) -> void:
	if not is_alive:
		return
	
	# Обновляем label с информацией
	if label:
		label.text = npc_name
	if state_label:
		state_label.text = state_machine.get_state_name()

## Инициализация NPC
func initialize(id: int, name: String, color: Color, role_type: String = "resident") -> void:
	npc_id = id
	npc_name = name
	base_color = color
	
	# Устанавливаем спрайт
	if sprite:
		sprite.modulate = color
	
	# Создаём роль
	_create_role(role_type)
	
	# Генерируем начальные отношения
	_generate_initial_relationships()

## Создание роли
func _create_role(role_type: String) -> void:
	match role_type:
		"mayor":
			role = MayorRole.new()
		"sheriff":
			role = SheriffRole.new()
		"resident":
			role = ResidentRole.new()
		_:
			role = Role.new()
	
	add_child(role)
	role.initialize(self)

## Генерация начальных отношений
func _generate_initial_relationships() -> void:
	var all_ids: Array[int] = []
	for npc in GameManager.npcs:
		all_ids.append(npc.npc_id)
	all_ids.append(npc_id)  # Добавляем себя
	
	relationship_graph.generate_initial_relationships(npc_id, all_ids)
	
	# Особые отношения для ролей
	_setup_role_relationships(role_type)

func _setup_role_relationships(role_type: String) -> void:
	match role_type:
		"mayor":
			# К мэру относятся с уважением и завистью
			for npc in GameManager.npcs:
				relationship_graph.modify_relationship(npc.npc_id, npc_id, trust_delta: 20.0, love_delta: 15.0)
		"sheriff":
			# К шерифу относятся с уважением
			for npc in GameManager.npcs:
				relationship_graph.modify_relationship(npc.npc_id, npc_id, trust_delta: 30.0)

## AI обновление
var murder_check_timer: float = 0.0
const MURDER_CHECK_INTERVAL: float = 10.0  # Проверка каждые 10 секунд

func _update_ai(delta: float) -> void:
	# Проверяем критические потребности
	if need_system.has_critical_need():
		_handle_critical_need()
		return
	
	# Проверяем возможность/желание убийства (периодически)
	murder_check_timer += delta
	if murder_check_timer >= MURDER_CHECK_INTERVAL:
		murder_check_timer = 0.0
		_check_murder_desire()
	
	# Обновляем роль
	if role:
		var behavior = role.get_current_behavior()
		_handle_behavior(behavior)

## Обработка критической потребности
func _handle_critical_need() -> void:
	var priority_need = need_system.get_priority_need()
	
	match priority_need:
		"hunger":
			state_machine.start_eating()
			need_system.eat()
		"energy":
			state_machine.start_sleeping()
			need_system.sleep()
		"social":
			state_machine.start_socializing()
			need_system.socialize()

## Обработка поведения
func _handle_behavior(behavior: String) -> void:
	match behavior:
		"sleep":
			if state_machine.current_state != state_machine.State.SLEEPING:
				state_machine.move_to(role.home_position)
		"work":
			if state_machine.current_state != state_machine.State.WORKING:
				state_machine.move_to(role.work_position)
		"wander", "social", "evening":
			if state_machine.current_state == state_machine.State.IDLE:
				var target = role.get_target_position()
				state_machine.move_to(target)
		"steal":
			if role is ResidentRole:
				role.attempt_theft()
				state_machine.start_stealing()

## Проверка желания убийства
func _check_murder_desire() -> void:
	# Не убиваем если нет системы
	if not GameManager.murder_system:
		return
	
	# Проверяем, не планируется ли уже убийство
	if GameManager.murder_system.murder_plans.has(npc_id):
		return
	
	# Проверяем каждого NPC на накопленную ненависть
	for other in GameManager.npcs:
		if other.npc_id == npc_id:
			continue
		if not other.is_alive:
			continue
		
		var rel = relationship_graph.get_relationship(npc_id, other.npc_id)
		
		# Если ненависть очень высока - начинаем планирование
		if rel.hate >= 60.0 and rel.trust < -20.0:
			GameManager.murder_system.start_planning_murder(self, other)
			print("💭 %s вынашивает план против %s (ненависть: %.0f)" % [npc_name, other.npc_name, rel.hate])
			break

## Обновление визуала
func _update_visual() -> void:
	# Определяем эмоцию по потребностям
	var emotion = _calculate_emotion()
	
	if emotion != current_emotion:
		current_emotion = emotion
		_apply_emotion_color(emotion)

func _calculate_emotion() -> String:
	if need_system.energy < 30:
		return "sleepy"
	elif need_system.hunger < 30:
		return "hungry"
	elif _has_enemies():
		return "angry"
	else:
		return "happy" if need_system.social > 50 else "neutral"

func _has_enemies() -> bool:
	var enemies = relationship_graph.get_enemies(npc_id)
	return enemies.size() > 0

func _apply_emotion_color(emotion: String) -> void:
	if sprite and EMOTION_COLORS.has(emotion):
		sprite.modulate = EMOTION_COLORS[emotion]

## Сигналы
func _on_critical_need(need_name: String) -> void:
	print("⚠️ ", npc_name, " критическая потребность: ", need_name)

func _on_state_changed(from_state: String, to_state: String) -> void:
	# Можно добавить звуки или эффекты при смене состояния
	pass

## Получить урон (для убийства)
func take_damage(amount: float = 100.0) -> void:
	# NPC просто "умирает" мгновенно для простоты
	die()

## Умереть
func die(killer: BaseNPC = null) -> void:
	if not is_alive:
		return
	
	is_alive = false
	
	# Уведомляем системы
	GameManager.unregister_npc(self)
	
	if killer:
		killer.memory_system.add_memory(
			MemorySystem.EventType.MURDER,
			npc_id,
			"Убил " + npc_name
		)
		
		# Расследование для шерифа
		for npc in GameManager.npcs:
			if npc.role is SheriffRole:
				npc.role.start_investigation(killer.npc_id)
	
	# Анимация смерти (позже можно добавить)
	queue_free()

## Взаимодействие с другим NPC
func interact_with(other: BaseNPC, action: String) -> void:
	match action:
		"help":
			relationship_graph.help(npc_id, other.npc_id)
			memory_system.add_memory(MemorySystem.EventType.HELP, other.npc_id, "Помог " + other.npc_name)
		"insult":
			relationship_graph.insult(npc_id, other.npc_id)
			memory_system.add_memory(MemorySystem.EventType.INSULT, other.npc_id, "Оскорбил " + other.npc_name)
		"meet":
			memory_system.add_memory(MemorySystem.EventType.MEETING, other.npc_id, "Встретился с " + other.npc_name)

## Получить информацию для UI
func get_info() -> Dictionary:
	return {
		"name": npc_name,
		"role": role.role_type if role else "unknown",
		"state": state_machine.get_state_name(),
		"emotion": current_emotion,
		"wealth": wealth,
		"needs": {
			"hunger": need_system.hunger,
			"energy": need_system.energy,
			"social": need_system.social,
		},
		"enemies": relationship_graph.get_enemies(npc_id).size(),
		"friends": relationship_graph.get_friends(npc_id).size(),
	}
