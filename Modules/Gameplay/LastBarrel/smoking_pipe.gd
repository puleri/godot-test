extends Node3D
## The ember and the trail share one lit state. Existing wisps disperse on snuffing.

func set_lit(lit: bool) -> void:
	$Ember.visible = lit
	$Smoke.emitting = lit
