## Карта Отношений - Визуализация связей между NPC
class_name RelationshipMap
extends Control

var panel: PanelContainer
var scroll: ScrollContainer
var grid: GridContainer

const COLORS = {
	"friend": Color(0.3, 0.8, 0.3, 1),
	"enemy": Color(0.9, 0.2, 0.2, 1),
	"neutral": Color(0.6, 0.6, 0.6, 1),
	"cultist": Color(0.4, 0.0, 0.4, 1),
}

var is_visible: bool = false

func _ready():
	_create_ui()
	visible = false

func _create_ui():
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-450, 60)
	panel.size = Vector2(430, 550)
	add_child(panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	
	var header = Label.new()
	header.text = "🕸️ Карта Города"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	header.add_theme_font_size_override("font_size", 18)
	panel.add_child(header)
	
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	
	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

func toggle():
	is_visible = not is_visible
	visible = is_visible
	if is_visible:
		update_map()

func update_map():
	for child in grid.get_children():
		child.queue_free()
	
	if GameManager.npcs.size() == 0:
		return
	
	for npc in GameManager.npcs:
		if not npc.is_alive:
			continue
		
		var name_label = Label.new()
		name_label.text = _get_npc_icon(npc) + " " + npc.npc_name
		name_label.add_theme_color_override("font_color", _get_role_color(npc.role.role_type if npc.role else ""))
		grid.add_child(name_label)
		
		var arrow = Label.new()
		arrow.text = "→"
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(arrow)
		
		var rel_container = VBoxContainer.new()
		
		# Проверяем культистов
		if GameManager.cult_system and GameManager.cult_system.is_cultist(npc.npc_id):
			var cult_label = Label.new()
			cult_label.text = "  🔮 СЕКТАНТ"
			cult_label.add_theme_color_override("font_color", COLORS.cultist)
			rel_container.add_child(cult_label)
		
		var friends = npc.relationship_graph.get_friends(npc.npc_id)
		for friend_id in friends:
			var friend = GameManager.get_npc_by_id(friend_id)
			if friend:
				var friend_label = Label.new()
				friend_label.text = "  ❤️ " + friend.npc_name
				friend_label.add_theme_color_override("font_color", COLORS.friend)
				rel_container.add_child(friend_label)
		
		var enemies = npc.relationship_graph.get_enemies(npc.npc_id)
		for enemy_id in enemies:
			var enemy = GameManager.get_npc_by_id(enemy_id)
			if enemy:
				var enemy_label = Label.new()
				enemy_label.text = "  💔 " + enemy.npc_name
				enemy_label.add_theme_color_override("font_color", COLORS.enemy)
				rel_container.add_child(enemy_label)
		
		if friends.size() == 0 and enemies.size() == 0:
			var none_label = Label.new()
			none_label.text = "  —"
			none_label.add_theme_color_override("font_color", COLORS.neutral)
			rel_container.add_child(none_label)
		
		if GameManager.murder_system:
			var plan = GameManager.murder_system.get_plan_against(npc.npc_id)
			if plan:
				var danger_label = Label.new()
				danger_label.text = "  ⚠️ В ОПАСНОСТИ"
				danger_label.add_theme_color_override("font_color", Color(1, 0.3, 0))
				rel_container.add_child(danger_label)
		
		grid.add_child(rel_container)

func _get_npc_icon(npc: BaseNPC) -> String:
	if npc.role is BaronRole:
		return "👑"
	elif npc.role is BishopRole:
		return "⛪"
	elif npc.role is InquisitionRole:
		return "🔥"
	elif npc.role is TreasurerRole:
		return "💰"
	elif npc.role is GarrisonSoldierRole:
		return "⚔️"
	elif npc.role is CultistRole:
		return "🔮"
	else:
		return "👤"

func _get_role_color(role: String) -> Color:
	match role:
		"baron": return Color(0.8, 0.6, 0.2)
		"bishop": return Color(0.8, 0.8, 0.9)
		"inquisition": return Color(0.7, 0.0, 0.0)
		"treasurer": return Color(0.6, 0.6, 0.2)
		"garrison": return Color(0.3, 0.3, 0.6)
		"cultist": return Color(0.4, 0.0, 0.4)
		"resident": return Color(0.8, 0.6, 0.4)
	return Color.WHITE

func _process(delta: float):
	if is_visible and randf() < 0.1:
		update_map()
