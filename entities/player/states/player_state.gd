# PlayerState: base for player states; gives each state a typed reference to the Player.
class_name PlayerState
extends State

var player: Player


func _ready() -> void:
	player = owner as Player
