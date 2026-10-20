# EnemySpawner: put enemies under this node in the editor. It remembers each one's scene and starting
# position, and rebuilds them all whenever the player respawns (death or debug_reset).
class_name EnemySpawner
extends Node2D

var _records: Array[Dictionary] = []


func _ready() -> void:
	for child: Node in get_children():
		var enemy: Node2D = child as Node2D
		if enemy != null and not enemy.scene_file_path.is_empty():
			_records.append({&"scene": load(enemy.scene_file_path), &"position": enemy.position})
	Events.player_respawned.connect(respawn_all)


func respawn_all() -> void:
	for child: Node in get_children():
		child.queue_free()
	for record: Dictionary in _records:
		var enemy: Node2D = (record[&"scene"] as PackedScene).instantiate() as Node2D
		# Positioned before entering the tree, so physics interpolation never draws it at the spawner's origin.
		enemy.position = record[&"position"]
		add_child(enemy)
		enemy.reset_physics_interpolation()
