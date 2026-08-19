## Роль Торговца
class_name MerchantRole
extends Role

# Магазин
@export var shop_position: Vector2 = Vector2(450, 400)

# Товары
var inventory: Dictionary = {
	"food": 10,
	"tools": 5,
	"luxury": 3,
}

# Цены
const PRICES: Dictionary = {
	"food": 3,
	"tools": 25,
	"luxury": 50,
}

# Доход
var daily_income: float = 0.0

func _init():
	role_type = "merchant"
	work_start_hour = 8.0
	work_end_hour = 20.0  # Торговец работает допоздна
	sleep_start_hour = 23.0
	sleep_end_hour = 7.0

func initialize(npc: BaseNPC) -> void:
	super.initialize(npc)
	shop_position = _cell(42, 29)
	work_position = shop_position
	home_position = _cell(40, 28)

func update(delta: float) -> void:
	super.update(delta)
	
	# Торговец ест из собственных запасов, если голоден
	if owner_npc and owner_npc.food <= 0.0 and owner_npc.need_system.hunger < 50.0:
		if int(inventory.get("food", 0)) > 0:
			inventory["food"] = int(inventory["food"]) - 1
			owner_npc.food += 3.0

func get_current_behavior() -> String:
	var time = TimeSystem.current_time
	
	var priority_need = owner_npc.need_system.get_priority_need()
	if priority_need != "":
		return priority_need
	
	# Работает весь день до позднего вечера
	if time >= 8.0 and time < 20.0:
		return "work"  # В магазине
	
	return "sleep"

func get_target_position() -> Vector2:
	match get_current_behavior():
		"work":
			return shop_position
		"sleep":
			return home_position
		"buy_food":
			return _cell(5, 6)  # На ферму за едой
	return home_position

## Продать товар
func sell_item(item: String, buyer: BaseNPC) -> bool:
	if not inventory.has(item) or inventory[item] <= 0:
		return false
	
	if buyer.wealth < PRICES[item]:
		return false
	
	# Сделка
	inventory[item] -= 1
	buyer.wealth -= PRICES[item]
	owner_npc.wealth += PRICES[item]
	daily_income += PRICES[item]
	
	# Товар переходит покупателю
	match item:
		"food":
			buyer.food += 5.0  # еды хватает на несколько трапез
			print("🛒 %s купил еду у %s за %.0f" % [buyer.npc_name, owner_npc.npc_name, PRICES[item]])
		"tools":
			buyer.need_system.safety = clamp(buyer.need_system.safety + 10.0, 0.0, 100.0)
		"luxury":
			buyer.need_system.social = clamp(buyer.need_system.social + 10.0, 0.0, 100.0)
	
	# Отношения улучшаются
	owner_npc.relationship_graph.modify_relationship(owner_npc.npc_id, buyer.npc_id, 5.0, 3.0)
	
	return true

## Купить товар (для себя)
func buy_essential() -> void:
	# Торговец покупает еду себе
	if owner_npc.wealth >= PRICES["food"] and inventory["food"] < 5:
		owner_npc.wealth -= PRICES["food"]
		inventory["food"] += 1

func get_description() -> String:
	return "Торговец. Продаёт товары, зарабатывает деньги. Работает допоздна."
