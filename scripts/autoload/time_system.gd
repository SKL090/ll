## Система времени и дня/ночи
class_name TimeSystem
extends Node

signal time_changed(game_time: float)
signal phase_changed(phase: TimePhase)

const HOUR: float = 1.0
const DAY_HOURS: float = 24.0

enum TimePhase {
	EARLY_MORNING,  # 6:00 - 8:00
	DAY,            # 8:00 - 18:00
	EVENING,        # 18:00 - 20:00
	LATE_NIGHT,     # 20:00 - 23:00
	NIGHT,          # 23:00 - 6:00
}

@export var game_time_scale: float = 1.0
@export var minutes_per_ingame_day: float = 5.0

var current_time: float = 6.0
var current_day: int = 1
var is_night: bool = false

var _previous_phase: TimePhase
var _daily_systems_ran_for_day: int = 0


func _ready() -> void:
	_previous_phase = get_current_phase()
	print("🌅 Время инициализировано: ", get_time_string())


func _process(delta: float) -> void:
	if GameManager.is_paused:
		return

	var hours_per_second = DAY_HOURS / (minutes_per_ingame_day * 60.0)
	current_time += hours_per_second * delta * game_time_scale * GameManager.game_speed

	if current_time >= DAY_HOURS:
		current_time -= DAY_HOURS
		current_day += 1
		GameManager.current_day = current_day

	var phase = get_current_phase()
	if phase != _previous_phase:
		_previous_phase = phase
		emit_signal("phase_changed", phase)
		_on_phase_change(phase)

	emit_signal("time_changed", current_time)


func get_current_phase() -> TimePhase:
	if current_time >= 6.0 and current_time < 8.0:
		return TimePhase.EARLY_MORNING
	if current_time >= 8.0 and current_time < 18.0:
		return TimePhase.DAY
	if current_time >= 18.0 and current_time < 20.0:
		return TimePhase.EVENING
	if current_time >= 20.0 and current_time < 23.0:
		return TimePhase.LATE_NIGHT
	return TimePhase.NIGHT


func is_nighttime() -> bool:
	return current_time >= 20.0 or current_time < 6.0


func get_time_string() -> String:
	var hours = int(current_time)
	var minutes = int((current_time - hours) * 60)
	return "%02d:%02d" % [hours, minutes]


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


func _on_phase_change(phase: TimePhase) -> void:
	match phase:
		TimePhase.DAY:
			print("☀️ День наступил")
			is_night = false
			_update_daily_systems()
		TimePhase.NIGHT:
			print("🌙 Ночь наступила")
			is_night = true
		TimePhase.EARLY_MORNING:
			print("🌅 Рассвет")
			is_night = false


func _update_daily_systems() -> void:
	if _daily_systems_ran_for_day == current_day:
		return
	_daily_systems_ran_for_day = current_day
	GameManager.advance_day()
	print("📅 Новый день - все системы обновлены")


func get_day_progress() -> float:
	return current_time / DAY_HOURS


func set_time(hours: float) -> void:
	current_time = clamp(hours, 0.0, DAY_HOURS)
