## Серый кардинал — игрок-кукловод
## Панель «ниточек»: косвенное влияние (шёпот) и прямые приказы NPC.
class_name GrayCardinal
extends CanvasLayer

var panel: PanelContainer
var info_label: Label
var buttons_vbox: VBoxContainer
var hint_label: Label

var selected_npc: BaseNPC = null
var pending: String = ""   # пустая строка — нет ожидания выбора цели


func _ready() -> void:
	_build_ui()
	visible = false


func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-340, -330)
	panel.size = Vector2(680, 320)
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.09, 0.96)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.4, 0.2)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	vbox.add_child(info_label)

	buttons_vbox = VBoxContainer.new()
	vbox.add_child(buttons_vbox)

	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(hint_label)


# ============================================================ ПОКАЗ / СКРЫТИЕ

func show_for(npc: BaseNPC) -> void:
	selected_npc = npc
	pending = ""
	visible = true
	_refresh()


func hide_panel() -> void:
	selected_npc = null
	pending = ""
	visible = false


func is_pending() -> bool:
	return pending != ""


# ============================================================ ОБРАБОТКА КЛИКОВ

## Возвращает true, если клик «съеден» панелью (ожидание выбора цели/места)
func handle_click(world_pos: Vector2) -> bool:
	if not visible or selected_npc == null or pending == "":
		return false
	if not is_instance_valid(selected_npc):
		hide_panel()
		return false

	var city := _get_city()
	var target_npc: BaseNPC = city.get_npc_at_position(world_pos) if city else null

	var ok := true
	match pending:
		"order_go":
			selected_npc.give_order("go", null, world_pos)
			_flash("🎭 %s идёт по приказу" % selected_npc.npc_name)
		"order_follow":
			ok = _require_target(target_npc)
			if ok:
				selected_npc.give_order("follow", target_npc)
		"order_attack":
			ok = _require_target(target_npc)
			if ok:
				selected_npc.give_order("attack", target_npc)
		"whisper_discord":
			ok = _require_target(target_npc)
			if ok:
				_do_whisper_discord(target_npc)
		"whisper_reconcile":
			ok = _require_target(target_npc)
			if ok:
				_do_whisper_reconcile(target_npc)
		"whisper_bribe":
			ok = _require_target(target_npc)
			if ok:
				_do_whisper_bribe(target_npc)
		"whisper_intimidate":
			ok = _require_target(target_npc)
			if ok:
				_do_whisper_intimidate(target_npc)
		"whisper_frame":
			ok = _require_target(target_npc)
			if ok:
				_do_whisper_frame(target_npc)

	if ok:
		pending = ""
		_refresh()
	return true


func _require_target(target_npc: BaseNPC) -> bool:
	if target_npc == null:
		_flash("Нужно кликнуть по NPC")
		return false
	if target_npc == selected_npc:
		_flash("Нельзя выбрать самого себя")
		return false
	return true


# ============================================================ ДЕЙСТВИЯ

func _start_pending(kind: String, prompt: String) -> void:
	pending = kind
	hint_label.text = prompt


func _flash(msg: String) -> void:
	hint_label.text = msg


func _spend(cost: float) -> bool:
	if GameManager.influence < cost:
		_flash("Недостаточно влияния (%.0f/%.0f)" % [GameManager.influence, cost])
		return false
	GameManager.influence -= cost
	return true


# --- Шёпот (косвенное влияние) ---

func _do_whisper_discord(b: BaseNPC) -> void:
	if not _spend(10.0):
		return
	var a := selected_npc
	a.relationship_graph.modify_relationship(a.npc_id, b.npc_id, -15.0, 0.0, 25.0)
	b.relationship_graph.modify_relationship(b.npc_id, a.npc_id, -20.0, 0.0, 20.0)
	b.memory_system.add_memory(MemorySystem.EventType.SUSPICIOUS, a.npc_id, "Почуял подвох от " + a.npc_name)
	_flash("🎭 %s теперь ненавидит %s" % [a.npc_name, b.npc_name])


func _do_whisper_reconcile(b: BaseNPC) -> void:
	if not _spend(15.0):
		return
	var a := selected_npc
	a.relationship_graph.modify_relationship(a.npc_id, b.npc_id, 20.0, 10.0, -15.0)
	b.relationship_graph.modify_relationship(b.npc_id, a.npc_id, 10.0, 5.0, -5.0)
	_flash("🕊️ %s и %s помирились" % [a.npc_name, b.npc_name])


func _do_whisper_bribe(b: BaseNPC) -> void:
	if not _spend(20.0):
		return
	var a := selected_npc
	if a.wealth < 10.0:
		_flash("У %s нет денег на взятку" % a.npc_name)
		return
	a.wealth -= 10.0
	b.wealth += 10.0
	b.relationship_graph.modify_relationship(b.npc_id, a.npc_id, 25.0, 5.0, -5.0)
	_flash("💰 %s подкупил %s" % [a.npc_name, b.npc_name])


func _do_whisper_intimidate(b: BaseNPC) -> void:
	if not _spend(15.0):
		return
	var a := selected_npc
	var gs: GURPSSystem = GameManager.gurps_system
	var resist: Dictionary = {}
	if gs:
		resist = gs.will_check(b, 0, "Запугивание: " + b.npc_name)
	if resist.get("success", false):
		b.relationship_graph.modify_relationship(b.npc_id, a.npc_id, -10.0, 0.0, 15.0)
		_flash("💪 %s дал отпор %s" % [b.npc_name, a.npc_name])
	else:
		b.relationship_graph.modify_relationship(b.npc_id, a.npc_id, -20.0, 0.0, 10.0)
		b.memory_system.add_memory(MemorySystem.EventType.SUSPICIOUS, a.npc_id, "Испуган: " + a.npc_name)
		_flash("😨 %s напугал %s" % [a.npc_name, b.npc_name])


func _do_whisper_frame(b: BaseNPC) -> void:
	if not _spend(25.0):
		return
	var a := selected_npc
	if GameManager.denunciation_system:
		GameManager.denunciation_system.file_denouncement(a.npc_id, b.npc_id, "подозрительное поведение")
		_flash("🕵️ %s подставил %s (донос инквизиции)" % [a.npc_name, b.npc_name])
	else:
		_flash("Нет системы доносов")


# --- Прямые приказы ---

func _order_trade() -> void:
	selected_npc.give_order("trade")
	_flash("🛒 %s отправлен торговать" % selected_npc.npc_name)


func _order_wait() -> void:
	selected_npc.give_order("wait")
	_flash("⏸️ %s замер" % selected_npc.npc_name)


func _order_stop() -> void:
	selected_npc.clear_order()
	_flash("🆓 %s свободен" % selected_npc.npc_name)


# ============================================================ UI

func _refresh() -> void:
	if selected_npc == null or not is_instance_valid(selected_npc):
		hide_panel()
		return

	var info := selected_npc.get_info()
	info_label.text = "🎭 %s — %s\nСостояние: %s | 💰 %.0f | 🍞 %.1f | 👁 %d\nВлияние кардинала: %.0f" % [
		info["name"], _role_name(info["role"]),
		info["state"], info["wealth"], info["food"], info["visible"],
		GameManager.influence,
	]

	for child in buttons_vbox.get_children():
		child.queue_free()

	_add_section("🧵 Ниточки (шёпот)")
	_add_button("😠 Поссорить (10)", "whisper_discord", "Кликни по NPC, кого настроить против выбранного")
	_add_button("🕊️ Помирить (15)", "whisper_reconcile", "Кликни по NPC, с кем помирить")
	_add_button("💰 Подкупить (20)", "whisper_bribe", "Кликни по NPC, кого подкупить")
	_add_button("😨 Запугать (15)", "whisper_intimidate", "Кликни по NPC, кого запугать")
	_add_button("🕵️ Подставить (25)", "whisper_frame", "Кликни по NPC, кого подставить")

	_add_section("🎬 Приказы")
	_add_button("🚶 Идти (клик по месту)", "order_go", "Кликни по точке на карте")
	_add_button("👣 Следовать (клик по NPC)", "order_follow", "Кликни по NPC, за кем следовать")
	_add_button("⚔️ Атаковать (клик по NPC)", "order_attack", "Кликни по NPC-цели")
	_add_button("🛒 Торговать", "order_trade", "")
	_add_button("⏸️ Ждать", "order_wait", "")
	_add_button("🆓 Отпустить (снять приказ)", "order_stop", "")

	hint_label.text = "Клик по пустому месту — закрыть"


func _add_section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	buttons_vbox.add_child(l)


func _add_button(text: String, action: String, prompt: String) -> void:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_button.bind(action, prompt))
	buttons_vbox.add_child(btn)


func _on_button(action: String, prompt: String) -> void:
	if selected_npc == null or not is_instance_valid(selected_npc):
		return
	match action:
		"order_trade":
			_order_trade()
			_refresh()
		"order_wait":
			_order_wait()
			_refresh()
		"order_stop":
			_order_stop()
			_refresh()
		_:
			if prompt != "":
				_start_pending(action, prompt)


func _get_city() -> Node:
	var tree := get_tree()
	if tree and tree.current_scene:
		return tree.current_scene
	return null


func _role_name(role: String) -> String:
	match role:
		"baron": return "👑 Барон"
		"bishop": return "⛪ Епископ"
		"inquisition": return "🔥 Инквизитор"
		"treasurer": return "💰 Казначей"
		"garrison": return "⚔️ Солдат"
		"merchant": return "🛒 Торговец"
		"cultist": return "🔮 Культист"
		"resident": return "👤 Житель"
		"mayor": return "🏛️ Мэр"
		"sheriff": return "⭐ Шериф"
		"priest": return "⛪ Священник"
	return role
