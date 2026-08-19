## Система Культа
## Скрытые культисты проводят ритуалы
class_name CultSystem
extends Node

signal cult_ritual_performed(ritual_type: String, success: bool)
signal cultist_revealed(cultist_id: int)
signal cult_discovery(awareness: float)

# Культисты
var cultists: Array[int] = []  # IDs cultists
var cult_leader_id: int = -1

# Сила культа
var cult_power: float = 0.0  # 0-100
var cult_awareness: float = 0.0  # Насколько инквизиция близка к раскрытию

# Настройки
const BASE_CULTIST_CHANCE: float = 0.1  # 10% жителей - cultists
const RITUAL_AWARENESS_INCREASE: float = 5.0  # Увеличение осведомлённости за ритуал
const MAX_CULTISTS: int = 4

func _ready():
	print("🔮 Система культа инициализирована")

## Добавить cultist
func add_cultist(npc: BaseNPC) -> void:
	if npc.npc_id in cultists:
		return
	if cultists.size() >= MAX_CULTISTS:
		return
	
	cultists.append(npc.npc_id)
	
	# Превращаем NPC в cultist
	_convert_to_cultist(npc)
	
	print("🔮 Новый культист: %s!" % npc.npc_name)
	emit_signal("cultist_revealed", npc.npc_id)

func _convert_to_cultist(npc: BaseNPC) -> void:
	# Удаляем старую роль
	if npc.role:
		npc.role.queue_free()
	
	# Создаём роль cultist
	var cultist_role = CultistRole.new()
	npc.add_child(cultist_role)
	cultist_role.initialize(npc)
	npc.role = cultist_role
	
	# Изменяем цвет (скрытый тёмный)
	npc.base_color = Color(0.3, 0.2, 0.3)
	if npc.sprite:
		npc.sprite.modulate = npc.base_color

## Убрать cultist
func remove_cultist(npc_id: int) -> void:
	if npc_id in cultists:
		cultists.erase(npc_id)
		cult_awareness -= 20.0  # Снижаем подозрительность

## Провести ритуал (вызывается от cultist)
func perform_ritual(cultist: BaseNPC) -> void:
	cult_power += 5.0
	cult_awareness += RITUAL_AWARENESS_INCREASE
	
	# Эффект на город
	_apply_ritual_effect()
	
	# Проверяем обнаружение
	_check_for_discovery()
	
	emit_signal("cult_ritual_performed", "dark_ritual", true)

func _apply_ritual_effect() -> void:
	# Случайный эффект на город
	var effect = randi() % 4
	
	match effect:
		0:  # Паника
			if GameManager.event_system:
				GameManager.event_system.decrease_order(10.0)
		1:  # Убийство
			_sacrifice_victim()
		2:  # Проклятие
			_curse_random_citizen()
		3:  # Размножение культа
			_attempt_spread()

func _sacrifice_victim() -> void:
	var victims: Array[BaseNPC] = []
	
	for npc in GameManager.npcs:
		if npc.role is CultistRole:
			continue
		if npc.role is BaronRole:
			continue
		victims.append(npc)
	
	if victims.size() == 0:
		return
	
	var victim = victims[randi() % victims.size()]
	var killer: BaseNPC = GameManager.get_npc_by_id(cultists[0]) if cultists.size() > 0 else null
	victim.die(killer)
	
	print("🔮💀 Жертвоприношение: %s!" % victim.npc_name)

func _curse_random_citizen() -> void:
	var targets: Array[BaseNPC] = []
	
	for npc in GameManager.npcs:
		if npc.role is CultistRole:
			continue
		targets.append(npc)
	
	if targets.size() == 0:
		return
	
	var target = targets[randi() % targets.size()]
	target.need_system.energy -= 40
	var gs: GURPSSystem = GameManager.gurps_system
	if gs and target.gurps:
		var resist = gs.ht_check(target, 0, "Проклятие: " + target.npc_name)
		if not resist.success:
			target.gurps.take_damage(2, "toxic")
	print("🔮 Проклятие обрушилось на %s!" % target.npc_name)

func _attempt_spread() -> void:
	# Пытаемся завербовать нового
	for npc in GameManager.npcs:
		if npc.role is CultistRole:
			continue
		if npc.npc_id in cultists:
			continue
		
		# Бедные и одинокие более восприимчивы
		if npc.wealth < 30 and npc.need_system.social < 40:
			var gs: GURPSSystem = GameManager.gurps_system
			var recruited := false
			if gs:
				var resist = gs.will_check(npc, -2, "Сопротивление культу: " + npc.npc_name)
				recruited = not resist.success
				print("🔮 ", gs.describe_result(resist))
			else:
				recruited = randf() < 0.2
			if recruited:
				add_cultist(npc)
				return

func _check_for_discovery() -> void:
	# Проверяем, не слишком ли опасно
	if cult_awareness >= 80.0:
		# Инквизиция близка!
		var inquisitor = _get_inquisitor()
		if inquisitor:
			# Инквизитор знает о культе
			for cultist_id in cultists:
				inquisitor.role.suspects.append(cultist_id)
	
	emit_signal("cult_discovery", cult_awareness)

func _get_inquisitor() -> BaseNPC:
	for npc in GameManager.npcs:
		if npc.role is InquisitionRole:
			return npc
	return null

## Раскрыть cultist (пойман инквизицией)
func expose_cultist(cultist_id: int) -> void:
	var cultist = GameManager.get_npc_by_id(cultist_id)
	if not cultist:
		return
	
	print("🔮💀 Культист %s разоблачён!" % cultist.npc_name)
	
	# Удаляем из списка
	remove_cultist(cultist_id)
	
	# NPC будет наказан
	var inquisitor = _get_inquisitor()
	if inquisitor:
		inquisitor.role._accuse_of_heresy(cultist)

## NPC является культистом?
func is_cultist(npc_id: int) -> bool:
	return npc_id in cultists

## Получить всех cultists
func get_cultists() -> Array[int]:
	return cultists

## Получить силу культа
func get_cult_power() -> float:
	return cult_power

## Запустить инициализацию культа
func initialize_cult() -> void:
	# Определяем начальных cultists
	var residents: Array[BaseNPC] = []
	
	for npc in GameManager.npcs:
		if npc.role is ResidentRole:
			residents.append(npc)
	
	# Случайные cultists
	var cultist_count = int(float(residents.size()) * BASE_CULTIST_CHANCE)
	cultist_count = clamp(cultist_count, 1, MAX_CULTISTS)
	
	for i in range(cultist_count):
		if residents.size() > i:
			add_cultist(residents[i])

## Увеличить осведомлённость
func increase_awareness(amount: float) -> void:
	cult_awareness = clamp(cult_awareness + amount, 0.0, 100.0)
	_check_for_discovery()
