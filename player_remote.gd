extends CharacterBody2D

var target_position: Vector2 = Vector2.ZERO
const INTERP_SPEED = 10.0

func _ready() -> void:
	target_position = position
	# Kamera deaktivieren — ist kein lokaler Spieler
	if has_node("Camera2D"):
		$Camera2D.enabled = false

func _physics_process(delta: float) -> void:
	position = position.lerp(target_position, INTERP_SPEED * delta)
