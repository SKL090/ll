## Базовый класс NPC — кукла-актёр
class_name BaseNPC
extends CharacterBody2D

# === СТАТИСТИКА ===
var npc_id: int
var npc_name: String = "NPC"
var base_color: Color = Color.WHITE

# === СИСТЕМЫ NPC ===
var need_system: NeedSystem
var relationship_graph: RelationshipGraph
var memory_system: MemorySystem
var planning_system: PlanningSystem
var state_machine: NPCStateMachine
var gurps: GURPSAttributes

# === РОЛЬ ===
var role: Role

# === ФИЗИКА ===
@export var move_speed: float = 80.0

# === СОСТОЯНИЕ ===
var wealth: float = 50.0
var food: float = 0.0            # еда на руках (единицы)
var is_alive: bool = true
var current_target: Node2D = null
var _assigned_role_type: String = "resident"
var _cached_behavior: String = ""
var _cached_target: Vector2 = Vector2.ZERO
var _last_theft_day: int = -1
var _death_started: bool = false
var _order_attack_cd: float = 0.0

# === ПРИКАЗЫ ИГРОКА (серый кардинал) ===
var player_order: Dictionary = {}   # {"type": String, "target": BaseNPC, "pos": Vector2}

# === ВИЗУАЛ ===
@onready var body_sprite: Sprite2D = $Puppet/Body
@onready var head_sprite: Sprite2D = $Puppet/Head
@onready var label: Label = $Label
@onready var state_label: Label = $StateLabel
@onready var collision: CollisionShape2D = $CollisionShape2D

# Алиас для совместимости (другие системы обращаются к npc.sprite)
var sprite: Sprite2D = null

# Гардероб: три куртки
const COAT_TEXTURES := {
	"lord": "res://assets/sprites/lord_coat_body.png",
	"inquisition": "res://assets/sprites/inquisition_coat.png",
	"common": "res://assets/sprites/coat_body.png",
}
# Цвета перекраски курток по ролям
const COAT_COLORS := {
	"baron": Color("8b0000"),        # кроваво-красный
	"mayor": Color("8b0000"),
	"inquisition": Color("555555"),  # тёмно-серая
	"inquisitor": Color("555555"),
	"garrison": Color("2f4f4f"),     # стража
	"soldier": Color("2f4f4f"),
	"resident": Color("556b2f"),     # жители
	"bishop": Color("151515"),       # чёрная
	"priest": Color("333333"),
	"merchant": Color("e07b39"),
	"treasurer": Color("8b7d3c"),
	"cultist": Color("3a1f4a"),
	"sheriff": Color("2f4f4f"),
}
var coat_color: Color = Color.WHITE

# Кровать (назначается городом)
var bed_position: Vector2 = Vector2.ZERO

const EMOTION_COLORS = {
	"happy": Color(0.486, 0.702, 0.259),
	"neutral": Color(0.992, 0.851, 0.208),
	"angry": Color(0.898, 0.224, 0.208),
	"sleepy": Color(0.361, 0.420, 0.737),
	"hungry": Color(0.553, 0.431, 0.388),
}

const MURDER_CHECK_INTERVAL: float = 10.0
const FOOD_PRICE: float = 3.0

var current_emotion: String = "neutral"
var murder_check_timer: float = 0.0

# === ЗРЕНИЕ ===
const VISION_RANGE: float = 200.0
const VISION_INTERVAL: float = 0.3
var visible_npcs: Array[BaseNPC] = []
var last_seen: Dictionary = {}   # npc_id -> {"pos": Vector2, "time": float}
var _vision_timer: float = 0.0

const WORK_BEHAVIORS = [
	"work", "office_work", "admin_work", "count_money", "distribute_funds",
	"evening_work", "audience", "meet_treasurer", "morning_preparation",
	"parish_duties", "confession", "morning_mass", "evening_service",
	"morning_service", "night_prayer", "counseling", "morning_drill",
]
const PATROL_BEHAVIORS = [
	"patrol", "patrol_day", "patrol_evening", "night_patrol",
	"night_patrol_aggressive", "prepare_patrol", "hunt_heretics",
	"investigate",
]
const REST_BEHAVIORS = [
	"sleep", "rest", "morning", "morning_routine", "lunch", "dinner",
]
const SOCIAL_BEHAVIORS = [
	"social", "evening", "wander", "evening_entertainment",
	"social_event", "receive_complaints",
]


func _init() -> void:
	need_system = NeedSystem.new()
	relationship_graph = RelationshipGraph.new()
	memory_system = MemorySystem.new()
	planning_system = PlanningSystem.new()
	state_machine = NPCStateMachine.new()
	gurps = GURPSAttributes.new()


func _ready() -> void:
	if need_system.get_parent() != self:
		add_child(need_system)
	if relationship_graph.get_parent() != self:
		add_child(relationship_graph)
	if memory_system.get_parent() != self:
		add_child(memory_system)
	if planning_system.get_parent() != self:
		add_child(planning_system)
	if state_machine.get_parent() != self:
		add_child(state_machine)
	if gurps.get_parent() != self:
		add_child(gurps)

	state_machine.set_owner_npc(self)
	planning_system.set_references(relationship_graph, memory_system)
	sprite = body_sprite
	_setup_puppet()

	if not need_system.critical_need.is_connected(_on_critical_need):
		need_system.connect("critical_need", _on_critical_need)
	if not state_machine.state_changed.is_connected(_on_state_changed):
		state_machine.connect("state_changed", _on_state_changed)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if GameManager.is_paused:
		velocity = Vector2.ZERO
		return

	if _order_attack_cd > 0.0:
		_order_attack_cd -= delta

	_update_ai(delta)
	_update_visual()


func _process(_delta: float) -> void:
	if not is_alive:
		return
	if label:
		label.text = npc_name
	if state_label:
		state_label.text = state_machine.get_state_name()


func initialize(id: int, given_name: String, color: Color, role_type: String = "resident") -> void:
	npc_id = id
	npc_name = given_name
	base_color = color
	_assigned_role_type = role_type

	if gurps:
		gurps.initialize_for_role(role_type)
		apply_move_from_gurps()

	_create_role(role_type)
	apply_wardrobe()
	_generate_initial_relationships()

	if not GameManager.npcs.has(self):
		GameManager.register_npc(self)


func _create_role(role_type: String) -> void:
	if role and is_instance_valid(role):
		role.queue_free()
		role = null

	match role_type:
		"mayor":
			role = MayorRole.new()
		"sheriff":
			role = SheriffRole.new()
		"baron":
			role = BaronRole.new()
		"bishop":
			role = BishopRole.new()
		"inquisition", "inquisitor":
			role = InquisitionRole.new()
		"treasurer":
			role = TreasurerRole.new()
		"garrison", "soldier":
			role = GarrisonSoldierRole.new()
		"merchant":
			role = MerchantRole.new()
		"priest":
			role = PriestRole.new()
		"cultist":
			role = CultistRole.new()
		"resident":
			role = ResidentRole.new()
		_:
			role = Role.new()

	add_child(role)
	role.initialize(self)


func _generate_initial_relationships() -> void:
	var all_ids: Array[int] = []
	for npc in GameManager.npcs:
		if is_instance_valid(npc):
			all_ids.append(npc.npc_id)
	if npc_id not in all_ids:
		all_ids.append(npc_id)

	relationship_graph.generate_initial_relationships(npc_id, all_ids)
	_setup_role_relationships(_assigned_role_type)


func _setup_role_relationships(role_type: String) -> void:
	match role_type:
		"mayor", "baron":
			for npc in GameManager.npcs:
				if npc != self and is_instance_valid(npc):
					relationship_graph.modify_relationship(npc.npc_id, npc_id, 20.0, 15.0, 0.0)
		"sheriff", "inquisition", "garrison":
			for npc in GameManager.npcs:
				if npc != self and is_instance_valid(npc):
					relationship_graph.modify_relationship(npc.npc_id, npc_id, 30.0, 0.0, 0.0)
		"bishop", "priest":
			for npc in GameManager.npcs:
				if npc != self and is_instance_valid(npc):
					relationship_graph.modify_relationship(npc.npc_id, npc_id, 15.0, 10.0, 0.0)


# ============================================================ ГЛАВНЫЙ ЦИКЛ AI

func _update_ai(delta: float) -> void:
	if role:
		role.update(delta)

	# Приказы игрока имеют высший приоритет
	if _handle_player_order(delta):
		return

	_update_vision(delta)

	if _is_recovering():
		return

	# ЕДА: есть еда и голодны — едим дома
	if food > 0.0 and need_system.hunger < 80.0:
		_go_or_act(role.home_position if role else global_position, state_machine.State.EATING)
		return

	# ЕДА: еды нет и голодны — идём покупать у торговца
	if food <= 0.0 and need_system.hunger < 45.0:
		if _try_buy_food():
			return

	if need_system.has_critical_need():
		_handle_critical_need()
		return

	murder_check_timer += delta
	if murder_check_timer >= MURDER_CHECK_INTERVAL:
		murder_check_timer = 0.0
		_check_murder_desire()
		_check_crime_desire()

	if role:
		_handle_behavior(role.get_current_behavior())


func _is_recovering() -> bool:
	var state = state_machine.current_state
	if state == state_machine.State.EATING and need_system.hunger < 80.0:
		return true
	if state == state_machine.State.SLEEPING and need_system.energy < 80.0:
		return true
	return false


func _handle_critical_need() -> void:
	var priority_need = need_system.get_priority_need()
	var rest_pos = role.home_position if role else global_position

	match priority_need:
		"hunger":
			if food > 0.0:
				_go_or_act(rest_pos, state_machine.State.EATING)
			else:
				_go_or_act(rest_pos, state_machine.State.IDLE)  # нечего есть
		"energy":
			# спать идём в кровать
			var sleep_pos := bed_position if bed_position != Vector2.ZERO else rest_pos
			_go_or_act(sleep_pos, state_machine.State.SLEEPING)
		"social":
			var social_pos = _get_social_target()
			_go_or_act(social_pos, state_machine.State.SOCIALIZING)


func _handle_behavior(behavior: String) -> void:
	if behavior != _cached_behavior:
		_cached_behavior = behavior
		_cached_target = role.get_target_position() if role else global_position

	if behavior == "steal":
		_handle_steal()
		return

	if behavior == "buy_food":
		if not _try_buy_food():
			_go_or_act(_cached_target, state_machine.State.IDLE)
		return

	if behavior == "perform_ritual":
		_go_or_act(_cached_target, state_machine.State.IDLE)
		if global_position.distance_to(_cached_target) < _arrive_dist() and role is CultistRole:
			role.start_ritual()
		return

	if behavior == "prepare_ritual":
		_go_or_act(_cached_target, state_machine.State.IDLE)
		return

	if behavior in REST_BEHAVIORS:
		var rest_target := _cached_target
		if behavior == "sleep" and bed_position != Vector2.ZERO:
			rest_target = bed_position
		_go_or_act(rest_target, state_machine.State.SLEEPING if behavior == "sleep" else state_machine.State.IDLE)
		return

	if behavior in WORK_BEHAVIORS:
		_go_or_act(_cached_target, state_machine.State.WORKING)
		return

	if behavior in PATROL_BEHAVIORS:
		_go_or_act(_cached_target, state_machine.State.PATROLLING)
		return

	if behavior in SOCIAL_BEHAVIORS:
		_go_or_act(_get_social_target(), state_machine.State.SOCIALIZING)
		return

	_go_or_act(_cached_target, state_machine.State.IDLE)


func _handle_steal() -> void:
	if not (role is ResidentRole):
		return

	_go_or_act(_cached_target, state_machine.State.STEALING)
	if global_position.distance_to(_cached_target) > _arrive_dist():
		return
	if _last_theft_day == GameManager.current_day:
		return

	_last_theft_day = GameManager.current_day
	role.attempt_theft()
	state_machine.start_stealing()


func _go_or_act(target: Vector2, arrive_state: NPCStateMachine.State) -> void:
	if target == Vector2.ZERO:
		target = global_position

	if global_position.distance_to(target) <= _arrive_dist():
		match arrive_state:
			state_machine.State.WORKING:
				state_machine.start_working()
			state_machine.State.SLEEPING:
				state_machine.start_sleeping()
			state_machine.State.EATING:
				state_machine.start_eating()
			state_machine.State.SOCIALIZING:
				state_machine.start_socializing()
			state_machine.State.PATROLLING:
				state_machine.start_patrolling()
			state_machine.State.STEALING:
				state_machine.start_stealing()
			_:
				if state_machine.current_state == state_machine.State.WALKING:
					state_machine.stop()
		return

	if state_machine.current_state != state_machine.State.WALKING \
			or state_machine.target_position.distance_to(target) > 40.0:
		state_machine.move_to(target)


# ============================================================ ПРИКАЗЫ ИГРОКА

func give_order(type: String, target: BaseNPC = null, pos: Vector2 = Vector2.ZERO) -> void:
	player_order = {"type": type, "target": target, "pos": pos}
	print("🎭 %s получил приказ: %s" % [npc_name, type])


func clear_order() -> void:
	player_order = {}
	state_machine.stop()


func has_order() -> bool:
	return not player_order.is_empty()


func _handle_player_order(_delta: float) -> bool:
	if player_order.is_empty():
		return false

	var type: String = player_order.get("type", "")
	match type:
		"wait":
			state_machine.stop()
			return true

		"go":
			var pos: Vector2 = player_order.get("pos", global_position)
			_go_or_act(pos, state_machine.State.IDLE)
			if global_position.distance_to(pos) <= _arrive_dist():
				clear_order()
			return true

		"follow":
			var t: BaseNPC = player_order.get("target")
			if t and is_instance_valid(t) and t.is_alive:
				if global_position.distance_to(t.global_position) > _arrive_dist():
					_go_or_act(t.global_position, state_machine.State.IDLE)
				else:
					state_machine.stop()
			else:
				clear_order()
			return true

		"attack":
			var at: BaseNPC = player_order.get("target")
			if at and is_instance_valid(at) and at.is_alive:
				if global_position.distance_to(at.global_position) > _arrive_dist():
					_go_or_act(at.global_position, state_machine.State.IDLE)
				elif _order_attack_cd <= 0.0:
					_order_attack_cd = 1.2
					at.take_damage(2.0, "crushing", self)
				return true
			clear_order()
			return false

		"trade":
			if _try_buy_food():
				return true
			clear_order()
			return false

	return false


# ============================================================ ЗРЕНИЕ

func _update_vision(delta: float) -> void:
	_vision_timer += delta
	if _vision_timer < VISION_INTERVAL:
		return
	_vision_timer = 0.0
	visible_npcs.clear()
	for other in GameManager.npcs:
		if other == self or not is_instance_valid(other) or not other.is_alive:
			continue
		var d: float = global_position.distance_to(other.global_position)
		if d > VISION_RANGE:
			continue
		if GameManager.world_map and not GameManager.world_map.has_line_of_sight(global_position, other.global_position):
			continue
		visible_npcs.append(other)
		last_seen[other.npc_id] = {"pos": other.global_position, "time": Time.get_ticks_msec() / 1000.0}


func can_see(other: BaseNPC) -> bool:
	if other == null or not is_instance_valid(other):
		return false
	if other in visible_npcs:
		return true
	# свежая проверка, если кэш устарел
	if GameManager.world_map == null:
		return global_position.distance_to(other.global_position) <= VISION_RANGE
	return global_position.distance_to(other.global_position) <= VISION_RANGE \
		and GameManager.world_map.has_line_of_sight(global_position, other.global_position)


func _get_social_target() -> Vector2:
	if visible_npcs.size() > 0:
		var nearest: BaseNPC = visible_npcs[0]
		var best: float = INF
		for other in visible_npcs:
			var d: float = global_position.distance_to(other.global_position)
			if d < best:
				best = d
				nearest = other
		return nearest.global_position
	return _cached_target if _cached_target != Vector2.ZERO else global_position


# ============================================================ ЕДА И ТОРГОВЛЯ

func _find_role_npc(role_type: String) -> BaseNPC:
	for npc in GameManager.npcs:
		if npc == self or not is_instance_valid(npc) or not npc.is_alive:
			continue
		if npc.role and npc.role.role_type == role_type:
			return npc
	return null


func _try_buy_food() -> bool:
	var merchant := _find_role_npc("merchant")
	if merchant == null:
		return false
	if wealth < FOOD_PRICE:
		return false

	if global_position.distance_to(merchant.global_position) > _arrive_dist() + 6.0:
		_go_or_act(merchant.global_position, state_machine.State.IDLE)
		return true

	if merchant.role is MerchantRole:
		merchant.role.sell_item("food", self)
	return true


# ============================================================ ПРЕСТУПЛЕНИЯ

## Ночью жители с сильной ненавистью могут поджечь дом врага
func _check_crime_desire() -> void:
	if not GameManager.crime_system:
		return
	if not (role is ResidentRole):
		return
	if not TimeSystem.is_nighttime():
		return
	if randf() > 0.05:
		return
	var enemies: Array[int] = relationship_graph.get_enemies(npc_id)
	if enemies.is_empty():
		return
	var target := GameManager.get_npc_by_id(enemies[0])
	if target == null or not is_instance_valid(target) or not target.is_alive:
		return
	if target.role and target.role.home_position != Vector2.ZERO:
		GameManager.crime_system.attempt_arson_at(self, target.role.home_position)


# ============================================================ УБИЙСТВА

func _check_murder_desire() -> void:
	if not GameManager.murder_system:
		return
	if GameManager.murder_system.murder_plans.has(npc_id):
		return

	for other in GameManager.npcs:
		if other == self or not is_instance_valid(other) or not other.is_alive:
			continue
		var rel = relationship_graph.get_relationship(npc_id, other.npc_id)
		if rel.hate >= 60.0 and rel.trust < -20.0:
			GameManager.murder_system.start_planning_murder(self, other)
			print("💭 %s вынашивает план против %s (ненависть: %.0f)" % [npc_name, other.npc_name, rel.hate])
			break


# ============================================================ ВИЗУАЛ

func _update_visual() -> void:
	var emotion = _calculate_emotion()
	if emotion != current_emotion:
		current_emotion = emotion
		_apply_emotion_color(emotion)


func _calculate_emotion() -> String:
	if gurps and gurps.current_hp < gurps.max_hp * 0.5:
		return "angry"
	if need_system.energy < 30:
		return "sleepy"
	if need_system.hunger < 30:
		return "hungry"
	if _has_enemies():
		return "angry"
	return "happy" if need_system.social > 50 else "neutral"


func _has_enemies() -> bool:
	return relationship_graph.get_enemies(npc_id).size() > 0


func _apply_emotion_color(emotion: String) -> void:
	if body_sprite == null:
		return
	if emotion == "neutral":
		body_sprite.modulate = coat_color
	elif EMOTION_COLORS.has(emotion):
		body_sprite.modulate = coat_color.lerp(EMOTION_COLORS[emotion], 0.5)


## Надеть куртку по роли и перекрасить
func apply_wardrobe() -> void:
	if body_sprite == null:
		return
	var role_key: String = role.role_type if (role and is_instance_valid(role)) else _assigned_role_type

	var tex_path: String = COAT_TEXTURES["common"]
	if role_key in ["baron", "mayor"]:
		tex_path = COAT_TEXTURES["lord"]
	elif role_key in ["inquisition", "inquisitor"]:
		tex_path = COAT_TEXTURES["inquisition"]

	var tex: Texture2D = load(tex_path)
	if tex:
		body_sprite.texture = tex

	coat_color = COAT_COLORS.get(role_key, Color.WHITE)
	body_sprite.modulate = coat_color
	if head_sprite:
		head_sprite.modulate = Color.WHITE
	_fit_puppet_scale()


func _setup_puppet() -> void:
	if body_sprite == null:
		return
	var head_tex: Texture2D = load("res://assets/sprites/head.png")
	if head_sprite:
		if head_tex:
			head_sprite.texture = head_tex
			head_sprite.modulate = Color.WHITE
		else:
			head_sprite.texture = null
	if load(COAT_TEXTURES["common"]) == null:
		_make_ball_fallback()
		return
	apply_wardrobe()


## Подгоняем куклу под размер тайла (тело ~1 тайл, голова ~0.5 тайла)
func _fit_puppet_scale() -> void:
	var ts := _tile_size()
	if body_sprite and body_sprite.texture:
		var bh: float = body_sprite.texture.get_height()
		if bh > 0.0:
			var s: float = ts / bh
			body_sprite.scale = Vector2(s, s)
	if head_sprite and head_sprite.texture:
		var hh: float = head_sprite.texture.get_height()
		if hh > 0.0:
			head_sprite.scale = Vector2(ts * 0.5 / hh, ts * 0.5 / hh)

	# голова встаёт на тело
	if body_sprite and head_sprite and body_sprite.texture:
		var body_h: float = body_sprite.texture.get_height() * body_sprite.scale.y
		var head_h: float = head_sprite.texture.get_height() * head_sprite.scale.y if head_sprite.texture else 0.0
		body_sprite.position = Vector2(0, 0)
		head_sprite.position = Vector2(0, -(body_h + head_h) * 0.5 + 1.0)

	# коллизия тоже масштабируется
	if collision:
		collision.scale = Vector2(ts / 32.0, ts / 32.0)


func _tile_size() -> float:
	if GameManager.world_map:
		return float(GameManager.world_map.get_tile_size())
	return 32.0


func _arrive_dist() -> float:
	return _tile_size() * 0.55


func _make_ball_fallback() -> void:
	if body_sprite == null:
		return
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := 14.5
	for x in size:
		for y in size:
			var point := Vector2(x + 0.5, y + 0.5)
			if point.distance_to(center) <= radius:
				var shade := 1.0 - (point.distance_to(center) / radius) * 0.25
				img.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	img.set_pixel(12, 13, Color(0.1, 0.1, 0.1, 1.0))
	img.set_pixel(13, 13, Color(0.1, 0.1, 0.1, 1.0))
	img.set_pixel(18, 13, Color(0.1, 0.1, 0.1, 1.0))
	img.set_pixel(19, 13, Color(0.1, 0.1, 0.1, 1.0))
	body_sprite.texture = ImageTexture.create_from_image(img)
	body_sprite.modulate = base_color
	if head_sprite:
		head_sprite.texture = null


func _on_critical_need(need_name: String) -> void:
	print("⚠️ ", npc_name, " критическая потребность: ", need_name)


func _on_state_changed(_from_state: String, _to_state: String) -> void:
	pass


func apply_move_from_gurps() -> void:
	if gurps:
		move_speed = (48.0 + float(gurps.basic_move) * 8.0) * (_tile_size() / 32.0)


func take_damage(amount: float = 1.0, damage_type: String = "crushing", attacker: BaseNPC = null) -> Dictionary:
	if not is_alive:
		return {}
	if gurps == null:
		die(attacker)
		return {"killing_blow": true, "damage": amount}

	var result: Dictionary = gurps.take_damage(int(amount), damage_type)
	print("⚔️ %s получает %d (%s) → HP %d/%d [%s]" % [
		npc_name, result.get("damage", 0), damage_type,
		gurps.current_hp, gurps.max_hp, gurps.get_health_state()
	])
	if result.get("killing_blow", false) or gurps.check_death():
		die(attacker)
	return result


func die(killer: BaseNPC = null) -> void:
	if not is_alive or _death_started:
		return

	is_alive = false
	_death_started = true
	velocity = Vector2.ZERO
	set_physics_process(false)

	if sprite:
		sprite.modulate = Color(0.25, 0.25, 0.25, 0.55)
	if head_sprite:
		head_sprite.modulate = Color(0.4, 0.4, 0.4, 0.7)

	if killer and is_instance_valid(killer) and killer != self:
		if killer.memory_system:
			killer.memory_system.add_memory(
				MemorySystem.EventType.MURDER,
				npc_id,
				"Убил " + npc_name
			)
		GameManager.commit_crime("murder", killer, self)
	else:
		GameManager.emit_signal("npc_died", self, killer)

	if is_inside_tree():
		var timer := get_tree().create_timer(1.5)
		timer.timeout.connect(_finish_death)
	else:
		_finish_death()


func _finish_death() -> void:
	if is_instance_valid(self):
		GameManager.unregister_npc(self)
		queue_free()


func interact_with(other: BaseNPC, action: String) -> void:
	match action:
		"help":
			relationship_graph.help(npc_id, other.npc_id)
			memory_system.add_memory(MemorySystem.EventType.HELP, other.npc_id, "Помог " + other.npc_name)
		"insult":
			relationship_graph.insult(npc_id, other.npc_id)
			memory_system.add_memory(MemorySystem.EventType.INSULT, other.npc_id, "Оскорбил " + other.npc_name)
		"meet":
			memory_system.add_memory(MemorySystem.EventType.MEETING, other.npc_id, "Встретился с " + other.npc_name)


func get_info() -> Dictionary:
	return {
		"name": npc_name,
		"role": role.role_type if role else "unknown",
		"state": state_machine.get_state_name(),
		"emotion": current_emotion,
		"wealth": wealth,
		"food": food,
		"visible": visible_npcs.size(),
		"order": player_order.get("type", "") if not player_order.is_empty() else "",
		"needs": {
			"hunger": need_system.hunger,
			"energy": need_system.energy,
			"social": need_system.social,
		},
		"enemies": relationship_graph.get_enemies(npc_id).size(),
		"friends": relationship_graph.get_friends(npc_id).size(),
		"gurps": gurps.get_data() if gurps else {},
		"gurps_text": gurps.get_summary() if gurps else "",
	}
