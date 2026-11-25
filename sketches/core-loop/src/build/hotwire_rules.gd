extends RefCounted

const RIVETED_ARMOUR := 2.0
const RIVETED_AIR_FACTOR := 0.75


const PART := "spark_tread"
const BONUS := 0.75
const RECOVERY := 3.0
const MIN_CRUISE_SHARE := 0.5
const WEAR_SCALE := 2.0
const ELIGIBLE := ["ram", "slam", "stomp"]


static func fitted(parts: Array, flag: String) -> bool:
	return PART in parts and flag != "off"


static func wear_scale(is_fitted: bool) -> float:
	return WEAR_SCALE if is_fitted else 1.0


static func eligible(kind: String, recovery_left: float, speed: float, cruise: float, mass: float) -> bool:
	return kind in ELIGIBLE and recovery_left <= 0.0 and mass > 0.0 and cruise > 0.0 \
		and speed >= cruise * MIN_CRUISE_SHARE


static func bonus_damage(punch: float) -> float:
	return punch * BONUS


static func fill(text: String) -> String:
	var mult_text := _times(RIVETED_ARMOUR)
	var wear_text := _times(WEAR_SCALE)
	return text.replace("{armor}", "Double" if is_equal_approx(RIVETED_ARMOUR, 2.0) else mult_text + "x") \
		.replace("{armor_x}", mult_text).replace("{steer}", str(int(round((1.0 - RIVETED_AIR_FACTOR) * 100.0)))) \
		.replace("{wear}", "Double" if is_equal_approx(WEAR_SCALE, 2.0) else wear_text + "x") \
		.replace("{wear_x}", wear_text).replace("{bonus}", str(int(round(BONUS * 100.0))))


static func _times(value: float) -> String:
	return "%d" % int(value) if is_equal_approx(value, round(value)) else "%.1f" % value
