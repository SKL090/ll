## HUD - интерфейс игрока
class_name HUD
extends CanvasLayer

@onready var info_panel: PanelContainer = $InfoPanel
@onready var vbox: VBoxContainer = $InfoPanel/VBox

# Дополнительные элементы
var relationship_map: RelationshipMap
var dialog_system: DialogSystem

# Выбранный NPC
var selected_npc: BaseNPC = null

# Журнал событий
var event_log_panel: PanelContainer
var event_log: VBoxContainer
const MAX_EVENTS = 7

func _ready():
	info_panel.visible = false
	_setup_relationship_map()
	_setup_event_log()
	_setup_dialog_system()
	_connect_signals()

func _setup_relationship_map():
	relationship_map = RelationshipMap.new()
	add_child(relationship_map)

func _setup_event_log():
	event_log_panel = PanelContainer.new()
	event_log_panel.position = Vector2(900, 60)
	event_log_panel.size = Vector2(320, 280)
	add_child(event_log_panel)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_log_panel.add_child(scroll)
	
	event_log = VBoxContainer.new()
	event_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(event_log)
	
	var title = Label.new()
	title.text = "📜 События"
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	event_log.add_child(title)

func _setup_dialog_system():
	dialog_system = DialogSystem.new()
	add_child(dialog_system)

func _connect_signals():
	GameManager.connect("crime_committed", _on_crime_committed)
	GameManager.connect("npc_died", _on_npc_died)
	TimeSystem.connect("phase_changed", _on_phase_changed)
	
	if GameManager.murder_system:
		GameManager.murder_system.connect("murder_committed", _on_murder_committed)
		GameManager.murder_system.connect("murder_planned", _on_murder_planned)
	
	if GameManager.investigation_system:
		GameManager.investigation_system.connect("investigation_started", _on_investigation_started)
		GameManager.investigation_system.connect("investigation_solved", _on_investigation_solved)
	
	if GameManager.event_system:
		GameManager.event_system.connect("event_started", _on_event_started)
		GameManager.event_system.connect("city_status_changed", _on_city_status_changed)
	
	if GameManager.crime_system:
		GameManager.crime_system.connect("crime_committed", _on_special_crime)
		GameManager.crime_system.connect("building_burned", _on_building_burned)
	
	if GameManager.weather_system:
		GameManager.weather_system.connect("weather_changed", _on_weather_changed)

	if GameManager.gurps_system:
		GameManager.gurps_system.connect("critical_success", _on_gurps_crit)
		GameManager.gurps_system.connect("critical_failure", _on_gurps_fumble)

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F5: _save_game()
			KEY_F6: _load_game()
			KEY_M: _toggle_relationship_map()
			KEY_R: _restart_game()
			KEY_ESCAPE:
				if dialog_system and dialog_system.is_active:
					dialog_system.close_dialog()
				else:
					GameManager.toggle_pause()
	
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT: _handle_left_click(event.position)
			MOUSE_BUTTON_RIGHT: _handle_right_click()

func _handle_left_click(pos: Vector2):
	var city = get_parent() as City
	if not city:
		return
	
	if pos.y > 550:
		return
	
	var npc = city.get_npc_at_position(pos)
	
	if npc:
		show_npc_dialog(npc)
	else:
		deselect_npc()

func _handle_right_click():
	GameManager.toggle_pause()

func show_npc_dialog(npc: BaseNPC):
	selected_npc = npc
	dialog_system.show_dialog(npc)
	update_info_panel()

func deselect_npc():
	selected_npc = null
	info_panel.visible = false

func update_info_panel():
	if not selected_npc or not is_instance_valid(selected_npc):
		info_panel.visible = false
		return

	info_panel.visible = true
	var info = selected_npc.get_info()
	
	var text = ""
	text += "%s (%s)\n" % [info["name"], _get_role_name(info["role"])]
	text += "Состояние: %s | Эмоция: %s\n" % [info["state"], info["emotion"]]
	text += "💰 Богатство: %.0f\n" % [info["wealth"]]
	text += "❤️ Друзья: %d | 💔 Враги: %d\n" % [info["friends"], info["enemies"]]
	if info.has("gurps_text") and str(info["gurps_text"]) != "":
		text += "\n" + str(info["gurps_text"]) + "\n"

	if GameManager.investigation_system:
		var inv = GameManager.investigation_system.get_investigation_about(selected_npc.npc_id)
		if inv:
			text += "\n⚠️ РАССЛЕДОВАНИЕ\n"
			text += "Улики: %.0f%%\n" % inv.evidence

	if GameManager.murder_system:
		var plan = GameManager.murder_system.get_plan_against(selected_npc.npc_id)
		if plan:
			text += "\n🗡️ В ОПАСНОСТИ!\n"
			text += "Ненависть: %.0f%%\n" % plan.hatred
			text += "Готовность убийцы: %.0f%%" % plan.readiness

	if GameManager.crime_system and GameManager.crime_system.is_kidnapped(selected_npc.npc_id):
		text += "\n👤 ПОХИЩЕН!\n"

	if GameManager.prison_system and GameManager.prison_system.is_in_prison(selected_npc.npc_id):
		var prison_info = GameManager.prison_system.get_prisoner_info(selected_npc.npc_id)
		text += "\n⛓️ В ТЮРЬМЕ!\n"
		text += "Осталось дней: %d\n" % prison_info.get("days_remaining", 0)

	if GameManager.anarchy_system and GameManager.anarchy_system.is_active():
		text += "\n⚔️ АНАРХИЯ!\n"
		text += "Дней без лидера: %d" % GameManager.anarchy_system.get_days_in_anarchy()

	text += "\nПотребности:\n"
	text += "🍔 Голод: %.0f%%\n" % info["needs"]["hunger"]
	text += "😴 Энергия: %.0f%%\n" % info["needs"]["energy"]
	text += "💬 Социальность: %.0f%%" % info["needs"]["social"]
	
	vbox.get_node("Title").text = info["name"]
	
	for i in range(1, vbox.get_child_count()):
		vbox.get_child(i).queue_free()
	
	var desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.text = text
	vbox.add_child(desc_label)

func _get_role_name(role: String) -> String:
	match role:
		"mayor": return "🏛️ Мэр"
		"sheriff": return "⭐ Шериф"
		"baron": return "👑 Барон"
		"bishop": return "⛪ Епископ"
		"inquisition": return "🔥 Инквизитор"
		"treasurer": return "💰 Казначей"
		"garrison": return "⚔️ Солдат"
		"cultist": return "🔮 Культист"
		"resident": return "👤 Житель"
		"merchant": return "🛒 Торговец"
		"priest": return "⛪ Священник"
	return role

func _add_event(text: String, color: Color = Color.WHITE):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	event_log.add_child(label)
	
	while event_log.get_child_count() > MAX_EVENTS + 1:
		event_log.get_child(1).queue_free()

func _add_notification(text: String, color: Color = Color.WHITE, duration: float = 2.0):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(640 - label.size.x / 2, 120)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 28)
	label.z_index = 100
	add_child(label)
	
	var tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(label.queue_free)

func _toggle_relationship_map():
	relationship_map.toggle()
	if relationship_map.map_open:
		_add_notification("🕸️ Карта отношений", Color.CYAN, 1.5)

func _save_game():
	if GameManager.save_game():
		_add_notification("💾 Сохранено!", Color.GREEN, 2.0)
	else:
		_add_notification("❌ Ошибка!", Color.RED, 2.0)

func _load_game():
	if GameManager.save_system.has_save():
		if GameManager.load_game():
			_add_notification("📂 Загружено!", Color.GREEN, 2.0)
		else:
			_add_notification("❌ Ошибка!", Color.RED, 2.0)
	else:
		_add_notification("📂 Нет сохранения!", Color.ORANGE, 2.0)

func _restart_game():
	var city = get_parent() as City
	if city:
		city.restart_game()
	else:
		GameManager.new_game()
	_add_notification("🔄 Новая игра!", Color.YELLOW, 2.0)

func update_stats():
	var stats = GameManager.get_city_stats()
	
	var order = 100.0
	var status_color = Color(0.3, 0.9, 0.3)
	
	if GameManager.event_system:
		order = GameManager.event_system.public_order
	
	if order < 70: status_color = Color(0.9, 0.9, 0.3)
	if order < 40: status_color = Color(0.9, 0.5, 0.2)
	if order < 20: status_color = Color(0.9, 0.2, 0.2)
	
	var order_label_node = get_parent().get_node_or_null("OrderLabel")
	if order_label_node:
		order_label_node.text = "📊 Порядок: %.0f%%" % order
		order_label_node.add_theme_color_override("font_color", status_color)
	
	var stats_label_node = get_parent().get_node_or_null("StatsLabel")
	if stats_label_node:
		stats_label_node.text = "👥 %d | 🚨 %.0f%%" % [stats["alive"], stats["crime_rate"]]
	
	# Обновляем погоду
	var weather_label = get_parent().get_node_or_null("WeatherLabel")
	if weather_label and GameManager.weather_system:
		weather_label.text = GameManager.weather_system.get_weather_string()

func _on_phase_changed(phase: TimeSystem.TimePhase):
	match phase:
		TimeSystem.TimePhase.NIGHT:
			_add_notification("🌙 Ночь...", Color.CYAN, 2.0)
			_add_event("🌙 Ночь наступила", Color.CYAN)
		TimeSystem.TimePhase.DAY:
			_add_notification("☀️ День %d" % GameManager.current_day, Color.YELLOW, 2.0)
			_add_event("☀️ День %d" % GameManager.current_day, Color.YELLOW)
			update_stats()

func _on_crime_committed(crime_type: String, criminal: BaseNPC, victim: BaseNPC):
	match crime_type:
		"theft":
			_add_event("🚨 %s украл у %s" % [criminal.npc_name, victim.npc_name], Color.ORANGE)
		"murder":
			_add_event("🩸 УБИЙСТВО: %s → %s" % [criminal.npc_name, victim.npc_name], Color.RED)

func _on_npc_died(npc: BaseNPC, killer: BaseNPC):
	_add_notification("💀 %s погиб!" % npc.npc_name, Color.RED, 3.0)
	_add_event("💀 %s погиб" % npc.npc_name, Color.RED)

func _on_murder_committed(planner: BaseNPC, target: BaseNPC):
	_add_notification("🗡️💀 УБИЙСТВО!", Color.RED, 3.0)
	_add_event("🗡️💀 %s убил %s" % [planner.npc_name, target.npc_name], Color.RED)

func _on_murder_planned(planner: BaseNPC, target: BaseNPC):
	_add_event("⚠️ %s планирует убийство %s" % [planner.npc_name, target.npc_name], Color.ORANGE)

func _on_investigation_started(investigation: InvestigationSystem.Investigation):
	_add_notification("🔍 Расследование!", Color.CYAN, 2.0)
	_add_event("🔍 Расследование: %s" % investigation.victim_name, Color.CYAN)

func _on_investigation_solved(investigation: InvestigationSystem.Investigation, culprit_id: int):
	var culprit = GameManager.get_npc_by_id(culprit_id)
	if culprit:
		_add_notification("⚖️ ДЕЛО РАСКРЫТО!", Color.GREEN, 3.0)
		_add_event("⚖️ %s виновен!" % culprit.npc_name, Color.GREEN)

func _on_event_started(event_name: String, description: String):
	_add_notification(event_name, Color.YELLOW, 3.0)
	_add_event("🎪 %s" % event_name, Color.YELLOW)

func _on_city_status_changed(status: String):
	match status:
		"stable": _add_event("🏘️ Стабильность", Color.GREEN)
		"unstable":
			_add_notification("⚠️ Нестабильность!", Color.ORANGE, 3.0)
			_add_event("⚠️ Нестабильность", Color.ORANGE)
		"chaotic":
			_add_notification("🔥 ХАОС!", Color.RED, 3.0)
			_add_event("🔥 Хаос!", Color.RED)
		"collapsed":
			_add_notification("💀 КОЛЛАПС!", Color.DARK_RED, 4.0)
			_add_event("💀 Коллапс!", Color.RED)

func _on_special_crime(crime_type: String, criminal: BaseNPC, target):
	match crime_type:
		"arson":
			_add_event("🔥 %s поджёг здание!" % criminal.npc_name, Color.ORANGE)
		"kidnapping":
			var target_name = criminal.npc_name if not target else target.npc_name
			_add_event("👤 %s похищен!" % target_name, Color.ORANGE)

func _on_building_burned(building_name: String):
	_add_notification("🔥 ПОЖАР!", Color.RED, 4.0)
	_add_event("🔥 Здание '%s' горит!" % building_name, Color.RED)

func _on_weather_changed(weather: WeatherSystem.WeatherType):
	var weather_label = get_parent().get_node_or_null("WeatherLabel")
	if weather_label and GameManager.weather_system:
		weather_label.text = GameManager.weather_system.get_weather_string()
	_add_event("🌤️ Погода: %s" % GameManager.weather_system.get_weather_string(), Color.CYAN)

func _on_gurps_crit(roll: int, target: int):
	_add_event("🎯 Критический успех: %d vs %d" % [roll, target], Color.YELLOW)


func _on_gurps_fumble(roll: int, target: int):
	_add_event("💥 Критический провал: %d vs %d" % [roll, target], Color.RED)


func _process(delta: float):
	if randf() < 0.1:
		update_stats()
