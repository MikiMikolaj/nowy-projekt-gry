# HealthComponent: hit points for any entity. Emits signals; the owner decides what damage/death looks like.
class_name HealthComponent
extends Node

signal damaged(amount: int, source: Node)
signal died

@export var max_hp: int = 3

var current_hp: int = 0
# Set by the owner during i-frames (dash, post-hurt flicker).
var invincible: bool = false


func _ready() -> void:
	current_hp = max_hp


func take_damage(amount: int, source: Node = null) -> void:
	if invincible or is_dead() or amount <= 0:
		return
	current_hp = maxi(current_hp - amount, 0)
	damaged.emit(amount, source)
	if current_hp == 0:
		died.emit()


func reset() -> void:
	current_hp = max_hp
	invincible = false


func is_dead() -> bool:
	return current_hp <= 0
