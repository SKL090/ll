## Машина состояний для NPC
class_name NPCStateMachine
extends Node

signal state_changed(from_state: String, to_state: String)

enum State {
	IDLE,
	WALKING,
	WORKING,
	EATING,
	SLEEPING,
	SOCIALIZING,
	PATROLLING,
	STEALING,
	INVESTIGATING,
	FLEEING,
	ARRESTING,
}

var current_state: State = State.IDLE
var previous_state: State = State.IDLE

var owner_npc: Node2D

var state_timer: float = 0.0
var min_state_duration: float = 1.0

var target_position: Vector2 = Vector2.ZERO
var target_node: Node2D = null

# Путь по тайловой карте
var path: Array[Vector2] = []
var path_index: int = 0
var _stuck_time: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO


func _init(p_owner: Node2D = null) -> void:
	owner_npc = p_owner


func set_owner_npc(p_owner: Node2D) -> void:
	owner_npc = p_owner


func _physics_process(delta: float) -> void:
	if GameManager.is_paused:
		return
	if owner_npc == null or not is_instance_valid(owner_npc):
		return
	if owner_npc is BaseNPC and not owner_npc.is_alive:
		return

	state_timer += delta
	_process_state(delta)


func _process_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.WALKING:
			_process_walking(delta)
		State.WORKING:
			_process_working(delta)
		State.EATING:
			_process_eating(delta)
		State.SLEEPING:
			_process_sleeping(delta)
		State.SOCIALIZING:
			_process_socializing(delta)
		State.PATROLLING:
			_process_patrolling(delta)
		State.STEALING:
			_process_stealing(delta)
		State.INVESTIGATING:
			_process_investigating(delta)
		State.FLEEING:
			_process_fleeing(delta)
		State.ARRESTING:
			_process_arresting(delta)


func change_state(new_state: State) -> void:
	if new_state == current_state:
		return

	previous_state = current_state
	current_state = new_state
	state_timer = 0.0

	var from_name = State.keys()[previous_state]
	var to_name = State.keys()[new_state]
	emit_signal("state_changed", from_name, to_name)
	_on_state_enter(new_state)


func _on_state_enter(_state: State) -> void:
	if owner_npc:
		owner_npc.velocity = Vector2.ZERO


func _process_idle(_delta: float) -> void:
	if owner_npc:
		owner_npc.velocity = Vector2.ZERO


func _process_walking(_delta: float) -> void:
	if path.size() > 0 and path_index < path.size():
		var way: Vector2 = path[path_index]
		if owner_npc.global_position.distance_to(way) < 8.0:
			path_index += 1
			if path_index >= path.size():
				_on_target_reached()
				return
			way = path[path_index]

		_move_towards(way)

		# открываем двери на пути
		if owner_npc is BaseNPC and GameManager.world_map:
			GameManager.world_map.open_door_near(owner_npc.global_position)

		_check_stuck()
		return

	# Запасной вариант — движение напрямую
	if target_position == Vector2.ZERO:
		change_state(State.IDLE)
		return

	var distance: float = owner_npc.global_position.distance_to(target_position)
	if distance < 8.0:
		_on_target_reached()
		return

	_move_towards(target_position)
	if owner_npc is BaseNPC and GameManager.world_map:
		GameManager.world_map.open_door_near(owner_npc.global_position)


func _move_towards(point: Vector2) -> void:
	var direction: Vector2 = point - owner_npc.global_position
	direction = direction.normalized()
	owner_npc.velocity = direction * owner_npc.move_speed
	owner_npc.move_and_slide()


func _check_stuck() -> void:
	var moved: float = owner_npc.global_position.distance_to(_last_pos)
	if moved < 2.0:
		_stuck_time += get_physics_process_delta_time()
	else:
		_stuck_time = 0.0
	_last_pos = owner_npc.global_position

	if _stuck_time > 1.5:
		_stuck_time = 0.0
		# пересчитываем путь (стены могли измениться из-за огня)
		if owner_npc is BaseNPC and GameManager.world_map:
			path = GameManager.world_map.find_path_world(owner_npc.global_position, target_position)
			path_index = 0 if path.size() == 0 else 1


func _process_working(_delta: float) -> void:
	if owner_npc:
		owner_npc.velocity = Vector2.ZERO


func _process_eating(delta: float) -> void:
	var npc: BaseNPC = owner_npc as BaseNPC
	if npc == null:
		change_state(State.IDLE)
		return
	# еда кончилась — идём покупать
	if npc.food <= 0.0:
		change_state(State.IDLE)
		return
	npc.food = max(0.0, npc.food - 1.0 * delta)
	_restore_need("hunger", delta)
	if state_timer > 5.0 or _need_value("hunger") >= 90.0 or npc.food <= 0.0:
		change_state(State.IDLE)


func _process_sleeping(delta: float) -> void:
	_restore_need("energy", delta)
	if state_timer > 8.0 or _need_value("energy") >= 90.0:
		change_state(State.IDLE)


func _process_socializing(delta: float) -> void:
	_restore_need("social", delta)
	# общаемся с соседом — быстрее, если рядом есть другой NPC
	if owner_npc is BaseNPC:
		for other in GameManager.npcs:
			if other == owner_npc or not is_instance_valid(other) or not other.is_alive:
				continue
			if owner_npc.global_position.distance_to(other.global_position) < 48.0:
				_restore_need("social", delta * 0.5)
				break
	if state_timer > 4.0 or _need_value("social") >= 80.0:
		change_state(State.IDLE)


func _process_patrolling(_delta: float) -> void:
	if state_timer > 8.0:
		target_position = _get_patrol_point()
		if target_position != Vector2.ZERO:
			change_state(State.WALKING)


func _process_stealing(_delta: float) -> void:
	if state_timer > 3.0:
		change_state(State.IDLE)


func _process_investigating(_delta: float) -> void:
	pass


func _process_fleeing(_delta: float) -> void:
	pass


func _process_arresting(_delta: float) -> void:
	pass


func move_to(position: Vector2) -> void:
	target_position = position
	path = []
	path_index = 0
	_stuck_time = 0.0
	if owner_npc is BaseNPC and GameManager.world_map:
		path = GameManager.world_map.find_path_world(owner_npc.global_position, position)
		if path.size() > 1:
			path_index = 1  # нулевой узел — текущая клетка
	change_state(State.WALKING)


func move_to_node(node: Node2D) -> void:
	if node == null:
		return
	target_node = node
	move_to(node.global_position)


func stop() -> void:
	target_position = Vector2.ZERO
	target_node = null
	path = []
	path_index = 0
	if owner_npc:
		owner_npc.velocity = Vector2.ZERO
	change_state(State.IDLE)


func start_working() -> void:
	change_state(State.WORKING)


func start_eating() -> void:
	change_state(State.EATING)


func start_sleeping() -> void:
	change_state(State.SLEEPING)


func start_socializing() -> void:
	change_state(State.SOCIALIZING)


func start_patrolling() -> void:
	target_position = _get_patrol_point()
	change_state(State.PATROLLING)


func start_stealing() -> void:
	change_state(State.STEALING)


func start_investigating() -> void:
	change_state(State.INVESTIGATING)


func _on_target_reached() -> void:
	if owner_npc:
		owner_npc.velocity = Vector2.ZERO
	path = []
	path_index = 0
	change_state(State.IDLE)


func _get_wander_position() -> Vector2:
	if owner_npc == null:
		return Vector2.ZERO
	if GameManager.world_map:
		return GameManager.world_map.random_walkable_position()
	var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	return owner_npc.global_position + offset


func _get_patrol_point() -> Vector2:
	if GameManager.world_map:
		return GameManager.world_map.random_walkable_position()
	var patrol_points = [
		Vector2(400, 300),
		Vector2(600, 300),
		Vector2(500, 400),
		Vector2(300, 400),
		Vector2(700, 350),
	]
	return patrol_points[randi() % patrol_points.size()]


func get_state_name() -> String:
	return State.keys()[current_state]


func _restore_need(need_name: String, delta: float) -> void:
	if not (owner_npc is BaseNPC):
		return
	var needs: NeedSystem = owner_npc.need_system
	if needs == null:
		return
	match need_name:
		"hunger":
			needs.eat(NeedSystem.EATING_RATE * delta)
		"energy":
			needs.sleep(NeedSystem.SLEEPING_RATE * delta)
		"social":
			needs.socialize(NeedSystem.SOCIALIZING_RATE * delta)


func _need_value(need_name: String) -> float:
	if not (owner_npc is BaseNPC) or owner_npc.need_system == null:
		return 100.0
	match need_name:
		"hunger":
			return owner_npc.need_system.hunger
		"energy":
			return owner_npc.need_system.energy
		"social":
			return owner_npc.need_system.social
	return 100.0
