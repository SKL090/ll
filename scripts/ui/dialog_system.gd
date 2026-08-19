## Система Диалогов
class_name DialogSystem
extends CanvasLayer

signal dialog_closed()
signal choice_made(npc_id: int, choice: String)

# UI элементы
var dialog_panel: PanelContainer
var npc_name_label: Label
var dialog_text: Label
var choices_container: VBoxContainer

# Текущий диалог
var current_npc: BaseNPC = null
var is_active: bool = false

func _ready():
	_create_dialog_ui()
	visible = false

func _create_dialog_ui():
	dialog_panel = PanelContainer.new()
	dialog_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialog_panel.position = Vector2(-300, -250)
	dialog_panel.size = Vector2(600, 200)
	add_child(dialog_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	dialog_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	
	# Имя NPC
	npc_name_label = Label.new()
	npc_name_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	npc_name_label.add_theme_font_size_override("font_size", 20)
	npc_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(npc_name_label)
	
	# Текст диалога
	dialog_text = Label.new()
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(dialog_text)
	
	# Кнопки выбора
	choices_container = VBoxContainer.new()
	choices_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(choices_container)

func show_dialog(npc: BaseNPC) -> void:
	if is_active:
		return
	
	current_npc = npc
	is_active = true
	visible = true
	
	# Устанавливаем имя
	npc_name_label.text = "[b]%s[/b]" % npc.npc_name
	
	# Генерируем реплику
	_update_dialog_text()
	_generate_choices()

func _update_dialog_text() -> void:
	if not current_npc:
		return
	
	var relationships = _get_relationship_summary()
	
	var texts = [
		"%s выглядит спокойным." % current_npc.npc_name,
		"%s озирается по сторонам." % current_npc.npc_name,
		"%s приветливо кивает." % current_npc.npc_name,
	]
	
	# Можно добавить контекст на основе состояния
	if current_npc.need_system.hunger < 30:
		texts.append("%s выглядит голодным." % current_npc.npc_name)
	if current_npc.need_system.energy < 30:
		texts.append("%s зевает." % current_npc.npc_name)
	
	dialog_text.text = texts[randi() % texts.size()] + "\n\n" + relationships

func _get_relationship_summary() -> String:
	var rel = current_npc.relationship_graph.get_relationship(
		GameManager.npcs[0].npc_id if GameManager.npcs.size() > 0 else -1,
		current_npc.npc_id
	)
	
	var summary = ""
	if rel.love > 50:
		summary = "Вы относитесь к нему с симпатией."
	elif rel.hate > 50:
		summary = "Вы чувствуете неприязнь к нему."
	else:
		summary = "Вы относитесь к нему нейтрально."
	
	return summary

func _generate_choices() -> void:
	# Очищаем старые кнопки
	for child in choices_container.get_children():
		child.queue_free()
	
	# Базовые варианты
	var choices = [
		{"text": "💬 Поговорить", "action": "talk"},
		{"text": "👋 Уйти", "action": "leave"},
	]
	
	# Дополнительные варианты в зависимости от отношений
	if current_npc.relationship_graph:
		var player_rel = current_npc.relationship_graph.get_relationship(0, current_npc.npc_id)
		
		if player_rel.love < 30:
			choices.append({"text": "🖕 Оскорбить", "action": "insult"})
		
		if player_rel.trust > 20:
			choices.append({"text": "❤️ Подружиться", "action": "befriend"})
	
	# Создаём кнопки
	for choice in choices:
		var btn = Button.new()
		btn.text = choice["text"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_choice_selected.bind(choice["action"]))
		choices_container.add_child(btn)

func _on_choice_selected(action: String) -> void:
	if not current_npc:
		close_dialog()
		return
	
	match action:
		"talk":
			_talk_action()
		"insult":
			_insult_action()
		"befriend":
			_befriend_action()
		"leave":
			close_dialog()
	
	emit_signal("choice_made", current_npc.npc_id, action)

func _talk_action() -> void:
	dialog_text.text = "Приятная беседа с %s.\n\nВы обсудили погоду и последние новости." % current_npc.npc_name
	current_npc.need_system.socialize(15)
	
	# Обновить кнопки
	_generate_choices()

func _insult_action() -> void:
	# Находим "игрока" - первого жителя или случайного NPC
	var player_npc = _find_player_npc()
	if player_npc and player_npc != current_npc:
		current_npc.relationship_graph.insult(current_npc.npc_id, player_npc.npc_id)
		
		# Добавляем память
		current_npc.memory_system.add_memory(
			MemorySystem.EventType.INSULT,
			player_npc.npc_id,
			"Был оскорблён"
		)
		
		dialog_text.text = "%s выглядит обиженным и раздражённым.\n\n'Не ожидал от тебя такого!'" % current_npc.npc_name
		
		# Генерируем ненависть к игроку
		GameManager.murder_system.add_trigger_event(current_npc.npc_id, 10.0)

func _befriend_action() -> void:
	var player_npc = _find_player_npc()
	if player_npc and player_npc != current_npc:
		current_npc.relationship_graph.modify_relationship(
			current_npc.npc_id, 
			player_npc.npc_id, 
			trust_delta: 20.0, 
			love_delta: 25.0
		)
		
		dialog_text.text = "%s радуется вашей дружбе!\n\n'Спасибо, друг!'" % current_npc.npc_name

func _find_player_npc() -> BaseNPC:
	# В этой версии "игрок" - просто первый NPC или мэр
	for npc in GameManager.npcs:
		if npc.role is MayorRole:
			return npc
	return GameManager.npcs[0] if GameManager.npcs.size() > 0 else null

func close_dialog() -> void:
	is_active = false
	visible = false
	current_npc = null
	emit_signal("dialog_closed")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and is_active:
			close_dialog()
		elif event.keycode == KEY_SPACE and is_active:
			close_dialog()
