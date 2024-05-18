class_name Quadrant
extends Object

const q2 := PI / 1
const q4 := PI / 2
const q8 := PI / 4

static func angle_to_q2(angle: float) -> int:
	return clampi(roundi(wrapf(angle, -PI / 2, 3 * PI / 2) / q2), 0, 1)
static func angle_to_q4(angle: float) -> int:
	return clampi(roundi(wrapf(angle, -PI / 4, 7 * PI / 4) / q4), 0, 3)
static func angle_to_q8(angle: float) -> int:
	return clampi(roundi(wrapf(angle, -PI / 8, 15 * PI / 8) / q8), 0, 7)
static func round_q2(angle: float) -> float:
	return angle_to_q2(angle) * q2
static func round_q4(angle: float) -> float:
	return angle_to_q4(angle) * q4
