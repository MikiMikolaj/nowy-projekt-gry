# State: base class for one state in a node-based StateMachine. Override only what you need.
class_name State
extends Node

# Set by the parent StateMachine so states can request transitions.
var state_machine: StateMachine


func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass
