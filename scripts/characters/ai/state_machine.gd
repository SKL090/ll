## Машина состояний для NPC
class_name NPCStateMachine
extends Node

signal state_changed(from_state: String, to_state: String)

# Состояния
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

# Текущее состояние
var current_state: State = State.IDLE
var previous_state: State = State.IDLE

# Владелец
var owner: Node2D

# Таймеры состояний
var state_timer: float = 0.0
var min_state_duration: float = 1.0

# Цель движения
var target_position: Vector2 = Vector2.ZERO
var target_node: Node2D = null

func _init(p_owner: Node2D):
	owner = p_owner

func _physics_process(delta: float) -> void:
	state_timer += delta
	_process_state(delta)

## Обработка текущего состояния
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

## Сменить состояние
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

## Обработка входа в состояние
func _on_state_enter(state: State) -> void:
	match state:
		State.WALKING:
			# Можно добавить звук шагов и т.д.
			pass
		State.SLEEPING:
			# Анимация сна
			pass
		State.WORKING:
			# Начать работу
			pass

# ==================== ОБРАБОТЧИКИ СОСТОЯНИЙ ====================

func _process_idle(delta: float) -> void:
	# Случайное блуждание если долго стоим
	if state_timer > 3.0:
		var wander_pos = _get_wander_position()
		if wander_pos != Vector2.ZERO:
			move_to(wander_pos)

func _process_walking(delta: float) -> void:
	if target_position == Vector2.ZERO:
		change_state(State.IDLE)
		return
	
	var direction = (target_position - owner.global_position)
	var distance = direction.length()
	
	if distance < 5.0:
		# Достигли цели
		_on_target_reached()
		return
	
	# Двигаемся к цели
	direction = direction.normalized()
	owner.velocity = direction * owner.move_speed
	owner.move_and_slide()
	
	# Смотрим в направлении движения
	if direction != Vector2.ZERO:
		owner.look_at(owner.global_position + direction)

func _process_working(delta: float) -> void:
	# Симуляция работы
	pass

func _process_eating(delta: float) -> void:
	if state_timer > 5.0:  # 5 секунд на еду
		change_state(State.IDLE)

func _process_sleeping(delta: float) -> void:
	if state_timer > 8.0:  # 8 секунд на сон
		change_state(State.IDLE)

func _process_socializing(delta: float) -> void:
	if state_timer > 4.0:
		change_state(State.IDLE)

func _process_patrolling(delta: float) -> void:
	# Патрулирование (для шерифа)
	if state_timer > 10.0:
		target_position = _get_patrol_point()
		if target_position != Vector2.ZERO:
			change_state(State.WALKING)

func _process_stealing(delta: float) -> void:
	# Воровство (для жителей-воров)
	if state_timer > 3.0:
		change_state(State.IDLE)

func _process_investigating(delta: float) -> void:
	# Расследование (для шерифа)
	pass

func _process_fleeing(delta: float) -> void:
	# Бегство от опасности
	pass

func _process_arresting(delta: float) -> void:
	# Арест
	pass

# ==================== ДЕЙСТВИЯ ====================

## Двигаться к позиции
func move_to(position: Vector2) -> void:
	target_position = position
	change_state(State.WALKING)

## Двигаться к ноде
func move_to_node(node: Node2D) -> void:
	target_node = node
	target_position = node.global_position
	change_state(State.WALKING)

## Остановиться
func stop() -> void:
	target_position = Vector2.ZERO
	target_node = null
	owner.velocity = Vector2.ZERO
	change_state(State.IDLE)

## Начать работать
func start_working() -> void:
	change_state(State.WORKING)

## Есть
func start_eating() -> void:
	change_state(State.EATING)

## Спать
func start_sleeping() -> void:
	change_state(State.SLEEPING)

## Общаться
func start_socializing() -> void:
	change_state(State.SOCIALIZING)

## Патрулировать
func start_patrolling() -> void:
	target_position = _get_patrol_point()
	change_state(State.PATROLLING)

# ==================== УТИЛИТЫ ====================

func _on_target_reached() -> void:
	stop()

func _get_wander_position() -> Vector2:
	# Случайная позиция рядом с текущей
	var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	return owner.global_position + offset

func _get_patrol_point() -> Vector2:
	# Точка патруля для шерифа
	var patrol_points = [
		Vector2(400, 300),
		Vector2(600, 300),
		Vector2(500, 400),
		Vector2(300, 400),
		Vector2(700, 350),
	]
	return patrol_points[randi() % patrol_points.size()]

## Получить текущее состояние в виде строки
func get_state_name() -> String:
	return State.keys()[current_state]
