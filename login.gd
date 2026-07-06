extends Control

const REQUEST_TIMEOUT_SEC := 8.0

@onready var name_input   = $VBoxContainer/LineEdit
@onready var pw_input     = $VBoxContainer/LineEdit2
@onready var status_label = $VBoxContainer/Label2
@onready var login_btn    = $VBoxContainer/HBoxContainer/Button
@onready var register_btn = $VBoxContainer/HBoxContainer/Button2

# true, solange auf die Antwort des Reducers (oder den Player-Insert) gewartet wird.
# Verhindert, dass ein verspäteter Timeout eine bereits erfolgreiche/fehlgeschlagene
# Anmeldung überschreibt, bzw. dass eine spätere Antwort einen zwischenzeitlichen Timeout überschreibt.
var _request_pending := false

func _ready() -> void:
	login_btn.disabled  = true
	register_btn.disabled = true
	status_label.text   = "Verbinde..."
	login_btn.pressed.connect(_on_login_pressed)
	register_btn.pressed.connect(_on_register_pressed)
	SpacetimeDB.Xianxia.connected.connect(_on_connected)
	SpacetimeDB.Xianxia.connection_error.connect(func(_c, r):
		status_label.text = "Verbindungsfehler: " + r
		login_btn.disabled = false
		register_btn.disabled = false
	)
	SpacetimeDB.Xianxia.connect_db("http://127.0.0.1:3000", "xianxia")

func _on_connected(identity, _token) -> void:
	Global.my_identity = identity.hex_encode()
	status_label.text  = "Verbunden. Bitte anmelden."
	login_btn.disabled = false
	register_btn.disabled = false

func _hash(pw: String) -> String:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(pw.to_utf8_buffer())
	return ctx.finish().hex_encode()

func _try_enter(name: String, pw: String, registrieren: bool) -> void:
	if name.is_empty() or pw.length() < 4:
		status_label.text = "Name + Passwort (min. 4 Zeichen) eingeben."
		return
	Global.my_name = name
	var pw_hash = _hash(pw)
	# Erst subscriben, dann Reducer — so kommt der Insert garantiert an.
	# Filter per :sender — es kommt nur die Zeile des anzumeldenden Spielers an,
	# nicht die komplette Player-Tabelle.
	SpacetimeDB.Xianxia.subscribe(["SELECT * FROM player WHERE identity = :sender", "SELECT * FROM world_tile"])
	SpacetimeDB.Xianxia.db.player.on_insert(_on_player_insert)

	login_btn.disabled = true
	register_btn.disabled = true
	_request_pending = true

	var call: SpacetimeDBReducerCall
	if registrieren:
		call = SpacetimeDB.Xianxia.reducers.register(name, pw_hash)
		status_label.text = "Registrieren..."
	else:
		call = SpacetimeDB.Xianxia.reducers.login(name, pw_hash)
		status_label.text = "Anmelden..."

	if call.error != OK:
		_on_reducer_failed("Anfrage konnte nicht gesendet werden (%s)." % error_string(call.error))
		return

	call.on_error.connect(_on_reducer_failed)
	call.on_internal_error.connect(_on_reducer_failed)

	_watch_timeout()

func _watch_timeout() -> void:
	await get_tree().create_timer(REQUEST_TIMEOUT_SEC).timeout
	if not _request_pending:
		return
	_request_pending = false
	status_label.text = "Zeitüberschreitung: Server antwortet nicht."
	login_btn.disabled = false
	register_btn.disabled = false

func _on_reducer_failed(err: String) -> void:
	if not _request_pending:
		return
	_request_pending = false
	status_label.text = "Fehler: " + err
	login_btn.disabled = false
	register_btn.disabled = false

func _on_player_insert(player) -> void:
	if not _request_pending:
		return
	_request_pending = false
	Global.my_player_id = player.player_id
	status_label.text = "Willkommen, " + player.get("name") + "!"
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://world.tscn")

func _on_login_pressed()    -> void: _try_enter(name_input.text.strip_edges(), pw_input.text, false)
func _on_register_pressed() -> void: _try_enter(name_input.text.strip_edges(), pw_input.text, true)
