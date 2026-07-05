extends Node2D

@onready var tilemap: TileMapLayer = $TileMapLayer

var player_local_scene  = preload("res://player_local.tscn")
var player_remote_scene = preload("res://player_remote.tscn")

# player_id -> Node
var player_nodes: Dictionary = {}

const BIOM_TILE = {
	0: Vector2i(0, 0),  # Wasser
	1: Vector2i(1, 0),  # Strand
	2: Vector2i(2, 0),  # Ebene
	3: Vector2i(3, 0),  # Wald
	4: Vector2i(4, 0),  # Berg
	5: Vector2i(5, 0),  # Schnee
}

var tiles_geladen   = 0
var welt_bereit     = false

func _ready() -> void:
	SpacetimeDB.Xianxia.db.world_tile.on_insert(_on_tile_insert)
	SpacetimeDB.Xianxia.db.player.on_insert(_on_player_insert)
	SpacetimeDB.Xianxia.db.player.on_update(_on_player_update)
	SpacetimeDB.Xianxia.db.player.on_delete(_on_player_delete)
	# Verbindung steht bereits (login.gd hat connect_db gemacht)
	# Welt-Tiles sind bereits subscribed — kommen direkt rein

func _on_tile_insert(tile) -> void:
	var coords = BIOM_TILE.get(tile.biom_typ, Vector2i(2, 0))
	tilemap.set_cell(Vector2i(tile.x, tile.y), 1, coords)
	tiles_geladen += 1
	if tiles_geladen == 65536:
		welt_bereit = true
		print("Welt geladen!")

func _on_player_insert(player) -> void:
	var pid = player.player_id
	if player_nodes.has(pid):
		return
	var ist_lokal = (pid == Global.my_player_id)
	var node
	if ist_lokal:
		node = player_local_scene.instantiate()
		node.position = Vector2(player.pos_x, player.pos_y)
	else:
		node = player_remote_scene.instantiate()
		node.position = Vector2(player.pos_x, player.pos_y)
	node.set_meta("player_id", pid)
	node.set_meta("player_name", player.get("name"))
	add_child(node)
	player_nodes[pid] = node

func _on_player_update(_old, player) -> void:
	var pid = player.player_id
	if not player_nodes.has(pid):
		return
	if pid == Global.my_player_id:
		return  # lokaler Spieler bewegt sich selbst
	# Remote-Spieler: Position vom Server übernehmen
	player_nodes[pid].target_position = Vector2(player.pos_x, player.pos_y)

func _on_player_delete(player) -> void:
	var pid = player.player_id
	if player_nodes.has(pid):
		player_nodes[pid].queue_free()
		player_nodes.erase(pid)
