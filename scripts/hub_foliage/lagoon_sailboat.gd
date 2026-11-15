## Slow open-water circuit. Geometry is exported in world coordinates, so this
## parent applies a small translation without changing its authored pose.
extends MeshInstance3D
var elapsed := 0.0
func _process(delta: float) -> void:
	elapsed += delta
	position.x = 5.0 * sin(elapsed * 0.025)
	position.z = 2.0 * (cos(elapsed * 0.025) - 1.0)
	position.y = 0.045 * sin(elapsed * 1.15)
