## Свободная камера наблюдателя: панорамирование, зум, слежение за NPC
class_name CameraController
extends Camera2D

const MIN_ZOOM := 0.7
const MAX_ZOOM := 2.5
const ZOOM_STEP := 1.1
const PAN_SPEED := 600.0

var follow_target: Node2D = null
var dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _cam_start: Vector2 = Vector2.ZERO
var map_limits: Rect2 = Rect2(0, 0, 1920, 1408)


func _ready() -> void:
	if GameManager.world_map:
		map_limits = GameManager.world_map.get_world_rect()
	position = map_limits.get_center()
	zoom = Vector2(1.0, 1.0)


func _process(delta: float) -> void:
	if follow_target and is_instance_valid(follow_target):
		position = follow_target.global_position
		return
	_handle_pan(delta)


func _unhandled_input(event: InputEvent) -> void:
	# зум колесом
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(ZOOM_STEP)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			_drag_start = get_global_mouse_position()
			_cam_start = position


func _handle_pan(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if dir != Vector2.ZERO:
		position += dir.normalized() * PAN_SPEED / zoom.x * delta

	if dragging:
		position = _cam_start + (_drag_start - get_global_mouse_position())

	_clamp_to_limits()


func _zoom_at(factor: float) -> void:
	follow_target = null
	var new_zoom: float = clamp(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(new_zoom, new_zoom)
	_clamp_to_limits()


func follow_npc(npc: Node2D) -> void:
	follow_target = npc


func stop_follow() -> void:
	follow_target = null


func is_following() -> bool:
	return follow_target != null


func _clamp_to_limits() -> void:
	var half_view := get_viewport_rect().size / (2.0 * zoom.x)
	var min_x := map_limits.position.x + half_view.x
	var max_x := map_limits.end.x - half_view.x
	var min_y := map_limits.position.y + half_view.y
	var max_y := map_limits.end.y - half_view.y

	if max_x < min_x:
		position.x = map_limits.get_center().x
	else:
		position.x = clamp(position.x, min_x, max_x)

	if max_y < min_y:
		position.y = map_limits.get_center().y
	else:
		position.y = clamp(position.y, min_y, max_y)
