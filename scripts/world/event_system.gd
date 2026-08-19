## Система Динамических Событий
class_name EventSystem
extends Node

signal event_started(event_name: String, description: String)
signal event_ended(event_name: String)
signal city_status_changed(status: String)

# Типы событий
enum EventType {
	FESTIVAL,       # Праздник - все общаются
	RIOT,           # Бунт - повышенная преступность
	MEETING,        # Собрание - обсуждение мэра
	FAMINE,         # Голод - дефицит еды
	PLAGUE,         # Болезнь - NPC болеют
	TAX_DAY,        # День налогов
	ELECTION,       # Выборы (будущее)
}

# Активные события
var active_events: Array[CityEvent] = []
var next_event_id: int = 1

# Состояние города
var city_status: String = "stable"  # stable, unstable, chaotic, collapsed
var public_order: float = 100.0      # Общественный порядок 0-100

class CityEvent:
	var id: int
	var type: EventType
	var name: String
	var description: String
	var duration_days: int
	var current_day: int
	var effects: Dictionary
	var is_active: bool
	
	func _init(p_id: int, p_type: EventType, p_name: String, p_desc: String, p_duration: int):
		id = p_id
		type = p_type
		name = p_name
		description = p_desc
		duration_days = p_duration
		current_day = 0
		effects = {}
		is_active = true

func _ready():
	# Запускаем первое событие через несколько дней
	print("🎪 Система событий инициализирована")

func _process(delta: float):
	# Обновляем активные события каждый день
	pass

## Проверить и запустить события (вызывается ежедневно)
func check_for_events() -> void:
	var day = GameManager.current_day
	
	# Проверяем условия для событий
	
	# Налоговый день (каждые 5 дней)
	if day % 5 == 0:
		_start_event(EventType.TAX_DAY, 1)
	
	# Праздник (каждые 10 дней, если порядок хороший)
	if day % 10 == 0 and public_order > 50:
		_start_event(EventType.FESTIVAL, 1)
	
	# Бунт (если порядок очень низкий)
	if public_order < 20 and not _has_event_type(EventType.RIOT):
		_start_event(EventType.RIOT, 3)
	
	# Собрание (если много убийств)
	if GameManager.unsolved_murders >= 2 and not _has_event_type(EventType.MEETING):
		_start_event(EventType.MEETING, 1)

## Запустить событие
func _start_event(type: EventType, duration: int) -> CityEvent:
	var event_data = _get_event_data(type)
	var city_event = CityEvent.new(
		next_event_id,
		type,
		event_data["name"],
		event_data["description"],
		duration
	)
	
	next_event_id += 1
	active_events.append(city_event)
	
	# Применяем эффекты
	_apply_event_effects(city_event)
	
	emit_signal("event_started", city_event.name, city_event.description)
	print("🎪 [%s] %s: %s" % [event_data["icon"], city_event.name, city_event.description])
	
	return city_event

func _get_event_data(type: EventType) -> Dictionary:
	match type:
		EventType.FESTIVAL:
			return {
				"name": "Праздник",
				"description": "Город празднует! Все жители общаются и веселятся.",
				"icon": "🎉",
				"social_boost": 30.0,
				"crime_modifier": -0.5,
			}
		EventType.RIOT:
			return {
				"name": "Бунт",
				"description": "Жители недовольны! Преступность растёт.",
				"icon": "⚠️",
				"crime_modifier": 2.0,
				"order_change": -20.0,
			}
		EventType.MEETING:
			return {
				"name": "Собрание",
				"description": "Жители собираются обсудить недавние события.",
				"icon": "📢",
				"trust_change": -10.0,  # К мэру
				"social_boost": 20.0,
			}
		EventType.FAMINE:
			return {
				"name": "Голод",
				"description": "Нехватка еды! Цены растут.",
				"icon": "⚠️",
				"hunger_rate": 2.0,
				"order_change": -15.0,
			}
		EventType.PLAGUE:
			return {
				"name": "Болезнь",
				"description": "Эпидемия! Некоторые жители болеют.",
				"icon": "🤒",
				"energy_drain": 1.5,
				"order_change": -10.0,
			}
		EventType.TAX_DAY:
			return {
				"name": "День налогов",
				"description": "Мэр собирает налоги с жителей.",
				"icon": "💰",
				"wealth_transfer": true,
			}
	return {"name": "Неизвестно", "description": "", "icon": "❓"}

func _apply_event_effects(event: CityEvent) -> void:
	match event.type:
		EventType.FESTIVAL:
			_apply_festival_effects()
		EventType.RIOT:
			_apply_riot_effects()
		EventType.TAX_DAY:
			_apply_tax_effects()
		EventType.MEETING:
			_apply_meeting_effects()

func _apply_festival_effects() -> void:
	# Все NPC получают бонус к социализации
	for npc in GameManager.npcs:
		npc.need_system.social += 30

func _apply_riot_effects() -> void:
	# Повышенная вероятность кражи
	public_order -= 20.0
	_update_city_status()

func _apply_tax_effects() -> void:
	# Правитель собирает налоги: фиксированная пошлина с каждого жителя
	var tax_amount = 10.0

	for npc in GameManager.npcs:
		if not is_instance_valid(npc) or not npc.is_alive:
			continue
		if npc.role is MayorRole or npc.role is BaronRole:
			continue
		var paid = min(tax_amount, max(npc.wealth, 0.0))
		npc.wealth -= paid
		GameManager.city_treasury += paid

func _apply_meeting_effects() -> void:
	# Жители обсуждают мэра
	var mayor = _get_mayor()
	if mayor:
		for npc in GameManager.npcs:
			if npc != mayor:
				npc.relationship_graph.modify_relationship(
					npc.npc_id,
					mayor.npc_id,
					trust_delta = -5.0
				)

## Обновить события (вызывается ежедневно)
func update_events() -> void:
	var to_remove: Array[int] = []
	
	for event in active_events:
		if not event.is_active:
			continue
		
		event.current_day += 1
		
		if event.current_day >= event.duration_days:
			_end_event(event)
			to_remove.append(event.id)
	
	for id in to_remove:
		for i in range(active_events.size() - 1, -1, -1):
			if active_events[i].id == id:
				active_events.remove_at(i)

func _end_event(event: CityEvent) -> void:
	event.is_active = false
	emit_signal("event_ended", event.name)
	print("🏁 Событие '%s' завершилось" % event.name)

func _has_event_type(type: EventType) -> bool:
	for event in active_events:
		if event.type == type and event.is_active:
			return true
	return false

func _get_mayor() -> BaseNPC:
	return GameManager.get_ruler()

## Увеличить порядок
func increase_order(amount: float) -> void:
	public_order = clamp(public_order + amount, 0.0, 100.0)
	_update_city_status()

## Уменьшить порядок
func decrease_order(amount: float) -> void:
	public_order = clamp(public_order - amount, 0.0, 100.0)
	_update_city_status()

func _update_city_status() -> void:
	var new_status: String
	
	if public_order >= 70:
		new_status = "stable"
	elif public_order >= 40:
		new_status = "unstable"
	elif public_order >= 20:
		new_status = "chaotic"
	else:
		new_status = "collapsed"
	
	if new_status != city_status:
		city_status = new_status
		emit_signal("city_status_changed", city_status)
		print("🏘️ Статус города: %s (порядок: %.0f%%)" % [new_status, public_order])

## Проверить, является ли сейчас праздник
func is_festival() -> bool:
	return _has_event_type(EventType.FESTIVAL)

## Проверить, идёт ли бунт
func is_rioting() -> bool:
	return _has_event_type(EventType.RIOT)

## Получить активные события
func get_active_events() -> Array[CityEvent]:
	return active_events.filter(func(e): return e.is_active)
