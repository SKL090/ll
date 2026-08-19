## Система Доносов
## Жители могут писать друг на друга доносы
class_name DenunciationSystem
extends Node

signal denouncement_filed(denouncer_id: int, accused_id: int, reason: String)
signal denouncement_investigated(result: bool)

# Активные доносы
var denouncements: Array[Denouncement] = []
var next_denouncement_id: int = 1

# Настройки
const BASE_DENOUNCE_CHANCE: float = 0.05  # 5% шанс в день
const FALSE_ACCUSATION_CHANCE: float = 0.3  # 30% доносов ложные

class Denouncement:
	var id: int
	var denouncer_id: int
	var accused_id: int
	var reason: String
	var evidence: float  # 0-100 сила доноса
	var day_filed: int
	var is_investigated: bool
	
	func _init(p_id: int, p_denouncer: int, p_accused: int, p_reason: String):
		id = p_id
		denouncer_id = p_denouncer
		accused_id = p_accused
		reason = p_reason
		evidence = _calculate_evidence()
		day_filed = GameManager.current_day
		is_investigated = false

func _calculate_evidence() -> float:
	# Сила доноса зависит от причины
	var base = randf_range(30.0, 70.0)
	return clamp(base, 0.0, 100.0)

func _ready():
	print("📜 Система доносов инициализирована")

## Создать донос (вызывается автоматически или игроком)
func file_denouncement(denouncer_id: int, accused_id: int, reason: String = "") -> Denouncement:
	# Проверяем, не написал ли уже
	for d in denouncements:
		if d.denouncer_id == denouncer_id and d.accused_id == accused_id and not d.is_investigated:
			return d  # Уже есть
	
	var d = Denouncement.new(next_denouncement_id, denouncer_id, accused_id, reason)
	next_denouncement_id += 1
	
	denouncements.append(d)
	
	emit_signal("denouncement_filed", denouncer_id, accused_id, reason)
	
	# Уведомляем инквизицию
	_notify_inquisition(d)
	
	return d

## Уведомить инквизицию о доносе
func _notify_inquisition(d: Denouncement) -> void:
	var inquisitor = _get_inquisitor()
	if inquisitor:
		inquisitor.role.receive_denouncement(d.denouncer_id, d.accused_id, d.reason)
		print("📜 Инквизиция получила донос на %s" % _get_npc_name(d.accused_id))

func _get_inquisitor() -> BaseNPC:
	for npc in GameManager.npcs:
		if npc.role is InquisitionRole:
			return npc
	return null

## NPC подумывает о доносе
func consider_denouncement(npc: BaseNPC) -> void:
	# Проверяем условия
	if randf() > BASE_DENOUNCE_CHANCE:
		return
	
	# Ищем кого обвинить
	var potential_targets: Array[BaseNPC] = []
	
	for other in GameManager.npcs:
		if other.npc_id == npc.npc_id:
			continue
		if other.role is BaronRole or other.role is InquisitionRole:
			continue
		
		# Проверяем отношения
		var rel = npc.relationship_graph.get_relationship(npc.npc_id, other.npc_id)
		if rel.hate > 30 or rel.trust < -20:
			potential_targets.append(other)
	
	if potential_targets.size() == 0:
		return
	
	# Выбираем цель
	var target = potential_targets[randi() % potential_targets.size()]
	
	# Определяем причину
	var reason = _generate_reason(npc, target)
	
	# Создаём донос
	file_denouncement(npc.npc_id, target.npc_id, reason)

func _generate_reason(denouncer: BaseNPC, target: BaseNPC) -> String:
	var reasons = [
		"ересь",
		"подозрительное поведение",
		"богохульство",
		"ночные сборища",
		"неуплата налогов",
		"оскорбление чести",
		"воровство",
	]
	
	# Выбираем причину на основе отношений
	var rel = denouncer.relationship_graph.get_relationship(denouncer.npc_id, target.npc_id)
	
	if rel.hate > 60:
		return reasons[randi() % 3]  # Серьёзные обвинения
	else:
		return reasons[3 + randi() % (reasons.size() - 3)]

## Расследовать донос
func investigate_denouncement(d: Denouncement) -> bool:
	if d.is_investigated:
		return false
	
	d.is_investigated = true
	
	# Определяем результат
	var is_true = d.evidence >= 50.0 and randf() < d.evidence / 100.0
	
	emit_signal("denouncement_investigated", is_true)
	
	if is_true:
		print("📜 Донос на %s подтверждён!" % _get_npc_name(d.accused_id))
	else:
		print("📜 Донос на %s оказался ложным!" % _get_npc_name(d.accused_id))
		# Клеветник получает наказание
		var denouncer = GameManager.get_npc_by_id(d.denouncer_id)
		if denouncer:
			denouncer.relationship_graph.modify_relationship(
				denouncer.npc_id,
				d.accused_id,
				hate_delta: 20.0  # Ещё больше ненавидят
			)
	
	return is_true

## Получить все нерасследованные доносы
func get_pending_denouncements() -> Array[Denouncement]:
	return denouncements.filter(func(d): return not d.is_investigated)

## Очистить старые доносы
func cleanup_old_denouncements() -> void:
	var cutoff_day = GameManager.current_day - 7  # Недельная давность
	
	var to_remove: Array[int] = []
	for d in denouncements:
		if d.day_filed < cutoff_day and d.is_investigated:
			to_remove.append(d.id)
	
	denouncements = denouncements.filter(func(d): return not d.id in to_remove)

## NPC хочет написать донос (публичный метод для UI)
func npc_wants_to_denounce(denouncer: BaseNPC, target: BaseNPC, custom_reason: String = "") -> bool:
	# Проверяем порог
	var rel = denouncer.relationship_graph.get_relationship(denouncer.npc_id, target.npc_id)
	
	if rel.hate < 40:
		return false  # Слишком хорошие отношения
	
	if rel.trust > 30:
		return false  # Не доверяет системе
	
	# Создаём донос
	var reason = custom_reason if custom_reason != "" else _generate_reason(denouncer, target)
	file_denouncement(denouncer.npc_id, target.npc_id, reason)
	
	return true

func _get_npc_name(npc_id: int) -> String:
	var npc = GameManager.get_npc_by_id(npc_id)
	return npc.npc_name if npc else "Неизвестный"
