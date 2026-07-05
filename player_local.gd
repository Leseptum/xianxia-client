extends CharacterBody2D

const SPEED = 150.0
const SEND_INTERVAL = 0.1  # 10x pro Sekunde

var _send_timer = 0.0
var _last_sent  = Vector2.ZERO

func _ready() -> void:
	$Camera2D.enabled = true

func _physics_process(delta: float) -> void:
	var input = Vector2.ZERO
	if Input.is_action_pressed("ui_right"): input += Vector2(1,  0.5)
	if Input.is_action_pressed("ui_left"):  input += Vector2(-1, -0.5)
	if Input.is_action_pressed("ui_down"):  input += Vector2(-1,  0.5)
	if Input.is_action_pressed("ui_up"):    input += Vector2(1, -0.5)

	velocity = input.normalized() * SPEED
	move_and_slide()

	# UpdatePosition nur senden wenn bewegt + Interval abgelaufen
	_send_timer += delta
	if _send_timer >= SEND_INTERVAL and position != _last_sent:
		_send_timer = 0.0
		_last_sent  = position
		SpacetimeDB.Xianxia.reducers.update_position(
			Global.my_player_id, position.x, position.y
		)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # E oder Enter
		SpacetimeDB.Xianxia.reducers.qi_sammeln(Global.my_player_id, 10)
