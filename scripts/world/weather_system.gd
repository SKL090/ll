## Система Погоды
class_name WeatherSystem
extends Node

signal weather_changed(weather: WeatherType)

# Типы погоды
enum WeatherType {
	CLEAR,      # Ясно
	CLOUDY,     # Облачно
	RAIN,       # Дождь
	STORM,      # Гроза
	SNOW,       # Снег (если есть зима)
	FOG,        # Туман
}

# Текущая погода
var current_weather: WeatherType = WeatherType.CLEAR
var weather_duration: float = 0.0
var weather_timer: float = 0.0

# Настройки
const MIN_WEATHER_DURATION: float = 30.0   # Минимум 30 секунд
const MAX_WEATHER_DURATION: float = 120.0  # Максимум 2 минуты

# Визуальные эффекты
var weather_particles: CPUParticles2D = null

func _ready():
	print("🌦️ Система погоды инициализирована")
	_change_weather(WeatherType.CLEAR)

func _process(delta: float):
	weather_timer += delta
	
	if weather_timer >= weather_duration:
		_change_to_random_weather()

## Сменить погоду
func _change_weather(new_weather: WeatherType) -> void:
	current_weather = new_weather
	weather_timer = 0.0
	weather_duration = randf_range(MIN_WEATHER_DURATION, MAX_WEATHER_DURATION)
	
	_apply_weather_effects(new_weather)
	emit_signal("weather_changed", new_weather)
	
	print("🌤️ Погода изменилась: %s" % _get_weather_name(new_weather))

## Применить эффекты погоды
func _apply_weather_effects(weather: WeatherType) -> void:
	match weather:
		WeatherType.CLEAR:
			_apply_clear_effects()
		WeatherType.CLOUDY:
			_apply_cloudy_effects()
		WeatherType.RAIN:
			_apply_rain_effects()
		WeatherType.STORM:
			_apply_storm_effects()
		WeatherType.FOG:
			_apply_fog_effects()

func _apply_clear_effects() -> void:
	# Ясная погода - всё хорошо
	EventSystem.increase_order(5.0) if EventSystem else None
	for npc in GameManager.npcs:
		npc.need_system.social += 5

func _apply_cloudy_effects() -> void:
	# Облачно - лёгкий дискомфорт
	for npc in GameManager.npcs:
		npc.need_system.energy -= 5

func _apply_rain_effects() -> void:
	# Дождь - все в помещениях
	EventSystem.decrease_order(5.0) if EventSystem else None
	for npc in GameManager.npcs:
		npc.need_system.social -= 10
		# Кражи реже (все дома)
		pass

func _apply_storm_effects() -> void:
	# Гроза - страх
	EventSystem.decrease_order(15.0) if EventSystem else None
	for npc in GameManager.npcs:
		npc.need_system.safety -= 30
		npc.need_system.social -= 20

func _apply_fog_effects() -> void:
	# Туман - идеально для преступлений
	for npc in GameManager.npcs:
		if npc.role is SheriffRole:
			npc.need_system.energy -= 10  # Сложнее патрулировать
		# Преступники счастливы

## Случайная погода
func _change_to_random_weather() -> void:
	# Веса для разной погоды
	var weights = {
		WeatherType.CLEAR: 40,
		WeatherType.CLOUDY: 25,
		WeatherType.RAIN: 20,
		WeatherType.STORM: 5,
		WeatherType.FOG: 10,
	}
	
	var total_weight = 0
	for w in weights.values():
		total_weight += w
	
	var roll = randf() * total_weight
	var cumulative = 0
	var chosen_weather = WeatherType.CLEAR
	
	for weather in weights.keys():
		cumulative += weights[weather]
		if roll <= cumulative:
			chosen_weather = weather
			break
	
	_change_weather(chosen_weather)

## Получить название погоды
func _get_weather_name(weather: WeatherType) -> String:
	match weather:
		WeatherType.CLEAR: return "☀️ Ясно"
		WeatherType.CLOUDY: return "☁️ Облачно"
		WeatherType.RAIN: return "🌧️ Дождь"
		WeatherType.STORM: return "⛈️ Гроза"
		WeatherType.SNOW: return "❄️ Снег"
		WeatherType.FOG: return "🌫️ Туман"
	return "Неизвестно"

## Получить текущую погоду
func get_current_weather() -> WeatherType:
	return current_weather

## Получить строковое представление
func get_weather_string() -> String:
	return _get_weather_name(current_weather)

## Проверить, опасна ли погода для выхода
func is_dangerous_weather() -> bool:
	return current_weather == WeatherType.STORM
