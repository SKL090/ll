## Система времени и дня/ночи
class_name TimeSystem
extends Node

signal time_changed(game_time: float)
signal phase_changed(phase: TimePhase)

# Константы времени (в игровых часах)
const HOUR: float = 1.0
const DAY_HOURS: float = 24.0

# Фазы дня
enum TimePhase {
	EARLY_MORNING,  # 6:00 - 8:00
	DAY,            # 8:00 - 18:00
	EVENING,        # 18:00 - 20:00
	LATE_NIGHT,     # 20:00 - 23:00
	NIGHT,          # 23:00 - 6:00
}

# Настройки цикла
@export var game_time_scale: float = 1.0  # Скорость времени (1.0 = реальная)
@export var minutes_per_ingame_day: float = 5.0  # Минут реального времени на игровой день

# Текущее состояние
var current_time: float = 6.0  # Начинаем с 6:00 утра
var current_day: int = 1
var is_night: bool = false

# Предыдущая фаза (для отслеживания смены)
var _previous_phase: TimePhase

func _ready() -> void:
	_previous_phase = get_current_phase()
	print("🌅 Время инициализировано: ", get_time_string())

func _process(delta: float) -> void:
	# Увеличиваем время: 24 часа игрового времени проходят за minutes_per_ingame_day минут
	var hours_per_second = DAY_HOURS / (minutes_per_ingame_day * 60.0)
	current_time += hours_per_second * delta * game_time_scale
	
	# Переход через полночь
	if current_time >= DAY_HOURS:
		current_time -= DAY_HOURS
		current_day += 1
		GameManager.current_day = current_day
		emit_signal("time_changed", current_time)
	
	# Проверяем смену фазы
	var phase = get_current_phase()
	if phase != _previous_phase:
		_previous_phase = phase
		emit_signal("phase_changed", phase)
		_on_phase_change(phase)
	
	emit_signal("time_changed", current_time)

## Получить текущую фазу дня
func get_current_phase() -> TimePhase:
	if current_time >= 6.0 and current_time < 8.0:
		return TimePhase.EARLY_MORNING
	elif current_time >= 8.0 and current_time < 18.0:
		return TimePhase.DAY
	elif current_time >= 18.0 and current_time < 20.0:
		return TimePhase.EVENING
	elif current_time >= 20.0 and current_time < 23.0:
		return TimePhase.LATE_NIGHT
	else:
		return TimePhase.NIGHT

## Проверка ночи
func is_nighttime() -> bool:
	return current_time >= 20.0 or current_time < 6.0

## Получить время в строковом формате
func get_time_string() -> String:
	var hours = int(current_time)
	var minutes = int((current_time - hours) * 60)
	return "%02d:%02d" % [hours, minutes]

## Получить описание времени суток
func get_phase_description() -> String:
	match get_current_phase():
		TimePhase.EARLY_MORNING:
			return "Раннее утро"
		TimePhase.DAY:
			return "День"
		TimePhase.EVENING:
			return "Вечер"
		TimePhase.LATE_NIGHT:
			return "Поздний вечер"
		TimePhase.NIGHT:
			return "Ночь"
	return "Неизвестно"

## Обработка смены фазы
func _on_phase_change(phase: TimePhase) -> void:
	match phase:
		TimePhase.DAY:
			print("☀️ День наступил")
			emit_signal("phase_changed", phase)
			# Обновляем системы каждый новый день
			_update_daily_systems()
		TimePhase.NIGHT:
			print("🌙 Ночь наступила")
			is_night = true
			emit_signal("phase_changed", phase)
		TimePhase.EARLY_MORNING:
			print("🌅 Рассвет")
			is_night = false
			emit_signal("phase_changed", phase)

## Ежедневное обновление систем
func _update_daily_systems() -> void:
	# Обновляем планы убийств
	if GameManager.murder_system:
		GameManager.murder_system.update_all_plans()
	
	# Обновляем расследования
	if GameManager.investigation_system:
		GameManager.investigation_system.update_investigations()
	
	# Обновляем события города
	if GameManager.event_system:
		GameManager.event_system.check_for_events()
		GameManager.event_system.update_events()
	
	# NPC просыпаются с новыми потребностями
	for npc in GameManager.npcs:
		if npc.need_system:
			npc.need_system.daily_reset()
	
	# Авансируем игровой день
	GameManager.advance_day()
	
	print("📅 Новый день - все системы обновлены")

## Получить прогресс дня (0.0 - 1.0)
func get_day_progress() -> float:
	return current_time / DAY_HOURS

## Установить время (для отладки)
func set_time(hours: float) -> void:
	current_time = clamp(hours, 0.0, DAY_HOURS)
