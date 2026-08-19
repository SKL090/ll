## GURPS-проверки: 3d6 против навыка, быстрые конкурсы, урон
class_name GURPSSystem
extends Node

signal roll_made(result: Dictionary)
signal critical_success(roll: int, target: int)
signal critical_failure(roll: int, target: int)

const DIFFICULTY = {
	"trivial": 15,
	"easy": 12,
	"average": 10,
	"hard": 8,
	"very_hard": 6,
	"impossible": 4,
}


func roll_1d6() -> int:
	return randi() % 6 + 1


func roll_3d6(_modifier: int = 0) -> int:
	return roll_1d6() + roll_1d6() + roll_1d6()


## Положительный modifier облегчает проверку (как в GURPS).
func make_roll(base_value: int, modifier: int = 0, description: String = "") -> Dictionary:
	var roll := roll_3d6()
	var effective := base_value + modifier
	var success := roll <= effective
	var critical := false
	var fumble := false

	# Криты по GURPS Lite
	if roll == 3 or roll == 4 or (roll == 5 and effective >= 15) or (roll == 6 and effective >= 16):
		critical = true
		success = true
	if roll == 18 or (roll == 17 and effective <= 15):
		fumble = true
		success = false
		critical = false

	var margin := effective - roll
	var result := {
		"roll": roll,
		"target": effective,
		"success": success,
		"critical": critical,
		"fumble": fumble,
		"margin": margin,
		"description": description,
		"base_value": base_value,
		"modifier": modifier,
		"effective_target": effective,
	}
	emit_signal("roll_made", result)
	if critical:
		emit_signal("critical_success", roll, effective)
	elif fumble:
		emit_signal("critical_failure", roll, effective)
	return result


func skill_check(skill_level: int, difficulty_modifier: int = 0, description: String = "") -> Dictionary:
	return make_roll(skill_level, difficulty_modifier, description)


func attribute_check(attribute_value: int, difficulty_modifier: int = 0, description: String = "") -> Dictionary:
	return make_roll(attribute_value, difficulty_modifier, description)


## Быстрый конкурс: кто набрал больший запас (margin).
func quick_contest(skill_a: int, skill_b: int, desc_a: String = "", desc_b: String = "") -> Dictionary:
	var a := make_roll(skill_a, 0, desc_a)
	var b := make_roll(skill_b, 0, desc_b)
	var winner := 0
	if a.critical and not b.critical:
		winner = 1
	elif b.critical and not a.critical:
		winner = 2
	elif a.margin > b.margin:
		winner = 1
	elif b.margin > a.margin:
		winner = 2
	return {
		"winner": winner,
		"margin": abs(a.margin - b.margin),
		"a": a,
		"b": b,
	}


func lighting_modifier(lighting: String) -> int:
	match lighting:
		"bright", "normal":
			return 0
		"dim":
			return -1
		"dark":
			return -3
		"pitch_black":
			return -5
	return 0


func current_vision_modifier() -> int:
	var mod := 0
	if TimeSystem.is_nighttime():
		if TimeSystem.current_time >= 23.0 or TimeSystem.current_time < 5.0:
			mod -= 3
		else:
			mod -= 1
	if GameManager.weather_system:
		match GameManager.weather_system.current_weather:
			WeatherSystem.WeatherType.FOG:
				mod -= 2
			WeatherSystem.WeatherType.STORM:
				mod -= 2
			WeatherSystem.WeatherType.RAIN:
				mod -= 1
	return mod


func describe_result(result: Dictionary) -> String:
	var text := "Бросок: %d vs %d" % [result.get("roll", 0), result.get("target", 0)]
	if result.get("critical", false):
		text += " 🎯 КРИТ!"
	elif result.get("fumble", false):
		text += " 💀 ПРОВАЛ!"
	elif result.get("success", false):
		text += " ✅ запас %d" % result.get("margin", 0)
	else:
		text += " ❌ нехватка %d" % abs(int(result.get("margin", 0)))
	var desc: String = str(result.get("description", ""))
	if desc != "":
		text = desc + " — " + text
	return text


func _attrs(npc: BaseNPC) -> GURPSAttributes:
	if npc and is_instance_valid(npc) and npc.gurps:
		return npc.gurps
	return null


func perception_check(npc: BaseNPC, modifier: int = 0, description: String = "") -> Dictionary:
	var gurps := _attrs(npc)
	var per := gurps.current_perception if gurps else 10
	var desc := description if description != "" else "Восприятие: " + npc.npc_name
	return make_roll(per, modifier + current_vision_modifier(), desc)


func will_check(npc: BaseNPC, modifier: int = 0, description: String = "") -> Dictionary:
	var gurps := _attrs(npc)
	var will := gurps.current_will if gurps else 10
	var desc := description if description != "" else "Воля: " + npc.npc_name
	return make_roll(will, modifier, desc)


func dx_check(npc: BaseNPC, modifier: int = 0, description: String = "") -> Dictionary:
	var gurps := _attrs(npc)
	var dx := gurps.dexterity if gurps else 10
	var desc := description if description != "" else "DX: " + npc.npc_name
	return make_roll(dx, modifier, desc)


func iq_check(npc: BaseNPC, modifier: int = 0, description: String = "") -> Dictionary:
	var gurps := _attrs(npc)
	var iq := gurps.intelligence if gurps else 10
	var desc := description if description != "" else "IQ: " + npc.npc_name
	return make_roll(iq, modifier, desc)


func st_check(npc: BaseNPC, modifier: int = 0, description: String = "") -> Dictionary:
	var gurps := _attrs(npc)
	var st := gurps.strength if gurps else 10
	var desc := description if description != "" else "ST: " + npc.npc_name
	return make_roll(st, modifier, desc)


func ht_check(npc: BaseNPC, modifier: int = 0, description: String = "") -> Dictionary:
	var gurps := _attrs(npc)
	var ht := gurps.health if gurps else 10
	var desc := description if description != "" else "HT: " + npc.npc_name
	return make_roll(ht, modifier, desc)


func dodge_check(npc: BaseNPC, modifier: int = 0) -> Dictionary:
	var gurps := _attrs(npc)
	var dodge := gurps.get_dodge() if gurps else 8
	if gurps and gurps.get_health_state() == "reeling":
		modifier -= 2
	return make_roll(dodge, modifier, "Уклонение: " + npc.npc_name)


func attack_check(npc: BaseNPC, modifier: int = 0) -> Dictionary:
	return dx_check(npc, modifier, "Атака: " + npc.npc_name)


func stealth_check(npc: BaseNPC, modifier: int = 0) -> Dictionary:
	return dx_check(npc, modifier, "Скрытность: " + npc.npc_name)


func thrust_damage(st: int) -> int:
	var bonus := -2
	if st <= 8:
		bonus = -4
	elif st <= 9:
		bonus = -3
	elif st <= 10:
		bonus = -2
	elif st <= 12:
		bonus = -1
	elif st <= 14:
		bonus = 0
	elif st <= 16:
		bonus = 1
	else:
		bonus = 2
	return max(1, roll_1d6() + bonus)
