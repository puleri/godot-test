extends RefCounted

const WEST := -12.6
const EAST := -3.55
const REAR := -4.4
const FRONT := 4.5
const UPPER_HEIGHT := 2.8
const STAIR_FOOT := Vector3(-6.03, 0, 1.60)
const STAIR_HEAD := Vector3(-6.03, UPPER_HEIGHT, -2.72)
const STAIR_TOP := Vector3(-6.03, UPPER_HEIGHT, -3.18)
const STAIR_WIDTH := 1.92
const ROOF_PEAK := 6.49


static func contains(at: Vector3) -> bool:
	return at.x > WEST and at.x < EAST and at.z > REAR and at.z < FRONT and at.y < ROOF_PEAK
