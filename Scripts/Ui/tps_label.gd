extends Label

@export var timeManager : Node
func _process(delta: float) -> void:
	if (timeManager):
		text = "TPS: " + str(roundf(1/timeManager.tickDeltaTime * 10) / 10)
	else:
		text = ""
