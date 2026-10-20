# WalkerState: base for walker states; gives each state a typed reference to the Walker.
class_name WalkerState
extends State

var walker: Walker


func _ready() -> void:
	walker = owner as Walker
